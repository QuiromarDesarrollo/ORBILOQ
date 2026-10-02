import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers.dart';
import 'labeled_dropdown.dart';

class CatalogoUbicacionDropdown extends ConsumerWidget {
  const CatalogoUbicacionDropdown(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged});
  final String label, value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(ubicacionesProvider).when(
          loading: () => const WmsLoadingStrip(),
          error: (e, _) => const Text(
              'No se pudieron cargar los estantes. Actualiza antes de continuar.'),
          data: (lista) {
            if (lista.isEmpty) {
              return const Text(
                  'No hay estantes activos. Solicita al administrador agregar uno.');
            }
            final elegido = lista.contains(value) ? value : lista.first;
            if (elegido != value) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) onChanged(elegido);
              });
            }
            return LabeledDropdown<String>(
                label: label,
                value: elegido,
                items: lista,
                onChanged: onChanged);
          });
}
