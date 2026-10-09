import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../application/providers.dart';
import '../../../domain/models.dart';
import '../../../domain/estado_recepcion_entrega.dart';

typedef _Entrega = ({Lote lote, LoteLinea linea});

/// Presentación del historial; no modifica entregas ni recepciones.
class HistorialProduccion extends ConsumerStatefulWidget {
  const HistorialProduccion({super.key});
  @override
  ConsumerState<HistorialProduccion> createState() =>
      _HistorialProduccionState();
}

class _HistorialProduccionState extends ConsumerState<HistorialProduccion> {
  String _consulta = '', _estado = 'Todas';
  DateTimeRange? _rango;
  final _abiertos = <String>{};
  static const _verde = Color(0xFF299D64), _ambar = Color(0xFFD98B00);

  Future<void> _fechas(List<_Entrega> registros) async {
    final ahora = DateTime.now();
    final fechas =
        registros.map((r) => r.lote.fechaEnvio.toLocal()).toList()..sort();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(
        fechas.isEmpty || fechas.first.year >= 1900 ? 1900 : fechas.first.year,
      ),
      lastDate: DateTime(
        fechas.isNotEmpty && fechas.last.year > ahora.year
            ? fechas.last.year + 1
            : ahora.year + 1,
        12,
        31,
      ),
      initialDateRange: _rango,
      helpText: 'Fecha de entrega de Producción',
      saveText: 'Aplicar',
    );
    if (mounted && rango != null) setState(() => _rango = rango);
  }

  @override
  Widget build(BuildContext context) {
    final lotes = ref.watch(wmsSnapshotProvider).value?.lotes ?? const <Lote>[];
    final registros = [
      for (final lote in lotes)
        for (final linea in lote.lineas) (lote: lote, linea: linea),
    ];
    final visibles =
        registros.where((r) {
            final item = r.linea.item;
            if (!'${item.op} ${item.codigo} ${item.descripcion} ${item.cliente} ${item.oc}'
                .toLowerCase()
                .contains(_consulta.trim().toLowerCase())) {
              return false;
            }
            final dia = DateUtils.dateOnly(r.lote.fechaEnvio.toLocal());
            if (_rango != null &&
                (dia.isBefore(DateUtils.dateOnly(_rango!.start)) ||
                    dia.isAfter(DateUtils.dateOnly(_rango!.end)))) {
              return false;
            }
            final recibida =
                EstadoRecepcionEntrega.calcular(
                  r.linea.cantidadEnviada,
                  r.linea.cantidadRecibida ?? 0,
                ) ==
                EstadoRecepcionEntrega.completado;
            return _estado == 'Todas' ||
                (_estado == 'Recibidas' ? recibida : !recibida);
          }).toList()
          ..sort((a, b) => b.lote.fechaEnvio.compareTo(a.lote.fechaEnvio));
    final grupos = <String, List<_Entrega>>{};
    for (final r in visibles) {
      final dia = DateFormat('yyyy-MM-dd').format(r.lote.fechaEnvio.toLocal());
      grupos.putIfAbsent('$dia/${r.linea.item.id}', () => []).add(r);
    }
    final enviadas = visibles.fold<int>(
      0,
      (s, r) => s + r.linea.cantidadEnviada,
    );
    final recibidas = visibles.fold<int>(
      0,
      (s, r) => s + (r.linea.cantidadRecibida ?? 0),
    );
    final pendientes = visibles.fold<int>(
      0,
      (s, r) =>
          s +
          (r.linea.cantidadEnviada - (r.linea.cantidadRecibida ?? 0)).clamp(
            0,
            r.linea.cantidadEnviada,
          ),
    );
    final ops = visibles.map((r) => r.linea.item.op).toSet().length;
    final entradas = grupos.entries.toList();
    return LayoutBuilder(
      builder: (context, c) {
        final mobile = c.maxWidth < 600;
        final buscar = TextField(
          onChanged: (v) => setState(() => _consulta = v),
          decoration: InputDecoration(
            hintText: mobile ? 'Buscar por OP' : 'OP, código o cliente',
            prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true,
          ),
        );
        final estados = SegmentedButton<String>(
          showSelectedIcon: false,
          style: const ButtonStyle(
            textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          segments: [
            for (final e in ['Todas', 'Por recibir', 'Recibidas'])
              ButtonSegment(value: e, label: Text(e)),
          ],
          selected: {_estado},
          onSelectionChanged: (v) => setState(() => _estado = v.single),
        );
        final fecha =
            mobile
                ? IconButton.outlined(
                  tooltip: 'Filtrar por fecha',
                  onPressed: () => _fechas(registros),
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                )
                : OutlinedButton.icon(
                  onPressed: () => _fechas(registros),
                  icon: const Icon(Icons.calendar_month_outlined, size: 17),
                  label: Text(
                    _rango == null ? 'Fecha: todas' : 'Fecha: filtrada',
                  ),
                );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!mobile) ...[
              Row(
                children: [
                  for (final m in [
                    ('Prendas entregadas', '$enviadas'),
                    ('Recibidas en logística', '$recibidas'),
                    ('Por recibir', '$pendientes'),
                    ('OP · movimientos', '$ops · ${visibles.length}'),
                  ])
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F7F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.$1,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF57707C),
                              ),
                            ),
                            Text(
                              m.$2,
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w600,
                                color:
                                    m.$1 == 'Recibidas en logística'
                                        ? _verde
                                        : m.$1 == 'Por recibir'
                                        ? _ambar
                                        : const Color(0xFF093E52),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (c.maxWidth < 850) ...[
              Row(
                children: [
                  Expanded(child: buscar),
                  const SizedBox(width: 8),
                  fecha,
                ],
              ),
              const SizedBox(height: 8),
              estados,
            ] else
              Row(
                children: [
                  Expanded(child: buscar),
                  const SizedBox(width: 10),
                  fecha,
                  const SizedBox(width: 20),
                  estados,
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
            if (mobile)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '$enviadas prendas · $ops OP · ${visibles.length} movimientos',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ColoredBox(
                color: const Color(0xFFF5F8F9),
                child:
                    entradas.isEmpty
                        ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'No hay entregas con estos filtros.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.all(6),
                          itemCount: entradas.length,
                          itemBuilder: (context, i) {
                            final entry = entradas[i];
                            final dia = DateUtils.dateOnly(
                              entry.value.first.lote.fechaEnvio.toLocal(),
                            );
                            final mostrarDia =
                                i == 0 ||
                                dia !=
                                    DateUtils.dateOnly(
                                      entradas[i - 1]
                                          .value
                                          .first
                                          .lote
                                          .fechaEnvio
                                          .toLocal(),
                                    );
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (mostrarDia)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    child: Text(
                                      DateFormat('dd/MM/yyyy').format(dia),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF57707C),
                                      ),
                                    ),
                                  ),
                                _tarjeta(entry.key, entry.value, mobile),
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

  Widget _tarjeta(String id, List<_Entrega> entregas, bool mobile) {
    final item = entregas.first.linea.item;
    final enviadas = entregas.fold<int>(
      0,
      (s, r) => s + r.linea.cantidadEnviada,
    );
    final recibidas = entregas.fold<int>(
      0,
      (s, r) => s + (r.linea.cantidadRecibida ?? 0),
    );
    final estado = EstadoRecepcionEntrega.calcular(enviadas, recibidas);
    final color = estado == EstadoRecepcionEntrega.completado ? _verde : _ambar;
    final abierto = _abiertos.contains(id);
    final progreso = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recibidas',
                style: TextStyle(fontSize: 10, color: Color(0xFF57707C)),
              ),
            ),
            Text(
              '$recibidas de $enviadas',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: enviadas > 0 ? (recibidas / enviadas).clamp(0.0, 1.0) : 0,
          color: color,
          backgroundColor: const Color(0xFFE3EDF1),
          minHeight: 4,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
    final titulo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          mobile
              ? 'OP ${item.op} · Talla ${item.talla}'
              : 'OP ${item.op} · ${item.descripcion} · Talla ${item.talla}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        if (mobile)
          Text(item.descripcion, style: const TextStyle(fontSize: 12)),
        if (!mobile || abierto)
          Text(
            '${item.codigo} · ${item.cliente} · OC ${item.oc}',
            style: const TextStyle(fontSize: 10, color: Color(0xFF57707C)),
          ),
      ],
    );
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '● ${estado == EstadoRecepcionEntrega.pendiente ? 'Por recibir' : estado.etiqueta}',
        style: TextStyle(fontSize: 10, color: color),
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDCE6EC)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: abierto,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap:
                  () => setState(() {
                    if (abierto) {
                      _abiertos.remove(id);
                    } else {
                      _abiertos.add(id);
                    }
                  }),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: titulo),
                        if (!mobile) ...[
                          const SizedBox(width: 16),
                          SizedBox(width: 150, child: progreso),
                        ],
                        const SizedBox(width: 8),
                        Flexible(flex: mobile ? 1 : 0, child: badge),
                        const SizedBox(width: 4),
                        Icon(
                          abierto ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                        ),
                      ],
                    ),
                    if (mobile) ...[const SizedBox(height: 8), progreso],
                  ],
                ),
              ),
            ),
          ),
          if (abierto) ...[
            const Divider(height: 1),
            for (final r in entregas)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 9,
                          color: r.linea.enTransito ? _ambar : _verde,
                        ),
                        Text(
                          'Entrega de ${r.linea.cantidadEnviada} unidades',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          r.linea.estado.etiqueta,
                          style: const TextStyle(fontSize: 11),
                        ),
                        Text(
                          '${DateFormat('dd/MM/yyyy · HH:mm').format(r.lote.fechaEnvio.toLocal())} · ${r.lote.id}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF57707C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder:
                          (context, c) => Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              for (final dato in [
                                ('Entregó', r.lote.operario),
                                (
                                  'Enviadas / recibidas',
                                  '${r.linea.cantidadEnviada} / ${r.linea.cantidadRecibida ?? 0}',
                                ),
                                (
                                  'Estante',
                                  r.linea.ubicacionDestino ?? 'Sin asignar',
                                ),
                                (
                                  'Recibió',
                                  r.linea.recibidoPor.isEmpty
                                      ? 'Sin registrar'
                                      : r.linea.recibidoPor,
                                ),
                              ])
                                SizedBox(
                                  width:
                                      (c.maxWidth - (mobile ? 12 : 36)) /
                                      (mobile ? 2 : 4),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dato.$1,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF57707C),
                                        ),
                                      ),
                                      Text(
                                        dato.$2,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                    ),
                    if (r.linea.novedad.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          r.linea.novedad,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
