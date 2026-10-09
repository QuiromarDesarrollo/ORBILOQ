import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/models.dart';

class HistorialNoConforme extends StatefulWidget {
  const HistorialNoConforme({super.key, required this.devoluciones});
  final List<Devolucion> devoluciones;
  @override
  State<HistorialNoConforme> createState() => _HistorialNoConformeState();
}

class _HistorialNoConformeState extends State<HistorialNoConforme> {
  String _busqueda = '';
  String? _causal;
  DateTimeRange? _rango;
  final _abiertos = <String>{};
  static const rojo = Color(0xFFB42318);

  Future<void> _fecha() async {
    final fechas =
        widget.devoluciones.map((d) => d.fecha.toLocal()).toList()..sort();
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
    final causales =
        widget.devoluciones.map((d) => d.causal).toSet().toList()..sort();
    final visibles =
        widget.devoluciones.where((d) {
            if (!'${d.item.op} ${d.item.codigo} ${d.item.cliente} ${d.item.descripcion}'
                .toLowerCase()
                .contains(_busqueda.trim().toLowerCase())) {
              return false;
            }
            if (_causal != null && d.causal != _causal) return false;
            final dia = DateUtils.dateOnly(d.fecha.toLocal());
            return _rango == null ||
                (!dia.isBefore(DateUtils.dateOnly(_rango!.start)) &&
                    !dia.isAfter(DateUtils.dateOnly(_rango!.end)));
          }).toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha));
    final grupos = <String, List<Devolucion>>{};
    final frecuencias = <String, int>{};
    for (final d in visibles) {
      grupos
          .putIfAbsent(
            '${DateFormat('yyyy-MM-dd').format(d.fecha.toLocal())}/${d.item.id}',
            () => [],
          )
          .add(d);
      frecuencias.update(d.causal, (n) => n + 1, ifAbsent: () => 1);
    }
    final frecuencia =
        frecuencias.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final total = visibles.fold<int>(0, (n, d) => n + d.cantidad);
    final entradas = grupos.entries.toList();
    return LayoutBuilder(
      builder: (context, c) {
        final mobile = c.maxWidth < 600;
        final filtroCausal = DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _causal ?? '',
          decoration: const InputDecoration(isDense: true, labelText: 'Causal'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Todas')),
            for (final causa in causales)
              DropdownMenuItem(
                value: causa,
                child: Text(causa, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() => _causal = v == '' ? null : v),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _busqueda = v),
                    decoration: InputDecoration(
                      hintText:
                          mobile ? 'Buscar por OP' : 'OP, código o cliente',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
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
            const SizedBox(height: 8),
            filtroCausal,
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
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final dato in [
                  ('$total', 'Prendas no conformes'),
                  (
                    frecuencia.isEmpty ? '—' : frecuencia.first.key,
                    'Causa más frecuente',
                  ),
                  if (!mobile)
                    (
                      '${visibles.map((d) => d.item.op).toSet().length} · ${visibles.length}',
                      'OP · reportes',
                    ),
                ])
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F7F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dato.$1,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color:
                                  dato.$2 == 'Prendas no conformes'
                                      ? rojo
                                      : const Color(0xFF093E52),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dato.$2,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF57707C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ColoredBox(
                color: const Color(0xFFF5F8F9),
                child:
                    entradas.isEmpty
                        ? const Center(
                          child: Text('No hay reportes con estos filtros.'),
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.all(6),
                          itemCount: entradas.length,
                          itemBuilder: (context, i) {
                            final entry = entradas[i];
                            final datos = entry.value;
                            final item = datos.first.item;
                            final abierto = _abiertos.contains(entry.key);
                            final fecha = DateFormat(
                              'dd/MM/yyyy',
                            ).format(datos.first.fecha.toLocal());
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
                                        color: Color(0xFF57707C),
                                      ),
                                    ),
                                  ),
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
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
                                                _abiertos.remove(entry.key);
                                              } else {
                                                _abiertos.add(entry.key);
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
                                                      'OP ${item.op} · Talla ${item.talla}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    Text(
                                                      item.descripcion,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 5),
                                                    Text(
                                                      datos
                                                          .map((d) => d.causal)
                                                          .toSet()
                                                          .join(' · '),
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        color: rojo,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                '${datos.fold<int>(0, (n, d) => n + d.cantidad)} uds',
                                                style: const TextStyle(
                                                  color: rojo,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Icon(
                                                abierto
                                                    ? Icons.expand_less
                                                    : Icons.expand_more,
                                                size: 18,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (abierto) ...[
                                        const Divider(height: 1),
                                        for (final d in datos)
                                          Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Text(
                                                  'Reporte de ${d.cantidad} unidades · ${DateFormat('dd/MM/yyyy · HH:mm').format(d.fecha.toLocal())}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                Text(
                                                  '${item.codigo} · ${item.cliente} · ${d.causal}',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Color(0xFF57707C),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'Reportó (bodega)\n${d.operario}',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        'Entregó (producción)\n${d.recibidoDeProduccion.isEmpty ? 'Sin registrar' : d.recibidoDeProduccion}',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (d.nota.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 8,
                                                        ),
                                                    child: Text(
                                                      d.nota,
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
