import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase Configuration
/// Used for image storage while keeping Firebase for auth/firestore
class SupabaseConfig {
  // Reads from .env file at runtime
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';

  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // Storage bucket names
  static const String templeImagesBucket = 'temple-images';
  static const String userImagesBucket = 'user-images';

  /// Check if Supabase is properly configured
  static bool isConfigured() {
    return supabaseAnonKey.isNotEmpty &&
        supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY_HERE';
  }
}
