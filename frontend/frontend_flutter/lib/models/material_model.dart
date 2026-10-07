class MaterialModel {
  final int materialId;
  final String fileName;
  final String fileUrl;
  final String fileType;
  final int fileSizeKb;
  final String? description;
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
