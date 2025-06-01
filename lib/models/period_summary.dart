// lib/models/period_summary.dart
import 'package:intl/intl.dart'; // DateFormatのために追加
import 'transaction.dart'; // Transaction モデルをインポート

class PeriodSummary {
  final DateTime startDate;
  final DateTime endDate;
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final Map<String, double> categoryTotals; // ★追加：項目別集計
  final List<Transaction> transactions; // この期間に含まれる取引のリスト

  PeriodSummary({
    required this.startDate,
    required this.endDate,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.categoryTotals, // ★追加：必須引数
    this.transactions = const [], // デフォルト値を設定
  });

  // 表示用のゲッター (必要に応じて)
  String get periodDisplay {
    final startFormat = DateFormat('yyyy/MM/dd', 'ja');
    final endFormat = DateFormat('yyyy/MM/dd', 'ja');
    return '${startFormat.format(startDate)} - ${endFormat.format(endDate)}';
  }

  // JSONから復元するためのファクトリコンストラクタ（必要であれば）
  // Hiveを使っているので通常は不要ですが、エクスポート・インポート機能がある場合は役立ちます
  factory PeriodSummary.fromJson(Map<String, dynamic> json) {
    return PeriodSummary(
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      totalIncome: (json['totalIncome'] as num).toDouble(),
      totalExpense: (json['totalExpense'] as num).toDouble(),
      balance: (json['balance'] as num).toDouble(),
      // JSONからMap<String, double>への変換
      categoryTotals: Map<String, double>.from(
          (json['categoryTotals'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, (value as num).toDouble()),
          ) ?? {}, // デフォルト値として空のMapを設定
      ),
      transactions: (json['transactions'] as List<dynamic>?)
              ?.map((e) => Transaction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  // JSONに変換するためのメソッド（必要であれば）
  Map<String, dynamic> toJson() {
    return {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'balance': balance,
      'categoryTotals': categoryTotals, // ★追加：JSONに含める
      'transactions': transactions.map((e) => e.toJson()).toList(),
    };
  }
}