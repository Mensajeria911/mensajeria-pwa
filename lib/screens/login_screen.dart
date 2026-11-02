import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

// Colores fijos del ingreso del boceto aprobado (DeepSeek): no cambian con el tema.
const _night = Palette.navy;
const _sky = Color(0xFF5AA9EC);
const _cream = Color(0xFFFBF7EB);
const _copy = Color(0xFFB3BDCC);
const _card = Color(0xFFEFF2F7);
const _cardInk = Color(0xFF1E293B);
const _border = Color(0xFFC8D0DB);
const _note = Color(0xFF4E6079);
const _error = Color(0xFFA9222B);
const _muted = Color(0xFF64748B);

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.state, super.key});
  final AppState state;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  bool _hidden = true;
  String _role = 'courier';
  String? _shownError;

  // Entrada escalonada, ciclo continuo del fondo (moto, ruta, círculos) y sacudida del error.
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();
  late final _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  // Partículas del fondo: van más despacio que el resto.
  late final _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _userFocus.addListener(_refresh);
    _passFocus.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Quien desactiva las animaciones del celular ve el ingreso quieto.
    if (MediaQuery.of(context).disableAnimations) {
      _loop.stop();
      _drift.stop();
      _intro.value = 1;
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    _shake.dispose();
    _drift.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_form.currentState?.validate() ?? false) {
      widget.state.signIn(_username.text, _password.text, expectedRole: _role);
    } else {
      _shake.forward(from: 0);
    }
  }

  /// Aparece desde abajo con un desvanecido, en su turno.
  Widget _enter(double start, Widget child) {
    final curve = CurvedAnimation(
      parent: _intro,
      curve: Interval(
        start,
        math.min(start + .55, 1),
        curve: Curves.easeOutCubic,
      ),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, .14),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final display = Theme.of(context).textTheme.headlineLarge;
    if (s.error != _shownError) {
      _shownError = s.error;
      if (s.error != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _shake.forward(from: 0),
        );
      }
    }
    final titleStyle = display?.copyWith(
      color: _cream,
      fontSize: 36,
      height: 1.02,
      letterSpacing: -1.4,
      fontWeight: FontWeight.w800,
    );
    return Scaffold(
      backgroundColor: _night,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _BackdropPainter(_drift)),
            ),
          ),
          SafeArea(
            // Ocupa todo el alto: lo que sobra se lo lleva la escena de entrega de abajo.
            // Con el teclado abierto se puede desplazar.
            child: LayoutBuilder(
              builder:
                  (context, viewport) => SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: math.max(20, (viewport.maxWidth - 440) / 2),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: viewport.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 10),
                            _enter(
                              0,
                              Row(
                                children: [
                                  // El logo flota suave.
                                  AnimatedBuilder(
                                    animation: _loop,
                                    builder:
                                        (context, child) => Transform.translate(
                                          offset: Offset(
                                            0,
                                            math.sin(
                                                  _loop.value * math.pi * 4,
                                                ) *
                                                2.5,
                                          ),
                                          child: child,
                                        ),
                                    child: const BrandMark(size: 38),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Mensajeros Montería 911',
                                      style: TextStyle(
                                        color: Color(0xFFC2CBD7),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                  _LiveBadge(animation: _loop),
                                ],
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(height: 16),
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  right: -90,
                                  top: -40,
                                  child: _Rings(animation: _loop),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _enter(
                                      .1,
                                      Row(
                                        children: [
                                          // La línea del encabezado se dibuja al entrar.
                                          AnimatedBuilder(
                                            animation: _intro,
                                            builder:
                                                (context, _) => Container(
                                                  width:
                                                      28 *
                                                      Curves.easeOut.transform(
                                                        _intro.value,
                                                      ),
                                                  height: 1.5,
                                                  color: _sky,
                                                ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Operación farmanorte',
                                            style: TextStyle(
                                              color: Color(0xFFBFC8D5),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    // El título entra palabra por palabra y un brillo recorre "aquí."
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 2,
                                      children: [
                                        for (final (i, word)
                                            in const [
                                              'Tu',
                                              'turno',
                                              'empieza',
                                              'aquí.',
                                            ].indexed)
                                          _enter(
                                            .14 + i * .07,
                                            i == 3
                                                ? _Shimmer(
                                                  animation: _loop,
                                                  child: Text(
                                                    word,
                                                    style: titleStyle,
                                                  ),
                                                )
                                                : Text(word, style: titleStyle),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _enter(
                                      .38,
                                      const Text(
                                        'Consulta tus domicilios, habla con la farmacia y cierra cada entrega desde un solo lugar.',
                                        style: TextStyle(
                                          color: _copy,
                                          fontSize: 14,
                                          height: 1.55,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Spacer(),
                            const SizedBox(height: 16),
                            _enter(
                              .44,
                              AnimatedBuilder(
                                animation: _shake,
                                builder: (context, child) {
                                  final t = _shake.value;
                                  return Transform.translate(
                                    offset: Offset(
                                      math.sin(t * math.pi * 6) * 9 * (1 - t),
                                      0,
                                    ),
                                    child: child,
                                  );
                                },
                                child: _buildCard(context, s),
                              ),
                            ),
                            Expanded(
                              // Peso alto: así casi todo el espacio libre va a la escena y no a los huecos.
                              flex: 6,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 124,
                                ),
                                child: _enter(
                                  .58,
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: _DeliveryScene(animation: _loop),
                                  ),
                                ),
                              ),
                            ),
                            _enter(
                              .66,
                              const Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: 'Mensajería para '),
                                    TextSpan(
                                      text: 'farmanorte',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    TextSpan(text: ' · Operación Montería'),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFFA1AEC0),
                                  fontSize: 12,
                                  height: 1.45,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, AppState s) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(21),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 38,
            offset: Offset(0, 20),
            spreadRadius: -25,
          ),
        ],
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ingresa a tu turno',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: _cardInk, fontSize: 17),
            ),
            const SizedBox(height: 12),
            _RoleSwitch(
              value: _role,
              onChanged: (value) => setState(() => _role = value),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child:
                  s.error == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDE9E8),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: _error,
                                size: 17,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  s.error!,
                                  style: const TextStyle(
                                    color: _error,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _username,
              focusNode: _userFocus,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _passFocus.requestFocus(),
              style: const TextStyle(
                color: _cardInk,
                fontWeight: FontWeight.w600,
                fontSize: 15.5,
              ),
              decoration: _inputDecoration(
                hint: 'Usuario',
                icon: _FieldIcon(
                  icon: Icons.person_outline,
                  active: _userFocus.hasFocus,
                ),
              ),
              validator:
                  (v) =>
                      (v == null || v.trim().length < 3)
                          ? 'Escribe tu usuario.'
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              focusNode: _passFocus,
              obscureText: _hidden,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              style: const TextStyle(
                color: _cardInk,
                fontWeight: FontWeight.w600,
                fontSize: 15.5,
              ),
              decoration: _inputDecoration(
                hint: 'Contraseña',
                // El candado se abre cuando se muestra la contraseña.
                icon: _FieldIcon(
                  icon: _hidden ? Icons.lock_outline : Icons.lock_open_outlined,
                  active: _passFocus.hasFocus,
                ),
                suffix: IconButton(
                  tooltip:
                      _hidden ? 'Mostrar contraseña' : 'Ocultar contraseña',
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder:
                        (child, a) => RotationTransition(
                          turns: Tween(begin: .75, end: 1.0).animate(a),
                          child: FadeTransition(opacity: a, child: child),
                        ),
                    child: Icon(
                      _hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      key: ValueKey(_hidden),
                      color: _note,
                    ),
                  ),
                  onPressed: () => setState(() => _hidden = !_hidden),
                ),
              ),
              validator:
                  (v) =>
                      (v == null || v.length < 6)
                          ? 'La contraseña tiene mínimo 6 caracteres.'
                          : null,
            ),
            const SizedBox(height: 10),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 15, color: _note),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Tu sesión queda abierta en este celular hasta que cierres sesión.',
                    style: TextStyle(color: _note, fontSize: 12, height: 1.42),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: s.busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: Palette.royal,
                  disabledBackgroundColor: Palette.royal.withValues(alpha: .75),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child:
                      s.busy
                          ? const SizedBox.square(
                            key: ValueKey('cargando'),
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                          : Row(
                            key: const ValueKey('entrar'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Entrar'),
                              const SizedBox(width: 8),
                              // La flecha empuja hacia adelante, como invitando a entrar.
                              AnimatedBuilder(
                                animation: _loop,
                                builder:
                                    (context, child) => Transform.translate(
                                      offset: Offset(
                                        (math.sin(
                                                  _loop.value * math.pi * 2 * 4,
                                                ) +
                                                1) *
                                            2.5,
                                        0,
                                      ),
                                      child: child,
                                    ),
                                child: const Icon(
                                  Icons.arrow_forward,
                                  size: 19,
                                ),
                              ),
                            ],
                          ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed:
                  s.busy
                      ? null
                      : () =>
                          widget.state.signInWithBiometric(expectedRole: _role),
              icon: const Icon(Icons.fingerprint),
              label: const Text('Entrar con huella'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Palette.royal,
                side: const BorderSide(color: Color(0xFFB9C8E2)),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              s.biometricReady
                  ? 'Huella activada en este dispositivo.'
                  : 'Entra una vez con usuario y clave para activar la huella.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _note, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required Widget icon,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _muted, fontWeight: FontWeight.w500),
      filled: true,
      fillColor: const Color(0xFFF8FAFD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 17),
      prefixIcon: Padding(padding: const EdgeInsets.only(left: 6), child: icon),
      suffixIcon: suffix,
      enabledBorder: border(_border),
      focusedBorder: border(const Color(0xFF1D4F95), 1.6),
      errorBorder: border(_error),
      focusedErrorBorder: border(_error, 1.6),
      errorStyle: const TextStyle(color: _error, fontSize: 11.5),
    );
  }
}

/// Ícono del campo: crece y salta un poco al tocar el campo.
class _FieldIcon extends StatelessWidget {
  const _FieldIcon({required this.icon, required this.active});
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: active ? 1.18 : 1,
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOutBack,
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
      child: Icon(
        icon,
        key: ValueKey(icon),
        color: active ? Palette.royal : const Color(0xFF3B5B9A),
      ),
    ),
  );
}

/// Selector del tipo de acceso que aparece en el diseño de referencia.
/// La selección se envía a AppState para que Supabase valide el rol real de
/// la cuenta y no se limite a cambiar una etiqueta visual.
class _RoleSwitch extends StatelessWidget {
  const _RoleSwitch({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(String role, String label, IconData icon) {
      final selected = value == role;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(role),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    key: ValueKey('$role-$selected'),
                    tween: Tween(begin: selected ? .6 : 1, end: 1),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.elasticOut,
                    builder:
                        (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                    child: Icon(
                      icon,
                      size: 19,
                      color: selected ? Palette.royal : _muted,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        color: selected ? Palette.royal : _muted,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE6EBF3),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFD5DDE8)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              alignment:
                  value == 'courier'
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: FractionallySizedBox(
                widthFactor: .5,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F0B2869),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              option('courier', 'Domiciliario', Icons.two_wheeler),
              option(
                'admin',
                'Administrador',
                Icons.admin_panel_settings_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Punto verde que late junto a la ciudad de operación.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: _sky.withValues(alpha: .22)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 12,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final p = (animation.value * 4) % 1;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: 1 + p * 1.2,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(
                          0xFF4ADE80,
                        ).withValues(alpha: .5 * (1 - p)),
                      ),
                    ),
                  ),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF4ADE80),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'Montería',
          style: TextStyle(
            color: Color(0xFFC2CBD7),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// Un brillo azul cruza la palabra de vez en cuando.
class _Shimmer extends StatelessWidget {
  const _Shimmer({required this.animation, required this.child});
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final x = -3 + animation.value * 6;
      return ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback:
            (rect) => LinearGradient(
              begin: Alignment(x - 1, 0),
              end: Alignment(x + 1, 0),
              colors: const [_cream, _sky, _cream],
            ).createShader(rect),
        child: child,
      );
    },
    child: child,
  );
}

/// Círculos concéntricos detrás del título: respiran y sueltan una onda, como un radar.
class _Rings extends StatelessWidget {
  const _Rings({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      size: const Size(240, 240),
      painter: _RingsPainter(animation),
    ),
  );
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.animation) : super(repaint: animation);
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final c = size.center(Offset.zero);
    final breath = 1 + math.sin(t * math.pi * 2) * .05;
    final fill = Paint()..color = _sky.withValues(alpha: .035);
    canvas.drawCircle(c, 120 * breath, fill);
    canvas.drawCircle(c, 100 * breath, fill);
    canvas.drawCircle(
      c,
      78 * breath,
      Paint()
        ..color = _sky.withValues(alpha: .28)
        ..style = PaintingStyle.stroke,
    );
    // Onda que sale del centro
    for (final offset in const [0.0, .5]) {
      final p = (t * 2 + offset) % 1;
      canvas.drawCircle(
        c,
        30 + p * 90,
        Paint()
          ..color = _sky.withValues(alpha: .22 * (1 - p))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter oldDelegate) => false;
}

/// Fondo de toda la pantalla: calles tenues de un mapa y partículas que suben.
class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.animation) : super(repaint: animation);
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final w = size.width;
    final h = size.height;
    final street =
        Paint()
          ..color = _sky.withValues(alpha: .045)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(-20, h * .2)
        ..quadraticBezierTo(w * .5, h * .32, w + 20, h * .14),
      street..strokeWidth = 16,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * .12, -20)
        ..quadraticBezierTo(w * .02, h * .5, w * .3, h + 20),
      street..strokeWidth = 12,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * .88, -20)
        ..quadraticBezierTo(w * .98, h * .55, w * .72, h + 20),
      street..strokeWidth = 10,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-20, h * .82)
        ..quadraticBezierTo(w * .45, h * .7, w + 20, h * .9),
      street..strokeWidth = 14,
    );

    final dot = Paint();
    for (var i = 0; i < 18; i++) {
      final seed = (i * .618034) % 1;
      final y = h + 20 - ((t + i / 18) % 1) * (h + 40);
      final x = seed * w + math.sin((t * 3 + seed) * math.pi * 2) * 14;
      dot.color = _sky.withValues(alpha: .08 + (i % 4) * .05);
      canvas.drawCircle(Offset(x, y), 1.2 + (i % 3) * .8, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) => false;
}

/// Escena de abajo: un servicio de la farmacia al cliente, con su estado en vivo.
class _DeliveryScene extends StatelessWidget {
  const _DeliveryScene({required this.animation});
  final Animation<double> animation;

  static const _stages = [
    (Icons.assignment_turned_in_outlined, 'Servicio asignado'),
    (Icons.two_wheeler, 'En camino'),
    (Icons.check_circle_outline, 'Entregado'),
  ];

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Column(
      children: [
        AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = animation.value;
            final (icon, label) =
                _stages[t < _DeliveryPainter.depart
                    ? 0
                    : t < _DeliveryPainter.arrive
                    ? 1
                    : 2];
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              transitionBuilder:
                  (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, .5),
                        end: Offset.zero,
                      ).animate(a),
                      child: child,
                    ),
                  ),
              child: Container(
                key: ValueKey(label),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _sky.withValues(alpha: .25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: .4, end: 1),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      builder:
                          (context, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                      child: Icon(
                        icon,
                        size: 16,
                        color:
                            label == 'Entregado'
                                ? const Color(0xFF4ADE80)
                                : _sky,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      label,
                      style: const TextStyle(
                        color: _cream,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _DeliveryPainter(animation),
          ),
        ),
      ],
    ),
  );
}

class _DeliveryPainter extends CustomPainter {
  _DeliveryPainter(this.animation) : super(repaint: animation);
  final Animation<double> animation;

  // Momentos del ciclo: sale de la farmacia y llega al cliente.
  static const depart = .18;
  static const arrive = .78;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final w = size.width;
    final h = size.height;
    final from = Offset(34, h * .56);
    final to = Offset(w - 34, h * .3);
    final path =
        Path()
          ..moveTo(from.dx, from.dy)
          ..cubicTo(w * .38, h * .95, w * .58, h * -.1, to.dx, to.dy);
    final metric = path.computeMetrics().first;
    final done =
        metric.length *
        Curves.easeInOutCubic.transform(
          ((t - depart) / (arrive - depart)).clamp(0.0, 1.0),
        );

    // Lo que falta: puntos que avanzan. Lo recorrido: trazo sólido.
    final dash =
        Paint()
          ..color = _sky.withValues(alpha: .3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
    for (double d = (t * 90) % 12; d < metric.length; d += 12) {
      if (d > done) canvas.drawPath(metric.extractPath(d, d + 3), dash);
    }
    if (done > 0) {
      canvas.drawPath(
        metric.extractPath(0, done),
        Paint()
          ..shader = LinearGradient(
            colors: [_sky.withValues(alpha: .1), _sky.withValues(alpha: .85)],
          ).createShader(Rect.fromPoints(from, to))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    _pin(
      canvas,
      from,
      Icons.local_pharmacy_outlined,
      'Farmacia',
      t < depart ? t / depart : null,
    );
    final arrived = t >= arrive;
    _pin(
      canvas,
      to,
      Icons.home_outlined,
      'Cliente',
      arrived ? (t - arrive) / (1 - arrive) : null,
    );

    // Chulo verde al entregar
    if (arrived) {
      final pop = Curves.elasticOut.transform(
        ((t - arrive) / .14).clamp(0.0, 1.0),
      );
      final badge = to + const Offset(14, -14);
      canvas.drawCircle(
        badge,
        9 * pop,
        Paint()..color = const Color(0xFF22C55E),
      );
      if (pop > .2) _icon(canvas, Icons.check, badge, 13 * pop, Colors.white);
    }

    // La moto: aparece en la farmacia, recorre la ruta saltando un poco y se va al llegar.
    final opacity =
        t < .06
            ? t / .06
            : t > .9
            ? (1 - t) / .1
            : 1.0;
    final tangent = metric.getTangentForOffset(math.max(done, 0.1));
    if (tangent != null && opacity > 0) {
      final moving = t > depart && t < arrive;
      final hop = moving ? math.sin(t * math.pi * 30).abs() * -2.5 : 0.0;
      canvas.save();
      canvas.translate(tangent.position.dx, tangent.position.dy);
      canvas.rotate(-tangent.angle * .6);
      canvas.drawCircle(
        const Offset(0, -12),
        17,
        Paint()
          ..color = _sky.withValues(alpha: .16 * opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      _icon(
        canvas,
        Icons.two_wheeler,
        Offset(0, -13 + hop),
        28,
        _cream.withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  void _pin(
    Canvas canvas,
    Offset at,
    IconData icon,
    String label,
    double? pulse,
  ) {
    if (pulse != null) {
      canvas.drawCircle(
        at,
        18 + pulse * 26,
        Paint()
          ..color = _sky.withValues(alpha: .45 * (1 - pulse))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
    canvas.drawCircle(at, 18, Paint()..color = const Color(0xFF1B3A7A));
    canvas.drawCircle(
      at,
      18,
      Paint()
        ..color = _sky.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    _icon(canvas, icon, at, 19, _cream);
    final text = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFF9FB0C8),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    )..layout();
    text.paint(canvas, at + Offset(-text.width / 2, 23));
  }

  void _icon(
    Canvas canvas,
    IconData icon,
    Offset center,
    double size,
    Color color,
  ) {
    final glyph = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size,
          color: color,
        ),
      ),
    )..layout();
    glyph.paint(canvas, center - Offset(glyph.width / 2, glyph.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DeliveryPainter oldDelegate) => false;
}

class BlockedScreen extends StatelessWidget {
  const BlockedScreen({required this.state, super.key});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(size: 72),
                const SizedBox(height: 22),
                Text(
                  'Acceso no disponible',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  state.blockedReason ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.muted, height: 1.45),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: state.signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
