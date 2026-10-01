import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart';

import '../features/workout/data/api_workout_gateway.dart';
import '../features/workout/domain/workout_gateway.dart';
import '../features/workout/data/preview_workout_gateway.dart';
import '../features/workout/presentation/workout_home.dart';

class MoveUpApp extends StatefulWidget {
  const MoveUpApp({super.key, this.gateway});
  final WorkoutGateway? gateway;
  @override
  State<MoveUpApp> createState() => _MoveUpAppState();
}

class _MoveUpAppState extends State<MoveUpApp> {
  late final WorkoutGateway gateway = widget.gateway ?? _defaultGateway();
  WorkoutGateway _defaultGateway() {
    if (const bool.fromEnvironment('USE_PREVIEW')) {
      return PreviewWorkoutGateway();
    }
    const configured = String.fromEnvironment('API_BASE_URL');
    final defaultUrl =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:5013'
        : 'http://localhost:5013';
    return ApiWorkoutGateway(
      baseUrl: configured.isEmpty ? defaultUrl : configured,
    );
  }

  @override
  void dispose() {
    if (widget.gateway == null && gateway is ApiWorkoutGateway) {
      (gateway as ApiWorkoutGateway).close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MoveUp',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff236b50)),
      scaffoldBackgroundColor: const Color(0xfff6f7f3),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xfff6f7f3)),
    ),
    home: WorkoutHome(gateway: gateway),
  );
}
