import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/income_expense_model.dart';
import '../../shared/providers.dart';
import '../../shared/utils/currency_utils.dart';

class CashFlowDetailSheet extends ConsumerWidget {
  final CashFlowModel cashflow;

  const CashFlowDetailSheet({super.key, required this.cashflow});

  static Future<void> show(BuildContext context, CashFlowModel cashflow) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CashFlowDetailSheet(cashflow: cashflow),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDeposit = cashflow.type == CashFlowType.deposit;
    final color = isDeposit
        ? AppColors.profitFor(Theme.of(context).brightness)
        : AppColors.loss;
    final textPrimary = isDark ? AppColors.darkText : AppColors.lightText;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final date = cashflow.date;
    final note = cashflow.note;
    final hasNote = note != null && note.isNotEmpty;
    final amountInTry = cashflow.amountInTry;

    return Container(
      key: const Key('cashflow-detail-sheet'),
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
            // Başlık: ikon + isim + tür/tarih
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: isDeposit
                        ? BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          )
                        : BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(13),
                          ),
                    child: Icon(
                      isDeposit
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      color: color,
                      size: 20,
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
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${isDeposit ? 'Giriş' : 'Çıkış'} · ${date.day}.${date.month}.${date.year}'
                          '${cashflow.currency != 'TRY' ? ' · ${cashflow.currency}' : ''}',
                          style: TextStyle(fontSize: 11, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Tutar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${isDeposit ? '+' : '-'}'
                  '${CurrencyUtils.formatCashFlow(cashflow.amount, cashflow.currency)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    letterSpacing: -1,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(height: 1, color: border),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow(
                      'Tarih',
                      '${date.day}.${date.month}.${date.year}',
                      textPrimary,
                      textSecondary,
                    ),
                    _detailRow(
                      'Tutar',
                      CurrencyUtils.formatCashFlow(
                        cashflow.amount,
                        cashflow.currency,
                      ),
                      textPrimary,
                      textSecondary,
                    ),
                    if (cashflow.currency != 'TRY') ...[
                      _detailRow(
                        'Sabitlenen Kur',
                        cashflow.rateAtEntry != null
                            ? '1 ${cashflow.currency} = '
                                  '${cashflow.rateAtEntry!.toStringAsFixed(4)} ₺'
                            : 'Kaydedilmedi',
                        textPrimary,
                        textSecondary,
                      ),
                      if (amountInTry != null)
                        _detailRow(
                          'TRY Karşılığı',
                          CurrencyUtils.formatCashFlow(amountInTry, 'TRY'),
                          textPrimary,
                          textSecondary,
                        ),
                    ],
                    if (hasNote) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Not',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkCard
                              : AppColors.lightCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border),
                        ),
                        child: Text(
                          note,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Sil butonu
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('cashflow-detail-delete'),
                  onPressed: () => _confirmDelete(context, ref),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('İşlemi Sil'),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Sil', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Bu işlemi silmek istiyor musun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(cashflowProvider.notifier).delete(cashflow.id);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
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
