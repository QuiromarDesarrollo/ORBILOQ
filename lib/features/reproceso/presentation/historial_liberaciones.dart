import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/models.dart';

class HistorialLiberaciones extends StatefulWidget {
  const HistorialLiberaciones({
    super.key,
    required this.liberaciones,
    this.pendientesPorItem,
  });
  final List<Liberacion> liberaciones;
  final Map<String, int>? pendientesPorItem;
  @override
  State<HistorialLiberaciones> createState() => _HistorialLiberacionesState();
}

class _HistorialLiberacionesState extends State<HistorialLiberaciones> {
  String _busqueda = '';
  DateTimeRange? _rango;
  final _cerrados = <String>{};
  static const verde = Color(0xFF1B7048);

  Future<void> _fecha() async {
    final fechas =
        widget.liberaciones.map((l) => l.fecha.toLocal()).toList()..sort();
    final ahora = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(
        fechas.isNotEmpty && fechas.first.year < 1900
            ? fechas.first.year
            : 1900,
      ),
      lastDate: DateTime(
        fechas.isNotEmpty && fechas.last.year > ahora.year
            ? fechas.last.year + 1
            : ahora.year + 1,
        12,
        31,
      ),
      initialDateRange: _rango,
    );
    if (mounted && rango != null) setState(() => _rango = rango);
  }

  @override
  Widget build(BuildContext context) {
    final visibles =
        widget.liberaciones.where((l) {
            final coincide =
                '${l.item.op} ${l.item.codigo} ${l.item.cliente} ${l.item.descripcion}'
                    .toLowerCase()
                    .contains(_busqueda.trim().toLowerCase());
            final dia = DateUtils.dateOnly(l.fecha.toLocal());
            return coincide &&
                (_rango == null ||
                    (!dia.isBefore(DateUtils.dateOnly(_rango!.start)) &&
                        !dia.isAfter(DateUtils.dateOnly(_rango!.end))));
          }).toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha));
    final grupos = <String, List<Liberacion>>{};
    for (final l in visibles) {
      grupos
          .putIfAbsent(
            '${DateFormat('yyyy-MM-dd').format(l.fecha.toLocal())}/${l.item.id}',
            () => [],
          )
          .add(l);
    }
    final entradas = grupos.entries.toList();
    final total = visibles.fold<int>(0, (n, l) => n + l.cantidad);
    return LayoutBuilder(
      builder: (context, c) {
        final mobile = c.maxWidth < 600;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _busqueda = v),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText:
                          mobile ? 'Buscar por OP' : 'OP, código o cliente',
                      prefixIcon: const Icon(Icons.search, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Filtrar por fecha',
                  onPressed: _fecha,
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                ),
              ],
            ),
            if (_rango != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _rango = null),
                  icon: const Icon(Icons.close, size: 14),
                  label: Text(
                    '${DateFormat('dd/MM/yyyy').format(_rango!.start)} – ${DateFormat('dd/MM/yyyy').format(_rango!.end)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '$total prendas liberadas · ${visibles.map((l) => l.item.op).toSet().length} OP · ${visibles.length} liberaciones',
                style: const TextStyle(fontSize: 12, color: verde),
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: const Color(0xFFF5F8F9),
                child:
                    entradas.isEmpty
                        ? const Center(
                          child: Text(
                            'No hay liberaciones con estos filtros.',
                            textAlign: TextAlign.center,
                          ),
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.all(6),
                          itemCount: entradas.length,
                          itemBuilder: (context, i) {
                            final entry = entradas[i];
                            final registros = entry.value;
                            final item = registros.first.item;
                            final fecha = DateFormat(
                              'dd/MM/yyyy',
                            ).format(registros.first.fecha.toLocal());
                            final unidades = registros.fold<int>(
                              0,
                              (n, l) => n + l.cantidad,
                            );
                            final pendiente =
                                widget.pendientesPorItem?[item.id];
                            final abierto = !_cerrados.contains(entry.key);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (i == 0 ||
                                    fecha !=
                                        DateFormat('dd/MM/yyyy').format(
                                          entradas[i - 1].value.first.fecha
                                              .toLocal(),
                                        ))
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    child: Text(
                                      fecha,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ),
                                Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: const Color(0xFFDCE6EC),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      InkWell(
                                        onTap:
                                            () => setState(() {
                                              if (abierto) {
                                                _cerrados.add(entry.key);
                                              } else {
                                                _cerrados.remove(entry.key);
                                              }
                                            }),
                                        borderRadius: BorderRadius.circular(12),
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
                                                      'OP ${item.op} · Talla ${item.talla}',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      item.descripcion,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    if (!mobile)
                                                      Text(
                                                        '${item.codigo} · ${item.cliente}',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              Colors.blueGrey,
                                                        ),
                                                      ),
                                                    if (pendiente != null)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              top: 6,
                                                            ),
                                                        child: Text(
                                                          pendiente == 0
                                                              ? '● Sin pendientes actualmente'
                                                              : '$pendiente pendientes actualmente',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color:
                                                                pendiente == 0
                                                                    ? verde
                                                                    : Colors
                                                                        .orange
                                                                        .shade800,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '$unidades uds',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: verde,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
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
                                        for (final l in registros)
                                          Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Text(
                                                  '● Liberación de ${l.cantidad} unidades · ${DateFormat('dd/MM/yyyy · HH:mm').format(l.fecha.toLocal())}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: verde,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Wrap(
                                                  spacing: 24,
                                                  runSpacing: 10,
                                                  children: [
                                                    for (final dato in [
                                                      (
                                                        'Liberó (producción)',
                                                        l.operario,
                                                      ),
                                                      (
                                                        'Recibió (logística)',
                                                        l
                                                                .recibidoPorLogistica
                                                                .isEmpty
                                                            ? 'Sin registrar'
                                                            : l.recibidoPorLogistica,
                                                      ),
                                                    ])
                                                      SizedBox(
                                                        width:
                                                            mobile
                                                                ? (c.maxWidth -
                                                                        62) /
                                                                    2
                                                                : 210,
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              dato.$1,
                                                              style: const TextStyle(
                                                                fontSize: 10,
                                                                color:
                                                                    Colors
                                                                        .blueGrey,
                                                              ),
                                                            ),
                                                            Text(
                                                              dato.$2,
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                if (l.nota.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 8,
                                                        ),
                                                    child: Text(
                                                      'Nota: ${l.nota}',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
              ),
            ),
          ],
        );
      },
    );
  }
}
