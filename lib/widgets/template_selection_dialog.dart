import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/item_template.dart';
import '../models/transaction.dart';
import '../services/template_service.dart';
import '../screens/add_transaction_screen.dart';
import '../constants/category_constants.dart';

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
    final templates = ref.watch(templateServiceProvider);
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
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
          child: Icon(
            CategoryConstants.getCategoryIcon(template.category),
            color: isIncome ? Colors.green : Colors.red,
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
              '${isIncome ? '+' : '-'}${NumberFormat('#,###').format(template.amount)}円',
              style: TextStyle(
                color: isIncome ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (template.category != null) 
              Text(
                template.category!,
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

  void _useTemplate(ItemTemplate template) async {
    // テンプレートからトランザクションを作成
    final transaction = ref.read(templateServiceProvider.notifier).createTransactionFromTemplate(template);
    
    // 編集画面で開く
    Navigator.pop(context); // ダイアログを閉じる
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          initialType: template.type,
          editingTransaction: transaction,
        ),
      ),
    );

    // 結果に応じてメッセージ表示
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${template.title}」を追加しました')),
      );
    }
  }

  void _showAddTemplateDialog(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddTemplateScreen(),
      ),
    );
    
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('テンプレートを追加しました')),
      );
    }
  }

  void _showEditTemplateDialog(ItemTemplate template) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTemplateScreen(editingTemplate: template),
      ),
    );
    
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('テンプレートを更新しました')),
      );
    }
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
                await ref.read(templateServiceProvider.notifier).deleteTemplate(template.id);
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

// テンプレート追加・編集画面
class AddTemplateScreen extends ConsumerStatefulWidget {
  final ItemTemplate? editingTemplate;

  const AddTemplateScreen({super.key, this.editingTemplate});

  @override
  ConsumerState<AddTemplateScreen> createState() => _AddTemplateScreenState();
}

class _AddTemplateScreenState extends ConsumerState<AddTemplateScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  
  TransactionType _type = TransactionType.expense;
  String? _category;

  @override
  void initState() {
    super.initState();
    
    if (widget.editingTemplate != null) {
      final template = widget.editingTemplate!;
      _titleController.text = template.title;
      _amountController.text = template.amount.toString();
      _memoController.text = template.memo ?? '';
      _type = template.type;
      _category = template.category;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editingTemplate != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'テンプレート編集' : 'テンプレート追加'),
        actions: [
          TextButton(
            onPressed: _saveTemplate,
            child: const Text('保存', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // タイトル
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'タイトル *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 16),

            // 金額
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '金額 *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_yen),
              ),
            ),
            const SizedBox(height: 16),

            // 収入/支出選択
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('種類', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SegmentedButton<TransactionType>(
                      segments: const [
                        ButtonSegment(
                          value: TransactionType.income,
                          label: Text('収入'),
                          icon: Icon(Icons.add_circle, color: Colors.green),
                        ),
                        ButtonSegment(
                          value: TransactionType.expense,
                          label: Text('支出'),
                          icon: Icon(Icons.remove_circle, color: Colors.red),
                        ),
                      ],
                      selected: {_type},
                      onSelectionChanged: (set) {
                        setState(() {
                          _type = set.first;
                          _category = null; // タイプ変更時はカテゴリリセット
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // カテゴリ選択
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'カテゴリ',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: CategoryConstants.getCategoriesForType(_type)
                  .map((category) => DropdownMenuItem(
                        value: category,
                        child: Row(
                          children: [
                            Icon(
                              CategoryConstants.getCategoryIcon(category),
                              size: 20,
                              color: CategoryConstants.getCategoryColor(category, context),
                            ),
                            const SizedBox(width: 8),
                            Text(category),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 16),

            // メモ
            TextField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: 'メモ（任意）',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // 保存ボタン（大きめ）
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saveTemplate,
                icon: const Icon(Icons.save),
                label: Text(isEditing ? 'テンプレートを更新' : 'テンプレートを追加'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveTemplate() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タイトルを入力してください')),
      );
      return;
    }

    if (_amountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('金額を入力してください')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正しい金額を入力してください')),
      );
      return;
    }

    try {
      final template = ItemTemplate()
        ..id = widget.editingTemplate?.id ?? DateTime.now().millisecondsSinceEpoch.toString()
        ..title = _titleController.text.trim()
        ..amount = amount
        ..type = _type
        ..memo = _memoController.text.trim().isEmpty ? null : _memoController.text.trim()
        ..category = _category
        ..createdAt = widget.editingTemplate?.createdAt ?? DateTime.now()
        ..updatedAt = DateTime.now();

      if (widget.editingTemplate != null) {
        await ref.read(templateServiceProvider.notifier).updateTemplate(template);
      } else {
        await ref.read(templateServiceProvider.notifier).addTemplate(template);
      }

      Navigator.pop(context, true); // 成功を示すtrueを返す
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
    }
  }
}