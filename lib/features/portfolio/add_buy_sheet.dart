import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/asset_model.dart';
import '../../shared/models/transaction_model.dart';
import '../../shared/providers.dart';
import '../../shared/services/asset_service.dart';
import '../../shared/services/transaction_service.dart';

class AddBuySheet extends ConsumerStatefulWidget {
  final AssetModel mergedAsset;

  const AddBuySheet({super.key, required this.mergedAsset});

  @override
  ConsumerState<AddBuySheet> createState() => _AddBuySheetState();
}

class _AddBuySheetState extends ConsumerState<AddBuySheet> {
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _commissionController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _commissionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _enteredQty =>
      double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 0;
  double get _enteredPrice =>
      double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0;
  double get _enteredCommission =>
      double.tryParse(_commissionController.text.replaceAll(',', '.')) ?? 0;
  double get _totalCost => (_enteredQty * _enteredPrice) + _enteredCommission;

  String get _currencySymbol {
    switch (widget.mergedAsset.currency) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      default:
        return '₺';
    }
  }

  Future<void> _save() async {
    final qty = _enteredQty;
    final price = _enteredPrice;

    if (qty <= 0) {
      _showError('Miktar 0\'dan büyük olmalı');
      return;
    }
    if (price <= 0) {
      _showError('Alış fiyatı 0\'dan büyük olmalı');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final newLot = AssetModel(
        id: '',
        portfolioId: widget.mergedAsset.portfolioId,
        name: widget.mergedAsset.name,
        symbol: widget.mergedAsset.symbol,
        type: widget.mergedAsset.type,
        quantity: qty,
        buyPrice: price,
        buyDate: _selectedDate,
        commission: _enteredCommission > 0 ? _enteredCommission : null,
        note: _noteController.text.isEmpty ? null : _noteController.text,
        currency: widget.mergedAsset.currency,
        apiSource: widget.mergedAsset.apiSource,
        apiId: widget.mergedAsset.apiId,
      );

      final saved = await AssetService.save(newLot);

      final buyTx = TransactionModel(
        id: '',
        assetId: saved.id,
        type: TransactionType.buy,
        quantity: qty,
        price: price,
        commission: _enteredCommission > 0 ? _enteredCommission : null,
        date: _selectedDate,
        note: _noteController.text.isEmpty ? null : _noteController.text,
        symbol: widget.mergedAsset.symbol,
        assetName: widget.mergedAsset.name,
      );
      await TransactionService.save(buyTx);

      ref.read(assetsProvider.notifier).load();
      ref.read(transactionsProvider.notifier).load();

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.mergedAsset.symbol} alışı kaydedildi'),
            backgroundColor: AppColors.profit,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Bir hata oluştu, lütfen tekrar deneyin');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.loss),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asset = widget.mergedAsset;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.profit.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.trending_up_rounded,
                      color: AppColors.profit,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alış Ekle — ${asset.symbol}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          asset.name,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: theme.dividerColor),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            controller: _quantityController,
                            label: 'Miktar',
                            hint: '0',
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField(
                            controller: _priceController,
                            label: 'Alış Fiyatı ($_currencySymbol)',
                            hint: '0,00',
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            controller: _commissionController,
                            label: 'Komisyon (opsiyonel)',
                            hint: '0,00',
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: _buildDatePicker(context)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _noteController,
                      label: 'Not (opsiyonel)',
                      hint: 'Bu alış hakkında bir not...',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    if (_enteredQty > 0 && _enteredPrice > 0)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.profit.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.profit.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Toplam Maliyet',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                            Text(
                              '$_currencySymbol${_totalCost.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: AppColors.profit,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.profit,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                            : const Text(
                                'Alışı Kaydet',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))]
          : null,
      maxLines: maxLines,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.profit, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (picked != null) setState(() => _selectedDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: AppColors.profit,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tarih',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
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
    );
  }
}
