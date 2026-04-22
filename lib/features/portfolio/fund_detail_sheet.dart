import 'package:flutter/material.dart';
import '../../shared/models/tefas_fund_model.dart';
import '../../shared/services/tefas_service.dart';

class FundDetailSheet extends StatefulWidget {
  final TefasFund fund;
  final Color color;
  final VoidCallback onAddToPortfolio;

  const FundDetailSheet({
    super.key,
    required this.fund,
    required this.color,
    required this.onAddToPortfolio,
  });

  @override
  State<FundDetailSheet> createState() => _FundDetailSheetState();
}

class _FundDetailSheetState extends State<FundDetailSheet> {
  TefasFundDetail? _detail;
  bool _loadingDetail = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final d = await TefasService.getFundDetail(
      widget.fund.code,
      isBefas: widget.fund.isBefas,
    );
    if (mounted) setState(() { _detail = d; _loadingDetail = false; });
  }

  TefasFundDetail get _displayFund =>
      _detail ??
      TefasFundDetail(
        code: widget.fund.code,
        name: widget.fund.name,
        price: widget.fund.price,
        type: widget.fund.type,
        category: widget.fund.category,
        return1Week: widget.fund.return1Week,
        return1Month: widget.fund.return1Month,
        return3Month: widget.fund.return3Month,
        return6Month: widget.fund.return6Month,
        return1Year: widget.fund.return1Year,
        returnYtd: widget.fund.returnYtd,
        totalSize: widget.fund.totalSize,
        isBefas: widget.fund.isBefas,
      );

  @override
  Widget build(BuildContext context) {
    final fund = _displayFund;
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      expand: false,
      builder: (context, ctrl) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              _Handle(),
              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  children: [
                    _Header(fund: fund, color: widget.color),
                    const SizedBox(height: 16),
                    _KeyMetrics(
                      fund: fund,
                      color: widget.color,
                      loading: _loadingDetail,
                    ),
                    const SizedBox(height: 16),
                    _Returns(fund: fund),
                    const SizedBox(height: 16),
                    _InfoSection(fund: fund),
                    if (fund.assetDistribution != null &&
                        fund.assetDistribution!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _Distribution(
                          fund: fund, color: widget.color),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              _AddButton(
                color: widget.color,
                onTap: () {
                  Navigator.pop(context);
                  widget.onAddToPortfolio();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ──────────────────────── Handle ────────────────────────

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ──────────────────────── Header ────────────────────────

class _Header extends StatelessWidget {
  final TefasFundDetail fund;
  final Color color;

  const _Header({required this.fund, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            fund.code,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fund.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (fund.isBefas)
                    _Badge(label: 'BEFAS', color: color),
                  if (fund.type != null && fund.type!.isNotEmpty)
                    _Badge(label: fund.type!, color: color),
                  if (fund.category != null && fund.category!.isNotEmpty)
                    _Badge(label: fund.category!, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ──────────────────────── Key Metrics ────────────────────────

class _KeyMetrics extends StatelessWidget {
  final TefasFundDetail fund;
  final Color color;
  final bool loading;

  const _KeyMetrics({
    required this.fund,
    required this.color,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = <(IconData, String, String?, Color?)>[];

    if (fund.price != null) {
      metrics.add((
        Icons.attach_money_rounded,
        'Birim Pay Değeri',
        '₺${fund.price!.toStringAsFixed(fund.price! < 1 ? 6 : 4)}',
        color,
      ));
    }
    if (fund.riskLevel != null) {
      metrics.add((Icons.shield_outlined, 'Risk', '${fund.riskLevel}/7', null));
    }
    if (fund.totalSize != null) {
      metrics.add((
        Icons.account_balance_wallet_outlined,
        'Fon Büyüklüğü',
        _formatSize(fund.totalSize!),
        null,
      ));
    }
    if (fund.founder != null) {
      metrics.add((Icons.business_outlined, 'Kurucu', fund.founder, null));
    }

    if (metrics.isEmpty && loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Birinci satır: fiyat + risk + büyüklük
        if (metrics.isNotEmpty)
          Row(
            children: metrics
                .take(3)
                .map((m) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: m.$1 == Icons.shield_outlined && fund.riskLevel != null
                            ? _RiskCard(risk: fund.riskLevel!)
                            : _MetricCard(
                                icon: m.$1,
                                label: m.$2,
                                value: m.$3 ?? '—',
                                valueColor: m.$4,
                              ),
                      ),
                    ))
                .toList(),
          ),
        // Kurucu varsa ikinci satırda
        if (metrics.length > 3) ...[
          const SizedBox(height: 8),
          Row(
            children: metrics
                .skip(3)
                .map((m) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _MetricCard(
                          icon: m.$1,
                          label: m.$2,
                          value: m.$3 ?? '—',
                          valueColor: m.$4,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  String _formatSize(double size) {
    if (size >= 1e9) return '₺${(size / 1e9).toStringAsFixed(2)} Mr';
    if (size >= 1e6) return '₺${(size / 1e6).toStringAsFixed(1)} Mn';
    if (size >= 1e3) return '₺${(size / 1e3).toStringAsFixed(0)} B';
    return '₺${size.toStringAsFixed(0)}';
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  final int risk;
  const _RiskCard({required this.risk});

  static const _riskColors = [
    Color(0xFF2E7D32),
    Color(0xFF388E3C),
    Color(0xFF8BC34A),
    Color(0xFFFFC107),
    Color(0xFFFF9800),
    Color(0xFFE64A19),
    Color(0xFFB71C1C),
  ];

  Color get _riskColor =>
      risk >= 1 && risk <= 7 ? _riskColors[risk - 1] : Colors.grey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 16, color: Colors.grey[500]),
          const SizedBox(height: 6),
          Text('Risk', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          const SizedBox(height: 6),
          Row(
            children: List.generate(7, (i) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 2),
                  height: 5,
                  decoration: BoxDecoration(
                    color: i < risk
                        ? _riskColor
                        : Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            '$risk / 7',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _riskColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────── Returns ────────────────────────

class _Returns extends StatelessWidget {
  final TefasFundDetail fund;
  const _Returns({required this.fund});

  @override
  Widget build(BuildContext context) {
    final items = <(String, double?)>[
      ('1H', fund.return1Week),
      ('1A', fund.return1Month),
      ('3A', fund.return3Month),
      ('6A', fund.return6Month),
      ('1Y', fund.return1Year),
      ('YBB', fund.returnYtd),
    ].where((e) => e.$2 != null).toList();

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Getiri Oranları',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Row(
          children: items.map((item) {
            final positive = (item.$2 ?? 0) >= 0;
            final c =
                positive ? const Color(0xFF00C853) : const Color(0xFFFF1744);
            return Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Text(item.$1,
                        style:
                            TextStyle(fontSize: 9, color: Colors.grey[600]),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(
                      '${positive ? '+' : ''}${item.$2!.toStringAsFixed(1)}%',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800, color: c),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ──────────────────────── Info Section ────────────────────────

class _InfoSection extends StatelessWidget {
  final TefasFundDetail fund;
  const _InfoSection({required this.fund});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[];
    if (fund.isin != null) rows.add(('ISIN', fund.isin!));
    if (fund.founder != null) rows.add(('Kurucu', fund.founder!));
    if (fund.date != null) rows.add(('Son Güncelleme', fund.date!));
    if (fund.category != null) rows.add(('Kategori', fund.category!));
    if (fund.type != null) rows.add(('Fon Türü', fund.type!));

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fon Bilgileri',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            children: rows
                .map((r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 110,
                            child: Text(r.$1,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500])),
                          ),
                          Expanded(
                            child: Text(r.$2,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────── Asset Distribution ────────────────────────

class _Distribution extends StatelessWidget {
  final TefasFundDetail fund;
  final Color color;

  const _Distribution({required this.fund, required this.color});

  static const _nameMap = {
    'hisse_senedi': 'Hisse Senedi',
    'devlet_tahvili': 'Devlet Tahvili',
    'hazine_bonosu': 'Hazine Bonosu',
    'nakit': 'Nakit ve Benzerleri',
    'eurobond': 'Eurobond',
    'altin': 'Altın',
    'dolar': 'ABD Doları',
    'repo': 'Repo',
    'katilim': 'Katılım Hesabı',
    'kira_sertifikasi': 'Kira Sertifikası',
    'ters_repo': 'Ters Repo',
    'vadeli_mevduat': 'Vadeli Mevduat',
    'hisse': 'Hisse Senedi',
    'tahvil': 'Tahvil/Bono',
    'fon': 'Fon',
  };

  String _friendlyName(String key) =>
      _nameMap[key.toLowerCase()] ??
      key.replaceAll('_', ' ').replaceAllMapped(
          RegExp(r'(\b\w)'),
          (m) => m.group(0)!.toUpperCase());

  @override
  Widget build(BuildContext context) {
    final dist = fund.assetDistribution!;
    final sorted = dist.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Varlık Dağılımı',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            children: sorted.map((e) {
              final pct = e.value.clamp(0.0, 100.0);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _friendlyName(e.key),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '%${pct.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        backgroundColor:
                            Theme.of(context).dividerColor,
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────── Add Button ────────────────────────

class _AddButton extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _AddButton({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Portföye Ekle',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}
