import '../../core/constants/app_constants.dart';

enum PortfolioScopeKind { empty, single, total }

class PortfolioScope {
  final PortfolioScopeKind kind;
  final List<String> portfolioIds;

  PortfolioScope._(this.kind, Iterable<String> portfolioIds)
    : portfolioIds = List.unmodifiable(portfolioIds);

  factory PortfolioScope.empty() {
    return PortfolioScope._(PortfolioScopeKind.empty, const []);
  }

  factory PortfolioScope.single(String portfolioId) {
    if (portfolioId.isEmpty || portfolioId == kTotalPortfolioId) {
      return PortfolioScope.empty();
    }
    return PortfolioScope._(PortfolioScopeKind.single, [portfolioId]);
  }

  factory PortfolioScope.total(Iterable<String> portfolioIds) {
    final uniqueIds = portfolioIds.toSet().toList()..sort();
    return PortfolioScope._(PortfolioScopeKind.total, uniqueIds);
  }

  bool get isEmpty => portfolioIds.isEmpty;
  bool get isTotal => kind == PortfolioScopeKind.total;
  String? get singlePortfolioId =>
      kind == PortfolioScopeKind.single ? portfolioIds.single : null;

  String get channelKey {
    if (kind == PortfolioScopeKind.empty) return 'empty';
    if (kind == PortfolioScopeKind.single) return portfolioIds.single;
    return 'total_${Object.hashAll(portfolioIds)}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PortfolioScope ||
        kind != other.kind ||
        portfolioIds.length != other.portfolioIds.length) {
      return false;
    }
    for (var i = 0; i < portfolioIds.length; i++) {
      if (portfolioIds[i] != other.portfolioIds[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(kind, Object.hashAll(portfolioIds));
}
