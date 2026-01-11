import 'errors.dart';

/// Minimal Result wrapper to unify success/error return paths.
///
/// Example usage:
/// ```dart
/// Result<User> fetchUser(int id) {
///   try {
///     final user = api.getUser(id);
///     return Result.ok(user);
///   } catch (e) {
///     return Result.err(UnknownError(e.toString()));
///   }
/// }
///
/// final result = fetchUser(1);
/// if (result.isOk) {
///   print('User: ${result.value}');
/// } else {
///   print('Error: ${result.error}');
/// }
/// ```
class Result<T> {
  final T? _value;
  final AppError? error;

  const Result.ok(T this._value) : error = null;
  const Result.err(this.error) : _value = null;

  /// Returns true if this is a successful result.
  bool get isOk => error == null;

  /// Returns true if this is an error result.
  bool get isErr => error != null;

  /// Gets the value. Throws if this is an error result.
  T get value {
    if (error != null) {
      throw StateError('Cannot get value from error result: $error');
    }
    return _value as T;
  }

  /// Gets the value or returns [defaultValue] if this is an error.
  T getOrElse(T defaultValue) => isOk ? _value as T : defaultValue;

  /// Gets the value or computes a default using [orElse] if this is an error.
  T getOrElseCompute(T Function() orElse) => isOk ? _value as T : orElse();

  /// Maps the value if successful, otherwise returns the error.
  Result<R> map<R>(R Function(T value) mapper) {
    if (isOk) {
      return Result.ok(mapper(_value as T));
    }
    return Result.err(error!);
  }

  /// Maps the value if successful using an async mapper.
  Future<Result<R>> mapAsync<R>(Future<R> Function(T value) mapper) async {
    if (isOk) {
      return Result.ok(await mapper(_value as T));
    }
    return Result.err(error!);
  }

  /// Flat maps the value if successful.
  Result<R> flatMap<R>(Result<R> Function(T value) mapper) {
    if (isOk) {
      return mapper(_value as T);
    }
    return Result.err(error!);
  }

  /// Executes [onOk] if successful, [onErr] if error.
  R fold<R>({
    required R Function(T value) onOk,
    required R Function(AppError error) onErr,
  }) {
    if (isOk) {
      return onOk(_value as T);
    }
    return onErr(error!);
  }

  @override
  String toString() {
    if (isOk) {
      return 'Result.ok($_value)';
    }
    return 'Result.err($error)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Result<T> && other._value == _value && other.error == error;
  }

  @override
  int get hashCode => Object.hash(_value, error);
}

/// Simple Either type for dual-typed returns.
///
/// By convention:
/// - Left represents failure/error case
/// - Right represents success case
///
/// Example usage:
/// ```dart
/// Either<String, int> parseNumber(String input) {
///   final number = int.tryParse(input);
///   if (number != null) {
///     return Either.right(number);
///   }
///   return Either.left('Invalid number format');
/// }
/// ```
class Either<L, R> {
  final L? _left;
  final R? _right;

  const Either.left(L this._left) : _right = null;
  const Either.right(R this._right) : _left = null;

  /// Returns true if this contains a left value.
  bool get isLeft => _left != null;

  /// Returns true if this contains a right value.
  bool get isRight => _right != null;

  /// Gets the left value. Throws if this is a right.
  L get left {
    if (_left == null) {
      throw StateError('Cannot get left from right Either');
    }
    return _left;
  }

  /// Gets the right value. Throws if this is a left.
  R get right {
    if (_right == null) {
      throw StateError('Cannot get right from left Either');
    }
    return _right;
  }

  /// Gets the left value or returns [defaultValue].
  L leftOrElse(L defaultValue) => isLeft ? _left as L : defaultValue;

  /// Gets the right value or returns [defaultValue].
  R rightOrElse(R defaultValue) => isRight ? _right as R : defaultValue;

  /// Maps the right value if present.
  Either<L, R2> map<R2>(R2 Function(R value) mapper) {
    if (isRight) {
      return Either.right(mapper(_right as R));
    }
    return Either.left(_left as L);
  }

  /// Maps the left value if present.
  Either<L2, R> mapLeft<L2>(L2 Function(L value) mapper) {
    if (isLeft) {
      return Either.left(mapper(_left as L));
    }
    return Either.right(_right as R);
  }

  /// Flat maps the right value if present.
  Either<L, R2> flatMap<R2>(Either<L, R2> Function(R value) mapper) {
    if (isRight) {
      return mapper(_right as R);
    }
    return Either.left(_left as L);
  }

  /// Executes [onLeft] if left, [onRight] if right.
  T fold<T>({
    required T Function(L left) onLeft,
    required T Function(R right) onRight,
  }) {
    if (isLeft) {
      return onLeft(_left as L);
    }
    return onRight(_right as R);
  }

  @override
  String toString() {
    if (isLeft) {
      return 'Either.left($_left)';
    }
    return 'Either.right($_right)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Either<L, R> &&
        other._left == _left &&
        other._right == _right;
  }

  @override
  int get hashCode => Object.hash(_left, _right);
}

/// Unit type for void-like returns in Result/Either.
class Unit {
  const Unit._();

  /// Singleton instance.
  static const Unit value = Unit._();

  @override
  String toString() => 'Unit';
}

/// Type alias for Result with no value (side-effect only operations).
typedef VoidResult = Result<Unit>;

/// Extension for creating VoidResult easily.
extension VoidResultExtension on Unit {
  /// Creates a successful VoidResult.
  static VoidResult ok() => const Result.ok(Unit.value);

  /// Creates a failed VoidResult.
  static VoidResult err(AppError error) => Result.err(error);
}
