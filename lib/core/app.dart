import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart';

import '../features/workout/data/api_workout_gateway.dart';
import '../features/workout/domain/workout_gateway.dart';
import '../features/workout/data/preview_workout_gateway.dart';
import '../features/workout/presentation/workout_home.dart';
import '../features/session/domain/session.dart';
import '../features/session/data/api_session_gateway.dart';
import '../features/session/data/preview_session_gateway.dart';
import '../features/session/presentation/session_store.dart';
import '../features/consistency/domain/consistency.dart';
import '../features/consistency/data/api_consistency_gateway.dart';
import '../features/consistency/presentation/consistency_store.dart';

class MoveUpApp extends StatefulWidget {
  const MoveUpApp({
    super.key,
    this.gateway,
    this.sessionGateway,
    this.consistencyGateway,
  });
  final WorkoutGateway? gateway;
  final SessionGateway? sessionGateway;
  final ConsistencyGateway? consistencyGateway;
  @override
  State<MoveUpApp> createState() => _MoveUpAppState();
}

class _MoveUpAppState extends State<MoveUpApp> {
  late final WorkoutGateway gateway = widget.gateway ?? _defaultGateway();
  late final SessionGateway sessionGateway =
      widget.sessionGateway ??
      (gateway is PreviewWorkoutGateway
          ? PreviewSessionGateway()
          : ApiSessionGateway(baseUrl: _apiUrl));
  late final SessionStore sessions = SessionStore(sessionGateway);
  late final ConsistencyGateway consistencyGateway =
      widget.consistencyGateway ??
      (gateway is PreviewWorkoutGateway
          ? UnavailableConsistencyGateway()
          : ApiConsistencyGateway(baseUrl: _apiUrl));
  late final ConsistencyStore consistency = ConsistencyStore(
    consistencyGateway,
  );
  String get _apiUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:5013'
        : 'http://localhost:5013';
  }

  WorkoutGateway _defaultGateway() {
    if (const bool.fromEnvironment('USE_PREVIEW')) {
      return PreviewWorkoutGateway();
    }
    return ApiWorkoutGateway(baseUrl: _apiUrl);
  }

  @override
  void dispose() {
    if (widget.gateway == null && gateway is ApiWorkoutGateway) {
      (gateway as ApiWorkoutGateway).close();
    }
    sessions.dispose();
    consistency.dispose();
    if (widget.consistencyGateway == null &&
        consistencyGateway is ApiConsistencyGateway) {
      (consistencyGateway as ApiConsistencyGateway).close();
    }
    if (widget.sessionGateway == null && sessionGateway is ApiSessionGateway) {
      (sessionGateway as ApiSessionGateway).close();
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
    home: WorkoutHome(
      gateway: gateway,
      sessions: sessions,
      consistency: consistency,
    ),
  );
}
