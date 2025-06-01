import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/holiday_handling.dart';
import '../services/transaction_service.dart';
import '../widgets/amount_input_dialog.dart'; // ★この行を追加★

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
                            onChanged: (value) => setState(() => _selectedType = value!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<TransactionType>(
                            title: const Text('支出'),
                            value: TransactionType.expense,
                            groupValue: _selectedType,
                            onChanged: (value) => setState(() => _selectedType = value!),
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
                        if (int.tryParse(cleanValue) == null) return '正しい金額を入力してください';
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
                      
                      // 金額表示設定
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('予定での金額表示', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '予定タブで金額を表示する',
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
                                            'OFF',
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
                                            'ON',
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
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _saveTransaction() {
    if (!_formKey.currentState!.validate()) return;

    final transaction = Transaction();
    transaction.id = widget.editingTransaction?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    transaction.title = _titleController.text;
    transaction.amount = double.parse(_amountController.text.replaceAll(',', ''));
    transaction.date = _selectedDate;
    transaction.type = _selectedType;
    transaction.isFixedItem = _isFixedItem;
    transaction.fixedMonths = List.from(_selectedMonths);
    transaction.fixedDay = _fixedDay;
    transaction.holidayHandling = _holidayHandling;
    transaction.showAmountInSchedule = _showAmountInSchedule;
    transaction.memo = _memoController.text.isEmpty ? null : _memoController.text;
    transaction.createdAt = widget.editingTransaction?.createdAt ?? DateTime.now();
    transaction.updatedAt = DateTime.now();

    if (widget.editingTransaction != null) {
      ref.read(transactionServiceProvider.notifier).updateTransaction(transaction);
    } else {
      ref.read(transactionServiceProvider.notifier).addTransaction(transaction);
    }

    Navigator.pop(context);
  }

  void _confirmAsActual() {
    if (!_formKey.currentState!.validate()) return;

    // 現在の入力値を基にTransactionを作成
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
            onPressed: () async { // ★async を追加★
              Navigator.pop(context); // 最初の確認ダイアログを閉じる

              double finalAmount = currentTransactionAmount;

              // ★ここから金額入力ロジックの追加★
              if (finalAmount == 0.0) {
                final double? inputAmount = await showAmountInputDialog(
                  context,
                  initialAmount: 0.0, // 現在0円なので0を初期値として渡す
                );

                if (inputAmount == null) {
                  // ユーザーが金額入力ダイアログでキャンセルした場合
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('実績化をキャンセルしました。')),
                  );
                  return; // 処理を中断
                }
                finalAmount = inputAmount; // ユーザーが入力した金額（0円も含む）を反映
              }
              // ★金額入力ロジックここまで★
              
              // 実績としての新しいTransactionオブジェクトを作成
              final actualTransaction = Transaction()
                ..id = DateTime.now().millisecondsSinceEpoch.toString()
                ..title = _titleController.text
                ..amount = finalAmount // ★ここ: 最終的に確定した金額を使用★
                ..date = _selectedDate
                ..type = _selectedType
                ..isFixedItem = false // 実績なのでfalse
                ..fixedMonths = [] // 実績には不要
                ..fixedDay = 1 // 実績には不要
                ..holidayHandling = HolidayHandling.none // 実績には不要
                ..showAmountInSchedule = false // 実績なのでfalse
                ..memo = '${_memoController.text}（予定から確定）'
                ..createdAt = DateTime.now()
                ..updatedAt = DateTime.now();

              ref.read(transactionServiceProvider.notifier).addTransaction(actualTransaction);
              
              Navigator.pop(context); // AddTransactionScreenを閉じる
              
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