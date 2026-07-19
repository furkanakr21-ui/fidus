import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/models/portfolio_model.dart';

class TotalPortfolioTile extends StatelessWidget {
  final int includedCount;
  final bool isActive;
  final VoidCallback onSelect;
  final VoidCallback onConfigure;

  const TotalPortfolioTile({
    super.key,
    required this.includedCount,
    required this.isActive,
    required this.onSelect,
    required this.onConfigure,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.accentFor(Theme.of(context).brightness);
    return ListTile(
      key: const ValueKey('total-portfolio-tile'),
      contentPadding: EdgeInsets.zero,
      onTap: isActive ? null : onSelect,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive
              ? accent.withValues(alpha: 0.15)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                    .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: isActive ? Border.all(color: accent, width: 1.5) : null,
        ),
        child: Icon(Icons.donut_large_rounded, size: 20, color: accent),
      ),
      title: Text(
        'Portföyler Toplamı',
        style: TextStyle(
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
          fontSize: 14,
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
      subtitle: Text(
        '$includedCount portföy dahil',
        style: TextStyle(
          fontSize: 11,
          color: isActive
              ? accent
              : (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive)
            Icon(
              Icons.check_circle_rounded,
              key: const ValueKey('total-portfolio-active'),
              color: accent,
              size: 20,
            )
          else
            TextButton(
              key: const ValueKey('select-total-portfolio'),
              onPressed: onSelect,
              child: const Text(
                'Seç',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          IconButton(
            key: const ValueKey('configure-total-portfolio'),
            onPressed: onConfigure,
            tooltip: 'Toplama dahil portföyler',
            icon: const Icon(Icons.tune_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class TotalViewSettingsSheet extends StatefulWidget {
  final List<PortfolioModel> portfolios;
  final Future<void> Function(String portfolioId, bool value) onChanged;

  const TotalViewSettingsSheet({
    super.key,
    required this.portfolios,
    required this.onChanged,
  });

  @override
  State<TotalViewSettingsSheet> createState() => _TotalViewSettingsSheetState();
}

class _TotalViewSettingsSheetState extends State<TotalViewSettingsSheet> {
  late final Map<String, bool> _values = {
    for (final portfolio in widget.portfolios)
      portfolio.id: portfolio.includeInTotal,
  };
  String? _pendingPortfolioId;

  Future<void> _toggle(PortfolioModel portfolio, bool value) async {
    if (_pendingPortfolioId != null) return;
    final previous = _values[portfolio.id] ?? portfolio.includeInTotal;
    setState(() {
      _values[portfolio.id] = value;
      _pendingPortfolioId = portfolio.id;
    });
    try {
      await widget.onChanged(portfolio.id, value);
    } catch (_) {
      if (!mounted) return;
      setState(() => _values[portfolio.id] = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Portföy tercihi kaydedilemedi'),
          backgroundColor: AppColors.loss,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _pendingPortfolioId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: const ValueKey('total-view-settings-sheet'),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.market.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.donut_large_rounded,
                      color: AppColors.market,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Toplama Dahil Portföyler',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Toplam görünümde yer alacak portföyleri seçin.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                itemCount: widget.portfolios.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                itemBuilder: (context, index) {
                  final portfolio = widget.portfolios[index];
                  final isIncluded =
                      _values[portfolio.id] ?? portfolio.includeInTotal;
                  final isPending = _pendingPortfolioId == portfolio.id;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(
                      portfolio.emoji,
                      style: const TextStyle(fontSize: 23),
                    ),
                    title: Text(
                      portfolio.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(isIncluded ? 'Toplama dahil' : 'Hariç'),
                    trailing: isPending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Switch(
                            key: ValueKey('total-view-switch-${portfolio.id}'),
                            value: isIncluded,
                            onChanged: _pendingPortfolioId == null
                                ? (value) => _toggle(portfolio, value)
                                : null,
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> showNoIncludedPortfoliosDialog(BuildContext context) async {
  final shouldConfigure = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('no-included-portfolios-dialog'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        'Toplama dahil portföy yok',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: const Text(
        'Portföyler Toplamı görünümünü açmak için en az bir portföy seçin.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Kapat'),
        ),
        FilledButton(
          key: const ValueKey('configure-empty-total-view'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Portföyleri Seç'),
        ),
      ],
    ),
  );
  return shouldConfigure ?? false;
}
