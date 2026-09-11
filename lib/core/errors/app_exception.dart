class AppException implements Exception {
  AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class AuthException extends AppException {
  AuthException(super.message, {super.code});
}

class ForbiddenException extends AppException {
  ForbiddenException([super.message = 'You do not have permission for this action.']);
}

class ValidationException extends AppException {
  ValidationException(super.message);
}

class NotFoundException extends AppException {
  NotFoundException([super.message = 'Record not found.']);
}
