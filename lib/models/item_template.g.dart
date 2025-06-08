// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ItemTemplateAdapter extends TypeAdapter<ItemTemplate> {
  @override
  final int typeId = 3;

  @override
  ItemTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ItemTemplate(
      id: fields[0] as String,
      title: fields[1] as String,
      defaultAmount: fields[2] as double,
      type: fields[3] as TransactionType,
      memo: fields[4] as String?,
      category: fields[6] as String?,
      createdAt: fields[5] as DateTime,
      updatedAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ItemTemplate obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.defaultAmount)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.memo)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.category)
      ..writeByte(7)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
