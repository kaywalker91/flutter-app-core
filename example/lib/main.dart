import 'package:app_core/app_core.dart';

Future<void> main() async {
  final container = DIContainer();

  // Example init hook that registers a value
  Future<void> registerServices(DIContainer c, EnvLoader env) async {
    c.registerSingleton<String>('example-service');
    c.registerLazySingleton<int>((container) => 42);
  }

  final result = await bootstrap(
    container: container,
    flavor: 'dev',
    hooks: [registerServices],
  );

  final svc = result.container.get<String>();
  final number = result.container.get<int>();

  // ignore: avoid_print
  print('Bootstrap complete!');
  // ignore: avoid_print
  print('Service: $svc');
  // ignore: avoid_print
  print('Number: $number');
  // ignore: avoid_print
  print('Environment: ${result.env.flavor.name}');
}
