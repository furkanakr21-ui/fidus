import 'package:flutter/material.dart';

class AppColors {
  // ── Primary accent ──────────────────────────────────────────────
  // Elektrik firuze: canlı, yenilikçi, güven verici — fintech kimliği
  static const primary = Color(0xFF00FFC1);
  static const primaryDark = Color(0xFF00C997);
  static const lightPrimary = Color(0xFF087D6E);
  static const lightPrimaryDark = Color(0xFF176B65);

  // ── Durum renkleri ───────────────────────────────────────────────
  // Kâr ve zarar renkleri yalnızca finansal yön ve sonuç bildirir.
  static const profit = Color(0xFF27FF9A);
  static const lightProfit = Color(0xFF0B7F5F);
  static const loss = Color(0xFFFF5474);

  static Color profitFor(Brightness brightness) =>
      brightness == Brightness.dark ? profit : lightProfit;

  static Color accentFor(Brightness brightness) =>
      brightness == Brightness.dark ? primary : lightPrimary;

  // ── Anlamsal aksanlar ───────────────────────────────────────────
  // Mavi: piyasa, portföy ve analitik bilgi
  static const market = Color(0xFF18DCFF);
  // Kehribar: nakit akışı, zaman ve dikkat gerektiren durumlar
  static const cashFlow = Color(0xFFFFDB3D);
  // Menekşe: hedefler, fonlar ve uzun vadeli planlama
  static const planning = Color(0xFFC895FF);
  static const gold = cashFlow;
  static const silver = Color(0xFF8B9CB8);

  // ── Koyu tema yüzeyleri (Grafit Aurora) ─────────────────────────
  // Nötr grafit taban, anlamsal renklerin yorucu olmadan öne çıkmasını sağlar.
  static const darkBackground = Color(0xFF050E14);
  static const darkSurface = Color(0xFF071D26);
  static const darkCard = Color(0xFF0A2934);
  static const darkRaised = Color(0xFF103A47);
  static const darkText = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFFBAD2DB);
  static const darkBorder = Color(0xFF236477);

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
