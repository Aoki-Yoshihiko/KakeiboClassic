import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/holiday_handling.dart';
import '../services/transaction_service.dart';
import '../screens/settings_screen.dart';
import '../screens/summary_screen.dart';
import '../screens/add_transaction_screen.dart';
import '../widgets/amount_input_dialog.dart';

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
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
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

  // UIを強制更新するヘルパーメソッド
  void _forceUpdate() {
    final currentMonth = ref.read(selectedMonthProvider);
    // 強制的にProviderを無効化して再構築
    ref.invalidate(transactionServiceProvider);
    // 現在の状態を一度リセットしてから再設定することで、確実に更新
    ref.read(selectedMonthProvider.notifier).state = DateTime(currentMonth.year, currentMonth.month, 1);
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
    
    // 完全に独立した実績Transactionを作成
    final actualTransaction = Transaction()
      ..id = '${DateTime.now().millisecondsSinceEpoch}_actual_${scheduledItem.title.replaceAll(' ', '_')}'
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
      return const Center(child: Text('この月には実績がありません。'));
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
                  transaction.type == TransactionType.income
                      ? Icons.add_circle
                      : Icons.remove_circle,
                  color: transaction.type == TransactionType.income
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
              ),
              title: Text(transaction.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('MM/dd (E)', 'ja').format(transaction.date)),
                  if (transaction.memo?.isNotEmpty == true) Text(transaction.memo!),
                ],
              ),
              trailing: Text(
                '${transaction.type == TransactionType.income ? '+' : '-'}${NumberFormat('#,###').format(transaction.amount.round())}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: transaction.type == TransactionType.income
                      ? Colors.green
                      : Colors.red,
                ),
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
      return const Center(child: Text('この月には予定がありません。'));
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
              Icons.schedule,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.orange.shade300
                  : Colors.orange.shade700,
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
              Text(
                DateFormat('MM/dd (E)', 'ja').format(scheduledItem.date),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 12,
                ),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('家計簿〜暮らしっく'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
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
              ],
            ),
          ),

          const SizedBox(height: 16),

          // メインコンテンツ（実績と予定のタブ表示）
          Expanded(
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
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTransactionsList(summary.transactions, transactionService, context),
                      _buildScheduledList(scheduledItems, transactionService, context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
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