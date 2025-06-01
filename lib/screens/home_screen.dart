import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/holiday_handling.dart';
import '../services/transaction_service.dart';
import '../screens/settings_screen.dart';
import '../screens/summary_screen.dart';
import '../screens/add_transaction_screen.dart';

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
  // PageController は現在のコードでは使用されていないため、削除しました。
  // late PageController _pageController;
  // int _currentPageIndex = 12;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // _pageController = PageController(initialPage: _currentPageIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    // _pageController.dispose();
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
    // Provider の状態を更新することで、UIが自動的に再構築されます
    ref.read(selectedMonthProvider.notifier).state = newMonth;
  }

  // 月選択ダイアログを表示するメソッド
  Future<void> _showMonthYearPicker(BuildContext context, WidgetRef ref) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: ref.read(selectedMonthProvider), // 現在の月を初期値に設定
      firstDate: DateTime(2000), // 選択可能な開始年
      lastDate: DateTime(2100), // 選択可能な終了年
      initialDatePickerMode: DatePickerMode.year, // 年から選択を開始
      locale: const Locale('ja', 'JP'), // 日本語ロケールを設定
    );

    if (picked != null) {
      // 選択された月の1日を設定して Provider の状態を更新
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

  // 予定を実績として確定するメソッド
  void _confirmScheduledItem(Transaction scheduledItem, TransactionService transactionService) async {
    final confirmedTransaction = scheduledItem.copyWith(
      id: '${DateTime.now().millisecondsSinceEpoch}_from_scheduled', // 新しいIDを生成
      isFixedItem: false, // 実績にするため false に設定
      fixedMonths: [], // 実績なので固定月情報は不要
      fixedDay: 1, // 実績なので固定日情報はリセット
      holidayHandling: HolidayHandling.none, // 実績なので休日処理もリセット
      showAmountInSchedule: false, // 実績なので予定での金額表示は無関係
      memo: '${scheduledItem.memo ?? ''} (予定から確定)', // メモに追記
      createdAt: DateTime.now(), // 確定日時を記録
    );
    await transactionService.addTransaction(confirmedTransaction);
    // 確定後、選択中の月を再設定することで UI を最新の状態に更新
    ref.read(selectedMonthProvider.notifier).state = DateTime(ref.read(selectedMonthProvider).year, ref.read(selectedMonthProvider).month, 1);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('予定を実績に移動しました')),
    );
  }

  // 予定リストからアイテムを削除するメソッド (固定項目テンプレート自体は削除しない)
  void _deleteScheduledItem(Transaction scheduledItem) {
    // 予定リストからアイテムを削除するだけで、永続的なデータは変更しません。
    // そのため、selectedMonthProvider を更新して UI を再描画するだけで十分です。
    ref.read(selectedMonthProvider.notifier).state = DateTime(ref.read(selectedMonthProvider).year, ref.read(selectedMonthProvider).month, 1);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('予定を削除しました')),
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
          key: ValueKey(transaction.id), // Dismissible に一意なキーを設定
          direction: DismissDirection.endToStart, // 右から左へのスワイプを許可
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
              // 削除後、選択中の月を再設定することで UI を最新の状態に更新
              ref.read(selectedMonthProvider.notifier).state = DateTime(ref.read(selectedMonthProvider).year, ref.read(selectedMonthProvider).month, 1);
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
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AddTransactionScreen(),
                  ),
                );
                // 編集後、選択中の月を再設定することで UI を最新の状態に更新
                ref.read(selectedMonthProvider.notifier).state = DateTime(ref.read(selectedMonthProvider).year, ref.read(selectedMonthProvider).month, 1);
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
      key: Key(scheduledItem.id), // Dismissible に一意なキーを設定
      direction: DismissDirection.horizontal, // 左右どちらへのスワイプも許可
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
          return await _showConfirmDialog(context, '予定を削除', 'この予定を削除しますか？');
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          _confirmScheduledItem(scheduledItem, transactionService);
        } else {
          _deleteScheduledItem(scheduledItem);
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        elevation: 1,
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3)
            : Colors.orange.shade50, // 予定の色
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.orange.shade800
                : Colors.orange.shade100,
            child: Icon(
              Icons.schedule, // 予定を表すアイコン
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
              if (scheduledItem.memo?.isNotEmpty == true) // メモがあれば表示
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
                    Icons.repeat, // 固定項目を表すアイコン
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
                      Icons.event_busy, // 休日処理を表すアイコン
                      size: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.blue.shade300
                          : Colors.blue.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      scheduledItem.holidayHandling.displayName, // 休日処理の表示名
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.blue.shade300
                            : Colors.blue.shade600,
                      ),
                    ),
                  ],
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
          ) : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // selectedMonthProvider を watch して、月の変更を検知
    final selectedMonth = ref.watch(selectedMonthProvider);
    // transactionServiceProvider の変更を watch して、データ更新を検知
    final transactionService = ref.watch(transactionServiceProvider.notifier);

    // 月次サマリーは実績のみを含むように TransactionService 側でフィルタリングされます
    final summary = transactionService.getMonthlySummary(selectedMonth);
    
    // スケジュールアイテムは予定のみを含むように TransactionService 側で取得されます
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
                  onPressed: () => _changeMonth(-1, ref), // ref を渡す
                  color: Theme.of(context).colorScheme.primary,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showMonthYearPicker(context, ref), // ref を渡す
                    onHorizontalDragEnd: (details) {
                      if (details.primaryVelocity! > 0) {
                        _changeMonth(-1, ref); // 右スワイプで前月
                      } else if (details.primaryVelocity! < 0) {
                        _changeMonth(1, ref); // 左スワイプで翌月
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
                  onPressed: () => _changeMonth(1, ref), // ref を渡す
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
                      // 実績タブの内容
                      _buildTransactionsList(summary.transactions, transactionService, context),
                      // 予定タブの内容
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
          // AddTransactionScreen から戻ってくるのを待機
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTransactionScreen(),
            ),
          );
          // 画面が戻ってきたら、選択中の月を再設定して UI を強制的に更新
          // これにより、追加・編集されたデータがリストに反映されます。
          ref.read(selectedMonthProvider.notifier).state = DateTime(selectedMonth.year, selectedMonth.month, 1);
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0, // 現在の画面がホームなので0
        type: BottomNavigationBarType.fixed, // アイテム数が多い場合でもラベルが表示されるように
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ホーム'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'サマリー'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '設定'),
        ],
        onTap: (index) {
          if (index == 1) { // サマリータブをタップした場合
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SummaryScreen()),
            );
          } else if (index == 2) { // 設定タブをタップした場合
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          }
          // ホームタブ (index == 0) は現在の画面なので何もしません
        },
      ),
    );
  }
}