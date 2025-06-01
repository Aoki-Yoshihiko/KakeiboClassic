import 'package:hive/hive.dart';

part 'holiday_handling.g.dart';

@HiveType(typeId: 2)
enum HolidayHandling {
  @HiveField(0)
  none,        // 処理なし（指定日のまま）
  
  @HiveField(1)
  before,      // 前営業日
  
  @HiveField(2)
  after,       // 後営業日
}

extension HolidayHandlingExtension on HolidayHandling {
  String get displayName {
    switch (this) {
      case HolidayHandling.none:
        return '処理なし';
      case HolidayHandling.before:
        return '前営業日';
      case HolidayHandling.after:
        return '後営業日';
    }
  }
  
  String get description {
    switch (this) {
      case HolidayHandling.none:
        return '指定日のまま表示';
      case HolidayHandling.before:
        return '休日の場合は前の営業日';
      case HolidayHandling.after:
        return '休日の場合は次の営業日';
    }
  }
}