import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/income_expense_model.dart';
import '../../shared/providers.dart';
import '../../shared/utils/currency_utils.dart';
import 'cashflow_detail_sheet.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashflows = ref.watch(cashflowProvider);
    final sorted = [...cashflows]..sort((a, b) => b.date.compareTo(a.date));

    final totalDeposit = cashflows
        .where((c) => c.type == CashFlowType.deposit)
        .fold(
          0.0,
          (sum, c) =>
              sum +
              CurrencyUtils.cashFlowToTry(
                c.amount,
                c.currency,
                rateAtEntry: c.rateAtEntry,
              ),
        );
    final totalWithdrawal = cashflows
        .where((c) => c.type == CashFlowType.withdrawal)
        .fold(
          0.0,
          (sum, c) =>
              sum +
              CurrencyUtils.cashFlowToTry(
                c.amount,
                c.currency,
                rateAtEntry: c.rateAtEntry,
              ),
        );
    final netFlow = totalDeposit - totalWithdrawal;
    final isPositive = netFlow >= 0;

    final Map<String, List<CashFlowModel>> grouped = {};
    for (final c in sorted) {
      final key = '${c.date.year}-${c.date.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(c);
    }
    final months = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.cashFlow,
          onRefresh: () async => ref.read(cashflowProvider.notifier).load(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverToBoxAdapter(
                child: _buildSummaryCard(
                  context,
                  netFlow,
                  totalDeposit,
                  totalWithdrawal,
                  cashflows.length,
                  isPositive,
                ),
              ),
              cashflows.isEmpty
                  ? SliverToBoxAdapter(child: _buildEmptyState(context))
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildMonthGroup(
                          context,
                          ref,
                          months[index],
                          grouped[months[index]]!,
                        ),
                        childCount: months.length,
                      ),
                    ),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nakit Akışı',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          Text(
            'Portföye giriş ve çıkışlar',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    double netFlow,
    double totalDeposit,
    double totalWithdrawal,
    int count,
    bool isPositive,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final netColor = isPositive
        ? AppColors.profitFor(Theme.of(context).brightness)
        : AppColors.loss;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        key: const Key('cash-flow-summary-card'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [
                    Color(0xFF4A3910),
                    Color(0xFF80620A),
                    Color(0xFFB88B00),
                  ]
                : const [
                    Color(0xFFFFF3D6),
                    Color(0xFFFFE6AD),
                    Color(0xFFF8D486),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? AppColors.cashFlow.withValues(alpha: 0.3)
                : AppColors.cashFlow.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NET NAKİT AKIŞI',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          '${isPositive ? '+' : ''}₺${CurrencyUtils.formatRaw(netFlow)}',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.lightText,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.5,
                            height: 1.0,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: netColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositive
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              color: netColor,
                              size: 13,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              isPositive ? 'Pozitif' : 'Negatif',
                              style: TextStyle(
                                color: netColor,
                                fontSize: 12,
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
                      _summaryCell(
                        context,
                        isDark,
                        'Toplam Giriş',
                        '₺${CurrencyUtils.formatRaw(totalDeposit)}',
                        AppColors.profitFor(Theme.of(context).brightness),
                      ),
                      _cellDivider(isDark),
                      _summaryCell(
                        context,
                        isDark,
                        'Toplam Çıkış',
                        '₺${CurrencyUtils.formatRaw(totalWithdrawal)}',
                        AppColors.loss,
                      ),
                      _cellDivider(isDark),
                      _summaryCell(
                        context,
                        isDark,
                        'İşlem',
                        '$count adet',
                        isDark ? AppColors.darkText : AppColors.lightText,
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

  Widget _summaryCell(
    BuildContext context,
    bool isDark,
    String label,
    String value,
    Color accent,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cellDivider(bool isDark) => Container(
    width: 1,
    height: 32,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
  );

  Widget _buildMonthGroup(
    BuildContext context,
    WidgetRef ref,
    String monthKey,
    List<CashFlowModel> items,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parts = monthKey.split('-');
    final month = int.parse(parts[1]);
    const months = [
      '',
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    final label = '${months[month]} ${parts[0]}';
    final deposit = items
        .where((c) => c.type == CashFlowType.deposit)
        .fold(
          0.0,
          (sum, c) =>
              sum +
              CurrencyUtils.cashFlowToTry(
                c.amount,
                c.currency,
                rateAtEntry: c.rateAtEntry,
              ),
        );
    final withdrawal = items
        .where((c) => c.type == CashFlowType.withdrawal)
        .fold(
          0.0,
          (sum, c) =>
              sum +
              CurrencyUtils.cashFlowToTry(
                c.amount,
                c.currency,
                rateAtEntry: c.rateAtEntry,
              ),
        );
    final net = deposit - withdrawal;
    final isPositive = net >= 0;
    final netColor = isPositive
        ? AppColors.profitFor(Theme.of(context).brightness)
        : AppColors.loss;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                    letterSpacing: -0.3,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: netColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: netColor.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    '${isPositive ? '+' : ''}₺${CurrencyUtils.formatRaw(net)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: netColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...items.map((c) => _buildCashFlowCard(context, ref, c)),
        ],
      ),
    );
  }

  Widget _buildCashFlowCard(
    BuildContext context,
    WidgetRef ref,
    CashFlowModel cashflow,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDeposit = cashflow.type == CashFlowType.deposit;
    final color = isDeposit
        ? AppColors.profitFor(Theme.of(context).brightness)
        : AppColors.loss;
    final bg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => CashFlowDetailSheet.show(context, cashflow),
        onLongPress: () => _confirmDelete(context, ref, cashflow.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: isDeposit
                    ? BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      )
                    : BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(11),
                      ),
                child: Icon(
                  isDeposit
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cashflow.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${isDeposit ? 'Giriş' : 'Çıkış'} · ${cashflow.date.day}.${cashflow.date.month}.${cashflow.date.year}'
                      '${cashflow.currency != 'TRY' ? ' · ${cashflow.currency}' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    if (cashflow.note != null && cashflow.note!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        cashflow.note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '${isDeposit ? '+' : '-'}${CurrencyUtils.formatCashFlow(cashflow.amount, cashflow.currency)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.cashFlow.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.swap_vert_rounded,
                size: 36,
                color: AppColors.cashFlow,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Nakit akışı yok',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '+ butonundan ekleyebilirsin.',
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

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Sil', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Bu işlemi silmek istiyor musun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(cashflowProvider.notifier).delete(id);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Sil', style: TextStyle(color: AppColors.loss)),
          ),
        ],
      ),
    );
  }
}
