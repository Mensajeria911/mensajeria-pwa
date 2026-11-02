import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'tones.dart';

const _channelId = 'servicios_911';
const _channelName = 'Servicios asignados';
const _channelDescription =
    'Aviso con sonido cuando la central te asigna un servicio.';
const _silentChannelId = 'servicios_911_silencio';

/// Avisos a los que el usuario les puede elegir tono.
enum AlertTone {
  assigned('assigned', 'Nuevo servicio', 'tono_firma_911'),
  updated('updated', 'Servicio actualizado', 'tono_servicio_actualizado'),
  removed('removed', 'Servicio retirado', 'tono_servicio_retirado'),
  completed('completed', 'Entrega completada', 'tono_entrega_completada');

  const AlertTone(this.key, this.label, this.fallback);
  final String key;
  final String label;
  final String fallback;
}

/// Llega aquí un push con la app cerrada. Android muestra la notificación
/// del payload por sí solo usando el canal con el sonido de la mensajería.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

/// Sonido, vibración y notificaciones. Funciona sin Firebase (avisos con la
/// app abierta) y con Firebase agrega el push con la app cerrada.
class AlertService {
  AlertService._();
  static final instance = AlertService._();

  final _local = FlutterLocalNotificationsPlugin();
  final _player = AudioPlayer();
  bool _localReady = false;
  bool _firebaseReady = false;
  bool soundEnabled = true;
  bool vibrationEnabled = true;

  bool get pushAvailable => _firebaseReady;

  Future<void> initLocal() async {
    if (_localReady || kIsWeb) {
      _localReady = true;
      return;
    }
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final android =
        _local
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    // En Android el sonido lo decide el canal: uno con el sonido de la
    // mensajería (el mismo que usan los push) y otro sin sonido.
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('alerta_servicio'),
        enableVibration: true,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _silentChannelId,
        'Servicios asignados (sin sonido)',
        description: 'Aviso sin sonido cuando apagas el sonido en Mi cuenta.',
        importance: Importance.high,
        playSound: false,
        enableVibration: true,
      ),
    );
    await android?.requestNotificationsPermission();
    _localReady = true;
    for (final tone in AlertTone.values) {
      await _ensureChannel(soundOf(tone));
    }
  }

  final Map<AlertTone, String> _chosen = {};

  String soundOf(AlertTone tone) => _chosen[tone] ?? tone.fallback;

  String labelOf(AlertTone tone) {
    final id = soundOf(tone);
    return tones.firstWhere((item) => item.id == id).label;
  }

  Map<String, String> get chosenSounds => {
    for (final tone in AlertTone.values) tone.key: soundOf(tone),
  };

  Future<void> chooseSound(AlertTone tone, String id) async {
    if (!tones.any((item) => item.id == id)) return;
    _chosen[tone] = id;
    await _ensureChannel(id);
  }

  /// Un canal por tono: en Android el sonido del push lo decide el canal.
  Future<void> _ensureChannel(String id) async {
    if (kIsWeb || !_localReady) return;
    final label = tones.firstWhere((item) => item.id == id).label;
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            id,
            'Tono: $label',
            importance: Importance.max,
            playSound: true,
            sound: RawResourceAndroidNotificationSound(id),
            enableVibration: true,
          ),
        );
  }

  /// Intenta activar Firebase Cloud Messaging. Devuelve el token o null si
  /// el proyecto todavía no tiene Firebase configurado.
  /// Pide el permiso de notificaciones sin registrar todavía el dispositivo.
  Future<void> requestNotificationPermission() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {
      // Sin Firebase la app sigue con las alertas locales.
    }
  }

  Future<String?> initPush({
    void Function(RemoteMessage)? onForegroundMessage,
    void Function(RemoteMessage)? onMessageOpened,
  }) async {
    try {
      if (Firebase.apps.isEmpty) {
        if (kIsWeb) {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
        } else {
          await Firebase.initializeApp();
        }
      }
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
      }
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      FirebaseMessaging.onMessage.listen(
        (message) => onForegroundMessage?.call(message),
      );
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => onMessageOpened?.call(message),
      );
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        onMessageOpened?.call(initialMessage);
      }
      final token =
          kIsWeb
              ? await FirebaseMessaging.instance.getToken(
                vapidKey:
                    firebaseWebVapidKey.isEmpty ? null : firebaseWebVapidKey,
              )
              : await FirebaseMessaging.instance.getToken();
      _firebaseReady = token != null;
      return token;
    } catch (_) {
      _firebaseReady = false;
      return null;
    }
  }

  Stream<String> get onTokenRefresh =>
      _firebaseReady
          ? FirebaseMessaging.instance.onTokenRefresh
          : const Stream.empty();

  /// Aviso de servicio nuevo: sonido propio, vibración larga y notificación.
  Future<void> serviceAssigned({
    required String title,
    required String body,
    AlertTone tone = AlertTone.assigned,
  }) async {
    if (vibrationEnabled) unawaited(_vibratePattern());
    if (kIsWeb || !_localReady) {
      // PWA: el navegador no permite notificaciones locales; suena dentro de la app.
      if (soundEnabled) unawaited(playAlert(tone));
      return;
    }
    final sound = soundOf(tone);
    await _ensureChannel(sound);
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          soundEnabled ? sound : _silentChannelId,
          soundEnabled ? 'Tono: ${labelOf(tone)}' : 'Servicios asignados (sin sonido)',
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.public,
        ),
      ),
    );
  }

  Future<void> playAlert([AlertTone tone = AlertTone.assigned]) async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/${soundOf(tone)}.wav'), volume: 1);
    } catch (_) {}
  }

  Future<void> previewSound(String id) async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/$id.wav'), volume: 1);
    } catch (_) {}
  }

  Future<void> playSuccess() async {
    if (!soundEnabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/${soundOf(AlertTone.completed)}.wav'), volume: .8);
    } catch (_) {}
  }

  Future<void> _vibratePattern() async {
    for (var i = 0; i < 3; i++) {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }
  }
}
