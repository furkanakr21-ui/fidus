import '../../shared/models/asset_model.dart';

class AssetInfo {
  final String symbol;
  final String name;
  final String apiSource;
  final String apiId;
  final String currency;
  final AssetType type;
  final String? unit; // gram, ons, adet vb.

  const AssetInfo({
    required this.symbol,
    required this.name,
    required this.apiSource,
    required this.apiId,
    this.currency = 'TRY',
    required this.type,
    this.unit,
  });
}

class AssetList {
  // BIST — kapsamlı liste (62 hisse, sektöre göre sıralı)
  static const List<AssetInfo> popularBist = [
    // ── Bankacılık ──
    AssetInfo(
      symbol: 'AKBNK',
      name: 'Akbank T.A.Ş.',
      apiSource: 'yahoo',
      apiId: 'AKBNK.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'GARAN',
      name: 'Garanti BBVA',
      apiSource: 'yahoo',
      apiId: 'GARAN.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'ISCTR',
      name: 'Türkiye İş Bankası (C)',
      apiSource: 'yahoo',
      apiId: 'ISCTR.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'VAKBN',
      name: 'T. Vakıflar Bankası',
      apiSource: 'yahoo',
      apiId: 'VAKBN.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'YKBNK',
      name: 'Yapı ve Kredi Bankası',
      apiSource: 'yahoo',
      apiId: 'YKBNK.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'HALKB',
      name: 'Türkiye Halk Bankası',
      apiSource: 'yahoo',
      apiId: 'HALKB.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'ALBRK',
      name: 'Albaraka Türk Katılım Bankası',
      apiSource: 'yahoo',
      apiId: 'ALBRK.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'SKBNK',
      name: 'Şekerbank T.A.Ş.',
      apiSource: 'yahoo',
      apiId: 'SKBNK.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'QNBFB',
      name: 'QNB Finansbank A.Ş.',
      apiSource: 'yahoo',
      apiId: 'QNBFB.IS',
      type: AssetType.stock,
    ),
    // ── Holding ──
    AssetInfo(
      symbol: 'KCHOL',
      name: 'Koç Holding A.Ş.',
      apiSource: 'yahoo',
      apiId: 'KCHOL.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'SAHOL',
      name: 'Sabancı Holding A.Ş.',
      apiSource: 'yahoo',
      apiId: 'SAHOL.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'DOHOL',
      name: 'Doğan Şirketler Grubu',
      apiSource: 'yahoo',
      apiId: 'DOHOL.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'SISE',
      name: 'Türkiye Şişe ve Cam Fab.',
      apiSource: 'yahoo',
      apiId: 'SISE.IS',
      type: AssetType.stock,
    ),
    // ── Otomotiv & Beyaz Eşya ──
    AssetInfo(
      symbol: 'TOASO',
      name: 'Tofaş Türk Otomobil Fab.',
      apiSource: 'yahoo',
      apiId: 'TOASO.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'FROTO',
      name: 'Ford Otosan A.Ş.',
      apiSource: 'yahoo',
      apiId: 'FROTO.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'OTKAR',
      name: 'Otokar Otomotiv ve Savunma',
      apiSource: 'yahoo',
      apiId: 'OTKAR.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'TTRAK',
      name: 'Türk Traktör ve Ziraat Mak.',
      apiSource: 'yahoo',
      apiId: 'TTRAK.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'ARCLK',
      name: 'Arçelik A.Ş.',
      apiSource: 'yahoo',
      apiId: 'ARCLK.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'DOAS',
      name: 'Doğuş Otomotiv Servis',
      apiSource: 'yahoo',
      apiId: 'DOAS.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'TOGG',
      name: 'Togg A.Ş.',
      apiSource: 'yahoo',
      apiId: 'TOGG.IS',
      type: AssetType.stock,
    ),
    // ── Telekomünikasyon ──
    AssetInfo(
      symbol: 'TCELL',
      name: 'Turkcell İletişim Hizmetleri',
      apiSource: 'yahoo',
      apiId: 'TCELL.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'TTKOM',
      name: 'Türk Telekomünikasyon A.Ş.',
      apiSource: 'yahoo',
      apiId: 'TTKOM.IS',
      type: AssetType.stock,
    ),
    // ── Havacılık & Ulaşım ──
    AssetInfo(
      symbol: 'THYAO',
      name: 'Türk Hava Yolları A.O.',
      apiSource: 'yahoo',
      apiId: 'THYAO.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'PGSUS',
      name: 'Pegasus Hava Taşımacılığı',
      apiSource: 'yahoo',
      apiId: 'PGSUS.IS',
      type: AssetType.stock,
    ),
    // ── Enerji ──
    AssetInfo(
      symbol: 'TUPRS',
      name: 'Tüpraş-Türkiye Petrol Raf.',
      apiSource: 'yahoo',
      apiId: 'TUPRS.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'AKSEN',
      name: 'Aksa Enerji Üretim A.Ş.',
      apiSource: 'yahoo',
      apiId: 'AKSEN.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'AYGAZ',
      name: 'Aygaz A.Ş.',
      apiSource: 'yahoo',
      apiId: 'AYGAZ.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'ENJSA',
      name: 'Enerjisa Enerji A.Ş.',
      apiSource: 'yahoo',
      apiId: 'ENJSA.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'ZOREN',
      name: 'Zorlu Enerji Elektrik Üretim',
      apiSource: 'yahoo',
      apiId: 'ZOREN.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'ENKAI',
      name: 'Enka İnşaat ve Sanayi',
      apiSource: 'yahoo',
      apiId: 'ENKAI.IS',
      type: AssetType.stock,
    ),
    // ── Çelik & Madencilik ──
    AssetInfo(
      symbol: 'EREGL',
      name: 'Ereğli Demir ve Çelik',
      apiSource: 'yahoo',
      apiId: 'EREGL.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'KRDMD',
      name: 'Kardemir (D) Karabük Demir',
      apiSource: 'yahoo',
      apiId: 'KRDMD.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'ISDMR',
      name: 'İskenderun Demir ve Çelik',
      apiSource: 'yahoo',
      apiId: 'ISDMR.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'KOZAL',
      name: 'Koza Altın İşletmeleri',
      apiSource: 'yahoo',
      apiId: 'KOZAL.IS',
      type: AssetType.stock,
    ),
    // ── Savunma ──
    AssetInfo(
      symbol: 'ASELS',
      name: 'Aselsan Elektronik San.',
      apiSource: 'yahoo',
      apiId: 'ASELS.IS',
      type: AssetType.stock,
    ),
    // ── Petrokimya ──
    AssetInfo(
      symbol: 'PETKM',
      name: 'Petkim Petrokimya Holding',
      apiSource: 'yahoo',
      apiId: 'PETKM.IS',
      type: AssetType.stock,
    ),
    // ── GYO & İnşaat ──
    AssetInfo(
      symbol: 'EKGYO',
      name: 'Emlak Konut GYO',
      apiSource: 'yahoo',
      apiId: 'EKGYO.IS',
      type: AssetType.stock,
    ),
    // ── Perakende ──
    AssetInfo(
      symbol: 'BIMAS',
      name: 'BİM Birleşik Mağazalar',
      apiSource: 'yahoo',
      apiId: 'BIMAS.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'MGROS',
      name: 'Migros Ticaret A.Ş.',
      apiSource: 'yahoo',
      apiId: 'MGROS.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'SOKM',
      name: 'Şok Marketler Ticaret',
      apiSource: 'yahoo',
      apiId: 'SOKM.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'MAVI',
      name: 'Mavi Giyim Sanayi',
      apiSource: 'yahoo',
      apiId: 'MAVI.IS',
      type: AssetType.stock,
    ),
    // ── Gıda & İçecek ──
    AssetInfo(
      symbol: 'ULKER',
      name: 'Ülker Bisküvi Sanayi',
      apiSource: 'yahoo',
      apiId: 'ULKER.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'CCOLA',
      name: 'Coca-Cola İçecek A.Ş.',
      apiSource: 'yahoo',
      apiId: 'CCOLA.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'AEFES',
      name: 'Anadolu Efes Biracılık',
      apiSource: 'yahoo',
      apiId: 'AEFES.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'TATGD',
      name: 'Tat Gıda Sanayi A.Ş.',
      apiSource: 'yahoo',
      apiId: 'TATGD.IS',
      type: AssetType.stock,
    ),
    // ── Cam & Çimento ──
    AssetInfo(
      symbol: 'TRKCM',
      name: 'Trakya Cam Sanayii',
      apiSource: 'yahoo',
      apiId: 'TRKCM.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'CIMSA',
      name: 'Çimsa Çimento Sanayi',
      apiSource: 'yahoo',
      apiId: 'CIMSA.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'AKCNS',
      name: 'Akçansa Çimento',
      apiSource: 'yahoo',
      apiId: 'AKCNS.IS',
      type: AssetType.stock,
    ),
    // ── İlaç & Sağlık ──
    AssetInfo(
      symbol: 'ECILC',
      name: 'Eczacıbaşı İlaç San. ve Tic.',
      apiSource: 'yahoo',
      apiId: 'ECILC.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'DEVA',
      name: 'Deva Holding A.Ş.',
      apiSource: 'yahoo',
      apiId: 'DEVA.IS',
      type: AssetType.stock,
    ),
    // ── Teknoloji & Yazılım ──
    AssetInfo(
      symbol: 'LOGO',
      name: 'Logo Yazılım Sanayi',
      apiSource: 'yahoo',
      apiId: 'LOGO.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'NETAS',
      name: 'Netaş Telekomünikasyon',
      apiSource: 'yahoo',
      apiId: 'NETAS.IS',
      type: AssetType.stock,
    ),
    // ── Sigorta ──
    AssetInfo(
      symbol: 'ANHYT',
      name: 'Anadolu Hayat Emeklilik',
      apiSource: 'yahoo',
      apiId: 'ANHYT.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'AKGRT',
      name: 'Aksigorta A.Ş.',
      apiSource: 'yahoo',
      apiId: 'AKGRT.IS',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'TURSG',
      name: 'Türkiye Sigorta A.Ş.',
      apiSource: 'yahoo',
      apiId: 'TURSG.IS',
      type: AssetType.stock,
    ),
  ];

  // Yabancı hisse ve ETF popüler
  static const List<AssetInfo> popularForeign = [
    AssetInfo(
      symbol: 'AAPL',
      name: 'Apple',
      apiSource: 'yahoo',
      apiId: 'AAPL',
      currency: 'USD',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'MSFT',
      name: 'Microsoft',
      apiSource: 'yahoo',
      apiId: 'MSFT',
      currency: 'USD',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'NVDA',
      name: 'NVIDIA',
      apiSource: 'yahoo',
      apiId: 'NVDA',
      currency: 'USD',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'TSLA',
      name: 'Tesla',
      apiSource: 'yahoo',
      apiId: 'TSLA',
      currency: 'USD',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'GOOGL',
      name: 'Alphabet',
      apiSource: 'yahoo',
      apiId: 'GOOGL',
      currency: 'USD',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'AMZN',
      name: 'Amazon',
      apiSource: 'yahoo',
      apiId: 'AMZN',
      currency: 'USD',
      type: AssetType.stock,
    ),
    AssetInfo(
      symbol: 'SPY',
      name: 'S&P 500 ETF',
      apiSource: 'yahoo',
      apiId: 'SPY',
      currency: 'USD',
      type: AssetType.fund,
    ),
    AssetInfo(
      symbol: 'QQQ',
      name: 'Nasdaq 100 ETF',
      apiSource: 'yahoo',
      apiId: 'QQQ',
      currency: 'USD',
      type: AssetType.fund,
    ),
  ];

  // Kripto popüler
  static const List<AssetInfo> popularCrypto = [
    AssetInfo(
      symbol: 'BTC',
      name: 'Bitcoin',
      apiSource: 'coingecko',
      apiId: 'bitcoin',
      currency: 'USD',
      type: AssetType.crypto,
    ),
    AssetInfo(
      symbol: 'ETH',
      name: 'Ethereum',
      apiSource: 'coingecko',
      apiId: 'ethereum',
      currency: 'USD',
      type: AssetType.crypto,
    ),
    AssetInfo(
      symbol: 'BNB',
      name: 'BNB',
      apiSource: 'coingecko',
      apiId: 'binancecoin',
      currency: 'USD',
      type: AssetType.crypto,
    ),
    AssetInfo(
      symbol: 'SOL',
      name: 'Solana',
      apiSource: 'coingecko',
      apiId: 'solana',
      currency: 'USD',
      type: AssetType.crypto,
    ),
    AssetInfo(
      symbol: 'XRP',
      name: 'Ripple',
      apiSource: 'coingecko',
      apiId: 'ripple',
      currency: 'USD',
      type: AssetType.crypto,
    ),
    AssetInfo(
      symbol: 'AVAX',
      name: 'Avalanche',
      apiSource: 'coingecko',
      apiId: 'avalanche-2',
      currency: 'USD',
      type: AssetType.crypto,
    ),
    AssetInfo(
      symbol: 'DOGE',
      name: 'Dogecoin',
      apiSource: 'coingecko',
      apiId: 'dogecoin',
      currency: 'USD',
      type: AssetType.crypto,
    ),
    AssetInfo(
      symbol: 'ADA',
      name: 'Cardano',
      apiSource: 'coingecko',
      apiId: 'cardano',
      currency: 'USD',
      type: AssetType.crypto,
    ),
  ];

  // Döviz — hepsi sabit liste
  static const List<AssetInfo> currencies = [
    AssetInfo(
      symbol: 'USD',
      name: 'Amerikan Doları',
      apiSource: 'exchangerate',
      apiId: 'USD',
      type: AssetType.currency,
    ),
    AssetInfo(
      symbol: 'EUR',
      name: 'Euro',
      apiSource: 'exchangerate',
      apiId: 'EUR',
      type: AssetType.currency,
    ),
    AssetInfo(
      symbol: 'GBP',
      name: 'İngiliz Sterlini',
      apiSource: 'exchangerate',
      apiId: 'GBP',
      type: AssetType.currency,
    ),
    AssetInfo(
      symbol: 'CHF',
      name: 'İsviçre Frangı',
      apiSource: 'exchangerate',
      apiId: 'CHF',
      type: AssetType.currency,
    ),
    AssetInfo(
      symbol: 'JPY',
      name: 'Japon Yeni',
      apiSource: 'exchangerate',
      apiId: 'JPY',
      type: AssetType.currency,
    ),
    AssetInfo(
      symbol: 'SAR',
      name: 'Suudi Riyali',
      apiSource: 'exchangerate',
      apiId: 'SAR',
      type: AssetType.currency,
    ),
    AssetInfo(
      symbol: 'AED',
      name: 'BAE Dirhemi',
      apiSource: 'exchangerate',
      apiId: 'AED',
      type: AssetType.currency,
    ),
    AssetInfo(
      symbol: 'CAD',
      name: 'Kanada Doları',
      apiSource: 'exchangerate',
      apiId: 'CAD',
      type: AssetType.currency,
    ),
    AssetInfo(
      symbol: 'AUD',
      name: 'Avustralya Doları',
      apiSource: 'exchangerate',
      apiId: 'AUD',
      type: AssetType.currency,
    ),
    AssetInfo(
      symbol: 'CNY',
      name: 'Çin Yuanı',
      apiSource: 'exchangerate',
      apiId: 'CNY',
      type: AssetType.currency,
    ),
    AssetInfo(
      symbol: 'RUB',
      name: 'Rus Rublesi',
      apiSource: 'exchangerate',
      apiId: 'RUB',
      type: AssetType.currency,
    ),
    AssetInfo(
      symbol: 'NOK',
      name: 'Norveç Kronu',
      apiSource: 'exchangerate',
      apiId: 'NOK',
      type: AssetType.currency,
    ),
  ];

  // Emtia — altın, gümüş, platin, paladyum
  // currency: 'USD' çünkü gold-api USD döndürür
  // buyPrice kullanıcıdan TRY olarak alınır
  // currentPrice USD olarak gelir, usdToTry ile çarpılır
  static const List<AssetInfo> commodities = [
    // Altın
    AssetInfo(
      symbol: 'GRAM_ALTIN',
      name: 'Gram Altın',
      apiSource: 'goldapi',
      apiId: 'XAU_GRAM',
      currency: 'TRY',
      type: AssetType.commodity,
      unit: 'gram',
    ),
    AssetInfo(
      symbol: 'ONS_ALTIN',
      name: 'Ons Altın',
      apiSource: 'goldapi',
      apiId: 'XAU',
      currency: 'USD',
      type: AssetType.commodity,
      unit: 'ons',
    ),
    AssetInfo(
      symbol: 'CEYREK_ALTIN',
      name: 'Çeyrek Altın',
      apiSource: 'goldapi',
      apiId: 'XAU_CEYREK',
      currency: 'TRY',
      type: AssetType.commodity,
      unit: 'adet',
    ),
    AssetInfo(
      symbol: 'YARIM_ALTIN',
      name: 'Yarım Altın',
      apiSource: 'goldapi',
      apiId: 'XAU_YARIM',
      currency: 'TRY',
      type: AssetType.commodity,
      unit: 'adet',
    ),
    AssetInfo(
      symbol: 'TAM_ALTIN',
      name: 'Tam Altın',
      apiSource: 'goldapi',
      apiId: 'XAU_TAM',
      currency: 'TRY',
      type: AssetType.commodity,
      unit: 'adet',
    ),
    AssetInfo(
      symbol: 'CUMHURIYET',
      name: 'Cumhuriyet Altını',
      apiSource: 'goldapi',
      apiId: 'XAU_TAM',
      currency: 'TRY',
      type: AssetType.commodity,
      unit: 'adet',
    ),
    // Gümüş
    AssetInfo(
      symbol: 'GRAM_GUMUS',
      name: 'Gram Gümüş',
      apiSource: 'goldapi',
      apiId: 'XAG_GRAM',
      currency: 'TRY',
      type: AssetType.commodity,
      unit: 'gram',
    ),
    AssetInfo(
      symbol: 'ONS_GUMUS',
      name: 'Ons Gümüş',
      apiSource: 'goldapi',
      apiId: 'XAG',
      currency: 'USD',
      type: AssetType.commodity,
      unit: 'ons',
    ),
    // Platin
    AssetInfo(
      symbol: 'ONS_PLATIN',
      name: 'Ons Platin',
      apiSource: 'goldapi',
      apiId: 'XPT',
      currency: 'USD',
      type: AssetType.commodity,
      unit: 'ons',
    ),
    AssetInfo(
      symbol: 'GRAM_PLATIN',
      name: 'Gram Platin',
      apiSource: 'goldapi',
      apiId: 'XPT_GRAM',
      currency: 'TRY',
      type: AssetType.commodity,
      unit: 'gram',
    ),
    // Paladyum
    AssetInfo(
      symbol: 'ONS_PALADYUM',
      name: 'Ons Paladyum',
      apiSource: 'goldapi',
      apiId: 'XPD',
      currency: 'USD',
      type: AssetType.commodity,
      unit: 'ons',
    ),
    AssetInfo(
      symbol: 'GRAM_PALADYUM',
      name: 'Gram Paladyum',
      apiSource: 'goldapi',
      apiId: 'XPD_GRAM',
      currency: 'TRY',
      type: AssetType.commodity,
      unit: 'gram',
    ),
  ];

  static const Map<String, String> currencyNames = {
    'USD': 'Amerikan Doları',
    'EUR': 'Euro',
    'GBP': 'İngiliz Sterlini',
    'TRY': 'Türk Lirası',
    'CHF': 'İsviçre Frangı',
    'JPY': 'Japon Yeni',
    'CNY': 'Çin Yuanı',
    'CAD': 'Kanada Doları',
    'AUD': 'Avustralya Doları',
    'NZD': 'Yeni Zelanda Doları',
    'SEK': 'İsveç Kronu',
    'NOK': 'Norveç Kronu',
    'DKK': 'Danimarka Kronu',
    'SGD': 'Singapur Doları',
    'HKD': 'Hong Kong Doları',
    'KRW': 'Güney Kore Wonu',
    'INR': 'Hint Rupisi',
    'BRL': 'Brezilya Reali',
    'MXN': 'Meksika Pesosu',
    'ZAR': 'Güney Afrika Randı',
    'RUB': 'Rus Rublesi',
    'SAR': 'Suudi Riyali',
    'AED': 'BAE Dirhemi',
    'QAR': 'Katar Riyali',
    'KWD': 'Kuveyt Dinarı',
    'BHD': 'Bahreyn Dinarı',
    'OMR': 'Umman Riyali',
    'EGP': 'Mısır Poundu',
    'IDR': 'Endonezya Rupisi',
    'THB': 'Tayland Bahtı',
    'MYR': 'Malezya Ringgiti',
    'PHP': 'Filipin Pesosu',
    'PKR': 'Pakistan Rupisi',
    'ILS': 'İsrail Şekeli',
    'CZK': 'Çek Korunası',
    'HUF': 'Macar Forinti',
    'PLN': 'Polonya Zlotisi',
    'RON': 'Romen Leyi',
    'HRK': 'Hırvat Kunası',
    'BGN': 'Bulgar Levası',
    'ISK': 'İzlanda Kronası',
    'TWD': 'Tayvan Doları',
    'CLP': 'Şili Pesosu',
    'COP': 'Kolombiya Pesosu',
    'PEN': 'Peru Solu',
    'ARS': 'Arjantin Pesosu',
    'VND': 'Vietnam Dongu',
    'UAH': 'Ukrayna Grivnası',
    'NGN': 'Nijerya Nirası',
    'KES': 'Kenya Şilingi',
    'GHS': 'Gana Sedisi',
    'MAD': 'Fas Dirhemi',
    'DZD': 'Cezayir Dinarı',
    'TND': 'Tunus Dinarı',
    'JOD': 'Ürdün Dinarı',
    'LBP': 'Lübnan Poundu',
    'IQD': 'Irak Dinarı',
    'IRR': 'İran Riyali',
    'AFN': 'Afgan Afgani',
    'BDT': 'Bangladeş Takası',
    'LKR': 'Sri Lanka Rupisi',
    'NPR': 'Nepal Rupisi',
    'MMK': 'Myanmar Kyatı',
    'KHR': 'Kamboçya Rieli',
    'LAK': 'Laos Kipi',
    'MNT': 'Moğolistan Tugriki',
    'KZT': 'Kazakistan Tengesi',
    'UZS': 'Özbekistan Somu',
    'GEL': 'Gürcistan Larisi',
    'AMD': 'Ermeni Dramı',
    'AZN': 'Azerbaycan Manatı',
  };

  static AssetInfo currencyToAssetInfo(String code) {
    return AssetInfo(
      symbol: code,
      name: currencyNames[code] ?? code,
      apiSource: 'exchangerate',
      apiId: code,
      type: AssetType.currency,
    );
  }

  static List<AssetInfo> getPopular(String key) {
    switch (key) {
      case 'bist':
        return popularBist;
      case 'foreign':
        return popularForeign;
      case 'crypto':
        return popularCrypto;
      case 'currency':
        return currencies;
      case 'commodity':
        return commodities;
      default:
        return [];
    }
  }
}
