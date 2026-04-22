import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/asset_model.dart';
import '../../shared/providers.dart';
import '../../shared/utils/currency_utils.dart';
import 'asset_detail_screen.dart';
import 'edit_asset_screen.dart';

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

enum _SortOption { valueDesc, plDesc, nameAsc }

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  int _selectedFilter = 0;
  _SortOption _sortOption = _SortOption.valueDesc;

  static const _filterLabels = [
    'Tümü',
    'Hisse',
    'Kripto',
    'Döviz/Altın',
    'TEFAS',
    'BEFAS',
    'Nakit/Diğer',
  ];

  static const _categoryColors = {
    AssetType.stock: AppColors.primary,
    AssetType.crypto: Color(0xFFF59E0B),
    AssetType.currency: Color(0xFF10B981),
    AssetType.commodity: AppColors.gold,
    AssetType.fund: Color(0xFF06B6D4),
    AssetType.cash: Color(0xFF66BB6A),
    AssetType.realEstate: Color(0xFFEF5350),
  };

  static const _distColors = {
    'Hisse': AppColors.primary,
    'Kripto': Color(0xFFF59E0B),
    'Döviz/Altın': AppColors.gold,
    'TEFAS': Color(0xFF06B6D4),
    'BEFAS': Color(0xFF00897B),
    'Yabancı/ETF': Color(0xFF185FA5),
    'Nakit': Color(0xFF66BB6A),
    'Diğer': AppColors.silver,
  };

  Color _colorForAsset(AssetModel a) {
    if (a.type == AssetType.fund && a.apiSource == 'befas') {
      return const Color(0xFF00897B);
    }
    return _categoryColors[a.type] ?? AppColors.primary;
  }

  List<AssetModel> _filteredAssets(List<AssetModel> assets) {
    switch (_selectedFilter) {
      case 0:
        return assets;
      case 3:
        return assets
            .where((a) =>
                a.type == AssetType.currency ||
                a.type == AssetType.commodity)
            .toList();
      case 4:
        return assets
            .where((a) =>
                a.type == AssetType.fund &&
                (a.apiSource == 'tefas' ||
                    a.apiSource == 'finance-api'))
            .toList();
      case 5:
        return assets
            .where((a) =>
                a.type == AssetType.fund && a.apiSource == 'befas')
            .toList();
      case 6:
        return assets
            .where((a) =>
                a.type == AssetType.cash ||
                a.type == AssetType.realEstate)
            .toList();
      default:
        final typeMap = {1: AssetType.stock, 2: AssetType.crypto};
        final type = typeMap[_selectedFilter];
        if (type == null) return assets;
        return assets.where((a) => a.type == type).toList();
    }
  }

  List<AssetModel> _sortedAssets(List<AssetModel> assets) {
    final list = List<AssetModel>.from(assets);
    switch (_sortOption) {
      case _SortOption.valueDesc:
        list.sort((a, b) => b.currentValue.compareTo(a.currentValue));
      case _SortOption.plDesc:
        list.sort((a, b) =>
            b.profitLossPercent.compareTo(a.profitLossPercent));
      case _SortOption.nameAsc:
        list.sort((a, b) => a.name.compareTo(b.name));
    }
    return list;
  }

  Map<String, double> _calcDistribution(List<AssetModel> assets) {
    final dist = {
      'Hisse': 0.0,
      'Kripto': 0.0,
      'Döviz/Altın': 0.0,
      'TEFAS': 0.0,
      'BEFAS': 0.0,
      'Yabancı/ETF': 0.0,
      'Nakit': 0.0,
      'Diğer': 0.0,
    };
    for (final a in assets) {
      final v = a.currentValue;
      switch (a.type) {
        case AssetType.stock:
          if (a.apiSource == 'yahoo' &&
              (a.apiId == null || !(a.apiId!.endsWith('.IS')))) {
            dist['Yabancı/ETF'] = dist['Yabancı/ETF']! + v;
          } else {
            dist['Hisse'] = dist['Hisse']! + v;
          }
        case AssetType.crypto:
          dist['Kripto'] = dist['Kripto']! + v;
        case AssetType.currency:
        case AssetType.commodity:
          dist['Döviz/Altın'] = dist['Döviz/Altın']! + v;
        case AssetType.fund:
          if (a.apiSource == 'befas') {
            dist['BEFAS'] = dist['BEFAS']! + v;
          } else if (a.apiSource == 'yahoo') {
            dist['Yabancı/ETF'] = dist['Yabancı/ETF']! + v;
          } else {
            dist['TEFAS'] = dist['TEFAS']! + v;
          }
        case AssetType.cash:
          dist['Nakit'] = dist['Nakit']! + v;
        default:
          dist['Diğer'] = dist['Diğer']! + v;
      }
    }
    return dist;
  }

  List<int> _filterCounts(List<AssetModel> merged) => [
        merged.length,
        merged.where((a) => a.type == AssetType.stock).length,
        merged.where((a) => a.type == AssetType.crypto).length,
        merged
            .where((a) =>
                a.type == AssetType.currency ||
                a.type == AssetType.commodity)
            .length,
        merged
            .where((a) =>
                a.type == AssetType.fund &&
                (a.apiSource == 'tefas' ||
                    a.apiSource == 'finance-api'))
            .length,
        merged
            .where((a) =>
                a.type == AssetType.fund && a.apiSource == 'befas')
            .length,
        merged
            .where((a) =>
                a.type == AssetType.cash ||
                a.type == AssetType.realEstate)
            .length,
      ];

  String _formatQty(double qty) {
    if (qty % 1 == 0) return qty.toStringAsFixed(0);
    return qty.toStringAsFixed(4);
  }

  @override
  Widget build(BuildContext context) {
    final allAssets = ref.watch(assetsProvider);
    final merged = ref.watch(mergedAssetsProvider);
    final filtered = _sortedAssets(_filteredAssets(merged));
    final totalValue = merged.fold(0.0, (s, a) => s + a.currentValue);
    final totalCost = allAssets.fold(0.0, (s, a) => s + a.totalCost);
    final symbolMap = <String, List<AssetModel>>{};
    for (final a in allAssets) {
      symbolMap.putIfAbsent(a.symbol, () => []).add(a);
    }
    final totalPL = totalValue - totalCost;
    final totalPLPct =
        totalCost == 0 ? 0.0 : (totalPL / totalCost) * 100;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayCurrency = ref.watch(currencyProvider);
    final dist = _calcDistribution(merged);
    final filterCounts = _filterCounts(merged);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () =>
              ref.read(priceUpdateProvider.notifier).updatePrices(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                  child: _buildHeader(context, merged.length, isDark)),
              SliverToBoxAdapter(
                child: _buildSummaryCard(
                  context,
                  isDark,
                  totalValue,
                  totalPL,
                  totalPLPct,
                  totalCost,
                  merged.length,
                  displayCurrency,
                ),
              ),
              if (merged.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildDistribution(
                      context, isDark, dist, totalValue, displayCurrency),
                ),
              SliverToBoxAdapter(
                child: _buildFilterChips(context, isDark, filterCounts),
              ),
              if (merged.isEmpty)
                SliverToBoxAdapter(
                    child: _buildEmptyState(context, isDark))
              else if (filtered.isEmpty)
                SliverToBoxAdapter(child: _buildFilteredEmpty(context))
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _buildAssetCard(
                      context,
                      filtered[i],
                      symbolMap[filtered[i].symbol] ?? [],
                      displayCurrency,
                      totalValue,
                      isDark,
                    ),
                    childCount: filtered.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────── Header ───────────────
  Widget _buildHeader(BuildContext context, int count, bool isDark) {
    final isLoading = ref.watch(priceLoadingProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 8, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Portföy',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.2,
                    color:
                        isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                if (count > 0)
                  Text(
                    '$count varlık takip ediliyor',
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
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              ),
            )
          else
            IconButton(
              onPressed: () =>
                  ref.read(priceUpdateProvider.notifier).updatePrices(),
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Fiyatları Güncelle',
            ),
          IconButton(
            onPressed: () => _showSortSheet(context),
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sırala',
          ),
        ],
      ),
    );
  }

  // ─────────────── Summary Card ───────────────
  Widget _buildSummaryCard(
    BuildContext context,
    bool isDark,
    double totalValue,
    double totalPL,
    double totalPLPct,
    double totalCost,
    int count,
    String displayCurrency,
  ) {
    final isProfit = totalPL >= 0;
    final plColor =
        isProfit ? AppColors.profit : AppColors.loss;
    final bg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          children: [
            // Teal top accent
            Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, Color(0xFF06E8B8)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOPLAM PORTFÖY DEĞERİ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          CurrencyUtils.format(
                              totalValue, displayCurrency),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.5,
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.lightText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: plColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isProfit
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              color: plColor,
                              size: 13,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${isProfit ? '+' : ''}${totalPLPct.toStringAsFixed(2)}%',
                              style: TextStyle(
                                color: plColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(height: 1, color: border),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _summaryMetric(
                        isDark,
                        'Yatırılan',
                        CurrencyUtils.format(totalCost, displayCurrency),
                        null,
                        Icons.savings_outlined,
                      ),
                      _summaryDivider(isDark),
                      _summaryMetric(
                        isDark,
                        'Kar / Zarar',
                        '${isProfit ? '+' : '-'}${CurrencyUtils.format(totalPL.abs(), displayCurrency)}',
                        plColor,
                        isProfit
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                      ),
                      _summaryDivider(isDark),
                      _summaryMetric(
                        isDark,
                        'Varlık',
                        '$count adet',
                        null,
                        Icons.account_balance_wallet_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryMetric(bool isDark, String label, String value,
      Color? valueColor, IconData icon) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              icon,
              size: 13,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: valueColor ??
                        (isDark
                            ? AppColors.darkText
                            : AppColors.lightText),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider(bool isDark) {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
    );
  }

  // ─────────────── Distribution ───────────────
  Widget _buildDistribution(
    BuildContext context,
    bool isDark,
    Map<String, double> dist,
    double totalValue,
    String displayCurrency,
  ) {
    final nonZero = dist.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final bg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Varlık Dağılımı',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
                  ),
                ),
                const Spacer(),
                if (nonZero.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${nonZero.length} kategori',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 7,
                child: totalValue == 0
                    ? Container(color: border)
                    : Row(
                        children: nonZero.map((e) {
                          final color =
                              _distColors[e.key] ?? AppColors.silver;
                          return Expanded(
                            flex: e.value
                                .round()
                                .clamp(1, 999999999),
                            child: Container(color: color),
                          );
                        }).toList(),
                      ),
              ),
            ),
            if (nonZero.isEmpty) ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Veri yok',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 14),
              ...nonZero.asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                final pct =
                    totalValue > 0 ? (e.value / totalValue) * 100 : 0.0;
                final color =
                    _distColors[e.key] ?? AppColors.silver;
                return Padding(
                  padding: EdgeInsets.only(
                      bottom: i < nonZero.length - 1 ? 10 : 0),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.key,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? const Color(0xFFD1D5DB)
                                : const Color(0xFF374151),
                          ),
                        ),
                      ),
                      Text(
                        CurrencyUtils.format(e.value, displayCurrency),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 48,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '%${pct.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────── Filter Chips ───────────────
  Widget _buildFilterChips(
      BuildContext context, bool isDark, List<int> counts) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 0, 8),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _filterLabels.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final isSelected = _selectedFilter == index;
            final count = counts[index];
            return GestureDetector(
              onTap: () => setState(() => _selectedFilter = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark
                          ? AppColors.darkCard
                          : AppColors.lightCard),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _filterLabels[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                      ),
                    ),
                    if (count > 0 && index != 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─────────────── Asset Card ───────────────
  Widget _buildAssetCard(
    BuildContext context,
    AssetModel asset,
    List<AssetModel> allForSymbol,
    String displayCurrency,
    double totalValue,
    bool isDark,
  ) {
    final color = _colorForAsset(asset);
    final isProfit = asset.profitLoss >= 0;
    final plColor = isProfit ? AppColors.profit : AppColors.loss;
    final portfolioWeight =
        totalValue > 0 ? (asset.currentValue / totalValue) * 100 : 0.0;
    final badge =
        asset.symbol.length > 5 ? asset.symbol.substring(0, 5) : asset.symbol;
    final badgeFontSize = badge.length > 4 ? 9.0 : 11.0;
    final qtyStr = _formatQty(asset.quantity);
    final bg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    onTap: () => _showAssetDetail(
                      context,
                      asset,
                      allForSymbol,
                      totalValue,
                      displayCurrency,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                badge,
                                style: TextStyle(
                                  fontSize: badgeFontSize,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      asset.symbol,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: isDark
                                            ? AppColors.darkText
                                            : AppColors.lightText,
                                      ),
                                    ),
                                    if (portfolioWeight >= 1) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: color
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '%${portfolioWeight.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  asset.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$qtyStr adet · ${asset.currentPriceDisplay}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                            .withValues(alpha: 0.7)
                                        : AppColors.lightTextSecondary
                                            .withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                CurrencyUtils.format(
                                    asset.currentValue, displayCurrency),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isDark
                                      ? AppColors.darkText
                                      : AppColors.lightText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: plColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${isProfit ? '+' : ''}${asset.profitLossPercent.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: plColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${isProfit ? '+' : '-'}${CurrencyUtils.format(asset.profitLoss.abs(), displayCurrency)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: plColor.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────── Asset Detail Modal ───────────────
  void _showAssetDetail(
    BuildContext context,
    AssetModel asset,
    List<AssetModel> allEntries,
    double totalValue,
    String displayCurrency,
  ) {
    final color = _colorForAsset(asset);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isProfit = asset.profitLoss >= 0;
    final plColor =
        isProfit ? AppColors.profit : AppColors.loss;
    final portfolioWeight =
        totalValue > 0 ? (asset.currentValue / totalValue) * 100 : 0.0;
    final qtyStr = _formatQty(asset.quantity);
    final border =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          asset.symbol.length > 4
                              ? asset.symbol.substring(0, 4)
                              : asset.symbol,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            asset.symbol,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkText
                                  : AppColors.lightText,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            asset.name,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyUtils.format(
                              asset.currentValue, displayCurrency),
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.lightText,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: plColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${isProfit ? '+' : ''}${asset.profitLossPercent.toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: plColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(height: 1, color: border),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _detailMetric(isDark, 'Anlık Fiyat',
                            asset.currentPriceDisplay,
                            Icons.price_change_outlined, color),
                        const SizedBox(width: 10),
                        _detailMetric(
                            isDark,
                            'Miktar',
                            '$qtyStr adet',
                            Icons.layers_outlined,
                            color),
                        const SizedBox(width: 10),
                        _detailMetric(
                          isDark,
                          'Kar/Zarar',
                          '${isProfit ? '+' : '-'}${CurrencyUtils.format(asset.profitLoss.abs(), displayCurrency)}',
                          isProfit
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          plColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _detailMetric(
                            isDark,
                            'Ort. Alış',
                            '${asset.currency == 'USD' ? '\$' : '₺'}${asset.buyPrice.toStringAsFixed(2)}',
                            Icons.receipt_outlined,
                            color),
                        const SizedBox(width: 10),
                        _detailMetric(
                            isDark,
                            'Maliyet',
                            CurrencyUtils.format(
                                asset.totalCost, displayCurrency),
                            Icons.account_balance_wallet_outlined,
                            color),
                        const SizedBox(width: 10),
                        _detailMetric(
                            isDark,
                            'Portföy Payı',
                            '%${portfolioWeight.toStringAsFixed(1)}',
                            Icons.pie_chart_outline_rounded,
                            color),
                      ],
                    ),
                  ],
                ),
              ),
              if (allEntries.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 14,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${allEntries.length} ayrı alım kaydı mevcut',
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
              Padding(
                padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    MediaQuery.of(context).viewPadding.bottom + 20),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AssetDetailScreen(mergedAsset: asset),
                            ),
                          );
                        },
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text('İşlem Geçmişi'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              if (allEntries.length == 1) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EditAssetScreen(
                                        asset: allEntries.first),
                                  ),
                                );
                              } else {
                                _showSelectEntrySheet(
                                    context, allEntries);
                              }
                            },
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Düzenle'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _confirmDeleteAll(
                                  context, asset.symbol, allEntries);
                            },
                            icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18),
                            label: const Text('Sil'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  AppColors.loss.withValues(alpha: 0.1),
                              foregroundColor: AppColors.loss,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailMetric(bool isDark, String title, String value,
      IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: color.withValues(alpha: 0.75)),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
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

  // ─────────────── Sort Sheet ───────────────
  void _showSortSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sırala',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                _sortTile(
                    context,
                    'Değere göre (büyükten küçüğe)',
                    Icons.trending_down_rounded,
                    _SortOption.valueDesc),
                _sortTile(
                    context,
                    'Kar/Zarara göre (büyükten küçüğe)',
                    Icons.percent_rounded,
                    _SortOption.plDesc),
                _sortTile(
                    context,
                    'İsme göre (A → Z)',
                    Icons.sort_by_alpha_rounded,
                    _SortOption.nameAsc),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sortTile(BuildContext context, String label, IconData icon,
      _SortOption option) {
    final isSelected = _sortOption == option;
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? AppColors.primary : null, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontWeight:
              isSelected ? FontWeight.w700 : FontWeight.w400,
          color: isSelected ? AppColors.primary : null,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_rounded,
              color: AppColors.primary, size: 20)
          : null,
      contentPadding: EdgeInsets.zero,
      onTap: () {
        setState(() => _sortOption = option);
        Navigator.pop(context);
      },
    );
  }

  // ─────────────── Select Entry Sheet ───────────────
  void _showSelectEntrySheet(
      BuildContext context, List<AssetModel> entries) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hangi alımı düzenlemek istiyorsun?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 16),
                ...entries.map((entry) {
                  final dateStr =
                      '${entry.buyDate.day}.${entry.buyDate.month}.${entry.buyDate.year}';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.receipt_outlined),
                    title: Text(
                      '${_formatQty(entry.quantity)} adet · ${entry.currency == 'USD' ? '\$' : '₺'}${entry.buyPrice.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '$dateStr${entry.platform != null ? ' · ${entry.platform}' : ''}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing:
                        const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              EditAssetScreen(asset: entry),
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────── Confirm Delete ───────────────
  void _confirmDeleteAll(
      BuildContext context, String symbol, List<AssetModel> entries) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: Text('$symbol Sil',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            '$symbol için ${entries.length} alım kaydını silmek istiyor musun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              final ids = entries.map((e) => e.id).toList();
              await ref.read(assetsProvider.notifier).deleteAll(ids);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$symbol silindi.'),
                    backgroundColor: AppColors.loss,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Sil',
                style: TextStyle(color: AppColors.loss)),
          ),
        ],
      ),
    );
  }

  // ─────────────── Empty States ───────────────
  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color:
                  isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pie_chart_outline_rounded,
                    size: 36, color: AppColors.primary),
              ),
              const SizedBox(height: 18),
              Text(
                'Portföyün henüz boş',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color:
                      isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hisse, kripto, döviz, altın veya fon ekleyerek\nvarlıklarını takip etmeye başla.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilteredEmpty(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.filter_list_off_rounded,
              size: 48,
              color: (isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary)
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'Bu kategoride varlık yok',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color:
                    isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Farklı bir filtre seçin veya varlık ekleyin.',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
