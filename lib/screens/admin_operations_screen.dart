import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../models.dart';
import '../repository.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AdminRatesScreen extends StatefulWidget {
  const AdminRatesScreen({required this.state, super.key});
  final AppState state;

  @override
  State<AdminRatesScreen> createState() => _AdminRatesScreenState();
}

class _AdminRatesScreenState extends State<AdminRatesScreen> with LiveReload<AdminRatesScreen> {
  @override
  AppState get liveState => widget.state;

  @override
  Future<void> reloadLive() => _load();

  List<Map<String, dynamic>>? _rates;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rates = await widget.state.repo.getAdminRates();
      if (mounted) {
        setState(() {
          _rates = rates;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _save(String id, int general, int courier) async {
    await widget.state.repo.updateAdminRate(
      id: id,
      generalPriceCop: general,
      courierPriceCop: courier,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Row(
            children: [
              const Icon(Icons.payments_outlined, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tarifas',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                tooltip: 'Actualizar tarifas',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Define cuánto cobra la mensajería y cuánto recibe el domiciliario.',
            style: TextStyle(color: p.muted),
          ),
          const SizedBox(height: 18),
          if (_error != null)
            EmptyState(
              icon: Icons.wifi_off,
              title: 'No se pudieron cargar',
              message: _error!,
            )
          else if (_rates == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_rates!.isEmpty)
            const EmptyState(
              icon: Icons.payments_outlined,
              title: 'Sin tarifas configuradas',
              message: 'Agrega las tarifas base en Supabase para comenzar.',
            )
          else
            for (final rate in _rates!)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RateCard(rate: rate, onSave: _save),
              ),
        ],
      ),
    );
  }
}

class _RateCard extends StatefulWidget {
  const _RateCard({required this.rate, required this.onSave});
  final Map<String, dynamic> rate;
  final Future<void> Function(String id, int general, int courier) onSave;

  @override
  State<_RateCard> createState() => _RateCardState();
}

class _RateCardState extends State<_RateCard> {
  late final TextEditingController _general;
  late final TextEditingController _courier;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _general = TextEditingController(
      text: _moneyText(widget.rate['general_price_cop']),
    );
    _courier = TextEditingController(
      text: _moneyText(widget.rate['courier_price_cop']),
    );
  }

  @override
  void didUpdateWidget(covariant _RateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rate['id'] != widget.rate['id'] ||
        oldWidget.rate['general_price_cop'] !=
            widget.rate['general_price_cop'] ||
        oldWidget.rate['courier_price_cop'] !=
            widget.rate['courier_price_cop']) {
      _general.text = _moneyText(widget.rate['general_price_cop']);
      _courier.text = _moneyText(widget.rate['courier_price_cop']);
    }
  }

  @override
  void dispose() {
    _general.dispose();
    _courier.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final general = _parseMoney(_general.text);
    final courier = _parseMoney(_courier.text);
    if (general <= 0 || courier <= 0) {
      setState(() => _error = 'Escribe valores mayores que cero.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(widget.rate['id'].toString(), general, courier);
      if (mounted) showMessage(context, 'Tarifa guardada.');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final label = widget.rate['label']?.toString() ?? 'Servicio';
    final payment = _paymentLabel(widget.rate['payment_method']?.toString());
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (payment != null) Pill(label: payment, background: p.wash),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = [
                _priceField(_general, 'Cobro a la farmacia'),
                _priceField(_courier, 'Pago al domiciliario'),
              ];
              if (constraints.maxWidth < 420) {
                return Column(
                  children: [fields[0], const SizedBox(height: 10), fields[1]],
                );
              }
              return Row(
                children: [
                  Expanded(child: fields[0]),
                  const SizedBox(width: 10),
                  Expanded(child: fields[1]),
                ],
              );
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: p.danger, fontSize: 12.5)),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon:
                  _saving
                      ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.save_outlined),
              label: const Text('Guardar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, prefixText: r'$ '),
      );
}

class AdminLocationsScreen extends StatefulWidget {
  const AdminLocationsScreen({required this.state, super.key});
  final AppState state;

  @override
  State<AdminLocationsScreen> createState() => _AdminLocationsScreenState();
}

class _AdminLocationsScreenState extends State<AdminLocationsScreen> with LiveReload<AdminLocationsScreen> {
  @override
  AppState get liveState => widget.state;

  @override
  Future<void> reloadLive() => _load();

  List<Map<String, dynamic>>? _locations;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final locations = await widget.state.repo.getCourierLocations();
      if (mounted) {
        setState(() {
          _locations = locations;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _openMap(Map<String, dynamic> location) async {
    final lat = location['last_lat'];
    final lng = location['last_lng'];
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      showMessage(context, 'No se pudo abrir Google Maps.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ubicaciones',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                tooltip: 'Actualizar ubicaciones',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Última posición reportada por cada domiciliario.',
            style: TextStyle(color: p.muted),
          ),
          const SizedBox(height: 18),
          if (_error != null)
            EmptyState(
              icon: Icons.wifi_off,
              title: 'No se pudieron cargar',
              message: _error!,
            )
          else if (_locations == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_locations!.isEmpty)
            const EmptyState(
              icon: Icons.location_off_outlined,
              title: 'Sin domiciliarios',
              message: 'Los usuarios creados aparecerán aquí.',
            )
          else
            for (final location in _locations!)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                location['available'] == true
                                    ? p.successWash
                                    : p.surface3,
                            child: Text(
                              initialsOf(
                                location['full_name']?.toString() ?? '911',
                              ),
                              style: TextStyle(
                                color:
                                    location['available'] == true
                                        ? p.success
                                        : p.muted,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  location['full_name']?.toString() ??
                                      location['username']?.toString() ??
                                      'Domiciliario',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  location['zone']?.toString().isNotEmpty ==
                                          true
                                      ? location['zone'].toString()
                                      : 'Sin zona asignada',
                                  style: TextStyle(
                                    color: p.muted,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Pill(
                            label:
                                location['no_signal'] == true
                                    ? 'Sin señal'
                                    : location['available'] == true
                                    ? 'Disponible'
                                    : 'Ocupado',
                            color:
                                location['available'] == true
                                    ? p.success
                                    : p.warning,
                            background:
                                location['available'] == true
                                    ? p.successWash
                                    : p.warningWash,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _locationDescription(location),
                        style: TextStyle(
                          color: p.muted,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_hasCoordinates(location))
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () => _openMap(location),
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Abrir en Google Maps'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

int _parseMoney(String value) =>
    int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

String _moneyText(dynamic value) => value == null ? '' : value.toString();

String? _paymentLabel(String? value) {
  switch (value) {
    case 'cash':
      return 'Efectivo';
    case 'card':
      return 'Datáfono';
    default:
      return null;
  }
}

bool _hasCoordinates(Map<String, dynamic> location) =>
    location['last_lat'] != null && location['last_lng'] != null;

String _locationDescription(Map<String, dynamic> location) {
  final lat = location['last_lat'];
  final lng = location['last_lng'];
  final timestamp =
      DateTime.tryParse(
        location['last_location_at']?.toString() ?? '',
      )?.toLocal();
  if (lat == null || lng == null) {
    return 'Todavía no ha reportado una ubicación desde este dispositivo.';
  }
  final time =
      timestamp == null
          ? ''
          : ' · ${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  return 'Coordenadas: $lat, $lng$time';
}

/// Lo que gana la mensajería: cobrado a farmacias menos pagado a domiciliarios.
class AdminEarningsScreen extends StatefulWidget {
  const AdminEarningsScreen({required this.state, super.key});
  final AppState state;

  @override
  State<AdminEarningsScreen> createState() => _AdminEarningsScreenState();
}

class _AdminEarningsScreenState extends State<AdminEarningsScreen>
    with LiveReload<AdminEarningsScreen> {
  @override
  AppState get liveState => widget.state;

  @override
  Future<void> reloadLive() => _load();

  int _days = 1;
  List<Map<String, dynamic>>? _rows;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final today = widget.state.startOfToday;
      final rows = await widget.state.repo.getCompanyEarnings(
        today.subtract(Duration(days: _days - 1)),
        today,
      );
      if (mounted) {
        setState(() {
          _rows = rows;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  int _sum(Iterable<Map<String, dynamic>> rows, String field) => rows.fold(
    0,
    (total, row) => total + ((row[field] as num?)?.toInt() ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final rows = _rows ?? const <Map<String, dynamic>>[];
    final byCourier = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      byCourier.putIfAbsent('${row['full_name']}', () => []).add(row);
    }
    final couriers =
        byCourier.entries.toList()..sort(
          (a, b) => _sum(b.value, 'margin').compareTo(_sum(a.value, 'margin')),
        );
    final pending = _sum(rows, 'pending');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Text('Ganancias', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Lo que se cobra a las farmacias menos lo que se paga a los domiciliarios.',
            style: TextStyle(color: p.muted),
          ),
          const SizedBox(height: 14),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('Hoy')),
              ButtonSegment(value: 7, label: Text('7 días')),
              ButtonSegment(value: 30, label: Text('30 días')),
            ],
            selected: {_days},
            showSelectedIcon: false,
            onSelectionChanged: (value) {
              setState(() => _days = value.first);
              _load();
            },
          ),
          const SizedBox(height: 14),
          if (_error != null)
            EmptyState(
              icon: Icons.wifi_off,
              title: 'No se pudieron cargar',
              message: _error!,
            )
          else if (_rows == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ganancia de la mensajería',
                    style: TextStyle(color: p.muted),
                  ),
                  Text(
                    formatCop(_sum(rows, 'margin')),
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: p.success,
                      fontSize: 36,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _EarningsLine('Cobrado', formatCop(_sum(rows, 'billed'))),
                  _EarningsLine('Pagado', formatCop(_sum(rows, 'paid'))),
                  _EarningsLine('Servicios', '${_sum(rows, 'services')}'),
                  if (pending > 0)
                    _EarningsLine('Sin tarifa completa', '$pending'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const SectionTitle('Por domiciliario'),
            if (couriers.isEmpty)
              const EmptyState(
                icon: Icons.trending_up,
                title: 'Sin entregas',
                message: 'Cuando se entregue un servicio, aparece aquí.',
              )
            else
              for (final courier in couriers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                courier.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              formatCop(_sum(courier.value, 'margin')),
                              style: TextStyle(
                                color: p.success,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_sum(courier.value, 'services')} servicios · cobrado ${formatCop(_sum(courier.value, 'billed'))} · pagado ${formatCop(_sum(courier.value, 'paid'))}',
                          style: TextStyle(color: p.muted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _EarningsLine extends StatelessWidget {
  const _EarningsLine(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: context.palette.muted)),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
