// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_operation.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SyncOperationAdapter extends TypeAdapter<SyncOperation> {
  @override
  final int typeId = 1;

  @override
  SyncOperation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyncOperation(
      id: fields[0] as String,
      entityType: fields[1] as String,
      method: fields[2] as String,
      endpoint: fields[3] as String,
      payloadJson: fields[4] as String?,
      tempClientId: fields[5] as String?,
      primaryKeyField: fields[6] as String?,
      dependsOnTempIds: (fields[7] as List).cast<String>(),
      status: fields[8] as SyncOpStatus,
      errorMessage: fields[9] as String?,
      retryCount: fields[10] as int,
      createdAt: fields[11] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SyncOperation obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.entityType)
      ..writeByte(2)
      ..write(obj.method)
      ..writeByte(3)
      ..write(obj.endpoint)
      ..writeByte(4)
      ..write(obj.payloadJson)
      ..writeByte(5)
      ..write(obj.tempClientId)
      ..writeByte(6)
      ..write(obj.primaryKeyField)
      ..writeByte(7)
      ..write(obj.dependsOnTempIds)
      ..writeByte(8)
      ..write(obj.status)
      ..writeByte(9)
      ..write(obj.errorMessage)
      ..writeByte(10)
      ..write(obj.retryCount)
      ..writeByte(11)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncOperationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SyncOpStatusAdapter extends TypeAdapter<SyncOpStatus> {
  @override
  final int typeId = 0;

  @override
  SyncOpStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SyncOpStatus.pending;
      case 1:
        return SyncOpStatus.syncing;
      case 2:
        return SyncOpStatus.failedNeedsReview;
      default:
        return SyncOpStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, SyncOpStatus obj) {
    switch (obj) {
      case SyncOpStatus.pending:
        writer.writeByte(0);
        break;
      case SyncOpStatus.syncing:
        writer.writeByte(1);
        break;
      case SyncOpStatus.failedNeedsReview:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncOpStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
