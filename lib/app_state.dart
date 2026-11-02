import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'alerts.dart';
import 'models.dart';
import 'repository.dart';

enum AppPhase { loading, signedOut, blocked, ready }

/// Estado central de la app del domiciliario.
class AppState extends ChangeNotifier {
  AppState(this.repo);

  final CourierRepository repo;
  final alerts = AlertService.instance;

  AppPhase phase = AppPhase.loading;
  String? blockedReason;
  String? error;
  CourierProfile? profile;
  Map<String, Branch> branches = const {};
  List<String> zones = const [];
  List<CourierService> services = const [];
  bool available = true;
  bool busy = false;
  bool biometricReady = false;

  /// Primera apertura de la APK: falta pedir notificaciones y GPS.
  bool permissionsPending = false;

  /// El turno está activo pero el GPS está apagado o sin permiso.
  bool gpsBlocked = false;
  String? updatingId;
  String? updatingStepKey;
  String pushStatus = 'Configurando';
  int earningsRevision = 0;

  /// Sube con cada cambio en vivo; las pantallas de administración recargan con él.
  int liveRevision = 0;

  /// Servicio recién asignado que se muestra en la hoja "Nuevo servicio".
  CourierService? incoming;

  ThemeMode themeMode = ThemeMode.system;
  bool get soundEnabled => alerts.soundEnabled;
  bool get vibrationEnabled => alerts.vibrationEnabled;
  bool get isAdmin => profile?.isAdmin ?? false;

  RealtimeChannel? _channel;
  RealtimeChannel? _liveChannel;
  Timer? _liveDebounce;
  Timer? _liveBackup;
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<Position>? _locationSub;
  int _gpsRun = 0;
  Timer? _gpsHeartbeat;
  Position? _lastPosition;
  SharedPreferences? _prefs;
  final LocalAuthentication _localAuth = LocalAuthentication();
  static const _secureUsernameKey = 'login_username';
  static const _securePasswordKey = 'login_password';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  List<CourierService> get active =>
      services.where((s) => s.isActive).toList()
        ..sort((a, b) => (a.isEnroute ? 0 : 1).compareTo(b.isEnroute ? 0 : 1));
  List<CourierService> get delivered =>
      services.where((s) => s.isDelivered).toList()..sort(
        (a, b) => (b.deliveredAt ?? DateTime(0)).compareTo(
          a.deliveredAt ?? DateTime(0),
        ),
      );

  List<CourierService> deliveredSince(DateTime from) =>
      delivered
          .where((s) => s.deliveredAt != null && !s.deliveredAt!.isBefore(from))
          .toList();

  DateTime get startOfToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  int get todayTotal =>
      deliveredSince(startOfToday).fold(0, (sum, s) => sum + (s.feeCop ?? 0));
  int get todayCount => deliveredSince(startOfToday).length;


  Branch branch(String code) => branches[code] ?? Branch.unknown(code);

  Future<void> start() async {
    _prefs = await SharedPreferences.getInstance();
    alerts.soundEnabled = _prefs?.getBool('sound') ?? true;
    alerts.vibrationEnabled = _prefs?.getBool('vibration') ?? true;
    for (final tone in AlertTone.values) {
      final saved = _prefs?.getString('tone_${tone.key}');
      if (saved != null) await alerts.chooseSound(tone, saved);
    }
    biometricReady = _prefs?.getBool('biometric_login_enabled') ?? false;
    permissionsPending =
        !kIsWeb && !(_prefs?.getBool('permissions_asked_v2') ?? false);
    themeMode = ThemeMode.values.byName(_prefs?.getString('theme') ?? 'system');
    await alerts.initLocal();
    if (permissionsPending) unawaited(requestStartupPermissions());

    _authSub = repo.client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedOut) _resetSession();
      if (state.event == AuthChangeEvent.signedIn && profile == null) {
        unawaited(_loadSession());
      }
    });
    if (repo.client.auth.currentSession != null) {
      await _loadSession();
    } else {
      phase = AppPhase.signedOut;
      notifyListeners();
    }
  }

  /// Inicia sesión con usuario y clave, verificando que la pestaña elegida
  /// coincida con el rol real guardado en Supabase.
  Future<void> signIn(
    String username,
    String password, {
    String expectedRole = 'courier',
  }) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _signInWithCredentials(
        username,
        password,
        expectedRole: expectedRole,
      );
    } catch (e) {
      if (e is AuthException) await _clearBiometricCredentials();
      error = friendlyError(e);
      phase = AppPhase.signedOut;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Inicio normal y registro seguro de las credenciales para que la huella
  /// sea una alternativa en la pantalla de ingreso, no un bloqueo posterior.
  Future<void> _signInWithCredentials(
    String username,
    String password, {
    required String expectedRole,
  }) async {
    await repo.client.auth.signInWithPassword(
      email: _usernameToAuthEmail(username),
      password: password,
    );
    await _prefs?.setString('last_username', username.trim().toLowerCase());
    final role = (await repo.getProfile()).role;
    if (role != expectedRole) {
      await repo.client.auth.signOut(scope: SignOutScope.local);
      throw AppException(
        'Esta cuenta es de ${roleLabels[role] ?? role}. Usa el acceso correspondiente.',
      );
    }
    await _saveBiometricCredentials(username, password);
    await _loadSession();
  }

  /// Inicia sesión con la huella del dispositivo usando las credenciales
  /// guardadas en el almacenamiento seguro después del primer acceso normal.
  Future<void> signInWithBiometric({String expectedRole = 'courier'}) async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      if (kIsWeb) {
        throw const AppException(
          'La huella está disponible en la APK Android.',
        );
      }
      final username = await _secureStorage.read(key: _secureUsernameKey);
      final password = await _secureStorage.read(key: _securePasswordKey);
      if (username == null || password == null || username.isEmpty) {
        throw const AppException(
          'Primero entra una vez con usuario y contraseña para activar la huella.',
        );
      }
      if (!await _localAuth.isDeviceSupported()) {
        throw const AppException(
          'Este teléfono no tiene desbloqueo biométrico disponible.',
        );
      }
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Verifica tu identidad para iniciar sesión.',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (!authenticated) {
        throw const AppException(
          'No se verificó la huella. Puedes usar tu clave.',
        );
      }
      await _signInWithCredentials(
        username,
        password,
        expectedRole: expectedRole,
      );
    } catch (e) {
      if (e is AuthException) await _clearBiometricCredentials();
      error = friendlyError(e);
      phase = AppPhase.signedOut;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _saveBiometricCredentials(
    String username,
    String password,
  ) async {
    if (kIsWeb) return;
    try {
      if (!await _localAuth.isDeviceSupported()) return;
      await _secureStorage.write(
        key: _secureUsernameKey,
        value: username.trim().toLowerCase(),
      );
      await _secureStorage.write(key: _securePasswordKey, value: password);
      biometricReady = true;
      await _prefs?.setBool('biometric_login_enabled', true);
    } catch (_) {
      biometricReady = false;
    }
  }

  Future<void> _clearBiometricCredentials() async {
    if (kIsWeb) return;
    await _secureStorage.delete(key: _secureUsernameKey);
    await _secureStorage.delete(key: _securePasswordKey);
    biometricReady = false;
    await _prefs?.setBool('biometric_login_enabled', false);
  }

  /// Pide los permisos uno detrás de otro: Android descarta el segundo si
  /// llegan al mismo tiempo.
  Future<void> requestStartupPermissions() async {
    await alerts.requestNotificationPermission();
    try {
      await const MethodChannel(
        'mensajeros911/permissions',
      ).invokeMethod<bool>('requestPhone');
    } catch (_) {
      // Sin este permiso, llamar sigue funcionando desde el marcador.
    }
    try {
      await Geolocator.requestPermission();
    } catch (_) {
      // Si no se concede, la pantalla de domicilios avisa que falta el GPS.
    }
    await _prefs?.setBool('permissions_asked_v2', true);
    permissionsPending = false;
    notifyListeners();
    if (phase == AppPhase.ready && profile?.isCourier == true) {
      _startCourierServices();
    }
  }

  void _startCourierServices() {
    if (permissionsPending) return;
    unawaited(_setupPush().whenComplete(_startLocationUpdates));
  }

  /// Salir de la cuenta también termina el turno y borra la última ubicación.
  Future<void> signOut() async {
    _stopLocationUpdates();
    if (profile?.isCourier == true) {
      try {
        await repo.setPresence(available: false);
      } catch (_) {
        // Sin conexión igual se cierra la sesión.
      }
    }
    await repo.client.auth.signOut();
    _resetSession();
  }

  Future<void> _loadSession() async {
    phase = AppPhase.loading;
    notifyListeners();
    try {
      final p = await repo.getProfile();
      if (!p.isCourier && !p.isAdmin) {
        _block(
          'Esta cuenta es de ${roleLabels[p.role]?.toLowerCase() ?? p.role}. Usa la web correspondiente.',
        );
        return;
      }
      if (!p.active) {
        _block('Usuario desactivado. Contacte a la Central.');
        return;
      }
      profile = p;
      available = p.available;
      branches = await repo.getBranches();
      if (p.isCourier) {
        services = await repo.getServices();
      } else {
        zones = await repo.getZones();
        services = const [];
      }
      phase = AppPhase.ready;
      error = null;
      notifyListeners();
      _startLive();
      if (p.isCourier) {
        _subscribe();
        _startCourierServices();
      }
    } catch (e) {
      error = friendlyError(e);
      phase = AppPhase.signedOut;
      notifyListeners();
    }
  }

  void _block(String reason) {
    blockedReason = reason;
    phase = AppPhase.blocked;
    notifyListeners();
  }

  void _resetSession() {
    _stopLive();
    if (_channel != null) unawaited(repo.client.removeChannel(_channel!));
    _channel = null;
    _tokenSub?.cancel();
    _stopLocationUpdates();
    profile = null;
    zones = const [];
    services = const [];
    incoming = null;
    phase = AppPhase.signedOut;
    notifyListeners();
  }

  /// Al volver desde segundo plano solo sincroniza la operación. La biometría
  /// se usa exclusivamente desde el botón de inicio de sesión.
  Future<void> handleLifecycle(AppLifecycleState lifecycle) async {
    if (phase != AppPhase.ready) return;
    if (lifecycle == AppLifecycleState.resumed) {
      await refresh();
      if (profile?.isCourier == true && available) _startLocationUpdates();
    }
  }

  Future<void> refresh() async {
    try {
      final p = await repo.getProfile();
      if (!p.active) {
        return _block('Usuario desactivado. Contacte a la Central.');
      }
      profile = p;
      if (p.isCourier) {
        services = await repo.getServices();
      } else if (p.isAdmin) {
        zones = await repo.getZones();
      }
      error = null;
    } catch (e) {
      error = friendlyError(e);
    }
    notifyListeners();
  }

  void _startLive() {
    _stopLive();
    _liveChannel = repo.subscribeToLive(
      isAdmin: profile?.isAdmin ?? false,
      onChange: _scheduleLiveSync,
      onReconnected: _scheduleLiveSync,
    );
    // Respaldo por si un aviso en vivo se pierde.
    _liveBackup = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _scheduleLiveSync(),
    );
  }

  void _stopLive() {
    _liveDebounce?.cancel();
    _liveBackup?.cancel();
    if (_liveChannel != null) {
      unawaited(repo.client.removeChannel(_liveChannel!));
    }
    _liveChannel = null;
  }

  void _scheduleLiveSync() {
    _liveDebounce?.cancel();
    _liveDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_syncLive());
    });
  }

  Future<void> _syncLive() async {
    if (phase != AppPhase.ready) return;
    final wasAvailable = available;
    final before = active;
    try {
      branches = await repo.getBranches();
    } catch (_) {
      // Se conservan las sedes que ya estaban cargadas.
    }
    await refresh();
    final current = profile;
    if (current != null) available = current.available;
    if (current?.isCourier == true && wasAvailable != available) {
      if (available) {
        _startLocationUpdates();
      } else {
        _stopLocationUpdates();
      }
    }
    _announceRemoved(before);
    earningsRevision++;
    liveRevision++;
    notifyListeners();
  }

  /// Avisa cuando la central le pasa a otro un servicio que este tenía.
  void _announceRemoved(List<CourierService> before) {
    final ids = services.map((s) => s.id).toSet();
    for (final service in before.where((s) => !ids.contains(s.id))) {
      if (incoming?.id == service.id) incoming = null;
      // En segundo plano ya lo avisa el push; aquí saldría repetido.
      final visible =
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (!visible && alerts.pushAvailable) continue;
      unawaited(
        alerts.serviceAssigned(
          title: 'Servicio retirado · ${service.code}',
          body: 'La central te quitó este servicio. Ya no sigue en tu lista.',
          tone: AlertTone.removed,
        ),
      );
    }
  }

  void _subscribe() {
    _channel = repo.subscribeToServices((payload) {
      if (payload.eventType == PostgresChangeEvent.delete) {
        final id = payload.oldRecord['id']?.toString();
        services = services.where((s) => s.id != id).toList();
        notifyListeners();
        return;
      }
      final record = Map<String, dynamic>.from(payload.newRecord);
      final id = record['id']?.toString();
      final previous = services.where((s) => s.id == id).firstOrNull;
      // El tiempo real no trae valores: el pago se conserva o se consulta.
      record['fee_cop'] = previous?.feeCop;
      record['fee_confirmed'] = previous?.feeConfirmed ?? false;
      final updated = CourierService.fromMap(record);
      final list = [...services];
      final index = list.indexWhere((s) => s.id == updated.id);
      if (updated.status == 'cancelled') {
        if (index != -1) list.removeAt(index);
        if (incoming?.id == updated.id) incoming = null;
      } else if (index == -1) {
        list.insert(0, updated);
      } else {
        list[index] = updated;
      }
      services = list;
      final isNewAssignment =
          updated.isAssigned && (previous == null || !previous.isAssigned);
      if (isNewAssignment) _announce(updated);
      if (previous == null) unawaited(_loadPay(updated.id));
      notifyListeners();
    });
  }

  Future<void> _loadPay(String id) async {
    await refresh();
    final fresh = services.where((s) => s.id == id).firstOrNull;
    if (fresh != null && incoming?.id == id) incoming = fresh;
    notifyListeners();
  }

  void _announce(CourierService service) {
    incoming = service;
    final origin = branch(service.branchCode);
    unawaited(
      alerts.serviceAssigned(
        title: 'Nuevo servicio · ${service.code}',
        body: '${service.label} desde ${origin.name}',
      ),
    );
  }

  void dismissIncoming() {
    incoming = null;
    notifyListeners();
  }

  Future<void> _setupPush() async {
    final token = await alerts.initPush(
      onForegroundMessage: (message) {
        // Las asignaciones ya se anuncian por Realtime. Los cambios de ruta
        // no generan una hoja nueva, pero sí deben llamar la atención.
        if (message.data['event_type']?.toString() == 'service_updated') {
          unawaited(_announceUpdateFromPush(message));
        }
      },
      onMessageOpened: (message) {
        unawaited(_openServiceFromPush(message));
      },
    );
    if (token != null) {
      try {
        final platform = kIsWeb ? 'ios-pwa' : 'android';
        await repo.saveDeviceToken(token, platform);
        _deviceToken = token;
        unawaited(_syncTones());
        _tokenSub = alerts.onTokenRefresh.listen((t) async {
          try {
            await repo.saveDeviceToken(t, platform);
            _deviceToken = t;
            unawaited(_syncTones());
          } catch (_) {
            // Un token vencido no debe sacar al domiciliario de la jornada.
          }
        });
        pushStatus = 'Activas';
      } catch (_) {
        pushStatus = 'Permiso activo; falta registrar este dispositivo';
      }
    } else {
      pushStatus =
          kIsWeb
              ? 'Solo con la app abierta'
              : 'Solo con la app abierta (falta Firebase)';
    }
    notifyListeners();
  }

  String? _deviceToken;

  /// El servidor necesita conocer los tonos para respetarlos con la app cerrada.
  Future<void> _syncTones() async {
    final token = _deviceToken;
    if (token == null) return;
    try {
      await repo.saveDeviceTones(token, alerts.chosenSounds);
    } catch (_) {
      // El tono sigue funcionando con la app abierta.
    }
  }

  Future<void> chooseTone(AlertTone tone, String id) async {
    await alerts.chooseSound(tone, id);
    await _prefs?.setString('tone_${tone.key}', id);
    notifyListeners();
    await _syncTones();
  }

  Future<void> _announceUpdateFromPush(RemoteMessage message) async {
    final id = message.data['service_id']?.toString();
    CourierService? service =
        id == null ? null : services.where((item) => item.id == id).firstOrNull;
    if (service == null) {
      await refresh();
      service =
          id == null
              ? null
              : services.where((item) => item.id == id).firstOrNull;
    }
    final code =
        service?.code ?? message.data['code']?.toString() ?? 'servicio';
    await alerts.serviceAssigned(
      title: 'Servicio actualizado · $code',
      body: 'La farmacia modificó tu ruta. Revísala antes de continuar.',
      tone: AlertTone.updated,
    );
  }

  Future<void> _openServiceFromPush(RemoteMessage message) async {
    final serviceId = message.data['service_id']?.toString();
    if (serviceId == null || serviceId.isEmpty) {
      await refresh();
      return;
    }
    var service = services.where((item) => item.id == serviceId).firstOrNull;
    if (service == null) {
      await refresh();
      service = services.where((item) => item.id == serviceId).firstOrNull;
    }
    if (service != null && service.isActive) _announce(service);
  }

  Future<String?> startService(CourierService service) =>
      _changeStatus(service, 'enroute');

  Future<String?> completeStep(CourierService service, ServiceStep step) async {
    if (step.key.isEmpty) {
      return 'Esta versión del servicio no tiene una parada actualizable.';
    }
    updatingStepKey = '${service.id}:${step.key}';
    notifyListeners();
    try {
      final updated = await repo.updateStepStatus(
        service.id,
        step.key,
        'completed',
      );
      services = services.map((s) => s.id == updated.id ? updated : s).toList();
      if (incoming?.id == updated.id) incoming = updated;
      return null;
    } catch (e) {
      return friendlyError(e);
    } finally {
      updatingStepKey = null;
      notifyListeners();
    }
  }

  Future<String?> deliverService(CourierService service) async {
    final result = await _changeStatus(service, 'delivered');
    if (result == null) unawaited(alerts.playSuccess());
    return result;
  }

  Future<String?> _changeStatus(CourierService service, String next) async {
    updatingId = service.id;
    notifyListeners();
    try {
      final updated = await repo.updateStatus(service.id, next);
      services = services.map((s) => s.id == updated.id ? updated : s).toList();
      if (incoming?.id == updated.id) incoming = null;
      if (updated.isDelivered) earningsRevision++;
      return null;
    } catch (e) {
      return friendlyError(e);
    } finally {
      updatingId = null;
      notifyListeners();
    }
  }

  Future<void> setAvailable(bool value) async {
    available = value;
    if (!value) {
      _stopLocationUpdates();
      gpsBlocked = false;
    }
    notifyListeners();
    try {
      await repo.setPresence(available: value);
      if (value) _startLocationUpdates();
    } catch (e) {
      available = !value;
      if (available) _startLocationUpdates();
      error = friendlyError(e);
      notifyListeners();
    }
  }

  /// Mantiene la última ubicación del domiciliario disponible para la central.
  /// En Android usa un servicio de ubicación en primer plano para continuar
  /// reportando cuando la interfaz queda en segundo plano.
  void _startLocationUpdates() {
    _stopLocationUpdates();
    unawaited(_subscribeToLocation());
  }

  Future<void> _subscribeToLocation() async {
    if (!available) return;
    // Si entra en pausa mientras esto espera al GPS, no debe seguir encendiéndolo.
    final run = _gpsRun;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (run != _gpsRun) return;
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (run != _gpsRun) return;
      final blocked =
          !enabled ||
          permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever;
      if (blocked != gpsBlocked) {
        gpsBlocked = blocked;
        notifyListeners();
      }
      if (blocked) return;

      void report(Position position) {
        if (run != _gpsRun || !available) return;
        _lastPosition = position;
        unawaited(
          repo
              .setPresence(lat: position.latitude, lng: position.longitude)
              .catchError((_) {}),
        );
      }

      // El seguimiento arranca primero: si el primer punto tarda, no lo frena.
      _locationSub = Geolocator.getPositionStream(
        locationSettings: _locationSettings(),
      ).listen(report, onError: (_) {});

      // Sin moverse no llegan puntos nuevos; se repite el último para que la
      // central sepa que el turno sigue activo.
      _gpsHeartbeat = Timer.periodic(const Duration(seconds: 60), (_) {
        final last = _lastPosition;
        if (last != null) report(last);
      });

      if (!kIsWeb) {
        final known = await Geolocator.getLastKnownPosition();
        if (known != null) report(known);
      }
      final fresh = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
      report(fresh);
    } catch (_) {
      // El GPS no debe cerrar la sesión ni bloquear la operación.
    }
  }

  LocationSettings _locationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 60,
        intervalDuration: Duration(seconds: 30),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'Mensajeros 911',
          notificationText: 'Ubicación activa durante tu turno.',
          enableWakeLock: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 60,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 60,
    );
  }

  /// Abre los ajustes del teléfono para activar el GPS o darle permiso a la app.
  Future<void> openGpsSettings() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
    } else {
      await Geolocator.openLocationSettings();
    }
  }

  void _stopLocationUpdates() {
    _gpsRun++;
    _gpsHeartbeat?.cancel();
    _gpsHeartbeat = null;
    _lastPosition = null;
    _locationSub?.cancel();
    _locationSub = null;
  }

  Future<void> setSound(bool value) async {
    alerts.soundEnabled = value;
    await _prefs?.setBool('sound', value);
    notifyListeners();
  }

  Future<void> setVibration(bool value) async {
    alerts.vibrationEnabled = value;
    await _prefs?.setBool('vibration', value);
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    themeMode = mode;
    await _prefs?.setString('theme', mode.name);
    notifyListeners();
  }

  Future<List<EarningsDay>> earnings(int days) {
    final to = startOfToday;
    return repo.getEarningsDays(to.subtract(Duration(days: days - 1)), to);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _tokenSub?.cancel();
    _stopLocationUpdates();
    super.dispose();
  }
}

String _usernameToAuthEmail(String value) {
  final username = value.trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9._-]'),
    '',
  );
  return '$username@usuarios.mensajeros911.local';
}
