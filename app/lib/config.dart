/// Fill these three values to connect the app to your backend. Leave them empty to run the app
/// fully on-device (bots, local saves) — that is how it ships today.
/// See GO_LIVE_GUIDE.md for where each value comes from.
class AppConfig {
  /// Your Node backend, e.g. https://chaupal-backend.up.railway.app  (no trailing slash)
  static const backendUrl = '';
  /// Supabase → Project Settings → API → Project URL, e.g. https://abcd1234.supabase.co
  static const supabaseUrl = '';
  /// Supabase → Project Settings → API → anon public key (safe to ship in the app)
  static const supabaseAnonKey = '';

  static const appVersion = '1.0.0';
  /// Filled at startup with a stable per-install id (hex). Used for device binding on the server.
  static String deviceId = '';
}
