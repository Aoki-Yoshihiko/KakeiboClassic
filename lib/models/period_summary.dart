import 'transaction.dart';

class PeriodSummary {
  final DateTime startDate;
  final DateTime endDate;
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final Map<String, double> categoryTotals;
  final List<Transaction> transactions;

  PeriodSummary({
    required this.startDate,
    required this.endDate,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.categoryTotals,
    required this.transactions,
  });

  // 期間の日数を取得
  int get dayCount => endDate.difference(startDate).inDays + 1;

  // 日次平均収入
  double get dailyAverageIncome => totalIncome / dayCount;

  // 日次平均支出
  double get dailyAverageExpense => totalExpense / dayCount;

  // 日次平均残高
  double get dailyAverageBalance => balance / dayCount;

  // 未来期間が含まれているかどうか
  bool get includesFuture => endDate.isAfter(DateTime.now());

  // 収入カテゴリの合計
  Map<String, double> get incomeCategoryTotals {
    return Map.fromEntries(
      categoryTotals.entries.where((entry) => 
        transactions.any((t) => t.category == entry.key && t.type == TransactionType.income)
      )
    );
  }

  // 支出カテゴリの合計
  Map<String, double> get expenseCategoryTotals {
    return Map.fromEntries(
      categoryTotals.entries.where((entry) => 
        transactions.any((t) => t.category == entry.key && t.type == TransactionType.expense)
      )
    );
  }

  @override
  String toString() {
    return 'PeriodSummary(${startDate.toIso8601String()} to ${endDate.toIso8601String()}, '
           'income: $totalIncome, expense: $totalExpense, balance: $balance)';
  }
}