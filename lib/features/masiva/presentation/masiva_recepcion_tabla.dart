import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/multi_select_filter.dart';

const _navy = AppColors.petroleo;
const _line = Color(0xFFDCE7EC);
const _headerText = Color(0xFFEAF4F6);
const _muted = Color(0xFF627D89);
const _columns = <({String key, String title, double width})>[
  (key: 'pedido', title: 'ORDEN DE COMPRA', width: 180),
  (key: 'pendiente', title: 'CANTIDAD PENDIENTE POR RECIBIR', width: 174),
  (key: 'esperado', title: 'CANTIDAD A RECIBIR', width: 145),
  (key: 'recibido', title: 'CANTIDAD RECIBIDA', width: 145),
  (key: 'horario', title: 'HORARIO', width: 180),
  (key: 'novedad', title: 'NOVEDAD', width: 210),
  (key: 'saldo', title: 'SALDO', width: 125),
];

/// La consulta externa entrega filas y opciones de todo el conjunto de datos.
/// Aquí solo se presenta la selección: nunca se filtra una página localmente.
class MasivaRecepcionTabla extends StatefulWidget {
  const MasivaRecepcionTabla({
    super.key,
    required this.filas,
    required this.filtros,
    required this.opciones,
    required this.onFiltrosChanged,
    required this.onAbrir,
    this.cargando = false,
  });

  final List<Map<String, dynamic>> filas;
  final Map<String, Set<String>> filtros;
  final Map<String, List<String>> opciones;
  final ValueChanged<Map<String, Set<String>>> onFiltrosChanged;
  final ValueChanged<Map<String, dynamic>> onAbrir;
  final bool cargando;

  @override
  State<MasivaRecepcionTabla> createState() => _MasivaRecepcionTablaState();
}

class _MasivaRecepcionTablaState extends State<MasivaRecepcionTabla> {
  final _horizontal = ScrollController();
  final _numbers = NumberFormat.decimalPattern('es_CO');

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  int get _active => widget.filtros.values.where((v) => v.isNotEmpty).length;

  String _text(dynamic value, {String empty = 'Sin registrar'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? empty : text;
  }

  String _number(dynamic value) {
    final number = value is num ? value : num.tryParse('$value');
    return number == null ? '—' : _numbers.format(number);
  }

  String _option(String key, String value) {
    if (value.isEmpty) return key == 'saldo' ? 'Por cruzar' : 'Sin registrar';
    if (['pendiente', 'esperado', 'recibido', 'saldo'].contains(key)) {
      return num.tryParse(value) == null ? value : _number(value);
    }
    return value;
  }

  Future<void> _filter(String key) async {
    if (widget.cargando) return;
    final column = _columns.firstWhere((c) => c.key == key);
    final selected = await showMultiSelectFilter<String>(
      context,
      title: column.title,
      options: widget.opciones[key] ?? const [],
      selected: widget.filtros[key] ?? const {},
      labelOf: (value) => _option(key, value),
    );
    if (!mounted || selected == null) return;
    final filters = <String, Set<String>>{
      for (final entry in widget.filtros.entries) entry.key: {...entry.value},
    };
    if (selected.isEmpty) {
      filters.remove(key);
    } else {
      filters[key] = selected;
    }
    widget.onFiltrosChanged(filters);
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(16),
    ),
    clipBehavior: Clip.antiAlias,
    child: Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 700;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _toolbar(mobile),
              if (mobile)
                ...widget.filas.map(_card)
              else
                _desktop(constraints.maxWidth),
              if (widget.filas.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.manage_search_rounded,
                        color: _muted,
                        size: 32,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No hay órdenes que coincidan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _navy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Ajusta los filtros o limpia la búsqueda.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F9FA),
                  border: Border(top: BorderSide(color: _line)),
                ),
                child: const Text(
                  'Saldo = recibido total del SKU − prendas requeridas por el personal. '
                  'Si una prenda está en varias órdenes, el saldo se concentra en la última '
                  'orden cargada y las anteriores muestran 0. Negativo: faltantes; positivo: sobrantes.',
                  style: TextStyle(color: _muted, fontSize: 11, height: 1.5),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _toolbar(bool mobile) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: _line)),
    ),
    child: Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Icon(Icons.receipt_long_outlined, size: 20, color: _navy),
        const Text(
          'Órdenes de compra',
          style: TextStyle(color: _navy, fontWeight: FontWeight.w700),
        ),
        if (mobile)
          PopupMenuButton<String>(
            tooltip: 'Filtrar columnas',
            enabled: !widget.cargando,
            onSelected: _filter,
            itemBuilder:
                (_) => [
                  for (final column in _columns)
                    PopupMenuItem(
                      value: column.key,
                      child: Row(
                        children: [
                          Icon(
                            widget.filtros[column.key]?.isNotEmpty == true
                                ? Icons.filter_alt
                                : Icons.filter_alt_outlined,
                            size: 18,
                            color: _navy,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(column.title)),
                        ],
                      ),
                    ),
                ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F6F7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _line),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_alt_outlined, size: 17, color: _navy),
                  SizedBox(width: 6),
                  Text(
                    'Filtrar columnas',
                    style: TextStyle(color: _navy, fontSize: 12),
                  ),
                  Icon(Icons.expand_more, size: 18, color: _navy),
                ],
              ),
            ),
          ),
        if (_active > 0) ...[
          Text(
            '$_active ${_active == 1 ? 'filtro activo' : 'filtros activos'}',
            style: const TextStyle(color: _navy, fontSize: 12),
          ),
          TextButton.icon(
            onPressed:
                widget.cargando ? null : () => widget.onFiltrosChanged({}),
            icon: const Icon(Icons.filter_alt_off_outlined, size: 17),
            label: const Text('Limpiar filtros'),
            style: TextButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: _navy,
              minimumSize: const Size(0, 36),
              textStyle: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontSize: 12),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _desktop(double availableWidth) {
    const minimumWidth = 1319.0;
    return Scrollbar(
      controller: _horizontal,
      thumbVisibility: availableWidth < minimumWidth,
      trackVisibility: availableWidth < minimumWidth,
      child: SingleChildScrollView(
        controller: _horizontal,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(
          bottom: availableWidth < minimumWidth ? 14 : 0,
        ),
        child: SizedBox(
          width: math.max(availableWidth, minimumWidth),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: {
              for (var i = 0; i < _columns.length; i++)
                i: FlexColumnWidth(_columns[i].width),
              _columns.length: const FlexColumnWidth(160),
            },
            border: const TableBorder(
              horizontalInside: BorderSide(color: _line),
            ),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: _navy),
                children: [
                  for (final column in _columns) _header(column),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Text(
                      'DETALLE',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              for (var index = 0; index < widget.filas.length; index++)
                TableRow(
                  decoration: BoxDecoration(
                    color:
                        index.isEven ? Colors.white : const Color(0xFFFAFCFC),
                  ),
                  children: [
                    _cell(_order(widget.filas[index])),
                    for (final key in ['pendiente', 'esperado', 'recibido'])
                      _cell(
                        Text(
                          _number(widget.filas[index][key]),
                          style: TextStyle(
                            color:
                                key == 'pendiente' &&
                                        (num.tryParse(
                                                  '${widget.filas[index][key]}',
                                                ) ??
                                                0) >
                                            0
                                    ? const Color(0xFF9B6500)
                                    : _navy,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        alignment: Alignment.centerRight,
                      ),
                    _cell(
                      Text(
                        _text(widget.filas[index]['horario']),
                        style: const TextStyle(color: _navy, fontSize: 12),
                      ),
                    ),
                    _cell(
                      Text(
                        _text(
                          widget.filas[index]['novedad'],
                          empty: 'Sin novedad',
                        ),
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                    _cell(
                      _balance(widget.filas[index]),
                      alignment: Alignment.center,
                    ),
                    _cell(_open(widget.filas[index])),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(({String key, String title, double width}) column) {
    final active = widget.filtros[column.key]?.isNotEmpty == true;
    return InkWell(
      key: ValueKey('masiva-filter-${column.key}'),
      onTap: widget.cargando ? null : () => _filter(column.key),
      child: Tooltip(
        message: 'Filtrar ${column.title.toLowerCase()}',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  column.title,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.5,
                    color: active ? AppColors.lima : Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color:
                      active
                          ? Colors.white.withValues(alpha: .14)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(
                  active ? Icons.filter_alt : Icons.filter_alt_outlined,
                  size: 16,
                  color: active ? AppColors.lima : _headerText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(Widget child, {Alignment alignment = Alignment.centerLeft}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Align(alignment: alignment, child: child),
      );

  Widget _order(Map<String, dynamic> row) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _text(row['pedido']),
        style: const TextStyle(
          color: _navy,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        _text(row['proveedor']),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _muted, fontSize: 11, height: 1.4),
      ),
    ],
  );

  Widget _balance(Map<String, dynamic> row) {
    final balance = num.tryParse('${row['saldo']}');
    final color =
        balance == null
            ? _muted
            : balance < 0
            ? const Color(0xFFAE4F18)
            : balance > 0
            ? const Color(0xFF087F56)
            : _navy;
    return Tooltip(
      message:
          balance == null
              ? 'Carga la base del personal para calcular el saldo.'
              : 'Saldo de las prendas asignado a esta orden. Si un SKU aparece en varias órdenes, '
                  'su diferencia total se muestra en la última orden cargada; las anteriores muestran 0.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          balance == null
              ? 'Por cruzar'
              : '${balance > 0 ? '+' : ''}${_number(balance)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _open(Map<String, dynamic> row) => Tooltip(
    message: 'Ver prendas de la orden ${_text(row['pedido'])}',
    child: OutlinedButton(
      onPressed: widget.cargando ? null : () => widget.onAbrir(row),
      style: OutlinedButton.styleFrom(
        foregroundColor: _navy,
        backgroundColor: Colors.transparent,
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        side: const BorderSide(color: _line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: const Text(
        'Ver prendas',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontFamily: 'ConductorSans', fontSize: 11),
      ),
    ),
  );

  Widget _card(Map<String, dynamic> row) => Container(
    padding: const EdgeInsets.all(16),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: _line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _order(row)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'SALDO',
                  style: TextStyle(
                    fontSize: 10,
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                _balance(row),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F6F7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in [
                ('A recibir', 'esperado'),
                ('Recibida', 'recibido'),
                ('Pendiente', 'pendiente'),
              ])
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.$1,
                        style: const TextStyle(fontSize: 10, color: _muted),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _number(row[entry.$2]),
                        style: const TextStyle(
                          fontSize: 15,
                          color: _navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Horario: ${_text(row['horario'])}',
          style: const TextStyle(fontSize: 12, color: _navy, height: 1.5),
        ),
        const SizedBox(height: 6),
        Text(
          'Novedad: ${_text(row['novedad'], empty: 'Sin novedad')}',
          style: const TextStyle(fontSize: 12, color: _muted, height: 1.5),
        ),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerRight, child: _open(row)),
      ],
    ),
  );
}
