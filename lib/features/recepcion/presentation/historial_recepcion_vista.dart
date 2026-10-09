import 'package:flutter/material.dart';
import '../../../shared/widgets/historial_agrupado.dart';
import '../../../core/utils/fecha.dart';

class HistorialRecepcionVista extends StatefulWidget {
  const HistorialRecepcionVista({
    super.key,
    required this.grupos,
    required this.novedades,
    required this.parciales,
    this.totales,
  });
  final List<GrupoHistorial> grupos;
  final Set<String> novedades, parciales;
  final List<GrupoHistorial>? totales;
  @override
  State<HistorialRecepcionVista> createState() =>
      _HistorialRecepcionVistaState();
}

class _HistorialRecepcionVistaState extends State<HistorialRecepcionVista> {
  String _busqueda = '';
  int _estado = 0;
  DateTimeRange? _rango;
  final _abiertos = <String>{};
  @override
  Widget build(BuildContext context) {
    final grupos = <GrupoHistorial>[];
    for (final g in widget.grupos) {
      final eventos =
          g.eventos
              .where(
                (e) =>
                    coincideHistorial(g.op, e.fecha, _busqueda, _rango) &&
                    (_estado == 0 ||
                        (_estado == 2
                            ? widget.novedades.contains(e.id)
                            : !widget.novedades.contains(e.id) &&
                                !widget.parciales.contains(e.id))),
              )
              .toList();
      if (eventos.isNotEmpty) {
        grupos.add(
          GrupoHistorial(
            id: g.id,
            op: g.op,
            titulo: g.titulo,
            detalle: g.detalle,
            eventos: eventos,
          ),
        );
      }
    }
    DateTime ultima(GrupoHistorial g) => g.eventos
        .map((e) => e.fecha ?? DateTime(1900))
        .reduce((a, b) => a.isAfter(b) ? a : b);
    grupos.sort((a, b) => ultima(b).compareTo(ultima(a)));
    final total = widget.totales?.fold<int>(
      0,
      (n, g) =>
          n +
          g.eventos
              .where((e) => coincideHistorial(g.op, e.fecha, _busqueda, _rango))
              .fold<int>(0, (n, e) => n + (e.cantidad ?? 0)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _busqueda = v),
                decoration: const InputDecoration(
                  hintText: 'Buscar por OP',
                  prefixIcon: Icon(Icons.search, size: 18),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: 'Filtrar por fecha',
              onPressed: () async {
                final fechas =
                    widget.grupos
                        .expand((g) => g.eventos)
                        .map((e) => e.fecha)
                        .whereType<DateTime>()
                        .toList()
                      ..sort();
                final hoy = DateTime.now();
                final rango = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(
                    fechas.isNotEmpty && fechas.first.year < 1900
                        ? fechas.first.year
                        : 1900,
                  ),
                  lastDate: DateTime(
                    fechas.isNotEmpty && fechas.last.year > hoy.year
                        ? fechas.last.year + 1
                        : hoy.year + 1,
                    12,
                    31,
                  ),
                  initialDateRange: _rango,
                );
                if (mounted && rango != null) setState(() => _rango = rango);
              },
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
            ),
          ],
        ),
        if (_rango != null)
          TextButton.icon(
            onPressed: () => setState(() => _rango = null),
            icon: const Icon(Icons.close, size: 14),
            label: const Text('Quitar filtro de fechas'),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var n = 0; n < 3; n++)
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _estado = n),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    backgroundColor:
                        _estado == n ? const Color(0xFFE5EFF2) : null,
                  ),
                  child: Text(
                    ['Todas', 'Conformes', 'Con novedad'][n],
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            _estado == 0 && total != null
                ? '$total prendas recibidas · ${grupos.map((g) => g.op).toSet().length} OP'
                : '${grupos.length} grupos de recepciones',
            style: const TextStyle(fontSize: 11, color: Color(0xFF1B7048)),
          ),
        ),
        Expanded(
          child:
              grupos.isEmpty
                  ? const Center(
                    child: Text('No hay recepciones con estos filtros.'),
                  )
                  : ListView.builder(
                    itemCount: grupos.length,
                    itemBuilder: (context, n) {
                      final g = grupos[n];
                      final abierto = _abiertos.contains(g.id);
                      final cantidad = g.eventos.fold<int>(
                        0,
                        (n, e) => n + (e.cantidad ?? 0),
                      );
                      final novedad = g.eventos.any(
                        (e) => widget.novedades.contains(e.id),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          color: Colors.white,
                          elevation: 0,
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFDCE6EC)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              InkWell(
                                onTap:
                                    () => setState(() {
                                      if (abierto) {
                                        _abiertos.remove(g.id);
                                      } else {
                                        _abiertos.add(g.id);
                                      }
                                    }),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              g.titulo,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              novedad
                                                  ? '● Recibido con novedad'
                                                  : g.eventos.any(
                                                    (e) => widget.parciales
                                                        .contains(e.id),
                                                  )
                                                  ? '● Recepción parcial'
                                                  : '● Recibido conforme',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color:
                                                    novedad
                                                        ? Colors.orange.shade800
                                                        : const Color(
                                                          0xFF1B7048,
                                                        ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$cantidad uds',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1B7048),
                                        ),
                                      ),
                                      Icon(
                                        abierto
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (abierto) ...[
                                const Divider(height: 1),
                                for (final e in g.eventos)
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (e.fecha != null)
                                          Text(
                                            formatFechaHora(e.fecha!),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.blueGrey,
                                            ),
                                          ),
                                        const SizedBox(height: 5),
                                        Text(
                                          e.detalle,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
