import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AuthService {
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  // 12 karakter rastgele kod üretir: XXXX-XXXX-XXXX
  static String _generateRawCode() {
    final rng = Random.secure();
    return List.generate(12, (_) => _chars[rng.nextInt(_chars.length)]).join();
  }

  static String formatCode(String raw) =>
      '${raw.substring(0, 4)}-${raw.substring(4, 8)}-${raw.substring(8, 12)}';

  static String _email(String rawCode) =>
      '${rawCode.toLowerCase()}@fidus.app';

  static String _password(String rawCode) => 'fidus_${rawCode.toLowerCase()}';

  // Sync kodu mevcut oturumdan türetir
  static String? getSyncCode() {
    final email = supabase.auth.currentUser?.email;
    if (email == null) return null;
    final raw = email.split('@').first.toUpperCase();
    if (raw.length != 12) return null;
    return formatCode(raw);
  }

  // İlk açılış: otomatik hesap oluşturur
  static Future<void> signUpAuto() async {
    final rawCode = _generateRawCode();
    await supabase.auth.signUp(
      email: _email(rawCode),
      password: _password(rawCode),
    );
  }

  // Başka cihazdan sync: kod girilerek giriş yapılır
  static Future<bool> signInWithCode(String formattedCode) async {
    final raw = formattedCode.replaceAll('-', '').toUpperCase();
    if (raw.length != 12) return false;
    try {
      final res = await supabase.auth.signInWithPassword(
        email: _email(raw),
        password: _password(raw),
      );
      return res.user != null;
    } on AuthException {
      return false;
    }
  }

  static bool get isSignedIn => supabase.auth.currentUser != null;
}
