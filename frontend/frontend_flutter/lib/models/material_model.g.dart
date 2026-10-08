// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'material_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MaterialModelAdapter extends TypeAdapter<MaterialModel> {
  @override
  final int typeId = 10;

  @override
  MaterialModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MaterialModel(
      materialId: fields[0] as int,
      fileName: fields[1] as String,
      fileUrl: fields[2] as String,
      fileType: fields[3] as String,
      fileSizeKb: fields[4] as int,
      description: fields[5] as String?,
      isOfflineCached: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, MaterialModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.materialId)
      ..writeByte(1)
      ..write(obj.fileName)
      ..writeByte(2)
      ..write(obj.fileUrl)
      ..writeByte(3)
      ..write(obj.fileType)
      ..writeByte(4)
      ..write(obj.fileSizeKb)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.isOfflineCached);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaterialModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
