import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/service_card.dart';
import '../widgets/slide_to_confirm.dart';

/// Hoja que sube cuando la central asigna un servicio.
Future<void> showIncomingSheet(
  BuildContext context,
  AppState state,
  CourierService service,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => _IncomingBody(state: state, service: service),
  ).whenComplete(state.dismissIncoming);
}

class _IncomingBody extends StatelessWidget {
  const _IncomingBody({required this.state, required this.service});
  final AppState state;
  final CourierService service;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final origin = state.branch(service.branchCode);
    final cross =
        service.crossBranchCode == null
            ? null
            : state.branch(service.crossBranchCode!);
    final steps = service.steps(origin, cross);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: p.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.notifications_active,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nuevo servicio asignado',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${service.code} · desde ${origin.name}',
                      style: TextStyle(color: p.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  service.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: p.successWash,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      formatCop(service.feeCop),
                      style: TextStyle(
                        color: p.success,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'ganas',
                      style: TextStyle(
                        color: p.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < steps.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.surface2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.line),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: p.primary,
                    child: Icon(
                      stepIcon(steps[i].kind),
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (steps[i].detail.isNotEmpty)
                          Text(
                            steps[i].detail,
                            style: TextStyle(color: p.muted, fontSize: 12.5),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          SlideToConfirm(
            label: 'Desliza para marcar entregado',
            busy: state.updatingId == service.id,
            onConfirmed: () async {
              final error = await state.deliverService(service);
              if (!context.mounted) return;
              if (error != null) {
                showMessage(context, error);
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Verlo después'),
          ),
        ],
      ),
    );
  }
}
