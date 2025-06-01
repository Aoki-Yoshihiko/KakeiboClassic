import 'package:flutter/material.dart';

class MonthSelectorWidget extends StatefulWidget {
  final List<int> selectedMonths;
  final Function(List<int>) onChanged;

  const MonthSelectorWidget({
    super.key,
    required this.selectedMonths,
    required this.onChanged,
  });

  @override
  State<MonthSelectorWidget> createState() => _MonthSelectorWidgetState();
}

class _MonthSelectorWidgetState extends State<MonthSelectorWidget> {
  late List<int> _selectedMonths;

  @override
  void initState() {
    super.initState();
    _selectedMonths = List.from(widget.selectedMonths);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '固定する月を選択:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        
        // 毎月選択
        CheckboxListTile(
          title: const Text('毎月'),
          subtitle: const Text('毎月繰り返し'),
          value: _selectedMonths.contains(0),
          onChanged: (value) {
            setState(() {
              if (value == true) {
                _selectedMonths = [0]; // 毎月を選択したら他を全てクリア
              } else {
                _selectedMonths.remove(0);
              }
            });
            widget.onChanged(_selectedMonths);
          },
        ),
        
        const Divider(),
        
        // 月別選択（毎月が選択されていない場合のみ有効）
        ...List.generate(12, (index) {
          final month = index + 1;
          final isMonthlySelected = _selectedMonths.contains(0);
          
          return CheckboxListTile(
            title: Text('${month}月'),
            value: !isMonthlySelected && _selectedMonths.contains(month),
            onChanged: isMonthlySelected ? null : (value) {
              setState(() {
                if (value == true) {
                  _selectedMonths.add(month);
                } else {
                  _selectedMonths.remove(month);
                }
              });
              widget.onChanged(_selectedMonths);
            },
          );
        }),
        
        const SizedBox(height: 16),
        
        // 選択状況表示
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '選択状況:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(_getSelectedMonthsDisplay()),
            ],
          ),
        ),
      ],
    );
  }

  String _getSelectedMonthsDisplay() {
    if (_selectedMonths.isEmpty) {
      return '未選択（固定項目として設定されません）';
    }
    if (_selectedMonths.contains(0)) {
      return '毎月自動生成されます';
    }
    
    final months = _selectedMonths.map((m) => '${m}月').toList();
    months.sort();
    return '${months.join('、')}に自動生成されます';
  }
}