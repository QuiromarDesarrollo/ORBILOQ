import 'package:flutter/material.dart';
import 'conductor_design.dart';

/// Componentes del expediente administrativo, adaptables al ancho disponible.
class FlotaPanel extends StatelessWidget {
  const FlotaPanel({
    super.key,
    required this.title,
    required this.children,
    this.compact = false,
  });
  final String title;
  final bool compact;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.only(bottom: compact ? 12 : 16),
    padding: EdgeInsets.all(
      compact
          ? 18
          : MediaQuery.sizeOf(context).width < 600
          ? 17
          : 21,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ConductorDesign.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: compact ? 12 : 18),
        ...children,
      ],
    ),
  );
}

class FlotaGrid extends StatelessWidget {
  const FlotaGrid({super.key, required this.children, this.columns = 4});
  final List<Widget> children;
  final int columns;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final count =
          c.maxWidth >= 950
              ? columns
              : c.maxWidth >= 580
              ? 2
              : 1;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final child in children)
            SizedBox(
              width: (c.maxWidth - (count - 1) * 16) / count,
              child: child,
            ),
        ],
      );
    },
  );
}

class FlotaMetric extends StatelessWidget {
  const FlotaMetric(
    this.label,
    this.value, {
    super.key,
    this.detail,
    this.compact = false,
    this.icon = Icons.insights_outlined,
  });
  final String label, value;
  final bool compact;
  final String? detail;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(compact ? 16 : 18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ConductorDesign.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compact)
          Row(
            children: [
              Icon(icon, color: ConductorDesign.muted, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: ConductorDesign.muted,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          )
        else ...[
          Icon(icon, color: ConductorDesign.muted, size: 22),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(color: ConductorDesign.muted, fontSize: 14),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        if (detail != null) ...[
          const SizedBox(height: 10),
          Text(
            detail!,
            style: const TextStyle(color: ConductorDesign.muted, fontSize: 14),
          ),
        ],
      ],
    ),
  );
}

class FlotaColumns extends StatelessWidget {
  const FlotaColumns({super.key, required this.main, required this.aside});
  final Widget main;
  final Widget? aside;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder:
        (context, c) =>
            aside == null
                ? main
                : c.maxWidth < 900
                ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [main, aside!],
                )
                : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: main),
                    const SizedBox(width: 24),
                    Expanded(child: aside!),
                  ],
                ),
  );
}
