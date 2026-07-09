import 'package:flutter/material.dart';

class AppTheme {
  final String name;
  final Color background; // Papel
  final Color primary; // Tinta
  final Color surface; // Bloques
  final Color accent; // Detalles (Rojo Sello)
  final Color highlight; // Selección suave
  final Brightness brightness;

  AppTheme({
    required this.name,
    required this.background,
    required this.primary,
    required this.surface,
    required this.accent,
    required this.highlight,
    required this.brightness,
  });
}

final List<AppTheme> myThemes = [
  AppTheme(
    name: "Tinta Zen",
    background: const Color(0xFFF9F7F2), // Blanco roto (Papel washi)
    primary: const Color(0xFF212121), // Tinta negra suave
    surface: const Color(0xFFFFFFFF),
    accent: const Color(0xFFB71C1C), // Rojo Japón
    highlight: const Color(0xFFE3F2FD),
    brightness: Brightness.light,
  ),
  AppTheme(
    name: "Noche Kyoto",
    background: const Color(0xFF181818),
    primary: const Color(0xFFE0E0E0),
    surface: const Color(0xFF262626),
    accent: const Color(0xFF81C784), // Verde bambú suave
    highlight: const Color(0xFF333333),
    brightness: Brightness.dark,
  ),
];
