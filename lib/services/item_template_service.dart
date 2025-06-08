import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item_template.dart';
// import '../models/transaction.dart';  // TransactionType用
import 'database_service.dart';
import 'transaction_service.dart';  // databaseServiceProviderのインポートを追加

// Provider定義
final itemTemplateServiceProvider = StateNotifierProvider<ItemTemplateService, List<ItemTemplate>>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return ItemTemplateService(databaseService);
});

class ItemTemplateService extends StateNotifier<List<ItemTemplate>> {
  final DatabaseService _databaseService;

  ItemTemplateService(this._databaseService) : super([]) {
    _loadTemplates();
  }

  // テンプレート一覧を読み込み
  void _loadTemplates() {
    final templates = _databaseService.itemTemplateBox.values.toList();
    templates.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = templates;
  }

  // テンプレートを追加
  Future<void> addTemplate(ItemTemplate template) async {
    await _databaseService.itemTemplateBox.put(template.id, template);
    _loadTemplates();
  }

  // テンプレートを更新
  Future<void> updateTemplate(ItemTemplate template) async {
    await _databaseService.itemTemplateBox.put(template.id, template);
    _loadTemplates();
  }

  // テンプレートを削除
  Future<void> deleteTemplate(String id) async {
    await _databaseService.itemTemplateBox.delete(id);
    _loadTemplates();
  }

  // IDでテンプレートを取得
  ItemTemplate? getTemplateById(String id) {
    return _databaseService.itemTemplateBox.get(id);
  }

  // タイプ別テンプレート取得
  List<ItemTemplate> getTemplatesByType(TransactionType type) {
    return state.where((template) => template.type == type).toList();
  }

  // よく使うテンプレート取得（作成日順）
  List<ItemTemplate> getRecentTemplates({int limit = 5}) {
    final sortedTemplates = List<ItemTemplate>.from(state);
    sortedTemplates.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sortedTemplates.take(limit).toList();
  }

  // テンプレート検索
  List<ItemTemplate> searchTemplates(String query) {
    if (query.isEmpty) return state;

    final lowerQuery = query.toLowerCase();
    return state.where((template) =>
      template.title.toLowerCase().contains(lowerQuery) ||
      (template.memo?.toLowerCase().contains(lowerQuery) ?? false)
    ).toList();
  }

  // 全データクリア
  Future<void> clearAllTemplates() async {
    await _databaseService.itemTemplateBox.clear();
    state = [];
  }

  // デフォルトテンプレートを作成
  Future<void> createDefaultTemplates() async {
    final defaultTemplates = [
      // 【あなたの最初のリクエスト分】コンビニなど
      ItemTemplate(
        id: 'template_convenience',
        title: 'コンビニ',
        defaultAmount: 500,
        type: TransactionType.expense,
        memo: '日用品',
        createdAt: DateTime.now(),
      ),
      ItemTemplate(
        id: 'template_supermarket',
        title: 'スーパー',
        defaultAmount: 3000,
        type: TransactionType.expense,
        memo: '食費',
        createdAt: DateTime.now(),
      ),
      ItemTemplate(
        id: 'template_coffee',
        title: 'カフェ',
        defaultAmount: 600,
        type: TransactionType.expense,
        memo: '食費',
        createdAt: DateTime.now(),
      ),
      ItemTemplate(
        id: 'template_train',
        title: '電車代',
        defaultAmount: 200,
        type: TransactionType.expense,
        memo: '交通費',
        createdAt: DateTime.now(),
      ),
      ItemTemplate(
        id: 'template_lunch',
        title: 'ランチ',
        defaultAmount: 1000,
        type: TransactionType.expense,
        memo: '食費',
        createdAt: DateTime.now(),
      ),
      ItemTemplate(
        id: 'template_taxi',
        title: 'タクシー',
        defaultAmount: 2000,
        type: TransactionType.expense,
        memo: '交通費',
        createdAt: DateTime.now(),
      ),
      ItemTemplate(
        id: 'template_drugstore',
        title: 'ドラッグストア',
        defaultAmount: 2000,
        type: TransactionType.expense,
        memo: '日用品',
        createdAt: DateTime.now(),
      ),
      ItemTemplate(
        id: 'template_gasoline',
        title: 'ガソリン',
        defaultAmount: 5000,
        type: TransactionType.expense,
        memo: '交通費',
        createdAt: DateTime.now(),
      ),

      // 【あなたの後から提示した】給料や光熱費など
      ItemTemplate(
        id: 'template_salary',
        title: '給料',
        defaultAmount: 250000,
        type: TransactionType.income,
        memo: '毎月の給与',
        createdAt: DateTime.now(),
      ),
      ItemTemplate(
        id: 'template_rent',
        title: '家賃',
        defaultAmount: 80000,
        type: TransactionType.expense,
        memo: '住居費',
        createdAt: DateTime.now(),
      ),
      ItemTemplate(
        id: 'template_electricity',
        title: '電気代',
        defaultAmount: 8000,
        type: TransactionType.expense,
        memo: '光熱費',
        createdAt: DateTime.now(),
      ),
      ItemTemplate(
        id: 'template_gas',
        title: 'ガス代',
        defaultAmount: 5000,
        type: TransactionType.expense,
        memo: '光熱費',
        createdAt: DateTime.now(),
      ),
      ItemTemplate(
        id: 'template_water',
        title: '水道代',
        defaultAmount: 3000,
        type: TransactionType.expense,
        memo: '光熱費',
        createdAt: DateTime.now(),
      ),
      ItemTemplate(
        id: 'template_internet',
        title: 'インターネット代',
        defaultAmount: 5000,
        type: TransactionType.expense,
        memo: '通信費',
        createdAt: DateTime.now(),
      ),
      ItemTemplate(
        id: 'template_phone',
        title: '携帯電話代',
        defaultAmount: 8000,
        type: TransactionType.expense,
        memo: '通信費',
        createdAt: DateTime.now(),
      ),
      ItemTemplate(
        id: 'template_food',
        title: '食費',
        defaultAmount: 40000,
        type: TransactionType.expense,
        memo: '生活費',
        createdAt: DateTime.now(),
      ),
    ];

    for (final template in defaultTemplates) {
      // 既存のテンプレートがない場合のみ追加
      if (getTemplateById(template.id) == null) {
        await addTemplate(template);
      }
    }
  }
}
