import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/kardex_filters.dart';
import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';

/// Barra de filtros: búsqueda libre + cliente + estado (tema oscuro).
class KardexFiltersBar extends ConsumerStatefulWidget {
  const KardexFiltersBar({super.key, this.integrada = false});
  final bool integrada;

  @override
  ConsumerState<KardexFiltersBar> createState() => _KardexFiltersBarState();
}

class _KardexFiltersBarState extends ConsumerState<KardexFiltersBar> {
  late final TextEditingController _busquedaCtrl;

  @override
  void initState() {
    super.initState();
    _busquedaCtrl =
        TextEditingController(text: ref.read(kardexFiltersProvider).busqueda);
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
    final rol = ref.watch(rolProvider);
    final colEstado = rol == Rol.produccion
        ? ColKardex.estadoProduccion
        : ColKardex.estadoBodega;
    final pal = palOf(context);
    final tipoFecha = switch (rol) {
      Rol.produccion => 'Fecha de entrega',
      Rol.logistica => 'Fecha de recibido',
      Rol.despacho => 'Fecha de despacho',
    };
    String fecha(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    ref.listen(kardexFiltersProvider, (_, nuevo) {
      if (_busquedaCtrl.text != nuevo.busqueda) _busquedaCtrl.text = nuevo.busqueda;
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: widget.integrada ? null : Border.all(color: pal.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final estrecho = constraints.maxWidth < 920;
          final campos = <Widget>[
            SizedBox(
              width: estrecho ? double.infinity : 320,
              child: TextField(
                controller: _busquedaCtrl,
                onChanged: notifier.setBusqueda,
                style: TextStyle(color: pal.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Buscar por OP, cliente, OC o producto',
                  hintStyle: TextStyle(color: pal.textMuted, fontSize: 13),
                  prefixIcon:
                      Icon(Icons.search, size: 20, color: pal.textMuted),
                  filled: true,
                  fillColor: pal.input,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: pal.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: pal.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: pal.accent),
                  ),
                ),
              ),
            ),
            _Desplegable(
              ancho: estrecho ? double.infinity : 200,
              etiquetaTodos: 'Todos los clientes',
              valor: filtros.valoresDe(ColKardex.cliente).firstOrNull,
              opciones: opciones.de(ColKardex.cliente),
              onChanged: (v) =>
                  notifier.setColumna(ColKardex.cliente, v == null ? {} : {v}),
            ),
            _Desplegable(
              ancho: estrecho ? double.infinity : 190,
              etiquetaTodos: 'Todos los estados',
              valor: filtros.valoresDe(colEstado).firstOrNull,
              opciones: opciones.de(colEstado),
              onChanged: (v) =>
                  notifier.setColumna(colEstado, v == null ? {} : {v}),
            ),
            SizedBox(
              width: estrecho ? double.infinity : 275,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.date_range_outlined, size: 18),
                label: Text(filtros.desde == null
                    ? '$tipoFecha: todas'
                    : '$tipoFecha\n${fecha(filtros.desde!)} – ${fecha(filtros.hasta!)}'),
                onPressed: () async {
                  final fechas = ref.read(kardexProvider).map((i) => switch (rol) {
                    Rol.produccion => i.fechaEntrega,
                    Rol.logistica => i.fechaRecepcion,
                    Rol.despacho => i.fechaDespacho,
                  }).whereType<DateTime>().toList();
                  final hoy = DateTime.now();
                  var inicio = DateTime(2000);
                  var fin = DateTime(hoy.year + 5, 12, 31);
                  for (final f in [...fechas, if (filtros.desde != null) filtros.desde!, if (filtros.hasta != null) filtros.hasta!]) {
                    if (f.isBefore(inicio)) inicio = DateTime(f.year, f.month, f.day);
                    if (f.isAfter(fin)) fin = DateTime(f.year, f.month, f.day);
                  }
                  final rango = await showDateRangePicker(
                    context: context,
                    firstDate: inicio,
                    lastDate: fin,
                    initialDateRange: filtros.desde == null ? null : DateTimeRange(start: filtros.desde!, end: filtros.hasta!),
                    helpText: tipoFecha,
                    saveText: 'Aplicar',
                    cancelText: 'Cancelar',
                    confirmText: 'Aplicar',
                    fieldStartLabelText: 'Desde',
                    fieldEndLabelText: 'Hasta',
                  );
                  if (!mounted || rango == null || ref.read(rolProvider) != rol) return;
                  ref.read(kardexFiltersProvider.notifier).setFechas(rango.start, rango.end);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: filtros.desde == null ? pal.textSecondary : pal.accent,
                  side: BorderSide(color: pal.cardBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ),
            if (filtros.desde != null)
              IconButton(
                tooltip: 'Quitar filtro de fechas',
                onPressed: () => notifier.setFechas(null, null),
                icon: const Icon(Icons.event_busy_outlined),
              ),
            OutlinedButton.icon(
              onPressed: () {
                _busquedaCtrl.clear();
                notifier.limpiar();
              },
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Limpiar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: pal.textSecondary,
                side: BorderSide(color: pal.cardBorder),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ];

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 12, runSpacing: 12, children: campos),
            if (filtros.desde != null) ...[
              const SizedBox(height: 8),
              Text('Filtra por la última fecha registrada. Las tarjetas muestran los saldos actuales de las filas seleccionadas.',
                style: TextStyle(fontSize: 12, color: pal.textSecondary)),
            ],
          ]);
        },
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
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
    final pal = palOf(context);
    return SizedBox(
      width: ancho,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: pal.input,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: pal.cardBorder),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            isExpanded: true,
            isDense: true,
            value: valor,
            dropdownColor: pal.card,
            hint: Text(etiquetaTodos,
                style: TextStyle(fontSize: 13, color: pal.textSecondary)),
            icon: Icon(Icons.expand_more, size: 18, color: pal.textMuted),
            items: [
              if (valor != null && !opciones.contains(valor))
                DropdownMenuItem<String?>(
                  value: valor,
                  enabled: false,
                  child: Text('$valor (sin coincidencias)',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: pal.textSecondary)),
                ),
              DropdownMenuItem<String?>(
                value: null,
                child: Text(etiquetaTodos,
                    style: TextStyle(fontSize: 13, color: pal.textPrimary)),
              ),
              for (final o in opciones)
                DropdownMenuItem<String?>(
                  value: o,
                  child: Text(o,
                      style: TextStyle(fontSize: 13, color: pal.textPrimary),
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
