import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/goal_model.dart';
import '../../shared/providers.dart';
import '../../shared/services/goal_service.dart';
import '../../shared/utils/currency_utils.dart';
import 'add_goal_sheet.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  int _daysLeft(DateTime? targetDate) {
    if (targetDate == null) return -1;
    return targetDate.difference(DateTime.now()).inDays;
  }

  double _monthlyRequired(GoalModel goal) {
    if (goal.targetDate == null) return 0;
    final now = DateTime.now();
    final target = goal.targetDate!;
    final months = (target.year - now.year) * 12 + (target.month - now.month);
    if (months <= 0) return 0;
    final remaining = goal.targetAmount - goal.currentAmount;
    if (remaining <= 0) return 0;
    return remaining / months;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final totalTarget = goals.fold(0.0, (sum, g) => sum + g.targetAmount);
    final totalCurrent = goals.fold(0.0, (sum, g) => sum + g.currentAmount);
    final overallProgress = totalTarget == 0
        ? 0.0
        : (totalCurrent / totalTarget) * 100;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.planning,
          onRefresh: () async => ref.read(goalsProvider.notifier).load(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context, ref, goals)),
              if (goals.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildOverviewCard(
                    context,
                    overallProgress,
                    totalTarget,
                    totalCurrent,
                  ),
                ),
              goals.isEmpty
                  ? SliverToBoxAdapter(child: _buildEmptyState(context, ref))
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _buildGoalCard(context, ref, goals[index]),
                        childCount: goals.length,
                      ),
                    ),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    List<GoalModel> goals,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hedefler',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              Text(
                '${goals.length} hedef · ${goals.where((g) => g.isCompleted).length} tamamlandı',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.planning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.planning.withValues(alpha: 0.2),
              ),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const AddGoalSheet(),
                ).then((_) => ref.read(goalsProvider.notifier).load());
              },
              icon: const Icon(
                Icons.add_rounded,
                color: AppColors.planning,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(
    BuildContext context,
    double overallProgress,
    double totalTarget,
    double totalCurrent,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF38265B), const Color(0xFF8252C7)]
                : [const Color(0xFF00705A), const Color(0xFF00CEAA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? const Color(0xFF4A2870) : AppColors.planning)
                  .withValues(alpha: isDark ? 0.5 : 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GENEL İLERLEME',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '%${overallProgress.toStringAsFixed(1)}',
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: overallProgress / 100,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.12)),
            const SizedBox(height: 16),
            Row(
              children: [
                _overviewStat(
                  'Toplam Hedef',
                  '₺${CurrencyUtils.formatRaw(totalTarget)}',
                ),
                _statDivider(),
                _overviewStat(
                  'Biriken',
                  '₺${CurrencyUtils.formatRaw(totalCurrent)}',
                ),
                _statDivider(),
                _overviewStat(
                  'Kalan',
                  '₺${CurrencyUtils.formatRaw(totalTarget - totalCurrent)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _overviewStat(String title, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _statDivider() => Container(
    width: 1,
    height: 30,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: Colors.white.withValues(alpha: 0.15),
  );

  Widget _buildGoalCard(BuildContext context, WidgetRef ref, GoalModel goal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = goal.progressPercent.clamp(0.0, 100.0);
    final isCompleted = goal.isCompleted;
    final daysLeft = _daysLeft(goal.targetDate);
    final monthly = _monthlyRequired(goal);
    final color = isCompleted
        ? AppColors.profitFor(Theme.of(context).brightness)
        : AppColors.planning;
    final profitColor = AppColors.profitFor(Theme.of(context).brightness);
    final bg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showGoalOptions(context, ref, goal),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          goal.emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: isDark
                                  ? AppColors.darkText
                                  : AppColors.lightText,
                            ),
                          ),
                          Text(
                            _goalTypeLabel(goal.type),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: progress / 100,
                            strokeWidth: 5,
                            backgroundColor: color.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                          Center(
                            child: Text(
                              '%${progress.toStringAsFixed(0)}',
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Biriken',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        Text(
                          '${goal.currency} ${CurrencyUtils.formatRaw(goal.currentAmount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Hedef',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        Text(
                          '${goal.currency} ${CurrencyUtils.formatRaw(goal.targetAmount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.lightText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Stack(
                  children: [
                    Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: (progress / 100).clamp(0.0, 1.0),
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          gradient: isCompleted
                              ? LinearGradient(
                                  colors: [AppColors.planning, profitColor],
                                )
                              : LinearGradient(
                                  colors: [
                                    AppColors.planning,
                                    AppColors.planning,
                                    profitColor,
                                  ],
                                  stops: const [0.0, 0.55, 1.0],
                                ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (daysLeft >= 0)
                      _infoChip(
                        Icons.calendar_today_outlined,
                        daysLeft == 0 ? 'Son gün!' : '$daysLeft gün kaldı',
                        daysLeft <= 30
                            ? AppColors.loss
                            : daysLeft <= 180
                            ? AppColors.gold
                            : (isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary),
                      ),
                    if (monthly > 0)
                      _infoChip(
                        Icons.savings_outlined,
                        'Aylık ${goal.currency} ${CurrencyUtils.formatRaw(monthly)}',
                        AppColors.gold,
                      ),
                    if (isCompleted)
                      _infoChip(
                        Icons.check_circle_outline_rounded,
                        'Tamamlandı!',
                        profitColor,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _goalTypeLabel(GoalType type) {
    switch (type) {
      case GoalType.retirement:
        return 'Emeklilik / Finansal özgürlük';
      case GoalType.savings:
        return 'Birikim hedefi';
      case GoalType.portfolio:
        return 'Portföy büyüklüğü';
      case GoalType.other:
        return 'Diğer';
    }
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 0),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.planning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.flag_rounded,
                size: 40,
                color: AppColors.planning,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Henüz hedef yok',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Finansal hedeflerini belirle,\nilerlemeyi takip et.',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const AddGoalSheet(),
                ).then((_) => ref.read(goalsProvider.notifier).load());
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('İlk Hedefi Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  void _showGoalOptions(BuildContext context, WidgetRef ref, GoalModel goal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(goal.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        goal.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.planning,
                  ),
                  title: const Text('İlerleme Güncelle'),
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.pop(context);
                    _showUpdateProgress(context, ref, goal);
                  },
                ),
                Divider(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.loss,
                  ),
                  title: const Text(
                    'Hedefi Sil',
                    style: TextStyle(color: AppColors.loss),
                  ),
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete(context, ref, goal);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUpdateProgress(
    BuildContext context,
    WidgetRef ref,
    GoalModel goal,
  ) {
    final controller = TextEditingController(
      text: goal.currentAmount.toStringAsFixed(0),
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'İlerleme Güncelle',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Mevcut tutar (${goal.currency})',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amount =
                          double.tryParse(
                            controller.text.replaceAll(',', '.'),
                          ) ??
                          0;
                      final updated = goal.copyWith(currentAmount: amount);
                      await GoalService.update(updated);
                      ref.read(goalsProvider.notifier).load();
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
                    child: const Text('Kaydet'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, GoalModel goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Hedefi Sil',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text('"${goal.title}" hedefini silmek istiyor musun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              await GoalService.delete(goal.id);
              ref.read(goalsProvider.notifier).load();
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
