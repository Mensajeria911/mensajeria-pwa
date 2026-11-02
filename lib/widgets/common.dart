import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';

import '../theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 40, super.key});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: EdgeInsets.all(size * .08),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(size * .3),
      border: Border.all(color: const Color(0xFFD6E2F5)),
    ),
    child: Image.asset(
      'assets/images/marca-911.png',
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Logo de Mensajeros Montería 911',
    ),
  );
}

class Pill extends StatelessWidget {
  const Pill({
    required this.label,
    this.color,
    this.background,
    this.icon,
    super.key,
  });
  final String label;
  final Color? color;
  final Color? background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = color ?? p.accentText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background ?? p.wash,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    super.key,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor ?? p.line),
        boxShadow:
            Theme.of(context).brightness == Brightness.light
                ? [
                  const BoxShadow(
                    color: Color(0x140B2869),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ]
                : null,
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.trailing, this.subtitle, super.key});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 19),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(color: p.muted, fontSize: 12.5),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: p.wash, shape: BoxShape.circle),
            child: Icon(icon, color: p.accentText),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.muted, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

Future<void> openExternal(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No se pudo abrir en este celular.')),
    );
  }
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Recarga la pantalla cuando llega un cambio en vivo.
mixin LiveReload<T extends StatefulWidget> on State<T> {
  AppState get liveState;
  Future<void> reloadLive();
  int _seenRevision = 0;

  void _onLiveChange() {
    if (_seenRevision == liveState.liveRevision) return;
    _seenRevision = liveState.liveRevision;
    unawaited(reloadLive());
  }

  @override
  void initState() {
    super.initState();
    _seenRevision = liveState.liveRevision;
    liveState.addListener(_onLiveChange);
  }

  @override
  void dispose() {
    liveState.removeListener(_onLiveChange);
    super.dispose();
  }
}
