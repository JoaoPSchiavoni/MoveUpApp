import 'package:flutter/material.dart';

import 'local_database.dart';

class Appearance extends ChangeNotifier {
  Appearance(this.data);
  final LocalData? data;
  bool disposed = false;
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }

  String? error;
  ThemeMode mode = ThemeMode.system;
  Future<void> load() async {
    try {
      final value = await data?.db.record('preference', 'theme');
      mode =
          ThemeMode.values.where((m) => m.name == value?['mode']).firstOrNull ??
          ThemeMode.system;
      error = null;
    } catch (_) {
      error = 'Não foi possível carregar a preferência de tema.';
    }
    if (!disposed) notifyListeners();
  }

  Future<void> set(ThemeMode value) async {
    await data?.change(
      () => data!.db.put('preference', 'theme', {'mode': value.name}),
    );
    mode = value;
    if (!disposed) notifyListeners();
  }
}

ThemeData moveUpTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff238260),
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xff101916)
        : const Color(0xfff4f7f4),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xff101916) : const Color(0xfff4f7f4),
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xff1b2722) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
