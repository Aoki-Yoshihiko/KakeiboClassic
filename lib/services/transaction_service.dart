// lib/services/transaction_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // @required の代わりに late や nullable を使うため、あるいは必要に応じて
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction.dart';
import '../models/monthly_summary.dart'; // MonthlySummary をインポート
import '../models/period_summary.dart';   // PeriodSummary をインポート
import '../models/holiday_handling.dart';
import 'database_service.dart';
import '../main.dart'; // globalDatabaseServiceのため

class TransactionService extends StateNotifier<List<Transaction>> {
  final DatabaseService _databaseService;

  TransactionService(this._databaseService) : super([]) {
    _loadTransactions();
  }

  void _loadTransactions() {
    final transactions = _databaseService.transactionBox.values.toList();
    transactions.sort((a, b) => a.date.compareTo(b.date)); // 日付順（昇順）に変更
    state = transactions;
  }

  Future<void> addTransaction(Transaction transaction) async {
    // 1. まず、渡された transaction が固定項目かどうかをチェック
    if (transaction.isFixedItem) {
      // 固定項目として新規登録・更新される場合

      // 元の固定項目テンプレートを保存（更新の場合は既存を上書き）
      // ここで保存されるのはisFixedItemがtrueの「テンプレート」
      await _databaseService.transactionBox.put(transaction.id, transaction);

      // 登録した現在の月に対して「実績」を生成する
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month);

      // 固定項目が現在月で発生する場合のみ実績を生成
      if (transaction.isFixedInMonth(currentMonth.month)) {
        // 現在月の日付は、AddTransactionScreenでユーザーが指定した日付を使用する
        // または、固定日のルールを適用する場合は transaction.getAdjustedDate(currentMonth) を使用
        // ここでは「指定した日にちで表示」という要件を優先し、transaction.date をそのまま使う
        // （もしfixedDayを適用したいなら adjustedDate を使う）
        final actualDateForCurrentMonth = transaction.date;

        // 既にこの固定項目テンプレートから生成された実績がその月に存在しないかチェック
        // （タイトルと日付が一致する isFixedItem: false の実績）
        final existingActual = state.any((t) =>
            t.title == transaction.title &&
            t.date.year == actualDateForCurrentMonth.year &&
            t.date.month == actualDateForCurrentMonth.month &&
            !t.isFixedItem &&
            !t.id.contains('_preview_') && // プレビュー項目は除外
            !t.id.contains('_scheduled_') // スケジュール項目は除外
        );

        if (!existingActual) {
          // 新しい実績として保存
          final actualTransaction = Transaction()
            ..id = '${DateTime.now().millisecondsSinceEpoch}_fixed_actual' // IDを_fixed_actualと区別
            ..title = transaction.title
            ..amount = transaction.amount
            ..date = actualDateForCurrentMonth // AddTransactionScreenで指定した日付
            ..type = transaction.type
            ..isFixedItem = false // 実績として登録されるのでfalse
            ..fixedMonths = [] // 実績には不要
            ..fixedDay = 1 // 実績には不要
            ..holidayHandling = HolidayHandling.none // 実績には不要
            ..showAmountInSchedule = false // 実績なのでfalse
            ..memo = transaction.memo // 必要に応じて "(自動生成)" などを追加
            ..createdAt = DateTime.now()
            ..updatedAt = DateTime.now();

          await _databaseService.transactionBox.put(actualTransaction.id, actualTransaction);
        }
      }
    } else {
      // 固定項目ではない通常の取引の場合
      await _databaseService.transactionBox.put(transaction.id, transaction);
    }

    _loadTransactions(); // Hiveの変更をStateNotifierに反映
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
    // まず、指定された月の実績（isFixedItemがfalseのもの）のみをフィルタリング
    final transactionsInMonth = state.where((t) {
      return t.date.year == month.year &&
             t.date.month == month.month &&
             !t.isFixedItem; // ここが重要: 実績のみを含める
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
      transactions: transactionsInMonth, // 実績のリストを渡す
    );
  }

  // 固定項目を含めて月別取引を取得（未来表示対応）
  // このメソッドは現在どこからも呼び出されていないため、必要に応じて削除または用途を定義してください。
  List<Transaction> getTransactionsByMonth(DateTime month, {bool includeFixed = true}) {
    // isFixedItemがtrueのものは実績として含めないようにフィルタリング
    final transactions = state.where((transaction) {
      return transaction.date.year == month.year &&
             transaction.date.month == month.month &&
             !transaction.isFixedItem; // 実績のみ
    }).toList();

    // 固定項目を未来の月に表示 (ここでのfixedItemsはプレビュー用なのでそのまま)
    if (includeFixed) {
      final fixedItems = _getFixedItemsForMonth(month);
      transactions.addAll(fixedItems);
    }

    // 日付順で昇順ソート
    transactions.sort((a, b) => a.date.compareTo(b.date));
    return transactions;
  }

  // 指定月の固定項目を取得（プレビュー用）
  List<Transaction> _getFixedItemsForMonth(DateTime targetMonth) {
    final fixedItems = <Transaction>[];

    // 現在月以降のみプレビュー表示（過去月は表示しない）
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final target = DateTime(targetMonth.year, targetMonth.month);

    if (target.isBefore(currentMonth)) {
      return fixedItems; // 過去月の場合は空のリストを返す
    }

    for (final transaction in state) {
      // ここではisFixedItemがtrueのものを対象とする
      if (transaction.isFixedItem && transaction.isFixedInMonth(targetMonth.month)) {
        // 既に同じ項目が存在するかチェック (実績として確定済みのもの)
        final existingSameActual = state.any((t) =>
          t.title == transaction.title &&
          t.date.year == targetMonth.year &&
          t.date.month == targetMonth.month &&
          !t.isFixedItem && // 実績であること
          !t.id.contains('_preview_') && // プレビュー項目は除外
          !t.id.contains('_scheduled_') // スケジュール項目は除外
        );
        
        // ※ここで_preview_と_scheduled_ IDをチェックしているのは、それらが永続化されていない
        // 一時的な表示用IDであることを前提としています。もしそれらも永続化されるなら、
        // 別の識別子が必要になるかもしれません。
        
        // 既存の実績がない場合にのみプレビューを生成
        if (!existingSameActual) {
          // 未来の月用に新しいTransactionを作成（表示用）
          final futureItem = transaction.copyWith(
            id: '${transaction.id}_preview_${targetMonth.year}_${targetMonth.month}',
            date: DateTime(targetMonth.year, targetMonth.month, transaction.fixedDay), // 固定日を適用
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

    // 現在の月以降の固定項目を予定として表示
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final targetMonth = DateTime(month.year, month.month);

    // 未来の月の場合のみ固定項目を予定として表示（過去月は表示しない）
    // および、現在月の場合も、まだ実績がない固定項目は予定として表示
    if (targetMonth.isAfter(currentMonth) || (targetMonth.year == currentMonth.year && targetMonth.month == currentMonth.month)) {
      for (final transaction in state) {
        // ここではisFixedItemがtrueのものを対象とする
        if (transaction.isFixedItem && transaction.isFixedInMonth(month.month)) {
          // 既に実績が存在するかチェック（実績として確定済みのもの）
          final existingTransaction = state.any((t) =>
            t.title == transaction.title &&
            t.date.year == month.year &&
            t.date.month == month.month &&
            !t.isFixedItem && // 実績であること
            !t.id.contains('_scheduled_') && // スケジュール項目は除外
            !t.id.contains('_fixed_actual') // 固定項目登録時に自動生成された実績もチェック
          );

          if (!existingTransaction) {
            // 調整された日付を取得
            final adjustedDate = transaction.getAdjustedDate(month);

            // 表示用の新しいTransactionを作成
            final scheduledItem = transaction.copyWith(
              id: '${transaction.id}_scheduled_${month.year}_${month.month}',
              date: adjustedDate,
            );

            scheduledItems.add(scheduledItem);
          }
        }
      }
    }

    // 日付順でソート
    scheduledItems.sort((a, b) => a.date.compareTo(b.date));
    return scheduledItems;
  }

  // 期間ごとのサマリーを取得するメソッド
  PeriodSummary getPeriodSummary(DateTime startDate, DateTime endDate) {
    // 指定された期間内の実績（isFixedItemがfalseのもの）のみをフィルタリング
    final transactionsInPeriod = state.where((t) {
      // 日付が期間内であること（startDate <= t.date <= endDate）
      // endDateは日を含まず月までなので、endDateの翌日の0時より前で判断する
      return (t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
              t.date.isBefore(endDate.add(const Duration(days: 1)))) &&
             !t.isFixedItem; // 実績のみを含める
    }).toList();

    double totalIncome = 0;
    double totalExpense = 0;

    // フィルタリングされた取引を基に収入と支出を集計
    for (var t in transactionsInPeriod) {
      if (t.type == TransactionType.income) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }

    // カテゴリ別の合計金額を計算
    final categoryTotals = _calculateCategoryTotals(transactionsInPeriod);

    return PeriodSummary(
      startDate: startDate,
      endDate: endDate,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      balance: totalIncome - totalExpense,
      categoryTotals: categoryTotals, // 計算した Map を渡す
      transactions: transactionsInPeriod,
    );
  }

  // 項目別集計を計算するヘルパーメソッド
  // Transactionモデルに'category'プロパティがあると仮定します。
  // なければ、t.titleなどを代わりに使用するか、Transactionモデルにcategoryプロパティを追加してください。
  Map<String, double> _calculateCategoryTotals(List<Transaction> transactions) {
    final Map<String, double> categoryMap = {};
    for (var t in transactions) {
      // t.category が null の場合のフォールバックロジック
      final category = t.category ?? (t.type == TransactionType.income ? '収入（その他）' : '支出（その他）');
      categoryMap.update(category, (value) => value + t.amount, ifAbsent: () => t.amount);
    }
    return categoryMap;
  }

  // 固定項目の自動生成（改良版）
  // このメソッドは、月が切り替わったときに過去の月の実績を生成するために使用されるべきです。
  // 現在の `addTransaction` のロジックと重複する部分があるので、
  // このメソッドの呼び出し元を確認し、必要に応じて調整してください。
  // 例えば、アプリ起動時や月を跨いだ際に一度だけ実行するなど。
  Future<void> addRecurringTransactions(DateTime targetMonth) async {
    final fixedItems = state.where((t) => t.isFixedItem).toList();

    for (final fixedItem in fixedItems) {
      if (fixedItem.isFixedInMonth(targetMonth.month)) {
        // 既に同じ項目が存在するかチェック
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
          newTransaction.isFixedItem = false; // 生成されたものは固定フラグを外す
          newTransaction.fixedMonths = [];
          newTransaction.fixedDay = fixedItem.fixedDay;
          newTransaction.holidayHandling = HolidayHandling.none;
          newTransaction.showAmountInSchedule = false;
          newTransaction.memo = '${fixedItem.memo ?? ''} (固定項目から自動生成)';
          newTransaction.createdAt = DateTime.now();
          newTransaction.updatedAt = DateTime.now();

          // addTransaction を呼び出すのではなく、直接 Hive に put するか、
          // addTransaction のロジックを再帰的に呼ばないように調整が必要。
          // ここでは、既に addTransaction が実績生成のロジックを持つため、
          // このメソッド自体が不要になるか、あるいは目的を再定義する必要があります。
          // いったん、このメソッドは現状維持としますが、
          // addTransaction の変更により、このメソッドの役割が変わる可能性があります。
          await _databaseService.transactionBox.put(newTransaction.id, newTransaction);
        }
      }
    }
    _loadTransactions(); // Hiveの変更をStateNotifierに反映
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
      // 既存データをクリア
      await _databaseService.transactionBox.clear();

      // インポート
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
  return globalDatabaseService; // グローバルインスタンスを使用
});

final transactionServiceProvider = StateNotifierProvider<TransactionService, List<Transaction>>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return TransactionService(databaseService);
});