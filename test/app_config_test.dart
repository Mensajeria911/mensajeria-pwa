import 'package:flutter_test/flutter_test.dart';

import 'package:mensajeria_911_driver/app_config.dart';

void main() {
  test('accepts a real Supabase URL and a public client key', () {
    expect(
      AppConfig.isValidSupabaseConfig(
        url: 'https://xwhohvxogfprizdmcusa.supabase.co',
        key: 'sb_publishable_${List.filled(32, 'a').join()}',
      ),
      isTrue,
    );
  });

  test('rejects the PowerShell hashtable placeholder', () {
    expect(
      AppConfig.isValidSupabaseConfig(
        url: 'System.Collections.Hashtable[VITE_SUPABASE_URL]',
        key: 'sb_publishable_${List.filled(32, 'a').join()}',
      ),
      isFalse,
    );
  });

  test('rejects a Vite placeholder', () {
    expect(
      AppConfig.isValidSupabaseConfig(
        url: 'https://TU-PROYECTO.supabase.co',
        key: '[VITE_SUPABASE_ANON_KEY]',
      ),
      isFalse,
    );
  });
}
