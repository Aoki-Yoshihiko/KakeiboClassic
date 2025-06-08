import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../services/transaction_service.dart';
import '../widgets/csv_export_dialog.dart';

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
                const Divider(height: 1),
                ListTile(
                  title: const Text('CSVファイルでエクスポート'),
                  subtitle: const Text('Excelで開けるCSV形式で保存'),
                  trailing: const Icon(Icons.table_chart),
                  onTap: () => showDialog(
                    context: context,
                    builder: (context) => const CSVExportDialog(),
                  ),
                ),
                ListTile(
                  title: const Text('データを共有'),
                  subtitle: const Text('メールやクラウドに保存'),
                  trailing: const Icon(Icons.share),
                  onTap: () => _shareData(context, ref),
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
                  subtitle: const Text('バックアップデータを読み込み'),
                  trailing: const Icon(Icons.upload),
                  onTap: () => _importData(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('CSVファイルからインポート'),
                  subtitle: const Text('CSV形式のデータを読み込み'),
                  trailing: const Icon(Icons.upload_file),
                  onTap: () => _importCSV(context, ref),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // データ管理セクション
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.delete_forever, color: Colors.red),
                  title: Text(
                    'データ削除',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  subtitle: Text('すべてのデータを削除'),
                ),
                ListTile(
                  title: const Text('全データを削除'),
                  subtitle: const Text('この操作は取り消せません'),
                  trailing: const Icon(Icons.warning, color: Colors.red),
                  textColor: Colors.red,
                  onTap: () => _clearAllData(context, ref),
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
                Text('• インポート時は現在のデータが上書きされます'),
                Text('• 機種変更時はデータを共有してから移行してください'),
                Text('• CSVファイルはExcelなどで編集可能です'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    try {
      // 確認ダイアログ
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('データをエクスポート'),
          content: const Text('現在のすべてのデータをファイルに保存します。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('エクスポート'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final transactionService = ref.read(transactionServiceProvider.notifier);
      final filePath = await transactionService.exportData();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('データを保存しました: ${filePath.split('/').last}'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: '共有',
              onPressed: () => Share.shareXFiles([XFile(filePath)]),
            ),
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

  Future<void> _shareData(BuildContext context, WidgetRef ref) async {
    try {
      final transactionService = ref.read(transactionServiceProvider.notifier);
      final filePath = await transactionService.exportData();
      
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: '家計簿データ ${DateFormat('yyyy年MM月dd日').format(DateTime.now())}',
      );
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
    try {
      // 警告ダイアログ
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('データをインポート'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('バックアップファイルからデータを復元します。'),
              SizedBox(height: 8),
              Text(
                '⚠️ 現在のデータはすべて上書きされます',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('インポート'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // ファイルピッカーでJSONファイルを選択
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) return;

      final filePath = result.files.single.path!;
      final transactionService = ref.read(transactionServiceProvider.notifier);
      
      await transactionService.importData(filePath);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('データをインポートしました'),
            backgroundColor: Colors.green,
          ),
        );
        
        // ホーム画面に戻る
        Navigator.of(context).popUntil((route) => route.isFirst);
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

  Future<void> _importCSV(BuildContext context, WidgetRef ref) async {
    try {
      // 警告ダイアログ
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('CSVファイルをインポート'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CSVファイルから取引データをインポートします。'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📄 CSVフォーマット', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('日付,種類,項目名,金額,カテゴリ,メモ,固定項目', style: TextStyle(fontSize: 12)),
                    Text('例: 2024/01/01,支出,コンビニ,500,日用品,お菓子,', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('選択'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // ファイルピッカーでCSVファイルを選択
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) return;

      final filePath = result.files.single.path!;
      final transactionService = ref.read(transactionServiceProvider.notifier);
      
      final importedCount = await transactionService.importFromCSV(filePath);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$importedCount件のデータをインポートしました'),
            backgroundColor: Colors.green,
          ),
        );
        
        // ホーム画面に戻る
        Navigator.of(context).popUntil((route) => route.isFirst);
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

  Future<void> _clearAllData(BuildContext context, WidgetRef ref) async {
    // 最終確認ダイアログ
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'すべてのデータを削除',
          style: TextStyle(color: Colors.red),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('本当にすべてのデータを削除しますか？'),
            SizedBox(height: 8),
            Text(
              'この操作は取り消せません！',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('削除前にバックアップを取ることをお勧めします。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              backgroundColor: Colors.red.shade50,
            ),
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 削除実行
    try {
      final transactionService = ref.read(transactionServiceProvider.notifier);
      await transactionService.clearAllData();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('すべてのデータを削除しました'),
            backgroundColor: Colors.orange,
          ),
        );
        
        // ホーム画面に戻る
        Navigator.of(context).popUntil((route) => route.isFirst);
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