import 'package:staffpro/models/enums.dart';

T _enumFrom<T extends Enum>(List<T> values, String? raw, T fallback) {
  if (raw == null) return fallback;
  return values.cast<T?>().firstWhere(
        (e) => e!.name == raw,
        orElse: () => fallback,
      )!;
}

DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
String _s(dynamic v, [String d = '']) => v?.toString() ?? d;
double? _d(dynamic v) => v == null ? null : double.tryParse(v.toString());
int? _i(dynamic v) => v == null ? null : int.tryParse(v.toString());
bool _b(dynamic v, [bool d = false]) => v is bool ? v : d;

class AdminPermissions {
  const AdminPermissions({
    this.fullAccess = true,
    this.employeeManagement = true,
    this.branchManagement = true,
    this.manageCategories = true,
  });

  final bool fullAccess;
  final bool employeeManagement;
  final bool branchManagement;
  final bool manageCategories;

  bool get canManageEmployees => fullAccess || employeeManagement;
  bool get canManageBranches => fullAccess || branchManagement;
  bool get canManageCategories => fullAccess || manageCategories;
  bool get canCorrectAttendance => fullAccess;
  bool get canTransfer => fullAccess || branchManagement;

  Map<String, dynamic> toJson() => {
        'fullAccess': fullAccess,
        'employeeManagement': employeeManagement,
        'branchManagement': branchManagement,
        'manageCategories': manageCategories,
      };

  factory AdminPermissions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AdminPermissions();
    return AdminPermissions(
      fullAccess: _b(json['fullAccess'], true),
      employeeManagement: _b(json['employeeManagement'], true),
      branchManagement: _b(json['branchManagement'], true),
      manageCategories: _b(json['manageCategories'], true),
    );
  }

  AdminPermissions copyWith({
    bool? fullAccess,
    bool? employeeManagement,
    bool? branchManagement,
    bool? manageCategories,
  }) {
    return AdminPermissions(
      fullAccess: fullAccess ?? this.fullAccess,
      employeeManagement: employeeManagement ?? this.employeeManagement,
      branchManagement: branchManagement ?? this.branchManagement,
      manageCategories: manageCategories ?? this.manageCategories,
    );
  }
}

class AppUser {
  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.passwordHash,
    required this.passwordSalt,
    required this.role,
    this.phone = '',
    this.businessId,
    this.branchId,
    this.managerId,
    this.employeeCode,
    this.position,
    this.joiningDate,
    this.status = EntityStatus.active,
    this.photoPath,
    this.permissions = const AdminPermissions(),
    this.isOwner = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String fullName;
  String email;
  String passwordHash;
  String passwordSalt;
  UserRole role;
  String phone;
  String? businessId;
  String? branchId;
  String? managerId;
  String? employeeCode;
  String? position;
  DateTime? joiningDate;
  EntityStatus status;
  String? photoPath;
  AdminPermissions permissions;
  bool isOwner;
  DateTime createdAt;
  DateTime updatedAt;

  bool get isActive => status == EntityStatus.active;
  String get firstName => fullName.split(' ').first;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'passwordHash': passwordHash,
        'passwordSalt': passwordSalt,
        'role': role.name,
        'phone': phone,
        'businessId': businessId,
        'branchId': branchId,
        'managerId': managerId,
        'employeeCode': employeeCode,
        'position': position,
        'joiningDate': joiningDate?.toIso8601String(),
        'status': status.name,
        'photoPath': photoPath,
        'permissions': permissions.toJson(),
        'isOwner': isOwner,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: _s(json['id']),
      fullName: _s(json['fullName']),
      email: _s(json['email']),
      passwordHash: _s(json['passwordHash']),
      passwordSalt: _s(json['passwordSalt']),
      role: _enumFrom(UserRole.values, json['role']?.toString(), UserRole.employee),
      phone: _s(json['phone']),
      businessId: json['businessId']?.toString(),
      branchId: json['branchId']?.toString(),
      managerId: json['managerId']?.toString(),
      employeeCode: json['employeeCode']?.toString(),
      position: json['position']?.toString(),
      joiningDate: _dt(json['joiningDate']),
      status: _enumFrom(EntityStatus.values, json['status']?.toString(), EntityStatus.active),
      photoPath: json['photoPath']?.toString(),
      permissions: AdminPermissions.fromJson(
        json['permissions'] is Map<String, dynamic>
            ? json['permissions'] as Map<String, dynamic>
            : null,
      ),
      isOwner: _b(json['isOwner']),
      createdAt: _dt(json['createdAt']) ?? DateTime.now(),
      updatedAt: _dt(json['updatedAt']) ?? DateTime.now(),
    );
  }
}

class Business {
  Business({
    required this.id,
    required this.name,
    this.code = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.city = '',
    this.status = EntityStatus.active,
    this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String name;
  String code;
  String phone;
  String email;
  String address;
  String city;
  EntityStatus status;
  String? createdBy;
  DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'phone': phone,
        'email': email,
        'address': address,
        'city': city,
        'status': status.name,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Business.fromJson(Map<String, dynamic> json) {
    return Business(
      id: _s(json['id']),
      name: _s(json['name']),
      code: _s(json['code']),
      phone: _s(json['phone']),
      email: _s(json['email']),
      address: _s(json['address']),
      city: _s(json['city']),
      status: _enumFrom(EntityStatus.values, json['status']?.toString(), EntityStatus.active),
      createdBy: json['createdBy']?.toString(),
      createdAt: _dt(json['createdAt']) ?? DateTime.now(),
      updatedAt: _dt(json['updatedAt']) ?? DateTime.now(),
    );
  }
}

class Branch {
  Branch({
    required this.id,
    required this.businessId,
    required this.name,
    this.code = '',
    this.phone = '',
    this.address = '',
    this.city = '',
    this.latitude,
    this.longitude,
    this.geofenceRadius = 200,
    this.blockOutsideGeofence = false,
    this.status = EntityStatus.active,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String businessId;
  String name;
  String code;
  String phone;
  String address;
  String city;
  double? latitude;
  double? longitude;
  double geofenceRadius;
  bool blockOutsideGeofence;
  EntityStatus status;
  DateTime createdAt;
  DateTime updatedAt;

  bool get hasLocation => latitude != null && longitude != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'code': code,
        'phone': phone,
        'address': address,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
        'geofenceRadius': geofenceRadius,
        'blockOutsideGeofence': blockOutsideGeofence,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: _s(json['id']),
      businessId: _s(json['businessId']),
      name: _s(json['name']),
      code: _s(json['code']),
      phone: _s(json['phone']),
      address: _s(json['address']),
      city: _s(json['city']),
      latitude: _d(json['latitude']),
      longitude: _d(json['longitude']),
      geofenceRadius: _d(json['geofenceRadius']) ?? 200,
      blockOutsideGeofence: _b(json['blockOutsideGeofence']),
      status: _enumFrom(EntityStatus.values, json['status']?.toString(), EntityStatus.active),
      createdAt: _dt(json['createdAt']) ?? DateTime.now(),
      updatedAt: _dt(json['updatedAt']) ?? DateTime.now(),
    );
  }
}

class Shift {
  Shift({
    required this.id,
    required this.businessId,
    this.branchId,
    required this.name,
    this.startTime = '09:00',
    this.endTime = '18:00',
    this.gracePeriodMinutes = 15,
    this.status = EntityStatus.active,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String businessId;
  String? branchId;
  String name;
  String startTime;
  String endTime;
  int gracePeriodMinutes;
  EntityStatus status;
  DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'branchId': branchId,
        'name': name,
        'startTime': startTime,
        'endTime': endTime,
        'gracePeriodMinutes': gracePeriodMinutes,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: _s(json['id']),
      businessId: _s(json['businessId']),
      branchId: json['branchId']?.toString(),
      name: _s(json['name'], 'Default Shift'),
      startTime: _s(json['startTime'], '09:00'),
      endTime: _s(json['endTime'], '18:00'),
      gracePeriodMinutes: _i(json['gracePeriodMinutes']) ?? 15,
      status: _enumFrom(EntityStatus.values, json['status']?.toString(), EntityStatus.active),
      createdAt: _dt(json['createdAt']) ?? DateTime.now(),
      updatedAt: _dt(json['updatedAt']) ?? DateTime.now(),
    );
  }
}

class Sale {
  Sale({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.userId,
    required this.amount,
    required this.date,
    this.category = 'Retail',
    this.paymentMethod = 'Cash',
    this.description = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String businessId;
  String branchId;
  String userId;
  double amount;
  DateTime date;
  String category;
  String paymentMethod;
  String description;
  DateTime createdAt;
  DateTime updatedAt;

  bool get isCash => paymentMethod.toLowerCase() == 'cash';

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'branchId': branchId,
        'userId': userId,
        'amount': amount,
        'date': date.toIso8601String(),
        'category': category,
        'paymentMethod': paymentMethod,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: _s(json['id']),
      businessId: _s(json['businessId']),
      branchId: _s(json['branchId']),
      userId: _s(json['userId']),
      amount: _d(json['amount']) ?? 0,
      date: _dt(json['date']) ?? DateTime.now(),
      category: _s(json['category'], 'Retail'),
      paymentMethod: _s(json['paymentMethod'], 'Cash'),
      description: _s(json['description']),
      createdAt: _dt(json['createdAt']) ?? DateTime.now(),
      updatedAt: _dt(json['updatedAt']) ?? DateTime.now(),
    );
  }
}

class Expense {
  Expense({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.userId,
    required this.amount,
    required this.date,
    required this.categoryId,
    this.categoryName = '',
    this.paymentMethod = 'Cash',
    this.description = '',
    this.receiptPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String businessId;
  String branchId;
  String userId;
  double amount;
  DateTime date;
  String categoryId;
  String categoryName;
  String paymentMethod;
  String description;
  String? receiptPath;
  DateTime createdAt;
  DateTime updatedAt;

  bool get isCash => paymentMethod.toLowerCase() == 'cash';

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'branchId': branchId,
        'userId': userId,
        'amount': amount,
        'date': date.toIso8601String(),
        'categoryId': categoryId,
        'categoryName': categoryName,
        'paymentMethod': paymentMethod,
        'description': description,
        'receiptPath': receiptPath,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: _s(json['id']),
      businessId: _s(json['businessId']),
      branchId: _s(json['branchId']),
      userId: _s(json['userId']),
      amount: _d(json['amount']) ?? 0,
      date: _dt(json['date']) ?? DateTime.now(),
      categoryId: _s(json['categoryId']),
      categoryName: _s(json['categoryName']),
      paymentMethod: _s(json['paymentMethod'], 'Cash'),
      description: _s(json['description']),
      receiptPath: json['receiptPath']?.toString(),
      createdAt: _dt(json['createdAt']) ?? DateTime.now(),
      updatedAt: _dt(json['updatedAt']) ?? DateTime.now(),
    );
  }
}

class ExpenseCategory {
  ExpenseCategory({
    required this.id,
    required this.businessId,
    required this.name,
    this.status = EntityStatus.active,
    this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String businessId;
  String name;
  EntityStatus status;
  String? createdBy;
  DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'status': status.name,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      id: _s(json['id']),
      businessId: _s(json['businessId']),
      name: _s(json['name']),
      status: _enumFrom(EntityStatus.values, json['status']?.toString(), EntityStatus.active),
      createdBy: json['createdBy']?.toString(),
      createdAt: _dt(json['createdAt']) ?? DateTime.now(),
      updatedAt: _dt(json['updatedAt']) ?? DateTime.now(),
    );
  }
}

class AttendanceRecord {
  AttendanceRecord({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.userId,
    required this.role,
    required this.date,
    required this.checkInAt,
    this.checkOutAt,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.shiftId,
    this.workedMinutes,
    this.status = AttendanceStatus.present,
    this.locationVerified = false,
    this.outsideGeofence = false,
    this.correctionReason,
    this.correctedBy,
    this.correctedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String businessId;
  String branchId;
  String userId;
  UserRole role;
  DateTime date;
  DateTime checkInAt;
  DateTime? checkOutAt;
  double? checkInLatitude;
  double? checkInLongitude;
  double? checkOutLatitude;
  double? checkOutLongitude;
  String? shiftId;
  int? workedMinutes;
  AttendanceStatus status;
  bool locationVerified;
  bool outsideGeofence;
  String? correctionReason;
  String? correctedBy;
  DateTime? correctedAt;
  DateTime createdAt;
  DateTime updatedAt;

  bool get isOpen => checkOutAt == null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'branchId': branchId,
        'userId': userId,
        'role': role.name,
        'date': date.toIso8601String(),
        'checkInAt': checkInAt.toIso8601String(),
        'checkOutAt': checkOutAt?.toIso8601String(),
        'checkInLatitude': checkInLatitude,
        'checkInLongitude': checkInLongitude,
        'checkOutLatitude': checkOutLatitude,
        'checkOutLongitude': checkOutLongitude,
        'shiftId': shiftId,
        'workedMinutes': workedMinutes,
        'status': status.name,
        'locationVerified': locationVerified,
        'outsideGeofence': outsideGeofence,
        'correctionReason': correctionReason,
        'correctedBy': correctedBy,
        'correctedAt': correctedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: _s(json['id']),
      businessId: _s(json['businessId']),
      branchId: _s(json['branchId']),
      userId: _s(json['userId']),
      role: _enumFrom(UserRole.values, json['role']?.toString(), UserRole.employee),
      date: _dt(json['date']) ?? DateTime.now(),
      checkInAt: _dt(json['checkInAt']) ?? DateTime.now(),
      checkOutAt: _dt(json['checkOutAt']),
      checkInLatitude: _d(json['checkInLatitude']),
      checkInLongitude: _d(json['checkInLongitude']),
      checkOutLatitude: _d(json['checkOutLatitude']),
      checkOutLongitude: _d(json['checkOutLongitude']),
      shiftId: json['shiftId']?.toString(),
      workedMinutes: _i(json['workedMinutes']),
      status: _enumFrom(
        AttendanceStatus.values,
        json['status']?.toString(),
        AttendanceStatus.present,
      ),
      locationVerified: _b(json['locationVerified']),
      outsideGeofence: _b(json['outsideGeofence']),
      correctionReason: json['correctionReason']?.toString(),
      correctedBy: json['correctedBy']?.toString(),
      correctedAt: _dt(json['correctedAt']),
      createdAt: _dt(json['createdAt']) ?? DateTime.now(),
      updatedAt: _dt(json['updatedAt']) ?? DateTime.now(),
    );
  }
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.recipientUserId,
    required this.type,
    required this.title,
    required this.message,
    this.businessId,
    this.branchId,
    this.relatedRecordId,
    this.isRead = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  String recipientUserId;
  String? businessId;
  String? branchId;
  NotificationType type;
  String title;
  String message;
  bool isRead;
  String? relatedRecordId;
  DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipientUserId': recipientUserId,
        'businessId': businessId,
        'branchId': branchId,
        'type': type.name,
        'title': title,
        'message': message,
        'isRead': isRead,
        'relatedRecordId': relatedRecordId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: _s(json['id']),
      recipientUserId: _s(json['recipientUserId']),
      businessId: json['businessId']?.toString(),
      branchId: json['branchId']?.toString(),
      type: _enumFrom(
        NotificationType.values,
        json['type']?.toString(),
        NotificationType.system,
      ),
      title: _s(json['title']),
      message: _s(json['message']),
      isRead: _b(json['isRead']),
      relatedRecordId: json['relatedRecordId']?.toString(),
      createdAt: _dt(json['createdAt']) ?? DateTime.now(),
    );
  }
}

class AuditLog {
  AuditLog({
    required this.id,
    required this.performedBy,
    required this.performedByRole,
    required this.action,
    required this.module,
    this.businessId,
    this.branchId,
    this.recordId,
    this.previousData,
    this.newData,
    this.reason,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  String? businessId;
  String? branchId;
  String performedBy;
  UserRole performedByRole;
  AuditAction action;
  String module;
  String? recordId;
  String? previousData;
  String? newData;
  String? reason;
  DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'branchId': branchId,
        'performedBy': performedBy,
        'performedByRole': performedByRole.name,
        'action': action.name,
        'module': module,
        'recordId': recordId,
        'previousData': previousData,
        'newData': newData,
        'reason': reason,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: _s(json['id']),
      businessId: json['businessId']?.toString(),
      branchId: json['branchId']?.toString(),
      performedBy: _s(json['performedBy']),
      performedByRole: _enumFrom(
        UserRole.values,
        json['performedByRole']?.toString(),
        UserRole.employee,
      ),
      action: _enumFrom(AuditAction.values, json['action']?.toString(), AuditAction.update),
      module: _s(json['module']),
      recordId: json['recordId']?.toString(),
      previousData: json['previousData']?.toString(),
      newData: json['newData']?.toString(),
      reason: json['reason']?.toString(),
      createdAt: _dt(json['createdAt']) ?? DateTime.now(),
    );
  }
}

class BranchAssignment {
  BranchAssignment({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.toBranchId,
    required this.effectiveFrom,
    this.fromBranchId,
    this.effectiveTo,
    this.changedBy,
    this.reason,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  String businessId;
  String userId;
  String? fromBranchId;
  String toBranchId;
  DateTime effectiveFrom;
  DateTime? effectiveTo;
  String? changedBy;
  String? reason;
  DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'userId': userId,
        'fromBranchId': fromBranchId,
        'toBranchId': toBranchId,
        'effectiveFrom': effectiveFrom.toIso8601String(),
        'effectiveTo': effectiveTo?.toIso8601String(),
        'changedBy': changedBy,
        'reason': reason,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BranchAssignment.fromJson(Map<String, dynamic> json) {
    return BranchAssignment(
      id: _s(json['id']),
      businessId: _s(json['businessId']),
      userId: _s(json['userId']),
      fromBranchId: json['fromBranchId']?.toString(),
      toBranchId: _s(json['toBranchId']),
      effectiveFrom: _dt(json['effectiveFrom']) ?? DateTime.now(),
      effectiveTo: _dt(json['effectiveTo']),
      changedBy: json['changedBy']?.toString(),
      reason: json['reason']?.toString(),
      createdAt: _dt(json['createdAt']) ?? DateTime.now(),
    );
  }
}

class PasswordResetRequest {
  PasswordResetRequest({
    required this.id,
    required this.userId,
    required this.email,
    this.businessId,
    this.branchId,
    this.message = '',
    this.status = PasswordResetStatus.pending,
    this.resolvedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String userId;
  String email;
  String? businessId;
  String? branchId;
  String message;
  PasswordResetStatus status;
  String? resolvedBy;
  DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'email': email,
        'businessId': businessId,
        'branchId': branchId,
        'message': message,
        'status': status.name,
        'resolvedBy': resolvedBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PasswordResetRequest.fromJson(Map<String, dynamic> json) {
    return PasswordResetRequest(
      id: _s(json['id']),
      userId: _s(json['userId']),
      email: _s(json['email']),
      businessId: json['businessId']?.toString(),
      branchId: json['branchId']?.toString(),
      message: _s(json['message']),
      status: _enumFrom(
        PasswordResetStatus.values,
        json['status']?.toString(),
        PasswordResetStatus.pending,
      ),
      resolvedBy: json['resolvedBy']?.toString(),
      createdAt: _dt(json['createdAt']) ?? DateTime.now(),
      updatedAt: _dt(json['updatedAt']) ?? DateTime.now(),
    );
  }
}

class PlatformSettings {
  PlatformSettings({
    this.secretCode = 'STAFFPRO-2026',
    this.geofenceRadius = 200,
    this.blockOutsideGeofence = false,
    this.allowManagerCategories = false,
  });

  String secretCode;
  double geofenceRadius;
  bool blockOutsideGeofence;
  bool allowManagerCategories;

  Map<String, dynamic> toJson() => {
        'secretCode': secretCode,
        'geofenceRadius': geofenceRadius,
        'blockOutsideGeofence': blockOutsideGeofence,
        'allowManagerCategories': allowManagerCategories,
      };

  factory PlatformSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PlatformSettings();
    return PlatformSettings(
      secretCode: _s(json['secretCode'], 'STAFFPRO-2026'),
      geofenceRadius: _d(json['geofenceRadius']) ?? 200,
      blockOutsideGeofence: _b(json['blockOutsideGeofence']),
      allowManagerCategories: _b(json['allowManagerCategories']),
    );
  }
}
