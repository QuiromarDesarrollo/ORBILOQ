import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/seguimiento_entregas.dart';

/// Catálogo limitado a placas, sin descargar información del conductor.
class PlacaQuiromarField extends ConsumerWidget {
  const PlacaQuiromarField({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo = ref.watch(placasSeguimientoProvider);
    return catalogo.when(
      loading:
          () => const InputDecorator(
            decoration: InputDecoration(
              labelText: 'Placa',
              border: OutlineInputBorder(),
            ),
            child: Text('Cargando placas de Transporte…'),
          ),
      error:
          (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.isEmpty
                    ? 'No se pudieron cargar las placas.'
                    : 'Placa guardada: $value. No se pudo cargar el catálogo.',
              ),
              TextButton.icon(
                onPressed:
                    enabled
                        ? () => ref.invalidate(placasSeguimientoProvider)
                        : null,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar placas'),
              ),
            ],
          ),
      data: (placas) {
        final actual = value.trim().toUpperCase();
        final historica = actual.isNotEmpty && !placas.contains(actual);
        return DropdownButtonFormField<String>(
          key: ValueKey('placa-quiromar-$actual-${placas.join(',')}'),
          initialValue: actual.isEmpty ? null : actual,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Placa',
            border: const OutlineInputBorder(),
            isDense: true,
            helperText:
                historica
                    ? 'Placa anterior; elige una registrada para cambiarla.'
                    : placas.isEmpty
                    ? 'No hay vehículos registrados en Transporte.'
                    : 'Vehículos registrados en Transporte',
            helperMaxLines: 2,
          ),
          hint: const Text('Selecciona una placa'),
          items: [
            if (historica)
              DropdownMenuItem(
                value: actual,
                enabled: false,
                child: Text('$actual · anterior'),
              ),
            for (final placa in placas)
              DropdownMenuItem(value: placa, child: Text(placa)),
          ],
          onChanged:
              enabled && placas.isNotEmpty
                  ? (v) {
                    if (v != null) onChanged(v);
                  }
                  : null,
        );
      },
    );
  }
}
