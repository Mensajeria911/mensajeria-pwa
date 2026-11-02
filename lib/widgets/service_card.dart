import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'common.dart';
import 'slide_to_confirm.dart';

IconData stepIcon(String kind) => switch (kind) {
  'pickup' => Icons.storefront_outlined,
  'buy' => Icons.shopping_bag_outlined,
  'cross' => Icons.swap_horiz_rounded,
  'change' => Icons.payments_outlined,
  _ => Icons.location_on_outlined,
};

/// Tarjeta del servicio en curso o por iniciar, con todo lo que el
/// domiciliario necesita: pasos, códigos y acciones.
class ServiceCard extends StatelessWidget {
  const ServiceCard({required this.service, required this.state, super.key});

  final CourierService service;
  final AppState state;

  /// Lleva al punto del paso que sigue: sede del cruce, lugar de compra, sede
  /// que publicó o cliente.
  Uri _mapsUri(Branch origin, Branch? cross, ServiceStep? step) {
    Uri directions(double lat, double lng) => Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=two-wheeler',
    );
    Uri search(String text) => Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$text, Montería, Córdoba')}',
    );
    Uri toBranch(Branch branch) =>
        branch.latitude != null && branch.longitude != null
            ? directions(branch.latitude!, branch.longitude!)
            : search('${branch.name} ${branch.address ?? ''}');

    if (step?.kind == 'cross') {
      final code = step?.sourceBranchCode;
      return toBranch(code != null ? state.branch(code) : (cross ?? origin));
    }
    if (step?.kind == 'buy') {
      final place = step?.place ?? service.buyPlace;
      if (place != null && place.isNotEmpty) return search(place);
    }
    if (step?.kind == 'pickup' || !service.hasHome) return toBranch(origin);
    if (service.destinationLat != null && service.destinationLng != null) {
      return directions(service.destinationLat!, service.destinationLng!);
    }
    return search(
      '${service.deliveryAddress ?? ''} ${service.neighborhood ?? ''}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final origin = state.branch(service.branchCode);
    final cross =
        service.crossBranchCode == null
            ? null
            : state.branch(service.crossBranchCode!);
    final steps = service.steps(origin, cross);
    final pendingIndex = steps.indexWhere((step) => !step.isCompleted);
    final current =
        pendingIndex == -1
            ? (steps.isEmpty ? 0 : steps.length - 1)
            : pendingIndex;
    final color = serviceColor(service.serviceType, service.paymentMethod);
    final busy = state.updatingId == service.id;

    return SurfaceCard(
      padding: EdgeInsets.zero,
      borderColor: service.isEnroute ? p.primary.withValues(alpha: .45) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Pill(
                            label: service.label,
                            color: color,
                            background: color.withValues(alpha: .12),
                          ),
                          if (service.usesCard)
                            const Pill(
                              label: 'Datáfono',
                              icon: Icons.credit_card,
                            ),
                        ],
                      ),
                    ),
                    Text(
                      service.code,
                      style: TextStyle(
                        color: p.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      service.isDelivered ? Icons.check_circle : Icons.circle,
                      size: service.isDelivered ? 15 : 9,
                      color:
                          service.isDelivered
                              ? p.success
                              : service.isEnroute
                              ? p.primary
                              : p.warning,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      service.isDelivered
                          ? 'Entregado'
                          : service.isEnroute
                          ? 'En camino'
                          : 'Por iniciar',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color:
                            service.isDelivered
                                ? p.success
                                : service.isEnroute
                                ? p.accentText
                                : p.warning,
                      ),
                    ),
                    Text(
                      service.isDelivered
                          ? (service.deliveredAt != null
                              ? ' · ${time12(service.deliveredAt!)}'
                              : '')
                          : ' · paso ${current + 1} de ${steps.length}',
                      style: TextStyle(color: p.muted),
                    ),
                    const Spacer(),
                    Text(
                      formatCop(service.feeCop),
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (service.skipsPharmacy)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: p.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      service.skipPharmacyReason,
                      style: TextStyle(
                        color: p.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          ...List.generate(
            steps.length,
            (i) => _StepRow(
              step: steps[i],
              index: i,
              current: current,
              last: i == steps.length - 1,
              service: service,
              state: state,
            ),
          ),
          if (service.note?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.surface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.line),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.sticky_note_2_outlined,
                      size: 18,
                      color: p.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        service.note!,
                        style: TextStyle(color: p.ink2, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          _CodesBlock(service: service),
          if (service.isDelivered) ...[
            if (service.hasEvidence) _EvidencePhoto(service: service, state: state),
            const SizedBox(height: 16),
          ] else ...[
            Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.navigation_outlined,
                    label: 'Google Maps',
                    onTap:
                        () => openExternal(
                          context,
                          _mapsUri(
                            origin,
                            cross,
                            steps.isEmpty ? null : steps[current],
                          ),
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                if (service.customerPhone != null && service.hasHome) ...[
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.phone_outlined,
                      label: 'Cliente',
                      onTap:
                          () => openExternal(
                            context,
                            Uri.parse('tel:+57${service.customerPhone}'),
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: _ActionButton(
                    icon: Icons.storefront_outlined,
                    label: origin.short,
                    onTap:
                        origin.phone == null
                            ? () => showMessage(
                              context,
                              '${origin.name} todavía no tiene teléfono registrado.',
                            )
                            : () => openExternal(
                              context,
                              Uri.parse(
                                'tel:${origin.phone!.replaceAll(' ', '')}',
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SlideToConfirm(
              label: 'Desliza para marcar entregado',
              busy: busy,
              onConfirmed: () async {
                final error = await state.deliverService(service);
                if (!context.mounted) return;
                showMessage(
                  context,
                  error ??
                      '¡Entregado! Ganancia guardada: ${formatCop(service.feeCop)}.',
                );
              },
            ),
          ),
          ],
        ],
      ),
    );
  }
}

/// Fila compacta para cuando hay varios servicios: se ven todos sin bajar y
/// al tocar uno se abre su tarjeta.
class ServiceSummaryRow extends StatelessWidget {
  const ServiceSummaryRow({
    required this.service,
    required this.state,
    required this.expanded,
    required this.onTap,
    super.key,
  });

  final CourierService service;
  final AppState state;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = serviceColor(service.serviceType, service.paymentMethod);
    final steps = service.steps(
      state.branch(service.branchCode),
      service.crossBranchCode == null
          ? null
          : state.branch(service.crossBranchCode!),
    );
    final pending = steps.indexWhere((step) => !step.isCompleted);
    final current = pending == -1 ? steps.length - 1 : pending;
    final now = steps.isEmpty ? null : steps[current < 0 ? 0 : current];
    return SurfaceCard(
      padding: EdgeInsets.zero,
      borderColor: expanded ? p.primary.withValues(alpha: .45) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 42,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${service.code} · ${service.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if (now != null)
                      Text(
                        'Paso ${current + 1} de ${steps.length}: ${now.title}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.muted,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatCop(service.feeCop),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                color: p.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Desglose de solo lectura de un servicio ya entregado.
Future<void> showServiceBreakdown(
  BuildContext context,
  CourierService service,
  AppState state,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder:
        (sheetContext) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .85,
          minChildSize: .4,
          maxChildSize: .95,
          builder:
              (_, controller) => ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white70,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  ServiceCard(service: service, state: state),
                ],
              ),
        ),
  );
}

class _EvidencePhoto extends StatelessWidget {
  const _EvidencePhoto({required this.service, required this.state});
  final CourierService service;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: FutureBuilder<String?>(
        future: state.repo.evidenceUrl(service.evidencePath!),
        builder: (context, snapshot) {
          final url = snapshot.data;
          if (url == null) {
            return Text(
              snapshot.connectionState == ConnectionState.done
                  ? 'No se pudo cargar la foto de la factura.'
                  : 'Cargando foto de la factura…',
              style: TextStyle(color: p.muted, fontSize: 13),
            );
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              semanticLabel: 'Foto de la factura de ${service.code}',
            ),
          );
        },
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.index,
    required this.current,
    required this.last,
    required this.service,
    required this.state,
  });
  final ServiceStep step;
  final int index;
  final int current;
  final bool last;
  final CourierService service;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final done = service.isDelivered || step.isCompleted || index < current;
    final now = !done && (step.isInProgress || index == current);
    final stepBusy = state.updatingStepKey == '${service.id}:${step.key}';
    final actionLabel = switch (step.kind) {
      'pickup' => 'Marcar recogido',
      'buy' => 'Marcar compra realizada',
      'cross' => 'Marcar cruce recogido',
      'change' => 'Marcar sencillo listo',
      _ => 'Marcar paso completado',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color:
                        done
                            ? p.success
                            : now
                            ? p.primary
                            : p.surface3,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    done ? Icons.check_rounded : stepIcon(step.kind),
                    size: 16,
                    color: done || now ? Colors.white : p.muted,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: done ? p.success : p.line,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14, top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (now)
                      Text(
                        'Ahora',
                        style: TextStyle(
                          color: p.accentText,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    Text(
                      step.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: done ? p.muted : p.ink,
                      ),
                    ),
                    if (step.detail.isNotEmpty)
                      Text(
                        step.detail,
                        style: TextStyle(
                          color: p.muted,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    if (!done && service.isActive && step.key.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed:
                              stepBusy
                                  ? null
                                  : () async {
                                    final error = await state.completeStep(
                                      service,
                                      step,
                                    );
                                    if (!context.mounted) return;
                                    if (error != null) {
                                      showMessage(context, error);
                                    }
                                  },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 5,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(stepBusy ? 'Guardando…' : actionLabel),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodesBlock extends StatelessWidget {
  const _CodesBlock({required this.service});
  final CourierService service;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final rows = <(String, String)>[
      if (service.invoiceCode != null) ('Factura', service.invoiceCode!),
      if (service.medicineValueCop != null)
        ('Valor del medicamento', formatCop(service.medicineValueCop)),
      if (service.crossCodes.isNotEmpty)
        (
          service.crossCodes.length > 1
              ? 'Códigos de cruce'
              : 'Código de cruce',
          service.crossCodes.join(', '),
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: p.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.line),
        ),
        child: Column(
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      row.$1,
                      style: TextStyle(color: p.muted, fontSize: 13),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        row.$2,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.wash,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: p.accentText),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.accentText,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
