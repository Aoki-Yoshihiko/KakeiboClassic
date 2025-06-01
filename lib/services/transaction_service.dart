// lib/services/transaction_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction.dart';
import '../models/monthly_summary.dart';
import '../models/period_summary.dart';
import '../models/holiday_handling.dart';
import 'database_service.dart';
import '../main.dart';

class TransactionService extends StateNotifier<List<Transaction>> {
  final DatabaseService _databaseService;

  TransactionService(this._databaseService) : super([]) {
    _loadTransactions();
  }

  void _loadTransactions() {
    final transactions = _databaseService.transactionBox.values.toList();
    transactions.sort((a, b) => a.date.compareTo(b.date));
    state = transactions;
  }

  Future<void> addTransaction(Transaction transaction) async {
    // 1. まず、渡された transaction が固定項目かどうかをチェック
    if (transaction.isFixedItem) {
      // 固定項目として新規登録・更新される場合

      // 元の固定項目テンプレートを保存（更新の場合は既存を上書き）
      await _databaseService.transactionBox.put(transaction.id, transaction);

      // 登録した現在の月に対して「実績」を生成する
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month);

      // 固定項目が現在月で発生する場合のみ実績を生成
      if (transaction.isFixedInMonth(currentMonth.month)) {
        final actualDateForCurrentMonth = transaction.date;

        // 既にこの固定項目テンプレートから生成された実績がその月に存在しないかチェック
        final existingActual = state.any((t) =>
            t.title == transaction.title &&
            t.date.year == actualDateForCurrentMonth.year &&
            t.date.month == actualDateForCurrentMonth.month &&
            !t.isFixedItem &&
            !t.id.contains('_preview_') &&
            !t.id.contains('_scheduled_') &&
            !t.id.contains('_actual_')
        );

        if (!existingActual) {
          // 新しい実績として保存
          final actualTransaction = Transaction()
            ..id = '${DateTime.now().millisecondsSinceEpoch}_fixed_actual'
            ..title = transaction.title
            ..amount = transaction.amount
            ..date = actualDateForCurrentMonth
            ..type = transaction.type
            ..isFixedItem = false
            ..fixedMonths = []
            ..fixedDay = 1
            ..holidayHandling = HolidayHandling.none
            ..showAmountInSchedule = false
            ..memo = transaction.memo
            ..createdAt = DateTime.now()
            ..updatedAt = DateTime.now();

          await _databaseService.transactionBox.put(actualTransaction.id, actualTransaction);
        }
      }
    } else {
      // 固定項目ではない通常の取引の場合
      await _databaseService.transactionBox.put(transaction.id, transaction);
    }

    _loadTransactions();
  }

  // 新しいメソッド：実績を直接保存（重複防止版）
  Future<void> addActualTransaction(Transaction transaction) async {
    print('=== 実績直接保存 ===');
    print('保存するTransaction: ID=${transaction.id}, 日付=${transaction.date}, isFixedItem=${transaction.isFixedItem}');
    
    // 既存の同一項目・同一日付の実績をチェック
    final existingActual = state.any((t) =>
        t.title == transaction.title &&
        t.date.year == transaction.date.year &&
        t.date.month == transaction.date.month &&
        t.date.day == transaction.date.day &&
        !t.isFixedItem &&
        !t.id.contains('_preview_') &&
        !t.id.contains('_scheduled_')
    );

    if (existingActual) {
      print('既存の実績が存在するため、保存をスキップ');
      return;
    }

    // 直接データベースに保存
    await _databaseService.transactionBox.put(transaction.id, transaction);
    print('実績を保存しました: ${transaction.id}');
    
    // 状態を更新
    _loadTransactions();
  }

  // 新しいメソッド：固定項目を完全削除
  Future<void> deleteFixedItemCompletely(String originalId) async {
    print('=== 固定項目完全削除 ===');
    print('削除対象のoriginalId: $originalId');
    
    // 1. 元の固定項目テンプレートを削除
    await _databaseService.transactionBox.delete(originalId);
    print('固定項目テンプレートを削除: $originalId');
    
    // 2. 関連するすべての予定項目を削除
    final allTransactions = _databaseService.transactionBox.values.toList();
    for (final transaction in allTransactions) {
      if (transaction.id.startsWith('${originalId}_scheduled_') || 
          transaction.id.startsWith('${originalId}_preview_')) {
        await _databaseService.transactionBox.delete(transaction.id);
        print('関連予定を削除: ${transaction.id}');
      }
    }
    
    // 3. 状態を更新
    _loadTransactions();
    print('固定項目完全削除完了');
  }

  Future<void> updateTransaction(Transaction transaction) async {
    final updatedTransaction = transaction.copyWith(
      updatedAt: DateTime.now(),
    );
    await _databaseService.transactionBox.put(transaction.id, updatedTransaction);
    _loadTransactions();
  }

  Future<void> deleteTransaction(String id) async {
    await _databaseService.transactionBox.delete(id);
    _loadTransactions();
  }

  // 実績のみを対象とした月次サマリーを取得するメソッド
  MonthlySummary getMonthlySummary(DateTime month) {
    final transactionsInMonth = state.where((t) {
      return t.date.year == month.year &&
             t.date.month == month.month &&
             !t.isFixedItem;
    }).toList();

    double totalIncome = 0;
    double totalExpense = 0;

    for (var t in transactionsInMonth) {
      if (t.type == TransactionType.income) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }

    return MonthlySummary(
      month: month,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      balance: totalIncome - totalExpense,
      transactions: transactionsInMonth,
    );
  }

  List<Transaction> getTransactionsByMonth(DateTime month, {bool includeFixed = true}) {
    final transactions = state.where((transaction) {
      return transaction.date.year == month.year &&
             transaction.date.month == month.month &&
             !transaction.isFixedItem;
    }).toList();

    if (includeFixed) {
      final fixedItems = _getFixedItemsForMonth(month);
      transactions.addAll(fixedItems);
    }

    transactions.sort((a, b) => a.date.compareTo(b.date));
    return transactions;
  }

  List<Transaction> _getFixedItemsForMonth(DateTime targetMonth) {
    final fixedItems = <Transaction>[];

    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final target = DateTime(targetMonth.year, targetMonth.month);

    if (target.isBefore(currentMonth)) {
      return fixedItems;
    }

    for (final transaction in state) {
      if (transaction.isFixedItem && transaction.isFixedInMonth(targetMonth.month)) {
        final existingSameActual = state.any((t) =>
          t.title == transaction.title &&
          t.date.year == targetMonth.year &&
          t.date.month == targetMonth.month &&
          !t.isFixedItem &&
          !t.id.contains('_preview_') &&
          !t.id.contains('_scheduled_')
        );
        
        if (!existingSameActual) {
          final futureItem = transaction.copyWith(
            id: '${transaction.id}_preview_${targetMonth.year}_${targetMonth.month}',
            date: DateTime(targetMonth.year, targetMonth.month, transaction.fixedDay),
          );
          fixedItems.add(futureItem);
        }
      }
    }
    return fixedItems;
  }

  // スケジュール項目を取得（固定項目を予定として表示）
  List<Transaction> getScheduledItemsForMonth(DateTime month) {
    final scheduledItems = <Transaction>[];

    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final targetMonth = DateTime(month.year, month.month);

    if (targetMonth.isAfter(currentMonth) || (targetMonth.year == currentMonth.year && targetMonth.month == currentMonth.month)) {
      for (final transaction in state) {
        if (transaction.isFixedItem && transaction.isFixedInMonth(month.month)) {
          // 既に実績が存在するかチェック
          final existingTransaction = state.any((t) =>
            t.title == transaction.title &&
            t.date.year == month.year &&
            t.date.month == month.month &&
            !t.isFixedItem &&
            !t.id.contains('_scheduled_') &&
            !t.id.contains('_fixed_actual') &&
            !t.id.contains('_actual_')
          );

          if (!existingTransaction) {
            final adjustedDate = transaction.getAdjustedDate(month);

            final scheduledItem = transaction.copyWith(
              id: '${transaction.id}_scheduled_${month.year}_${month.month}',
              date: adjustedDate,
            );

            scheduledItems.add(scheduledItem);
          }
        }
      }
    }

    scheduledItems.sort((a, b) => a.date.compareTo(b.date));
    return scheduledItems;
  }

  // 期間ごとのサマリーを取得するメソッド
  PeriodSummary getPeriodSummary(DateTime startDate, DateTime endDate) {
    final transactionsInPeriod = state.where((t) {
      return (t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
              t.date.isBefore(endDate.add(const Duration(days: 1)))) &&
             !t.isFixedItem;
    }).toList();

    double totalIncome = 0;
    double totalExpense = 0;

    for (var t in transactionsInPeriod) {
      if (t.type == TransactionType.income) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }

    final categoryTotals = _calculateCategoryTotals(transactionsInPeriod);

    return PeriodSummary(
      startDate: startDate,
      endDate: endDate,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      balance: totalIncome - totalExpense,
      categoryTotals: categoryTotals,
      transactions: transactionsInPeriod,
    );
  }

  Map<String, double> _calculateCategoryTotals(List<Transaction> transactions) {
    final Map<String, double> categoryMap = {};
    for (var t in transactions) {
      final category = t.category ?? (t.type == TransactionType.income ? '収入（その他）' : '支出（その他）');
      categoryMap.update(category, (value) => value + t.amount, ifAbsent: () => t.amount);
    }
    return categoryMap;
  }

  Future<void> addRecurringTransactions(DateTime targetMonth) async {
    final fixedItems = state.where((t) => t.isFixedItem).toList();

    for (final fixedItem in fixedItems) {
      if (fixedItem.isFixedInMonth(targetMonth.month)) {
        final existingItem = state.any((t) =>
          t.title == fixedItem.title &&
          t.date.year == targetMonth.year &&
          t.date.month == targetMonth.month &&
          !t.isFixedItem &&
          !t.id.contains('_preview_') &&
          !t.id.contains('_scheduled_')
        );

        if (!existingItem) {
          final adjustedDate = fixedItem.getAdjustedDate(targetMonth);

          final newTransaction = Transaction();
          newTransaction.id = '${DateTime.now().millisecondsSinceEpoch}_${fixedItem.title}';
          newTransaction.title = fixedItem.title;
          newTransaction.amount = fixedItem.amount;
          newTransaction.date = adjustedDate;
          newTransaction.type = fixedItem.type;
          newTransaction.isFixedItem = false;
          newTransaction.fixedMonths = [];
          newTransaction.fixedDay = fixedItem.fixedDay;
          newTransaction.holidayHandling = HolidayHandling.none;
          newTransaction.showAmountInSchedule = false;
          newTransaction.memo = '${fixedItem.memo ?? ''} (固定項目から自動生成)';
          newTransaction.createdAt = DateTime.now();
          newTransaction.updatedAt = DateTime.now();

          await _databaseService.transactionBox.put(newTransaction.id, newTransaction);
        }
      }
    }
    _loadTransactions();
  }

  // データエクスポート
  Future<String> exportData() async {
    final data = {
      'transactions': state.map((t) => t.toJson()).toList(),
      'exportDate': DateTime.now().toIso8601String(),
      'version': '1.0.0',
    };

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/kurashikku_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(jsonEncode(data));

    return file.path;
  }

  // データインポート
  Future<void> importData(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('ファイルが見つかりません');

    final content = await file.readAsString();
    final data = jsonDecode(content);

    if (data['transactions'] != null) {
      await _databaseService.transactionBox.clear();

      final transactions = (data['transactions'] as List)
          .map((json) => Transaction.fromJson(json))
          .toList();

      for (final transaction in transactions) {
        await _databaseService.transactionBox.put(transaction.id, transaction);
      }

      _loadTransactions();
    }
  }

  // 全データクリア
  Future<void> clearAllData() async {
    await _databaseService.transactionBox.clear();
    _loadTransactions();
  }
}

// Provider定義
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return globalDatabaseService;
});

final transactionServiceProvider = StateNotifierProvider<TransactionService, List<Transaction>>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return TransactionService(databaseService);
});