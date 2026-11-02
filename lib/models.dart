// Modelos de la app del domiciliario. Reflejan las tablas de Supabase.

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value.toString());
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

class CourierProfile {
  const CourierProfile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.active,
    required this.available,
    this.phone,
    this.zone,
    this.vehicle,
  });

  final String id;
  final String fullName;
  final String role;
  final bool active;
  final bool available;
  final String? phone;
  final String? zone;
  final String? vehicle;

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;
  bool get isAdmin => role == 'admin';
  bool get isCourier => role == 'courier';

  factory CourierProfile.fromMap(Map<String, dynamic> map) {
    final name = map['full_name']?.toString().trim() ?? '';
    return CourierProfile(
      id: map['id']?.toString() ?? '',
      fullName: name.isEmpty ? 'Domiciliario' : name,
      role: map['role']?.toString() ?? 'courier',
      active: map['active'] != false,
      available: map['available'] != false,
      phone: map['phone']?.toString(),
      zone: map['zone']?.toString(),
      vehicle: map['vehicle']?.toString(),
    );
  }
}

class Branch {
  const Branch({
    required this.code,
    required this.name,
    this.address,
    this.neighborhood,
    this.phone,
    this.latitude,
    this.longitude,
    this.active = true,
  });

  final String code;
  final String name;
  final String? address;
  final String? neighborhood;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final bool active;

  String get short => 'FN $code';

  factory Branch.fromMap(Map<String, dynamic> map) => Branch(
    code: map['code']?.toString() ?? '',
    name: map['name']?.toString() ?? 'farmanorte ${map['code']}',
    address: map['address']?.toString(),
    neighborhood: map['neighborhood']?.toString(),
    phone: map['phone']?.toString(),
    latitude: _asDouble(map['latitude']),
    longitude: _asDouble(map['longitude']),
    active: map['active'] != false,
  );

  static Branch unknown(String code) => Branch(
    code: code,
    name: code.isEmpty ? 'farmanorte' : 'farmanorte $code',
  );
}

/// Cuenta visible para el módulo de administración.
class StaffMember {
  const StaffMember({
    required this.id,
    required this.fullName,
    required this.role,
    required this.active,
    this.phone,
    this.zone,
    this.vehicle,
    this.branchCode,
    this.branchName,
  });

  final String id;
  final String fullName;
  final String role;
  final bool active;
  final String? phone;
  final String? zone;
  final String? vehicle;
  final String? branchCode;
  final String? branchName;

  factory StaffMember.fromMap(Map<String, dynamic> map) {
    final branch = map['branches'];
    return StaffMember(
      id: map['id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? 'Sin nombre',
      role: map['role']?.toString() ?? 'courier',
      active: map['active'] != false,
      phone: map['phone']?.toString(),
      zone: map['zone']?.toString(),
      vehicle: map['vehicle']?.toString(),
      branchCode: branch is Map ? branch['code']?.toString() : null,
      branchName: branch is Map ? branch['name']?.toString() : null,
    );
  }
}

const roleLabels = <String, String>{
  'courier': 'Domiciliario',
  'pharmacy': 'Farmacia',
  'central': 'Central',
  'admin': 'Administrador',
};

class EarningsDay {
  const EarningsDay({
    required this.day,
    required this.services,
    required this.total,
    required this.paid,
  });

  final DateTime day;
  final int services;
  final int total;
  final bool paid;

  factory EarningsDay.fromMap(Map<String, dynamic> map) => EarningsDay(
    day: DateTime.parse(map['day'].toString()),
    services: _asInt(map['services']) ?? 0,
    total: _asInt(map['fee_total']) ?? 0,
    paid: map['paid'] == true,
  );
}

const _typeLabels = <String, Map<String, String>>{
  'home': {'cash': 'Domicilio en efectivo', 'card': 'Domicilio con datáfono'},
  'home_buy': {
    'cash': 'Domicilio con compra',
    'card': 'Domicilio con compra y datáfono',
  },
  'home_cross': {
    'cash': 'Domicilio con cruce',
    'card': 'Domicilio con cruce y datáfono',
  },
  'home_buy_cross': {
    'cash': 'Domicilio con compra y cruce',
    'card': 'Domicilio con compra, cruce y datáfono',
  },
  'buy': {'none': 'Compra'},
  'cross': {'none': 'Cruce'},
  'change': {'none': 'Cambio de menuda'},
};

const statusLabels = <String, String>{
  'unassigned': 'Sin asignar',
  'assigned': 'Por iniciar',
  'enroute': 'En camino',
  'delivered': 'Entregado',
  'cancelled': 'Cancelado',
};

class ServiceStep {
  const ServiceStep({
    this.key = '',
    required this.kind,
    required this.title,
    required this.detail,
    this.status = 'pending',
    this.sourceBranchCode,
    this.place,
  });

  /// pickup | buy | cross | deliver | change
  final String key;
  final String kind;
  final String title;
  final String detail;
  final String status;
  final String? sourceBranchCode;
  final String? place;

  bool get isCompleted => status == 'completed' || status == 'skipped';
  bool get isInProgress => status == 'in_progress';

  factory ServiceStep.fromMap(Map<String, dynamic> map) => ServiceStep(
    key: map['key']?.toString() ?? '',
    kind: map['kind']?.toString() ?? 'pickup',
    title: map['title']?.toString() ?? 'Paso de la ruta',
    detail: map['detail']?.toString() ?? '',
    status: map['status']?.toString() ?? 'pending',
    sourceBranchCode: map['source_branch_code']?.toString(),
    place: map['place']?.toString(),
  );
}

class CourierService {
  const CourierService({
    required this.id,
    required this.code,
    required this.serviceType,
    required this.status,
    required this.branchCode,
    required this.paymentMethod,
    required this.feeConfirmed,
    required this.crossCodes,
    this.routePlan = const [],
    this.suggestedCourierId,
    this.feeCop,
    this.customerName,
    this.customerPhone,
    this.deliveryAddress,
    this.neighborhood,
    this.destinationLat,
    this.destinationLng,
    this.buyProduct,
    this.buyPlace,
    this.crossBranchCode,
    this.note,
    this.invoiceCode,
    this.medicineValueCop,
    this.changeAmountCop,
    this.evidencePath,
    this.createdAt,
    this.assignedAt,
    this.startedAt,
    this.deliveredAt,
  });

  final String id;
  final String code;
  final String serviceType;
  final String status;
  final String branchCode;
  final String paymentMethod;
  final bool feeConfirmed;
  final List<String> crossCodes;
  final List<ServiceStep> routePlan;
  final String? suggestedCourierId;
  final int? feeCop;
  final String? customerName;
  final String? customerPhone;
  final String? deliveryAddress;
  final String? neighborhood;
  final double? destinationLat;
  final double? destinationLng;
  final String? buyProduct;
  final String? buyPlace;
  final String? crossBranchCode;
  final String? note;
  final String? invoiceCode;
  final int? medicineValueCop;
  final int? changeAmountCop;
  final String? evidencePath;
  final DateTime? createdAt;
  final DateTime? assignedAt;
  final DateTime? startedAt;
  final DateTime? deliveredAt;

  String get label =>
      _typeLabels[serviceType]?[paymentMethod] ??
      _typeLabels[serviceType]?.values.first ??
      serviceType;
  String get statusLabel => statusLabels[status] ?? status;

  bool get hasHome => serviceType.startsWith('home');
  bool get hasBuy => serviceType == 'buy' || serviceType.contains('buy');
  bool get hasCross => serviceType == 'cross' || serviceType.contains('cross');
  bool get isChange => serviceType == 'change';
  bool get usesCard => paymentMethod == 'card';
  bool get hasEvidence => evidencePath != null && evidencePath!.isNotEmpty;

  bool get isAssigned => status == 'assigned';
  bool get isEnroute => status == 'enroute';
  bool get isActive => isAssigned || isEnroute;
  bool get isDelivered => status == 'delivered';

  /// Domicilio con compra o cruce que va directo al cliente.
  bool get skipsPharmacy =>
      hasHome &&
      serviceType != 'home' &&
      routePlan.isNotEmpty &&
      !routePlan.any((step) => step.kind == 'pickup');

  String get skipPharmacyReason {
    final what =
        hasBuy && hasCross
            ? 'la compra y el cruce'
            : hasBuy
            ? 'la compra'
            : 'el cruce';
    return 'No vayas a la farmacia: solo lleva $what.';
  }

  /// Pasos en el orden en que el domiciliario los hace.
  List<ServiceStep> steps(Branch origin, Branch? crossBranch) {
    if (routePlan.isNotEmpty) return _ordered(routePlan);
    return _ordered(_defaultSteps(origin, crossBranch));
  }

  /// Primero lo que hay que buscar afuera y al final la entrega. En compra o
  /// cruce solos no se pasa antes por la sede que publicó, porque ahí termina.
  List<ServiceStep> _ordered(List<ServiceStep> source) {
    if (isChange) return source;
    final kept =
        source.where((step) {
          if (hasHome) {
            return step.key != 'return-origin' && step.key != 'cross-return';
          }
          return step.kind != 'pickup';
        }).toList();
    int rank(ServiceStep step) => switch (step.kind) {
      'cross' => 0,
      'buy' => 1,
      'pickup' => 2,
      _ => 3,
    };
    final indexed = kept.asMap().entries.toList();
    indexed.sort((a, b) {
      final byKind = rank(a.value).compareTo(rank(b.value));
      return byKind != 0 ? byKind : a.key.compareTo(b.key);
    });
    return [for (final entry in indexed) entry.value];
  }

  List<ServiceStep> _defaultSteps(Branch origin, Branch? crossBranch) {
    final list = <ServiceStep>[];
    final originDetail = [
      origin.address,
      origin.neighborhood,
    ].whereType<String>().where((v) => v.isNotEmpty).join(' · ');
    if (isChange) {
      list.add(
        ServiceStep(
          kind: 'pickup',
          title: 'Recoger los billetes en ${origin.name}',
          detail: originDetail.isEmpty ? 'Pregunta en caja' : originDetail,
        ),
      );
      list.add(
        ServiceStep(
          kind: 'change',
          title: 'Cambiar por sencillo',
          detail:
              changeAmountCop != null
                  ? 'Valor a cambiar: ${formatCop(changeAmountCop)}'
                  : 'Trae billetes y monedas pequeñas',
        ),
      );
      list.add(
        ServiceStep(
          kind: 'deliver',
          title: 'Entregar el sencillo en ${origin.name}',
          detail: 'Pide que cuenten el dinero al recibir',
        ),
      );
      return list;
    }
    list.add(
      ServiceStep(
        kind: 'pickup',
        title: 'Recoger en ${origin.name}',
        detail: [
          if (originDetail.isNotEmpty) originDetail,
          if (hasBuy) 'Pide la plata de la compra',
        ].join('. '),
      ),
    );
    if (hasBuy) {
      final purchaseLines =
          (buyProduct ?? '')
              .split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList();
      final purchaseTitle =
          purchaseLines.length > 1
              ? 'Comprar ${purchaseLines.length} productos'
              : 'Comprar ${buyProduct ?? 'el producto'}';
      list.add(
        ServiceStep(
          kind: 'buy',
          title: purchaseTitle,
          detail: [
            if (buyPlace != null) 'En $buyPlace',
            'Guarda la factura',
          ].join('. '),
        ),
      );
    }
    if (hasCross) {
      final source = crossBranch?.short ?? 'FN ${crossBranchCode ?? ''}';
      list.add(
        ServiceStep(
          kind: 'cross',
          title: 'Recoger cruce en $source para ${origin.short}',
          detail:
              crossCodes.isEmpty
                  ? 'Cruce entre sedes'
                  : 'Códigos: ${crossCodes.join(', ')}',
        ),
      );
    }
    if (serviceType == 'cross') {
      list.add(
        ServiceStep(
          kind: 'deliver',
          title: 'Entregar los cruces en ${origin.short}',
          detail: originDetail,
        ),
      );
    }
    if (serviceType == 'buy') {
      list.add(
        ServiceStep(
          kind: 'deliver',
          title: 'Regresar con la compra a ${origin.short}',
          detail: originDetail,
        ),
      );
    }
    if (hasHome) {
      list.add(
        ServiceStep(
          kind: 'deliver',
          title: 'Entregar en ${deliveryAddress ?? 'la dirección del cliente'}',
          detail: [
            if (neighborhood != null) neighborhood!,
            usesCard ? 'Cobrar con datáfono' : 'Cobrar en efectivo',
          ].join('. '),
        ),
      );
    }
    return list;
  }

  factory CourierService.fromMap(Map<String, dynamic> map) {
    final codes = map['cross_codes'];
    final route = map['route_plan'];
    return CourierService(
      id: map['id']?.toString() ?? '',
      code: map['code']?.toString() ?? 'Servicio',
      serviceType: map['service_type']?.toString() ?? 'home',
      status: map['status']?.toString() ?? 'assigned',
      branchCode: map['branch_code']?.toString() ?? '',
      paymentMethod: map['payment_method']?.toString() ?? 'none',
      feeConfirmed: map['fee_confirmed'] == true,
      crossCodes:
          codes is List ? codes.map((c) => c.toString()).toList() : const [],
      routePlan:
          route is List
              ? route
                  .whereType<Map>()
                  .map(
                    (step) =>
                        ServiceStep.fromMap(Map<String, dynamic>.from(step)),
                  )
                  .toList()
              : const [],
      suggestedCourierId: map['suggested_courier_id']?.toString(),
      feeCop: _asInt(map['fee_cop']),
      customerName: map['customer_name']?.toString(),
      customerPhone: map['customer_phone']?.toString(),
      deliveryAddress: map['delivery_address']?.toString(),
      neighborhood: map['neighborhood']?.toString(),
      destinationLat: _asDouble(map['destination_lat']),
      destinationLng: _asDouble(map['destination_lng']),
      buyProduct: map['buy_product']?.toString(),
      buyPlace: map['buy_place']?.toString(),
      crossBranchCode: map['cross_branch_code']?.toString(),
      note: map['note']?.toString(),
      invoiceCode: map['invoice_code']?.toString(),
      medicineValueCop: _asInt(map['medicine_value_cop']),
      changeAmountCop: _asInt(map['change_amount_cop']),
      evidencePath: map['evidence_path']?.toString(),
      createdAt: _asDate(map['created_at']),
      assignedAt: _asDate(map['assigned_at']),
      startedAt: _asDate(map['started_at']),
      deliveredAt: _asDate(map['delivered_at']),
    );
  }
}

String formatCop(int? value) {
  if (value == null) return 'Por confirmar';
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}\$$buffer';
}

const _weekdays = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];
const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String weekdayName(DateTime date) => _weekdays[date.weekday - 1];
String weekdayShort(DateTime date) => weekdayName(date).substring(0, 3);
String dateLong(DateTime date) =>
    '${weekdayName(date)} ${date.day} de ${_months[date.month - 1]}';

String time12(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minutes = date.minute.toString().padLeft(2, '0');
  return '$hour:$minutes ${date.hour < 12 ? 'a. m.' : 'p. m.'}';
}

String greetingFor(DateTime date) {
  if (date.hour < 12) return 'Buenos días';
  if (date.hour < 19) return 'Buenas tardes';
  return 'Buenas noches';
}

String initialsOf(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '911';
  if (parts.length == 1) {
    return parts.first
        .substring(0, parts.first.length > 1 ? 2 : 1)
        .toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
