import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item_template.dart';
import '../models/transaction.dart';
import '../models/holiday_handling.dart';
import 'database_service.dart';
import '../main.dart';

final templateServiceProvider = StateNotifierProvider<TemplateService, List<ItemTemplate>>((ref) {
  return TemplateService();
});

class TemplateService extends StateNotifier<List<ItemTemplate>> {
  TemplateService() : super([]) {
    loadTemplates();
  }

  Future<void> loadTemplates() async {
    try {
      final templates = globalDatabaseService.itemTemplateBox.values.toList();
      // 更新日時でソート（新しい順）
      templates.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      state = templates;
    } catch (e) {
      print('テンプレート読み込みエラー: $e');
      state = [];
    }
  }

  Future<void> addTemplate(ItemTemplate template) async {
    try {
      await globalDatabaseService.itemTemplateBox.put(template.id, template);
      await loadTemplates(); // 再読み込みでソート
    } catch (e) {
      print('テンプレート追加エラー: $e');
      rethrow;
    }
  }

  Future<void> updateTemplate(ItemTemplate template) async {
    try {
      await globalDatabaseService.itemTemplateBox.put(template.id, template);
      await loadTemplates(); // 再読み込みでソート
    } catch (e) {
      print('テンプレート更新エラー: $e');
      rethrow;
    }
  }

  Future<void> deleteTemplate(String id) async {
    try {
      await globalDatabaseService.itemTemplateBox.delete(id);
      state = state.where((t) => t.id != id).toList();
    } catch (e) {
      print('テンプレート削除エラー: $e');
      rethrow;
    }
  }

  // テンプレートからトランザクションを作成
  Transaction createTransactionFromTemplate(ItemTemplate template) {
    return Transaction()
      ..id = DateTime.now().millisecondsSinceEpoch.toString()
      ..title = template.title
      ..amount = template.amount
      ..date = DateTime.now()
      ..type = template.type
      ..isFixedItem = false
      ..fixedMonths = []
      ..showAmountInSchedule = false
      ..memo = template.memo
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now()
      ..fixedDay = 1
      ..holidayHandling = HolidayHandling.none
      ..category = template.category;
  }

  // よく使う取引からテンプレートを作成する機能
  Future<void> createTemplateFromTransaction(Transaction transaction, String templateName) async {
    final template = ItemTemplate()
      ..id = DateTime.now().millisecondsSinceEpoch.toString()
      ..title = templateName.isEmpty ? transaction.title : templateName
      ..amount = transaction.amount
      ..type = transaction.type
      ..memo = transaction.memo
      ..category = transaction.category
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();

    await addTemplate(template);
  }

  // カテゴリ別テンプレート取得
  List<ItemTemplate> getTemplatesByCategory(String? category) {
    if (category == null) return state;
    return state.where((t) => t.category == category).toList();
  }

  // 収入テンプレート
  List<ItemTemplate> get incomeTemplates =>
      state.where((t) => t.type == TransactionType.income).toList();

  // 支出テンプレート
  List<ItemTemplate> get expenseTemplates =>
      state.where((t) => t.type == TransactionType.expense).toList();
}