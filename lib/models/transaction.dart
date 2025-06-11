import 'package:hive/hive.dart';
import 'holiday_handling.dart';

part 'transaction.g.dart';

@HiveType(typeId: 1)
enum TransactionType {
  @HiveField(0)
  income,
  @HiveField(1)
  expense,
}

@HiveType(typeId: 0)
class Transaction extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String title;

  @HiveField(2)
  late double amount;

  @HiveField(3)
  late DateTime date;

  @HiveField(4)
  late TransactionType type;

  @HiveField(5)
  late bool isFixedItem;

  @HiveField(6)
  late List<int> fixedMonths;

  @HiveField(7, defaultValue: false)
  late bool showAmountInSchedule;  // 予定での金額表示ON/OFF

  @HiveField(8)
  String? memo;

  @HiveField(9)
  late DateTime createdAt;

  @HiveField(10)
  late DateTime updatedAt;

  // 固定項目の発生日（1-31）
  @HiveField(11, defaultValue: 1)
  late int fixedDay;

  @HiveField(12, defaultValue: HolidayHandling.none)
  late HolidayHandling holidayHandling;

  @HiveField(13) // カテゴリフィールド
  String? category;

  Transaction();

  Transaction copyWith({
    String? id,
    String? title,
    double? defaultAmount ,
    DateTime? date,
    TransactionType? type,
    bool? isFixedItem,
    List<int>? fixedMonths,
    bool? showAmountInSchedule,
    String? memo,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? fixedDay,
    HolidayHandling? holidayHandling,
    String? category,
  }) {
    final newTransaction = Transaction();
    newTransaction.id = id ?? this.id;
    newTransaction.title = title ?? this.title;
    newTransaction.amount = amount ?? this.amount;
    newTransaction.date = date ?? this.date;
    newTransaction.type = type ?? this.type;
    newTransaction.isFixedItem = isFixedItem ?? this.isFixedItem;
    newTransaction.fixedMonths = fixedMonths ?? List.from(this.fixedMonths);
    newTransaction.showAmountInSchedule = showAmountInSchedule ?? this.showAmountInSchedule;
    newTransaction.memo = memo ?? this.memo;
    newTransaction.createdAt = createdAt ?? this.createdAt;
    newTransaction.updatedAt = updatedAt ?? this.updatedAt;
    newTransaction.fixedDay = fixedDay ?? this.fixedDay;
    newTransaction.holidayHandling = holidayHandling ?? this.holidayHandling;
    newTransaction.category = category ?? this.category;
    return newTransaction;
  }

  // 固定項目が指定された月に表示されるかチェック
  bool isFixedInMonth(int month) {
    if (!isFixedItem) return false;
    return fixedMonths.isEmpty || fixedMonths.contains(month);
  }

  // 休日処理を適用した実際の日付を取得
  DateTime getAdjustedDate(DateTime targetMonth) {
    // 月末日を超える場合の処理
    final lastDayOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
    final adjustedDay = fixedDay > lastDayOfMonth ? lastDayOfMonth : fixedDay;
    
    DateTime targetDate = DateTime(targetMonth.year, targetMonth.month, adjustedDay);
    
    if (holidayHandling == HolidayHandling.none) {
      return targetDate;
    }
    
    // 簡易的な休日判定（土日のみ）
    while (_isWeekend(targetDate)) {
      if (holidayHandling == HolidayHandling.before) {
        targetDate = targetDate.subtract(const Duration(days: 1));
        // 前月になってしまった場合は、元の日付の前の金曜日を返す
        if (targetDate.month != targetMonth.month) {
          targetDate = DateTime(targetMonth.year, targetMonth.month, adjustedDay);
          while (_isWeekend(targetDate)) {
            targetDate = targetDate.subtract(const Duration(days: 1));
          }
          break;
        }
      } else {
        targetDate = targetDate.add(const Duration(days: 1));
        // 翌月になってしまった場合は、そのまま翌月の日付を返す
      }
    }
    
    return targetDate;
  }

  bool _isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type.index,
      'isFixedItem': isFixedItem,
      'fixedMonths': fixedMonths,
      'showAmountInSchedule': showAmountInSchedule,
      'memo': memo,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'fixedDay': fixedDay,
      'holidayHandling': holidayHandling.index,
      'category': category,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final transaction = Transaction();
    transaction.id = json['id'];
    transaction.title = json['title'];
    transaction.amount = json['amount'].toDouble();
    transaction.date = DateTime.parse(json['date']);
    transaction.type = TransactionType.values[json['type']];
    transaction.isFixedItem = json['isFixedItem'] ?? false;
    transaction.fixedMonths = List<int>.from(json['fixedMonths'] ?? []);
    transaction.showAmountInSchedule = json['showAmountInSchedule'] ?? false;
    transaction.memo = json['memo'];
    transaction.createdAt = DateTime.parse(json['createdAt']);
    transaction.updatedAt = DateTime.parse(json['updatedAt']);
    transaction.fixedDay = json['fixedDay'] ?? 1;
    transaction.holidayHandling = json['holidayHandling'] != null 
        ? HolidayHandling.values[json['holidayHandling']] 
        : HolidayHandling.none;
    transaction.category = json['category'];
    return transaction;
  }
}