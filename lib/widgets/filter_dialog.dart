// lib/widgets/filter_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../providers/filter_provider.dart';
import '../constants/category_constants.dart';

class FilterDialog extends ConsumerStatefulWidget {
  final bool isTransactionTab;

  const FilterDialog({
    super.key,
    required this.isTransactionTab,
  });

  @override
  ConsumerState<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends ConsumerState<FilterDialog> {
  final _minAmountController = TextEditingController();
  final _maxAmountController = TextEditingController();
  
  late FilterCriteria _criteria;

  @override
  void initState() {
    super.initState();
    _criteria = widget.isTransactionTab
        ? ref.read(transactionFilterProvider)
        : ref.read(scheduledFilterProvider);
    
    _minAmountController.text = _criteria.minAmount?.round().toString() ?? '';
    _maxAmountController.text = _criteria.maxAmount?.round().toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Text('フィルター'),
          const Spacer(),
          if (_criteria.hasActiveFilters)
            TextButton(
              onPressed: _clearAll,
              child: const Text('クリア'),
            ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // タイプフィルター
            const Text('種類', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                FilterChip(
                  label: const Text('すべて'),
                  selected: _criteria.type == null,
                  onSelected: (selected) {
                    setState(() {
                      _criteria = _criteria.copyWith(clearType: true);
                    });
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('収入'),
                  selected: _criteria.type == TransactionType.income,
                  onSelected: (selected) {
                    setState(() {
                      _criteria = _criteria.copyWith(
                        type: selected ? TransactionType.income : null,
                        clearType: !selected,
                      );
                    });
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('支出'),
                  selected: _criteria.type == TransactionType.expense,
                  onSelected: (selected) {
                    setState(() {
                      _criteria = _criteria.copyWith(
                        type: selected ? TransactionType.expense : null,
                        clearType: !selected,
                      );
                    });
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 金額範囲
            const Text('金額範囲', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minAmountController,
                    decoration: const InputDecoration(
                      labelText: '最小金額',
                      suffixText: '円',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _ThousandsSeparatorInputFormatter(),
                    ],
                    onChanged: (value) {
                      final cleanValue = value.replaceAll(',', '');
                      setState(() {
                        _criteria = _criteria.copyWith(
                          minAmount: cleanValue.isEmpty ? null : double.tryParse(cleanValue),
                          clearMinAmount: cleanValue.isEmpty,
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _maxAmountController,
                    decoration: const InputDecoration(
                      labelText: '最大金額',
                      suffixText: '円',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _ThousandsSeparatorInputFormatter(),
                    ],
                    onChanged: (value) {
                      final cleanValue = value.replaceAll(',', '');
                      setState(() {
                        _criteria = _criteria.copyWith(
                          maxAmount: cleanValue.isEmpty ? null : double.tryParse(cleanValue),
                          clearMaxAmount: cleanValue.isEmpty,
                        );
                      });
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // カテゴリフィルター
            const Text('カテゴリ', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _criteria.category,
              decoration: const InputDecoration(
                labelText: 'カテゴリを選択',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('すべて'),
                ),
                if (_criteria.type == null || _criteria.type == TransactionType.income)
                  ...CategoryConstants.incomeCategories.map((category) => DropdownMenuItem<String>(
                    value: category,
                    child: Row(
                      children: [
                        Icon(
                          CategoryConstants.getCategoryIcon(category),
                          size: 20,
                          color: CategoryConstants.getCategoryColor(category, context),
                        ),
                        const SizedBox(width: 8),
                        Text(category),
                      ],
                    ),
                  )),
                if (_criteria.type == null || _criteria.type == TransactionType.expense)
                  ...CategoryConstants.expenseCategories.map((category) => DropdownMenuItem<String>(
                    value: category,
                    child: Row(
                      children: [
                        Icon(
                          CategoryConstants.getCategoryIcon(category),
                          size: 20,
                          color: CategoryConstants.getCategoryColor(category, context),
                        ),
                        const SizedBox(width: 8),
                        Text(category),
                      ],
                    ),
                  )),
              ],
              onChanged: (value) {
                setState(() {
                  _criteria = _criteria.copyWith(
                    category: value,
                    clearCategory: value == null,
                  );
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _applyFilter,
          child: const Text('適用'),
        ),
      ],
    );
  }

  void _clearAll() {
    setState(() {
      _criteria = FilterCriteria();
      _minAmountController.clear();
      _maxAmountController.clear();
    });
  }

  void _applyFilter() {
    final notifier = widget.isTransactionTab
        ? ref.read(transactionFilterProvider.notifier)
        : ref.read(scheduledFilterProvider.notifier);
    
    // 各フィルター条件を適用
    notifier.setType(_criteria.type);
    notifier.setMinAmount(_criteria.minAmount);
    notifier.setMaxAmount(_criteria.maxAmount);
    notifier.setCategory(_criteria.category);
    
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }
}

// 3桁ごとにカンマを追加するFormatter
class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final number = int.tryParse(newValue.text.replaceAll(',', ''));
    if (number == null) {
      return oldValue;
    }

    final formatter = NumberFormat('#,###');
    final newText = formatter.format(number);

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}