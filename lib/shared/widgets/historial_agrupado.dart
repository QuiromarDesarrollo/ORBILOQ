import 'wms_empty_state.dart';
import 'package:flutter/material.dart';
import '../../core/utils/fecha.dart';
import '../../domain/models.dart';
import 'status_chip.dart';

class EventoHistorial {
  const EventoHistorial(
      {required this.id,
      required this.titulo,
      required this.detalle,
      required this.fecha,
      this.cantidad,
      this.color = Colors.teal});
  final String id, titulo, detalle;
  final DateTime? fecha;
  final int? cantidad;
  final Color color;
}

class GrupoHistorial {
  const GrupoHistorial(
      {required this.id,
      required this.op,
      required this.titulo,
      required this.detalle,
      required this.eventos});
  final String id, op, titulo, detalle;
  final List<EventoHistorial> eventos;
}

GrupoHistorial grupoDeItem(ItemOrden item, List<EventoHistorial> eventos) =>
    GrupoHistorial(
      id: item.id,
      op: item.op,
      titulo: 'OP: ${item.op} - ${item.descripcion} (${item.talla})',
      detalle:
          'Código: ${item.codigo} | Cliente: ${item.cliente}${item.oc.isEmpty ? '' : ' | OC: ${item.oc}'}',
      eventos: eventos,
    );

List<GrupoHistorial> agruparHistorial<T>(Iterable<T> registros,
    ItemOrden Function(T) item, EventoHistorial Function(T) evento) {
  final grupos = <String, List<T>>{};
  for (final r in registros) {
    grupos.putIfAbsent(item(r).id, () => []).add(r);
  }
  return [
    for (final g in grupos.values)
      grupoDeItem(item(g.first), g.map(evento).toList())
  ];
}

/// Los límites se comparan por día local, incluyendo ambos extremos.
bool coincideHistorial(
    String op, DateTime? fecha, String consulta, DateTimeRange? rango) {
  if (!op.toLowerCase().contains(consulta.trim().toLowerCase())) return false;
  if (rango == null) return true;
  if (fecha == null) return false;
  final local = fecha.toLocal();
  final dia = DateTime(local.year, local.month, local.day);
  return !dia.isBefore(DateUtils.dateOnly(rango.start)) &&
      !dia.isAfter(DateUtils.dateOnly(rango.end));
}

class HistorialAgrupado extends StatefulWidget {
  const HistorialAgrupado(
      {super.key, required this.grupos, this.embebido = false});
  final List<GrupoHistorial> grupos;
  final bool embebido;
  @override
  State<HistorialAgrupado> createState() => _HistorialAgrupadoState();
}

class _HistorialAgrupadoState extends State<HistorialAgrupado> {
  final _op = TextEditingController();
  final Set<String> _expandidos = {};
  DateTimeRange? _rango;
  @override
  void dispose() {
    _op.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final fechas = widget.grupos
        .expand((g) => g.eventos)
        .map((e) => e.fecha?.toLocal())
        .whereType<DateTime>()
        .toList()
      ..sort();
    final ahora = DateTime.now();
    final desde = fechas.isEmpty || fechas.first.year >= 1900
        ? DateTime(1900)
        : DateTime(fechas.first.year);
    final hasta = DateTime(
        fechas.isNotEmpty && fechas.last.year > ahora.year
            ? fechas.last.year + 1
            : ahora.year + 1,
        12,
        31);
    final rango = await showDateRangePicker(
        context: context,
        firstDate: desde,
        lastDate: hasta,
        initialDateRange: _rango,
        helpText: 'Seleccionar fechas',
        builder: (context, child) => Theme(
              data: Theme.of(context).copyWith(
                datePickerTheme: DatePickerTheme.of(context).copyWith(
                  rangePickerHeaderHeadlineStyle: const TextStyle(fontSize: 16),
                ),
              ),
              child: child!,
            ),
        saveText: 'Aplicar',
        cancelText: 'Cancelar',
        confirmText: 'Aplicar',
        fieldStartLabelText: 'Desde',
        fieldEndLabelText: 'Hasta');
    if (mounted && rango != null) setState(() => _rango = rango);
  }

  String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final visibles = <GrupoHistorial>[];
    for (final g in widget.grupos) {
      final eventos = g.eventos
          .where((e) => coincideHistorial(g.op, e.fecha, _op.text, _rango))
          .toList()
        ..sort((a, b) {
          final c = (a.fecha ?? DateTime(1)).compareTo(b.fecha ?? DateTime(1));
          return c != 0 ? c : a.id.compareTo(b.id);
        });
      if (eventos.isNotEmpty) {
        visibles.add(GrupoHistorial(
            id: g.id,
            op: g.op,
            titulo: g.titulo,
            detalle: g.detalle,
            eventos: eventos));
      }
    }
    visibles.sort((a, b) => (b.eventos.last.fecha ?? DateTime(1))
        .compareTo(a.eventos.last.fecha ?? DateTime(1)));
    final filtrado = _op.text.trim().isNotEmpty || _rango != null;
    final lista = visibles.isEmpty
        ? Padding(
            padding: const EdgeInsets.all(20),
            child: WmsEmptyState(icon: Icons.history_rounded, title: filtrado ? 'Sin coincidencias' : 'Historial de movimientos', message: filtrado
                ? 'No hay movimientos que coincidan con los filtros.'
                : 'Aún no hay movimientos registrados.'))
        : ListView.builder(
            shrinkWrap: widget.embebido,
            physics:
                widget.embebido ? const NeverScrollableScrollPhysics() : null,
            itemCount: visibles.length,
            itemBuilder: (context, i) => _tarjeta(visibles[i], filtrado));
    return Column(
        mainAxisSize: widget.embebido ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
              builder: (context, box) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                            width: box.maxWidth < 480 ? box.maxWidth : 220,
                            child: TextField(
                                controller: _op,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                    labelText: 'Buscar por OP',
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: _op.text.isEmpty
                                        ? null
                                        : IconButton(
                                            tooltip: 'Limpiar OP',
                                            onPressed: () =>
                                                setState(() => _op.clear()),
                                            icon: const Icon(Icons.close))))),
                        OutlinedButton.icon(
                            onPressed: _elegirFecha,
                            icon: const Icon(Icons.date_range),
                            label: Text(_rango == null
                                ? 'Filtrar por fecha'
                                : '${_fecha(_rango!.start)} – ${_fecha(_rango!.end)}')),
                        if (_rango != null)
                          IconButton(
                              tooltip: 'Quitar filtro de fecha',
                              onPressed: () => setState(() => _rango = null),
                              icon: const Icon(Icons.event_busy)),
                        if (filtrado)
                          TextButton(
                              onPressed: () => setState(() {
                                    _op.clear();
                                    _rango = null;
                                  }),
                              child: const Text('Limpiar filtros')),
                      ])),
          const SizedBox(height: 8),
          Text(
              'Fecha del movimiento · ${visibles.length} grupo(s) · ${visibles.fold<int>(0, (n, g) => n + g.eventos.length)} movimiento(s)',
              style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          if (widget.embebido) lista else Expanded(child: lista),
        ]);
  }

  Widget _tarjeta(GrupoHistorial grupo, bool filtrado) {
    final expandido = _expandidos.contains(grupo.id);
    final cantidades = grupo.eventos.where((e) => e.cantidad != null);
    return Card(
        key: ValueKey('historial-${grupo.id}'),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
            button: true,
            expanded: expandido,
            child: InkWell(
                onTap: () => setState(() {
                      if (expandido) {
                        _expandidos.remove(grupo.id);
                      } else {
                        _expandidos.add(grupo.id);
                      }
                    }),
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(grupo.titulo,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold))),
                            const SizedBox(width: 8),
                            Tooltip(
                                message: expandido
                                    ? 'Ocultar trazabilidad'
                                    : 'Ver trazabilidad',
                                child: Icon(expandido
                                    ? Icons.expand_less
                                    : Icons.expand_more)),
                          ]),
                          if (grupo.detalle.isNotEmpty)
                            Text(grupo.detalle,
                                style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, runSpacing: 6, children: [
                            if (cantidades.isNotEmpty)
                              StatusChip(
                                  label:
                                      '${cantidades.fold<int>(0, (n, e) => n + e.cantidad!)} Uds${filtrado ? ' en el filtro' : ' en total'}',
                                  color: Colors.teal),
                            Text(
                                '${grupo.eventos.length} movimiento(s)${filtrado ? ' coincidentes' : ''}'),
                          ]),
                          if (expandido) ...[
                            const Divider(),
                            for (final e in grupo.eventos)
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.history,
                                            color: e.color, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                              Text(e.titulo,
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: e.color)),
                                              Text(
                                                  e.fecha == null
                                                      ? 'Sin fecha registrada'
                                                      : formatFechaHora(
                                                          e.fecha!.toLocal()),
                                                  style: const TextStyle(
                                                      fontSize: 12)),
                                              Text(e.detalle,
                                                  style: const TextStyle(
                                                      fontSize: 12)),
                                            ])),
                                      ])),
                          ],
                        ])))));
  }
}
