import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colores del logo de Mensajeros Montería 911 y del boceto aprobado.
class Palette {
  const Palette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.ink,
    required this.ink2,
    required this.muted,
    required this.line,
    required this.lineStrong,
    required this.primary,
    required this.primaryDeep,
    required this.onPrimary,
    required this.accentText,
    required this.wash,
    required this.hero,
    required this.success,
    required this.successWash,
    required this.warning,
    required this.warningWash,
    required this.danger,
    required this.dangerWash,
    required this.nav,
  });

  final Color bg,
      surface,
      surface2,
      surface3,
      ink,
      ink2,
      muted,
      line,
      lineStrong;
  final Color primary, primaryDeep, onPrimary, accentText, wash, hero;
  final Color success,
      successWash,
      warning,
      warningWash,
      danger,
      dangerWash,
      nav;

  static const navy = Color(0xFF0B2869);
  static const royal = Color(0xFF0B3FA0);
  static const sky = Color(0xFF1D93DE);

  static const light = Palette(
    bg: Color(0xFFF1F5F9),
    surface: Colors.white,
    surface2: Color(0xFFF8FAFC),
    surface3: Color(0xFFEEF2F6),
    ink: navy,
    ink2: Color(0xFF1E293B),
    muted: Color(0xFF475569),
    line: Color(0xFFE2E8F0),
    lineStrong: Color(0xFFCBD5E1),
    primary: royal,
    primaryDeep: navy,
    onPrimary: Colors.white,
    accentText: royal,
    wash: Color(0xFFE6EEFB),
    hero: royal,
    success: Color(0xFF15803D),
    successWash: Color(0xFFE8F5EC),
    warning: Color(0xFF7C5200),
    warningWash: Color(0xFFFFF3CF),
    danger: Color(0xFFB4232B),
    dangerWash: Color(0xFFFDE9E8),
    nav: Colors.white,
  );

  static const dark = Palette(
    bg: Color(0xFF020617),
    surface: Color(0xFF0F172A),
    surface2: Color(0xFF162033),
    surface3: Color(0xFF1E293B),
    ink: Color(0xFFF1F5F9),
    ink2: Color(0xFFCBD5E1),
    muted: Color(0xFF94A3B8),
    line: Color(0xFF1E293B),
    lineStrong: Color(0xFF334155),
    primary: Color(0xFF1F56C4),
    primaryDeep: Color(0xFF0B3FA0),
    onPrimary: Colors.white,
    accentText: Color(0xFF5AA9EC),
    wash: Color(0xFF10264D),
    hero: Color(0xFF1F56C4),
    success: Color(0xFF4ADE80),
    successWash: Color(0xFF14321F),
    warning: Color(0xFFF5CD7D),
    warningWash: Color(0xFF352C18),
    danger: Color(0xFFFF999D),
    dangerWash: Color(0xFF3A2022),
    nav: Color(0xFF0B1222),
  );
}

extension PaletteContext on BuildContext {
  Palette get palette =>
      Theme.of(this).brightness == Brightness.dark
          ? Palette.dark
          : Palette.light;
}

/// Color propio de cada tipo de servicio (igual que en el boceto).
Color serviceColor(String serviceType, String paymentMethod) {
  switch (serviceType) {
    case 'home':
      return paymentMethod == 'card'
          ? const Color(0xFF2258B3)
          : const Color(0xFFB4421A);
    case 'home_buy':
      return paymentMethod == 'card'
          ? const Color(0xFF0A6B61)
          : const Color(0xFF086D84);
    case 'home_cross':
      return paymentMethod == 'card'
          ? const Color(0xFF4654A0)
          : const Color(0xFFA43668);
    case 'home_buy_cross':
      return paymentMethod == 'card'
          ? const Color(0xFF61478A)
          : const Color(0xFF8E3034);
    case 'buy':
      return const Color(0xFF7D5A00);
    case 'cross':
      return const Color(0xFF516A25);
    case 'change':
      return const Color(0xFF29633C);
    default:
      return Palette.royal;
  }
}

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? Palette.dark : Palette.light;
  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Palette.royal,
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      surface: p.surface,
      onSurface: p.ink,
      error: p.danger,
    ),
    scaffoldBackgroundColor: p.bg,
  );
  final body = GoogleFonts.hankenGroteskTextTheme(
    base.textTheme,
  ).apply(bodyColor: p.ink, displayColor: p.ink);
  return base.copyWith(
    textTheme: body.copyWith(
      headlineLarge: GoogleFonts.bricolageGrotesque(
        textStyle: body.headlineLarge,
        fontWeight: FontWeight.w800,
        color: p.ink,
        letterSpacing: -0.8,
      ),
      headlineMedium: GoogleFonts.bricolageGrotesque(
        textStyle: body.headlineMedium,
        fontWeight: FontWeight.w800,
        color: p.ink,
        letterSpacing: -0.6,
      ),
      titleLarge: GoogleFonts.bricolageGrotesque(
        textStyle: body.titleLarge,
        fontWeight: FontWeight.w700,
        color: p.ink,
      ),
    ),
    dividerColor: p.line,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: p.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: p.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: p.primary, width: 1.6),
      ),
      labelStyle: TextStyle(color: p.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        minimumSize: const Size(44, 48),
        side: BorderSide(color: p.lineStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.nav,
      indicatorColor: p.wash,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight:
              states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w600,
          color: states.contains(WidgetState.selected) ? p.accentText : p.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? p.accentText : p.muted,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(color: p.bg, fontWeight: FontWeight.w600),
    ),
  );
}
