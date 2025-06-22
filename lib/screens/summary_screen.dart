import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import '../constants/category_constants.dart';
import '../widgets/csv_export_dialog.dart';

class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now().add(const Duration(days: 30)); // 未来30日まで初期設定

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
    final transactionService = ref.watch(transactionServiceProvider.notifier);
    final periodSummary = transactionService.getPeriodSummary(_startDate, _endDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('サマリー'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '期間収支'),
            Tab(text: 'カテゴリ'),
            Tab(text: 'チャート'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _showCSVExportDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 期間選択部分
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectStartDate(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '開始日',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            DateFormat('yyyy/MM/dd').format(_startDate),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectEndDate(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '終了日',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            DateFormat('yyyy/MM/dd').format(_endDate),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // プリセット期間ボタン
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPresetButton('今月', _getThisMonth),
                      const SizedBox(width: 8),
                      _buildPresetButton('先月', _getLastMonth),
                      const SizedBox(width: 8),
                      _buildPresetButton('今年', _getThisYear),
                      const SizedBox(width: 8),
                      _buildPresetButton('過去30日', _getLast30Days),
                      const SizedBox(width: 8),
                      _buildPresetButton('未来30日', _getNext30Days), // 未来期間追加
                      const SizedBox(width: 8),
                      _buildPresetButton('今月+来月', _getThisAndNextMonth), // 今月+来月追加
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // メインコンテンツ
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPeriodSummaryTab(periodSummary),
                _buildCategoryTab(periodSummary),
                _buildChartTab(periodSummary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton(String label, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  // プリセット期間設定メソッド
  void _getThisMonth() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month + 1, 0);
    });
  }

  void _getLastMonth() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month - 1, 1);
      _endDate = DateTime(now.year, now.month, 0);
    });
  }

  void _getThisYear() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, 1, 1);
      _endDate = DateTime(now.year, 12, 31);
    });
  }

  void _getLast30Days() {
    final now = DateTime.now();
    setState(() {
      _startDate = now.subtract(const Duration(days: 30));
      _endDate = now;
    });
  }

  void _getNext30Days() {
    final now = DateTime.now();
    setState(() {
      _startDate = now;
      _endDate = now.add(const Duration(days: 30));
    });
  }

  void _getThisAndNextMonth() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month + 2, 0); // 来月末まで
    });
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000), // 2000年から
      lastDate: DateTime(2100),  // 2100年まで
      locale: const Locale('ja', 'JP'),
    );
    if (date != null && date.isBefore(_endDate.add(const Duration(days: 1)))) {
      setState(() => _startDate = date);
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100), // 2100年まで
      locale: const Locale('ja', 'JP'),
    );
    if (date != null) {
      setState(() => _endDate = date);
    }
  }

  Widget _buildPeriodSummaryTab(dynamic periodSummary) {
    final daysDiff = _endDate.difference(_startDate).inDays + 1;
    final isFuturePeriod = _endDate.isAfter(DateTime.now());
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 期間情報
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  '${DateFormat('yyyy年M月d日').format(_startDate)} 〜 ${DateFormat('yyyy年M月d日').format(_endDate)}',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('期間: ${daysDiff}日'),
                    if (isFuturePeriod)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '未来期間含む',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 収支サマリー
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  '期間収支',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text('収入', style: TextStyle(fontSize: 16)),
                          const SizedBox(height: 8),
                          Text(
                            '+${NumberFormat('#,###').format(periodSummary.totalIncome.round())}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: Theme.of(context).dividerColor,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text('支出', style: TextStyle(fontSize: 16)),
                          const SizedBox(height: 8),
                          Text(
                            '-${NumberFormat('#,###').format(periodSummary.totalExpense.round())}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: Theme.of(context).dividerColor,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text('残高', style: TextStyle(fontSize: 16)),
                          const SizedBox(height: 8),
                          Text(
                            '${periodSummary.balance >= 0 ? '+' : ''}${NumberFormat('#,###').format(periodSummary.balance.round())}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: periodSummary.balance >= 0 ? Colors.blue : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                if (isFuturePeriod) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '未来期間の予定データも含まれています',
                            style: TextStyle(fontSize: 12, color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 日次平均
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '日次平均',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('収入/日'),
                        Text(
                          '+${NumberFormat('#,###').format((periodSummary.totalIncome / daysDiff).round())}',
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('支出/日'),
                        Text(
                          '-${NumberFormat('#,###').format((periodSummary.totalExpense / daysDiff).round())}',
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('残高/日'),
                        Text(
                          '${(periodSummary.balance / daysDiff) >= 0 ? '+' : ''}${NumberFormat('#,###').format((periodSummary.balance / daysDiff).round())}',
                          style: TextStyle(
                            color: (periodSummary.balance / daysDiff) >= 0 ? Colors.blue : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTab(dynamic periodSummary) {
    final Map<String, double> categoryTotals = periodSummary.categoryTotals;
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'カテゴリ別集計',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ...sortedCategories.map((entry) {
          final category = entry.key;
          final amount = entry.value;
          final isIncome = CategoryConstants.incomeCategories.contains(category);
          
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
                child: Icon(
                  CategoryConstants.getCategoryIcon(category),
                  color: CategoryConstants.getCategoryColor(category, context),
                ),
              ),
              title: Text(category),
              trailing: Text(
                '${isIncome ? '+' : '-'}${NumberFormat('#,###').format(amount.round())}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isIncome ? Colors.green : Colors.red,
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  // 修正された _buildChartTab メソッド
  Widget _buildChartTab(dynamic periodSummary) {
    final Map<String, double> categoryTotals = periodSummary.categoryTotals;
    final expenseCategories = categoryTotals.entries
        .where((entry) => !CategoryConstants.incomeCategories.contains(entry.key))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (expenseCategories.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('支出データがありません'),
            SizedBox(height: 8),
            Text(
              '支出を入力すると、カテゴリ別の内訳が表示されます',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // 修正：SafeArea + SingleChildScrollView で囲む
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '支出カテゴリ内訳',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // チャート部分：固定高さに変更
            SizedBox(
              height: 300, // 固定高さでチャートを表示
              child: PieChart(
                PieChartData(
                  sections: expenseCategories.take(8).map((entry) {
                    final category = entry.key;
                    final amount = entry.value;
                    final percentage = (amount / periodSummary.totalExpense * 100);
                    
                    return PieChartSectionData(
                      color: CategoryConstants.getCategoryColor(category, context),
                      value: amount,
                      title: '${percentage.toStringAsFixed(1)}%',
                      radius: 100,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 凡例表示（スクロール可能エリア）
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📊 カテゴリ別内訳',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: expenseCategories.take(8).map((entry) {
                      final category = entry.key;
                      final amount = entry.value;
                      final percentage = (amount / periodSummary.totalExpense * 100);
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: CategoryConstants.getCategoryColor(category, context).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: CategoryConstants.getCategoryColor(category, context).withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: CategoryConstants.getCategoryColor(category, context),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              category,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: CategoryConstants.getCategoryColor(category, context),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            
            // 底部の安全余白
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showCSVExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CSVExportDialog(),
    );
  }
}