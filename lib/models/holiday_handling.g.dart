// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'holiday_handling.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HolidayHandlingAdapter extends TypeAdapter<HolidayHandling> {
  @override
  final int typeId = 2;

  @override
  HolidayHandling read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return HolidayHandling.none;
      case 1:
        return HolidayHandling.before;
      case 2:
        return HolidayHandling.after;
      default:
        return HolidayHandling.none;
    }
  }

  @override
  void write(BinaryWriter writer, HolidayHandling obj) {
    switch (obj) {
      case HolidayHandling.none:
        writer.writeByte(0);
        break;
      case HolidayHandling.before:
        writer.writeByte(1);
        break;
      case HolidayHandling.after:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HolidayHandlingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
