import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction.dart';
import '../models/holiday_handling.dart';
import '../services/transaction_service.dart';
import '../providers/sort_provider.dart';
import '../providers/filter_provider.dart';
import '../screens/settings_screen.dart';
import '../screens/summary_screen.dart';
import '../screens/add_transaction_screen.dart';
import '../widgets/amount_input_dialog.dart';
import '../widgets/template_selection_dialog.dart';
import '../widgets/filter_dialog.dart';
import '../constants/category_constants.dart';

// selectedMonthProvider は、通常は別のファイル (例: providers/selected_month_provider.dart)
// で定義することをお勧めしますが、今回はこのファイル内で定義します。
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  // 現在の月の1日を設定
  return DateTime(DateTime.now().year, DateTime.now().month, 1);
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {}); // タブ切り替え時に再描画
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 固定項目の表示月を文字列として取得するヘルパー関数
  String fixedMonthsDisplay(List<int> months) {
    if (months.isEmpty) return '毎月';
    if (months.length == 12) return '毎月';
    if (months.length <= 3) {
      return months.map((m) => '${m}月').join('、');
    }
    return '${months.length}ヶ月指定';
  }

  // 月を変更するメソッド
  void _changeMonth(int delta, WidgetRef ref) {
    final currentMonth = ref.read(selectedMonthProvider);
    final newMonth = DateTime(
      currentMonth.year,
      currentMonth.month + delta,
    );
    ref.read(selectedMonthProvider.notifier).state = newMonth;
  }

  // 月選択ダイアログを表示するメソッド
  Future<void> _showMonthYearPicker(BuildContext context, WidgetRef ref) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: ref.read(selectedMonthProvider),
      firstDate: DateTime(2000), // 2000年から
      lastDate: DateTime(2100),  // 2100年まで
      initialDatePickerMode: DatePickerMode.year,
      locale: const Locale('ja', 'JP'),
    );

    if (picked != null) {
      ref.read(selectedMonthProvider.notifier).state = DateTime(picked.year, picked.month, 1);
    }
  }

  // 確認ダイアログを表示するヘルパーメソッド
  Future<bool?> _showConfirmDialog(BuildContext context, String title, String content) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: <Widget>[
          TextButton(
            child: const Text('キャンセル'),
            onPressed: () {
              Navigator.of(ctx).pop(false);
            },
          ),
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(ctx).pop(true);
            },
          ),
        ],
      ),
    );
  }

  // // UIを強制更新するヘルパーメソッド
  // void _forceUpdate() {
  //   final currentMonth = ref.read(selectedMonthProvider);
  //   // 強制的にProviderを無効化して再構築
  //   ref.invalidate(transactionServiceProvider);
  //   // 現在の状態を一度リセットしてから再設定することで、確実に更新
  //   ref.read(selectedMonthProvider.notifier).state = DateTime(currentMonth.year, currentMonth.month, 1);
  // }
  // 修正後（安全軽量版）
  void _forceUpdate() {
    // 軽量だが確実な更新
    if (mounted) {
      setState(() {}); // 現在のWidgetのみ再描画
    }
  }

  // テンプレート選択ダイアログを表示
  void _showTemplateSelection(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => const TemplateSelectionDialog(),
    );
    _forceUpdate();
  }

  // 当月のCSVエクスポート
  Future<void> _exportMonthCSV(BuildContext context, WidgetRef ref) async {
    try {
      final selectedMonth = ref.read(selectedMonthProvider);
      final transactionService = ref.read(transactionServiceProvider.notifier);
      final filePath = await transactionService.exportMonthToCSV(selectedMonth);
      
      // 共有ダイアログを表示
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: '家計簿データ（${DateFormat('yyyy年M月').format(selectedMonth)}）',
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSVファイルを作成しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 並び替えチップを構築
  Widget _buildSortChip(BuildContext context, WidgetRef ref, int tabIndex) {
    final isTransactionTab = tabIndex == 0;
    final currentSort = isTransactionTab 
        ? ref.watch(transactionSortProvider)
        : ref.watch(scheduledSortProvider);
    
    return ActionChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currentSort.shortName,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 16),
        ],
      ),
      onPressed: () => _showSortDialog(context, ref, isTransactionTab),
      visualDensity: VisualDensity.compact,
    );
  }

  // フィルターダイアログを表示
  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => FilterDialog(
        isTransactionTab: _tabController.index == 0,
      ),
    );
  }

  // 並び替えダイアログを表示
  void _showSortDialog(BuildContext context, WidgetRef ref, bool isTransactionTab) {
    final currentSort = isTransactionTab 
        ? ref.read(transactionSortProvider)
        : ref.read(scheduledSortProvider);
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('並び替え'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SortType.values.map((sortType) {
            return RadioListTile<SortType>(
              title: Text(sortType.displayName),
              value: sortType,
              groupValue: currentSort,
              onChanged: (value) {
                if (value != null) {
                  if (isTransactionTab) {
                    ref.read(transactionSortProvider.notifier).state = value;
                  } else {
                    ref.read(scheduledSortProvider.notifier).state = value;
                  }
                  Navigator.pop(dialogContext);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // トランザクションリストを並び替え
  List<Transaction> _sortTransactions(List<Transaction> transactions, SortType sortType) {
    final sorted = List<Transaction>.from(transactions);
    
    switch (sortType) {
      case SortType.dateDesc:
        sorted.sort((a, b) => b.date.compareTo(a.date));
        break;
      case SortType.dateAsc:
        sorted.sort((a, b) => a.date.compareTo(b.date));
        break;
      case SortType.amountDesc:
        sorted.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case SortType.amountAsc:
        sorted.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      case SortType.titleAsc:
        sorted.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SortType.titleDesc:
        sorted.sort((a, b) => b.title.compareTo(a.title));
        break;
    }
    
    return sorted;
  }

  // フィルターを適用
  List<Transaction> _applyFilter(List<Transaction> transactions, FilterCriteria criteria) {
    if (!criteria.hasActiveFilters) {
      return transactions;
    }
    
    return transactions.where((transaction) => criteria.matches(transaction)).toList();
  }

  // 予定を実績として確定するメソッド（修正版）
  void _confirmScheduledItem(Transaction scheduledItem, TransactionService transactionService) async {
    double finalAmount = scheduledItem.amount;
    
    // showAmountInSchedule が false の場合（毎回入力設定）は金額入力ダイアログを表示
    if (!scheduledItem.showAmountInSchedule) {
      final double? inputAmount = await showAmountInputDialog(
        context,
        initialAmount: scheduledItem.amount,
      );
      
      if (inputAmount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('実績化をキャンセルしました')),
        );
        return;
      }
      finalAmount = inputAmount;
    }
    
    print('=== 実績確定デバッグ ===');
    print('元の予定日付: ${scheduledItem.date}');
    print('確定する金額: $finalAmount');
    
    // 元の固定項目のIDを取得
    String originalFixedItemId;
    if (scheduledItem.id.contains('_scheduled_')) {
      originalFixedItemId = scheduledItem.id.split('_scheduled_')[0];
    } else if (scheduledItem.id.contains('_preview_')) {
      originalFixedItemId = scheduledItem.id.split('_preview_')[0];
    } else {
      originalFixedItemId = scheduledItem.id;
    }
    
    // 完全に独立した実績Transactionを作成
    final actualTransaction = Transaction()
      ..id = '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}_actual_from_$originalFixedItemId'
      ..title = scheduledItem.title
      ..amount = finalAmount
      ..date = scheduledItem.date // 予定の日付をそのまま使用
      ..type = scheduledItem.type
      ..isFixedItem = false // 重要: 実績なので絶対にfalse
      ..fixedMonths = [] // 実績には不要
      ..fixedDay = 1 // 実績には不要
      ..holidayHandling = HolidayHandling.none // 実績には不要
      ..showAmountInSchedule = false // 実績には不要
      ..memo = '${scheduledItem.memo ?? ''} (予定から確定)'
      ..category = scheduledItem.category // カテゴリを引き継ぐ
      ..createdAt = DateTime.now() // 作成日時は現在
      ..updatedAt = DateTime.now();
    
    print('作成する実績: ID=${actualTransaction.id}, 日付=${actualTransaction.date}, 金額=${actualTransaction.amount}');
    
    // 新しいaddActualTransactionメソッドを使用
    await transactionService.addActualTransaction(actualTransaction);
    
    // UI更新
    _forceUpdate();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('予定を実績に移動しました')),
    );
  }

  // 予定削除メソッド（完全削除版）
  void _deleteScheduledItem(Transaction scheduledItem, TransactionService transactionService) async {
    print('=== 予定削除デバッグ ===');
    print('削除対象のID: ${scheduledItem.id}');
    
    // スケジュール項目のIDから元の固定項目のIDを取得
    String originalId;
    if (scheduledItem.id.contains('_scheduled_')) {
      originalId = scheduledItem.id.split('_scheduled_')[0];
    } else if (scheduledItem.id.contains('_preview_')) {
      originalId = scheduledItem.id.split('_preview_')[0];
    } else {
      originalId = scheduledItem.id;
    }
    
    print('削除する固定項目のID: $originalId');
    
    // 新しいdeleteFixedItemCompletelyメソッドを使用
    await transactionService.deleteFixedItemCompletely(originalId);
    
    // UI更新
    _forceUpdate();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('予定と固定項目を完全に削除しました'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // 実績リストを構築するウィジェット
  Widget _buildTransactionsList(
      List<Transaction> transactions,
      TransactionService transactionService,
      BuildContext context) {
    if (transactions.isEmpty) {
      final hasFilters = ref.watch(transactionFilterProvider).hasActiveFilters;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters ? Icons.search_off : Icons.receipt_long,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? '検索条件に一致する項目がありません' : 'この月には実績がありません',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  ref.read(transactionFilterProvider.notifier).clearFilters();
                },
                child: const Text('フィルターをクリア'),
              ),
            ],
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: transactions.length,
      itemBuilder: (ctx, index) {
        final transaction = transactions[index];
        return Dismissible(
          key: ValueKey(transaction.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            return await _showConfirmDialog(
                context, '取引の削除', 'この取引を削除しますか？');
          },
          onDismissed: (direction) async {
            if (direction == DismissDirection.endToStart) {
              await transactionService.deleteTransaction(transaction.id);
              _forceUpdate();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('取引を削除しました')),
              );
            }
          },
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            elevation: 1,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: transaction.type == TransactionType.income
                    ? Colors.green.shade100
                    : Colors.red.shade100,
                child: Icon(
                  transaction.category != null 
                      ? CategoryConstants.getCategoryIcon(transaction.category!)
                      : (transaction.type == TransactionType.income
                          ? Icons.add_circle
                          : Icons.remove_circle),
                  color: transaction.category != null
                      ? CategoryConstants.getCategoryColor(transaction.category!, context)
                      : (transaction.type == TransactionType.income
                          ? Colors.green.shade700
                          : Colors.red.shade700),
                ),
              ),
              title: Text(transaction.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        DateFormat('MM/dd (E)', 'ja').format(transaction.date),
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (transaction.category != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: CategoryConstants.getCategoryColor(transaction.category!, context).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            transaction.category!,
                            style: TextStyle(
                              fontSize: 10,
                              color: CategoryConstants.getCategoryColor(transaction.category!, context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (transaction.memo?.isNotEmpty == true) 
                    Text(
                      transaction.memo!,
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${transaction.type == TransactionType.income ? '+' : '-'}${NumberFormat('#,###').format(transaction.amount.round())}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: transaction.type == TransactionType.income
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ],
              ),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddTransactionScreen(editingTransaction: transaction),
                  ),
                );
                _forceUpdate();
              },
            ),
          ),
        );
      },
    );
  }

  // 予定リストを構築するウィジェット
  Widget _buildScheduledList(
      List<Transaction> scheduledItems,
      TransactionService transactionService,
      BuildContext context) {
    if (scheduledItems.isEmpty) {
      final hasFilters = ref.watch(scheduledFilterProvider).hasActiveFilters;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters ? Icons.search_off : Icons.event_available,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? '検索条件に一致する項目がありません' : 'この月には予定がありません',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  ref.read(scheduledFilterProvider.notifier).clearFilters();
                },
                child: const Text('フィルターをクリア'),
              ),
            ],
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: scheduledItems.length,
      itemBuilder: (ctx, index) {
        final scheduledItem = scheduledItems[index];
        return _buildScheduledItem(scheduledItem, transactionService, context);
      },
    );
  }

  // 個々の予定アイテムを構築するウィジェット
  Widget _buildScheduledItem(
      Transaction scheduledItem,
      TransactionService transactionService,
      BuildContext context) {
    return Dismissible(
      key: Key(scheduledItem.id),
      direction: DismissDirection.horizontal,
      background: Container(
        color: Colors.green,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.check, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // 左スワイプ：確定
          return await _showConfirmDialog(context, '予定を確定', 'この予定を実績に移動しますか？');
        } else {
          // 右スワイプ：削除
          return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('予定を完全削除'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('「${scheduledItem.title}」を削除しますか？'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚠️ 完全削除の影響',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                        SizedBox(height: 4),
                        Text('• この固定項目が完全に削除されます'),
                        Text('• 現在月および将来のすべての月の予定が削除されます'),
                        Text('• 既存の実績は削除されません'),
                        Text('• この操作は取り消せません'),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('キャンセル'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('完全削除'),
                ),
              ],
            ),
          );
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          _confirmScheduledItem(scheduledItem, transactionService);
        } else {
          _deleteScheduledItem(scheduledItem, transactionService);
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        elevation: 1,
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3)
            : Colors.orange.shade50,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.orange.shade800
                : Colors.orange.shade100,
            child: Icon(
              scheduledItem.category != null 
                  ? CategoryConstants.getCategoryIcon(scheduledItem.category!)
                  : Icons.schedule,
              color: scheduledItem.category != null
                  ? CategoryConstants.getCategoryColor(scheduledItem.category!, context)
                  : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.orange.shade300
                      : Colors.orange.shade700),
            ),
          ),
          title: Text(
            scheduledItem.title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    DateFormat('MM/dd (E)', 'ja').format(scheduledItem.date),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                  if (scheduledItem.category != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: CategoryConstants.getCategoryColor(scheduledItem.category!, context).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        scheduledItem.category!,
                        style: TextStyle(
                          fontSize: 10,
                          color: CategoryConstants.getCategoryColor(scheduledItem.category!, context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (scheduledItem.memo?.isNotEmpty == true)
                Text(
                  scheduledItem.memo!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              Row(
                children: [
                  Icon(
                    Icons.repeat,
                    size: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.orange.shade300
                        : Colors.orange.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '固定項目',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.orange.shade300
                          : Colors.orange.shade600,
                    ),
                  ),
                  // 休日処理設定があれば表示
                  if (scheduledItem.holidayHandling != HolidayHandling.none) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.event_busy,
                      size: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.blue.shade300
                          : Colors.blue.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      scheduledItem.holidayHandling.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.blue.shade300
                            : Colors.blue.shade600,
                      ),
                    ),
                  ],
                  // 金額設定の表示
                  const SizedBox(width: 8),
                  Icon(
                    scheduledItem.showAmountInSchedule ? Icons.attach_money : Icons.edit,
                    size: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.purple.shade300
                        : Colors.purple.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    scheduledItem.showAmountInSchedule ? '金額固定' : '金額入力',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.purple.shade300
                          : Colors.purple.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // showAmountInSchedule が true の場合のみ金額を表示
          trailing: scheduledItem.showAmountInSchedule ? Text(
            '${scheduledItem.type == TransactionType.income ? '+' : '-'}${NumberFormat('#,###').format(scheduledItem.amount.round())}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: scheduledItem.type == TransactionType.income
                  ? (Theme.of(context).brightness == Brightness.dark
                      ? Colors.green.shade300
                      : Colors.green.shade700)
                  : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.red.shade300
                      : Colors.red.shade700),
            ),
          ) : Text(
            scheduledItem.type == TransactionType.income ? '収入' : '支出',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          onTap: () async {
            // 元の固定項目を編集するために、IDを取得
            String originalId;
            if (scheduledItem.id.contains('_scheduled_')) {
              originalId = scheduledItem.id.split('_scheduled_')[0];
            } else if (scheduledItem.id.contains('_preview_')) {
              originalId = scheduledItem.id.split('_preview_')[0];
            } else {
              originalId = scheduledItem.id;
            }
            
            // 元の固定項目を取得
            final transactions = ref.read(transactionServiceProvider);
            final originalTransaction = transactions.firstWhere(
              (t) => t.id == originalId,
              orElse: () => scheduledItem,
            );
            
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddTransactionScreen(editingTransaction: originalTransaction),
              ),
            );
            _forceUpdate();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final transactionService = ref.watch(transactionServiceProvider.notifier);

    final summary = transactionService.getMonthlySummary(selectedMonth);
    final scheduledItems = transactionService.getScheduledItemsForMonth(selectedMonth);

    // 見込み値（実績＋予定）の計算
    double scheduledIncome = 0;
    double scheduledExpense = 0;
    
    for (final item in scheduledItems) {
      if (item.showAmountInSchedule) {
        // 金額が固定の場合のみ集計（金額入力設定の場合は未確定なので含めない）
        if (item.type == TransactionType.income) {
          scheduledIncome += item.amount;
        } else {
          scheduledExpense += item.amount;
        }
      }
    }
    
    final estimatedIncome = summary.totalIncome + scheduledIncome;
    final estimatedExpense = summary.totalExpense + scheduledExpense;
    final estimatedBalance = estimatedIncome - estimatedExpense;

    return Scaffold(
      appBar: AppBar(
        title: const Text('家計簿〜暮らしっく'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
                case 'csv_export':
                  await _exportMonthCSV(context, ref);
                  break;
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'csv_export',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('当月CSVエクスポート'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('設定'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 年月選択コンポーネント
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1, ref),
                  color: Theme.of(context).colorScheme.primary,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showMonthYearPicker(context, ref),
                    onHorizontalDragEnd: (details) {
                      if (details.primaryVelocity! > 0) {
                        _changeMonth(-1, ref);
                      } else if (details.primaryVelocity! < 0) {
                        _changeMonth(1, ref);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        DateFormat('yyyy年MM月').format(selectedMonth),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1, ref),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),

          // 収支サマリー表示部分
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.secondaryContainer,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // 実績行
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '収入',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '+${NumberFormat('#,###').format(summary.totalIncome.round())}',
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.green.shade300
                                  : Colors.green.shade700,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.3),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '支出',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '-${NumberFormat('#,###').format(summary.totalExpense.round())}',
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.red.shade300
                                  : Colors.red.shade700,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.3),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '残高',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${summary.balance >= 0 ? '+' : ''}${NumberFormat('#,###').format(summary.balance.round())}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: summary.balance >= 0
                                  ? (Theme.of(context).brightness == Brightness.dark
                                      ? Colors.blue.shade300
                                      : Colors.blue.shade700)
                                  : (Theme.of(context).brightness == Brightness.dark
                                      ? Colors.orange.shade300
                                      : Colors.orange.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // 区切り線
                Container(
                  height: 1,
                  color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.2),
                ),
                
                const SizedBox(height: 12),
                
                // 見込み行（実績＋予定）
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '見込み収入',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '+${NumberFormat('#,###').format(estimatedIncome.round())}',
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.green.shade400.withOpacity(0.8)
                                  : Colors.green.shade600.withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.2),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '見込み支出',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '-${NumberFormat('#,###').format(estimatedExpense.round())}',
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.red.shade400.withOpacity(0.8)
                                  : Colors.red.shade600.withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.2),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '見込み残高',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${estimatedBalance >= 0 ? '+' : ''}${NumberFormat('#,###').format(estimatedBalance.round())}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: estimatedBalance >= 0
                                  ? (Theme.of(context).brightness == Brightness.dark
                                      ? Colors.blue.shade400.withOpacity(0.8)
                                      : Colors.blue.shade600.withOpacity(0.8))
                                  : (Theme.of(context).brightness == Brightness.dark
                                      ? Colors.orange.shade400.withOpacity(0.8)
                                      : Colors.orange.shade600.withOpacity(0.8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // メインコンテンツ（実績と予定のタブ表示）
          Expanded(
            child: Column(
              children: [
                Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        labelColor: Theme.of(context).colorScheme.primary,
                        unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        indicatorColor: Theme.of(context).colorScheme.primary,
                        tabs: const [
                          Tab(text: '実績'),
                          Tab(text: '予定'),
                        ],
                      ),
                      // 検索バーとフィルターボタン
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: ValueKey('search_${_tabController.index}'),
                                controller: TextEditingController(
                                  text: _tabController.index == 0
                                      ? ref.watch(transactionFilterProvider).searchQuery
                                      : ref.watch(scheduledFilterProvider).searchQuery,
                                ),
                                decoration: InputDecoration(
                                  hintText: '検索...',
                                  prefixIcon: const Icon(Icons.search, size: 20),
                                  suffixIcon: _tabController.index == 0
                                      ? ref.watch(transactionFilterProvider).searchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear, size: 20),
                                              onPressed: () {
                                                ref.read(transactionFilterProvider.notifier).updateSearchQuery('');
                                              },
                                            )
                                          : null
                                      : ref.watch(scheduledFilterProvider).searchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear, size: 20),
                                              onPressed: () {
                                                ref.read(scheduledFilterProvider.notifier).updateSearchQuery('');
                                              },
                                            )
                                          : null,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                ),
                                style: const TextStyle(fontSize: 14),
                                onChanged: (value) {
                                  if (_tabController.index == 0) {
                                    ref.read(transactionFilterProvider.notifier).updateSearchQuery(value);
                                  } else {
                                    ref.read(scheduledFilterProvider.notifier).updateSearchQuery(value);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            // フィルターボタン
                            Badge(
                              label: Text(
                                _tabController.index == 0
                                    ? '${ref.watch(transactionFilterProvider).activeFilterCount}'
                                    : '${ref.watch(scheduledFilterProvider).activeFilterCount}',
                              ),
                              isLabelVisible: _tabController.index == 0
                                  ? ref.watch(transactionFilterProvider).activeFilterCount > 0
                                  : ref.watch(scheduledFilterProvider).activeFilterCount > 0,
                              child: IconButton(
                                icon: const Icon(Icons.filter_list),
                                onPressed: () => _showFilterDialog(context),
                                style: IconButton.styleFrom(
                                  backgroundColor: (_tabController.index == 0
                                          ? ref.watch(transactionFilterProvider).hasActiveFilters
                                          : ref.watch(scheduledFilterProvider).hasActiveFilters)
                                      ? Theme.of(context).colorScheme.primaryContainer
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 並び替えボタン
                      Container(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.sort, 
                              size: 14,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '並び替え:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildSortChip(context, ref, _tabController.index),
                            const Spacer(),
                            // 検索結果件数表示
                            if (_tabController.index == 0 && ref.watch(transactionFilterProvider).hasActiveFilters)
                              Text(
                                '${_applyFilter(summary.transactions, ref.watch(transactionFilterProvider)).length}件',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              )
                            else if (_tabController.index == 1 && ref.watch(scheduledFilterProvider).hasActiveFilters)
                              Text(
                                '${_applyFilter(scheduledItems, ref.watch(scheduledFilterProvider)).length}件',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTransactionsList(
                        _sortTransactions(
                          _applyFilter(summary.transactions, ref.watch(transactionFilterProvider)), 
                          ref.watch(transactionSortProvider)
                        ), 
                        transactionService, 
                        context
                      ),
                      _buildScheduledList(
                        _sortTransactions(
                          _applyFilter(scheduledItems, ref.watch(scheduledFilterProvider)), 
                          ref.watch(scheduledSortProvider)
                        ), 
                        transactionService, 
                        context
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            child: FloatingActionButton.small(
              heroTag: "template",
              onPressed: () => _showTemplateSelection(context),
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              child: Icon(
                Icons.list_alt,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          GestureDetector(
            onLongPress: () => _showTemplateSelection(context),
            child: FloatingActionButton(
              heroTag: "add",
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddTransactionScreen(),
                  ),
                );
                _forceUpdate();
              },
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ホーム'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'サマリー'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '設定'),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SummaryScreen()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          }
        },
      ),
    );
  }
}