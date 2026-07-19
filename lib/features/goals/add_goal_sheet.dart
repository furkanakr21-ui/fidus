import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/goal_model.dart';
import '../../shared/models/portfolio_write_target.dart';
import '../../shared/providers.dart';
import '../../shared/services/goal_service.dart';
import '../../shared/widgets/portfolio_picker.dart';

class AddGoalSheet extends ConsumerStatefulWidget {
  const AddGoalSheet({super.key});

  @override
  ConsumerState<AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends ConsumerState<AddGoalSheet> {
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  final _currentController = TextEditingController(text: '0');
  GoalType _selectedType = GoalType.savings;
  String _selectedEmoji = '🎯';
  String _selectedCurrency = 'TRY';
  DateTime? _targetDate;
  String? _targetPortfolioId;
  bool _isSaving = false;

  final _emojis = ['🎯', '🏠', '🚗', '✈️', '📚', '💍', '🏖️', '💰', '🏦', '🌟'];
  final _types = [
    {'type': GoalType.savings, 'label': 'Birikim'},
    {'type': GoalType.retirement, 'label': 'Emeklilik'},
    {'type': GoalType.portfolio, 'label': 'Portföy'},
    {'type': GoalType.other, 'label': 'Diğer'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _currentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTotalView = ref.watch(isTotalViewProvider);
    final portfolios = ref.watch(portfoliosProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCard : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkText : AppColors.lightText;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
            blurRadius: 30,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.planning, Color(0xFF8C75D4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.flag_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yeni Hedef',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Finansal hedefini belirle',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: textSecondary),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (isTotalView) ...[
              TargetPortfolioField(
                portfolios: portfolios,
                selectedPortfolioId: _targetPortfolioId,
                onChanged: (id) => setState(() => _targetPortfolioId = id),
              ),
              const SizedBox(height: 20),
            ],

            // Emoji picker
            _sectionLabel('Emoji', textSecondary),
            const SizedBox(height: 8),
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _emojis.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final selected = _selectedEmoji == _emojis[i];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedEmoji = _emojis[i]),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.planning.withValues(alpha: 0.12)
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppColors.planning
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _emojis[i],
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Title field
            _sectionLabel('Hedef Adı', textSecondary),
            const SizedBox(height: 8),
            _styledField(
              controller: _titleController,
              hint: 'örn. Ev almak, Emeklilik fonu',
              icon: Icons.edit_outlined,
              bg: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              border: border,
              textColor: textPrimary,
              hintColor: textSecondary,
            ),
            const SizedBox(height: 20),

            // Goal type chips
            _sectionLabel('Hedef Türü', textSecondary),
            const SizedBox(height: 8),
            Row(
              children: _types.map((t) {
                final selected = _selectedType == t['type'];
                return Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedType = t['type'] as GoalType),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.planning
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        t['label'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Target amount + currency
            _sectionLabel('Hedef Tutar', textSecondary),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _styledField(
                    controller: _targetController,
                    hint: '0',
                    icon: Icons.attach_money_rounded,
                    isNumber: true,
                    bg: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    border: border,
                    textColor: textPrimary,
                    hintColor: textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCurrency,
                        isExpanded: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        borderRadius: BorderRadius.circular(12),
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        dropdownColor: bg,
                        items: ['TRY', 'USD', 'EUR']
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedCurrency = v!),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Current amount
            _sectionLabel('Mevcut Tutar (opsiyonel)', textSecondary),
            const SizedBox(height: 8),
            _styledField(
              controller: _currentController,
              hint: '0',
              icon: Icons.savings_outlined,
              isNumber: true,
              bg: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              border: border,
              textColor: textPrimary,
              hintColor: textSecondary,
            ),
            const SizedBox(height: 16),

            // Target date
            _sectionLabel('Hedef Tarihi (opsiyonel)', textSecondary),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 365)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _targetDate = picked);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.planning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        size: 15,
                        color: AppColors.planning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _targetDate == null
                          ? 'Tarih seç'
                          : '${_targetDate!.day}.${_targetDate!.month}.${_targetDate!.year}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _targetDate == null
                            ? textSecondary
                            : textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (_targetDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _targetDate = null),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: textSecondary,
                        ),
                      )
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: textSecondary,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.planning,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        '$_selectedEmoji  Hedef Oluştur',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) => Text(
    text,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: color,
      letterSpacing: 0.2,
    ),
  );

  Widget _styledField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color bg,
    required Color border,
    required Color textColor,
    required Color hintColor,
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))]
          : null,
      style: TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: hintColor, fontSize: 14),
        prefixIcon: Icon(icon, size: 18, color: hintColor),
        filled: true,
        fillColor: bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.planning, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final targetText = _targetController.text.replaceAll(',', '.');
    final targetAmount = double.tryParse(targetText);

    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Hedef başlığı boş olamaz')));
      return;
    }
    if (targetAmount == null || targetAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir hedef tutarı girin')),
      );
      return;
    }

    final portfolioId = resolveWritePortfolioId(
      activePortfolioId: ref.read(activePortfolioProvider),
      selectedPortfolioId: _targetPortfolioId,
    );
    if (portfolioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hedefin kaydedileceği portföyü seçin'),
          backgroundColor: AppColors.loss,
        ),
      );
      return;
    }
    final goal = GoalModel(
      id: '',
      portfolioId: portfolioId,
      title: _titleController.text,
      emoji: _selectedEmoji,
      type: _selectedType,
      targetAmount: targetAmount,
      currentAmount:
          double.tryParse(_currentController.text.replaceAll(',', '.')) ?? 0,
      targetDate: _targetDate,
      currency: _selectedCurrency,
    );
    setState(() => _isSaving = true);
    try {
      await GoalService.save(goal);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hedef kaydedilemedi, lütfen tekrar deneyin'),
          backgroundColor: AppColors.loss,
        ),
      );
    }
  }
}
