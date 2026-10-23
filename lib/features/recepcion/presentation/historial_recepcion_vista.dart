import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/historial_agrupado.dart';
import '../../../core/utils/fecha.dart';

class HistorialRecepcionVista extends StatefulWidget {
  const HistorialRecepcionVista({
    super.key,
    required this.grupos,
    required this.novedades,
    required this.parciales,
    this.totales,
    this.enviadas = const {},
    this.movimientosReales = false,
  });
  final List<GrupoHistorial> grupos;
  final Set<String> novedades, parciales;
  final List<GrupoHistorial>? totales;
  final Map<String, int> enviadas;
  final bool movimientosReales;
  @override
  State<HistorialRecepcionVista> createState() =>
      _HistorialRecepcionVistaState();
}

class _HistorialRecepcionVistaState extends State<HistorialRecepcionVista> {
  final _consulta = TextEditingController();
  String _estado = 'Todas';
  DateTimeRange? _rango;
  final _abiertos = <String>{};
  static const _verde = Color(0xFF22A368), _ambar = Color(0xFFD78A00);
  static const _azul = Color(0xFF093E52), _gris = Color(0xFF57707C);
  @override
  void dispose() {
    _consulta.dispose();
    super.dispose();
  }

  bool _coincide(GrupoHistorial g, EventoHistorial e) => coincideHistorial(
    '${g.op} ${g.titulo} ${g.detalle}',
    e.fecha,
    _consulta.text,
    _rango,
  );
  String _dia(EventoHistorial e) =>
      e.fecha == null
          ? 'Sin fecha'
          : DateFormat('dd/MM/yyyy').format(e.fecha!.toLocal());
  Future<void> _fechas() async {
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
      helpText: 'Fecha de recepción en bodega',
      saveText: 'Aplicar',
    );
    if (mounted && rango != null) setState(() => _rango = rango);
  }

  @override
  Widget build(BuildContext context) {
    final grupos = <GrupoHistorial>[];
    for (final g in widget.grupos) {
      final dias = <String, List<EventoHistorial>>{};
      for (final e in g.eventos) {
        if (!_coincide(g, e)) continue;
        final novedad = widget.novedades.contains(e.id);
        final parcial = widget.parciales.contains(e.id);
        if (_estado == 'Conformes' && (novedad || parcial)) continue;
        if (_estado == 'Con novedad' && !novedad) continue;
        dias.putIfAbsent(_dia(e), () => []).add(e);
      }
      for (final d in dias.entries) {
        d.value.sort(
          (a, b) =>
              (b.fecha ?? DateTime(1900)).compareTo(a.fecha ?? DateTime(1900)),
        );
        grupos.add(
          GrupoHistorial(
            id: '${g.id}/${d.key}',
            op: g.op,
            titulo: g.titulo,
            detalle: g.detalle,
            eventos: d.value,
          ),
        );
      }
    }
    grupos.sort(
      (a, b) => (b.eventos.first.fecha ?? DateTime(1900)).compareTo(
        a.eventos.first.fecha ?? DateTime(1900),
      ),
    );
    final eventos = grupos.expand((g) => g.eventos).toList();
    final recibidas = eventos.fold<int>(0, (s, e) => s + (e.cantidad ?? 0));
    final total = widget.totales?.fold<int>(
      0,
      (s, g) =>
          s +
          g.eventos
              .where((e) => _coincide(g, e))
              .fold<int>(0, (n, e) => n + (e.cantidad ?? 0)),
    );
    final conformes =
        eventos
            .where(
              (e) =>
                  !widget.novedades.contains(e.id) &&
                  !widget.parciales.contains(e.id),
            )
            .length;
    final novedades =
        eventos.where((e) => widget.novedades.contains(e.id)).length;
    final ops = grupos.map((g) => g.op).where((op) => op != '—').toSet().length;
    return LayoutBuilder(
      builder: (context, c) {
        final mobile = c.maxWidth < 600;
        final buscar = TextField(
          controller: _consulta,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText:
                mobile
                    ? 'Buscar OP, producto o cliente'
                    : 'OP, producto, código o cliente',
            prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true,
            suffixIcon:
                _consulta.text.isEmpty
                    ? null
                    : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      onPressed: () => setState(_consulta.clear),
                      icon: const Icon(Icons.close, size: 18),
                    ),
          ),
        );
        final fecha =
            mobile
                ? IconButton.outlined(
                  tooltip: 'Filtrar por fecha',
                  onPressed: _fechas,
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                )
                : OutlinedButton.icon(
                  onPressed: _fechas,
                  icon: const Icon(Icons.calendar_month_outlined, size: 17),
                  label: Text(
                    _rango == null ? 'Fecha: todas' : 'Fecha: filtrada',
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
            for (final e in ['Todas', 'Conformes', 'Con novedad'])
              ButtonSegment(value: e, label: Text(e)),
          ],
          selected: {_estado},
          onSelectionChanged: (v) => setState(() => _estado = v.single),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!mobile) ...[
              Row(
                children: [
                  _metrica(
                    widget.movimientosReales
                        ? 'Recibidas netas en el período'
                        : _estado == 'Todas' && total != null
                        ? 'Prendas recibidas'
                        : 'Recibidas en registros',
                    '${_estado == 'Todas' && total != null ? total : recibidas}',
                    _azul,
                  ),
                  _metrica(
                    widget.movimientosReales
                        ? 'Entradas de recepción'
                        : 'Registros conformes',
                    widget.movimientosReales
                        ? '${eventos.where((e) => (e.cantidad ?? 0) > 0).fold<int>(0, (s, e) => s + (e.cantidad ?? 0))}'
                        : '$conformes',
                    _verde,
                  ),
                  _metrica(
                    widget.movimientosReales
                        ? 'Ajustes de recepción'
                        : 'Con novedad',
                    widget.movimientosReales
                        ? '${eventos.where((e) => (e.cantidad ?? 0) < 0).fold<int>(0, (s, e) => s + (e.cantidad ?? 0))}'
                        : '$novedades',
                    _ambar,
                  ),
                  _metrica('OP · registros', '$ops · ${eventos.length}', _azul),
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
              if (!widget.movimientosReales) estados,
            ] else
              Row(
                children: [
                  Expanded(child: buscar),
                  const SizedBox(width: 10),
                  fecha,
                  const SizedBox(width: 20),
                  if (!widget.movimientosReales) estados,
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
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                widget.movimientosReales
                    ? '$recibidas prendas netas · $ops OP · ${eventos.length} movimientos del período. Fecha de recepción real; abre cada tarjeta para comparar con la entrega de producción.'
                    : '${mobile ? '$recibidas prendas · ' : ''}$ops OP · ${eventos.length} registros · Cantidades acumuladas por línea; fecha de última recepción.',
                style: const TextStyle(fontSize: 11, color: _gris),
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: const Color(0xFFF5F8F9),
                child:
                    grupos.isEmpty
                        ? const Center(
                          child: Text('No hay recepciones con estos filtros.'),
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.all(6),
                          itemCount: grupos.length,
                          itemBuilder: (context, i) {
                            final g = grupos[i];
                            final dia = _dia(g.eventos.first);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (i == 0 ||
                                    dia != _dia(grupos[i - 1].eventos.first))
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    child: Text(
                                      dia,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _gris,
                                      ),
                                    ),
                                  ),
                                _tarjeta(g, mobile),
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

  Widget _metrica(String titulo, String valor, Color color) => Expanded(
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
          Text(titulo, style: const TextStyle(fontSize: 11, color: _gris)),
          Text(
            valor,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _tarjeta(GrupoHistorial g, bool mobile) {
    final abierto = _abiertos.contains(g.id);
    final cantidad = g.eventos.fold<int>(0, (s, e) => s + (e.cantidad ?? 0));
    final tieneEnviadas = g.eventos.every(
      (e) => widget.enviadas.containsKey(e.id),
    );
    final enviadas = g.eventos.fold<int>(
      0,
      (s, e) => s + (widget.enviadas[e.id] ?? 0),
    );
    final novedad = g.eventos.any((e) => widget.novedades.contains(e.id));
    final parcial = g.eventos.any((e) => widget.parciales.contains(e.id));
    final color = novedad || parcial ? _ambar : _verde;
    final estado =
        novedad
            ? 'Con novedad'
            : parcial
            ? 'Parcial'
            : 'Conforme';
    final titulo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          g.titulo,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(g.detalle, style: const TextStyle(fontSize: 10, color: _gris)),
      ],
    );
    final progreso = SizedBox(
      width: mobile ? null : 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recibidas',
                  style: TextStyle(fontSize: 10, color: _gris),
                ),
              ),
              Text(
                tieneEnviadas ? '$cantidad de $enviadas' : '$cantidad uds',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (tieneEnviadas) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: enviadas > 0 ? (cantidad / enviadas).clamp(0.0, 1.0) : 0,
              color: color,
              backgroundColor: const Color(0xFFE3EDF1),
              minHeight: 4,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ],
      ),
    );
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('● $estado', style: TextStyle(fontSize: 10, color: color)),
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
                      _abiertos.remove(g.id);
                    } else {
                      _abiertos.add(g.id);
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
                          progreso,
                          const SizedBox(width: 8),
                          if (!widget.movimientosReales) badge,
                        ],
                        const SizedBox(width: 6),
                        Icon(
                          abierto ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                          color: _gris,
                        ),
                      ],
                    ),
                    if (mobile) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: progreso),
                          const SizedBox(width: 12),
                          if (!widget.movimientosReales) badge,
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (abierto) ...[
            const Divider(height: 1),
            for (final e in g.eventos)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (e.fecha != null)
                      Text(
                        formatFechaHora(e.fecha!),
                        style: const TextStyle(fontSize: 10, color: _gris),
                      ),
                    const SizedBox(height: 5),
                    Text(
                      e.titulo,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      e.detalle,
                      style: const TextStyle(fontSize: 11, height: 1.5),
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
