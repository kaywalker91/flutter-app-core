# app_core

**Flutter 앱의 핵심 인프라 모듈** | *Core Infrastructure Module for Flutter Apps*

[![Dart](https://img.shields.io/badge/Dart-3.10+-blue.svg)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-1.17+-blue.svg)](https://flutter.dev)

---

## 📋 목차 | Table of Contents

- [개요 | Overview](#개요--overview)
- [설치 | Installation](#설치--installation)
- [주요 기능 | Features](#주요-기능--features)
- [사용법 | Usage](#사용법--usage)
  - [Bootstrap](#1-bootstrap-앱-초기화)
  - [DI Container](#2-di-container-의존성-주입)
  - [EnvLoader](#3-envloader-환경-설정)
  - [Result & Either](#4-result--either-함수형-타입)
  - [AppError](#5-apperror-에러-처리)
- [전체 예제 | Complete Example](#전체-예제--complete-example)
- [테스트 | Testing](#테스트--testing)
- [API 레퍼런스 | API Reference](#api-레퍼런스--api-reference)

---

## 개요 | Overview

`app_core`는 Flutter 앱 개발에 필요한 핵심 인프라를 제공하는 모듈입니다. 
의존성 주입(DI), 환경 설정 관리, 함수형 에러 처리 패턴을 통해 
클린 아키텍처 구현을 지원합니다.

*`app_core` provides essential infrastructure for Flutter app development, 
including Dependency Injection, Environment Configuration, and Functional Error Handling patterns 
to support Clean Architecture implementation.*

### 아키텍처 위치 | Architecture Position

```
┌─────────────────────────────────────────┐
│            Main Application             │
│    (UI, Features, Business Logic)       │
├─────────────────────────────────────────┤
│              app_core                   │  ◀── 이 모듈
│  • Bootstrap    • DI Container          │
│  • EnvLoader    • Common Types/Errors   │
└─────────────────────────────────────────┘
```

---

## 설치 | Installation

### pubspec.yaml

```yaml
dependencies:
  app_core:
    path: ../app_core  # 로컬 경로 | local path
```

### 임포트 | Import

```dart
import 'package:app_core/app_core.dart';
```

---

## 주요 기능 | Features

| 기능 | 설명 | Description |
|------|------|-------------|
| **Bootstrap** | 앱 초기화 시퀀스 관리 | App initialization sequence management |
| **DI Container** | 의존성 주입 컨테이너 | Dependency Injection container |
| **EnvLoader** | 환경별 설정 로드 | Environment-specific configuration loader |
| **Result<T>** | 성공/실패 반환 래퍼 | Success/Failure return wrapper |
| **Either<L,R>** | 이중 타입 반환 | Dual-type return |
| **AppError** | 통합 에러 처리 | Unified error handling |

---

## 사용법 | Usage

### 1. Bootstrap (앱 초기화)

앱 시작 시 필요한 초기화 작업을 순차적으로 실행합니다.

*Executes required initialization tasks sequentially at app startup.*

#### 기본 사용법 | Basic Usage

```dart
import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final result = await bootstrap(
    container: DIContainer(),
    flavor: 'dev',  // 'dev' | 'staging' | 'prod'
    hooks: [
      _registerServices,
      _initializeFirebase,
      _loadUserPreferences,
    ],
  );
  
  runApp(MyApp(container: result.container));
}

// 초기화 훅 예시 | Init hook example
Future<void> _registerServices(DIContainer container, EnvLoader env) async {
  container.registerLazySingleton<ApiService>(
    (c) => ApiServiceImpl(baseUrl: env.getString('API_URL')),
  );
}
```

#### 에러 처리 포함 | With Error Handling

```dart
final result = await bootstrap(
  container: DIContainer(),
  flavor: 'prod',
  hooks: [initializeApp],
  envOverrides: {'API_URL': 'https://api.example.com'},  // 환경 변수 오버라이드
  onError: (error) {
    // 초기화 실패 시 처리 | Handle initialization failure
    print('Bootstrap failed at ${error.phase}: ${error.cause}');
  },
);
```

#### 앱 종료 시 정리 | Cleanup on App Exit

```dart
await shutdown(
  container: container,
  hooks: [
    (c) async => await c.get<DatabaseService>().close(),
    (c) async => await c.get<AnalyticsService>().flush(),
  ],
);
```

---

### 2. DI Container (의존성 주입)

서비스, 레포지토리 등의 인스턴스를 중앙에서 관리합니다.

*Centrally manages instances of services, repositories, etc.*

#### 등록 방법 | Registration Methods

```dart
final container = DIContainer();

// 1️⃣ 싱글톤 (이미 생성된 인스턴스)
// Singleton (pre-created instance)
container.registerSingleton<Logger>(ConsoleLogger());

// 2️⃣ 레이지 싱글톤 (첫 접근 시 생성, 이후 동일 인스턴스)
// Lazy Singleton (created on first access, same instance thereafter)
container.registerLazySingleton<DatabaseService>(
  (c) => SQLiteDatabase(logger: c.get<Logger>()),
);

// 3️⃣ 팩토리 (매번 새 인스턴스 생성)
// Factory (new instance on each request)
container.registerFactory<HttpClient>(
  (c) => HttpClient(timeout: Duration(seconds: 30)),
);
```

#### 조회 방법 | Resolution Methods

```dart
// 기본 조회 (없으면 예외 발생)
// Basic resolution (throws if not found)
final logger = container.get<Logger>();

// 안전한 조회 (없으면 null 반환)
// Safe resolution (returns null if not found)
final analytics = container.tryGet<AnalyticsService>();

// 등록 여부 확인 | Check if registered
if (container.isRegistered<CacheService>()) {
  // ...
}
```

#### 네이밍된 인스턴스 | Named Instances

같은 타입의 여러 인스턴스를 구분하여 등록할 수 있습니다.

*Register multiple instances of the same type with different names.*

```dart
// 같은 타입, 다른 구현체 등록
container.registerSingleton<ApiService>(
  ProductionApi(), 
  name: 'production',
);
container.registerSingleton<ApiService>(
  MockApi(), 
  name: 'mock',
);

// 이름으로 조회
final prodApi = container.get<ApiService>(name: 'production');
final mockApi = container.get<ApiService>(name: 'mock');
```

#### 오버라이드 및 제거 | Override and Removal

```dart
// 기존 등록 덮어쓰기 (테스트용)
container.registerSingleton<ApiService>(
  MockApiService(), 
  allowOverride: true,
);

// 특정 의존성 제거 | Remove specific dependency
container.unregister<CacheService>();

// 레이지 싱글톤 리셋 (재생성 유도)
container.resetLazySingletons();

// 모든 등록 제거 | Clear all registrations
container.reset();
```

---

### 3. EnvLoader (환경 설정)

환경별(dev, staging, prod) 설정을 타입 안전하게 관리합니다.

*Manage environment-specific (dev, staging, prod) configurations with type safety.*

#### 환경 로드 | Load Environment

```dart
final env = await EnvLoader.load(
  flavor: 'dev',
  overrides: {'DEBUG': 'true'},  // 선택적 오버라이드
);
```

#### 값 조회 | Value Access

```dart
// 문자열 | String
final apiUrl = env.getString('API_URL', defaultValue: 'https://api.dev.com');

// 정수 | Integer
final port = env.getInt('PORT', defaultValue: 8080);

// 실수 | Double
final timeout = env.getDouble('TIMEOUT', defaultValue: 30.0);

// 불리언 (true, 1, yes, on 인식)
// Boolean (recognizes true, 1, yes, on)
final debug = env.getBool('DEBUG', defaultValue: false);

// 문자열 리스트 (쉼표 구분)
// String list (comma-separated)
final hosts = env.getStringList('ALLOWED_HOSTS', defaultValue: []);
// 예: 'host1,host2,host3' → ['host1', 'host2', 'host3']

// 직접 접근 (null 가능) | Direct access (nullable)
final customValue = env['CUSTOM_KEY'];
```

#### 환경 확인 | Environment Check

```dart
if (env.isDev) {
  // 개발 환경 전용 로직
}

if (env.isProd) {
  // 프로덕션 환경 전용 로직
}

if (env.isDebug) {  // dev 또는 staging
  // 디버그 모드 로직
}

print('현재 환경: ${env.flavor.name}');  // 'dev', 'staging', 'prod'
```

#### 테스트용 환경 | For Testing

```dart
final testEnv = EnvLoader.forTesting(
  config: {
    'API_URL': 'https://test.api.com',
    'MOCK_ENABLED': 'true',
  },
  flavor: AppFlavor.dev,
);
```

---

### 4. Result & Either (함수형 타입)

명시적인 성공/실패 처리로 예외 기반 코드를 대체합니다.

*Replace exception-based code with explicit success/failure handling.*

#### Result<T> 사용법 | Result<T> Usage

```dart
// 함수 정의 | Function definition
Result<User> fetchUser(int id) {
  try {
    final user = api.getUser(id);
    return Result.ok(user);
  } catch (e) {
    return Result.err(NetworkError('사용자 조회 실패'));
  }
}

// 사용 예시 | Usage example
final result = fetchUser(123);

// 방법 1: isOk/isErr 체크
if (result.isOk) {
  print('사용자: ${result.value.name}');
} else {
  print('에러: ${result.error?.message}');
}

// 방법 2: fold 사용 (권장)
final message = result.fold(
  onOk: (user) => '환영합니다, ${user.name}님!',
  onErr: (error) => '오류: ${error.message}',
);

// 방법 3: getOrElse로 기본값 사용
final user = result.getOrElse(User.guest());
```

#### Result 체이닝 | Result Chaining

```dart
final result = await fetchUser(123)
    .map((user) => user.profile)           // User → Profile
    .flatMap((profile) => validateProfile(profile))  // Profile → Result<ValidProfile>
    .mapAsync((valid) => saveProfile(valid));        // 비동기 변환
```

#### Either<L, R> 사용법 | Either<L, R> Usage

`Left`는 실패, `Right`는 성공을 나타내는 컨벤션입니다.

*Convention: Left represents failure, Right represents success.*

```dart
Either<String, int> parseNumber(String input) {
  final number = int.tryParse(input);
  if (number != null) {
    return Either.right(number);
  }
  return Either.left('유효하지 않은 숫자 형식');
}

// 사용
final result = parseNumber('42');
final value = result.fold(
  onLeft: (error) => -1,
  onRight: (number) => number,
);
```

#### VoidResult (부수 효과 전용) | VoidResult (Side-effect Only)

반환 값이 없는 작업에 사용합니다.

*Use for operations with no return value.*

```dart
VoidResult deleteUser(int id) {
  try {
    api.delete(id);
    return VoidResultExtension.ok();
  } catch (e) {
    return VoidResultExtension.err(UnknownError(e.toString()));
  }
}
```

---

### 5. AppError (에러 처리)

계층화된 에러 클래스로 일관된 에러 처리를 지원합니다.

*Hierarchical error classes for consistent error handling.*

#### 에러 계층 | Error Hierarchy

```
AppError (추상 클래스)
├── UnknownError      # 알 수 없는 에러
├── NetworkError      # 네트워크 관련 (HTTP 상태 코드 포함)
├── ValidationError   # 검증 실패 (필드명 포함)
└── StorageError      # 저장소 관련
```

#### 에러 생성 | Creating Errors

```dart
// 기본 에러 | Basic error
const error = UnknownError('예상치 못한 오류 발생');

// 에러 코드 포함 | With error code
const authError = UnknownError(
  '인증 토큰이 만료되었습니다',
  code: 'AUTH_001',
);

// 원인 예외 체이닝 | Cause chaining
try {
  await api.fetch();
} catch (e, st) {
  throw UnknownError.fromException(e, st);
}

// 네트워크 에러 (HTTP 상태 코드)
const networkError = NetworkError(
  '서버 연결 실패',
  statusCode: 500,
  code: 'NET_001',
);

// 검증 에러 (필드명)
const validationError = ValidationError(
  '이메일 형식이 올바르지 않습니다',
  field: 'email',
  code: 'VAL_001',
);
```

#### 에러 처리 | Error Handling

```dart
try {
  await performAction();
} on NetworkError catch (e) {
  if (e.statusCode == 401) {
    // 인증 만료 처리
  } else if (e.statusCode == 500) {
    // 서버 에러 처리
  }
} on ValidationError catch (e) {
  showFieldError(e.field, e.message);
} on AppError catch (e) {
  // 기타 앱 에러
  logError(e.code, e.message, e.stackTrace);
}
```

---

## 전체 예제 | Complete Example

```dart
import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

// 서비스 인터페이스 | Service Interface
abstract class UserRepository {
  Future<Result<User>> getUser(int id);
}

// 서비스 구현체 | Service Implementation
class UserRepositoryImpl implements UserRepository {
  final String baseUrl;
  
  UserRepositoryImpl({required this.baseUrl});
  
  @override
  Future<Result<User>> getUser(int id) async {
    try {
      // API 호출 로직
      return Result.ok(User(id: id, name: 'John'));
    } catch (e) {
      return Result.err(NetworkError('사용자 조회 실패', statusCode: 500));
    }
  }
}

// 앱 진입점 | App Entry Point
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final result = await bootstrap(
    container: DIContainer(),
    flavor: const String.fromEnvironment('FLAVOR', defaultValue: 'dev'),
    hooks: [
      // 서비스 등록 | Register services
      (container, env) async {
        container.registerLazySingleton<UserRepository>(
          (c) => UserRepositoryImpl(
            baseUrl: env.getString('API_URL', defaultValue: 'https://api.dev.com'),
          ),
        );
      },
    ],
  );
  
  runApp(MyApp(container: result.container));
}

// 앱 위젯 | App Widget
class MyApp extends StatelessWidget {
  final DIContainer container;
  
  const MyApp({super.key, required this.container});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: UserPage(
        repository: container.get<UserRepository>(),
      ),
    );
  }
}

// 사용자 페이지 | User Page
class UserPage extends StatelessWidget {
  final UserRepository repository;
  
  const UserPage({super.key, required this.repository});
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Result<User>>(
      future: repository.getUser(1),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }
        
        return snapshot.data!.fold(
          onOk: (user) => Text('안녕하세요, ${user.name}님!'),
          onErr: (error) => Text('에러: ${error.message}'),
        );
      },
    );
  }
}

// 도메인 모델 | Domain Model
class User {
  final int id;
  final String name;
  
  User({required this.id, required this.name});
}
```

---

## 테스트 | Testing

### 테스트 실행 | Running Tests

```bash
flutter test
```

### DI 컨테이너 테스트 | DI Container Testing

```dart
void main() {
  late DIContainer container;
  
  setUp(() {
    container = DIContainer();
  });
  
  tearDown(() {
    container.reset();
  });
  
  test('서비스 모킹 테스트', () {
    // Mock 서비스 등록
    container.registerSingleton<UserRepository>(MockUserRepository());
    
    final repo = container.get<UserRepository>();
    expect(repo, isA<MockUserRepository>());
  });
}
```

### EnvLoader 테스트 | EnvLoader Testing

```dart
test('환경 설정 테스트', () {
  final env = EnvLoader.forTesting(
    config: {'API_URL': 'https://test.com'},
    flavor: AppFlavor.dev,
  );
  
  expect(env.getString('API_URL'), equals('https://test.com'));
  expect(env.isDev, isTrue);
});
```

---

## API 레퍼런스 | API Reference

### DIContainer

| 메서드 | 설명 |
|--------|------|
| `registerSingleton<T>(T instance, {String? name, bool allowOverride})` | 싱글톤 등록 |
| `registerLazySingleton<T>(FactoryFunc<T> factory, {String? name, bool allowOverride})` | 레이지 싱글톤 등록 |
| `registerFactory<T>(FactoryFunc<T> factory, {String? name, bool allowOverride})` | 팩토리 등록 |
| `get<T>({String? name})` | 의존성 조회 (예외 발생 가능) |
| `tryGet<T>({String? name})` | 의존성 조회 (null 반환) |
| `isRegistered<T>({String? name})` | 등록 여부 확인 |
| `unregister<T>({String? name})` | 등록 해제 |
| `resetLazySingletons()` | 레이지 싱글톤 리셋 |
| `reset()` | 모든 등록 제거 |

### EnvLoader

| 메서드/프로퍼티 | 설명 |
|----------------|------|
| `load({String flavor, Map<String, String>? overrides})` | 환경 로드 (static) |
| `forTesting({required Map<String, String> config, AppFlavor flavor})` | 테스트용 생성 (factory) |
| `getString(String key, {String? defaultValue})` | 문자열 값 조회 |
| `getInt(String key, {int defaultValue})` | 정수 값 조회 |
| `getDouble(String key, {double defaultValue})` | 실수 값 조회 |
| `getBool(String key, {bool defaultValue})` | 불리언 값 조회 |
| `getStringList(String key, {List<String> defaultValue})` | 문자열 리스트 조회 |
| `isDev`, `isStaging`, `isProd`, `isDebug` | 환경 확인 프로퍼티 |

### Result<T>

| 메서드/프로퍼티 | 설명 |
|----------------|------|
| `Result.ok(T value)` | 성공 결과 생성 |
| `Result.err(AppError error)` | 실패 결과 생성 |
| `isOk`, `isErr` | 상태 확인 |
| `value` | 값 조회 (에러 시 예외) |
| `getOrElse(T defaultValue)` | 값 또는 기본값 |
| `map<R>(R Function(T) mapper)` | 값 변환 |
| `flatMap<R>(Result<R> Function(T) mapper)` | 중첩 Result 평탄화 |
| `fold({onOk, onErr})` | 분기 처리 |

### AppError

| 클래스 | 추가 필드 | 설명 |
|--------|----------|------|
| `AppError` | `message`, `code`, `cause`, `stackTrace` | 기본 에러 (추상) |
| `UnknownError` | - | 알 수 없는 에러 |
| `NetworkError` | `statusCode` | 네트워크 에러 |
| `ValidationError` | `field` | 검증 에러 |
| `StorageError` | - | 저장소 에러 |

---

## 라이선스 | License

MIT License

---

## 기여 | Contributing

이슈와 PR은 언제나 환영합니다! 🎉

*Issues and PRs are always welcome!*
