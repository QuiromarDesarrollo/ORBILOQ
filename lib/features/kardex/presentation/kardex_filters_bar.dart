import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';

/// Barra de filtros: búsqueda libre + cliente + estado.
class KardexFiltersBar extends ConsumerStatefulWidget {
  const KardexFiltersBar({super.key});

  @override
  ConsumerState<KardexFiltersBar> createState() => _KardexFiltersBarState();
}

class _KardexFiltersBarState extends ConsumerState<KardexFiltersBar> {
  late final TextEditingController _busquedaCtrl;

  @override
  void initState() {
    super.initState();
    _busquedaCtrl = TextEditingController(text: ref.read(kardexFiltersProvider).busqueda);
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtros = ref.watch(kardexFiltersProvider);
    final opciones = ref.watch(opcionesFiltroProvider);
    final notifier = ref.read(kardexFiltersProvider.notifier);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final estrecho = constraints.maxWidth < 760;
          final campos = <Widget>[
            SizedBox(
              width: estrecho ? double.infinity : 320,
              child: TextField(
                controller: _busquedaCtrl,
                onChanged: notifier.setBusqueda,
                decoration: InputDecoration(
                  hintText: 'Buscar por OP, cliente, OC o producto',
                  hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.slate400),
                  filled: true,
                  fillColor: AppColors.slate50,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                ),
              ),
            ),
            _Desplegable(
              ancho: estrecho ? double.infinity : 200,
              etiquetaTodos: 'Todos los clientes',
              valor: filtros.cliente,
              opciones: opciones.clientes,
              onChanged: notifier.setCliente,
            ),
            _Desplegable(
              ancho: estrecho ? double.infinity : 190,
              etiquetaTodos: 'Todos los estados',
              valor: filtros.estado,
              opciones: opciones.estados,
              onChanged: notifier.setEstado,
            ),
            OutlinedButton.icon(
              onPressed: () {
                _busquedaCtrl.clear();
                notifier.limpiar();
              },
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Limpiar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.slate600,
                side: const BorderSide(color: AppColors.cardBorder),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ];

          return Wrap(spacing: 12, runSpacing: 12, children: campos);
        },
      ),
    );
  }
}

class _Desplegable extends StatelessWidget {
  const _Desplegable({
    required this.ancho,
    required this.etiquetaTodos,
    required this.valor,
    required this.opciones,
    required this.onChanged,
  });

  final double ancho;
  final String etiquetaTodos;
  final String? valor;
  final List<String> opciones;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            isExpanded: true,
            isDense: true,
            value: valor,
            hint: Text(etiquetaTodos, style: const TextStyle(fontSize: 13, color: AppColors.slate600)),
            icon: const Icon(Icons.expand_more, size: 18, color: AppColors.slate400),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(etiquetaTodos, style: const TextStyle(fontSize: 13)),
              ),
              for (final o in opciones)
                DropdownMenuItem<String?>(
                  value: o,
                  child: Text(o, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
