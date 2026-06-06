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

  test('graphite jade light palette does not alter dark theme colors', () {
    expect(AppColors.primary, const Color(0xFF00CEAA));
    expect(AppColors.darkBackground, const Color(0xFF070A10));
    expect(AppTheme.dark.colorScheme.primary, AppColors.primary);
  });
}
