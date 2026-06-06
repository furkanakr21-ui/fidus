import 'package:fidus/core/theme/app_theme.dart';
import 'package:fidus/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('app themes use bundled Plus Jakarta Sans as the primary font', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      expect(theme.textTheme.bodyLarge?.fontFamily, 'Plus Jakarta Sans');
      expect(theme.textTheme.titleLarge?.fontFamily, 'Plus Jakarta Sans');
      expect(theme.appBarTheme.titleTextStyle?.fontFamily, 'Plus Jakarta Sans');
    }
  });

  test('light theme uses the graphite jade palette', () {
    expect(AppColors.lightBackground, const Color(0xFFF1F4F4));
    expect(AppColors.lightSurface, const Color(0xFFFAFBFB));
    expect(AppColors.lightCard, const Color(0xFFFAFBFB));
    expect(AppColors.lightText, const Color(0xFF142027));
    expect(AppColors.lightTextSecondary, const Color(0xFF687981));
    expect(AppColors.lightBorder, const Color(0xFFDCE3E4));
    expect(AppColors.lightPrimary, const Color(0xFF087D6E));
    expect(AppTheme.light.colorScheme.primary, AppColors.lightPrimary);
  });

  test('dark theme uses the electric aurora surface palette', () {
    expect(AppColors.darkBackground, const Color(0xFF050E14));
    expect(AppColors.darkSurface, const Color(0xFF071D26));
    expect(AppColors.darkCard, const Color(0xFF0A2934));
    expect(AppColors.darkRaised, const Color(0xFF103A47));
    expect(AppColors.darkBorder, const Color(0xFF236477));
    expect(AppColors.darkText, const Color(0xFFFFFFFF));
    expect(AppColors.darkTextSecondary, const Color(0xFFBAD2DB));
    expect(AppTheme.dark.colorScheme.primary, AppColors.primary);
  });

  test('semantic colors keep one stable financial meaning', () {
    expect(AppColors.primary, const Color(0xFF00FFC1));
    expect(AppColors.profit, const Color(0xFF27FF9A));
    expect(AppColors.loss, const Color(0xFFFF5474));
    expect(AppColors.market, const Color(0xFF18DCFF));
    expect(AppColors.cashFlow, const Color(0xFFFFDB3D));
    expect(AppColors.planning, const Color(0xFFC895FF));
    expect(AppColors.gold, AppColors.cashFlow);
  });

  test('positive financial values use a readable theme-aware green', () {
    expect(AppColors.lightProfit, const Color(0xFF0B7F5F));
    expect(AppColors.profitFor(Brightness.light), AppColors.lightProfit);
    expect(AppColors.profitFor(Brightness.dark), AppColors.profit);
  });

  test('general accents use the calmer light-theme jade', () {
    expect(AppColors.accentFor(Brightness.light), AppColors.lightPrimary);
    expect(AppColors.accentFor(Brightness.dark), AppColors.primary);
  });
}
