import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../repository.dart';
import '../theme.dart';
import '../widgets/common.dart';

const _creatable = [
  (
    role: 'courier',
    label: 'Domiciliario',
    icon: Icons.two_wheeler,
    hint: 'Recibe y entrega servicios',
  ),
  (
    role: 'pharmacy',
    label: 'Farmacia',
    icon: Icons.local_pharmacy_outlined,
    hint: 'Publica servicios de su sede',
  ),
  (
    role: 'central',
    label: 'Central',
    icon: Icons.support_agent_outlined,
    hint: 'Despacha y asigna servicios',
  ),
  (
    role: 'admin',
    label: 'Administrador',
    icon: Icons.admin_panel_settings_outlined,
    hint: 'Acceso a todo',
  ),
];

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({required this.state, super.key});
  final AppState state;

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> with LiveReload<AdminUsersScreen> {
  @override
  AppState get liveState => widget.state;

  @override
  Future<void> reloadLive() => _load();

  List<StaffMember>? _people;
  String? _error;
  String _filter = 'courier';
  String? _togglingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final people = await widget.state.repo.getPeople();
      if (mounted) {
        setState(() {
          _people = people;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _toggle(StaffMember person) async {
    setState(() => _togglingId = person.id);
    try {
      await widget.state.repo.setPersonActive(person.id, !person.active);
      await _load();
      if (mounted) {
        showMessage(
          context,
          '${person.fullName} ${person.active ? 'desactivado' : 'activado'}.',
        );
      }
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _togglingId = null);
    }
  }

  Future<void> _revoke(StaffMember person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('¿Eliminar este acceso?'),
            content: Text(
              'Se quitará el acceso de ${person.fullName}, pero se conservarán sus domicilios y su historial.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar acceso'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    setState(() => _togglingId = person.id);
    try {
      await widget.state.repo.setPersonActive(person.id, false);
      await _load();
      if (mounted) {
        showMessage(context, 'Acceso eliminado. El historial se conserva.');
      }
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _togglingId = null);
    }
  }

  Future<void> _create(String role) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _CreateUserSheet(state: widget.state, role: role),
    );
    if (created == true) {
      setState(() => _filter = role);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final people =
        (_people ?? const <StaffMember>[])
            .where((person) => _filter == 'all' || person.role == _filter)
            .toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Row(
            children: [
              const BrandMark(size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Administración',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Crea cuentas y activa o desactiva el acceso.',
            style: TextStyle(color: p.muted),
          ),
          const SizedBox(height: 18),
          const SectionTitle('Crear usuario'),
          LayoutBuilder(
            builder:
                (context, constraints) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in _creatable)
                      SizedBox(
                        width: (constraints.maxWidth - 8) / 2,
                        child: _RoleTile(
                          icon: item.icon,
                          label: item.label,
                          hint: item.hint,
                          onTap: () => _create(item.role),
                        ),
                      ),
                  ],
                ),
          ),
          const SizedBox(height: 22),
          const SectionTitle('Cuentas'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in const [
                  ('courier', 'Domiciliarios'),
                  ('pharmacy', 'Farmacias'),
                  ('central', 'Central'),
                  ('admin', 'Admin'),
                  ('all', 'Todos'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.$2),
                      selected: _filter == entry.$1,
                      onSelected: (_) => setState(() => _filter = entry.$1),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            EmptyState(
              icon: Icons.wifi_off,
              title: 'No se pudo cargar',
              message: _error!,
            )
          else if (_people == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (people.isEmpty)
            const EmptyState(
              icon: Icons.group_outlined,
              title: 'Sin cuentas en este grupo',
              message: 'Créalas con los recuadros de arriba.',
            )
          else
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < people.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: p.line),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: people[i].active ? p.wash : p.surface3,
                        child: Text(
                          initialsOf(people[i].fullName),
                          style: TextStyle(
                            color: people[i].active ? p.accentText : p.muted,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      title: Text(
                        people[i].fullName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: people[i].active ? null : p.muted,
                        ),
                      ),
                      subtitle: Text(
                        [
                              roleLabels[people[i].role] ?? people[i].role,
                              people[i].branchName,
                              people[i].zone,
                              people[i].phone,
                            ]
                            .whereType<String>()
                            .where((v) => v.isNotEmpty)
                            .join(' · '),
                        style: TextStyle(color: p.muted, fontSize: 12.5),
                      ),
                      trailing:
                          _togglingId == people[i].id
                              ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                ),
                              )
                              : people[i].id == widget.state.profile?.id
                              ? const Pill(label: 'Tú')
                              : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: people[i].active,
                                    onChanged: (_) => _toggle(people[i]),
                                  ),
                                  IconButton(
                                    tooltip:
                                        people[i].active
                                            ? 'Eliminar acceso'
                                            : 'Acceso eliminado',
                                    onPressed:
                                        people[i].active
                                            ? () => _revoke(people[i])
                                            : null,
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 128),
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.lineStrong),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: p.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                hint,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(color: p.muted, fontSize: 10.5, height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateUserSheet extends StatefulWidget {
  const _CreateUserSheet({required this.state, required this.role});

  final AppState state;
  final String role;

  @override
  State<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends State<_CreateUserSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  String? _branchCode;
  bool _busy = false;
  bool _hidden = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _password.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.state.repo.createUser(
        username: _username.text,
        password: _password.text,
        fullName: _name.text,
        role: widget.role,
        branchCode: widget.role == 'pharmacy' ? _branchCode : null,
        phone: _phone.text.replaceAll(RegExp(r'\D'), ''),
      );
      if (!mounted) return;
      showMessage(
        context,
        'Cuenta creada. Usuario: ${normalizeUsername(_username.text)}.',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final label = roleLabels[widget.role] ?? widget.role;
    final branches =
        widget.state.branches.values.where((b) => b.active).toList()
          ..sort((a, b) => a.code.compareTo(b.code));
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _form,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Nuevo ${label.toLowerCase()}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Entrará con el usuario y la clave que escribas aquí.',
              style: TextStyle(color: p.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.dangerWash,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: p.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText:
                    widget.role == 'pharmacy'
                        ? 'Nombre (ej. farmanorte 310)'
                        : 'Nombre completo',
              ),
              validator:
                  (v) =>
                      (v == null || v.trim().length < 3)
                          ? 'Escribe el nombre.'
                          : null,
            ),
            const SizedBox(height: 12),
            if (widget.role == 'pharmacy') ...[
              DropdownButtonFormField<String>(
                initialValue: _branchCode,
                decoration: const InputDecoration(labelText: 'Sede'),
                items: [
                  for (final branch in branches)
                    DropdownMenuItem(
                      value: branch.code,
                      child: Text('${branch.name} · FN ${branch.code}'),
                    ),
                ],
                onChanged:
                    (value) => setState(() {
                      _branchCode = value;
                      if (value != null && _username.text.isEmpty) {
                        _username.text = 'sede$value';
                      }
                    }),
                validator: (v) => v == null ? 'Elige la sede.' : null,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _username,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Usuario',
                helperText: 'Letras, números, punto o guion.',
              ),
              validator:
                  (v) =>
                      RegExp(
                            r'^[a-z0-9._-]{3,32}$',
                          ).hasMatch((v ?? '').trim().toLowerCase())
                          ? null
                          : 'Entre 3 y 32 caracteres válidos.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: _hidden,
              decoration: InputDecoration(
                labelText: 'Clave',
                suffixIcon: IconButton(
                  tooltip: _hidden ? 'Mostrar clave' : 'Ocultar clave',
                  icon: Icon(
                    _hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _hidden = !_hidden),
                ),
              ),
              validator:
                  (v) =>
                      (v == null || v.length < 8)
                          ? 'Mínimo 8 caracteres.'
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Celular (opcional)',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child:
                  _busy
                      ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                      : Text('Crear ${label.toLowerCase()}'),
            ),
          ],
        ),
      ),
    );
  }
}
