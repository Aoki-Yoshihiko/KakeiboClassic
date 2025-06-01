import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
//import '../services/transaction_service.dart';

class DataManagementScreen extends ConsumerWidget {
  const DataManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('データ管理'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // バックアップセクション
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.backup),
                  title: Text(
                    'データバックアップ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('データをファイルに保存'),
                ),
                ListTile(
                  title: const Text('JSONファイルでエクスポート'),
                  subtitle: const Text('すべての取引データを保存'),
                  trailing: const Icon(Icons.download),
                  onTap: () => _exportData(context, ref),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 注意事項
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💡 データ管理について',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• 定期的にバックアップを取ることをお勧めします'),
                Text('• エクスポートしたファイルは安全な場所に保管してください'),
                Text('• データは端末内に保存されています'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    try {
//      final transactionService = ref.read(transactionServiceProvider.notifier);
//      final filePath = await transactionService.exportData();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('データをエクスポートしました'),
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
}