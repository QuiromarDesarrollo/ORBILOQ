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
  static const darkBg = Color(0xFF0C1421);
  static const darkHeader = Color(0xFF0E1729);
  static const darkCard = Color(0xFF141E2D);
  static const darkCardBorder = Color(0xFF2A3749);
  static const darkInput = Color(0xFF0F1729);
  static const darkTextPrimary = Color(0xFFF1F5F9);
  static const darkTextSecondary = Color(0xFFA7B3C5);
  static const darkTextMuted = Color(0xFF91A0B6);
  static const tealAccent = Color(0xFF2DD4BF);
  static const chipRedBgDark = Color(0xFF3B1219);
  static const chipRedDark = Color(0xFFFCA5A5);
  static const chipGreenBgDark = Color(0xFF0F2E22);
  static const chipGreenDark = Color(0xFF6EE7B7);
  static const chipNeutralBgDark = Color(0xFF1B2438);
  static const chipNeutralDark = Color(0xFF94A3B8);
}

abstract final class AppTheme {
  static ThemeData get light => kardex(TemaModo.claro);

  static ThemeData kardex(TemaModo modo) {
    final dark = modo == TemaModo.oscuro;
    final pal = dark ? AppPalette.oscuro : AppPalette.claro;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.tealPrimary,
      brightness: dark ? Brightness.dark : Brightness.light,
    ).copyWith(
        primary: pal.accent,
        onPrimary: dark ? AppColors.slate900 : Colors.white,
        surface: pal.card,
        onSurface: pal.textPrimary,
        onSurfaceVariant: pal.textSecondary,
        outline: pal.textMuted,
        outlineVariant: pal.cardBorder,
        error: pal.chipRed);
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'Roboto');
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    return base.copyWith(
      scaffoldBackgroundColor: pal.bg,
      extensions: [pal],
      textTheme: base.textTheme.copyWith(
        headlineLarge: TextStyle(
            fontSize: 32,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            color: pal.textPrimary),
        headlineSmall: TextStyle(
            fontSize: 24,
            height: 1.3,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            color: pal.textPrimary),
        titleLarge: TextStyle(
            fontSize: 20,
            height: 1.3,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: pal.textPrimary),
        titleMedium: TextStyle(
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: pal.textPrimary),
        bodyLarge: TextStyle(fontSize: 14, height: 1.5, color: pal.textPrimary),
        bodyMedium:
            TextStyle(fontSize: 13, height: 1.5, color: pal.textPrimary),
        bodySmall:
            TextStyle(fontSize: 12, height: 1.4, color: pal.textSecondary),
        labelLarge: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      ).apply(fontFamily: 'Roboto'),
      dividerTheme:
          DividerThemeData(color: pal.cardBorder, thickness: 1, space: 24),
      iconTheme: IconThemeData(size: 20, color: pal.textSecondary),
      cardTheme: CardThemeData(
          color: pal.card,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: pal.cardBorder))),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              shape: shape,
              minimumSize: const Size(0, 42),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12))),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              shape: shape,
              elevation: 0,
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              minimumSize: const Size(0, 42),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              shape: shape,
              foregroundColor: pal.textPrimary,
              side: BorderSide(color: pal.cardBorder),
              minimumSize: const Size(0, 42),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12))),
      textButtonTheme:
          TextButtonThemeData(style: TextButton.styleFrom(shape: shape)),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: pal.input,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          labelStyle: TextStyle(color: pal.textSecondary, fontSize: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: pal.cardBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: pal.accent, width: 1.5))),
      progressIndicatorTheme: ProgressIndicatorThemeData(
          color: pal.accent, linearTrackColor: pal.cardBorder),
      tooltipTheme: TooltipThemeData(
          waitDuration: const Duration(milliseconds: 400),
          decoration: BoxDecoration(
              color: pal.textPrimary, borderRadius: BorderRadius.circular(6)),
          textStyle: TextStyle(fontSize: 12, color: pal.card)),
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
    textMuted: Color(0xFF627287),
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
AppPalette palOf(BuildContext context) =>
    Theme.of(context).extension<AppPalette>() ?? AppPalette.oscuro;

final ThemeData _temaDialogoClaro = AppTheme.light.copyWith(
  tabBarTheme: TabBarThemeData(
    indicator: BoxDecoration(color: AppColors.tealSoft, borderRadius: BorderRadius.circular(8)),
    indicatorSize: TabBarIndicatorSize.tab,
    dividerColor: Colors.transparent,
    labelColor: AppColors.tealDark,
    unselectedLabelColor: AppColors.slate600,
    labelStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 12, fontWeight: FontWeight.w600),
    labelPadding: const EdgeInsets.symmetric(horizontal: 16),
  ),
);

/// Envuelve un diálogo utilitario (filtros, confirmaciones, tickets) para
/// que siempre se vea en modo claro, sin importar si el Kardex está en tema
/// oscuro o claro: su diseño (texto navy fijo, tarjeta blanca) no está
/// pensado para adaptarse, y en tema oscuro el título quedaba casi
/// invisible. `showDialog` monta cada diálogo como una ruta aparte, así que
/// esto se aplica en cada `builder`, no una sola vez arriba del árbol.
Widget dialogoClaro(Widget child) =>
    Theme(data: _temaDialogoClaro, child: child);

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
