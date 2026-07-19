import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../providers.dart';

class TotalViewBadge extends ConsumerWidget {
  const TotalViewBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isTotalViewProvider)) return const SizedBox.shrink();
    final includedCount = ref.watch(includedPortfolioIdsProvider).length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.accentFor(Theme.of(context).brightness);
    return Container(
      key: const ValueKey('total-view-badge'),
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.13 : 0.09),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.donut_large_rounded, size: 12, color: accent),
            const SizedBox(width: 5),
            Text(
              'Toplam görünüm · $includedCount portföy',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
