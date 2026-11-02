import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Botón de deslizar para confirmar: evita entregar o iniciar por un toque accidental.
class SlideToConfirm extends StatefulWidget {
  const SlideToConfirm({
    required this.label,
    required this.onConfirmed,
    this.busy = false,
    this.enabled = true,
    super.key,
  });

  final String label;
  final Future<void> Function() onConfirmed;
  final bool busy;
  final bool enabled;

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> {
  static const _thumb = 52.0;
  double _dx = 0;
  bool _done = false;

  Future<void> _complete(double max) async {
    setState(() {
      _dx = max;
      _done = true;
    });
    HapticFeedback.mediumImpact();
    await widget.onConfirmed();
    if (mounted) {
      setState(() {
        _dx = 0;
        _done = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final active = widget.enabled && !widget.busy;
    return Semantics(
      button: true,
      label: '${widget.label}. Toca dos veces para confirmar.',
      onTap: active ? () => _complete(0) : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final max = constraints.maxWidth - _thumb - 8;
          final progress = max <= 0 ? 0.0 : (_dx / max).clamp(0.0, 1.0);
          return Container(
            height: 60,
            decoration: BoxDecoration(
              color: active ? p.primary : p.surface3,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Positioned.fill(
                  child: Center(
                    child: Opacity(
                      opacity: 1 - progress * .8,
                      child: Text(
                        widget.busy ? 'Guardando…' : widget.label,
                        style: TextStyle(
                          color: active ? p.onPrimary : p.muted,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 4 + _dx,
                  child: GestureDetector(
                    onHorizontalDragUpdate:
                        active && !_done
                            ? (d) => setState(
                              () => _dx = (_dx + d.delta.dx).clamp(0.0, max),
                            )
                            : null,
                    onHorizontalDragEnd:
                        active && !_done
                            ? (_) {
                              if (_dx >= max * .82) {
                                _complete(max);
                              } else {
                                setState(() => _dx = 0);
                              }
                            }
                            : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: _thumb,
                      height: _thumb,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child:
                          widget.busy
                              ? Padding(
                                padding: const EdgeInsets.all(15),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: p.primary,
                                ),
                              )
                              : Icon(
                                _done
                                    ? Icons.check_rounded
                                    : Icons.arrow_forward_rounded,
                                color: active ? Palette.royal : p.muted,
                              ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
