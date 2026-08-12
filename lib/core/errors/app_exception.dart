class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class AppAuthException extends AppException {
  const AppAuthException(super.message, {super.code});
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'Network error. Please try again.']);
}

class PermissionException extends AppException {
  const PermissionException([super.message = 'You do not have permission for this action.']);
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}

String mapErrorToMessage(Object error) {
  if (error is AppException) return error.message;
  final text = error.toString();
  if (text.contains('Invalid login credentials')) {
    return 'Incorrect email or password.';
  }
  if (text.contains('Email not confirmed')) {
    return 'Please confirm your email before signing in.';
  }
  if (text.contains('User already registered')) {
    return 'An account with this email already exists.';
  }
  if (text.contains('JWT') || text.contains('not authenticated')) {
    return 'Please sign in again.';
  }
  if (text.contains('SocketException') || text.contains('Failed host lookup')) {
    return 'Unable to connect. Check your internet connection.';
  }
  return 'Something went wrong. Please try again.';
}
