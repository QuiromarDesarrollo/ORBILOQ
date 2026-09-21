import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/fecha.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/multi_select_filter.dart';

/// Barra de filtros desplegables con casillas y búsqueda.
class KardexFiltersBar extends ConsumerWidget {
  const KardexFiltersBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rol = ref.watch(rolProvider);
    final filtros = ref.watch(kardexFiltersProvider);
    final opciones = ref.watch(opcionesFiltroProvider);
    final notifier = ref.read(kardexFiltersProvider.notifier);
    final esProduccion = rol == Rol.produccion;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _FilterButton(
            icon: Icons.tag,
            etiqueta: 'OP',
            todos: 'TODOS',
            cantidad: filtros.ops.length,
            onTap: () async {
              final r = await showMultiSelectFilter<String>(
                context,
                title: 'Filtrar por OP',
                options: opciones.ops,
                selected: filtros.ops,
                labelOf: (v) => v,
              );
              if (r != null) notifier.setOps(r);
            },
          ),
          _FilterButton(
            icon: Icons.receipt_long,
            etiqueta: 'OC',
            todos: 'TODOS',
            cantidad: filtros.ocs.length,
            onTap: () async {
              final r = await showMultiSelectFilter<String>(
                context,
                title: 'Filtrar por Orden de Compra (OC)',
                options: opciones.ocs,
                selected: filtros.ocs,
                labelOf: (v) => v,
              );
              if (r != null) notifier.setOcs(r);
            },
          ),
          _FilterButton(
            icon: Icons.business,
            etiqueta: 'Cliente',
            todos: 'TODOS',
            cantidad: filtros.clientes.length,
            onTap: () async {
              final r = await showMultiSelectFilter<String>(
                context,
                title: 'Filtrar por Cliente',
                options: opciones.clientes,
                selected: filtros.clientes,
                labelOf: (v) => v,
              );
              if (r != null) notifier.setClientes(r);
            },
          ),
          _FilterButton(
            icon: esProduccion ? Icons.event_available : Icons.event_note,
            etiqueta: esProduccion ? 'F. Entrega' : 'F. Recepción',
            todos: 'TODAS',
            cantidad: filtros.fechas.length,
            onTap: () async {
              final r = await showMultiSelectFilter<DateTime>(
                context,
                title: esProduccion
                    ? 'Filtrar por Fecha de Entrega (Producción)'
                    : 'Filtrar por Fecha de Recepción (Bodega)',
                options: opciones.fechas,
                selected: filtros.fechas,
                labelOf: formatFecha,
              );
              if (r != null) notifier.setFechas(r);
            },
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.icon,
    required this.etiqueta,
    required this.todos,
    required this.cantidad,
    required this.onTap,
  });

  final IconData icon;
  final String etiqueta;
  final String todos;
  final int cantidad;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activo = cantidad > 0;
    final color = activo ? AppColors.primaryNavy : Colors.grey.shade700;
    return SizedBox(
      width: 210,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: activo ? Colors.blue.shade50 : Colors.grey.shade100,
            border: Border.all(
              color: activo ? AppColors.primaryNavy : Colors.grey.shade400,
              width: activo ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  activo ? '$etiqueta: ($cantidad)' : '$etiqueta: $todos',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: activo ? FontWeight.bold : FontWeight.w500,
                    color: activo ? AppColors.primaryNavy : Colors.black87,
                  ),
                ),
              ),
              Icon(Icons.arrow_drop_down, size: 20, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
