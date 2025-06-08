import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/item_template.dart';
import '../models/transaction.dart';
import '../models/holiday_handling.dart';
import '../services/item_template_service.dart';
import '../services/transaction_service.dart';
import '../constants/category_constants.dart';
import '../widgets/amount_input_dialog.dart';

class TemplateSelectionDialog extends ConsumerWidget {
  const TemplateSelectionDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(itemTemplateServiceProvider);
    
    if (templates.isEmpty) {
      return AlertDialog(
        title: const Text('テンプレートから選択'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.list_alt,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text('テンプレートがありません'),
            const SizedBox(height: 8),
            const Text(
              '設定画面から項目テンプレートを\n登録してください',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      );
    }

    // 最近使用したテンプレートを上位に表示
    final sortedTemplates = List<ItemTemplate>.from(templates)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'テンプレートから選択',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: sortedTemplates.length,
                itemBuilder: (context, index) {
                  final template = sortedTemplates[index];
                  final category = _findCategoryFromMemo(template.memo);
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: template.type == TransactionType.income
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      child: Icon(
                        category != null 
                            ? CategoryConstants.getCategoryIcon(category)
                            : (template.type == TransactionType.income 
                                ? Icons.add 
                                : Icons.remove),
                        color: category != null
                            ? CategoryConstants.getCategoryColor(category, context)
                            : (template.type == TransactionType.income 
                                ? Colors.green.shade700 
                                : Colors.red.shade700),
                      ),
                    ),
                    title: Text(template.title),
                    subtitle: Text(
                      '${NumberFormat('#,###').format(template.defaultAmount.round())}円',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    ),
                    onTap: () => _useTemplate(context, ref, template),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _findCategoryFromMemo(String? memo) {
    if (memo == null) return null;
    
    // すべてのカテゴリから検索
    final allCategories = [
      ...CategoryConstants.incomeCategories,
      ...CategoryConstants.expenseCategories,
    ];
    
    for (final category in allCategories) {
      if (memo.contains(category)) {
        return category;
      }
    }
    
    return null;
  }

  Future<void> _useTemplate(BuildContext context, WidgetRef ref, ItemTemplate template) async {
    // 金額入力ダイアログを表示
    final amount = await showAmountInputDialog(
      context,
      initialAmount: template.defaultAmount,
    );
    
    if (amount == null) return;
    
    // カテゴリを抽出
    final category = _findCategoryFromMemo(template.memo);
    
    // 取引を作成
    final transaction = Transaction()
      ..id = DateTime.now().millisecondsSinceEpoch.toString()
      ..title = template.title
      ..amount = amount
      ..date = DateTime.now()
      ..type = template.type
      ..isFixedItem = false
      ..fixedMonths = []
      ..fixedDay = 1
      ..holidayHandling = HolidayHandling.none
      ..showAmountInSchedule = false
      ..memo = template.memo
      ..category = category
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
    
    // 保存
    await ref.read(transactionServiceProvider.notifier).addTransaction(transaction);
    
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「${template.title}」を追加しました'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}