import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/item_template.dart';
import '../models/transaction.dart';
import '../services/item_template_service.dart';
import '../constants/category_constants.dart';
import 'template_edit_screen.dart';

class TemplateManagementScreen extends ConsumerWidget {
  const TemplateManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(itemTemplateServiceProvider);
    final incomeTemplates = templates.where((t) => t.type == TransactionType.income).toList();
    final expenseTemplates = templates.where((t) => t.type == TransactionType.expense).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('項目テンプレート'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '支出'),
              Tab(text: '収入'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () => _showHelpDialog(context),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildTemplateList(context, ref, expenseTemplates, TransactionType.expense),
            _buildTemplateList(context, ref, incomeTemplates, TransactionType.income),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TemplateEditScreen(),
            ),
          ),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildTemplateList(
    BuildContext context, 
    WidgetRef ref,
    List<ItemTemplate> templates,
    TransactionType type,
  ) {
    if (templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.list_alt,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'テンプレートがありません',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'よく使う項目を登録しましょう',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        final category = _findCategoryForTemplate(template);
        
        return Dismissible(
          key: Key(template.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('テンプレートを削除'),
                content: Text('「${template.title}」を削除しますか？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('キャンセル'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('削除'),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) {
            ref.read(itemTemplateServiceProvider.notifier).deleteTemplate(template.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('「${template.title}」を削除しました')),
            );
          },
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: type == TransactionType.income
                    ? Colors.green.shade100
                    : Colors.red.shade100,
                child: Icon(
                  category != null 
                      ? CategoryConstants.getCategoryIcon(category)
                      : (type == TransactionType.income ? Icons.add : Icons.remove),
                  color: category != null
                      ? CategoryConstants.getCategoryColor(category, context)
                      : (type == TransactionType.income 
                          ? Colors.green.shade700 
                          : Colors.red.shade700),
                ),
              ),
              title: Text(template.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${NumberFormat('#,###').format(template.defaultAmount.round())}円',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (template.memo != null && template.memo!.isNotEmpty)
                    Text(
                      template.memo!,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TemplateEditScreen(template: template),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String? _findCategoryForTemplate(ItemTemplate template) {
    // メモからカテゴリを推測（簡易実装）
    if (template.memo == null) return null;
    
    final categories = template.type == TransactionType.income 
        ? CategoryConstants.incomeCategories 
        : CategoryConstants.expenseCategories;
    
    for (final category in categories) {
      if (template.memo!.contains(category)) {
        return category;
      }
    }
    
    return null;
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('項目テンプレートとは'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('よく使う項目を登録しておくことで、素早く入力できる機能です。'),
              SizedBox(height: 12),
              Text('💡 使い方', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('1. よく使う店名や項目を登録'),
              Text('2. ホーム画面の「＋」ボタン長押し'),
              Text('3. テンプレートを選択して入力'),
              SizedBox(height: 12),
              Text('🎯 メリット', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• 入力時間の短縮'),
              Text('• 項目名の統一'),
              Text('• 集計精度の向上'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}