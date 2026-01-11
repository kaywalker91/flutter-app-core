/// DI (Dependency Injection) Container for managing service instances.
///
/// This container supports:
/// - Singleton registration (shared instances)
/// - Factory registration (new instance per request)
/// - Lazy initialization
/// - Named instances for multiple implementations of the same type
library;

/// Factory function type for creating instances.
typedef FactoryFunc<T> = T Function(DIContainer container);

/// Lifecycle type for registered dependencies.
enum Lifecycle {
  /// Single instance shared across all requests.
  singleton,

  /// New instance created for each request.
  factory,

  /// Lazy singleton - created on first access.
  lazySingleton,
}

/// Exception thrown when a dependency is not found.
class DependencyNotFoundError implements Exception {
  final Type type;
  final String? name;

  const DependencyNotFoundError(this.type, [this.name]);

  @override
  String toString() {
    final nameInfo = name != null ? ' with name "$name"' : '';
    return 'DependencyNotFoundError: No dependency registered for type $type$nameInfo';
  }
}

/// Exception thrown when trying to register a duplicate dependency.
class DuplicateDependencyError implements Exception {
  final Type type;
  final String? name;

  const DuplicateDependencyError(this.type, [this.name]);

  @override
  String toString() {
    final nameInfo = name != null ? ' with name "$name"' : '';
    return 'DuplicateDependencyError: Dependency already registered for type $type$nameInfo';
  }
}

/// Internal registration entry.
class _Registration<T> {
  final FactoryFunc<T> factory;
  final Lifecycle lifecycle;
  T? _instance;

  _Registration({
    required this.factory,
    required this.lifecycle,
  });

  T resolve(DIContainer container) {
    switch (lifecycle) {
      case Lifecycle.singleton:
      case Lifecycle.lazySingleton:
        return _instance ??= factory(container);
      case Lifecycle.factory:
        return factory(container);
    }
  }

  void reset() {
    _instance = null;
  }
}

/// Dependency Injection Container.
///
/// Example usage:
/// ```dart
/// final container = DIContainer();
///
/// // Register a singleton
/// container.registerSingleton<ApiService>(ApiServiceImpl());
///
/// // Register a factory
/// container.registerFactory<Logger>((c) => Logger(c.get<ApiService>()));
///
/// // Register a lazy singleton
/// container.registerLazySingleton<Database>((c) => Database());
///
/// // Resolve dependencies
/// final api = container.get<ApiService>();
/// final logger = container.get<Logger>();
/// ```
class DIContainer {
  final Map<String, _Registration<dynamic>> _registrations = {};

  /// Generates a unique key for type + optional name.
  String _key<T>([String? name]) => '${T.toString()}${name ?? ''}';

  /// Registers a singleton instance (already created).
  ///
  /// [instance] - The pre-created instance to register.
  /// [name] - Optional name for named registration.
  void registerSingleton<T extends Object>(
    T instance, {
    String? name,
    bool allowOverride = false,
  }) {
    final key = _key<T>(name);
    if (!allowOverride && _registrations.containsKey(key)) {
      throw DuplicateDependencyError(T, name);
    }
    _registrations[key] = _Registration<T>(
      factory: (_) => instance,
      lifecycle: Lifecycle.singleton,
    ).._instance = instance;
  }

  /// Registers a lazy singleton (created on first access).
  ///
  /// [factory] - Factory function to create the instance.
  /// [name] - Optional name for named registration.
  void registerLazySingleton<T extends Object>(
    FactoryFunc<T> factory, {
    String? name,
    bool allowOverride = false,
  }) {
    final key = _key<T>(name);
    if (!allowOverride && _registrations.containsKey(key)) {
      throw DuplicateDependencyError(T, name);
    }
    _registrations[key] = _Registration<T>(
      factory: factory,
      lifecycle: Lifecycle.lazySingleton,
    );
  }

  /// Registers a factory (new instance per request).
  ///
  /// [factory] - Factory function to create instances.
  /// [name] - Optional name for named registration.
  void registerFactory<T extends Object>(
    FactoryFunc<T> factory, {
    String? name,
    bool allowOverride = false,
  }) {
    final key = _key<T>(name);
    if (!allowOverride && _registrations.containsKey(key)) {
      throw DuplicateDependencyError(T, name);
    }
    _registrations[key] = _Registration<T>(
      factory: factory,
      lifecycle: Lifecycle.factory,
    );
  }

  /// Resolves a dependency by type.
  ///
  /// Throws [DependencyNotFoundError] if not registered.
  T get<T extends Object>({String? name}) {
    final key = _key<T>(name);
    final registration = _registrations[key];
    if (registration == null) {
      throw DependencyNotFoundError(T, name);
    }
    return registration.resolve(this) as T;
  }

  /// Tries to resolve a dependency, returns null if not found.
  T? tryGet<T extends Object>({String? name}) {
    try {
      return get<T>(name: name);
    } on DependencyNotFoundError {
      return null;
    }
  }

  /// Checks if a dependency is registered.
  bool isRegistered<T extends Object>({String? name}) {
    return _registrations.containsKey(_key<T>(name));
  }

  /// Unregisters a dependency.
  ///
  /// Returns true if the dependency was found and removed.
  bool unregister<T extends Object>({String? name}) {
    final key = _key<T>(name);
    return _registrations.remove(key) != null;
  }

  /// Resets all lazy singletons (forces re-creation on next access).
  void resetLazySingletons() {
    for (final reg in _registrations.values) {
      if (reg.lifecycle == Lifecycle.lazySingleton) {
        reg.reset();
      }
    }
  }

  /// Clears all registrations.
  void reset() {
    _registrations.clear();
  }

  /// Returns the count of registered dependencies (for testing/debugging).
  int get registrationCount => _registrations.length;
}
