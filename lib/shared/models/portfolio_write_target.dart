import '../../core/constants/app_constants.dart';
import 'asset_model.dart';
import 'portfolio_model.dart';

String? resolveWritePortfolioId({
  required String activePortfolioId,
  String? selectedPortfolioId,
}) {
  final candidate = activePortfolioId == kTotalPortfolioId
      ? selectedPortfolioId
      : activePortfolioId;
  if (candidate == null ||
      candidate.isEmpty ||
      candidate == kTotalPortfolioId) {
    return null;
  }
  return candidate;
}

String? resolveSymbolWritePortfolioId({
  required String activePortfolioId,
  required List<PortfolioHolding> holdings,
  String? selectedPortfolioId,
}) {
  if (activePortfolioId != kTotalPortfolioId) {
    return resolveWritePortfolioId(activePortfolioId: activePortfolioId);
  }
  if (holdings.length == 1) return holdings.single.portfolio.id;
  if (selectedPortfolioId != null &&
      holdings.any((holding) => holding.portfolio.id == selectedPortfolioId)) {
    return selectedPortfolioId;
  }
  return null;
}

class PortfolioHolding {
  final PortfolioModel portfolio;
  final double quantity;
  final int lotCount;

  const PortfolioHolding({
    required this.portfolio,
    required this.quantity,
    required this.lotCount,
  });
}

List<PortfolioHolding> portfolioHoldingsForSymbol({
  required List<AssetModel> assets,
  required List<PortfolioModel> portfolios,
  required String symbol,
}) {
  final lotsByPortfolio = <String, List<AssetModel>>{};
  for (final asset in assets) {
    if (asset.symbol != symbol || asset.quantity <= 0) continue;
    lotsByPortfolio.putIfAbsent(asset.portfolioId, () => []).add(asset);
  }

  return [
    for (final portfolio in portfolios)
      if (lotsByPortfolio[portfolio.id] case final lots?)
        PortfolioHolding(
          portfolio: portfolio,
          quantity: lots.fold(0, (sum, lot) => sum + lot.quantity),
          lotCount: lots.length,
        ),
  ];
}

int compareAssetLotsForFifo(AssetModel a, AssetModel b) {
  final byBuyDate = a.buyDate.compareTo(b.buyDate);
  if (byBuyDate != 0) return byBuyDate;
  final aCreatedAt = a.createdAt;
  final bCreatedAt = b.createdAt;
  if (aCreatedAt != null && bCreatedAt != null) {
    final byCreatedAt = aCreatedAt.compareTo(bCreatedAt);
    if (byCreatedAt != 0) return byCreatedAt;
  } else if (aCreatedAt != null) {
    return -1;
  } else if (bCreatedAt != null) {
    return 1;
  }
  return a.id.compareTo(b.id);
}
