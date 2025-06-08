// lib/providers/filter_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction.dart';

// フィルター条件を保持するクラス
class FilterCriteria {
  final String searchQuery;
  final double? minAmount;
  final double? maxAmount;
  final String? category;
  final TransactionType? type;

  FilterCriteria({
    this.searchQuery = '',
    this.minAmount,
    this.maxAmount,
    this.category,
    this.type,
  });

  FilterCriteria copyWith({
    String? searchQuery,
    double? minAmount,
    double? maxAmount,
    String? category,
    TransactionType? type,
    bool clearMinAmount = false,
    bool clearMaxAmount = false,
    bool clearCategory = false,
    bool clearType = false,
  }) {
    return FilterCriteria(
      searchQuery: searchQuery ?? this.searchQuery,
      minAmount: clearMinAmount ? null : (minAmount ?? this.minAmount),
      maxAmount: clearMaxAmount ? null : (maxAmount ?? this.maxAmount),
      category: clearCategory ? null : (category ?? this.category),
      type: clearType ? null : (type ?? this.type),
    );
  }

  bool get hasActiveFilters {
    return searchQuery.isNotEmpty ||
        minAmount != null ||
        maxAmount != null ||
        category != null ||
        type != null;
  }

  int get activeFilterCount {
    int count = 0;
    if (searchQuery.isNotEmpty) count++;
    if (minAmount != null) count++;
    if (maxAmount != null) count++;
    if (category != null) count++;
    if (type != null) count++;
    return count;
  }

  // フィルター条件に合致するかチェック
  bool matches(Transaction transaction) {
    // 検索クエリのチェック
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      final titleMatches = transaction.title.toLowerCase().contains(query);
      final memoMatches = transaction.memo?.toLowerCase().contains(query) ?? false;
      final categoryMatches = transaction.category?.toLowerCase().contains(query) ?? false;
      
      if (!titleMatches && !memoMatches && !categoryMatches) {
        return false;
      }
    }

    // 金額範囲のチェック
    if (minAmount != null && transaction.amount < minAmount!) {
      return false;
    }
    if (maxAmount != null && transaction.amount > maxAmount!) {
      return false;
    }

    // カテゴリのチェック
    if (category != null && transaction.category != category) {
      return false;
    }

    // タイプのチェック
    if (type != null && transaction.type != type) {
      return false;
    }

    return true;
  }
}

// フィルター状態を管理するNotifier
class FilterNotifier extends StateNotifier<FilterCriteria> {
  FilterNotifier() : super(FilterCriteria());

  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setMinAmount(double? amount) {
    state = state.copyWith(minAmount: amount, clearMinAmount: amount == null);
  }

  void setMaxAmount(double? amount) {
    state = state.copyWith(maxAmount: amount, clearMaxAmount: amount == null);
  }

  void setCategory(String? category) {
    state = state.copyWith(category: category, clearCategory: category == null);
  }

  void setType(TransactionType? type) {
    state = state.copyWith(type: type, clearType: type == null);
  }

  void clearFilters() {
    state = FilterCriteria();
  }
}

// 実績用のフィルタープロバイダー
final transactionFilterProvider = StateNotifierProvider<FilterNotifier, FilterCriteria>((ref) {
  return FilterNotifier();
});

// 予定用のフィルタープロバイダー
final scheduledFilterProvider = StateNotifierProvider<FilterNotifier, FilterCriteria>((ref) {
  return FilterNotifier();
});