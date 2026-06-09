import '../models/asset_model.dart';

List<String> priceLookupKeysForAsset(AssetModel asset) {
  final baseKey = asset.apiId ?? asset.symbol;
  final source = asset.apiSource ?? 'manual';
  final sources = <String>[source];

  if (source == 'tefas') {
    sources.add('befas');
  } else if (source == 'befas') {
    sources.add('tefas');
  } else if (source == 'finance-api' && asset.type == AssetType.fund) {
    sources.add('tefas');
  }

  return sources.map((candidate) => '${baseKey}_$candidate').toList();
}

T? firstPriceForAsset<T>(AssetModel asset, Map<String, T> prices) {
  for (final key in priceLookupKeysForAsset(asset)) {
    final price = prices[key];
    if (price != null) return price;
  }
  return null;
}
