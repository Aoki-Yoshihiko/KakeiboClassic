// lib/services/transaction_service.dart

import 'dart:convert';
import 'dart:io';
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

  Future<void> _loadTransactions() async {
    // Hiveの読み込みを確実に待つ（より長い遅延）
    await Future.delayed(const Duration(milliseconds: 100));
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
        // 修正：休日処理を適用した正しい日付を取得
        final actualDateForCurrentMonth = transaction.getAdjustedDate(currentMonth);
        // 修正前：final actualDateForCurrentMonth = transaction.date;

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
            ..id = '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}_fixed_actual'
            ..title = transaction.title
            ..amount = transaction.amount
            ..date = actualDateForCurrentMonth // ← 正しい調整済み日付を使用
            ..type = transaction.type
            ..isFixedItem = false
            ..fixedMonths = []
            ..fixedDay = 1
            ..holidayHandling = HolidayHandling.none
            ..showAmountInSchedule = false
            ..memo = transaction.memo
            ..category = transaction.category
            ..createdAt = DateTime.now()
            ..updatedAt = DateTime.now();

          await _databaseService.transactionBox.put(actualTransaction.id, actualTransaction);
          // 実績追加後も少し待つ
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
    } else {
      // 固定項目ではない通常の取引の場合
      await _databaseService.transactionBox.put(transaction.id, transaction);
    }

    // データベースへの書き込みを確実に待ってから状態を更新
    await _loadTransactions();
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
    await _loadTransactions();
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
    await _loadTransactions();
    print('固定項目完全削除完了');
  }

  Future<void> updateTransaction(Transaction transaction) async {
    final updatedTransaction = transaction.copyWith(
      updatedAt: DateTime.now(),
    );
    await _databaseService.transactionBox.put(transaction.id, updatedTransaction);
    await _loadTransactions();
  }

  Future<void> deleteTransaction(String id) async {
    await _databaseService.transactionBox.delete(id);
    await _loadTransactions();
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

    // 現在月より前の場合は固定項目を表示しない
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

    // 現在月より前の場合は予定を表示しない（過去に予定はおかしいため）
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final targetMonth = DateTime(month.year, month.month);
    
    // 過去の月には予定を表示しない
    if (targetMonth.isBefore(currentMonth)) {
      return scheduledItems;
    }

    for (final transaction in state) {
      if (transaction.isFixedItem && transaction.isFixedInMonth(month.month)) {
        // *** 当月の場合は予定を表示しない（実績のみ） ***
        if (targetMonth.year == currentMonth.year && targetMonth.month == currentMonth.month) {
          continue; // 当月は予定を表示しない
        }
        
        // より厳密な重複チェック：
        // 1. 同じ固定項目IDから生成された実績があるか
        // 2. 同じタイトルで同じ月の実績があるか
        final existingTransaction = state.any((t) {
          // 固定項目ではない（実績である）
          if (t.isFixedItem) return false;
          
          // 同じ年月でない場合はスキップ
          if (t.date.year != month.year || t.date.month != month.month) return false;
          
          // 以下のいずれかの条件を満たす場合は重複とみなす
          // 1. IDに元の固定項目のIDが含まれている（_actual_from_XXX形式）
          if (t.id.contains('_actual_from_${transaction.id}')) return true;
          
          // 2. タイトルが一致し、メモに「予定から確定」が含まれている
          if (t.title == transaction.title && 
              t.memo != null && 
              t.memo!.contains('予定から確定')) return true;
          
          // 3. タイトルが一致し、固定項目から自動生成されたもの
          if (t.title == transaction.title && 
              t.memo != null && 
              t.memo!.contains('固定項目から自動生成')) return true;
          
          // 4. 単純にタイトルが一致する実績（手動入力の可能性もあるが安全側に倒す）
          if (t.title == transaction.title) return true;
          
          return false;
        });

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

    scheduledItems.sort((a, b) => a.date.compareTo(b.date));
    return scheduledItems;
  }

// lib/services/transaction_service.dart の getPeriodSummary メソッドを修正

  // 期間ごとのサマリーを取得するメソッド
  PeriodSummary getPeriodSummary(DateTime startDate, DateTime endDate) {
    final now = DateTime.now();
    final currentDate = DateTime(now.year, now.month, now.day);
    
    // 実績データ（日付制限なし - ユーザーが入力した実績は未来日付でも表示）
    final actualTransactions = state.where((t) {
      return (t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
              t.date.isBefore(endDate.add(const Duration(days: 1)))) &&
            !t.isFixedItem; // 固定項目でない実績のみ
            // !t.date.isAfter(currentDate) を削除
    }).toList();

    // 未来期間が含まれる場合は予定データも追加
    List<Transaction> allTransactions = List.from(actualTransactions);
    
    if (endDate.isAfter(currentDate)) {
      // 未来期間の予定データを取得
      final futureMonths = <DateTime>{};
      DateTime month = DateTime(currentDate.year, currentDate.month + 1);
      while (month.isBefore(endDate.add(const Duration(days: 1)))) {
        futureMonths.add(month);
        month = DateTime(month.year, month.month + 1);
      }
      
      for (final month in futureMonths) {
        final scheduledItems = getScheduledItemsForMonth(month);
        final filteredScheduled = scheduledItems.where((t) {
          return t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
                t.date.isBefore(endDate.add(const Duration(days: 1))) &&
                t.showAmountInSchedule; // 金額が確定している予定のみ
        }).toList();
        allTransactions.addAll(filteredScheduled);
      }
    }

    double totalIncome = 0;
    double totalExpense = 0;

    for (var t in allTransactions) {
      if (t.type == TransactionType.income) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }

    final categoryTotals = _calculateCategoryTotals(allTransactions);

    return PeriodSummary(
      startDate: startDate,
      endDate: endDate,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      balance: totalIncome - totalExpense,
      categoryTotals: categoryTotals,
      transactions: allTransactions,
    );
  }

  Map<String, double> _calculateCategoryTotals(List<Transaction> transactions) {
    final Map<String, double> categoryMap = {};
    for (var t in transactions) {
      // categoryフィールドを優先し、なければデフォルト値を使用
      String category;
      if (t.category != null && t.category!.isNotEmpty) {
        category = t.category!;
      } else {
        category = t.type == TransactionType.income ? 'その他収入' : 'その他支出';
      }
      
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
          newTransaction.id = '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}_${fixedItem.title}';
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
          newTransaction.category = fixedItem.category;
          newTransaction.createdAt = DateTime.now();
          newTransaction.updatedAt = DateTime.now();

          await _databaseService.transactionBox.put(newTransaction.id, newTransaction);
        }
      }
    }
    await _loadTransactions();
  }

  // データエクスポート
  Future<String> exportData() async {
    try {
      final data = {
        'transactions': state.map((t) => t.toJson()).toList(),
        'exportDate': DateTime.now().toIso8601String(),
        'version': '1.0.0',
      };

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/kurashikku_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonEncode(data));

      return file.path;
    } catch (e) {
      print('エクスポートエラー: $e');
      throw Exception('データのエクスポートに失敗しました: $e');
    }
  }

  // CSVエクスポート（全データ）
  Future<String> exportToCSV() async {
    try {
      final transactions = state.where((t) => !t.isFixedItem).toList();
      transactions.sort((a, b) => a.date.compareTo(b.date));
      
      return _exportTransactionsToCSV(transactions, 'all_data');
    } catch (e) {
      print('CSVエクスポートエラー: $e');
      throw Exception('CSVエクスポートに失敗しました: $e');
    }
  }

  // CSVエクスポート（月指定）
  Future<String> exportMonthToCSV(DateTime month) async {
    try {
      final transactions = state.where((t) {
        return t.date.year == month.year &&
               t.date.month == month.month &&
               !t.isFixedItem;
      }).toList();
      transactions.sort((a, b) => a.date.compareTo(b.date));
      
      final monthStr = '${month.year}${month.month.toString().padLeft(2, '0')}';
      return _exportTransactionsToCSV(transactions, 'month_$monthStr');
    } catch (e) {
      print('月別CSVエクスポートエラー: $e');
      throw Exception('月別CSVエクスポートに失敗しました: $e');
    }
  }

  // CSVエクスポート（期間指定）
  Future<String> exportPeriodToCSV(DateTime startDate, DateTime endDate) async {
    try {
      final transactions = state.where((t) {
        return t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
               t.date.isBefore(endDate.add(const Duration(days: 1))) &&
               !t.isFixedItem;
      }).toList();
      transactions.sort((a, b) => a.date.compareTo(b.date));
      
      final startStr = '${startDate.year}${startDate.month.toString().padLeft(2, '0')}${startDate.day.toString().padLeft(2, '0')}';
      final endStr = '${endDate.year}${endDate.month.toString().padLeft(2, '0')}${endDate.day.toString().padLeft(2, '0')}';
      return _exportTransactionsToCSV(transactions, 'period_${startStr}_$endStr');
    } catch (e) {
      print('期間別CSVエクスポートエラー: $e');
      throw Exception('期間別CSVエクスポートに失敗しました: $e');
    }
  }

  // CSVエクスポート共通処理
  Future<String> _exportTransactionsToCSV(List<Transaction> transactions, String suffix) async {
    try {
      final buffer = StringBuffer();
      
      // BOM付きUTF-8ヘッダー（Excelでの文字化け防止）
      buffer.write('\uFEFF');
      
      // CSVヘッダー
      buffer.writeln('日付,種類,項目名,金額,カテゴリ,メモ,固定項目');
      
      // データ行
      for (final transaction in transactions) {
        final dateStr = '${transaction.date.year}/${transaction.date.month.toString().padLeft(2, '0')}/${transaction.date.day.toString().padLeft(2, '0')}';
        final typeStr = transaction.type == TransactionType.income ? '収入' : '支出';
        final titleStr = _escapeCsv(transaction.title);
        final amountStr = transaction.amount.round().toString();
        final categoryStr = _escapeCsv(transaction.category ?? '');
        final memoStr = _escapeCsv(transaction.memo ?? '');
        final fixedStr = transaction.isFixedItem ? '固定' : '';
        
        buffer.writeln('$dateStr,$typeStr,$titleStr,$amountStr,$categoryStr,$memoStr,$fixedStr');
      }
      
      // ファイル保存
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/kurashikku_${suffix}_$timestamp.csv');
      await file.writeAsString(buffer.toString());
      
      return file.path;
    } catch (e) {
      print('CSV書き込みエラー: $e');
      throw Exception('CSVファイルの作成に失敗しました: $e');
    }
  }

  // CSV用文字列エスケープ
  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  // データインポート
  Future<void> importData(String filePath) async {
    try {
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

        await _loadTransactions();
      }
    } catch (e) {
      print('インポートエラー: $e');
      throw Exception('データのインポートに失敗しました: $e');
    }
  }

  // CSVインポート
  Future<int> importFromCSV(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) throw Exception('ファイルが見つかりません');

      final content = await file.readAsString();
      final lines = content.split('\n');
      
      if (lines.isEmpty) throw Exception('CSVファイルが空です');
      
      // ヘッダー行をスキップ
      int importedCount = 0;
      
      // 安全なID生成のためのベースタイムスタンプ（1回だけ取得）
      final baseTimestamp = DateTime.now().millisecondsSinceEpoch;
      
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        
        try {
          final fields = _parseCsvLine(line);
          if (fields.length < 6) continue; // 最低限必要なフィールド数
          
          // CSV形式: 日付,種類,項目名,金額,カテゴリ,メモ,固定項目
          final dateStr = fields[0];
          final typeStr = fields[1];
          final title = fields[2];
          final amountStr = fields[3];
          final category = fields.length > 4 ? fields[4] : null;
          final memo = fields.length > 5 ? fields[5] : null;
          final isFixedStr = fields.length > 6 ? fields[6] : '';
          
          // 日付パース
          DateTime? date;
          try {
            final dateParts = dateStr.split('/');
            if (dateParts.length == 3) {
              date = DateTime(
                int.parse(dateParts[0]),
                int.parse(dateParts[1]),
                int.parse(dateParts[2]),
              );
            }
          } catch (e) {
            continue; // 日付パースエラーの場合はスキップ
          }
          
          if (date == null) continue;
          
          // 種類パース
          TransactionType? type;
          if (typeStr == '収入') {
            type = TransactionType.income;
          } else if (typeStr == '支出') {
            type = TransactionType.expense;
          }
          
          if (type == null) continue;
          
          // 金額パース
          final amount = double.tryParse(amountStr);
          if (amount == null) continue;
          
          // 取引作成 - IDのみ安全化（他は一切変更なし）
          final transaction = Transaction()
            ..id = 'csv_import_${baseTimestamp}_${i}_${DateTime.now().microsecond}' // ← より安全なID
            ..title = title
            ..amount = amount
            ..date = date
            ..type = type
            ..isFixedItem = isFixedStr == '固定'
            ..fixedMonths = []
            ..fixedDay = date.day
            ..holidayHandling = HolidayHandling.none
            ..showAmountInSchedule = false
            ..memo = memo?.isEmpty == true ? null : memo
            ..category = category?.isEmpty == true ? null : category
            ..createdAt = DateTime.now()
            ..updatedAt = DateTime.now();
          
          await _databaseService.transactionBox.put(transaction.id, transaction);
          importedCount++;
          
        } catch (e) {
          // エラーの場合はその行をスキップして続行
          print('CSV行 $i のインポートエラー: $e');
          continue;
        }
      }
      
      await _loadTransactions();
      return importedCount;
    } catch (e) {
      print('CSVインポートエラー: $e');
      throw Exception('CSVインポートに失敗しました: $e');
    }
  }

  // CSV行パース（簡易版）
  List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    bool inQuotes = false;
    String currentField = '';
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          // エスケープされたクォート
          currentField += '"';
          i++; // 次の文字をスキップ
        } else {
          // クォートの開始/終了
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        // フィールド区切り
        fields.add(currentField);
        currentField = '';
      } else {
        currentField += char;
      }
    }
    
    // 最後のフィールドを追加
    fields.add(currentField);
    
    return fields;
  }

  // 全データクリア
  Future<void> clearAllData() async {
    await _databaseService.transactionBox.clear();
    await _loadTransactions();
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