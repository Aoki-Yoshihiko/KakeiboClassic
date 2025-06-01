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
}
