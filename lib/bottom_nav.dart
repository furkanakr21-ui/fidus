import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shared/providers.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/portfolio/portfolio_screen.dart';
import 'features/portfolio/add_asset_screen.dart';
import 'features/funds/tefas_browser_screen.dart';
import 'features/budget/budget_screen.dart';
import 'features/budget/add_cashflow_screen.dart';
import 'features/goals/goals_screen.dart';
import 'features/goals/add_goal_sheet.dart';
import 'features/settings/settings_screen.dart';
import 'core/theme/app_colors.dart';

class BottomNav extends ConsumerWidget {
  const BottomNav({super.key});

  static const List<Widget> _screens = [
    DashboardScreen(),
    PortfolioScreen(),
    BudgetScreen(),
    GoalsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(tabIndexProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: FidusNavigationLayer(
        body: IndexedStack(index: currentIndex, children: _screens),
        navigation: FidusBottomNavigation(
          currentIndex: currentIndex,
          isDark: isDark,
          onTap: (index) => ref.read(tabIndexProvider.notifier).setTab(index),
        ),
        action: _buildFab(context, ref),
      ),
    );
  }

  Widget _buildFab(BuildContext context, WidgetRef ref) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.38),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _showQuickAddSheet(context, ref),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  void _showQuickAddSheet(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Ne eklemek istiyorsun?',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.05,
                    children: [
                      _QuickAddTile(
                        icon: Icons.trending_up_rounded,
                        label: 'Varlık',
                        color: AppColors.primary,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddAssetScreen(),
                            ),
                          );
                        },
                      ),
                      _QuickAddTile(
                        icon: Icons.account_balance_outlined,
                        label: 'Fonlar',
                        color: const Color(0xFF8B5CF6),
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TefasBrowserScreen(),
                            ),
                          );
                        },
                      ),
                      _QuickAddTile(
                        icon: Icons.flag_rounded,
                        label: 'Hedef',
                        color: AppColors.gold,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const AddGoalSheet(),
                          );
                        },
                      ),
                      _QuickAddTile(
                        icon: Icons.arrow_downward_rounded,
                        label: 'Para Girişi',
                        color: AppColors.profit,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AddCashFlowScreen(isDeposit: true),
                            ),
                          );
                        },
                      ),
                      _QuickAddTile(
                        icon: Icons.arrow_upward_rounded,
                        label: 'Para Çıkışı',
                        color: AppColors.loss,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AddCashFlowScreen(isDeposit: false),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class FidusNavigationLayer extends StatelessWidget {
  final Widget body;
  final Widget navigation;
  final Widget action;

  const FidusNavigationLayer({
    super.key,
    required this.body,
    required this.navigation,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;

    return Stack(
      key: const Key('fidus-navigation-layer'),
      fit: StackFit.expand,
      children: [
        MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: body,
        ),
        Align(alignment: Alignment.bottomCenter, child: navigation),
        Positioned(right: 20, bottom: safeBottom + 66, child: action),
      ],
    );
  }
}

class FidusBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final bool isDark;
  final ValueChanged<int> onTap;

  const FidusBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.isDark,
    required this.onTap,
  });

  static const _items = [
    ('Anasayfa', Icons.home_outlined, Icons.home_rounded),
    ('Portföy', Icons.pie_chart_outline_rounded, Icons.pie_chart_rounded),
    (
      'Nakit Akışı',
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet_rounded,
    ),
    ('Hedefler', Icons.flag_outlined, Icons.flag_rounded),
    ('Ayarlar', Icons.settings_outlined, Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark
        ? AppColors.darkSurface.withValues(alpha: 0.68)
        : Colors.white.withValues(alpha: 0.76);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.10),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                key: const Key('fidus-nav-surface'),
                height: 50,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: _items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Expanded(
                      child: _NavItem(
                        index: index,
                        label: item.$1,
                        icon: item.$2,
                        selectedIcon: item.$3,
                        isSelected: currentIndex == index,
                        isDark: isDark,
                        onTap: () => onTap(index),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Nav Item ──────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final int index;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _NavItem({
    required this.index,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    return Semantics(
      label: label,
      button: true,
      selected: isSelected,
      child: GestureDetector(
        key: Key('fidus-nav-item-$index'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                scale: isSelected ? 1.06 : 1,
                child: ExcludeSemantics(
                  child: Icon(
                    isSelected ? selectedIcon : icon,
                    size: 20,
                    color: isSelected ? AppColors.primary : inactive,
                  ),
                ),
              ),
              if (isSelected)
                Positioned(
                  bottom: 0,
                  child: Container(
                    key: Key('fidus-nav-selected-indicator-$index'),
                    width: 20,
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.75),
                          blurRadius: 7,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Quick Add Tile ────────────────────────────────────────────────────────
class _QuickAddTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickAddTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.07 : 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.14 : 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 9),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
