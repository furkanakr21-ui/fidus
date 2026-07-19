import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../models/portfolio_model.dart';

Future<PortfolioModel?> showPortfolioPicker(
  BuildContext context, {
  required List<PortfolioModel> portfolios,
  String title = 'Hedef Portföy',
  String description = 'İşlemin kaydedileceği portföyü seçin.',
  Map<String, String> detailsByPortfolioId = const {},
}) {
  return showModalBottomSheet<PortfolioModel>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
      return SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(sheetContext).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: portfolios.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: Theme.of(sheetContext).dividerColor,
                  ),
                  itemBuilder: (_, index) {
                    final portfolio = portfolios[index];
                    final details = detailsByPortfolioId[portfolio.id];
                    final isExcluded = !portfolio.includeInTotal;
                    final warningColor = _warningColor(sheetContext);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(
                        portfolio.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        portfolio.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: details != null || isExcluded
                          ? Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (details != null)
                                    Text(
                                      details,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  if (isExcluded)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.info_outline_rounded,
                                          size: 12,
                                          color: warningColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Toplama dahil değil',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: warningColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            )
                          : null,
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                      ),
                      onTap: () async {
                        if (isExcluded) {
                          final confirmed =
                              await _confirmExcludedPortfolioSelection(
                                sheetContext,
                                portfolio,
                              );
                          if (!confirmed || !sheetContext.mounted) return;
                        }
                        Navigator.pop(sheetContext, portfolio);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class TargetPortfolioField extends StatelessWidget {
  final List<PortfolioModel> portfolios;
  final String? selectedPortfolioId;
  final ValueChanged<String> onChanged;
  final String label;

  const TargetPortfolioField({
    super.key,
    required this.portfolios,
    required this.selectedPortfolioId,
    required this.onChanged,
    this.label = 'Hedef Portföy',
  });

  @override
  Widget build(BuildContext context) {
    PortfolioModel? selected;
    for (final portfolio in portfolios) {
      if (portfolio.id == selectedPortfolioId) selected = portfolio;
    }
    final selectedIsExcluded = selected != null && !selected.includeInTotal;
    final warningColor = _warningColor(context);

    return InkWell(
      key: const ValueKey('target_portfolio_field'),
      borderRadius: BorderRadius.circular(10),
      onTap: portfolios.isEmpty
          ? null
          : () async {
              final result = await showPortfolioPicker(
                context,
                portfolios: portfolios,
                title: label,
              );
              if (result == null || !context.mounted) return;
              onChanged(result.id);
            },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '$label *',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
        child: Row(
          children: [
            Text(selected?.emoji ?? 'P', style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selected?.name ??
                        (portfolios.isEmpty
                            ? 'Portföy bulunamadı'
                            : 'Portföy seçin'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: selected == null
                          ? FontWeight.w500
                          : FontWeight.w700,
                      color: selected == null
                          ? Theme.of(context).hintColor
                          : null,
                    ),
                  ),
                  if (selectedIsExcluded)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Toplama dahil değil',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: warningColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.unfold_more_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

Color _warningColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppColors.cashFlow
      : const Color(0xFF8A5A00);
}

Future<bool> _confirmExcludedPortfolioSelection(
  BuildContext context,
  PortfolioModel portfolio,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        'Toplama dahil değil',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: Text(
        '${portfolio.name} toplam görünümün dışında. Bu portföye kaydedilen işlem Portföyler Toplamı içinde görünmez.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const ValueKey('confirm_excluded_portfolio'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Yine de Seç'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
