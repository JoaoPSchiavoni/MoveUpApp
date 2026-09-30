import 'package:flutter/material.dart';

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
  late final WorkoutGateway gateway = widget.gateway ?? PreviewWorkoutGateway();
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
