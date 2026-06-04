import 'package:fidus/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('app themes use Plus Jakarta Sans as the primary font', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      expect(
        theme.textTheme.bodyLarge?.fontFamily,
        contains('PlusJakartaSans'),
      );
      expect(
        theme.textTheme.titleLarge?.fontFamily,
        contains('PlusJakartaSans'),
      );
      expect(
        theme.appBarTheme.titleTextStyle?.fontFamily,
        contains('PlusJakartaSans'),
      );
    }
  });
}
