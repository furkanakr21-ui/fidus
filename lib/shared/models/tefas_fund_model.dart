double? _pd(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.'));
  return null;
}

int? _pi(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

String _str(dynamic v) => v?.toString() ?? '';

/// Şirket adını temizler: Map, URL, "name:"/"url:" kalıplarını kaldırır.
String _extractCompanyName(dynamic v) {
  if (v == null) return '';
  String raw;
  if (v is Map) {
    // {name: "AK PORTFÖY", url: "https://..."} → sadece name al
    raw = _str(
      v['name'] ?? v['title'] ?? v['kod'] ?? v['code'] ?? v.values.firstOrNull,
    );
  } else {
    raw = _str(v);
  }
  // URL'leri kaldır
  raw = raw.replaceAll(RegExp(r'https?://\S+'), '');
  raw = raw.replaceAll(RegExp(r'www\.\S+'), '');
  // "name:", "url:", "title:" gibi etiketleri kaldır
  raw = raw.replaceAll(
    RegExp(r'\b(name|url|title|kod|code)\s*:\s*', caseSensitive: false),
    '',
  );
  // İçinde URL geçen parantezleri kaldır
  raw = raw.replaceAll(RegExp(r'\([^)]*(?:https?|www)[^)]*\)'), '');
  // Fazla boşluk ve noktalama temizliği
  raw = raw.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  raw = raw.replaceAll(RegExp(r'^[,;\-\s]+|[,;\-\s]+$'), '').trim();
  return raw;
}

List<dynamic> extractFundList(dynamic data) {
  if (data is List) return data;
  if (data is Map) {
    for (final k in [
      'data',
      'funds',
      'result',
      'items',
      'results',
      'list',
      'content',
    ]) {
      if (data[k] is List) return data[k] as List;
      if (data[k] is Map) {
        return [
          data[k],
        ]; // Tekil detay isteğinde dönen data objesini listeye çevirip okumasını sağla
      }
    }
    if (data.isNotEmpty) return [data];
  }
  return [];
}

class TefasFund {
  final String code;
  final String name;
  final double? price;
  final String? type;
  final String? category;
  final double? return1Week;
  final double? return1Month;
  final double? return3Month;
  final double? return6Month;
  final double? return1Year;
  final double? returnYtd;
  final double? totalSize;
  final bool isBefas;

  const TefasFund({
    required this.code,
    required this.name,
    this.price,
    this.type,
    this.category,
    this.return1Week,
    this.return1Month,
    this.return3Month,
    this.return6Month,
    this.return1Year,
    this.returnYtd,
    this.totalSize,
    this.isBefas = false,
  });

  factory TefasFund.fromSupabase(Map<String, dynamic> row) {
    return TefasFund(
      code: row['code'] as String,
      name: row['name'] as String? ?? '',
      price: (row['price'] as num?)?.toDouble(),
      type: row['type'] as String?,
      category: row['category'] as String?,
      return1Week: (row['return_1w'] as num?)?.toDouble(),
      return1Month: (row['return_1m'] as num?)?.toDouble(),
      return3Month: (row['return_3m'] as num?)?.toDouble(),
      return6Month: (row['return_6m'] as num?)?.toDouble(),
      return1Year: (row['return_1y'] as num?)?.toDouble(),
      returnYtd: (row['return_ytd'] as num?)?.toDouble(),
      totalSize: (row['total_size'] as num?)?.toDouble(),
      isBefas: row['is_befas'] as bool? ?? false,
    );
  }

  factory TefasFund.fromJson(
    Map<String, dynamic> json, {
    bool isBefas = false,
  }) {
    final code = _str(
      json['code'] ??
          json['fund_code'] ??
          json['fonKodu'] ??
          json['FonKodu'] ??
          json['FONKODU'] ??
          json['fon_kodu'] ??
          json['key'] ??
          json['fundCode'],
    );
    final name = _str(
      json['title'] ??
          json['name'] ??
          json['fund_name'] ??
          json['fonAdi'] ??
          json['FonAdi'] ??
          json['fon_adi'] ??
          json['fonUnvan'] ??
          json['unvan'] ??
          json['value'] ??
          json['fundName'] ??
          json['company'] ??
          json['kurucu'],
    );
    final type = _str(
      json['fund_type'] ??
          json['type'] ??
          json['fonTuru'] ??
          json['fon_turu'] ??
          json['kategori'] ??
          json['category'] ??
          json['fundType'],
    );

    // fundType=2 → Emeklilik (BEFAS).
    // fundType alanı bazı BEFAS fonlarında API'den hatalı gelebilir (ör. '1').
    // Bu nedenle fundType=2 yoksa isim/tür üzerinden de tespit yapılır.
    final rawFundType = _str(
      json['fundType'] ?? json['fund_type'] ?? json['fonTuru'],
    );
    final isFundTypePension = rawFundType == '2';
    final nameUpper = name.toUpperCase();
    final typeUpper = type.toUpperCase();
    final isPension =
        isFundTypePension ||
        nameUpper.contains('EMEKLİLİK') ||
        nameUpper.contains(' OKS ') ||
        nameUpper.contains(' EYF') ||
        typeUpper.contains('EMEKLİLİK') ||
        typeUpper.contains('PENSION');

    return TefasFund(
      code: code,
      name: name,
      price: _pd(
        json['price'] ??
            json['nav'] ??
            json['navValue'] ??
            json['lastPrice'] ??
            json['last_price'] ??
            json['currentPrice'] ??
            json['current_price'] ??
            json['birimPayDegeri'] ??
            json['BirimPayDegeri'] ??
            json['birim_pay_degeri'] ??
            json['unit_price'] ??
            json['unitPrice'] ??
            json['son_birim_pay'] ??
            json['BirimPay'] ??
            json['fiyat'] ??
            json['sonFiyat'] ??
            json['son_fiyat'] ??
            json['guncelFiyat'] ??
            json['guncel_fiyat'] ??
            json['payFiyat'] ??
            json['pay_fiyat'],
      ),
      type: type.isEmpty ? null : type,
      category: _str(
        json['category'] ?? json['fonKategorisi'] ?? json['fon_kategorisi'],
      ).let((s) => s.isEmpty ? null : s),
      return1Week: _pd(
        json['return1w'] ??
            json['return_1_week'] ??
            json['week1'] ??
            json['haftalik'] ??
            json['w1'] ??
            json['haftaIci'],
      ),
      return1Month: _pd(
        json['return1m'] ??
            json['return_1_month'] ??
            json['month1'] ??
            json['aylik'] ??
            json['m1'] ??
            json['bir_ay'],
      ),
      return3Month: _pd(
        json['return3m'] ??
            json['return_3_month'] ??
            json['month3'] ??
            json['uc_aylik'] ??
            json['m3'] ??
            json['uc_ay'],
      ),
      return6Month: _pd(
        json['return6m'] ??
            json['return_6_month'] ??
            json['month6'] ??
            json['alti_aylik'] ??
            json['m6'] ??
            json['alti_ay'],
      ),
      return1Year: _pd(
        json['return1y'] ??
            json['return_1_year'] ??
            json['year1'] ??
            json['yillik'] ??
            json['y1'] ??
            json['bir_yil'],
      ),
      returnYtd: _pd(
        json['returnYtd'] ??
            json['return_ytd'] ??
            json['ytd'] ??
            json['yil_basi'] ??
            json['yilBasi'],
      ),
      totalSize: _pd(
        json['total_size'] ??
            json['fund_size'] ??
            json['fonBuyuklugu'] ??
            json['buyukluk'] ??
            json['size'],
      ),
      isBefas:
          isBefas ||
          isPension, // Eğer emeklilik fonuysa doğrudan BEFAS sekmesine gönder
    );
  }
}

extension _LetExt<T> on T {
  R let<R>(R Function(T) block) => block(this);
}

// ──────────────────────── Tarihsel Fiyat Kaydı ────────────────────────

class TefasFundHistoryEntry {
  final DateTime date;
  final double price;

  const TefasFundHistoryEntry({required this.date, required this.price});

  factory TefasFundHistoryEntry.fromJson(Map<String, dynamic> json) {
    // Tarih alanı — birçok format dene
    DateTime date = DateTime.now();
    final dateRaw = _str(
      json['date'] ??
          json['tarih'] ??
          json['fon_tarihi'] ??
          json['reportDate'] ??
          json['report_date'] ??
          json['valueDate'] ??
          json['value_date'],
    );
    if (dateRaw.isNotEmpty) {
      try {
        // ISO: 2026-04-15 veya 2026-04-15T00:00:00
        date = DateTime.parse(dateRaw);
      } catch (_) {
        try {
          // Türk: 15.04.2026
          final parts = dateRaw.split('.');
          if (parts.length == 3) {
            date = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          }
        } catch (_) {}
      }
    }

    final price = _pd(
      json['price'] ??
          json['nav'] ??
          json['birimPayDegeri'] ??
          json['BirimPayDegeri'] ??
          json['birim_pay_degeri'] ??
          json['lastPrice'] ??
          json['last_price'] ??
          json['fiyat'] ??
          json['sonFiyat'] ??
          json['son_fiyat'],
    );

    return TefasFundHistoryEntry(date: date, price: price ?? 0.0);
  }
}

class TefasFundDetail extends TefasFund {
  final String? isin;
  final int? riskLevel;
  final Map<String, double>? assetDistribution;
  final String? date;
  final String? founder;

  const TefasFundDetail({
    required super.code,
    required super.name,
    super.price,
    super.type,
    super.category,
    super.return1Week,
    super.return1Month,
    super.return3Month,
    super.return6Month,
    super.return1Year,
    super.returnYtd,
    super.totalSize,
    super.isBefas,
    this.isin,
    this.riskLevel,
    this.assetDistribution,
    this.date,
    this.founder,
  });

  factory TefasFundDetail.fromMerged(
    Map<String, dynamic> json,
    String fallbackCode, {
    bool isBefas = false,
  }) {
    final base = TefasFund.fromJson(json, isBefas: isBefas);

    Map<String, double>? dist;
    final distRaw =
        json['asset_distribution'] ??
        json['assetDistribution'] ??
        json['varlik_dagilimi'] ??
        json['dagılım'];
    if (distRaw is Map) {
      dist = {};
      distRaw.forEach((k, v) {
        final val = _pd(v);
        if (val != null && val > 0) dist![k.toString()] = val;
      });
      if (dist.isEmpty) dist = null;
    }

    final isin = _str(json['isin'] ?? json['ISIN'] ?? json['isinKodu']);

    // Şirket adı: Map gelebilir ({name: ..., url: ...}), String de gelebilir
    final founder = _extractCompanyName(
      json['founder'] ??
          json['kurucusu'] ??
          json['company'] ??
          json['kurulus'] ??
          json['portfoyYoneticisi'],
    );

    final date = _str(json['date'] ?? json['tarih'] ?? json['son_tarih']);

    return TefasFundDetail(
      code: base.code.isEmpty ? fallbackCode : base.code,
      name: base.name,
      price: base.price,
      type: base.type,
      category: base.category,
      return1Week: base.return1Week,
      return1Month: base.return1Month,
      return3Month: base.return3Month,
      return6Month: base.return6Month,
      return1Year: base.return1Year,
      returnYtd: base.returnYtd,
      totalSize: base.totalSize,
      isBefas: isBefas,
      isin: isin.isEmpty ? null : isin,
      riskLevel: _pi(json['risk_value'] ?? json['riskDegeri'] ?? json['risk']),
      assetDistribution: dist,
      date: date.isEmpty ? null : date,
      founder: founder.isEmpty ? null : founder,
    );
  }
}
