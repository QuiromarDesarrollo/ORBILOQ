import 'package:flutter/material.dart';

/// Formularios: campos y acciones lado a lado si caben; apilados en móvil.
class ResponsiveRow extends StatelessWidget {
  const ResponsiveRow(
      {super.key,
      required this.children,
      this.mainAxisAlignment = MainAxisAlignment.start,
      this.crossAxisAlignment = CrossAxisAlignment.center,
      this.mainAxisSize = MainAxisSize.max});
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || constraints.maxWidth >= 560) {
          return Row(
              mainAxisAlignment: mainAxisAlignment,
              crossAxisAlignment: crossAxisAlignment,
              mainAxisSize: mainAxisSize,
              children: children);
        }
        return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final child in children)
                if (child is Spacer)
                  const SizedBox(height: 8)
                else if (child is Flexible)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: child.child)
                else if (child is SizedBox && child.child == null)
                  const SizedBox(height: 8)
                else
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: child),
            ]);
      });
}
