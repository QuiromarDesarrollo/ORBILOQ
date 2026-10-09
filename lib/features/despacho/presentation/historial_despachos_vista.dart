import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/utils/fecha.dart';

/// Una tarjeta por LE. Las cantidades son movimientos; los empaques se muestran
/// una sola vez aunque su contenido esté distribuido en varios estantes.
class HistorialDespachosVista extends StatefulWidget {
  const HistorialDespachosVista({
    super.key,
    required this.filas,
    required this.entregas,
    required this.pendientes,
    required this.onCorregir,
    required this.onDocumento,
    this.ocupado = false,
    this.mostrarEntregadas = true,
  });
  final List<Map<String, dynamic>> filas;
  final List<Map<String, dynamic>>? entregas;
  final bool mostrarEntregadas;
  final bool pendientes, ocupado;
  final ValueChanged<String>? onCorregir, onDocumento;
  @override
  State<HistorialDespachosVista> createState() => _VistaState();
}

class _VistaState extends State<HistorialDespachosVista> {
  String buscar = '';
  DateTimeRange? rango;
  final abiertos = <String>{};
  static const navy = Color(0xff123e4f),
      borde = Color(0xffdce6eb),
      suave = Color(0xfff5f8f9);
  String id(Map f) => '${f['despacho_oc_id'] ?? f['registro']}';
  int cantidad(Iterable<Map<String, dynamic>> filas) =>
      filas.fold(0, (n, f) => n + ((f['cantidad'] as num?)?.toInt() ?? 0));
  String estado(String clave) {
    if (widget.pendientes) return 'Por liberar';
    final e = widget.entregas?.where((e) => '${e['id']}' == clave).firstOrNull;
    return switch (e?['estado']) {
      'entregado' => 'Entregado',
      'devuelto_cliente' => 'Devuelto por el cliente',
      'devolucion_parcial' => 'Devolución parcial',
      'en_transito' => 'En tránsito',
      _ =>
        e == null
            ? 'Salida confirmada'
            : e['recibido'] != null
            ? 'Entregado'
            : 'En tránsito',
    };
  }

  List<Map> empaques(List<Map<String, dynamic>> filas) {
    final unicos = <String, Map>{};
    for (final f in filas) {
      if (f['empaques'] is! List) continue;
      for (final e in f['empaques'] as List) {
        if (e is Map) {
          unicos[jsonEncode([
                e['numero'],
                e['op'],
                e['talla'],
                e['id'],
                e['nombre'],
                e['cantidad'],
              ])] =
              e;
        }
      }
    }
    return unicos.values.toList();
  }

  Widget badge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color:
          text == 'Entregado'
              ? const Color(0xffe5f3eb)
              : const Color(0xfffff2dc),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color:
            text == 'Entregado'
                ? const Color(0xff1c704b)
                : const Color(0xff8c5900),
      ),
    ),
  );
  Future<void> fechas() async {
    final now = DateTime.now();
    final v = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: rango,
    );
    if (v != null && mounted) setState(() => rango = v);
  }

  @override
  Widget build(BuildContext context) {
    final grupos = <String, List<Map<String, dynamic>>>{};
    for (final f in widget.filas) {
      grupos.putIfAbsent(id(f), () => []).add(f);
    }
    final visibles =
        grupos.entries
            .where(
              (g) => g.value.any((f) {
                final fecha = DateTime.tryParse('${f['fecha']}')?.toLocal();
                return '${f['le_numero'] ?? ''} ${f['oc']} ${f['op']} ${f['cliente']}'
                        .toLowerCase()
                        .contains(buscar) &&
                    (rango == null ||
                        fecha != null &&
                            !fecha.isBefore(rango!.start) &&
                            fecha.isBefore(
                              rango!.end.add(const Duration(days: 1)),
                            ));
              }),
            )
            .toList()
          ..sort(
            (a, b) => '${b.value.first['fecha']}'.compareTo(
              '${a.value.first['fecha']}',
            ),
          );
    final total = cantidad(visibles.expand((g) => g.value));
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final entrada = TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por LE, OC u OP',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
              ),
              onChanged: (v) => setState(() => buscar = v.trim().toLowerCase()),
            );
            final fecha = Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: fechas,
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(
                    rango == null
                        ? widget.pendientes
                            ? 'Fecha de empaque'
                            : 'Todas las fechas'
                        : '${rango!.start.day}/${rango!.start.month} – ${rango!.end.day}/${rango!.end.month}',
                  ),
                ),
                if (rango != null)
                  IconButton(
                    tooltip: 'Quitar fecha',
                    onPressed: () => setState(() => rango = null),
                    icon: const Icon(Icons.close, size: 18),
                  ),
              ],
            );
            return c.maxWidth < 550
                ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [entrada, const SizedBox(height: 8), fecha],
                )
                : Row(
                  children: [
                    Expanded(child: entrada),
                    const SizedBox(width: 10),
                    fecha,
                  ],
                );
          },
        ),
        const SizedBox(height: 12),
        if (widget.pendientes)
          Text(
            '$total prendas reservadas · ${visibles.length} LE',
            style: const TextStyle(fontWeight: FontWeight.bold, color: navy),
          )
        else
          LayoutBuilder(
            builder:
                (context, c) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final v in [
                      ('Prendas despachadas', '$total'),
                      (
                        'Listas de empaque',
                        '${visibles.length} · ${visibles.expand((g) => g.value).length} movimientos',
                      ),
                      if (widget.mostrarEntregadas)
                        (
                          'Entregadas',
                          widget.entregas == null
                              ? 'No disponible'
                              : '${visibles.where((g) => estado(g.key) == 'Entregado').length} de ${visibles.length}',
                        ),
                    ])
                      Container(
                        width:
                            c.maxWidth < 500
                                ? c.maxWidth
                                : widget.mostrarEntregadas
                                ? (c.maxWidth - 16) / 3
                                : (c.maxWidth - 8) / 2,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: borde),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v.$1, style: const TextStyle(fontSize: 12)),
                            Text(
                              v.$2,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
          ),
        const SizedBox(height: 12),
        if (visibles.isEmpty)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Text(
              'No hay despachos que coincidan con los filtros.',
              textAlign: TextAlign.center,
            ),
          ),
        for (final g in visibles) _tarjeta(g.key, g.value),
      ],
    );
  }

  Widget _tarjeta(String clave, List<Map<String, dynamic>> filas) {
    final f = filas.first, lista = empaques(filas);
    final abierta = abiertos.contains(clave);
    final le =
        f['le_numero'] == null ? 'Despacho sin LE' : 'LE N° ${f['le_numero']}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: widget.pendientes ? const Color(0xffe5b953) : borde,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap:
                  () => setState(() {
                    if (abierta) {
                      abiertos.remove(clave);
                    } else {
                      abiertos.add(clave);
                    }
                  }),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            le,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: navy,
                            ),
                          ),
                        ),
                        Text(
                          '${cantidad(filas)} uds',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: navy,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          abierta ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${f['cliente']} · ${f['oc']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        badge(estado(clave)),
                        Text(
                          formatFechaHora(
                            DateTime.tryParse('${f['fecha']}')?.toLocal(),
                          ),
                          style: const TextStyle(fontSize: 11),
                        ),
                        Text(
                          '${lista.map((e) => e['numero']).where((n) => n != null).toSet().length} empaques',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (abierta)
              Container(
                color: suave,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final m in filas)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OP ${m['op']} · ${m['producto']} · Talla ${m['talla']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'Por: ${m['persona']} · Estante: ${m['ubicacion']} · Correcciones: ${m['ediciones'] ?? 0}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    if (lista.isNotEmpty)
                      LayoutBuilder(
                        builder:
                            (context, c) => Column(
                              children: [
                                for (final e in lista)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 9,
                                      horizontal: 8,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      border: Border(
                                        bottom: BorderSide(color: borde),
                                      ),
                                    ),
                                    child:
                                        c.maxWidth < 500
                                            ? Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Text(
                                                  'Empaque ${e['numero'] ?? '–'} · ${e['cantidad']} prendas',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                Text(
                                                  '${e['nombre'] ?? e['categoria'] ?? ''} · ${e['largo_cm'] ?? '–'} × ${e['ancho_cm'] ?? '–'} × ${e['alto_cm'] ?? '–'} cm',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                Text(
                                                  'OP ${e['op'] ?? ''} · Talla ${e['talla'] ?? ''}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            )
                                            : Row(
                                              children: [
                                                SizedBox(
                                                  width: 85,
                                                  child: Text(
                                                    'Empaque ${e['numero'] ?? '–'}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    '${e['nombre'] ?? ''} · ${e['largo_cm'] ?? '–'} × ${e['ancho_cm'] ?? '–'} × ${e['alto_cm'] ?? '–'} cm',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    'OP ${e['op'] ?? ''} · Talla ${e['talla'] ?? ''}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                Text('${e['cantidad']}'),
                                              ],
                                            ),
                                  ),
                              ],
                            ),
                      ),
                    const SizedBox(height: 10),
                    if (widget.pendientes)
                      const Text(
                        'Las prendas siguen en bodega hasta que confirmes la salida.',
                        style: TextStyle(fontSize: 12),
                      ),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (f['despacho_oc_id'] != null &&
                            widget.onCorregir != null)
                          OutlinedButton.icon(
                            onPressed:
                                widget.ocupado
                                    ? null
                                    : () => widget.onCorregir!(clave),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Corregir despacho'),
                          ),
                        if (f['despacho_oc_id'] != null &&
                            widget.onDocumento != null)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: navy,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => widget.onDocumento!(clave),
                            icon: const Icon(
                              Icons.picture_as_pdf_outlined,
                              size: 16,
                            ),
                            label: Text(
                              widget.pendientes
                                  ? 'Confirmar salida'
                                  : 'Lista de empaque PDF',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
