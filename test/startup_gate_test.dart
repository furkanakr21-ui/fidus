import 'package:fidus/features/startup/startup_gate.dart';
import 'package:fidus/shared/models/portfolio_model.dart';
import 'package:fidus/shared/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final portfolio = PortfolioModel(
    id: 'portfolio-1',
    userId: 'user-1',
    name: 'Ana Portföy',
    emoji: 'P',
    createdAt: DateTime(2026),
  );

  test('initial data readiness requires the critical server-backed values', () {
    final incomplete = ProviderContainer(
      overrides: [
        activePortfolioProvider.overrideWithBuild(
          (ref, notifier) => 'portfolio-1',
        ),
        portfoliosProvider.overrideWithBuild((ref, notifier) => [portfolio]),
        pricesProvider.overrideWithBuild((ref, notifier) => const {}),
        exchangeRatesProvider.overrideWithBuild(
          (ref, notifier) => const {'TRY': 43},
        ),
        todayAssetSnapshotsProvider.overrideWithBuild(
          (ref, notifier) => const {},
        ),
        initialDataLoadTrackerProvider.overrideWithBuild(
          (ref, notifier) => InitialDataLoadTracker.requiredSections,
        ),
      ],
    );
    addTearDown(incomplete.dispose);

    expect(incomplete.read(initialDataReadyProvider), isFalse);

    final dashboardStillLoading = ProviderContainer(
      overrides: [
        activePortfolioProvider.overrideWithBuild(
          (ref, notifier) => 'portfolio-1',
        ),
        portfoliosProvider.overrideWithBuild((ref, notifier) => [portfolio]),
        pricesProvider.overrideWithBuild(
          (ref, notifier) => const {'AAA_manual': PriceRecord(100, 'TRY')},
        ),
        exchangeRatesProvider.overrideWithBuild(
          (ref, notifier) => const {'TRY': 43},
        ),
        todayAssetSnapshotsProvider.overrideWithBuild(
          (ref, notifier) => const {},
        ),
        initialDataLoadTrackerProvider.overrideWithBuild(
          (ref, notifier) => const {InitialDataLoadTracker.assets},
        ),
      ],
    );
    addTearDown(dashboardStillLoading.dispose);

    expect(dashboardStillLoading.read(initialDataReadyProvider), isFalse);

    final ready = ProviderContainer(
      overrides: [
        activePortfolioProvider.overrideWithBuild(
          (ref, notifier) => 'portfolio-1',
        ),
        portfoliosProvider.overrideWithBuild((ref, notifier) => [portfolio]),
        pricesProvider.overrideWithBuild(
          (ref, notifier) => const {'AAA_manual': PriceRecord(100, 'TRY')},
        ),
        exchangeRatesProvider.overrideWithBuild(
          (ref, notifier) => const {'TRY': 43},
        ),
        todayAssetSnapshotsProvider.overrideWithBuild(
          (ref, notifier) => const {},
        ),
        initialDataLoadTrackerProvider.overrideWithBuild(
          (ref, notifier) => InitialDataLoadTracker.requiredSections,
        ),
      ],
    );
    addTearDown(ready.dispose);

    expect(ready.read(initialDataReadyProvider), isTrue);
  });

  test('initial data readiness accepts a completed empty portfolio list', () {
    final newUser = ProviderContainer(
      overrides: [
        activePortfolioProvider.overrideWithBuild((ref, notifier) => ''),
        portfoliosProvider.overrideWithBuild((ref, notifier) => const []),
        initialDataLoadTrackerProvider.overrideWithBuild(
          (ref, notifier) => const {InitialDataLoadTracker.portfolios},
        ),
      ],
    );
    addTearDown(newUser.dispose);

    expect(newUser.read(initialDataReadyProvider), isTrue);
  });

  testWidgets('startup gate waits for readiness and minimum display time', (
    tester,
  ) async {
    var isReady = false;
    late StateSetter updateGate;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            updateGate = setState;
            return StartupGate(
              isReady: isReady,
              minimumDisplayDuration: const Duration(milliseconds: 800),
              maximumWaitDuration: const Duration(seconds: 5),
              transitionDuration: const Duration(milliseconds: 300),
              child: const Text('Anasayfa'),
            );
          },
        ),
      ),
    );

    expect(find.byType(StartupSplash), findsOneWidget);
    expect(find.text('Anasayfa'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    updateGate(() => isReady = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 399));
    expect(find.byType(StartupSplash), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 401));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byType(StartupSplash), findsNothing);
  });

  testWidgets('startup gate releases after the maximum wait duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StartupGate(
          isReady: false,
          minimumDisplayDuration: Duration(milliseconds: 100),
          maximumWaitDuration: Duration(milliseconds: 500),
          transitionDuration: Duration(milliseconds: 200),
          child: Text('Anasayfa'),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 501));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(find.byType(StartupSplash), findsNothing);
    expect(find.text('Anasayfa'), findsOneWidget);
  });

  testWidgets('startup timeout begins only when it is enabled', (tester) async {
    var timeoutEnabled = false;
    late StateSetter updateGate;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            updateGate = setState;
            return StartupGate(
              isReady: false,
              timeoutEnabled: timeoutEnabled,
              minimumDisplayDuration: const Duration(milliseconds: 100),
              maximumWaitDuration: const Duration(milliseconds: 400),
              transitionDuration: const Duration(milliseconds: 100),
              child: const Text('Anasayfa'),
            );
          },
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(StartupSplash), findsOneWidget);

    updateGate(() => timeoutEnabled = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 401));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(StartupSplash), findsNothing);
  });

  testWidgets('startup splash uses the deep petrol identity surface', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: StartupSplash()));

    final surface = tester.widget<DecoratedBox>(
      find.byKey(const Key('startup-splash-surface')),
    );
    final decoration = surface.decoration as BoxDecoration;
    final gradient = decoration.gradient! as RadialGradient;

    expect(gradient.colors, const [
      Color(0xFF102D36),
      Color(0xFF071D26),
      Color(0xFF050E14),
    ]);
    expect(find.text('Finansal görünümünüz hazırlanıyor'), findsOneWidget);
    expect(find.byKey(const Key('startup-signature-line')), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('fidus')).style?.decoration,
      TextDecoration.none,
    );
  });
}
