import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({required this.state, super.key});
  final AppState state;

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  int _days = 7;
  late Future<List<EarningsDay>> _future = widget.state.earnings(_days);
  late int _revision = widget.state.earningsRevision;

  void _setPeriod(int days) => setState(() {
    _days = days;
    _future = widget.state.earnings(days);
  });

  @override
  Widget build(BuildContext context) {
    if (_revision != widget.state.earningsRevision) {
      _revision = widget.state.earningsRevision;
      _future = widget.state.earnings(_days);
    }
    final p = context.palette;
    final from = widget.state.startOfToday.subtract(Duration(days: _days - 1));
    final services = widget.state.deliveredSince(from);
    final groups = <String, (int count, int total, String type, String pay)>{};
    for (final s in services) {
      final g = groups[s.label];
      groups[s.label] = (
        (g?.$1 ?? 0) + 1,
        (g?.$2 ?? 0) + (s.feeCop ?? 0),
        s.serviceType,
        s.paymentMethod,
      );
    }
    final sortedGroups =
        groups.entries.toList()
          ..sort((a, b) => b.value.$2.compareTo(a.value.$2));

    return RefreshIndicator(
      onRefresh: () async => _setPeriod(_days),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Text('Ganancias', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 14),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('Hoy')),
              ButtonSegment(value: 7, label: Text('7 días')),
              ButtonSegment(value: 30, label: Text('30 días')),
            ],
            selected: {_days},
            onSelectionChanged: (v) => _setPeriod(v.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<EarningsDay>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return EmptyState(
                  icon: Icons.wifi_off,
                  title: 'No se pudo cargar',
                  message: 'Desliza hacia abajo para intentar de nuevo.',
                );
              }
              final days = snapshot.data ?? const [];
              final total = days.fold(0, (sum, d) => sum + d.total);
              final pending = days
                  .where((d) => !d.paid)
                  .fold(0, (sum, d) => sum + d.total);
              final count = days.fold(0, (sum, d) => sum + d.services);
              final max =
                  days.isEmpty
                      ? 1
                      : days
                          .map((d) => d.total)
                          .reduce((a, b) => a > b ? a : b)
                          .clamp(1, 1 << 31);
              return Column(
                children: [
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _days == 1 ? 'Hoy' : 'Últimos $_days días',
                          style: TextStyle(
                            color: p.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          formatCop(total),
                          style: Theme.of(
                            context,
                          ).textTheme.headlineLarge?.copyWith(fontSize: 36),
                        ),
                        Text(
                          '$count ${count == 1 ? 'servicio' : 'servicios'} · por cobrar ${formatCop(pending)}',
                          style: TextStyle(color: p.muted),
                        ),
                        if (days.length > 1) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 120,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                for (final d in days.reversed)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: Tooltip(
                                        message:
                                            '${dateLong(d.day)}: ${formatCop(d.total)}',
                                        child: Container(
                                          height: 8 + 104 * d.total / max,
                                          decoration: BoxDecoration(
                                            color:
                                                d.paid
                                                    ? p.lineStrong
                                                    : p.primary,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _Legend(color: p.primary, label: 'Por cobrar'),
                              const SizedBox(width: 14),
                              _Legend(color: p.lineStrong, label: 'Ya pagado'),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const SectionTitle('Por tipo de servicio'),
                  if (sortedGroups.isEmpty)
                    const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Sin servicios en este periodo',
                      message: 'Lo que entregues aparecerá aquí con su valor.',
                    )
                  else
                    SurfaceCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < sortedGroups.length; i++) ...[
                            if (i > 0) Divider(height: 1, color: p.line),
                            ListTile(
                              leading: CircleAvatar(
                                radius: 6,
                                backgroundColor: serviceColor(
                                  sortedGroups[i].value.$3,
                                  sortedGroups[i].value.$4,
                                ),
                              ),
                              title: Text(
                                sortedGroups[i].key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                '${sortedGroups[i].value.$1} ${sortedGroups[i].value.$1 == 1 ? 'servicio' : 'servicios'}',
                                style: TextStyle(color: p.muted, fontSize: 12),
                              ),
                              trailing: Text(
                                formatCop(sortedGroups[i].value.$2),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: context.palette.muted, fontSize: 12)),
    ],
  );
}
