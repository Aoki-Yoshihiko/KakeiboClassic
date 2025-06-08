// lib/providers/sort_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

// 並び替えの種類
enum SortType {
  dateDesc,    // 日付降順（新しい順）
  dateAsc,     // 日付昇順（古い順）
  amountDesc,  // 金額降順（高い順）
  amountAsc,   // 金額昇順（安い順）
  titleAsc,    // 項目名昇順（あ→ん）
  titleDesc,   // 項目名降順（ん→あ）
}

// 並び替え種類の拡張メソッド
extension SortTypeExtension on SortType {
  String get displayName {
    switch (this) {
      case SortType.dateDesc:
        return '日付（新しい順）';
      case SortType.dateAsc:
        return '日付（古い順）';
      case SortType.amountDesc:
        return '金額（高い順）';
      case SortType.amountAsc:
        return '金額（安い順）';
      case SortType.titleAsc:
        return '項目名（昇順）';
      case SortType.titleDesc:
        return '項目名（降順）';
    }
  }

  String get shortName {
    switch (this) {
      case SortType.dateDesc:
        return '新しい順';
      case SortType.dateAsc:
        return '古い順';
      case SortType.amountDesc:
        return '高額順';
      case SortType.amountAsc:
        return '少額順';
      case SortType.titleAsc:
        return '名前順↑';
      case SortType.titleDesc:
        return '名前順↓';
    }
  }
}

// 実績の並び替え状態
final transactionSortProvider = StateProvider<SortType>((ref) => SortType.dateDesc);

// 予定の並び替え状態
final scheduledSortProvider = StateProvider<SortType>((ref) => SortType.dateAsc);