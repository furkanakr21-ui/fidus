import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/asset_model.dart';
import '../../shared/models/daily_asset_change.dart';
import '../../shared/models/daily_portfolio_change.dart';
import '../../shared/models/income_expense_model.dart';
import '../../shared/models/goal_model.dart';
import '../../shared/providers.dart';
import '../../shared/utils/currency_utils.dart';

const _budgetTabIndex = 2;
const _goalsTabIndex = 3;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(assetsProvider);
    final merged = ref.watch(mergedAssetsProvider);
    final totalValue = ref.watch(totalValueProvider);
    final totalCost = ref.watch(totalCostProvider);
    final dailyChange = ref.watch(dailyPortfolioChangeProvider);
    final dailyAssetChanges = ref.watch(dailyAssetChangesProvider);
    ref.watch(priceUpdateProvider);
    final cashflows = ref.watch(cashflowProvider);
    final goals = ref.watch(goalsProvider);
    final displayCurrency = ref.watch(currencyProvider);
    final isLoading = ref.watch(priceLoadingProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final lastUpdate = ref.watch(priceUpdateProvider);
    final updateStr = isLoading
        ? 'Güncelleniyor...'
        : lastUpdate == null
        ? null
        : 'Son: ${lastUpdate.hour.toString().padLeft(2, '0')}:${lastUpdate.minute.toString().padLeft(2, '0')}';
    final isStale =
        !isLoading &&
        lastUpdate != null &&
        DateTime.now().difference(lastUpdate).inMinutes >= 10;

    final recentCashflows = ([
      ...cashflows,
    ]..sort((a, b) => b.date.compareTo(a.date))).take(3).toList();

    final activeGoals =
        goals.where((g) => g.currentAmount < g.targetAmount).toList()
          ..sort((a, b) {
            if (a.targetDate == null && b.targetDate == null) return 0;
            if (a.targetDate == null) return 1;
            if (b.targetDate == null) return -1;
            return a.targetDate!.compareTo(b.targetDate!);
          });
    final nearestGoal = activeGoals.isNotEmpty ? activeGoals.first : null;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async =>
              ref.read(priceUpdateProvider.notifier).updatePrices(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(
                        context,
                        ref,
                        isLoading,
                        updateStr,
                        displayCurrency,
                        isStale,
                      ),
                      const SizedBox(height: 22),
                      _buildHeroCard(
                        context,
                        isDark,
                        totalValue,
                        dailyChange,
                        totalCost,
                        displayCurrency,
                      ),
                      const SizedBox(height: 14),
                      _buildStatsStrip(
                        context,
                        isDark,
                        dailyChange,
                        totalCost,
                        assets.length,
                        displayCurrency,
                      ),
                    ],
                  ),
                ),
              ),
              if (merged.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                    child: _buildAssetsByCategory(
                      context,
                      merged,
                      dailyAssetChanges,
                      displayCurrency,
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                  child: _buildRecentCashflows(context, ref, recentCashflows),
                ),
              ),
              if (nearestGoal != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                    child: _buildGoalCard(context, ref, nearestGoal),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────── Header ───────────────
  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    bool isLoading,
    String? updateStr,
    String displayCurrency,
    bool isStale,
  ) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Günaydın'
        : now.hour < 18
        ? 'İyi günler'
        : 'İyi akşamlar';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'Fidus',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  letterSpacing: -1.2,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        // Para birimi chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.09),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Text(
            displayCurrency,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 6),
        if (updateStr != null)
          Text(
            updateStr,
            style: TextStyle(
              fontSize: 10,
              color: isStale ? AppColors.gold : textSecondary,
            ),
          ),
        SizedBox(
          width: 38,
          height: 38,
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: textSecondary,
                  ),
                  onPressed: () =>
                      ref.read(priceUpdateProvider.notifier).updatePrices(),
                ),
        ),
      ],
    );
  }

  // ─────────────── Hero Card ───────────────
  Widget _buildHeroCard(
    BuildContext context,
    bool isDark,
    double totalValue,
    DailyPortfolioChange dailyChange,
    double totalCost,
    String displayCurrency,
  ) {
    final isProfit = dailyChange.isProfit;
    final plColor = dailyChange.hasSnapshot
        ? (isProfit ? AppColors.profit : AppColors.loss)
        : AppColors.gold;
    final dailyAmountText = dailyChange.hasSnapshot
        ? dailyChange.formatAmount()
        : 'İlk kayıt bekleniyor';
    final dailyMetricText = dailyChange.hasSnapshot
        ? dailyChange.formatAmount(absolute: true)
        : 'Bekleniyor';
    final dailyPercentText = dailyChange.hasSnapshot
        ? '${isProfit ? '+' : ''}${dailyChange.percent.toStringAsFixed(2)}%'
        : '--';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0D1B2E), const Color(0xFF08201A)]
              : [const Color(0xFF00705A), const Color(0xFF00CEAA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? const Color(0xFF0C1526) : AppColors.primary)
                .withValues(alpha: isDark ? 0.6 : 0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative glow circles
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -45,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'TOPLAM VARLIK',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  CurrencyUtils.formatHero(totalValue, displayCurrency),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: plColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: plColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            dailyChange.hasSnapshot
                                ? (isProfit
                                      ? Icons.arrow_upward_rounded
                                      : Icons.arrow_downward_rounded)
                                : Icons.schedule_rounded,
                            color: plColor,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dailyPercentText,
                            style: TextStyle(
                              color: plColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        dailyAmountText,
                        style: TextStyle(
                          color: plColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _heroStat(
                      'Maliyet',
                      CurrencyUtils.format(totalCost, displayCurrency),
                    ),
                    _heroDivider(),
                    _heroStat('Bugün', dailyMetricText, color: plColor),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value, {Color? color}) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );

  Widget _heroDivider() => Container(
    width: 1,
    height: 30,
    margin: const EdgeInsets.symmetric(horizontal: 16),
    color: Colors.white.withValues(alpha: 0.12),
  );

  // ─────────────── Stats Strip ───────────────
  Widget _buildStatsStrip(
    BuildContext context,
    bool isDark,
    DailyPortfolioChange dailyChange,
    double totalCost,
    int assetCount,
    String displayCurrency,
  ) {
    final isProfit = dailyChange.isProfit;
    final dailyColor = dailyChange.hasSnapshot
        ? (isProfit ? AppColors.profit : AppColors.loss)
        : AppColors.gold;
    final bg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: dailyChange.hasSnapshot
                ? (isProfit
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded)
                : Icons.schedule_rounded,
            label: 'Bugün',
            value: dailyChange.hasSnapshot
                ? dailyChange.formatAmount()
                : 'Bekleniyor',
            accentColor: dailyColor,
            bg: bg,
            border: border,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.receipt_long_outlined,
            label: 'Yatırım',
            value: CurrencyUtils.format(totalCost, displayCurrency),
            accentColor: AppColors.gold,
            bg: bg,
            border: border,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.layers_outlined,
            label: 'Varlık',
            value: '$assetCount adet',
            accentColor: AppColors.primary,
            bg: bg,
            border: border,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  // ─────────────── Assets by Category ───────────────
  static final _categories = [
    // TEFAS: indigo-mor — kurumsal fonlar, istikrar + güven
    const _AssetCategory(
      'TEFAS',
      Icons.account_balance_outlined,
      Color(0xFF7C6AF5),
    ),
    // BEFAS: daha açık mor — uzun vadeli emeklilik, sabır
    const _AssetCategory(
      'BEFAS',
      Icons.business_center_outlined,
      Color(0xFFAA82FA),
    ),
    // BIST: parlak mavi — borsa dinamizmi, enerji
    const _AssetCategory('BIST', Icons.show_chart_rounded, Color(0xFF2196F3)),
    // Yabancı/ETF: cyan — küresel, teknoloji hissi
    const _AssetCategory(
      'Yabancı / ETF',
      Icons.language_rounded,
      Color(0xFF00C8E0),
    ),
    // Kripto: turuncu-amber — spekülatif, yüksek enerji
    const _AssetCategory(
      'Kripto',
      Icons.currency_bitcoin_rounded,
      Color(0xFFFF8F00),
    ),
    // Döviz: taze yeşil — likit, erişilebilir para
    const _AssetCategory(
      'Döviz',
      Icons.attach_money_rounded,
      Color(0xFF00D98F),
    ),
    // Altın/Emtia: canlı altın — kıymetli maden, premium
    const _AssetCategory(
      'Altın / Emtia',
      Icons.diamond_outlined,
      Color(0xFFFFAB00),
    ),
    // Nakit: açık yeşil — güvenli, likit
    const _AssetCategory(
      'Nakit',
      Icons.account_balance_wallet_outlined,
      Color(0xFF69F0AE),
    ),
    // Gayrimenkul: canlı kırmızı — fiziksel varlık, somut
    const _AssetCategory('Gayrimenkul', Icons.home_outlined, Color(0xFFFF5252)),
  ];

  List<AssetModel> _assetsForCategory(
    String category,
    List<AssetModel> assets,
  ) {
    switch (category) {
      case 'TEFAS':
        return assets
            .where(
              (a) =>
                  a.type == AssetType.fund &&
                  (a.apiSource == 'tefas' || a.apiSource == 'finance-api'),
            )
            .toList();
      case 'BEFAS':
        return assets
            .where((a) => a.type == AssetType.fund && a.apiSource == 'befas')
            .toList();
      case 'BIST':
        return assets
            .where(
              (a) =>
                  a.type == AssetType.stock &&
                  (a.apiId?.endsWith('.IS') ?? false),
            )
            .toList();
      case 'Yabancı / ETF':
        return assets
            .where(
              (a) =>
                  (a.type == AssetType.stock &&
                      !(a.apiId?.endsWith('.IS') ?? false)) ||
                  (a.type == AssetType.fund && a.apiSource == 'yahoo'),
            )
            .toList();
      case 'Kripto':
        return assets.where((a) => a.type == AssetType.crypto).toList();
      case 'Döviz':
        return assets.where((a) => a.type == AssetType.currency).toList();
      case 'Altın / Emtia':
        return assets.where((a) => a.type == AssetType.commodity).toList();
      case 'Nakit':
        return assets.where((a) => a.type == AssetType.cash).toList();
      case 'Gayrimenkul':
        return assets.where((a) => a.type == AssetType.realEstate).toList();
      default:
        return [];
    }
  }

  Widget _buildAssetsByCategory(
    BuildContext context,
    List<AssetModel> merged,
    Map<String, DailyAssetChange> dailyAssetChanges,
    String displayCurrency,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nonEmpty = _categories
        .map((cat) => (cat, _assetsForCategory(cat.label, merged)))
        .where((pair) => pair.$2.isNotEmpty)
        .toList();

    if (nonEmpty.isEmpty) return const SizedBox.shrink();

    final totalVal = nonEmpty.fold(
      0.0,
      (s, p) => s + p.$2.fold(0.0, (sv, a) => sv + a.currentValue),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Varlıklarım',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkText : AppColors.lightText,
                letterSpacing: -0.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Text(
                '${nonEmpty.length} kategori',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Distribution color bar
        if (totalVal > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 4,
              child: Row(
                children: nonEmpty.map((p) {
                  final pct =
                      p.$2.fold(0.0, (s, a) => s + a.currentValue) / totalVal;
                  return Expanded(
                    flex: (pct * 1000).round().clamp(1, 1000),
                    child: Container(color: p.$1.color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        ...nonEmpty.asMap().entries.map((entry) {
          final cat = entry.value.$1;
          final catAssets = entry.value.$2;
          final catTotal = catAssets.fold(0.0, (s, a) => s + a.currentValue);
          final catPct = totalVal > 0 ? (catTotal / totalVal * 100) : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildCategoryTile(
              context,
              isDark,
              cat,
              catAssets,
              catTotal,
              catPct,
              dailyAssetChanges,
              displayCurrency,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCategoryTile(
    BuildContext context,
    bool isDark,
    _AssetCategory cat,
    List<AssetModel> assets,
    double catTotal,
    double catPct,
    Map<String, DailyAssetChange> dailyAssetChanges,
    String displayCurrency,
  ) {
    final bg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(6, 4, 16, 4),
            childrenPadding: EdgeInsets.zero,
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 3,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cat.color,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(2),
                      bottomRight: Radius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 17),
                ),
              ],
            ),
            title: Text(
              cat.label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            subtitle: Row(
              children: [
                Text(
                  '${assets.length} varlık',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '%${catPct.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: cat.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyUtils.format(catTotal, displayCurrency),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ],
            ),
            children: [
              Divider(height: 1, color: border, indent: 16, endIndent: 16),
              ...assets.map(
                (a) => _buildAssetRow(
                  context,
                  isDark,
                  a,
                  cat.color,
                  dailyAssetChanges[a.symbol],
                  displayCurrency,
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssetRow(
    BuildContext context,
    bool isDark,
    AssetModel asset,
    Color color,
    DailyAssetChange? dailyChange,
    String displayCurrency,
  ) {
    final isDailyReady = dailyChange?.hasPortfolioSnapshot ?? false;
    final isProfit = dailyChange?.isProfit ?? true;
    final plColor = !isDailyReady
        ? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
        : isProfit
        ? AppColors.profit
        : AppColors.loss;
    final dailyText = _dailyAssetChangeText(dailyChange);
    final sym = asset.symbol.length > 6
        ? asset.symbol.substring(0, 6)
        : asset.symbol;
    final qty = asset.quantity % 1 == 0
        ? asset.quantity.toStringAsFixed(0)
        : asset.quantity.toStringAsFixed(4);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              sym,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$qty adet',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyUtils.format(asset.currentValue, displayCurrency),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 118),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: plColor.withValues(alpha: isDailyReady ? 0.1 : 0.07),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      dailyText,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: plColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _dailyAssetChangeText(DailyAssetChange? change) {
    if (change == null || !change.hasPortfolioSnapshot) return '--';
    final amount = change.formatAmount();
    if (!change.hasAssetSnapshot && change.baselineValue == 0) return amount;
    final percentPrefix = change.percent >= 0 ? '+' : '';
    return '$amount · $percentPrefix${change.percent.toStringAsFixed(2)}%';
  }

  // ─────────────── Recent Cashflows ───────────────
  Widget _buildRecentCashflows(
    BuildContext context,
    WidgetRef ref,
    List<CashFlowModel> cashflows,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Son Nakit Akışları',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkText : AppColors.lightText,
                letterSpacing: -0.5,
              ),
            ),
            GestureDetector(
              onTap: () =>
                  ref.read(tabIndexProvider.notifier).setTab(_budgetTabIndex),
              child: Text(
                'Tümünü gör →',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        cashflows.isEmpty
            ? _emptyCard(
                context,
                Icons.swap_vert_rounded,
                'Henüz nakit akışı yok',
                '+ butonundan ekleyebilirsin',
              )
            : Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                ),
                child: Column(
                  children: cashflows.asMap().entries.map((entry) {
                    final i = entry.key;
                    final c = entry.value;
                    final isDeposit = c.type == CashFlowType.deposit;
                    final color = isDeposit ? AppColors.profit : AppColors.loss;
                    final isLast = i == cashflows.length - 1;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: isDeposit
                                    ? BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      )
                                    : BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                child: Icon(
                                  isDeposit
                                      ? Icons.arrow_downward_rounded
                                      : Icons.arrow_upward_rounded,
                                  color: color,
                                  size: 17,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: isDark
                                            ? AppColors.darkText
                                            : AppColors.lightText,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${c.date.day}.${c.date.month}.${c.date.year}'
                                      '${c.currency != 'TRY' ? ' · ${c.currency}' : ''}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${isDeposit ? '+' : '-'}${CurrencyUtils.formatCashFlow(c.amount, c.currency)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          Divider(
                            height: 1,
                            indent: 64,
                            endIndent: 14,
                            color: border,
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
      ],
    );
  }

  // ─────────────── Goal Card ───────────────
  Widget _buildGoalCard(BuildContext context, WidgetRef ref, GoalModel goal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final progress = goal.targetAmount > 0
        ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final remaining = goal.targetAmount - goal.currentAmount;
    final daysLeft = goal.targetDate?.difference(DateTime.now()).inDays;
    final progressPct = (progress * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Aktif Hedef',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkText : AppColors.lightText,
                letterSpacing: -0.5,
              ),
            ),
            GestureDetector(
              onTap: () =>
                  ref.read(tabIndexProvider.notifier).setTab(_goalsTabIndex),
              child: Text(
                'Tümünü gör →',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(goal.emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.lightText,
                          ),
                        ),
                        if (daysLeft != null)
                          Text(
                            daysLeft > 0 ? '$daysLeft gün kaldı' : 'Süre doldu',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: daysLeft <= 30
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: daysLeft <= 0
                                  ? AppColors.loss
                                  : daysLeft <= 30
                                  ? AppColors.loss
                                  : daysLeft <= 180
                                  ? AppColors.gold
                                  : (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        width: 4,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '%$progressPct',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Stack(
                children: [
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF06E8B8)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${CurrencyUtils.symbol(goal.currency)}${CurrencyUtils.formatRaw(goal.currentAmount)} / ${CurrencyUtils.symbol(goal.currency)}${CurrencyUtils.formatRaw(goal.targetAmount)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  Text(
                    '${CurrencyUtils.symbol(goal.currency)}${CurrencyUtils.formatRaw(remaining)} kaldı',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────── Empty Card ───────────────
  Widget _emptyCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color:
                  (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary)
                      .withValues(alpha: 0.4),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────── Stat Card Widget ───────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;
  final Color bg;
  final Color border;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
    required this.bg,
    required this.border,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentColor.withValues(alpha: 0.09), bg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: accentColor, size: 15),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetCategory {
  final String label;
  final IconData icon;
  final Color color;

  const _AssetCategory(this.label, this.icon, this.color);
}
