import 'package:fidus/core/theme/app_theme.dart';
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
}
