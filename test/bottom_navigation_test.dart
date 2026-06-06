import 'package:fidus/bottom_nav.dart';
import 'package:fidus/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('navigation layer floats navigation over the page content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FidusNavigationLayer(
            body: ColoredBox(key: Key('page-content'), color: Colors.red),
            navigation: SizedBox(
              key: Key('floating-navigation'),
              width: 300,
              height: 50,
            ),
            action: SizedBox(
              key: Key('floating-action'),
              width: 48,
              height: 48,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('fidus-navigation-layer')), findsOneWidget);
    final contentRect = tester.getRect(find.byKey(const Key('page-content')));
    final navigationRect = tester.getRect(
      find.byKey(const Key('floating-navigation')),
    );
    expect(contentRect.overlaps(navigationRect), isTrue);
  });

  testWidgets('page background extends beneath the bottom device safe area', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
          child: Scaffold(
            body: FidusNavigationLayer(
              body: Builder(
                builder: (context) => Text(
                  '${MediaQuery.paddingOf(context).bottom}',
                  key: const Key('body-bottom-padding'),
                ),
              ),
              navigation: const SizedBox(width: 300, height: 50),
              action: const SizedBox(width: 48, height: 48),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.byKey(const Key('body-bottom-padding'))).data,
      '0.0',
    );
  });

  testWidgets('bottom navigation is compact and respects the safe area', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(viewPadding: EdgeInsets.only(bottom: 24)),
          child: Scaffold(
            bottomNavigationBar: FidusBottomNavigation(
              currentIndex: 0,
              isDark: true,
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SafeArea), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('fidus-nav-surface'))).height,
      50,
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('bottom navigation surface is a borderless full pill', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: FidusBottomNavigation(
            currentIndex: 0,
            isDark: true,
            onTap: (_) {},
          ),
        ),
      ),
    );

    final surface = tester.widget<Container>(
      find.byKey(const Key('fidus-nav-surface')),
    );
    final decoration = surface.decoration! as BoxDecoration;
    expect(decoration.border, isNull);
    expect(decoration.borderRadius, BorderRadius.circular(25));
  });

  testWidgets('bottom navigation uses wallet icon and selected-only emphasis', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: FidusBottomNavigation(
            currentIndex: 2,
            isDark: true,
            onTap: (_) {},
          ),
        ),
      ),
    );

    final selectedWallet = tester.widget<Icon>(
      find.byIcon(Icons.account_balance_wallet_rounded),
    );
    expect(selectedWallet.color, AppColors.primary);
    expect(find.byIcon(Icons.swap_vert_rounded), findsNothing);
    expect(
      find.byKey(const Key('fidus-nav-selected-indicator-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('fidus-nav-selected-indicator-0')),
      findsNothing,
    );
  });

  testWidgets(
    'bottom navigation keeps each destination at least 48 pixels tall',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: FidusBottomNavigation(
              currentIndex: 0,
              isDark: true,
              onTap: (_) {},
            ),
          ),
        ),
      );

      for (var index = 0; index < 5; index++) {
        expect(
          tester.getSize(find.byKey(Key('fidus-nav-item-$index'))).height,
          greaterThanOrEqualTo(48),
        );
      }
    },
  );

  testWidgets('bottom navigation exposes meaningful accessible tab names', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: FidusBottomNavigation(
            currentIndex: 0,
            isDark: true,
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Anasayfa'), findsOneWidget);
    expect(find.bySemanticsLabel('Portföy'), findsOneWidget);
    expect(find.bySemanticsLabel('Nakit Akışı'), findsOneWidget);
    expect(find.bySemanticsLabel('Hedefler'), findsOneWidget);
    expect(find.bySemanticsLabel('Ayarlar'), findsOneWidget);
  });
}
