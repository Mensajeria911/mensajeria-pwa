import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/service_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.state, super.key});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final profile = state.profile!;
    final now = DateTime.now();
    final active = state.active;
    final doneToday = state.deliveredSince(state.startOfToday);

    return RefreshIndicator(
      onRefresh: state.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Row(
            children: [
              const BrandMark(size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mensajeros Montería 911',
                  style: TextStyle(
                    color: p.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              CircleAvatar(
                radius: 19,
                backgroundColor: p.wash,
                child: Text(
                  initialsOf(profile.fullName),
                  style: TextStyle(
                    color: p.accentText,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '${greetingFor(now)}, ${profile.firstName}.',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 4),
          Text(
            profile.zone != null
                ? 'Tu zona: ${profile.zone}. La central te avisa cada servicio.'
                : 'La central te avisa cada servicio que te asigne.',
            style: TextStyle(color: p.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: state.available ? p.success : p.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.available ? 'Conectado' : 'En pausa',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        state.available
                            ? 'La central ve tu ubicación durante el turno'
                            : 'GPS apagado. La central no ve tu ubicación',
                        style: TextStyle(color: p.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: state.available,
                  onChanged: state.setAvailable,
                  activeThumbColor: Colors.white,
                  activeTrackColor: p.success,
                ),
              ],
            ),
          ),
          if (state.available && state.gpsBlocked) ...[
            const SizedBox(height: 8),
            Material(
              color: p.dangerWash,
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                dense: true,
                leading: Icon(Icons.location_off, color: p.danger),
                title: Text(
                  'El GPS está apagado o sin permiso. La central no te ve.',
                  style: TextStyle(
                    color: p.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: TextButton(
                  onPressed: state.openGpsSettings,
                  child: const Text('Activar'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _EarningsHero(
            total: state.todayTotal,
            count: state.todayCount,
          ),
          const SizedBox(height: 22),
          SectionTitle(
            active.isEmpty
                ? 'Sin servicios en curso'
                : active.length == 1
                ? 'Tu servicio en curso'
                : 'Tus servicios',
            subtitle:
                active.isEmpty
                    ? null
                    : active.length == 1
                    ? 'Sigue los pasos en orden.'
                    : 'Toca un servicio para ver sus pasos.',
          ),
          if (active.isEmpty)
            const EmptyState(
              icon: Icons.inbox_outlined,
              title: 'Todo al día',
              message:
                  'Cuando la central te asigne un servicio, suena y aparece aquí.',
            )
          else if (active.length == 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: ServiceCard(service: active.first, state: state),
            )
          else
            _ActiveServices(services: active, state: state),
          if (doneToday.isNotEmpty) ...[
            const SizedBox(height: 10),
            SectionTitle(
              'Hechos hoy',
              trailing: Text(
                '${doneToday.length}',
                style: TextStyle(
                  color: p.accentText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < doneToday.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: p.line),
                    ListTile(
                      onTap:
                          () => showServiceBreakdown(
                            context,
                            doneToday[i],
                            state,
                          ),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: serviceColor(
                          doneToday[i].serviceType,
                          doneToday[i].paymentMethod,
                        ).withValues(alpha: .14),
                        child: Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: serviceColor(
                            doneToday[i].serviceType,
                            doneToday[i].paymentMethod,
                          ),
                        ),
                      ),
                      title: Text(
                        doneToday[i].label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        '${state.branch(doneToday[i].branchCode).short} · ${doneToday[i].deliveredAt != null ? time12(doneToday[i].deliveredAt!) : ''}',
                        style: TextStyle(color: p.muted, fontSize: 12),
                      ),
                      trailing: Text(
                        formatCop(doneToday[i].feeCop),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveServices extends StatefulWidget {
  const _ActiveServices({required this.services, required this.state});
  final List<CourierService> services;
  final AppState state;

  @override
  State<_ActiveServices> createState() => _ActiveServicesState();
}

class _ActiveServicesState extends State<_ActiveServices> {
  String? _openId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final service in widget.services) ...[
          ServiceSummaryRow(
            service: service,
            state: widget.state,
            expanded: _openId == service.id,
            onTap:
                () => setState(
                  () => _openId = _openId == service.id ? null : service.id,
                ),
          ),
          const SizedBox(height: 8),
          if (_openId == service.id) ...[
            ServiceCard(service: service, state: widget.state),
            const SizedBox(height: 12),
          ],
        ],
        const SizedBox(height: 6),
      ],
    );
  }
}

class _EarningsHero extends StatelessWidget {
  const _EarningsHero({
    required this.total,
    required this.count,
  });
  final int total;
  final int count;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x400B2869),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Ganado hoy',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formatCop(total),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontSize: 40,
            ),
          ),
          const SizedBox(height: 10),
          Divider(color: Colors.white.withValues(alpha: .22), height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              _HeroMetric(
                value: '$count',
                label: count == 1 ? 'servicio' : 'servicios',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    ),
  );
}
