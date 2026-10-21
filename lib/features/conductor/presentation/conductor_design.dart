import 'package:flutter/material.dart';

/// Paleta y componentes exclusivos del portal; no alteran el tema del WMS.
abstract final class ConductorDesign {
  static const navy = Color(0xFF0B3A4F);
  static const lime = Color(0xFFC5D900);
  static const cyan = Color(0xFF3A9AD0);
  static const ink = Color(0xFF163A49);
  static const muted = Color(0xFF56717D);
  static const line = Color(0xFFDCE6E8);
  static const background = Color(0xFFF2F6F6);
  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'ConductorSans',
      colorScheme: ColorScheme.fromSeed(
        seedColor: navy,
        brightness: Brightness.light,
      ).copyWith(primary: navy, secondary: cyan, surface: Colors.white),
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: base.textTheme
          .apply(bodyColor: ink, displayColor: ink)
          .copyWith(
            bodyLarge: const TextStyle(
              fontFamily: 'ConductorSans',
              fontSize: 14,
              height: 1.4,
              color: ink,
            ),
            bodyMedium: const TextStyle(
              fontFamily: 'ConductorSans',
              fontSize: 13,
              height: 1.4,
              color: ink,
            ),
            titleMedium: const TextStyle(
              fontFamily: 'ConductorSans',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 60,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lime,
          foregroundColor: navy,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'ConductorSans',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: const BorderSide(color: line),
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cyan,
          minimumSize: const Size(48, 44),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        labelStyle: const TextStyle(color: muted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: cyan, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFFF0F5CF),
        elevation: 0,
        height: 76,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            color: s.contains(WidgetState.selected) ? navy : muted,
            fontSize: 11,
            fontWeight:
                s.contains(WidgetState.selected)
                    ? FontWeight.w700
                    : FontWeight.w400,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: cyan,
        linearTrackColor: line,
        linearMinHeight: 5,
      ),
    );
  }
}

class ConductorHeading extends StatelessWidget {
  const ConductorHeading(this.title, this.subtitle, {super.key});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -.5,
            color: ConductorDesign.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 14, color: ConductorDesign.muted),
        ),
      ],
    ),
  );
}

class ConductorPanel extends StatelessWidget {
  const ConductorPanel({
    super.key,
    required this.title,
    required this.children,
    this.icon,
  });
  final String title;
  final List<Widget> children;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 21, color: ConductorDesign.cyan),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: ConductorDesign.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );
}

class ConductorBadge extends StatelessWidget {
  const ConductorBadge(
    this.text, {
    super.key,
    this.warning = false,
    this.error = false,
  });
  final String text;
  final bool warning, error;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color:
          error
              ? const Color(0xFFFDE9E7)
              : warning
              ? const Color(0xFFFFF0D4)
              : const Color(0xFFE7F2F7),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color:
            error
                ? const Color(0xFFA13732)
                : warning
                ? const Color(0xFF805100)
                : const Color(0xFF165F7B),
      ),
    ),
  );
}

class ConductorGrid extends StatelessWidget {
  const ConductorGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns =
          box.maxWidth >= 300 && MediaQuery.textScalerOf(context).scale(14) < 21
              ? 2
              : 1;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children)
            SizedBox(
              width: (box.maxWidth - (columns - 1) * 12) / columns,
              child: child,
            ),
        ],
      );
    },
  );
}

class ConductorShortcut extends StatelessWidget {
  const ConductorShortcut({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: ConductorDesign.line),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: ConductorDesign.cyan, size: 24),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: ConductorDesign.ink,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: ConductorDesign.muted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
