import 'package:flutter/material.dart';
import '../../../domain/ciclos.dart';

/// Consulta paginada: los filtros no alteran el histórico ni sus mediciones.
class CiclosDetalleOp extends StatefulWidget {
  const CiclosDetalleOp({
    super.key,
    required this.datos,
    required this.ordenes,
  });
  final DatosCiclos datos;
  final List<OrdenCiclo> ordenes;
  @override
  State<CiclosDetalleOp> createState() => _CiclosDetalleOpState();
}

class _CiclosDetalleOpState extends State<CiclosDetalleOp> {
  String _buscar = '', _filtro = 'Todas', _orden = 'OP';
  int _pagina = 0;
  final _abiertas = <String>{};
  static const _verde = Color(0xff107e78), _rojo = Color(0xffbe2345);
  List<MedicionCiclo> _medidas(OrdenCiclo o) => [
    for (final p in ProcesoCiclo.values) widget.datos.medir(o, p),
  ];
  bool _tarde(MedicionCiclo m) => m.cumplio == false || m.estado == 'Vencido';
  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
  String _fecha(DateTime? d) =>
      d == null
          ? '—'
          : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final ordenes =
        widget.ordenes.where((o) {
            if (!'${o.op} ${o.cliente}'.toLowerCase().contains(
              _buscar.trim().toLowerCase(),
            )) {
              return false;
            }
            return switch (_filtro) {
              'Con atraso' => _medidas(o).any(_tarde),
              'En proceso' => _medidas(o).any(
                (m) =>
                    m.inicio != null &&
                    !m.inicio!.isAfter(widget.datos.hoy) &&
                    m.fin == null,
              ),
              'Trazabilidad incompleta' => !o.completa,
              _ => true,
            };
          }).toList()
          ..sort(
            (a, b) =>
                _orden == 'Cliente'
                    ? a.cliente.compareTo(b.cliente)
                    : _orden == 'Unidades'
                    ? b.cantidad.compareTo(a.cantidad)
                    : a.op.compareTo(b.op),
          );
    final pagina = _pagina.clamp(
      0,
      ordenes.isEmpty ? 0 : (ordenes.length - 1) ~/ 20,
    );
    final color = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: color.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, box) {
          final amplio = box.maxWidth >= 950;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: box.maxWidth < 600 ? box.maxWidth - 32 : 330,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Buscar OP o cliente',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                        onChanged:
                            (v) => setState(() {
                              _buscar = v;
                              _pagina = 0;
                            }),
                      ),
                    ),
                    for (final filtro in [
                      'Todas',
                      'Con atraso',
                      'En proceso',
                      'Trazabilidad incompleta',
                    ])
                      ChoiceChip(
                        label: Text(filtro),
                        selected: _filtro == filtro,
                        onSelected:
                            (_) => setState(() {
                              _filtro = filtro;
                              _pagina = 0;
                            }),
                      ),
                    SizedBox(
                      width: (box.maxWidth - 32).clamp(0, 280).toDouble(),
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _orden,
                        underline: const SizedBox.shrink(),
                        items: [
                          for (final s in ['OP', 'Cliente', 'Unidades'])
                            DropdownMenuItem(
                              value: s,
                              child: Text(
                                'Ordenar: $s',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged:
                            (v) => setState(() {
                              _orden = v!;
                              _pagina = 0;
                            }),
                      ),
                    ),
                  ],
                ),
              ),
              if (amplio)
                Padding(
                  padding: const EdgeInsets.fromLTRB(60, 10, 20, 10),
                  child: Row(
                    children: [
                      _celda('OP', 4),
                      _celda('CLIENTE', 3),
                      _celda('UNIDADES', 1),
                      _celda('TRAZABILIDAD', 2),
                      _celda('RESULTADO', 2),
                    ],
                  ),
                ),
              if (ordenes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No hay OP que coincidan con los filtros.'),
                ),
              for (final o in ordenes.skip(pagina * 20).take(20))
                _fila(o, amplio),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    Text(
                      ordenes.isEmpty
                          ? '0 OP'
                          : 'Mostrando ${pagina * 20 + 1}–${(pagina * 20 + 20).clamp(0, ordenes.length)} de ${ordenes.length} OP',
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Página anterior',
                          onPressed:
                              pagina == 0
                                  ? null
                                  : () => setState(() => _pagina = pagina - 1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('Página ${pagina + 1}'),
                        IconButton(
                          tooltip: 'Página siguiente',
                          onPressed:
                              (pagina + 1) * 20 >= ordenes.length
                                  ? null
                                  : () => setState(() => _pagina = pagina + 1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _celda(String texto, int flex, {bool bold = false}) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    ),
  );

  Widget _fila(OrdenCiclo o, bool amplio) {
    final abierta = _abiertas.contains(o.op), ms = _medidas(o);
    final evaluadas = ms.where((m) => m.cumplio != null).length;
    final atrasos = ms.where(_tarde).length;
    final resultado =
        atrasos > 0
            ? '$atrasos con atraso'
            : evaluadas == 0
            ? 'Sin cierres evaluables'
            : '${ms.where((m) => m.cumplio == true).length} de $evaluadas a tiempo';
    final badge = _badge(
      resultado,
      atrasos > 0
          ? _rojo
          : evaluadas == 0
          ? Colors.blueGrey
          : _verde,
    );
    return Container(
      decoration: BoxDecoration(
        color:
            abierta
                ? Theme.of(context).colorScheme.primary.withValues(alpha: .035)
                : null,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap:
                () => setState(
                  () => abierta ? _abiertas.remove(o.op) : _abiertas.add(o.op),
                ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Row(
                children: [
                  Icon(
                    abierta ? Icons.expand_less : Icons.expand_more,
                    semanticLabel: abierta ? 'Contraer OP' : 'Expandir OP',
                  ),
                  const SizedBox(width: 20),
                  if (amplio) ...[
                    _celda(o.op, 4, bold: true),
                    _celda(o.cliente, 3),
                    _celda('${o.cantidad}', 1),
                    _celda(o.completa ? '● Completa' : '○ Incompleta', 2),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: badge,
                      ),
                    ),
                  ] else
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.op,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(o.cliente),
                          Text(
                            '${o.cantidad} unidades · ${o.completa ? 'Completa' : 'Incompleta'}',
                          ),
                          const SizedBox(height: 6),
                          badge,
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (abierta)
            Padding(
              padding: EdgeInsets.fromLTRB(amplio ? 56 : 12, 0, 16, 16),
              child: _detalle(o, ms, amplio),
            ),
        ],
      ),
    );
  }

  Widget _detalle(OrdenCiclo o, List<MedicionCiclo> ms, bool amplio) {
    final fechas = [
      if (o.inicio != null) o.inicio!,
      for (final m in ms) ...[
        if (m.fin != null) m.fin!,
        if (m.esperada != null) m.esperada!,
        if (m.inicio != null &&
            m.fin == null &&
            !m.inicio!.isAfter(widget.datos.hoy))
          widget.datos.hoy,
      ],
    ]..sort();
    final min = fechas.firstOrNull, max = fechas.lastOrNull;
    final objetivo =
        ms.every((m) => m.parametro != null)
            ? ms.fold<int>(0, (s, m) => s + m.parametro!.dias)
            : null;
    final real =
        o.completa
            ? widget.datos.calendario.transcurridos(o.inicio!, o.fines.last!)
            : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            Text('Inicio ${_fecha(o.inicio)}'),
            Text('Evaluado al ${_fecha(widget.datos.hoy)}'),
            Text('Fin ${_fecha(o.fines.last)}'),
            Text('Ciclo cerrado: ${real == null ? '—' : '$real días hábiles'}'),
            Text(
              'Objetivo de procesos: ${objetivo == null ? '—' : '$objetivo días'}',
            ),
            if (real != null && objetivo != null)
              Text('Margen: ${objetivo - real} días hábiles'),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 18,
          runSpacing: 6,
          children: [
            _leyenda('Duración / transcurrido', _verde),
            _leyenda(
              'Margen hasta fecha esperada',
              _verde.withValues(alpha: .25),
            ),
            _leyenda('Atraso', _rojo),
          ],
        ),
        const SizedBox(height: 12),
        if (amplio) ...[
          Row(
            children: [
              _celda('Proceso', 2),
              Expanded(
                flex: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fecha(min), style: const TextStyle(fontSize: 11)),
                    Text(_fecha(max), style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              _celda('Inicio', 2),
              _celda('Fin', 2),
              _celda('Esperada', 2),
              _celda('Real / objetivo', 2),
              _celda('Margen', 1),
              _celda('Estado', 2),
            ],
          ),
          const Divider(),
        ],
        for (final m in ms) _proceso(m, min, max, amplio),
        const SizedBox(height: 12),
        const Text(
          'Días hábiles · * Tiempo transcurrido en un proceso abierto. Margen = objetivo − duración o tiempo transcurrido al corte. Las fechas vacías no se estiman. La línea de tiempo usa fechas calendario. El objetivo de procesos no incluye la reserva de 3 días.',
          style: TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  Widget _leyenda(String texto, Color c) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 18, height: 8, color: c),
      const SizedBox(width: 6),
      Text(texto, style: const TextStyle(fontSize: 11)),
    ],
  );

  Widget _proceso(MedicionCiclo m, DateTime? min, DateTime? max, bool amplio) {
    final transcurridos =
        m.inicio != null &&
                m.fin == null &&
                !m.inicio!.isAfter(widget.datos.hoy)
            ? widget.datos.calendario.transcurridos(m.inicio!, widget.datos.hoy)
            : null;
    final dias = m.duracion ?? transcurridos;
    final margen =
        dias == null || m.parametro == null ? null : m.parametro!.dias - dias;
    final duracion =
        '${dias ?? '—'} / ${m.parametro?.dias ?? '—'} d${transcurridos == null ? '' : ' *'}';
    final estado = _badge(
      m.estado,
      _tarde(m)
          ? _rojo
          : m.cumplio == true
          ? _verde
          : Colors.blueGrey,
    );
    final barra = _barra(m, min, max);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child:
          amplio
              ? Row(
                children: [
                  _celda(m.proceso.titulo, 2, bold: true),
                  Expanded(flex: 5, child: barra),
                  const SizedBox(width: 18),
                  _celda(_fecha(m.inicio), 2),
                  _celda(_fecha(m.fin), 2),
                  _celda(_fecha(m.esperada), 2),
                  _celda(duracion, 2, bold: true),
                  _celda(
                    margen == null ? '—' : '${margen > 0 ? '+' : ''}$margen d',
                    1,
                  ),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: estado,
                    ),
                  ),
                ],
              )
              : Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          Text(
                            m.proceso.titulo,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          estado,
                        ],
                      ),
                      const SizedBox(height: 10),
                      barra,
                      const SizedBox(height: 10),
                      Text(
                        'Inicio: ${_fecha(m.inicio)} · Fin: ${_fecha(m.fin)}',
                      ),
                      Text('Esperada: ${_fecha(m.esperada)}'),
                      Text(
                        'Real / objetivo: $duracion · Margen: ${margen ?? '—'} d',
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _barra(MedicionCiclo m, DateTime? min, DateTime? max) => LayoutBuilder(
    builder: (context, box) {
      if (min == null || max == null || m.inicio == null) {
        return const SizedBox(height: 14);
      }
      final total = max.difference(min).inDays.clamp(1, 1000000);
      double x(DateTime d) =>
          (d.difference(min).inDays / total).clamp(0.0, 1.0) * box.maxWidth;
      final fin =
          m.fin ??
          (!m.inicio!.isAfter(widget.datos.hoy) ? widget.datos.hoy : m.inicio!);
      Widget segmento(DateTime a, DateTime b, Color c) => Positioned(
        left: x(a),
        width: (x(b) - x(a)).clamp(2.0, box.maxWidth),
        top: 2,
        bottom: 2,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
      return Tooltip(
        message:
            '${m.proceso.titulo}: ${_fecha(m.inicio)} → ${_fecha(m.fin)} · Esperada ${_fecha(m.esperada)}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 16,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: .25),
                  ),
                ),
                if (m.esperada != null)
                  segmento(
                    m.inicio!,
                    m.esperada!,
                    _verde.withValues(alpha: .22),
                  ),
                segmento(m.inicio!, fin, _verde),
                if (m.esperada != null && fin.isAfter(m.esperada!))
                  segmento(m.esperada!, fin, _rojo),
              ],
            ),
          ),
        ),
      );
    },
  );
}
