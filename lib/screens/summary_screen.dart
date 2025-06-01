import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';

class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final transactionService = ref.watch(transactionServiceProvider.notifier);
    final summary = transactionService.getPeriodSummary(_startDate, _endDate);
    
    // カテゴリでフィルタリング
    final filteredTransactions = _selectedCategory == null
        ? summary.transactions
        : summary.transactions.where((t) => t.category == _selectedCategory).toList();

    final filteredIncome = filteredTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
    
    final filteredExpense = filteredTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('サマリー'),
      ),
      body: Column(
        children: [
          // 期間選択
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('期間選択', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectStartDate(),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: '開始日',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(DateFormat('yyyy/MM/dd').format(_startDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectEndDate(),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: '終了日',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(DateFormat('yyyy/MM/dd').format(_endDate)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // カテゴリフィルター
                  DropdownButtonFormField<String?>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'カテゴリフィルター',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('すべて'),
                      ),
                      ...summary.categoryTotals.keys.map((category) =>
                          DropdownMenuItem<String?>(
                            value: category,
                            child: Text(category),
                          ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // サマリー表示
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSummaryRow('収入', filteredIncome, Colors.green),
                  const Divider(),
                  _buildSummaryRow('支出', filteredExpense, Colors.red),
                  const Divider(),
                  _buildSummaryRow(
                    '収支',
                    filteredIncome - filteredExpense,
                    (filteredIncome - filteredExpense) >= 0 ? Colors.green : Colors.red,
                    isBalance: true,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // カテゴリ別集計（選択されていない場合のみ）
          if (_selectedCategory == null)
            Expanded(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'カテゴリ別集計',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: summary.categoryTotals.length,
                        itemBuilder: (context, index) {
                          final entry = summary.categoryTotals.entries.elementAt(index);
                          final transactions = summary.transactions
                              .where((t) => t.category == entry.key)
                              .toList();
                          final isIncome = transactions.isNotEmpty && 
                              transactions.first.type == TransactionType.income;
                          
                          return ListTile(
                            title: Text(entry.key),
                            subtitle: Text('${transactions.length}件'),
                            trailing: Text(
                              '${NumberFormat('#,###').format(entry.value.round())}円',
                              style: TextStyle(
                                color: isIncome ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                _selectedCategory = entry.key;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            // 選択カテゴリの取引一覧
            Expanded(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            '$_selectedCategory の取引',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategory = null;
                              });
                            },
                            child: const Text('クリア'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredTransactions.length,
                        itemBuilder: (context, index) {
                          final transaction = filteredTransactions[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: transaction.type == TransactionType.income
                                  ? Colors.green
                                  : Colors.red,
                              child: Icon(
                                transaction.type == TransactionType.income
                                    ? Icons.add
                                    : Icons.remove,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(transaction.title),
                            subtitle: Text(DateFormat('yyyy/MM/dd').format(transaction.date)),
                            trailing: Text(
                              '${NumberFormat('#,###').format(transaction.amount.round())}円',
                              style: TextStyle(
                                color: transaction.type == TransactionType.income
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, Color color, {bool isBalance = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBalance ? 18 : 16,
            fontWeight: isBalance ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '${isBalance && amount > 0 ? '+' : ''}${NumberFormat('#,###').format(amount.round())}円',
          style: TextStyle(
            fontSize: isBalance ? 18 : 16,
            fontWeight: isBalance ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _endDate = date;
      });
    }
  }
}