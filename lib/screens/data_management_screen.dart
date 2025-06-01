import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/transaction_service.dart';

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

          const SizedBox(height: 16),

          // 復元セクション
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.restore),
                  title: Text(
                    'データ復元',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('バックアップファイルから復元'),
                ),
                ListTile(
                  title: const Text('JSONファイルからインポート'),
                  subtitle: const Text('既存データは削除されます'),
                  trailing: const Icon(Icons.upload),
                  onTap: () => _importData(context, ref),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 危険な操作
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.warning, color: Colors.red),
                  title: Text(
                    '危険な操作',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ),
                ListTile(
                  title: const Text(
                    'すべてのデータを削除',
                    style: TextStyle(color: Colors.red),
                  ),
                  subtitle: const Text('この操作は取り消せません'),
                  trailing: const Icon(Icons.delete_forever, color: Colors.red),
                  onTap: () => _deleteAllData(context, ref),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 注意事項
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚠️ 注意事項',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• データの復元時は既存のデータがすべて削除されます'),
                Text('• 定期的にバックアップを取ることをお勧めします'),
                Text('• バックアップファイルは安全な場所に保管してください'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    try {
      final transactionService = ref.read(transactionServiceProvider.notifier);
      final filePath = await transactionService.exportData();
      
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

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('データ復元確認'),
        content: const Text(
          '既存のすべてのデータが削除され、'
          'バックアップファイルのデータで置き換えられます。\n\n'
          'この操作は取り消すことができません。\n'
          '続行しますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('復元'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ファイル選択機能を実装中です'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _deleteAllData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('データ削除確認'),
        content: const Text(
          'すべての取引データを削除しますか？\n\n'
          'この操作は取り消すことができません。\n'
          '削除する前にバックアップを取ることを強くお勧めします。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('データ削除機能を実装中です'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}