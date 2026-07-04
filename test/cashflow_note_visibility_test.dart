import 'package:fidus/core/theme/app_theme.dart';
import 'package:fidus/features/budget/budget_screen.dart';
import 'package:fidus/features/dashboard/dashboard_screen.dart';
import 'package:fidus/shared/models/daily_portfolio_change.dart';
import 'package:fidus/shared/models/income_expense_model.dart';
import 'package:fidus/shared/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CashFlowModel _cashflow({
  required String id,
  required String title,
  required CashFlowType type,
  double amount = 100,
  String currency = 'TRY',
  double? rateAtEntry,
  String? note,
}) {
  return CashFlowModel(
    id: id,
    portfolioId: 'portfolio-1',
    title: title,
    amount: amount,
    currency: currency,
    type: type,
    date: DateTime(2026, 6, 5),
    note: note,
    rateAtEntry: rateAtEntry,
  );
}

Widget _budgetApp(List<CashFlowModel> cashflows) {
  return ProviderScope(
    overrides: [
      cashflowProvider.overrideWithBuild((ref, notifier) => cashflows),
    ],
    child: MaterialApp(theme: AppTheme.dark, home: const BudgetScreen()),
  );
}

Finder _inDetailSheet(Finder matching) {
  return find.descendant(
    of: find.byKey(const Key('cashflow-detail-sheet')),
    matching: matching,
  );
}

void main() {
  testWidgets('cash flow card shows a single-line note preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _budgetApp([
        _cashflow(
          id: 'with-note',
          title: 'Kira Ödemesi',
          type: CashFlowType.withdrawal,
          note: 'Haziran kirası için çekildi',
        ),
      ]),
    );

    final preview = tester.widget<Text>(
      find.text('Haziran kirası için çekildi'),
    );
    expect(preview.maxLines, 1);
    expect(preview.overflow, TextOverflow.ellipsis);
    expect(preview.style?.fontStyle, FontStyle.italic);
  });

  testWidgets('cash flow card without a note keeps its compact layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _budgetApp([
        _cashflow(id: 'no-note', title: 'Maaş', type: CashFlowType.deposit),
      ]),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && widget.style?.fontStyle == FontStyle.italic,
      ),
      findsNothing,
    );
  });

  testWidgets('tapping a cash flow card opens the detail sheet with the note', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _budgetApp([
        _cashflow(
          id: 'with-note',
          title: 'Kira Ödemesi',
          type: CashFlowType.withdrawal,
          note: 'Haziran kirası için çekildi',
        ),
      ]),
    );

    await tester.tap(find.text('Kira Ödemesi'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cashflow-detail-sheet')), findsOneWidget);
    expect(
      _inDetailSheet(find.text('Haziran kirası için çekildi')),
      findsOneWidget,
    );
    expect(_inDetailSheet(find.text('Not')), findsOneWidget);
  });

  testWidgets(
    'detail sheet shows the locked rate and TRY equivalent for foreign currency',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _budgetApp([
          _cashflow(
            id: 'usd-flow',
            title: 'Dolar Bozdurma',
            type: CashFlowType.deposit,
            amount: 100,
            currency: 'USD',
            rateAtEntry: 40,
          ),
        ]),
      );

      await tester.tap(find.text('Dolar Bozdurma'));
      await tester.pumpAndSettle();

      expect(_inDetailSheet(find.text('1 USD = 40.0000 ₺')), findsOneWidget);
      expect(_inDetailSheet(find.text('₺4.000')), findsOneWidget);
    },
  );

  testWidgets('detail sheet delete action asks for confirmation first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _budgetApp([
        _cashflow(
          id: 'with-note',
          title: 'Kira Ödemesi',
          type: CashFlowType.withdrawal,
          note: 'Haziran kirası için çekildi',
        ),
      ]),
    );

    await tester.tap(find.text('Kira Ödemesi'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cashflow-detail-delete')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('İptal'), findsOneWidget);

    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('cashflow-detail-sheet')), findsOneWidget);
  });

  testWidgets('dashboard recent cash flow row opens the same detail sheet', (
    tester,
  ) async {
    // Test fontu (Ahem) gerçek fonttan geniş çizildiği için dashboard başlık
    // satırının sığması adına geniş görünüm kullanılır.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activePortfolioProvider.overrideWithBuild(
            (ref, notifier) => 'portfolio-1',
          ),
          assetsProvider.overrideWithBuild((ref, notifier) => const []),
          priceLoadingProvider.overrideWithBuild((ref, notifier) => false),
          priceUpdateProvider.overrideWithBuild((ref, notifier) => null),
          cashflowProvider.overrideWithBuild(
            (ref, notifier) => [
              _cashflow(
                id: 'with-note',
                title: 'Kira Ödemesi',
                type: CashFlowType.withdrawal,
                note: 'Haziran kirası için çekildi',
              ),
            ],
          ),
          goalsProvider.overrideWithBuild((ref, notifier) => const []),
          currencyProvider.overrideWithBuild((ref, notifier) => 'TRY'),
          dailyPortfolioChangeProvider.overrideWithValue(
            const DailyPortfolioChange(
              hasSnapshot: false,
              currentValue: 0,
              baselineValue: 0,
              amount: 0,
              percent: 0,
              displayCurrency: 'TRY',
            ),
          ),
          dailyAssetChangesProvider.overrideWithValue(const {}),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const DashboardScreen()),
      ),
    );

    await tester.tap(find.text('Kira Ödemesi'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cashflow-detail-sheet')), findsOneWidget);
    expect(
      _inDetailSheet(find.text('Haziran kirası için çekildi')),
      findsOneWidget,
    );
  });
}
