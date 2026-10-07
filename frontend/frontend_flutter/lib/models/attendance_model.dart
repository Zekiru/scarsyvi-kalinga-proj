class StudentAttendanceRecord {
  final int studentId;
  final String status;
  final String? notes;

  StudentAttendanceRecord({
    required this.studentId,
    this.status = 'PRESENT',
    this.notes,
  });

  factory StudentAttendanceRecord.fromJson(Map<String, dynamic> json) {
    return StudentAttendanceRecord(
      studentId: json['student_id'] as int,
      status: json['status'] as String? ?? 'PRESENT',
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'status': status,
      if (notes != null) 'notes': notes,
    };
  }
}

class AttendanceSessionModel {
  final int? id;
  final String date; // YYYY-MM-DD
  final String? remarks;
  final List<StudentAttendanceRecord> records;

  AttendanceSessionModel({
    this.id,
    required this.date,
    this.remarks,
    required this.records,
  });

  factory AttendanceSessionModel.fromJson(Map<String, dynamic> json) {
    return AttendanceSessionModel(
      id: json['id'] as int?,
      date: json['date'] as String,
      remarks: json['remarks'] as String?,
      records: (json['records'] as List<dynamic>?)
              ?.map((item) => StudentAttendanceRecord.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'remarks': remarks ?? '',
      'records': records.map((r) => r.toJson()).toList(),
    };
  }
}
