/// Configuración pública que se incorpora en tiempo de compilación.
///
/// Las claves de cliente de Supabase son públicas por diseño, pero deben
/// corresponder al proyecto correcto. Nunca se debe poner aquí una clave de
/// servicio ni una credencial privada.
class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get hasValidSupabase {
    return isValidSupabaseConfig(url: supabaseUrl, key: supabaseAnonKey);
  }

  static bool isValidSupabaseConfig({
    required String url,
    required String key,
  }) {
    url = url.trim();
    key = key.trim();
    final parsed = Uri.tryParse(url);
    return parsed != null &&
        (parsed.scheme == 'https' || parsed.scheme == 'http') &&
        parsed.host.isNotEmpty &&
        !_looksLikePlaceholder(url) &&
        key.length >= 20 &&
        !_looksLikePlaceholder(key);
  }

  static String get configurationMessage {
    if (supabaseUrl.trim().isEmpty || supabaseAnonKey.trim().isEmpty) {
      return 'Esta versión se compiló sin la conexión a Supabase.';
    }
    return 'Esta versión se compiló con una configuración de Supabase inválida.';
  }

  static bool _looksLikePlaceholder(String value) {
    final lower = value.toLowerCase();
    return lower.contains('hashtable') ||
        lower.contains('vite_supabase_') ||
        lower.contains('tu-proyecto') ||
        lower.contains('system.collections');
  }
}
