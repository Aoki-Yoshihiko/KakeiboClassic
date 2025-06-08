import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/theme_service.dart';
import '../services/transaction_service.dart';
import '../widgets/csv_export_dialog.dart';
import '../widgets/template_selection_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          // アプリ設定
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'アプリ設定',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),

          // テーマ設定
          ListTile(
            leading: Icon(
              themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
            ),
            title: const Text('テーマ'),
            subtitle: Text(
              themeMode == ThemeMode.dark ? 'ダークモード' : 'ライトモード',
            ),
            trailing: Switch(
              value: themeMode == ThemeMode.dark,
              onChanged: (value) {
                ref.read(themeServiceProvider.notifier).toggleTheme();
              },
            ),
          ),

          // テンプレート管理
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text('テンプレート管理'),
            subtitle: const Text('よく使う取引をテンプレートとして保存'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const TemplateSelectionDialog(),
              );
            },
          ),

          // データ管理
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'データ管理',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),

          // CSVエクスポート
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('データエクスポート'),
            subtitle: const Text('取引データをCSVファイルで出力'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const CSVExportDialog(),
              );
            },
          ),

          // データリセット
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('データをリセット'),
            subtitle: const Text('すべての取引データを削除'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showResetDialog(context, ref),
          ),

          // アプリ情報
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'アプリ情報',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),

          // バージョン情報
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('バージョン'),
            subtitle: Text('家計簿〜暮らしっく v1.0.0'),
          ),

          // 利用規約
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('利用規約'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              _showTermsDialog(context);
            },
          ),

          // プライバシーポリシー
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('プライバシーポリシー'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              _showPrivacyDialog(context);
            },
          ),

          // デバッグ情報（デバッグモード時のみ）
          if (const bool.fromEnvironment('dart.vm.product') == false) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'デバッグ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.orange),
              title: const Text('デバッグ情報'),
              subtitle: const Text('開発者向け情報'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _showDebugInfo(context, ref),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('データリセット'),
        content: const Text(
          'すべての取引データが削除されます。\nこの操作は取り消せません。\n\n本当に削除しますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref.read(transactionServiceProvider.notifier).clearAllData();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('データをリセットしました'),
                    backgroundColor: Colors.red,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('リセットに失敗しました: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('利用規約'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '家計簿〜暮らしっく 利用規約',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                '第1条（適用）\n'
                '本規約は、本アプリの利用条件を定めるものです。\n\n'
                '第2条（利用者の責任）\n'
                '利用者は、自己の責任において本アプリを利用するものとします。\n\n'
                '第3条（データの管理）\n'
                '利用者は、入力したデータの管理について責任を負います。\n\n'
                '第4条（免責事項）\n'
                '本アプリの利用による損害について、開発者は一切の責任を負いません。',
                style: TextStyle(fontSize: 12),
              ),
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

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('プライバシーポリシー'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '家計簿〜暮らしっく プライバシーポリシー',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                '1. 個人情報の収集\n'
                '本アプリは、利用者の個人情報を収集しません。\n\n'
                '2. データの保存\n'
                'すべてのデータは端末内にローカル保存されます。\n\n'
                '3. データの送信\n'
                '本アプリは、入力されたデータを外部に送信しません。\n\n'
                '4. 分析ツール\n'
                '本アプリは、アクセス解析ツールを使用していません。',
                style: TextStyle(fontSize: 12),
              ),
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

  void _showDebugInfo(BuildContext context, WidgetRef ref) {
    final transactionService = ref.read(transactionServiceProvider.notifier);
    final totalTransactions = transactionService.state.length;
    final fixedItems = transactionService.state.where((t) => t.isFixedItem).length;
    final regularItems = totalTransactions - fixedItems;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('デバッグ情報'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('総取引数: $totalTransactions'),
            Text('実績: $regularItems'),
            Text('固定項目: $fixedItems'),
            const SizedBox(height: 16),
            Text('ビルドモード: ${const bool.fromEnvironment('dart.vm.product') ? 'Release' : 'Debug'}'),
            Text('Dart version: ${const String.fromEnvironment('dart.version', defaultValue: 'Unknown')}'),
          ],
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