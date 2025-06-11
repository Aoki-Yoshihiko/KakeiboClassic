import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/item_template.dart';
import '../models/transaction.dart';
import '../services/item_template_service.dart';
import '../screens/add_transaction_screen.dart';
import '../screens/template_edit_screen.dart';
import '../constants/category_constants.dart';
import '../models/holiday_handling.dart';

class TemplateSelectionDialog extends ConsumerStatefulWidget {
  const TemplateSelectionDialog({super.key});

  @override
  ConsumerState<TemplateSelectionDialog> createState() => _TemplateSelectionDialogState();
}

class _TemplateSelectionDialogState extends ConsumerState<TemplateSelectionDialog> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(itemTemplateServiceProvider);
    final incomeTemplates = templates.where((t) => t.type == TransactionType.income).toList();
    final expenseTemplates = templates.where((t) => t.type == TransactionType.expense).toList();

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // ヘッダー
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'テンプレートから選択',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _showAddTemplateDialog(context),
                        tooltip: 'テンプレート追加',
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // タブ
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: 'すべて (${templates.length})'),
                Tab(text: '収入 (${incomeTemplates.length})'),
                Tab(text: '支出 (${expenseTemplates.length})'),
              ],
            ),

            // タブビュー
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTemplateList(templates),
                  _buildTemplateList(incomeTemplates),
                  _buildTemplateList(expenseTemplates),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateList(List<ItemTemplate> templates) {
    if (templates.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('テンプレートがありません'),
            SizedBox(height: 8),
            Text('+ ボタンでテンプレートを追加できます'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return _buildTemplateCard(template);
      },
    );
  }

  Widget _buildTemplateCard(ItemTemplate template) {
    final isIncome = template.type == TransactionType.income;
    final category = _extractCategoryFromMemo(template.memo);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
          child: Icon(
            category != null 
                ? CategoryConstants.getCategoryIcon(category)
                : (isIncome ? Icons.add_circle : Icons.remove_circle),
            color: category != null
                ? CategoryConstants.getCategoryColor(category, context)
                : (isIncome ? Colors.green : Colors.red),
            size: 20,
          ),
        ),
        title: Text(
          template.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${isIncome ? '+' : '-'}${NumberFormat('#,###').format(template.defaultAmount.round())}円',
              style: TextStyle(
                color: isIncome ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (category != null) 
              Text(
                category,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            if (template.memo != null && template.memo!.isNotEmpty)
              Text(
                template.memo!,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _showEditTemplateDialog(template);
                break;
              case 'delete':
                _confirmDeleteTemplate(template);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('編集'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('削除', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _useTemplate(template),
      ),
    );
  }

  // メモからカテゴリを推測する関数
  String? _extractCategoryFromMemo(String? memo) {
    if (memo == null) return null;
    
    final allCategories = [...CategoryConstants.incomeCategories, ...CategoryConstants.expenseCategories];
    
    for (final category in allCategories) {
      if (memo.contains(category)) {
        return category;
      }
    }
    
    return null;
  }

// lib/widgets/template_selection_dialog.dart の _useTemplate メソッドを修正

  void _useTemplate(ItemTemplate template) async {
    // テンプレートからトランザクションを作成
    final transaction = _createTransactionFromTemplate(template);
    
    // 編集画面で開く
    Navigator.pop(context); // ダイアログを閉じる
    
    final saved = await Navigator.push( // ← saved変数で戻り値を受け取る（修正箇所）
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(editingTransaction: transaction),
      ),
    );
    
    // 保存された場合のみ成功通知を表示（新規追加箇所）
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「${template.title}」を追加しました'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // テンプレートからトランザクションを作成するヘルパーメソッド
  Transaction _createTransactionFromTemplate(ItemTemplate template) {
    final category = _extractCategoryFromMemo(template.memo);
    
    final transaction = Transaction();

    // ID重複防止の修正
    transaction.id = '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
    //          

    transaction.title = template.title;
    transaction.amount = template.defaultAmount;
    transaction.date = DateTime.now();
    transaction.type = template.type;
    transaction.isFixedItem = false;
    transaction.fixedMonths = [];
    transaction.fixedDay = 1;
    transaction.holidayHandling = HolidayHandling.none;
    transaction.showAmountInSchedule = false;
    transaction.memo = template.memo;
    transaction.category = category;
    transaction.createdAt = DateTime.now();
    transaction.updatedAt = DateTime.now();
    
    return transaction;
  }

  void _showAddTemplateDialog(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TemplateEditScreen(),
      ),
    );
  }

  void _showEditTemplateDialog(ItemTemplate template) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TemplateEditScreen(template: template),
      ),
    );
  }

  void _confirmDeleteTemplate(ItemTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('テンプレート削除'),
        content: Text('「${template.title}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref.read(itemTemplateServiceProvider.notifier).deleteTemplate(template.id);
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('テンプレートを削除しました')),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('削除に失敗しました: $e')),
                  );
                }
              }
            },
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}