import 'package:fidus/shared/models/asset_model.dart';
import 'package:fidus/shared/utils/asset_price_lookup.dart';
import 'package:flutter_test/flutter_test.dart';

AssetModel _asset({
  required AssetType type,
  required String apiSource,
  String symbol = 'AAL',
  String? apiId,
}) {
  return AssetModel(
    id: 'asset-1',
    portfolioId: 'portfolio-1',
    name: 'Test Asset',
    symbol: symbol,
    type: type,
    quantity: 1,
    buyPrice: 1,
    buyDate: DateTime(2026, 6, 9),
    apiSource: apiSource,
    apiId: apiId,
  );
}

void main() {
  test('legacy finance-api fund falls back to the TEFAS price key', () {
    final asset = _asset(type: AssetType.fund, apiSource: 'finance-api');
    final keys = priceLookupKeysForAsset(asset);

    expect(keys, ['AAL_finance-api', 'AAL_tefas']);
    expect(firstPriceForAsset(asset, const {'AAL_tefas': 3.27}), 3.27);
  });

  test('exact source remains preferred over a compatibility fallback', () {
    final asset = _asset(type: AssetType.fund, apiSource: 'finance-api');

    expect(
      firstPriceForAsset(asset, const {
        'AAL_finance-api': 3.1,
        'AAL_tefas': 3.27,
      }),
      3.1,
    );
  });

  test('finance-api fallback never applies to non-fund assets', () {
    final keys = priceLookupKeysForAsset(
      _asset(type: AssetType.stock, apiSource: 'finance-api'),
    );

    expect(keys, ['AAL_finance-api']);
  });

  test('current TEFAS and BEFAS compatibility behavior is preserved', () {
    expect(
      priceLookupKeysForAsset(_asset(type: AssetType.fund, apiSource: 'tefas')),
      ['AAL_tefas', 'AAL_befas'],
    );
    expect(
      priceLookupKeysForAsset(_asset(type: AssetType.fund, apiSource: 'befas')),
      ['AAL_befas', 'AAL_tefas'],
    );
  });

  test('price lookup uses api id before the display symbol', () {
    final keys = priceLookupKeysForAsset(
      _asset(
        type: AssetType.fund,
        apiSource: 'finance-api',
        symbol: 'DISPLAY',
        apiId: 'SOURCE-ID',
      ),
    );

    expect(keys, ['SOURCE-ID_finance-api', 'SOURCE-ID_tefas']);
  });
}
