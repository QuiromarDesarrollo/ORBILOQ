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

  /// Tema del Kardex (pantalla principal), en su variante oscura o clara,
  /// con [AppPalette] enganchada como [ThemeExtension] para que cualquier
  /// widget pueda leerla con `palOf(context)`.
  static ThemeData kardex(TemaModo modo) {
    final pal = modo == TemaModo.claro ? AppPalette.claro : AppPalette.oscuro;
    return ThemeData(
      useMaterial3: true,
      brightness: modo == TemaModo.claro ? Brightness.light : Brightness.dark,
      scaffoldBackgroundColor: pal.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.tealPrimary,
        brightness: modo == TemaModo.claro ? Brightness.light : Brightness.dark,
      ),
      extensions: [pal],
    );
  }
}

/// Modo de color de la pantalla del Kardex. No afecta el login ni ninguna
/// funcionalidad: solo cambia qué [AppPalette] se usa.
enum TemaModo { oscuro, claro }

/// Paleta de colores del Kardex, como [ThemeExtension]: cada widget la lee
/// con `palOf(context)` en vez de usar directamente `AppColors.darkXxx`, así
/// el mismo código sirve para el tema oscuro y el claro.
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.header,
    required this.card,
    required this.cardBorder,
    required this.input,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.chipRedBg,
    required this.chipRed,
    required this.chipGreenBg,
    required this.chipGreen,
    required this.chipNeutralBg,
    required this.warning,
    required this.info,
  });

  final Color bg;
  final Color header;
  final Color card;
  final Color cardBorder;
  final Color input;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color chipRedBg;
  final Color chipRed;
  final Color chipGreenBg;
  final Color chipGreen;
  final Color chipNeutralBg;

  /// Color de advertencia (ámbar) para cifras/chips de atención, como
  /// "Producto no conforme" o "HOY". Distinto del rojo de alerta.
  final Color warning;

  /// Azul informativo, para cifras como "Recibido en bodega".
  final Color info;

  static const oscuro = AppPalette(
    bg: AppColors.darkBg,
    header: AppColors.darkHeader,
    card: AppColors.darkCard,
    cardBorder: AppColors.darkCardBorder,
    input: AppColors.darkInput,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textMuted: AppColors.darkTextMuted,
    accent: AppColors.tealAccent,
    chipRedBg: AppColors.chipRedBgDark,
    chipRed: AppColors.chipRedDark,
    chipGreenBg: AppColors.chipGreenBgDark,
    chipGreen: AppColors.chipGreenDark,
    chipNeutralBg: AppColors.chipNeutralBgDark,
    warning: Color(0xFFFBBF24),
    info: Color(0xFF60A5FA),
  );

  static const claro = AppPalette(
    bg: Color(0xFFF3F5F9),
    header: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    cardBorder: AppColors.slate200,
    input: Color(0xFFF8FAFC),
    textPrimary: AppColors.slate900,
    textSecondary: AppColors.slate600,
    textMuted: AppColors.slate400,
    accent: AppColors.tealPrimary,
    chipRedBg: AppColors.redChipBg,
    chipRed: Color(0xFFB91C1C),
    chipGreenBg: AppColors.greenChipBg,
    chipGreen: Color(0xFF047857),
    chipNeutralBg: Color(0xFFF1F5F9),
    warning: AppColors.amberChip,
    info: AppColors.blueChip,
  );

  @override
  AppPalette copyWith({
    Color? bg,
    Color? header,
    Color? card,
    Color? cardBorder,
    Color? input,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? chipRedBg,
    Color? chipRed,
    Color? chipGreenBg,
    Color? chipGreen,
    Color? chipNeutralBg,
    Color? warning,
    Color? info,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      header: header ?? this.header,
      card: card ?? this.card,
      cardBorder: cardBorder ?? this.cardBorder,
      input: input ?? this.input,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      chipRedBg: chipRedBg ?? this.chipRedBg,
      chipRed: chipRed ?? this.chipRed,
      chipGreenBg: chipGreenBg ?? this.chipGreenBg,
      chipGreen: chipGreen ?? this.chipGreen,
      chipNeutralBg: chipNeutralBg ?? this.chipNeutralBg,
      warning: warning ?? this.warning,
      info: info ?? this.info,
    );
  }

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      header: Color.lerp(header, other.header, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      input: Color.lerp(input, other.input, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      chipRedBg: Color.lerp(chipRedBg, other.chipRedBg, t)!,
      chipRed: Color.lerp(chipRed, other.chipRed, t)!,
      chipGreenBg: Color.lerp(chipGreenBg, other.chipGreenBg, t)!,
      chipGreen: Color.lerp(chipGreen, other.chipGreen, t)!,
      chipNeutralBg: Color.lerp(chipNeutralBg, other.chipNeutralBg, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

/// Atajo para leer la paleta activa desde cualquier widget con [context].
AppPalette palOf(BuildContext context) => Theme.of(context).extension<AppPalette>() ?? AppPalette.oscuro;

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
