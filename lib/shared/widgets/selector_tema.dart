import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers.dart';
import '../../core/theme/app_theme.dart';

class SelectorTema extends ConsumerWidget {
  const SelectorTema({super.key});
  static const nombres = {
    TemaModo.claro: 'Claro',
    TemaModo.oscuro: 'Oscuro',
    TemaModo.corporativo: 'Corporativo Quiromar',
  };
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actual = ref.watch(temaProvider);
    return PopupMenuButton<TemaModo>(
      tooltip: 'Elegir apariencia',
      icon: Icon(
        actual == TemaModo.corporativo
            ? Icons.palette_outlined
            : actual == TemaModo.claro
            ? Icons.light_mode_outlined
            : Icons.dark_mode_outlined,
      ),
      onSelected: ref.read(temaProvider.notifier).seleccionar,
      itemBuilder:
          (_) => [
            for (final modo in [
              TemaModo.claro,
              TemaModo.oscuro,
              TemaModo.corporativo,
            ])
              CheckedPopupMenuItem(
                key: ValueKey('tema-${modo.name}'),
                value: modo,
                checked: modo == actual,
                child: Text(nombres[modo]!),
              ),
          ],
    );
  }
}
