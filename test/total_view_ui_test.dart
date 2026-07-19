import 'dart:async';

import 'package:fidus/core/constants/app_constants.dart';
import 'package:fidus/features/dashboard/dashboard_screen.dart';
import 'package:fidus/features/portfolio/portfolio_screen.dart';
import 'package:fidus/features/settings/total_view_controls.dart';
import 'package:fidus/shared/models/daily_portfolio_change.dart';
import 'package:fidus/shared/models/portfolio_model.dart';
import 'package:fidus/shared/providers.dart';
import 'package:fidus/shared/widgets/total_view_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PortfolioModel _portfolio(
  String id,
  String name, {
  bool includeInTotal = true,
}) {
  return PortfolioModel(
    id: id,
    userId: 'user-1',
    name: name,
    emoji: 'P',
    includeInTotal: includeInTotal,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

Widget _badgeApp({
  required String activePortfolioId,
  required List<PortfolioModel> portfolios,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      activePortfolioProvider.overrideWithBuild(
        (ref, notifier) => activePortfolioId,
      ),
      portfoliosProvider.overrideWithBuild((ref, notifier) => portfolios),
    ],
    child: const MaterialApp(
      home: Scaffold(body: Align(child: TotalViewBadge())),
    ),
  );
}

Widget _sheetApp({
  required List<PortfolioModel> portfolios,
  required Future<void> Function(String, bool) onChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 600,
        child: TotalViewSettingsSheet(
          portfolios: portfolios,
          onChanged: onChanged,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('total portfolio tile exposes selection and settings actions', (
    tester,
  ) async {
    var selectCount = 0;
    var configureCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TotalPortfolioTile(
            includedCount: 2,
            isActive: false,
            onSelect: () => selectCount++,
            onConfigure: () => configureCount++,
          ),
        ),
      ),
    );

    expect(find.text('Portföyler Toplamı'), findsOneWidget);
    expect(find.text('2 portföy dahil'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('select-total-portfolio')));
    await tester.tap(find.byKey(const ValueKey('configure-total-portfolio')));

    expect(selectCount, 1);
    expect(configureCount, 1);
  });

  testWidgets('active total portfolio tile shows a check instead of select', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TotalPortfolioTile(
            includedCount: 3,
            isActive: true,
            onSelect: () {},
            onConfigure: () {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('total-portfolio-active')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('select-total-portfolio')), findsNothing);
  });

  testWidgets('settings sheet writes the selected inclusion value', (
    tester,
  ) async {
    String? changedId;
    bool? changedValue;
    await tester.pumpWidget(
      _sheetApp(
        portfolios: [_portfolio('p1', 'Ana')],
        onChanged: (id, value) async {
          changedId = id;
          changedValue = value;
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey('total-view-switch-p1')));
    await tester.pumpAndSettle();

    expect(changedId, 'p1');
    expect(changedValue, isFalse);
    final toggle = tester.widget<Switch>(
      find.byKey(const ValueKey('total-view-switch-p1')),
    );
    expect(toggle.value, isFalse);
  });

  testWidgets('settings sheet restores the switch after a write failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      _sheetApp(
        portfolios: [_portfolio('p1', 'Ana')],
        onChanged: (_, _) => Future<void>.error(StateError('write failed')),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('total-view-switch-p1')));
    await tester.pumpAndSettle();

    final toggle = tester.widget<Switch>(
      find.byKey(const ValueKey('total-view-switch-p1')),
    );
    expect(toggle.value, isTrue);
    expect(find.text('Portföy tercihi kaydedilemedi'), findsOneWidget);
  });

  testWidgets('settings sheet serializes inclusion writes', (tester) async {
    final pending = Completer<void>();
    await tester.pumpWidget(
      _sheetApp(
        portfolios: [_portfolio('p1', 'Ana'), _portfolio('p2', 'Uzun Vade')],
        onChanged: (_, _) => pending.future,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('total-view-switch-p1')));
    await tester.pump();

    final secondToggle = tester.widget<Switch>(
      find.byKey(const ValueKey('total-view-switch-p2')),
    );
    expect(secondToggle.onChanged, isNull);

    pending.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('empty total selection explains how to choose portfolios', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showNoIncludedPortfoliosDialog(context);
              },
              child: const Text('Aç'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    expect(find.text('Toplama dahil portföy yok'), findsOneWidget);
    expect(
      find.text(
        'Portföyler Toplamı görünümünü açmak için en az bir portföy seçin.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('configure-empty-total-view')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('total view badge is rendered only for total mode', (
    tester,
  ) async {
    final portfolios = [
      _portfolio('p1', 'Ana'),
      _portfolio('p2', 'Uzun Vade'),
      _portfolio('p3', 'Hariç', includeInTotal: false),
    ];
    await tester.pumpWidget(
      _badgeApp(activePortfolioId: 'p1', portfolios: portfolios),
    );
    expect(find.byKey(const ValueKey('total-view-badge')), findsNothing);

    await tester.pumpWidget(
      _badgeApp(activePortfolioId: kTotalPortfolioId, portfolios: portfolios),
    );
    expect(find.byKey(const ValueKey('total-view-badge')), findsOneWidget);
    expect(find.text('Toplam görünüm · 2 portföy'), findsOneWidget);
  });

  testWidgets('dashboard header fits the total view badge on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final portfolios = [_portfolio('p1', 'Ana'), _portfolio('p2', 'Uzun Vade')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activePortfolioProvider.overrideWithBuild(
            (ref, notifier) => kTotalPortfolioId,
          ),
          portfoliosProvider.overrideWithBuild((ref, notifier) => portfolios),
          assetsProvider.overrideWithBuild((ref, notifier) => const []),
          priceLoadingProvider.overrideWithBuild((ref, notifier) => false),
          priceUpdateProvider.overrideWithBuild((ref, notifier) => null),
          cashflowProvider.overrideWithBuild((ref, notifier) => const []),
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
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    expect(find.byKey(const ValueKey('total-view-badge')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('portfolio header fits the total view badge on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final portfolios = [_portfolio('p1', 'Ana'), _portfolio('p2', 'Uzun Vade')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activePortfolioProvider.overrideWithBuild(
            (ref, notifier) => kTotalPortfolioId,
          ),
          portfoliosProvider.overrideWithBuild((ref, notifier) => portfolios),
          assetsProvider.overrideWithBuild((ref, notifier) => const []),
          exchangeRatesProvider.overrideWithBuild((ref, notifier) => const {}),
          portfolioSnapshotHistoryProvider.overrideWithBuild(
            (ref, notifier) => const [],
          ),
          priceLoadingProvider.overrideWithBuild((ref, notifier) => false),
          priceUpdateProvider.overrideWithBuild((ref, notifier) => null),
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
        ],
        child: const MaterialApp(home: PortfolioScreen()),
      ),
    );

    expect(find.byKey(const ValueKey('total-view-badge')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
