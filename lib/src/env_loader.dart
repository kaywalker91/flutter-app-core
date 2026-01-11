import 'dart:io';

/// Supported app flavors/environments.
enum AppFlavor {
  dev,
  staging,
  prod,
}

/// Extension for AppFlavor to get string representation.
extension AppFlavorExtension on AppFlavor {
  /// Returns the flavor name as a string.
  String get name {
    switch (this) {
      case AppFlavor.dev:
        return 'dev';
      case AppFlavor.staging:
        return 'staging';
      case AppFlavor.prod:
        return 'prod';
    }
  }

  /// Parses a string to AppFlavor.
  static AppFlavor fromString(String value) {
    switch (value.toLowerCase()) {
      case 'dev':
      case 'development':
        return AppFlavor.dev;
      case 'staging':
      case 'stage':
        return AppFlavor.staging;
      case 'prod':
      case 'production':
        return AppFlavor.prod;
      default:
        return AppFlavor.dev;
    }
  }
}

/// EnvLoader loads environment and flavor-specific configuration.
///
/// This class provides a centralized way to access environment variables
/// and flavor-specific settings. It supports:
/// - Platform environment variables
/// - Custom configuration maps
/// - Type-safe access with defaults
///
/// Example usage:
/// ```dart
/// final env = await EnvLoader.load(flavor: 'dev');
///
/// // Access values with type conversion
/// final apiUrl = env.getString('API_URL', defaultValue: 'https://api.dev.example.com');
/// final timeout = env.getInt('TIMEOUT', defaultValue: 30);
/// final debug = env.getBool('DEBUG', defaultValue: true);
/// ```
class EnvLoader {
  final Map<String, String> _env;
  final AppFlavor flavor;

  EnvLoader._(this._env, this.flavor);

  /// Loads environment configuration for the specified flavor.
  ///
  /// [flavor] - The app flavor/environment (e.g., 'dev', 'prod').
  /// [overrides] - Optional map to override or add configuration values.
  static Future<EnvLoader> load({
    String flavor = 'dev',
    Map<String, String>? overrides,
  }) async {
    final appFlavor = AppFlavorExtension.fromString(flavor);

    // Start with platform environment variables
    final map = Map<String, String>.from(Platform.environment);

    // Add flavor-specific defaults
    map['FLAVOR'] = appFlavor.name;
    map['IS_DEBUG'] = (appFlavor == AppFlavor.dev).toString();

    // Apply overrides if provided
    if (overrides != null) {
      map.addAll(overrides);
    }

    // TODO: Extend to load from .env files or secure storage
    // await _loadFromEnvFile(appFlavor, map);

    return EnvLoader._(map, appFlavor);
  }

  /// Creates an EnvLoader with a custom configuration map (for testing).
  factory EnvLoader.forTesting({
    required Map<String, String> config,
    AppFlavor flavor = AppFlavor.dev,
  }) {
    return EnvLoader._(Map.from(config), flavor);
  }

  /// Gets a raw value by key, or null if not found.
  String? operator [](String key) => _env[key];

  /// Gets a string value with optional default.
  String getString(String key, {String? defaultValue}) {
    return _env[key] ?? defaultValue ?? '';
  }

  /// Gets an integer value with optional default.
  int getInt(String key, {int defaultValue = 0}) {
    final value = _env[key];
    if (value == null) return defaultValue;
    return int.tryParse(value) ?? defaultValue;
  }

  /// Gets a double value with optional default.
  double getDouble(String key, {double defaultValue = 0.0}) {
    final value = _env[key];
    if (value == null) return defaultValue;
    return double.tryParse(value) ?? defaultValue;
  }

  /// Gets a boolean value with optional default.
  ///
  /// Recognizes: 'true', '1', 'yes', 'on' as true (case-insensitive).
  bool getBool(String key, {bool defaultValue = false}) {
    final value = _env[key]?.toLowerCase();
    if (value == null) return defaultValue;
    return value == 'true' || value == '1' || value == 'yes' || value == 'on';
  }

  /// Gets a list of strings (comma-separated).
  List<String> getStringList(String key, {List<String> defaultValue = const []}) {
    final value = _env[key];
    if (value == null || value.isEmpty) return defaultValue;
    return value.split(',').map((e) => e.trim()).toList();
  }

  /// Checks if a key exists in the environment.
  bool containsKey(String key) => _env.containsKey(key);

  /// Returns true if running in development mode.
  bool get isDev => flavor == AppFlavor.dev;

  /// Returns true if running in staging mode.
  bool get isStaging => flavor == AppFlavor.staging;

  /// Returns true if running in production mode.
  bool get isProd => flavor == AppFlavor.prod;

  /// Returns true if running in debug mode (dev or staging).
  bool get isDebug => flavor != AppFlavor.prod;

  /// Returns all keys in the environment.
  Iterable<String> get keys => _env.keys;

  @override
  String toString() => 'EnvLoader(flavor: ${flavor.name}, keys: ${_env.length})';
}
