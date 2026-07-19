import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../models/portfolio_model.dart';

Future<PortfolioModel?> showPortfolioPicker(
  BuildContext context, {
  required List<PortfolioModel> portfolios,
  String title = 'Hedef Portföy',
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
                'İşlemin kaydedileceği portföyü seçin.',
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
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(
                        portfolio.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        portfolio.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                      ),
                      onTap: () => Navigator.pop(sheetContext, portfolio),
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
              if (result != null) onChanged(result.id);
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
              child: Text(
                selected?.name ??
                    (portfolios.isEmpty
                        ? 'Portföy bulunamadı'
                        : 'Portföy seçin'),
                style: TextStyle(
                  fontWeight: selected == null
                      ? FontWeight.w500
                      : FontWeight.w700,
                  color: selected == null ? Theme.of(context).hintColor : null,
                ),
              ),
            ),
            const Icon(Icons.unfold_more_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}
