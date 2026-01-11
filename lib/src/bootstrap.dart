import 'dart:async';

import 'di/container.dart';
import 'env_loader.dart';

/// Init hook signature used during bootstrap.
///
/// Hooks are executed sequentially in the order they are provided.
/// Each hook receives the DI container and environment loader.
typedef InitHook = FutureOr<void> Function(DIContainer container, EnvLoader env);

/// Dispose hook signature for cleanup during shutdown.
typedef DisposeHook = FutureOr<void> Function(DIContainer container);

/// Bootstrap result containing initialized container and environment.
class BootstrapResult {
  final DIContainer container;
  final EnvLoader env;

  const BootstrapResult({
    required this.container,
    required this.env,
  });
}

/// Bootstrap error thrown when initialization fails.
class BootstrapError implements Exception {
  final String phase;
  final Object cause;
  final StackTrace? stackTrace;

  const BootstrapError({
    required this.phase,
    required this.cause,
    this.stackTrace,
  });

  @override
  String toString() => 'BootstrapError during $phase: $cause';
}

/// Bootstrap sequence: loads env, runs init hooks, and returns when complete.
///
/// This function orchestrates the application startup sequence:
/// 1. Loads environment configuration based on flavor
/// 2. Executes init hooks sequentially for dependency registration
/// 3. Returns the configured container and environment
///
/// Example usage:
/// ```dart
/// void main() async {
///   final result = await bootstrap(
///     container: DIContainer(),
///     flavor: 'dev',
///     hooks: [
///       // Register services
///       (container, env) {
///         container.registerLazySingleton<ApiService>(
///           (c) => ApiServiceImpl(baseUrl: env.getString('API_URL')),
///         );
///       },
///       // Initialize analytics
///       (container, env) async {
///         final analytics = container.get<AnalyticsService>();
///         await analytics.init();
///       },
///     ],
///   );
///
///   runApp(MyApp(container: result.container));
/// }
/// ```
///
/// [container] - The DI container to configure.
/// [flavor] - The app flavor/environment (e.g., 'dev', 'prod').
/// [hooks] - List of initialization hooks to execute.
/// [envOverrides] - Optional environment variable overrides.
/// [onError] - Optional error handler for hook failures.
Future<BootstrapResult> bootstrap({
  required DIContainer container,
  required String flavor,
  List<InitHook> hooks = const [],
  Map<String, String>? envOverrides,
  void Function(BootstrapError error)? onError,
}) async {
  EnvLoader? env;

  try {
    // Phase 1: Load environment
    env = await EnvLoader.load(
      flavor: flavor,
      overrides: envOverrides,
    );

    // Register the container and env loader in themselves for DI access
    container.registerSingleton<DIContainer>(container);
    container.registerSingleton<EnvLoader>(env);

    // Phase 2: Execute init hooks
    for (int i = 0; i < hooks.length; i++) {
      try {
        await hooks[i](container, env);
      } catch (e, st) {
        final error = BootstrapError(
          phase: 'init hook ${i + 1}/${hooks.length}',
          cause: e,
          stackTrace: st,
        );
        if (onError != null) {
          onError(error);
        } else {
          throw error;
        }
      }
    }

    return BootstrapResult(container: container, env: env);
  } catch (e, st) {
    if (e is BootstrapError) rethrow;

    final error = BootstrapError(
      phase: 'environment loading',
      cause: e,
      stackTrace: st,
    );
    if (onError != null) {
      onError(error);
      // Return partial result if error handler doesn't throw
      return BootstrapResult(
        container: container,
        env: env ?? EnvLoader.forTesting(config: {}, flavor: AppFlavor.dev),
      );
    }
    throw error;
  }
}

/// Graceful shutdown: runs dispose hooks and cleans up resources.
///
/// [container] - The DI container to dispose.
/// [hooks] - List of dispose hooks to execute (in reverse order).
Future<void> shutdown({
  required DIContainer container,
  List<DisposeHook> hooks = const [],
}) async {
  // Execute dispose hooks in reverse order (LIFO)
  for (int i = hooks.length - 1; i >= 0; i--) {
    try {
      await hooks[i](container);
    } catch (e) {
      // Log but don't throw during shutdown
      // ignore: avoid_print
      print('Warning: Dispose hook ${i + 1} failed: $e');
    }
  }

  // Clear container registrations
  container.reset();
}
