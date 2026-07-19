import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/asset_model.dart';
import '../../shared/models/portfolio_write_target.dart';
import '../../shared/models/transaction_model.dart';
import '../../shared/providers.dart';
import '../../shared/utils/currency_utils.dart';
import '../../shared/widgets/portfolio_picker.dart';
import 'add_sell_sheet.dart';
import 'edit_asset_screen.dart';

class AssetDetailScreen extends ConsumerWidget {
  /// Portföyde birleştirilmiş (merged) varlık kartı
  final AssetModel mergedAsset;

  const AssetDetailScreen({super.key, required this.mergedAsset});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayCurrency = ref.watch(currencyProvider);
    final transactions = ref.watch(
      transactionsProvider.select(
        (list) => list.where((t) => t.symbol == mergedAsset.symbol).toList(),
      ),
    );
    final allAssets = ref.watch(assetsProvider);
    final lots = allAssets.where((a) => a.symbol == mergedAsset.symbol).toList()
      ..sort(compareAssetLotsForFifo);

    final mergedList = ref.watch(mergedAssetsProvider);
    final current = mergedList.firstWhere(
      (a) => a.symbol == mergedAsset.symbol,
      orElse: () => mergedAsset,
    );

    final color = _colorForAsset(current);

    return Scaffold(
      appBar: AppBar(
        title: Text(mergedAsset.symbol),
        actions: [
          // Düzenle — ilk lotu düzenler (tek lot varsa doğrudan gider)
          if (lots.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Düzenle',
              onPressed: () => _openEditScreen(context, ref, lots),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildSummaryCard(
              context,
              ref,
              displayCurrency,
              color,
              current,
            ),
          ),
          // Lotlar (birden fazlaysa göster)
          if (lots.length > 1) ...[
            SliverToBoxAdapter(
              child: _sectionHeader(context, 'Alış Lotları (${lots.length})'),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _buildLotTile(context, lots[i], color),
                childCount: lots.length,
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: _sectionHeader(
              context,
              'İşlem Geçmişi (${transactions.length})',
            ),
          ),
          transactions.isEmpty
              ? SliverToBoxAdapter(child: _buildEmptyHistory(context))
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) =>
                        _buildTransactionTile(context, transactions[i], color),
                    childCount: transactions.length,
                  ),
                ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      floatingActionButton: current.quantity > 0
          ? FloatingActionButton.extended(
              onPressed: () => _openSellSheet(context, ref),
              backgroundColor: AppColors.loss,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.trending_down_rounded),
              label: const Text(
                'Satış Kaydet',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }

  // ─── Özet kartı ───

  Widget _buildSummaryCard(
    BuildContext context,
    WidgetRef ref,
    String displayCurrency,
    Color color,
    AssetModel current,
  ) {
    final value = current.currentValue;
    final cost = current.totalCost;
    final pl = current.profitLoss;
    final plPct = current.profitLossPercent;
    final isProfit = pl >= 0;
    final plColor = isProfit
        ? AppColors.profitFor(Theme.of(context).brightness)
        : AppColors.loss;

    String fmt(double v) => CurrencyUtils.format(v, displayCurrency);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    current.symbol.length > 4
                        ? current.symbol.substring(0, 4)
                        : current.symbol,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _typeBadgeLabel(current),
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmt(value),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: plColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${isProfit ? '+' : ''}${fmt(pl)} (${plPct.toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: plColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: color.withValues(alpha: 0.2)),
          const SizedBox(height: 14),
          Row(
            children: [
              _statCell(context, 'Miktar', _formatQty(current.quantity)),
              _statCell(
                context,
                'Ort. Maliyet',
                '${current.currency == 'USD' ? '\$' : '₺'}${current.buyPrice.toStringAsFixed(current.buyPrice < 10 ? 4 : 2)}',
              ),
              _statCell(
                context,
                'Güncel Fiyat',
                current.currentPrice != null
                    ? '${current.currency == 'USD' ? '\$' : '₺'}${current.currentPrice!.toStringAsFixed(current.currentPrice! < 10 ? 4 : 2)}'
                    : '—',
              ),
              _statCell(context, 'Toplam Maliyet', fmt(cost)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCell(BuildContext context, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─── Lot tile ───

  Widget _buildLotTile(BuildContext context, AssetModel lot, Color color) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${_formatQty(lot.quantity)} adet  ·  ${lot.buyDate.day}.${lot.buyDate.month}.${lot.buyDate.year}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '${lot.currency == 'USD' ? '\$' : '₺'}${lot.buyPrice.toStringAsFixed(lot.buyPrice < 10 ? 4 : 2)}',
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  // ─── İşlem tile ───

  Widget _buildTransactionTile(
    BuildContext context,
    TransactionModel tx,
    Color color,
  ) {
    final isBuy = tx.type == TransactionType.buy;
    final txColor = isBuy
        ? AppColors.profitFor(Theme.of(context).brightness)
        : AppColors.loss;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: txColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isBuy ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: txColor,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: txColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isBuy ? 'ALIŞ' : 'SATIŞ',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: txColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_formatQty(tx.quantity)} adet',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${tx.date.day}.${tx.date.month}.${tx.date.year}  ·  Fiyat: ${tx.price.toStringAsFixed(tx.price < 10 ? 4 : 2)}',
              style: TextStyle(
                fontSize: 11,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            if (tx.note != null && tx.note!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                tx.note!,
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: theme.textTheme.bodySmall?.color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₺${tx.total.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: txColor,
              ),
            ),
            if (tx.commission != null && tx.commission! > 0)
              Text(
                'Kom: ₺${tx.commission!.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistory(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.history_rounded,
              size: 48,
              color: Theme.of(context).dividerColor,
            ),
            const SizedBox(height: 12),
            Text(
              'Henüz işlem geçmişi yok',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Yeni varlık eklemelerinden itibaren otomatik kaydedilir',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  // ─── Satış sheet'i ───

  Future<void> _openSellSheet(BuildContext context, WidgetRef ref) async {
    final allAssets = ref.read(assetsProvider);
    final lots = allAssets
        .where((a) => a.symbol == mergedAsset.symbol)
        .toList();
    final holdings = portfolioHoldingsForSymbol(
      assets: lots,
      portfolios: ref.read(portfoliosProvider),
      symbol: mergedAsset.symbol,
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
        symbol: mergedAsset.symbol,
        assetName: mergedAsset.name,
        totalQuantity: holding.quantity,
        currentPrice: mergedAsset.currentPrice,
        currency: mergedAsset.currency,
        portfolioId: holding.portfolio.id,
        portfolioName: ref.read(isTotalViewProvider)
            ? holding.portfolio.name
            : null,
      ),
    );
  }

  Future<void> _openEditScreen(
    BuildContext context,
    WidgetRef ref,
    List<AssetModel> lots,
  ) async {
    if (lots.isEmpty) return;
    AssetModel selectedLot = lots.first;
    if (ref.read(isTotalViewProvider) && lots.length > 1) {
      final portfolioNames = {
        for (final portfolio in ref.read(portfoliosProvider))
          portfolio.id: portfolio.name,
      };
      final selected = await showModalBottomSheet<AssetModel>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(sheetContext).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Düzenlenecek Lot',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ...lots.map(
                  (lot) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.receipt_outlined),
                    title: Text(
                      '${_formatQty(lot.quantity)} adet · ${portfolioNames[lot.portfolioId] ?? 'Portföy'}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${lot.buyDate.day}.${lot.buyDate.month}.${lot.buyDate.year}',
                    ),
                    onTap: () => Navigator.pop(sheetContext, lot),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (selected == null || !context.mounted) return;
      selectedLot = selected;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditAssetScreen(asset: selectedLot)),
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

  // ─── Yardımcılar ───

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

  String _typeBadgeLabel(AssetModel a) {
    if (a.type == AssetType.fund) {
      return a.apiSource == 'befas' ? 'BEFAS' : 'TEFAS';
    }
    switch (a.type) {
      case AssetType.stock:
        return a.currency == 'USD' ? 'Yabancı Hisse' : 'BIST Hisse';
      case AssetType.crypto:
        return 'Kripto';
      case AssetType.currency:
        return 'Döviz';
      case AssetType.commodity:
        return 'Emtia';
      case AssetType.cash:
        return 'Nakit';
      case AssetType.realEstate:
        return 'Gayrimenkul';
      default:
        return '';
    }
  }

  String _formatQty(double qty) {
    return qty == qty.truncateToDouble()
        ? qty.toStringAsFixed(0)
        : qty.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '');
  }
}
