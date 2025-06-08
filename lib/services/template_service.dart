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
      templates.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = templates;
    } catch (e) {
      print('テンプレート読み込みエラー: $e');
      state = [];
    }
  }

  Future<void> addTemplate(ItemTemplate template) async {
    try {
      await globalDatabaseService.itemTemplateBox.put(template.id, template);
      await loadTemplates();
    } catch (e) {
      print('テンプレート追加エラー: $e');
      rethrow;
    }
  }

  Future<void> updateTemplate(ItemTemplate template) async {
    try {
      await globalDatabaseService.itemTemplateBox.put(template.id, template);
      await loadTemplates();
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

  Transaction createTransactionFromTemplate(ItemTemplate template) {
    return Transaction()
      ..id = DateTime.now().millisecondsSinceEpoch.toString()
      ..title = template.title
      ..amount = template.defaultAmount
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
}