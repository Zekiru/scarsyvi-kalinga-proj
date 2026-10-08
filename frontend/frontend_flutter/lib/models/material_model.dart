import 'package:hive/hive.dart';

part 'material_model.g.dart';

@HiveType(typeId: 10)
class MaterialModel extends HiveObject {
  @HiveField(0)
  final int materialId;

  @HiveField(1)
  final String fileName;

  @HiveField(2)
  final String fileUrl;

  @HiveField(3)
  final String fileType;

  @HiveField(4)
  final int fileSizeKb;

  @HiveField(5)
  final String? description;

  @HiveField(6)
  final bool isOfflineCached;

  MaterialModel({
    required this.materialId,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSizeKb,
    this.description,
    required this.isOfflineCached,
  });

  factory MaterialModel.fromJson(Map<String, dynamic> json) {
    return MaterialModel(
      materialId: json['material_id'] as int,
      fileName: json['file_name'] as String,
      fileUrl: json['file_url'] as String,
      fileType: json['file_type'] as String,
      fileSizeKb: json['file_size_kb'] as int,
      description: json['description'] as String?,
      isOfflineCached: json['is_offline_cached'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'material_id': materialId,
      'file_name': fileName,
      'file_url': fileUrl,
      'file_type': fileType,
      'file_size_kb': fileSizeKb,
      'description': description,
      'is_offline_cached': isOfflineCached,
    };
  }
}
