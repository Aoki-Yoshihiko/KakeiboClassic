import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/item_template.dart';
import '../models/transaction.dart';
import '../services/item_template_service.dart';
import '../constants/category_constants.dart';

class TemplateEditScreen extends ConsumerStatefulWidget {
  final ItemTemplate? template;

  const TemplateEditScreen({super.key, this.template});

  @override
  ConsumerState<TemplateEditScreen> createState() => _TemplateEditScreenState();
}

class _TemplateEditScreenState extends ConsumerState<TemplateEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  
  TransactionType _selectedType = TransactionType.expense;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      _titleController.text = widget.template!.title;
      _amountController.text = widget.template!.defaultAmount.round().toString();
      _memoController.text = widget.template!.memo ?? '';
      _selectedType = widget.template!.type;
      // メモからカテゴリを推測
      _selectedCategory = _findCategoryFromMemo(widget.template!.memo);
    }
  }

  String? _findCategoryFromMemo(String? memo) {
    if (memo == null) return null;
    
    final categories = _selectedType == TransactionType.income 
        ? CategoryConstants.incomeCategories 
        : CategoryConstants.expenseCategories;
    
    for (final category in categories) {
      if (memo.contains(category)) {
        return category;
      }
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template != null ? 'テンプレート編集' : 'テンプレート作成'),
        actions: [
          TextButton(
            onPressed: _saveTemplate,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // タイプ選択
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('タイプ', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<TransactionType>(
                            title: const Text('収入'),
                            value: TransactionType.income,
                            groupValue: _selectedType,
                            onChanged: (value) => setState(() {
                              _selectedType = value!;
                              // タイプ変更時にカテゴリをリセット
                              if (_selectedCategory != null &&
                                  !(_selectedType == TransactionType.income 
                                      ? CategoryConstants.incomeCategories 
                                      : CategoryConstants.expenseCategories
                                  ).contains(_selectedCategory)) {
                                _selectedCategory = null;
                              }
                            }),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<TransactionType>(
                            title: const Text('支出'),
                            value: TransactionType.expense,
                            groupValue: _selectedType,
                            onChanged: (value) => setState(() {
                              _selectedType = value!;
                              // タイプ変更時にカテゴリをリセット
                              if (_selectedCategory != null &&
                                  !(_selectedType == TransactionType.income 
                                      ? CategoryConstants.incomeCategories 
                                      : CategoryConstants.expenseCategories
                                  ).contains(_selectedCategory)) {
                                _selectedCategory = null;
                              }
                            }),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 基本情報
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'テンプレート名',
                        hintText: '例：セブンイレブン、電車代',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.isEmpty == true ? 'テンプレート名を入力してください' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // 修正された金額入力フィールド
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'デフォルト金額',
                        border: OutlineInputBorder(),
                        suffixText: '円',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _ThousandsSeparatorInputFormatter(),
                      ],
                      validator: (value) {
                        if (value?.isEmpty == true) return '金額を入力してください';
                        
                        final cleanValue = value!.replaceAll(',', '');
                        
                        // 数値変換チェック
                        final parsedValue = double.tryParse(cleanValue);
                        if (parsedValue == null) return '正しい金額を入力してください';
                        
                        // オーバーフロー防止: 最大値チェック
                        if (parsedValue > 999999999) return '金額が大きすぎます（最大9億9999万円）';
                        if (parsedValue < 0) return '金額は0以上で入力してください';
                        
                        // 無限大・NaN チェック
                        if (!parsedValue.isFinite) return '正しい金額を入力してください';
                        
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // カテゴリ選択
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'デフォルトカテゴリ（任意）',
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(
                          _selectedCategory != null 
                              ? CategoryConstants.getCategoryIcon(_selectedCategory!)
                              : Icons.category,
                          color: _selectedCategory != null
                              ? CategoryConstants.getCategoryColor(_selectedCategory!, context)
                              : null,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('カテゴリを選択'),
                        ),
                        ...(_selectedType == TransactionType.income 
                            ? CategoryConstants.incomeCategories 
                            : CategoryConstants.expenseCategories
                        ).map((category) => DropdownMenuItem<String>(
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
                          _selectedCategory = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _memoController,
                      decoration: const InputDecoration(
                        labelText: 'メモ（任意）',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 使い方のヒント
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 登録のコツ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• よく使う店名や項目名を登録しましょう',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    '• 金額は後から変更できるので、目安でOK',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    '• カテゴリを設定すると自動で反映されます',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 修正された _saveTemplate メソッド
  void _saveTemplate() {
    if (!_formKey.currentState!.validate()) return;

    // 安全な金額パース
    final cleanAmount = _amountController.text.replaceAll(',', '');
    final parsedAmount = double.tryParse(cleanAmount);
    
    if (parsedAmount == null || !parsedAmount.isFinite || parsedAmount > 999999999) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('金額の入力に問題があります'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // メモにカテゴリ情報を含める
    String? memo = _memoController.text.isEmpty ? null : _memoController.text;
    if (_selectedCategory != null && (memo == null || !memo.contains(_selectedCategory!))) {
      memo = _selectedCategory! + (memo != null ? ' - $memo' : '');
    }

    final template = ItemTemplate(
      id: widget.template?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text,
      defaultAmount: parsedAmount, // 安全にパースした金額を使用
      type: _selectedType,
      memo: memo,
      createdAt: widget.template?.createdAt ?? DateTime.now(),
    );

    if (widget.template != null) {
      ref.read(itemTemplateServiceProvider.notifier).updateTemplate(template);
    } else {
      ref.read(itemTemplateServiceProvider.notifier).addTemplate(template);
    }

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _memoController.dispose();
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