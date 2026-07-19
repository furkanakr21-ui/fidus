import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/asset_model.dart';
import '../../shared/models/portfolio_write_target.dart';
import '../../shared/models/transaction_model.dart';
import '../../shared/providers.dart';
import '../../shared/services/asset_service.dart';
import '../../shared/services/transaction_service.dart';

class AddSellSheet extends ConsumerStatefulWidget {
  final String symbol;
  final String assetName;
  final double totalQuantity;
  final double? currentPrice;
  final String currency;
  final String portfolioId;
  final String? portfolioName;

  const AddSellSheet({
    super.key,
    required this.symbol,
    required this.assetName,
    required this.totalQuantity,
    this.currentPrice,
    required this.currency,
    required this.portfolioId,
    this.portfolioName,
  });

  @override
  ConsumerState<AddSellSheet> createState() => _AddSellSheetState();
}

class _AddSellSheetState extends ConsumerState<AddSellSheet> {
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _commissionController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.currentPrice != null) {
      _priceController.text = widget.currentPrice!.toStringAsFixed(
        widget.currentPrice! < 1 ? 6 : 2,
      );
    }
  }

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
  double get _totalProceeds =>
      (_enteredQty * _enteredPrice) - _enteredCommission;

  String get _currencySymbol {
    switch (widget.currency) {
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
      _showError('Satış miktarı 0\'dan büyük olmalı');
      return;
    }
    if (qty > widget.totalQuantity) {
      _showError(
        'Elinizdeki miktardan (${_formatQty(widget.totalQuantity)}) fazla satış yapılamaz',
      );
      return;
    }
    if (price <= 0) {
      _showError('Satış fiyatı 0\'dan büyük olmalı');
      return;
    }
    final portfolioId = resolveWritePortfolioId(
      activePortfolioId: widget.portfolioId,
    );
    if (portfolioId == null) {
      _showError('Satış için geçerli bir portföy seçilemedi');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Lotları önce çek — assetId için ve FIFO'da tekrar DB çağrısı yapmamak için
      final lots = await _fetchSortedLots(portfolioId);
      if (lots.isEmpty) {
        setState(() => _isSaving = false);
        _showError('Satılacak lot bulunamadı');
        return;
      }
      final availableQuantity = lots.fold(
        0.0,
        (sum, lot) => sum + lot.quantity,
      );
      if (qty > availableQuantity) {
        setState(() => _isSaving = false);
        _showError(
          'Güncel miktar ${_formatQty(availableQuantity)}. Satış miktarını kontrol edin',
        );
        return;
      }

      final sellTx = TransactionModel(
        id: '',
        assetId: lots.first.id,
        type: TransactionType.sell,
        quantity: qty,
        price: price,
        commission: _enteredCommission > 0 ? _enteredCommission : null,
        date: _selectedDate,
        note: _noteController.text.isEmpty ? null : _noteController.text,
        symbol: widget.symbol,
        assetName: widget.assetName,
      );
      await TransactionService.save(sellTx);

      // FIFO: en eski lotlardan başlayarak miktarı düş
      await _applyFifo(qty, lots);

      ref.read(transactionsProvider.notifier).load();
      ref.read(assetsProvider.notifier).load();

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.symbol} satışı kaydedildi'),
            backgroundColor: AppColors.profit,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('Satış tamamlanamadı. Portföyü yenileyip kontrol edin');
    }
  }

  Future<List<AssetModel>> _fetchSortedLots(String portfolioId) async {
    final all = await AssetService.getByPortfolio(portfolioId);
    return all.where((a) => a.symbol == widget.symbol).toList()
      ..sort(compareAssetLotsForFifo);
  }

  Future<void> _applyFifo(double sellQty, List<AssetModel> lots) async {
    double remaining = sellQty;
    for (final lot in lots) {
      if (remaining <= 0) break;
      if (lot.quantity <= remaining) {
        remaining -= lot.quantity;
        await AssetService.delete(lot.id);
      } else {
        await AssetService.update(
          lot.copyWith(quantity: lot.quantity - remaining),
        );
        remaining = 0;
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.loss),
    );
  }

  String _formatQty(double qty) {
    return qty == qty.truncateToDouble()
        ? qty.toStringAsFixed(0)
        : qty.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.loss.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.trending_down_rounded,
                      color: AppColors.loss,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Satış Kaydet — ${widget.symbol}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${widget.portfolioName == null ? '' : '${widget.portfolioName} · '}Eldeki miktar: ${_formatQty(widget.totalQuantity)} · FIFO uygulanır',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textTheme.bodySmall?.color,
                          ),
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
                            label: 'Satış Miktarı',
                            hint: _formatQty(widget.totalQuantity),
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField(
                            controller: _priceController,
                            label: 'Satış Fiyatı ($_currencySymbol)',
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
                      hint: 'Bu satış hakkında bir not...',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    // Özet
                    if (_enteredQty > 0 && _enteredPrice > 0)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.loss.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.loss.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tahmini Gelir',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                            Text(
                              '$_currencySymbol${_totalProceeds.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: AppColors.loss,
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
                          backgroundColor: AppColors.loss,
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
                                'Satışı Kaydet',
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
          borderSide: const BorderSide(color: AppColors.loss, width: 2),
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
              color: AppColors.loss,
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
