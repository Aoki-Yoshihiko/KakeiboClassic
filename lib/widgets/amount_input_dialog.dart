// lib/widgets/amount_input_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // TextInputFormatterのために追加

Future<double?> showAmountInputDialog(BuildContext context, {double? initialAmount}) async {
  final TextEditingController _controller = TextEditingController(text: initialAmount?.toString() ?? '');
  
  return showDialog<double?>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('金額を入力してください'),
        content: TextField(
          controller: _controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}$')), // 数字と小数点のみ、小数点以下2桁まで
          ],
          decoration: const InputDecoration(
            hintText: '金額',
          ),
          autofocus: true,
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('キャンセル'),
            onPressed: () {
              Navigator.of(dialogContext).pop(); // null を返す
            },
          ),
          TextButton(
            child: const Text('確定'),
            onPressed: () {
              final double? amount = double.tryParse(_controller.text);
              Navigator.of(dialogContext).pop(amount ?? 0.0); // パースできない場合は0.0を返す
            },
          ),
        ],
      );
    },
  );
}