import 'dart:convert';

enum AccountRole {
  admin('ADMIN'),
  checker('CHECKER'),
  teacher('TEACHER');

  const AccountRole(this.apiValue);
  final String apiValue;

  static AccountRole fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'ADMIN':
        return AccountRole.admin;
      case 'CHECKER':
        return AccountRole.checker;
      case 'TEACHER':
      default:
        return AccountRole.teacher;
    }
  }
}

class Account {
  const Account({
    required this.id,
    required this.username,
    required this.email,
    this.firstName = '',
    this.lastName = '',
    required this.role,
    this.school = '',
    this.isActive = true,
  });

  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final AccountRole role;
  final String school;
  final bool isActive;

  String get fullName {
    final combined = '$firstName $lastName'.trim();
    return combined.isNotEmpty ? combined : username;
  }

  bool get isAdmin => role == AccountRole.admin;
  bool get isChecker => role == AccountRole.checker;
  bool get isTeacher => role == AccountRole.teacher;
  bool get canModerate => isAdmin || isChecker;

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: (json['id'] ?? json['user_id'] ?? json['pk']) as int,
      username: (json['username'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      firstName: (json['first_name'] ?? '') as String,
      lastName: (json['last_name'] ?? '') as String,
      role: AccountRole.fromString(json['role'] as String?),
      school: (json['school'] ?? '') as String,
      isActive: (json['is_active'] ?? true) as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'role': role.apiValue,
      'school': school,
      'is_active': isActive,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory Account.fromJsonString(String raw) =>
      Account.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
