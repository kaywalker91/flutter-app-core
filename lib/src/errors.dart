/// AppError base class: all module errors should extend this.
///
/// Provides a consistent error interface across the application with:
/// - Human-readable message
/// - Optional error code for programmatic handling
/// - Optional stack trace for debugging
/// - Optional cause for error chaining
abstract class AppError implements Exception {
  /// Human-readable error message.
  final String message;

  /// Optional error code for programmatic handling (e.g., 'AUTH_001').
  final String? code;

  /// Optional original exception that caused this error.
  final Object? cause;

  /// Optional stack trace for debugging.
  final StackTrace? stackTrace;

  const AppError(
    this.message, {
    this.code,
    this.cause,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType');
    if (code != null) {
      buffer.write(' [$code]');
    }
    buffer.write(': $message');
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }

  /// Creates a copy with additional context.
  AppError copyWith({
    String? message,
    String? code,
    Object? cause,
    StackTrace? stackTrace,
  });
}

/// Generic unknown error for unexpected exceptions.
class UnknownError extends AppError {
  const UnknownError(
    super.message, {
    super.code,
    super.cause,
    super.stackTrace,
  });

  /// Creates an UnknownError from any exception.
  factory UnknownError.fromException(Object exception, [StackTrace? trace]) {
    return UnknownError(
      exception.toString(),
      cause: exception,
      stackTrace: trace,
    );
  }

  @override
  UnknownError copyWith({
    String? message,
    String? code,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return UnknownError(
      message ?? this.message,
      code: code ?? this.code,
      cause: cause ?? this.cause,
      stackTrace: stackTrace ?? this.stackTrace,
    );
  }
}

/// Network-related errors.
class NetworkError extends AppError {
  /// HTTP status code if applicable.
  final int? statusCode;

  const NetworkError(
    super.message, {
    this.statusCode,
    super.code,
    super.cause,
    super.stackTrace,
  });

  @override
  NetworkError copyWith({
    String? message,
    String? code,
    Object? cause,
    StackTrace? stackTrace,
    int? statusCode,
  }) {
    return NetworkError(
      message ?? this.message,
      statusCode: statusCode ?? this.statusCode,
      code: code ?? this.code,
      cause: cause ?? this.cause,
      stackTrace: stackTrace ?? this.stackTrace,
    );
  }

  @override
  String toString() {
    final base = super.toString();
    if (statusCode != null) {
      return '$base (HTTP $statusCode)';
    }
    return base;
  }
}

/// Validation-related errors.
class ValidationError extends AppError {
  /// Field that failed validation (if applicable).
  final String? field;

  const ValidationError(
    super.message, {
    this.field,
    super.code,
    super.cause,
    super.stackTrace,
  });

  @override
  ValidationError copyWith({
    String? message,
    String? code,
    Object? cause,
    StackTrace? stackTrace,
    String? field,
  }) {
    return ValidationError(
      message ?? this.message,
      field: field ?? this.field,
      code: code ?? this.code,
      cause: cause ?? this.cause,
      stackTrace: stackTrace ?? this.stackTrace,
    );
  }

  @override
  String toString() {
    final base = super.toString();
    if (field != null) {
      return '$base (field: $field)';
    }
    return base;
  }
}

/// Storage/persistence-related errors.
class StorageError extends AppError {
  const StorageError(
    super.message, {
    super.code,
    super.cause,
    super.stackTrace,
  });

  @override
  StorageError copyWith({
    String? message,
    String? code,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return StorageError(
      message ?? this.message,
      code: code ?? this.code,
      cause: cause ?? this.cause,
      stackTrace: stackTrace ?? this.stackTrace,
    );
  }
}
