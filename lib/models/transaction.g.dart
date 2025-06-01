// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionAdapter extends TypeAdapter<Transaction> {
  @override
  final int typeId = 0;

  @override
  Transaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Transaction()
      ..id = fields[0] as String
      ..title = fields[1] as String
      ..amount = fields[2] as double
      ..date = fields[3] as DateTime
      ..type = fields[4] as TransactionType
      ..isFixedItem = fields[5] as bool
      ..fixedMonths = (fields[6] as List).cast<int>()
      ..showAmountInSchedule = fields[7] == null ? false : fields[7] as bool
      ..memo = fields[8] as String?
      ..createdAt = fields[9] as DateTime
      ..updatedAt = fields[10] as DateTime
      ..fixedDay = fields[11] == null ? 1 : fields[11] as int
      ..holidayHandling = fields[12] == null
          ? HolidayHandling.none
          : fields[12] as HolidayHandling;
  }

  @override
  void write(BinaryWriter writer, Transaction obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.isFixedItem)
      ..writeByte(6)
      ..write(obj.fixedMonths)
      ..writeByte(7)
      ..write(obj.showAmountInSchedule)
      ..writeByte(8)
      ..write(obj.memo)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt)
      ..writeByte(11)
      ..write(obj.fixedDay)
      ..writeByte(12)
      ..write(obj.holidayHandling);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TransactionTypeAdapter extends TypeAdapter<TransactionType> {
  @override
  final int typeId = 1;

  @override
  TransactionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TransactionType.income;
      case 1:
        return TransactionType.expense;
      default:
        return TransactionType.income;
    }
  }

  @override
  void write(BinaryWriter writer, TransactionType obj) {
    switch (obj) {
      case TransactionType.income:
        writer.writeByte(0);
        break;
      case TransactionType.expense:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
