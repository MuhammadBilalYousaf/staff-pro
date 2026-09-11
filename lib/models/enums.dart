enum UserRole { superAdmin, businessAdmin, manager, employee }

enum EntityStatus { active, inactive, suspended, archived }

enum AttendanceStatus {
  present,
  absent,
  late,
  onTime,
  earlyDeparture,
  missingCheckout,
}

enum NotificationType {
  employeeCheckin,
  employeeCheckout,
  managerCheckin,
  managerCheckout,
  passwordResetRequest,
  branchTransfer,
  userCreated,
  businessCreated,
  saleAdded,
  expenseAdded,
  system,
}

enum PasswordResetStatus { pending, approved, rejected, completed }

enum AuditAction {
  create,
  update,
  deactivate,
  archive,
  login,
  logout,
  branchAssignment,
  branchTransfer,
  attendanceCorrection,
  salesModification,
  expenseModification,
  permissionChange,
  passwordRecovery,
  passwordChange,
  resetAccess,
}

String roleLabel(UserRole role) {
  switch (role) {
    case UserRole.superAdmin:
      return 'Super Admin';
    case UserRole.businessAdmin:
      return 'Business Admin';
    case UserRole.manager:
      return 'Manager';
    case UserRole.employee:
      return 'Employee';
  }
}

String statusLabel(EntityStatus status) {
  switch (status) {
    case EntityStatus.active:
      return 'Active';
    case EntityStatus.inactive:
      return 'Inactive';
    case EntityStatus.suspended:
      return 'Suspended';
    case EntityStatus.archived:
      return 'Archived';
  }
}

String attendanceLabel(AttendanceStatus status) {
  switch (status) {
    case AttendanceStatus.present:
      return 'Present';
    case AttendanceStatus.absent:
      return 'Absent';
    case AttendanceStatus.late:
      return 'Late';
    case AttendanceStatus.onTime:
      return 'On Time';
    case AttendanceStatus.earlyDeparture:
      return 'Early Leave';
    case AttendanceStatus.missingCheckout:
      return 'Missing Checkout';
  }
}
