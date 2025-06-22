import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/holiday_handling.dart';
import '../services/transaction_service.dart';
import '../constants/category_constants.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final Transaction? editingTransaction;

  const AddTransactionScreen({super.key, this.editingTransaction});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();

  TransactionType _selectedType = TransactionType.expense;
  DateTime _selectedDate = DateTime.now();
  bool _isFixedItem = false;
  List<int> _selectedMonths = [];
  int _fixedDay = 1;
  HolidayHandling _holidayHandling = HolidayHandling.none;
  bool _showAmountInSchedule = true;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    if (widget.editingTransaction != null) {
      _initializeFromTransaction(widget.editingTransaction!);
    }
  }

  void _initializeFromTransaction(Transaction transaction) {
    _titleController.text = transaction.title;
    _amountController.text = transaction.amount.round().toString();
    _memoController.text = transaction.memo ?? '';
    _selectedType = transaction.type;
    _selectedDate = transaction.date;
    _isFixedItem = transaction.isFixedItem;
    _selectedMonths = List.from(transaction.fixedMonths);
    _fixedDay = transaction.fixedDay;
    _holidayHandling = transaction.holidayHandling;
    _showAmountInSchedule = transaction.showAmountInSchedule;
    _selectedCategory = transaction.category;
    
    // メモからカテゴリを抽出
    _extractCategoryFromMemo();
  }

  void _extractCategoryFromMemo() {
    final memo = _memoController.text;
    final categories = _selectedType == TransactionType.income 
        ? CategoryConstants.incomeCategories 
        : CategoryConstants.expenseCategories;
    
    for (final category in categories) {
      if (memo.contains(category)) {
        _selectedCategory = category;
        // カテゴリ部分をメモから除去
        final cleanMemo = memo.replaceAll(category, '').trim();
        _memoController.text = cleanMemo.startsWith(' - ') 
            ? cleanMemo.substring(3) 
            : cleanMemo;
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editingTransaction != null ? '項目編集' : '項目追加'),
        actions: [
          if (widget.editingTransaction?.isFixedItem == true)
            TextButton.icon(
              onPressed: _confirmAsActual,
              icon: const Icon(Icons.check),
              label: const Text('実績として確定'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green,
              ),
            ),
          TextButton(
            onPressed: _saveTransaction,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 収入・支出タイプ選択
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
                              _selectedCategory = null; // カテゴリをリセット
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
                              _selectedCategory = null; // カテゴリをリセット
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
                        labelText: '項目名',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.isEmpty == true ? '項目名を入力してください' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // カテゴリ選択
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'カテゴリ',
                        border: OutlineInputBorder(),
                      ),
                      items: (_selectedType == TransactionType.income 
                          ? CategoryConstants.incomeCategories 
                          : CategoryConstants.expenseCategories)
                          .map((category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedCategory = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // 修正された金額入力フィールド
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: '金額',
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
                    if (!_isFixedItem)
                      ListTile(
                        title: const Text('日付'),
                        subtitle: Text(DateFormat('yyyy年MM月dd日').format(_selectedDate)),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: _selectDate,
                      ),
                    const SizedBox(height: 8),
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

            // 固定項目設定
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      title: const Text('固定として設定'),
                      subtitle: const Text('毎月自動で予定に表示'),
                      value: _isFixedItem,
                      onChanged: (value) {
                        if (!value && widget.editingTransaction?.isFixedItem == true) {
                          // 固定項目をキャンセルする場合の確認
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('固定項目をキャンセル'),
                              content: const Text(
                                'この項目の固定設定をキャンセルすると、'
                                'すべての月の予定から削除されます。\n\n'
                                '実績は削除されません。\n'
                                '続行しますか？',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('いいえ'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() => _isFixedItem = false);
                                    Navigator.pop(context);
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('はい'),
                                ),
                              ],
                            ),
                          );
                        } else {
                          setState(() => _isFixedItem = value);
                        }
                      },
                    ),
                    if (_isFixedItem) ...[
                      const SizedBox(height: 16),
                      
                      // 発生日選択
                      const Text('発生日', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: _fixedDay,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: List.generate(31, (index) => index + 1)
                            .map((day) => DropdownMenuItem(
                                  value: day,
                                  child: Text('$day日'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _fixedDay = value);
                          }
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 休日処理設定
                      const Text('休日処理', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...HolidayHandling.values.map((handling) => RadioListTile<HolidayHandling>(
                        title: Text(handling.displayName),
                        subtitle: Text(handling.description),
                        value: handling,
                        groupValue: _holidayHandling,
                        onChanged: (value) => setState(() => _holidayHandling = value!),
                      )),
                      
                      const SizedBox(height: 16),
                      
                      // 金額設定方法
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('金額の設定方法', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'デフォルト金額を使用する',
                                    style: TextStyle(
                                      color: Theme.of(context).textTheme.bodyMedium?.color,
                                    ),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: _showAmountInSchedule 
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () => setState(() => _showAmountInSchedule = false),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: !_showAmountInSchedule 
                                                ? Theme.of(context).colorScheme.surface
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            '毎回入力',
                                            style: TextStyle(
                                              color: !_showAmountInSchedule 
                                                  ? Theme.of(context).colorScheme.primary
                                                  : Theme.of(context).colorScheme.onPrimary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => setState(() => _showAmountInSchedule = true),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: _showAmountInSchedule 
                                                ? Theme.of(context).colorScheme.surface
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            '固定金額',
                                            style: TextStyle(
                                              color: _showAmountInSchedule 
                                                  ? Theme.of(context).colorScheme.primary
                                                  : Theme.of(context).colorScheme.onPrimary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '💡 設定について',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '• 毎回入力：項目は固定、金額は実績確定時に毎回入力',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    '• 固定金額：上記で設定した金額をそのまま使用',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 表示する月を選択
                      const Text('表示する月を選択（未選択で全月）'),
                      const SizedBox(height: 8),
                      _buildMonthSelector(_selectedMonths, (months) => setState(() => _selectedMonths = months)),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector(List<int> selectedMonths, Function(List<int>) onChanged) {
    return Wrap(
      spacing: 8,
      children: List.generate(12, (index) {
        final month = index + 1;
        final isSelected = selectedMonths.contains(month);
        return FilterChip(
          label: Text('${month}月'),
          selected: isSelected,
          onSelected: (selected) {
            final newMonths = List<int>.from(selectedMonths);
            if (selected) {
              newMonths.add(month);
            } else {
              newMonths.remove(month);
            }
            onChanged(newMonths);
          },
        );
      }),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000), // 2000年から
      lastDate: DateTime(2100),  // 2100年まで
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // 修正された _saveTransaction メソッド
  void _saveTransaction() {
    if (!_formKey.currentState!.validate()) return;

    final transaction = Transaction();
    // ID重複防止の修正
    transaction.id = widget.editingTransaction?.id ?? 
      '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
    transaction.title = _titleController.text;
    
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
    
    transaction.amount = parsedAmount;
    transaction.date = _selectedDate;
    transaction.type = _selectedType;
    transaction.isFixedItem = _isFixedItem;
    transaction.fixedMonths = List.from(_selectedMonths);
    transaction.fixedDay = _fixedDay;
    transaction.holidayHandling = _holidayHandling;
    transaction.showAmountInSchedule = _showAmountInSchedule;
    transaction.category = _selectedCategory;
    
    // メモにカテゴリを含める
    String finalMemo = _memoController.text;
    if (_selectedCategory != null) {
      finalMemo = finalMemo.isEmpty 
          ? _selectedCategory! 
          : '$_selectedCategory - $finalMemo';
    }
    transaction.memo = finalMemo.isEmpty ? null : finalMemo;
    
    transaction.createdAt = widget.editingTransaction?.createdAt ?? DateTime.now();
    transaction.updatedAt = DateTime.now();

    if (widget.editingTransaction != null) {
      ref.read(transactionServiceProvider.notifier).updateTransaction(transaction);
    } else {
      ref.read(transactionServiceProvider.notifier).addTransaction(transaction);
    }

    // 保存成功を通知して戻る
    Navigator.pop(context, true); // ← true を追加（修正箇所）
  }

  void _confirmAsActual() {
    if (!_formKey.currentState!.validate()) return;

    final currentTransactionAmount = double.parse(_amountController.text.replaceAll(',', ''));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('実績として確定'),
        content: const Text('この予定を実績として確定しますか？\n固定項目の設定は維持されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              double finalAmount = currentTransactionAmount;

              // showAmountInSchedule が false の場合（毎回入力設定）に金額入力ダイアログを表示
              if (!_showAmountInSchedule) {
                final double? inputAmount = await _showAmountInputDialog(currentTransactionAmount);
                if (inputAmount == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('実績化をキャンセルしました。')),
                  );
                  return;
                }
                finalAmount = inputAmount;
              }
              
              final originalId = widget.editingTransaction?.id ?? '';
              
              // メモにカテゴリを含める
              String finalMemo = '${_memoController.text}（予定から確定）';
              if (_selectedCategory != null) {
                finalMemo = _memoController.text.isEmpty 
                    ? '$_selectedCategory（予定から確定）'
                    : '$_selectedCategory - ${_memoController.text}（予定から確定）';
              }
              
              final actualTransaction = Transaction()
                ..id = '${DateTime.now().millisecondsSinceEpoch}_actual_from_$originalId'
                ..title = _titleController.text
                ..amount = finalAmount
                ..date = _selectedDate
                ..type = _selectedType
                ..isFixedItem = false
                ..fixedMonths = []
                ..fixedDay = 1
                ..holidayHandling = HolidayHandling.none
                ..showAmountInSchedule = false
                ..memo = finalMemo
                ..category = _selectedCategory
                ..createdAt = DateTime.now()
                ..updatedAt = DateTime.now();

              ref.read(transactionServiceProvider.notifier).addTransaction(actualTransaction);
              
              Navigator.pop(context);
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('実績として確定しました'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.green,
            ),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  Future<double?> _showAmountInputDialog(double initialAmount) async {
    final controller = TextEditingController(text: initialAmount.round().toString());
    double? result;

    await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('実績金額を入力'),
        content: TextFormField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '金額',
            border: OutlineInputBorder(),
            suffixText: '円',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _ThousandsSeparatorInputFormatter(),
          ],
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(controller.text.replaceAll(',', ''));
              if (amount != null) {
                result = amount;
                Navigator.pop(context);
              }
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
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