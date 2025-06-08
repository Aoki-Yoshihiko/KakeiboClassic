import 'transaction.dart';

class MonthlySummary {
  final DateTime month;
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final List<Transaction> transactions;

  MonthlySummary({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.transactions,
  });

  // 月の日数を取得
  int get daysInMonth {
    final nextMonth = DateTime(month.year, month.month + 1, 1);
    final lastDayOfMonth = nextMonth.subtract(const Duration(days: 1));
    return lastDayOfMonth.day;
  }

  // 日次平均収入
  double get dailyAverageIncome => totalIncome / daysInMonth;

  // 日次平均支出
  double get dailyAverageExpense => totalExpense / daysInMonth;

  // 日次平均残高
  double get dailyAverageBalance => balance / daysInMonth;

  // 収入の取引のみ
  List<Transaction> get incomeTransactions => 
      transactions.where((t) => t.type == TransactionType.income).toList();

  // 支出の取引のみ
  List<Transaction> get expenseTransactions => 
      transactions.where((t) => t.type == TransactionType.expense).toList();

  // カテゴリ別集計
  Map<String, double> get categoryTotals {
    final Map<String, double> totals = {};
    for (final transaction in transactions) {
      final category = transaction.category ?? 
          (transaction.type == TransactionType.income ? '収入（その他）' : '支出（その他）');
      totals.update(category, (value) => value + transaction.amount, ifAbsent: () => transaction.amount);
    }
    return totals;
  }

  @override
  String toString() {
    return 'MonthlySummary(${month.year}/${month.month}, '
           'income: $totalIncome, expense: $totalExpense, balance: $balance)';
  }
}