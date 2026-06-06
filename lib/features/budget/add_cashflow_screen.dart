import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/income_expense_model.dart';
import '../../shared/providers.dart';
import '../../shared/services/cashflow_service.dart';
import '../../shared/utils/currency_utils.dart';

class AddCashFlowScreen extends ConsumerStatefulWidget {
  final bool isDeposit;
  const AddCashFlowScreen({super.key, required this.isDeposit});

  @override
  ConsumerState<AddCashFlowScreen> createState() => _AddCashFlowScreenState();
}

class _AddCashFlowScreenState extends ConsumerState<AddCashFlowScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _currency = 'TRY';
  double? _rateAtEntry; // işlem anında sabitlenecek kur (TRY dışı için)
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Color get _color => widget.isDeposit
      ? AppColors.profitFor(Theme.of(context).brightness)
      : AppColors.loss;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isDeposit ? 'Para Girişi' : 'Para Çıkışı'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'Kaydet',
              style: TextStyle(color: _color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.isDeposit
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      color: _color,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isDeposit
                                ? 'Portföye Para Girişi'
                                : 'Portföyden Para Çıkışı',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _color,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.isDeposit
                                ? 'Bankadan portföyüne aktardığın para'
                                : 'Portföyünden bankana çektiğin para',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'İşlem Bilgileri',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildTextField(
                        _titleController,
                        'İşlem Adı',
                        widget.isDeposit
                            ? 'örn. Nisan yatırımı'
                            : 'örn. Kira için çekim',
                        required: true,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildTextField(
                              _amountController,
                              'Tutar',
                              '0,00',
                              isNumber: true,
                              required: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _currency,
                              decoration: InputDecoration(
                                labelText: 'Birim',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).dividerColor,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                              items: ['TRY', 'USD', 'EUR']
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                setState(() {
                                  _currency = v!;
                                  // Para birimi değişince o anki kuru sabitle
                                  _rateAtEntry = _currency == 'TRY'
                                      ? null
                                      : CurrencyUtils.currentRateForCurrency(
                                          _currency,
                                        );
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      // Kur bilgisi — TRY dışı seçildiğinde gösterilir
                      if (_currency != 'TRY') ...[
                        const SizedBox(height: 8),
                        _buildRateInfo(),
                      ],
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: _color,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tarih',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    '${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _noteController,
                        'Not (opsiyonel)',
                        'Bu işlem hakkında bir not...',
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRateInfo() {
    if (_rateAtEntry != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: 14, color: _color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '1 $_currency = ${_rateAtEntry!.toStringAsFixed(4)} ₺ — bu kur işlemle birlikte sabitlenecek',
                style: TextStyle(fontSize: 12, color: _color),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Anlık kur bilgisi bulunamadı. Fiyatları güncelleyip tekrar deneyin.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    bool isNumber = false,
    bool required = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))]
          : null,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _color, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      validator: required
          ? (v) => (v == null || v.isEmpty) ? '$label zorunlu' : null
          : null,
    );
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final portfolioId = ref.read(activePortfolioProvider);
      final cashflow = CashFlowModel(
        id: '',
        portfolioId: portfolioId,
        title: _titleController.text,
        amount: double.parse(_amountController.text.replaceAll(',', '.')),
        currency: _currency,
        type: widget.isDeposit ? CashFlowType.deposit : CashFlowType.withdrawal,
        date: _selectedDate,
        note: _noteController.text.isEmpty ? null : _noteController.text,
        rateAtEntry: _rateAtEntry,
      );
      CashFlowService.save(cashflow);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isDeposit ? 'Para girişi eklendi!' : 'Para çıkışı eklendi!',
          ),
          backgroundColor: _color,
        ),
      );
    }
  }
}
