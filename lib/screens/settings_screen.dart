import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart'; // TransactionType用
import '../services/transaction_service.dart';
import 'data_management_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionServiceProvider);
    
    // 統計情報
    final totalTransactions = transactions.length;
    final totalIncome = transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
    final totalExpense = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
    final fixedItemsCount = transactions.where((t) => t.isFixedItem).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          // アプリ情報セクション
          _buildSection(
            title: 'アプリ情報',
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('家計簿〜暮らしっく'),
                subtitle: const Text('バージョン 1.0.0'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAboutDialog(context),
              ),
            ],
          ),

          // データ管理セクション
          _buildSection(
            title: 'データ管理',
            children: [
              ListTile(
                leading: const Icon(Icons.backup),
                title: const Text('データ管理'),
                subtitle: const Text('バックアップ・復元'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DataManagementScreen(),
                  ),
                ),
              ),
            ],
          ),

          // 統計情報セクション
          _buildSection(
            title: '統計情報',
            children: [
              ListTile(
                leading: const Icon(Icons.analytics_outlined),
                title: const Text('取引件数'),
                subtitle: Text('$totalTransactions件'),
              ),
              ListTile(
                leading: const Icon(Icons.trending_up, color: Colors.green),
                title: const Text('総収入'),
                subtitle: Text('${NumberFormat('#,###').format(totalIncome.round())}円'),
              ),
              ListTile(
                leading: const Icon(Icons.trending_down, color: Colors.red),
                title: const Text('総支出'),
                subtitle: Text('${NumberFormat('#,###').format(totalExpense.round())}円'),
              ),
              ListTile(
                leading: Icon(
                  (totalIncome - totalExpense) >= 0 
                      ? Icons.savings 
                      : Icons.warning,
                  color: (totalIncome - totalExpense) >= 0 
                      ? Colors.green 
                      : Colors.red,
                ),
                title: const Text('総収支'),
                subtitle: Text(
                  '${(totalIncome - totalExpense) >= 0 ? '+' : ''}${NumberFormat('#,###').format((totalIncome - totalExpense).round())}円',
                  style: TextStyle(
                    color: (totalIncome - totalExpense) >= 0 
                        ? Colors.green 
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.repeat),
                title: const Text('固定項目数'),
                subtitle: Text('$fixedItemsCount件'),
              ),
            ],
          ),

          // 機能紹介セクション
          _buildSection(
            title: '機能紹介',
            children: [
              ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: const Text('使い方のヒント'),
                subtitle: const Text('効率的な使い方を確認'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showTipsDialog(context),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: children),
        ),
      ],
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: '家計簿〜暮らしっく',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.account_balance_wallet, size: 48),
      children: [
        const Text('シンプルで使いやすい家計簿アプリです。'),
        const SizedBox(height: 16),
        const Text('主な機能:'),
        const Text('• 収入・支出の記録'),
        const Text('• 固定項目の設定'),
        const Text('• 月別・期間別集計'),
        const Text('• データのバックアップ'),
      ],
    );
  }

  void _showTipsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('💡 使い方のヒント'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('📅 固定項目の活用', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('給料や家賃など毎月発生する項目は「固定として設定」をオンにしましょう。'),
              SizedBox(height: 12),
              
              Text('📆 発生日の設定', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('固定項目では発生日を1〜31日で設定できます。月末日を超える場合は自動調整されます。'),
              SizedBox(height: 12),
              
              Text('🏖️ 休日処理', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('固定項目で休日の場合の処理（前営業日・後営業日）を設定できます。'),
              SizedBox(height: 12),
              
              Text('💰 金額表示の切り替え', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('予定タブでの金額表示はON/OFFで切り替えられます。'),
              SizedBox(height: 12),
              
              Text('✅ 予定の確定', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('予定項目を左にスワイプすると実績に確定できます。'),
              SizedBox(height: 12),
              
              Text('📊 期間集計', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('サマリー画面では期間と項目を指定して詳細な分析ができます。'),
              SizedBox(height: 12),
              
              Text('💾 バックアップ', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('定期的にデータをエクスポートして大切なデータを保護しましょう。'),
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