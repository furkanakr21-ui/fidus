import 'package:flutter/material.dart';

class AppColors {
  // ── Primary accent ──────────────────────────────────────────────
  // Elektrik firuze: canlı, yenilikçi, güven verici — fintech kimliği
  static const primary = Color(0xFF00CEAA);
  static const primaryDark = Color(0xFF00A88A);
  static const lightPrimary = Color(0xFF087D6E);
  static const lightPrimaryDark = Color(0xFF176B65);

  // ── Durum renkleri ───────────────────────────────────────────────
  // Kâr: saf dijital yeşil — başarı, büyüme (sarımsı değil, taze)
  static const profit = Color(0xFF0FD97C);
  // Zarar: enerji kırmızısı — uyarı sinyali, belirsiz turuncu değil
  static const loss = Color(0xFFFF3D5B);

  // ── Nötr aksan ──────────────────────────────────────────────────
  // Altın: canlı amber — yatırım maliyeti, premium hissi
  static const gold = Color(0xFFFFAB00);
  static const silver = Color(0xFF8B9CB8);

  // ── Koyu tema yüzeyleri (mavi-lacivert bazlı) ───────────────────
  // Arkaplan: derin lacivert-siyah — Bloomberg/terminal etkisi, otorite
  static const darkBackground = Color(0xFF070A10);
  static const darkSurface = Color(0xFF0D1119);
  // Kart: arkaplanından belirgin, mavi tonlu — derinlik ve hiyerarşi
  static const darkCard = Color(0xFF131C2A);
  // Metin: hafif mavi-beyaz — tam beyazdan daha az göz yorucu
  static const darkText = Color(0xFFEAF0FF);
  // İkincil metin: mavi-gri — okunabilir ama geri planda
  static const darkTextSecondary = Color(0xFF7A8EA8);
  // Kenar: görünür ama baskın değil
  static const darkBorder = Color(0xFF1A2535);

  // ── Açık tema yüzeyleri ──────────────────────────────────────────
  // Hafif yesil-gri zemin ve kirik beyaz yuzeyler
  static const lightBackground = Color(0xFFF1F4F4);
  static const lightSurface = Color(0xFFFAFBFB);
  static const lightCard = Color(0xFFFAFBFB);
  // Grafit metinler ve sakin yesil-gri sinirlar
  static const lightText = Color(0xFF142027);
  static const lightTextSecondary = Color(0xFF687981);
  static const lightBorder = Color(0xFFDCE3E4);
}
