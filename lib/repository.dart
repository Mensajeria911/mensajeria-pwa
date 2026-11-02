
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_auth/local_auth.dart';

import 'models.dart';

/// Supabase Auth usa un correo técnico; en la interfaz solo se muestra el
/// usuario que entrega la central.
const usernameDomain = 'usuarios.mensajeros911.local';

String normalizeUsername(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]'), '');

/// Todo el acceso a Supabase de la app. Las reglas de negocio (transiciones,
/// evidencia obligatoria, permisos) las valida la base de datos.
class CourierRepository {
  CourierRepository(this.client);

  final SupabaseClient client;

  String? get userId => client.auth.currentUser?.id;

  Future<CourierProfile> getProfile() async {
    final row =
        await client
            .from('profiles')
            .select(
              'id, full_name, phone, role, active, available, zone, vehicle',
            )
            .eq('id', userId!)
            .maybeSingle();
    if (row == null) {
      throw const AppException(
        'Tu cuenta todavía no tiene un perfil. Comunícate con la central.',
      );
    }
    return CourierProfile.fromMap(row);
  }

  Future<Map<String, Branch>> getBranches() async {
    final rows = await client
        .from('branches')
        .select(
          'code, name, address, neighborhood, phone, latitude, longitude, active',
        )
        .order('code');
    return {
      for (final row in rows) row['code'].toString(): Branch.fromMap(row),
    };
  }

  Future<List<String>> getZones() async {
    final rows = await client
        .from('zones')
        .select('name')
        .eq('active', true)
        .order('sort_order');
    return rows.map((row) => row['name'].toString()).toList();
  }

  /// Servicios activos y los entregados de los últimos 31 días.
  Future<List<CourierService>> getServices() async {
    final since =
        DateTime.now()
            .subtract(const Duration(days: 31))
            .toUtc()
            .toIso8601String();
    final rows = await client
        .from('visible_services')
        .select()
        .eq('assigned_courier_id', userId!)
        .or('status.in.(assigned,enroute),delivered_at.gte.$since')
        .order('assigned_at', ascending: false);
    return rows.map(CourierService.fromMap).toList();
  }

  Future<List<EarningsDay>> getEarningsDays(DateTime from, DateTime to) async {
    String day(DateTime d) => d.toIso8601String().substring(0, 10);
    final rows = await client.rpc(
      'payroll_days',
      params: {'p_courier_id': userId, 'p_from': day(from), 'p_to': day(to)},
    );
    return (rows as List)
        .map((r) => EarningsDay.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<CourierService> updateStatus(
    String serviceId,
    String nextStatus,
  ) async {
    final result = await client.rpc(
      'update_delivery_status',
      params: {'p_service_id': serviceId, 'p_next_status': nextStatus},
    );
    return CourierService.fromMap(Map<String, dynamic>.from(result as Map));
  }

  Future<CourierService> updateStepStatus(
    String serviceId,
    String stepKey,
    String status,
  ) async {
    final result = await client.rpc(
      'update_delivery_step_status',
      params: {
        'p_service_id': serviceId,
        'p_step_key': stepKey,
        'p_status': status,
      },
    );
    return CourierService.fromMap(Map<String, dynamic>.from(result as Map));
  }

  Future<String?> evidenceUrl(String path) async {
    try {
      return await client.storage
          .from('evidence')
          .createSignedUrl(path, 60 * 30);
    } catch (_) {
      return null;
    }
  }

  Future<void> setPresence({bool? available, double? lat, double? lng}) async {
    await client.rpc(
      'set_courier_presence',
      params: {'p_available': available, 'p_lat': lat, 'p_lng': lng},
    );
  }

  RealtimeChannel subscribeToServices(
    void Function(PostgresChangePayload payload) onChange,
  ) {
    return client
        .channel('courier-services-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'delivery_services',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'assigned_courier_id',
            value: userId,
          ),
          callback: onChange,
        )
        .subscribe();
  }

  /// Todo lo demás que la app muestra: perfil, sedes, tarifas y pagos.
  RealtimeChannel subscribeToLive({
    required bool isAdmin,
    required void Function() onChange,
    required void Function() onReconnected,
  }) {
    var channel = client.channel('live-$userId');
    void listen(String table, {String? column}) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter:
            column == null
                ? null
                : PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: column,
                  value: userId,
                ),
        callback: (_) => onChange(),
      );
    }

    listen('branches');
    listen('service_rates');
    if (isAdmin) {
      listen('profiles');
      listen('delivery_services');
      listen('zones');
      listen('payroll_paid_days');
    } else {
      listen('profiles', column: 'id');
      listen('notification_outbox', column: 'user_id');
      listen('payroll_paid_days', column: 'courier_id');
    }
    var connected = false;
    return channel.subscribe((status, [error]) {
      if (status != RealtimeSubscribeStatus.subscribed) return;
      if (connected) onReconnected();
      connected = true;
    });
  }

  Future<void> saveDeviceToken(String token, String platform) async {
    await client.from('notification_devices').upsert({
      'user_id': userId,
      'platform': platform,
      'token': token,
      'enabled': true,
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,platform,token');
  }

  Future<void> saveDeviceTones(String token, Map<String, String> tones) async {
    await client
        .from('notification_devices')
        .update({'tones': tones})
        .eq('user_id', userId!)
        .eq('token', token);
  }

  // ---------------------------------------------------------------------
  // Administración de cuentas
  // ---------------------------------------------------------------------

  Future<List<StaffMember>> getPeople() async {
    final rows = await client
        .from('profiles')
        .select(
          'id, full_name, phone, role, active, available, zone, vehicle, branch_id, branches(code, name)',
        )
        .order('full_name');
    return rows.map(StaffMember.fromMap).toList();
  }

  Future<void> setPersonActive(String id, bool active) async {
    await client.rpc(
      'admin_set_profile_active',
      params: {'p_user_id': id, 'p_active': active},
    );
  }

  Future<List<Map<String, dynamic>>> getCompanyEarnings(
    DateTime from,
    DateTime to,
  ) async {
    String day(DateTime d) => d.toIso8601String().split('T').first;
    final rows = await client.rpc(
      'company_earnings',
      params: {'p_from': day(from), 'p_to': day(to)},
    );
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getAdminRates() async {
    final rows = await client
        .from('service_rates')
        .select(
          'id, service_type, payment_method, label, general_price_cop, courier_price_cop, general_price_confirmed, courier_price_confirmed, active',
        )
        .eq('active', true)
        .order('label');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> updateAdminRate({
    required String id,
    required int generalPriceCop,
    required int courierPriceCop,
  }) async {
    await client
        .from('service_rates')
        .update({
          'general_price_cop': generalPriceCop,
          'courier_price_cop': courierPriceCop,
          'general_price_confirmed': true,
          'courier_price_confirmed': true,
          'price_cop': courierPriceCop,
          'price_confirmed': true,
          'updated_by': userId,
        })
        .eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getAdminCouriers() async {
    final rows = await client
        .from('profiles')
        .select('id, full_name, username, active, zone')
        .eq('role', 'courier')
        .order('full_name');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> getCourierLocations() async {
    final rows = await client
        .from('profiles')
        .select(
          'id, full_name, username, active, available, zone, last_lat, last_lng, last_location_at',
        )
        .eq('role', 'courier')
        .order('full_name');
    return rows.map((row) {
      final location = Map<String, dynamic>.from(row);
      final at = DateTime.tryParse(location['last_location_at']?.toString() ?? '');
      // El celular reporta cada minuto; 10 sin noticias significa que dejó de hacerlo.
      location['no_signal'] =
          location['available'] == true &&
          (at == null || DateTime.now().difference(at).inMinutes > 10);
      if (location['no_signal'] == true) location['available'] = false;
      return location;
    }).toList();
  }

  Future<void> createUser({
    required String username,
    required String password,
    required String fullName,
    required String role,
    String? branchCode,
    String? zone,
    String? phone,
  }) async {
    final response = await client.functions.invoke(
      'admin-create-user',
      body: {
        'username': normalizeUsername(username),
        'password': password,
        'full_name': fullName.trim(),
        'role': role,
        'branch_code': branchCode,
        'zone': zone,
        'phone': phone,
      },
    );
    final data = response.data;
    if (response.status >= 400) {
      throw AppException(
        data is Map && data['error'] != null
            ? data['error'].toString()
            : 'No se pudo crear la cuenta.',
      );
    }
  }
}


class AppException implements Exception {
  const AppException(this.message);
  final String message;
  @override
  String toString() => message;
}

String friendlyError(Object error) {
  if (error is LocalAuthException) {
    switch (error.code) {
      case LocalAuthExceptionCode.noBiometricsEnrolled:
        return 'No hay una huella configurada en este teléfono. Configúrala en Ajustes y vuelve a intentarlo.';
      case LocalAuthExceptionCode.noBiometricHardware:
        return 'Este teléfono no tiene lector biométrico disponible.';
      case LocalAuthExceptionCode.noCredentialsSet:
        return 'Configura una huella o bloqueo seguro en el teléfono antes de usar este acceso.';
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
        return 'No se verificó la huella. Puedes usar tu usuario y clave.';
      case LocalAuthExceptionCode.temporaryLockout:
      case LocalAuthExceptionCode.biometricLockout:
        return 'La huella está bloqueada temporalmente. Desbloquea el teléfono y vuelve a intentarlo.';
      default:
        return error.description ??
            'No se pudo usar la huella. Puedes usar tu usuario y clave.';
    }
  }
  if (error is PostgrestException) {
    if (error.code == '401' || error.message.contains('401')) {
      return 'La conexión con Supabase rechazó esta versión. Hay que actualizar la URL o la clave pública antes de iniciar sesión.';
    }
    return error.message;
  }
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('email not confirmed')) {
      return 'La cuenta todavía no está confirmada. El administrador debe confirmar el usuario antes de iniciar sesión.';
    }
    if (message.contains('invalid login')) {
      return 'El usuario o la clave no coinciden.';
    }
    if (message.contains('invalid api key')) {
      return 'La clave pública de Supabase no es válida para este proyecto.';
    }
    return error.message;
  }
  if (error is FunctionException) {
    final details = error.details;
    if (details is Map && details['error'] != null) {
      return details['error'].toString();
    }
    if (error.status == 0) {
      return 'No se pudo contactar el servicio de usuarios. Revisa tu conexión e inténtalo de nuevo.';
    }
    return 'El servicio de usuarios respondió con un error (${error.status}).';
  }
  if (error is StorageException) {
    return 'No se pudo subir la foto: ${error.message}';
  }
  if (error is AppException) return error.message;
  return 'No pudimos conectarnos. Revisa tu internet e inténtalo de nuevo.';
}
