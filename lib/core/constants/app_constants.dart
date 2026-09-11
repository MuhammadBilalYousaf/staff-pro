class AppConstants {
  AppConstants._();

  static const appName = 'StaffPro';
  static const tagline = 'Manage People. Grow Business.';
  static const defaultSecretCode = 'STAFFPRO-2026';
  static const defaultGeofenceRadiusMeters = 200.0;
  static const defaultGracePeriodMinutes = 15;
  static const defaultShiftStart = '09:00';
  static const defaultShiftEnd = '18:00';
  static const currencySymbol = 'Rs';
  static const rememberMeKey = 'staffpro.remember_email';
  static const sessionUserKey = 'staffpro.session_user';
  static const selectedBranchKey = 'staffpro.selected_branch';

  static const saleCategories = [
    'Retail',
    'Services',
    'Products',
    'Other',
  ];

  static const paymentMethods = [
    'Cash',
    'Card',
    'Bank Transfer',
    'Other',
  ];

  static const defaultExpenseCategories = [
    'Utilities',
    'Supplies',
    'Maintenance',
    'Transport',
    'Food',
    'Other',
  ];

  static const employeePositions = [
    'Sales Executive',
    'Cashier',
    'Store Associate',
    'Technician',
    'Support',
    'Other',
  ];
}
