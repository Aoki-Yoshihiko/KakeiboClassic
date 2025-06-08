import 'package:hive/hive.dart';
import 'transaction.dart'; // TransactionTypeをインポート

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

  ItemTemplate({
    required this.id,
    required this.title,
    required this.defaultAmount,
    required this.type,
    this.memo,
    required this.createdAt,
  });

  // デフォルトコンストラクタ（Hive用）
  ItemTemplate.empty();

  ItemTemplate copyWith({
    String? id,
    String? title,
    double? defaultAmount,
    TransactionType? type,
    String? memo,
    DateTime? createdAt,
  }) {
    final newTemplate = ItemTemplate.empty();
    newTemplate.id = id ?? this.id;
    newTemplate.title = title ?? this.title;
    newTemplate.defaultAmount = defaultAmount ?? this.defaultAmount;
    newTemplate.type = type ?? this.type;
    newTemplate.memo = memo ?? this.memo;
    newTemplate.createdAt = createdAt ?? this.createdAt;
    return newTemplate;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'defaultAmount': defaultAmount,
      'type': type.index,
      'memo': memo,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ItemTemplate.fromJson(Map<String, dynamic> json) {
    final template = ItemTemplate.empty();
    template.id = json['id'];
    template.title = json['title'];
    template.defaultAmount = json['defaultAmount'].toDouble();
    template.type = TransactionType.values[json['type']];
    template.memo = json['memo'];
    template.createdAt = DateTime.parse(json['createdAt']);
    return template;
  }
}