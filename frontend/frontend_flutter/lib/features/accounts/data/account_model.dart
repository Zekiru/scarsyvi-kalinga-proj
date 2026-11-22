import 'dart:convert';
import '../../curriculum/data/models/json_parsers.dart';

enum AccountRole {
  teacher,
  checker,
  admin;

  String get apiValue {
    switch (this) {
      case AccountRole.teacher:
        return 'TEACHER';
      case AccountRole.checker:
        return 'CHECKER';
      case AccountRole.admin:
        return 'ADMIN';
    }
  }

  static AccountRole fromApi(dynamic raw) {
    final val = raw?.toString().trim().toUpperCase() ?? 'TEACHER';
    switch (val) {
      case 'ADMIN':
      case 'ADMINISTRATOR':
        return AccountRole.admin;
      case 'CHECKER':
      case 'REVIEWER':
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
    this.email = '',
    this.firstName = '',
    this.lastName = '',
    this.school = '',
    this.role = AccountRole.teacher,
    this.roleDisplay = '',
  });

  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String school;
  final AccountRole role;
  final String roleDisplay;

  String get fullName => '$firstName $lastName'.trim();

  bool get canTeach =>
      role == AccountRole.teacher ||
      role == AccountRole.checker ||
      role == AccountRole.admin;

  bool get canModerate =>
      role == AccountRole.checker || role == AccountRole.admin;

  bool get canAdminister => role == AccountRole.admin;

  factory Account.fromJson(Map<String, dynamic> json) {
    final userObj = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : (json['account'] is Map
            ? Map<String, dynamic>.from(json['account'] as Map)
            : json);

    final rawRole = userObj['role'] ?? json['role'];
    final parsedRole = AccountRole.fromApi(rawRole);

    return Account(
      id: asInt(
        userObj['id'] ??
            userObj['account_id'] ??
            userObj['user_id'] ??
            userObj['pk'] ??
            json['id'] ??
            json['account_id'],
      ),
      username: asString(userObj['username'] ?? json['username']),
      email: asString(userObj['email'] ?? json['email']),
      firstName: asString(userObj['first_name'] ?? json['first_name']),
      lastName: asString(userObj['last_name'] ?? json['last_name']),
      school: asString(
        userObj['school'] ??
            userObj['school_name'] ??
            json['school'] ??
            json['school_name'],
      ),
      role: parsedRole,
      roleDisplay: asString(
        userObj['role_display'] ?? json['role_display'],
        parsedRole.apiValue,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'account_id': id,
        'username': username,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'school': school,
        'role': role.apiValue,
        'role_display': roleDisplay,
      };

  String toJsonString() => jsonEncode(toJson());

  factory Account.fromJsonString(String raw) =>
      Account.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
