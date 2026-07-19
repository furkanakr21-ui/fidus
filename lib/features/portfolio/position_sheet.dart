import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/asset_model.dart';
import '../../shared/models/portfolio_write_target.dart';
import '../../shared/providers.dart';
import '../../shared/utils/currency_utils.dart';
import '../../shared/widgets/portfolio_picker.dart';
import 'add_buy_sheet.dart';
import 'add_sell_sheet.dart';
import 'asset_detail_screen.dart';
import 'edit_asset_screen.dart';

class PositionSheet extends ConsumerWidget {
  final AssetModel mergedAsset;
  final List<AssetModel> allLots;
  final double portfolioWeight;

  const PositionSheet({
    super.key,
    required this.mergedAsset,
    required this.allLots,
    required this.portfolioWeight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mergedList = ref.watch(mergedAssetsProvider);
    final current = mergedList.firstWhere(
      (a) => a.symbol == mergedAsset.symbol,
      orElse: () => mergedAsset,
    );
    final lots =
        ref
            .watch(assetsProvider)
            .where((a) => a.symbol == mergedAsset.symbol)
            .toList()
          ..sort(compareAssetLotsForFifo);
    final portfolios = ref.watch(portfoliosProvider);
    final isTotalView = ref.watch(isTotalViewProvider);
    final holdings = portfolioHoldingsForSymbol(
      assets: lots,
      portfolios: portfolios,
      symbol: mergedAsset.symbol,
    );

    final displayCurrency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _colorForAsset(current);
    final isProfit = current.profitLoss >= 0;
    final plColor = isProfit
        ? AppColors.profitFor(Theme.of(context).brightness)
        : AppColors.loss;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            // Header: ikon + isim + edit/delete
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Center(
                      child: Text(
                        current.symbol.length > 4
                            ? current.symbol.substring(0, 4)
                            : current.symbol,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          current.symbol,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.lightText,
                          ),
                        ),
                        Text(
                          current.name,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Düzenle',
                    onPressed: () => _onEdit(context, ref, lots),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: AppColors.loss.withValues(alpha: 0.75),
                    ),
                    tooltip: 'Sil',
                    onPressed: () => _onDelete(context, ref, current, lots),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Değer + K/Z satırı
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyUtils.format(current.currentValue, displayCurrency),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                      letterSpacing: -1,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: plColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${isProfit ? '+' : ''}${CurrencyUtils.format(current.profitLoss, displayCurrency)} (${current.profitLossPercent.toStringAsFixed(2)}%)',
                        style: TextStyle(
                          color: plColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(height: 1, color: border),
            ),
            // İstatistik grid
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  _statCell(
                    context,
                    isDark,
                    'Miktar',
                    _formatQty(current.quantity),
                  ),
                  _statCell(
                    context,
                    isDark,
                    'Ort. Maliyet',
                    '${current.currency == 'USD' ? '\$' : '₺'}${current.buyPrice.toStringAsFixed(current.buyPrice < 10 ? 4 : 2)}',
                  ),
                  _statCell(
                    context,
                    isDark,
                    'Güncel',
                    current.currentPrice != null
                        ? '${current.currency == 'USD' ? '\$' : '₺'}${current.currentPrice!.toStringAsFixed(current.currentPrice! < 10 ? 4 : 2)}'
                        : '—',
                  ),
                  _statCell(
                    context,
                    isDark,
                    'Maliyet',
                    CurrencyUtils.format(current.totalCost, displayCurrency),
                  ),
                ],
              ),
            ),
            if (lots.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
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
                      isTotalView
                          ? '${lots.length} alım lotu · ${holdings.length} portföy · Portföy payı %${portfolioWeight.toStringAsFixed(1)}'
                          : '${lots.length} ayrı alım lotu · Portföy payı %${portfolioWeight.toStringAsFixed(1)}',
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Container(height: 1, color: border),
            ),
            // Alış / Satış butonları
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openAddBuy(context, current),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Alış Ekle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.profitFor(
                          Theme.of(context).brightness,
                        ).withValues(alpha: 0.12),
                        foregroundColor: AppColors.profitFor(
                          Theme.of(context).brightness,
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: current.quantity > 0
                          ? () => _openSell(context, ref, current, lots)
                          : null,
                      icon: const Icon(Icons.remove_rounded, size: 18),
                      label: const Text('Satış Kaydet'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.loss.withValues(alpha: 0.12),
                        foregroundColor: AppColors.loss,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // İşlem Geçmişi butonu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AssetDetailScreen(mergedAsset: current),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: const Text('İşlem Geçmişi'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _statCell(
    BuildContext context,
    bool isDark,
    String label,
    String value,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _openAddBuy(BuildContext context, AssetModel current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddBuySheet(mergedAsset: current),
    );
  }

  Future<void> _openSell(
    BuildContext context,
    WidgetRef ref,
    AssetModel current,
    List<AssetModel> lots,
  ) async {
    final holdings = portfolioHoldingsForSymbol(
      assets: lots,
      portfolios: ref.read(portfoliosProvider),
      symbol: current.symbol,
    );
    final holding = await _selectHolding(
      context,
      ref,
      holdings,
      title: 'Satış Portföyü',
    );
    if (holding == null || !context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSellSheet(
        symbol: current.symbol,
        assetName: current.name,
        totalQuantity: holding.quantity,
        currentPrice: current.currentPrice,
        currency: current.currency,
        portfolioId: holding.portfolio.id,
        portfolioName: ref.read(isTotalViewProvider)
            ? holding.portfolio.name
            : null,
      ),
    );
  }

  void _onEdit(BuildContext context, WidgetRef ref, List<AssetModel> lots) {
    if (lots.isEmpty) return;
    if (lots.length == 1) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EditAssetScreen(asset: lots.first)),
      );
    } else {
      _showSelectLotSheet(context, ref, lots);
    }
  }

  void _showSelectLotSheet(
    BuildContext context,
    WidgetRef ref,
    List<AssetModel> lots,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTotalView = ref.read(isTotalViewProvider);
    final portfolioNames = {
      for (final portfolio in ref.read(portfoliosProvider))
        portfolio.id: portfolio.name,
    };
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hangi lotu düzenlemek istiyorsun?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 16),
              ...lots.map((lot) {
                final dateStr =
                    '${lot.buyDate.day}.${lot.buyDate.month}.${lot.buyDate.year}';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.receipt_outlined),
                  title: Text(
                    '${_formatQty(lot.quantity)} adet · ${lot.currency == 'USD' ? '\$' : '₺'}${lot.buyPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isTotalView
                        ? '$dateStr · ${portfolioNames[lot.portfolioId] ?? 'Portföy'}'
                        : dateStr,
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditAssetScreen(asset: lot),
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onDelete(
    BuildContext context,
    WidgetRef ref,
    AssetModel current,
    List<AssetModel> lots,
  ) async {
    final isTotalView = ref.read(isTotalViewProvider);
    final holdings = portfolioHoldingsForSymbol(
      assets: lots,
      portfolios: ref.read(portfoliosProvider),
      symbol: current.symbol,
    );
    final holding = await _selectHolding(
      context,
      ref,
      holdings,
      title: 'Silinecek Portföy',
    );
    if (holding == null || !context.mounted) return;
    final targetLots = lots
        .where((lot) => lot.portfolioId == holding.portfolio.id)
        .toList(growable: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          '${current.symbol} Sil',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          isTotalView
              ? '${holding.portfolio.name} portföyündeki ${targetLots.length} alım kaydı silinecek. Devam etmek istiyor musun?'
              : '${current.symbol} için ${targetLots.length} alım kaydını silmek istiyor musun?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              final ids = targetLots.map((e) => e.id).toList();
              await ref.read(assetsProvider.notifier).deleteAll(ids);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!context.mounted) return;
              final messenger = ScaffoldMessenger.of(context);
              final symbol = current.symbol;
              Navigator.pop(context);
              messenger.showSnackBar(
                SnackBar(
                  content: Text('$symbol silindi.'),
                  backgroundColor: AppColors.loss,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Sil', style: TextStyle(color: AppColors.loss)),
          ),
        ],
      ),
    );
  }

  Future<PortfolioHolding?> _selectHolding(
    BuildContext context,
    WidgetRef ref,
    List<PortfolioHolding> holdings, {
    required String title,
  }) async {
    if (holdings.isEmpty) return null;
    if (!ref.read(isTotalViewProvider) || holdings.length == 1) {
      return holdings.first;
    }
    final portfolio = await showPortfolioPicker(
      context,
      portfolios: holdings
          .map((holding) => holding.portfolio)
          .toList(growable: false),
      title: title,
    );
    if (portfolio == null) return null;
    return holdings.firstWhere(
      (holding) => holding.portfolio.id == portfolio.id,
    );
  }

  Color _colorForAsset(AssetModel a) {
    const colors = {
      AssetType.stock: AppColors.market,
      AssetType.crypto: AppColors.cashFlow,
      AssetType.currency: AppColors.profit,
      AssetType.commodity: AppColors.cashFlow,
      AssetType.fund: AppColors.planning,
      AssetType.cash: AppColors.profit,
      AssetType.realEstate: AppColors.planning,
    };
    if (a.type == AssetType.fund && a.apiSource == 'befas') {
      return AppColors.planning;
    }
    return colors[a.type] ?? AppColors.market;
  }

  String _formatQty(double qty) {
    return qty == qty.truncateToDouble()
        ? qty.toStringAsFixed(0)
        : qty.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '');
  }
}
