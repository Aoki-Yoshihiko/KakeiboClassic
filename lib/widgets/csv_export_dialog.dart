// lib/widgets/csv_export_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../services/transaction_service.dart';

class CSVExportDialog extends ConsumerStatefulWidget {
  const CSVExportDialog({super.key});

  @override
  ConsumerState<CSVExportDialog> createState() => _CSVExportDialogState();
}

class _CSVExportDialogState extends ConsumerState<CSVExportDialog> {
  String _selectedOption = 'all';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('CSVエクスポート'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'エクスポート範囲を選択してください',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            
            // オプション選択
            RadioListTile<String>(
              title: const Text('すべてのデータ'),
              subtitle: const Text('全期間の取引データ'),
              value: 'all',
              groupValue: _selectedOption,
              onChanged: (value) => setState(() => _selectedOption = value!),
            ),
            RadioListTile<String>(
              title: const Text('今月のデータ'),
              subtitle: Text(DateFormat('yyyy年M月').format(DateTime.now())),
              value: 'month',
              groupValue: _selectedOption,
              onChanged: (value) => setState(() => _selectedOption = value!),
            ),
            RadioListTile<String>(
              title: const Text('期間を指定'),
              subtitle: const Text('開始日と終了日を選択'),
              value: 'period',
              groupValue: _selectedOption,
              onChanged: (value) => setState(() => _selectedOption = value!),
            ),
            
            // 期間指定の場合
            if (_selectedOption == 'period') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectStartDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '開始日',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: Text(
                          DateFormat('yyyy/MM/dd').format(_startDate),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectEndDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '終了日',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: Text(
                          DateFormat('yyyy/MM/dd').format(_endDate),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 16),
            
            // CSV形式の説明
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📄 CSVファイルの内容',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '日付、種類、項目名、金額、カテゴリ、メモ、固定項目',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Excel等の表計算ソフトで開けます',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    '• 文字化け防止のためUTF-8（BOM付き）で保存',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isExporting ? null : () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _isExporting ? null : _exportCSV,
          child: _isExporting 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('エクスポート'),
        ),
      ],
    );
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: _endDate,
      locale: const Locale('ja', 'JP'),
    );
    if (date != null) {
      setState(() => _startDate = date);
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
      locale: const Locale('ja', 'JP'),
    );
    if (date != null) {
      setState(() => _endDate = date);
    }
  }

  Future<void> _exportCSV() async {
    setState(() => _isExporting = true);

    try {
      final transactionService = ref.read(transactionServiceProvider.notifier);
      String filePath;
      
      switch (_selectedOption) {
        case 'all':
          filePath = await transactionService.exportToCSV();
          break;
        case 'month':
          final now = DateTime.now();
          filePath = await transactionService.exportMonthToCSV(now);
          break;
        case 'period':
          filePath = await transactionService.exportPeriodToCSV(_startDate, _endDate);
          break;
        default:
          return;
      }
      
      if (mounted) {
        Navigator.pop(context);
        
        // 共有ダイアログを表示
        await Share.shareXFiles(
          [XFile(filePath)],
          subject: '家計簿データ（CSV）${DateFormat('yyyyMMdd').format(DateTime.now())}',
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CSVファイルを作成しました'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isExporting = false);
      if (mounted) {
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