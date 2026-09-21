import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Dropdown controlado (compatible con todas las versiones de Flutter).
/// [value] debe estar contenido en [items].
class LabeledDropdown<T> extends StatelessWidget {
  const LabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabel,
  });

  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final String Function(T)? itemLabel;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: wmsInput(label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          isDense: true,
          value: value,
          items: [
            for (final i in items)
              DropdownMenuItem<T>(
                value: i,
                child: Text(itemLabel?.call(i) ?? '$i', overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
