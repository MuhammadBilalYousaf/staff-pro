import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:staffpro/core/constants/app_constants.dart';
import 'package:staffpro/models/models.dart';

class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();
  static const _storageKey = 'staffpro_db_json';

  final List<AppUser> users = [];
  final List<Business> businesses = [];
  final List<Branch> branches = [];
  final List<Shift> shifts = [];
  final List<Sale> sales = [];
  final List<Expense> expenses = [];
  final List<ExpenseCategory> expenseCategories = [];
  final List<AttendanceRecord> attendance = [];
  final List<AppNotification> notifications = [];
  final List<AuditLog> auditLogs = [];
  final List<BranchAssignment> assignments = [];
  final List<PasswordResetRequest> passwordRequests = [];
  PlatformSettings settings = PlatformSettings();

  SharedPreferences? _prefs;
  bool _loaded = false;

  Future<void> init() async {
    if (_loaded) return;
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _fromJson(decoded);
      } else if (decoded is Map) {
        _fromJson(Map<String, dynamic>.from(decoded));
      }
    } else {
      settings = PlatformSettings(secretCode: AppConstants.defaultSecretCode);
      await persist();
    }
    _loaded = true;
  }

  Future<void> persist() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_storageKey, jsonEncode(toJson()));
  }

  Map<String, dynamic> toJson() => {
        'users': users.map((e) => e.toJson()).toList(),
        'businesses': businesses.map((e) => e.toJson()).toList(),
        'branches': branches.map((e) => e.toJson()).toList(),
        'shifts': shifts.map((e) => e.toJson()).toList(),
        'sales': sales.map((e) => e.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'expenseCategories': expenseCategories.map((e) => e.toJson()).toList(),
        'attendance': attendance.map((e) => e.toJson()).toList(),
        'notifications': notifications.map((e) => e.toJson()).toList(),
        'auditLogs': auditLogs.map((e) => e.toJson()).toList(),
        'assignments': assignments.map((e) => e.toJson()).toList(),
        'passwordRequests': passwordRequests.map((e) => e.toJson()).toList(),
        'settings': settings.toJson(),
      };

  void _fromJson(Map<String, dynamic> json) {
    users
      ..clear()
      ..addAll(((json['users'] as List?) ?? []).map((e) => AppUser.fromJson(Map<String, dynamic>.from(e as Map))));
    businesses
      ..clear()
      ..addAll(((json['businesses'] as List?) ?? []).map((e) => Business.fromJson(Map<String, dynamic>.from(e as Map))));
    branches
      ..clear()
      ..addAll(((json['branches'] as List?) ?? []).map((e) => Branch.fromJson(Map<String, dynamic>.from(e as Map))));
    shifts
      ..clear()
      ..addAll(((json['shifts'] as List?) ?? []).map((e) => Shift.fromJson(Map<String, dynamic>.from(e as Map))));
    sales
      ..clear()
      ..addAll(((json['sales'] as List?) ?? []).map((e) => Sale.fromJson(Map<String, dynamic>.from(e as Map))));
    expenses
      ..clear()
      ..addAll(((json['expenses'] as List?) ?? []).map((e) => Expense.fromJson(Map<String, dynamic>.from(e as Map))));
    expenseCategories
      ..clear()
      ..addAll(((json['expenseCategories'] as List?) ?? [])
          .map((e) => ExpenseCategory.fromJson(Map<String, dynamic>.from(e as Map))));
    attendance
      ..clear()
      ..addAll(((json['attendance'] as List?) ?? [])
          .map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e as Map))));
    notifications
      ..clear()
      ..addAll(((json['notifications'] as List?) ?? [])
          .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e as Map))));
    auditLogs
      ..clear()
      ..addAll(((json['auditLogs'] as List?) ?? []).map((e) => AuditLog.fromJson(Map<String, dynamic>.from(e as Map))));
    assignments
      ..clear()
      ..addAll(((json['assignments'] as List?) ?? [])
          .map((e) => BranchAssignment.fromJson(Map<String, dynamic>.from(e as Map))));
    passwordRequests
      ..clear()
      ..addAll(((json['passwordRequests'] as List?) ?? [])
          .map((e) => PasswordResetRequest.fromJson(Map<String, dynamic>.from(e as Map))));
    settings = PlatformSettings.fromJson(
      json['settings'] is Map ? Map<String, dynamic>.from(json['settings'] as Map) : null,
    );
  }
}
