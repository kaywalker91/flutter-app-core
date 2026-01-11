import 'package:flutter_test/flutter_test.dart';
import 'package:app_core/app_core.dart';

void main() {
  group('DIContainer', () {
    late DIContainer container;

    setUp(() {
      container = DIContainer();
    });

    tearDown(() {
      container.reset();
    });

    test('registerSingleton stores and retrieves instance', () {
      container.registerSingleton<String>('test-value');
      expect(container.get<String>(), equals('test-value'));
    });

    test('registerSingleton returns same instance', () {
      final list = <int>[1, 2, 3];
      container.registerSingleton<List<int>>(list);

      final retrieved1 = container.get<List<int>>();
      final retrieved2 = container.get<List<int>>();

      expect(identical(retrieved1, retrieved2), isTrue);
    });

    test('registerFactory creates new instances', () {
      container.registerFactory<List<int>>((c) => <int>[]);

      final list1 = container.get<List<int>>();
      final list2 = container.get<List<int>>();

      expect(identical(list1, list2), isFalse);
    });

    test('registerLazySingleton creates instance on first access', () {
      var creationCount = 0;
      container.registerLazySingleton<String>((c) {
        creationCount++;
        return 'lazy-value';
      });

      expect(creationCount, equals(0));

      final value1 = container.get<String>();
      expect(creationCount, equals(1));
      expect(value1, equals('lazy-value'));

      final value2 = container.get<String>();
      expect(creationCount, equals(1));
      expect(identical(value1, value2), isTrue);
    });

    test('named registration allows multiple instances of same type', () {
      container.registerSingleton<String>('default', name: 'first');
      container.registerSingleton<String>('other', name: 'second');

      expect(container.get<String>(name: 'first'), equals('default'));
      expect(container.get<String>(name: 'second'), equals('other'));
    });

    test('get throws DependencyNotFoundError when not registered', () {
      expect(
        () => container.get<String>(),
        throwsA(isA<DependencyNotFoundError>()),
      );
    });

    test('tryGet returns null when not registered', () {
      expect(container.tryGet<String>(), isNull);
    });

    test('isRegistered returns correct status', () {
      expect(container.isRegistered<String>(), isFalse);

      container.registerSingleton<String>('test');

      expect(container.isRegistered<String>(), isTrue);
    });

    test('unregister removes dependency', () {
      container.registerSingleton<String>('test');
      expect(container.isRegistered<String>(), isTrue);

      final removed = container.unregister<String>();
      expect(removed, isTrue);
      expect(container.isRegistered<String>(), isFalse);
    });

    test('duplicate registration throws DuplicateDependencyError', () {
      container.registerSingleton<String>('first');

      expect(
        () => container.registerSingleton<String>('second'),
        throwsA(isA<DuplicateDependencyError>()),
      );
    });

    test('allowOverride permits duplicate registration', () {
      container.registerSingleton<String>('first');
      container.registerSingleton<String>('second', allowOverride: true);

      expect(container.get<String>(), equals('second'));
    });
  });

  group('Result', () {
    test('Result.ok contains value', () {
      final result = Result.ok(42);

      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.value, equals(42));
    });

    test('Result.err contains error', () {
      final result = Result<int>.err(const UnknownError('test error'));

      expect(result.isOk, isFalse);
      expect(result.isErr, isTrue);
      expect(result.error?.message, equals('test error'));
    });

    test('Result.getOrElse returns default on error', () {
      final okResult = Result.ok(10);
      final errResult = Result<int>.err(const UnknownError('error'));

      expect(okResult.getOrElse(0), equals(10));
      expect(errResult.getOrElse(0), equals(0));
    });

    test('Result.map transforms value', () {
      final result = Result.ok(5);
      final mapped = result.map((v) => v * 2);

      expect(mapped.value, equals(10));
    });

    test('Result.map preserves error', () {
      final result = Result<int>.err(const UnknownError('error'));
      final mapped = result.map((v) => v * 2);

      expect(mapped.isErr, isTrue);
    });

    test('Result.fold handles both cases', () {
      final okResult = Result.ok(5);
      final errResult = Result<int>.err(const UnknownError('error'));

      final okValue = okResult.fold(
        onOk: (v) => 'value: $v',
        onErr: (e) => 'error: ${e.message}',
      );
      final errValue = errResult.fold(
        onOk: (v) => 'value: $v',
        onErr: (e) => 'error: ${e.message}',
      );

      expect(okValue, equals('value: 5'));
      expect(errValue, equals('error: error'));
    });
  });

  group('Either', () {
    test('Either.left contains left value', () {
      final either = Either<String, int>.left('error');

      expect(either.isLeft, isTrue);
      expect(either.isRight, isFalse);
      expect(either.left, equals('error'));
    });

    test('Either.right contains right value', () {
      final either = Either<String, int>.right(42);

      expect(either.isLeft, isFalse);
      expect(either.isRight, isTrue);
      expect(either.right, equals(42));
    });

    test('Either.map transforms right value', () {
      final either = Either<String, int>.right(5);
      final mapped = either.map((v) => v * 2);

      expect(mapped.right, equals(10));
    });

    test('Either.mapLeft transforms left value', () {
      final either = Either<String, int>.left('error');
      final mapped = either.mapLeft((v) => v.toUpperCase());

      expect(mapped.left, equals('ERROR'));
    });
  });

  group('EnvLoader', () {
    test('forTesting creates loader with custom config', () {
      final env = EnvLoader.forTesting(
        config: {'API_URL': 'https://test.com', 'PORT': '8080'},
        flavor: AppFlavor.dev,
      );

      expect(env.getString('API_URL'), equals('https://test.com'));
      expect(env.getInt('PORT'), equals(8080));
      expect(env.isDev, isTrue);
    });

    test('getBool parses various true values', () {
      final env = EnvLoader.forTesting(
        config: {
          'TRUE_1': 'true',
          'TRUE_2': '1',
          'TRUE_3': 'yes',
          'TRUE_4': 'on',
          'FALSE_1': 'false',
          'FALSE_2': '0',
        },
      );

      expect(env.getBool('TRUE_1'), isTrue);
      expect(env.getBool('TRUE_2'), isTrue);
      expect(env.getBool('TRUE_3'), isTrue);
      expect(env.getBool('TRUE_4'), isTrue);
      expect(env.getBool('FALSE_1'), isFalse);
      expect(env.getBool('FALSE_2'), isFalse);
    });

    test('getStringList splits comma-separated values', () {
      final env = EnvLoader.forTesting(
        config: {'HOSTS': 'host1, host2, host3'},
      );

      expect(env.getStringList('HOSTS'), equals(['host1', 'host2', 'host3']));
    });
  });

  group('AppError', () {
    test('UnknownError.fromException captures cause', () {
      final original = Exception('original error');
      final error = UnknownError.fromException(original);

      expect(error.cause, equals(original));
      expect(error.message, contains('original error'));
    });

    test('NetworkError includes statusCode in toString', () {
      const error = NetworkError('Connection failed', statusCode: 500);

      expect(error.toString(), contains('500'));
    });

    test('ValidationError includes field in toString', () {
      const error = ValidationError('Invalid email', field: 'email');

      expect(error.toString(), contains('email'));
    });
  });
}
