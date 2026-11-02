import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../alerts.dart';
import '../tones.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({required this.state, super.key});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final profile = state.profile!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Text('Mi cuenta', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 14),
        SurfaceCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: p.primary,
                child: Text(
                  initialsOf(profile.fullName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      [profile.phone, profile.vehicle, profile.zone]
                          .whereType<String>()
                          .where((v) => v.isNotEmpty)
                          .join(' · ')
                          .ifEmpty(roleLabels[profile.role] ?? 'Domiciliario'),
                      style: TextStyle(color: p.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (state.isAdmin) ...[
          const SizedBox(height: 18),
          const SectionTitle(
            'Acceso administrativo',
            subtitle: 'Gestiona las cuentas desde este celular',
          ),
          const SurfaceCard(
            child: Text(
              'Desde la pestaña Usuarios puedes crear cuentas, consultar sus roles y activar o desactivar el acceso.',
              style: TextStyle(height: 1.45),
            ),
          ),
        ],
        const SizedBox(height: 18),
        const SectionTitle('Alertas y sonido'),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.notifications_active_outlined,
                  color: p.accentText,
                ),
                title: const Text(
                  'Avisos con la app cerrada',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  state.pushStatus,
                  style: TextStyle(color: p.muted, fontSize: 12.5),
                ),
                trailing: Pill(
                  label: state.alerts.pushAvailable ? 'Activos' : 'Pendiente',
                  color: state.alerts.pushAvailable ? p.success : p.warning,
                  background:
                      state.alerts.pushAvailable
                          ? p.successWash
                          : p.warningWash,
                ),
              ),
              Divider(height: 1, color: p.line),
              SwitchListTile(
                secondary: Icon(Icons.volume_up_outlined, color: p.accentText),
                title: const Text(
                  'Sonido de alerta',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Suena aunque tengas la app abierta',
                  style: TextStyle(color: p.muted, fontSize: 12.5),
                ),
                value: state.soundEnabled,
                onChanged: state.setSound,
              ),
              for (final tone in AlertTone.values) ...[
                Divider(height: 1, color: p.line),
                ListTile(
                  leading: Icon(Icons.music_note_outlined, color: p.accentText),
                  title: Text(
                    tone.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    state.alerts.labelOf(tone),
                    style: TextStyle(color: p.muted, fontSize: 12.5),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showTonePicker(context, state, tone),
                ),
              ],
              if (!kIsWeb) ...[
                Divider(height: 1, color: p.line),
                SwitchListTile(
                  secondary: Icon(Icons.vibration, color: p.accentText),
                  title: const Text(
                    'Vibrar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  value: state.vibrationEnabled,
                  onChanged: state.setVibration,
                ),
              ],
              Divider(height: 1, color: p.line),
              Padding(
                padding: const EdgeInsets.all(12),
                child: OutlinedButton.icon(
                  onPressed: state.alerts.playAlert,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Probar el sonido'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (kIsWeb) ...[
          const SizedBox(height: 10),
          Text(
            'En iPhone, instala la app desde Safari con "Compartir → Agregar a inicio" para recibir avisos. El iPhone no permite vibrar desde una web.',
            style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.4),
          ),
        ],
        const SizedBox(height: 18),
        const SectionTitle('Tema'),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.light,
              label: Text('Claro'),
              icon: Icon(Icons.light_mode_outlined),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              label: Text('Oscuro'),
              icon: Icon(Icons.dark_mode_outlined),
            ),
            ButtonSegment(
              value: ThemeMode.system,
              label: Text('Automático'),
              icon: Icon(Icons.brightness_auto_outlined),
            ),
          ],
          selected: {state.themeMode},
          onSelectionChanged: (v) => state.setTheme(v.first),
          showSelectedIcon: false,
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder:
                  (c) => AlertDialog(
                    title: const Text('¿Cerrar sesión?'),
                    content: const Text(
                      'Dejarás de recibir los servicios en este celular hasta que vuelvas a entrar.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44),
                        ),
                        child: const Text('Cerrar sesión'),
                      ),
                    ],
                  ),
            );
            if (ok == true) await state.signOut();
          },
          icon: Icon(Icons.logout, color: p.danger),
          label: Text('Cerrar sesión', style: TextStyle(color: p.danger)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'Mensajeros Montería 911 · versión 1.1.4',
            style: TextStyle(color: p.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// Lista por género: tocar un tono lo hace sonar y lo deja elegido.
Future<void> _showTonePicker(
  BuildContext context,
  AppState state,
  AlertTone tone,
) {
  final p = context.palette;
  final genres = tones.map((item) => item.genre).toSet().toList();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder:
        (sheet) => SizedBox(
          height: MediaQuery.of(sheet).size.height * .78,
          child: StatefulBuilder(
            builder: (sheet, setSheet) {
              final current = state.alerts.soundOf(tone);
              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                    child: Text(
                      tone.label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  for (final genre in genres) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                      child: Text(
                        genre,
                        style: TextStyle(
                          color: p.accentText,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    for (final item in tones.where((t) => t.genre == genre))
                      ListTile(
                        dense: true,
                        minTileHeight: 48,
                        title: Text(item.label),
                        trailing:
                            item.id == current
                                ? Icon(Icons.check_circle, color: p.accentText)
                                : const Icon(Icons.play_arrow_rounded),
                        onTap: () async {
                          unawaited(state.alerts.previewSound(item.id));
                          await state.chooseTone(tone, item.id);
                          setSheet(() {});
                        },
                      ),
                  ],
                ],
              );
            },
          ),
        ),
  );
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
