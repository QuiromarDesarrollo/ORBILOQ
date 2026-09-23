import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primaryNavy = Color(0xFF173559);
  static const secondaryNavy = Color(0xFF1F436E);
  static const actionGreen = Color(0xFF2E8B57);
  static const actionOrange = Color(0xFFF37021);
  static const alertRed = Color(0xFFD32F2F);
  static const accentCyan = Color(0xFF00A8CC);
  static const background = Color(0xFFF4F6F9);

  // ---- Paleta del rediseño del Kardex (pantalla principal) ----
  static const tealPrimary = Color(0xFF0F766E);
  static const tealDark = Color(0xFF0B5750);
  static const tealSoft = Color(0xFFE6F4F2);
  static const slate900 = Color(0xFF0F172A);
  static const slate600 = Color(0xFF475569);
  static const slate400 = Color(0xFF94A3B8);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate50 = Color(0xFFF8FAFC);
  static const cardBorder = Color(0xFFE5E9F0);
  static const amberChip = Color(0xFFB45309);
  static const amberChipBg = Color(0xFFFFF7ED);
  static const redChipBg = Color(0xFFFEF2F2);
  static const greenChipBg = Color(0xFFECFDF5);
  static const blueChipBg = Color(0xFFEFF6FF);
  static const blueChip = Color(0xFF1D4ED8);

  // ---- Paleta oscura (rediseño del Kardex, tema dark) ----
  static const darkBg = Color(0xFF0B1220);
  static const darkHeader = Color(0xFF0E1729);
  static const darkCard = Color(0xFF141B2D);
  static const darkCardBorder = Color(0xFF232D42);
  static const darkInput = Color(0xFF0F1729);
  static const darkTextPrimary = Color(0xFFF1F5F9);
  static const darkTextSecondary = Color(0xFF8895AC);
  static const darkTextMuted = Color(0xFF5B6B85);
  static const tealAccent = Color(0xFF2DD4BF);
  static const chipRedBgDark = Color(0xFF3B1219);
  static const chipRedDark = Color(0xFFFCA5A5);
  static const chipGreenBgDark = Color(0xFF0F2E22);
  static const chipGreenDark = Color(0xFF6EE7B7);
  static const chipNeutralBgDark = Color(0xFF1B2438);
  static const chipNeutralDark = Color(0xFF94A3B8);
}

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryNavy),
        scaffoldBackgroundColor: AppColors.background,
      );
}

/// Decoración estándar de campos de texto.
InputDecoration wmsInput(String label, {IconData? icon, String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon),
    border: const OutlineInputBorder(),
    isDense: true,
  );
}
