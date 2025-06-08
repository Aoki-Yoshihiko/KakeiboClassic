import 'package:hive/hive.dart';
import 'transaction.dart';

part 'item_template.g.dart';

@HiveType(typeId: 3)
class ItemTemplate extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String title;

  @HiveField(2)
  late double defaultAmount;

  @HiveField(3)
  late TransactionType type;

  @HiveField(4)
  String? memo;

  @HiveField(5)
  late DateTime createdAt;

  @HiveField(6)
  String? category;

  @HiveField(7)
  late DateTime updatedAt;

  ItemTemplate({
    required this.id,
    required this.title,
    required this.defaultAmount,
    required this.type,
    this.memo,
    this.category,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  ItemTemplate.empty() {
    updatedAt = DateTime.now();
  }

  // 互換性のためのゲッター/セッター
  double get amount => defaultAmount;
  set amount(double value) => defaultAmount = value;

  ItemTemplate copyWith({
    String? id,
    String? title,
    double? defaultAmount,
    TransactionType? type,
    String? memo,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final newTemplate = ItemTemplate.empty();
    newTemplate.id = id ?? this.id;
    newTemplate.title = title ?? this.title;
    newTemplate.defaultAmount = defaultAmount ?? this.defaultAmount;
    newTemplate.type = type ?? this.type;
    newTemplate.memo = memo ?? this.memo;
    newTemplate.category = category ?? this.category;
    newTemplate.createdAt = createdAt ?? this.createdAt;
    newTemplate.updatedAt = updatedAt ?? this.updatedAt;
    return newTemplate;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'defaultAmount': defaultAmount,
      'type': type.index,
      'memo': memo,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ItemTemplate.fromJson(Map<String, dynamic> json) {
    final template = ItemTemplate.empty();
    template.id = json['id'];
    template.title = json['title'];
    template.defaultAmount = json['defaultAmount'].toDouble();
    template.type = TransactionType.values[json['type']];
    template.memo = json['memo'];
    template.category = json['category'];
    template.createdAt = DateTime.parse(json['createdAt']);
    template.updatedAt = DateTime.parse(json['updatedAt'] ?? json['createdAt']);
    return template;
  }
}