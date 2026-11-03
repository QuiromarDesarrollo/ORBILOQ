import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/multi_select_filter.dart';

const _ink = AppColors.petroleo;
const _headerText = Color(0xFFEAF4F6);
const _muted = Color(0xFF627D89);
const _line = Color(0xFFDCE7EC);
typedef MasivaMaestroColumna = ({String key, String title, double width});
typedef _Column = MasivaMaestroColumna;

const masivaListadoColumnas = <MasivaMaestroColumna>[
  (key: 'estado', title: 'Estado', width: 180),
  (key: 'lista', title: 'Lista de empaque', width: 165),
  (key: 'fecha_generado', title: 'Fecha de PDF', width: 180),
  (key: 'cliente', title: 'Cliente', width: 185),
  (key: 'ciudad', title: 'Ciudad', width: 155),
  (key: 'sede', title: 'Sede', width: 170),
  (key: 'direccion', title: 'Dirección', width: 220),
  (key: 'responsable', title: 'Responsable', width: 185),
  (key: 'total_piezas', title: 'Total piezas', width: 130),
  (key: 'cajas', title: 'Cajas', width: 110),
  (key: 'bolsas', title: 'Bolsas', width: 110),
  (key: 'peso_total', title: 'Peso estimado (kg)', width: 165),
  (key: 'volumen', title: 'Volumen (m³)', width: 145),
  (key: 'kits_totales', title: 'Kits totales', width: 125),
  (key: 'kits_validados', title: 'Kits validados', width: 140),
  (key: 'kits_empacados', title: 'Kits empacados', width: 145),
  (key: 'ultima_validacion', title: 'Última validación', width: 180),
  (key: 'fecha_despacho', title: 'Fecha de despacho', width: 180),
  (key: 'fecha_recepcion', title: 'Fecha de recepción', width: 180),
  (key: 'transportadora', title: 'Vehículo / transportadora', width: 200),
  (key: 'placa_guia', title: 'Placa / guía', width: 155),
  (key: 'novedades', title: 'Novedades', width: 220),
];
const masivaBaseColumnas = <MasivaMaestroColumna>[
  (key: 'fecha_carga', title: 'Fecha de carga', width: 180),
  (key: 'cliente', title: 'Cliente', width: 185),
  (key: 'logistica', title: 'Logística', width: 170),
  (key: 'entrega', title: 'Entrega', width: 170),
  (key: 'lista', title: 'Lista de empaque', width: 165),
  (key: 'numero_persona', title: 'Número de persona', width: 150),
  (key: 'ciudad', title: 'Ciudad', width: 155),
  (key: 'regional', title: 'Regional', width: 160),
  (key: 'departamento', title: 'Departamento', width: 170),
  (key: 'sede', title: 'Sede', width: 170),
  (key: 'sector', title: 'Sector', width: 160),
  (key: 'unidad', title: 'Unidad', width: 160),
  (key: 'unidad_directiva', title: 'Unidad directiva', width: 180),
  (key: 'gerencia', title: 'Gerencia', width: 180),
  (key: 'cargo', title: 'Cargo', width: 190),
  (key: 'direccion', title: 'Dirección', width: 220),
  (key: 'responsable', title: 'Responsable', width: 185),
  (key: 'cedula', title: 'Cédula', width: 155),
  (key: 'nombre', title: 'Nombre de la persona', width: 210),
  (key: 'sku', title: 'SKU', width: 160),
  (key: 'prenda', title: 'Prenda', width: 190),
  (key: 'descripcion', title: 'Descripción de la prenda', width: 240),
  (key: 'empaque', title: 'Empaque', width: 155),
  (key: 'numero_contenedor', title: 'Número de caja / bolsa', width: 175),
  (key: 'cantidad', title: 'Cantidad', width: 120),
  (key: 'items_kit', title: 'Ítems del kit', width: 135),
  (key: 'items_lista', title: 'Ítems de la lista', width: 145),
  (key: 'items_direccion', title: 'Ítems por dirección', width: 155),
  (key: 'validado', title: 'Cantidad validada', width: 150),
  (key: 'estado', title: 'Estado', width: 180),
  (key: 'validador', title: 'Validador', width: 185),
  (key: 'empacador', title: 'Empacador', width: 185),
  (key: 'fecha_validacion', title: 'Fecha de validación', width: 180),
  (key: 'transportadora', title: 'Vehículo / transportadora', width: 200),
  (key: 'placa_guia', title: 'Placa / guía', width: 155),
  (key: 'motivo_modificacion', title: 'Motivo de modificación', width: 240),
];
const _numeric = {
  'total_piezas',
  'cajas',
  'bolsas',
  'peso_total',
  'volumen',
  'kits_totales',
  'kits_validados',
  'kits_empacados',
  'cantidad',
  'validado',
  'items_kit',
  'items_lista',
  'items_direccion',
};
const _dates = {
  'fecha_carga',
  'ultima_validacion',
  'fecha_despacho',
  'fecha_recepcion',
  'fecha_generado',
  'fecha_validacion',
};

/// Presenta una página del maestro; las opciones y el filtrado pertenecen a la
/// consulta del servidor, no a las filas visibles de esta página.
class MasivaMaestroTabla extends StatefulWidget {
  const MasivaMaestroTabla({
    super.key,
    required this.base,
    required this.filas,
    required this.filtros,
    required this.opciones,
    required this.onFiltrosChanged,
    required this.onAbrir,
    this.seleccionadas = const {},
    this.onSeleccionChanged,
    this.cargando = false,
  });

  final bool base;
  final List<Map<String, dynamic>> filas;
  final Map<String, Set<String>> filtros;
  final Map<String, List<String>> opciones;
  final ValueChanged<Map<String, Set<String>>> onFiltrosChanged;
  final ValueChanged<Map<String, dynamic>> onAbrir;
  final Set<String> seleccionadas;
  final ValueChanged<Set<String>>? onSeleccionChanged;
  final bool cargando;

  @override
  State<MasivaMaestroTabla> createState() => _MasivaMaestroTablaState();
}

class _MasivaMaestroTablaState extends State<MasivaMaestroTabla> {
  final _horizontal = ScrollController();
  final _vertical = ScrollController();
  final _number = NumberFormat.decimalPattern('es_CO')
    ..maximumFractionDigits = 3;
  List<_Column> get _columns =>
      widget.base ? masivaBaseColumnas : masivaListadoColumnas;
  bool get _selectable => !widget.base && widget.onSeleccionChanged != null;
  Set<String> get _visibleIds => {
    for (final row in widget.filas)
      if (_id(row).isNotEmpty) _id(row),
  };

  String _id(Map<String, dynamic> row) => '${row['lista'] ?? ''}';

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  String _display(String key, dynamic value) {
    if (value == null || '$value'.trim().isEmpty) return '—';
    if (_numeric.contains(key)) {
      final number = value is num ? value : num.tryParse('$value');
      return number == null ? '$value' : _number.format(number);
    }
    if (_dates.contains(key)) {
      final date = value is DateTime ? value : DateTime.tryParse('$value');
      if (date == null) return '$value';
      // Supabase entrega instantes UTC; se presentan en la hora de Colombia.
      final local = date.isUtc ? date.subtract(const Duration(hours: 5)) : date;
      final onlyDate = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch('$value');
      return DateFormat(
        onlyDate ? 'dd/MM/yyyy' : 'dd/MM/yyyy HH:mm',
      ).format(local);
    }
    return '$value';
  }

  Future<void> _filter(_Column column) async {
    if (widget.cargando) return;
    final result = await showMultiSelectFilter<String>(
      context,
      title: column.title,
      options: widget.opciones[column.key] ?? const [],
      selected: widget.filtros[column.key] ?? const {},
      labelOf:
          (value) =>
              value.isEmpty ? 'Sin registrar' : _display(column.key, value),
    );
    if (!mounted || result == null) return;
    final next = <String, Set<String>>{
      for (final entry in widget.filtros.entries) entry.key: {...entry.value},
    };
    if (result.isEmpty) {
      next.remove(column.key);
    } else {
      next[column.key] = result;
    }
    widget.onFiltrosChanged(next);
  }

  void _select(String id, bool selected) {
    final next = {...widget.seleccionadas};
    selected ? next.add(id) : next.remove(id);
    widget.onSeleccionChanged?.call(next);
  }

  Widget _pageSelection({bool onDark = false}) {
    final ids = _visibleIds;
    final count = ids.where(widget.seleccionadas.contains).length;
    return Checkbox(
      key: const ValueKey('maestro-select-page'),
      semanticLabel: 'Seleccionar listas de esta página',
      tristate: true,
      activeColor: onDark ? AppColors.lima : _ink,
      checkColor: _ink,
      side: onDark ? const BorderSide(color: _headerText) : null,
      value:
          count == 0
              ? false
              : count == ids.length
              ? true
              : null,
      onChanged:
          widget.cargando || ids.isEmpty
              ? null
              : (_) {
                final next = {...widget.seleccionadas};
                count == ids.length ? next.removeAll(ids) : next.addAll(ids);
                widget.onSeleccionChanged?.call(next);
              },
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _line),
    ),
    child: Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 700;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _toolbar(mobile),
              if (widget.filas.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.manage_search_rounded,
                        color: _muted,
                        size: 32,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No hay registros que coincidan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _ink,
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
                )
              else if (mobile)
                ...widget.filas.map(_card)
              else
                _desktop(constraints.maxWidth),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F9FA),
                  border: Border(top: BorderSide(color: _line)),
                ),
                child: Text(
                  widget.base
                      ? 'Cada fila corresponde a una prenda de una persona. '
                          'Abre el kit para consultar su detalle completo.'
                      : 'Total piezas = cajas + bolsas. El peso estimado se calcula '
                          'con los promedios del catálogo de empaques.',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _toolbar(bool mobile) {
    final active = widget.filtros.values.where((v) => v.isNotEmpty).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            widget.base
                ? Icons.table_rows_outlined
                : Icons.inventory_2_outlined,
            color: _ink,
            size: 20,
          ),
          Text(
            widget.base ? 'Base de datos maestra' : 'Listado maestro',
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
          ),
          Text(
            '${widget.filas.length} ${widget.base ? 'prendas' : 'listas'} en esta página',
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
          if (mobile)
            PopupMenuButton<_Column>(
              tooltip: 'Filtrar columnas',
              enabled: !widget.cargando,
              onSelected: _filter,
              itemBuilder:
                  (_) => [
                    for (final column in _columns)
                      PopupMenuItem(
                        value: column,
                        child: Row(
                          children: [
                            Icon(
                              widget.filtros[column.key]?.isNotEmpty == true
                                  ? Icons.filter_alt
                                  : Icons.filter_alt_outlined,
                              size: 18,
                              color: _ink,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(column.title)),
                          ],
                        ),
                      ),
                  ],
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.filter_alt_outlined, size: 17, color: _ink),
                    SizedBox(width: 6),
                    Text(
                      'Filtrar columnas',
                      style: TextStyle(color: _ink, fontSize: 12),
                    ),
                    Icon(Icons.expand_more, size: 18, color: _ink),
                  ],
                ),
              ),
            ),
          if (!mobile)
            const Text(
              'Desliza horizontalmente para ver todas las columnas ↔',
              style: TextStyle(fontSize: 11, color: _muted),
            ),
          if (_selectable && mobile)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _pageSelection(),
                const Text(
                  'Seleccionar esta página',
                  style: TextStyle(color: _ink, fontSize: 12),
                ),
              ],
            ),
          if (_selectable && widget.seleccionadas.isNotEmpty)
            Text(
              '${widget.seleccionadas.length} listas seleccionadas',
              style: const TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (active > 0) ...[
            Text(
              '$active ${active == 1 ? 'filtro activo' : 'filtros activos'}',
              style: const TextStyle(color: _ink, fontSize: 12),
            ),
            TextButton.icon(
              onPressed:
                  widget.cargando ? null : () => widget.onFiltrosChanged({}),
              icon: const Icon(Icons.filter_alt_off_outlined, size: 17),
              label: const Text('Limpiar filtros'),
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: _ink,
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
  }

  Widget _desktop(double availableWidth) {
    final width = math.max(
      availableWidth,
      _columns.fold<double>(0, (sum, column) => sum + column.width) +
          (_selectable ? 48 : 0) +
          120,
    );
    return Scrollbar(
      controller: _horizontal,
      thumbVisibility: true,
      trackVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontal,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 15),
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              Container(
                height: 65,
                color: _ink,
                child: Row(
                  children: [
                    if (_selectable)
                      SizedBox(width: 48, child: _pageSelection(onDark: true)),
                    for (final column in _columns) _header(column),
                    const SizedBox(
                      width: 120,
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text(
                          'DETALLE',
                          style: TextStyle(
                            color: _headerText,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: math.min(widget.filas.length * 68.0, 544),
                child: Scrollbar(
                  controller: _vertical,
                  child: ListView.builder(
                    controller: _vertical,
                    itemExtent: 68,
                    itemCount: widget.filas.length,
                    itemBuilder:
                        (_, index) => _desktopRow(widget.filas[index], index),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(_Column column) {
    final active = widget.filtros[column.key]?.isNotEmpty == true;
    return SizedBox(
      width: column.width,
      height: double.infinity,
      child: InkWell(
        key: ValueKey('maestro-filter-${column.key}'),
        onTap: widget.cargando ? null : () => _filter(column),
        child: Tooltip(
          message: 'Filtrar ${column.title.toLowerCase()}',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    column.title.toUpperCase(),
                    style: TextStyle(
                      color: active ? AppColors.lima : _headerText,
                      fontSize: 10.5,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
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
      ),
    );
  }

  Widget _desktopRow(Map<String, dynamic> row, int index) => Container(
    decoration: BoxDecoration(
      color:
          widget.seleccionadas.contains(_id(row)) && _selectable
              ? const Color(0xFFF4F7DB)
              : index.isEven
              ? Colors.white
              : const Color(0xFFFAFCFC),
      border: const Border(bottom: BorderSide(color: _line)),
    ),
    child: Row(
      children: [
        if (_selectable) SizedBox(width: 48, child: _rowSelection(row)),
        for (final column in _columns)
          SizedBox(
            width: column.width,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child:
                  column.key == 'estado'
                      ? _status(row['estado'])
                      : Tooltip(
                        message: _display(column.key, row[column.key]),
                        child: Text(
                          _display(column.key, row[column.key]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign:
                              _numeric.contains(column.key)
                                  ? TextAlign.right
                                  : TextAlign.left,
                          style: TextStyle(
                            color: _ink,
                            fontSize: 12,
                            fontWeight:
                                column.key == 'lista' || column.key == 'sku'
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                          ),
                        ),
                      ),
            ),
          ),
        SizedBox(
          width: 120,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _open(row),
          ),
        ),
      ],
    ),
  );

  Widget _rowSelection(Map<String, dynamic> row) => Checkbox(
    key: ValueKey('maestro-select-${_id(row)}'),
    semanticLabel: 'Seleccionar lista ${_id(row)}',
    value: widget.seleccionadas.contains(_id(row)),
    activeColor: _ink,
    onChanged:
        widget.cargando || _id(row).isEmpty
            ? null
            : (value) => _select(_id(row), value == true),
  );

  Widget _status(dynamic value) {
    final text = _display('estado', value);
    final normalized = text.toUpperCase();
    final color =
        normalized == 'COMPLETO' || normalized == 'VALIDADO'
            ? const Color(0xFF087F56)
            : normalized.contains('PARCIAL')
            ? const Color(0xFF9B6500)
            : _muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _open(Map<String, dynamic> row) => OutlinedButton(
    key: ValueKey(
      'maestro-open-${widget.base ? row['kit_id'] ?? row['id'] : _id(row)}',
    ),
    onPressed: widget.cargando ? null : () => widget.onAbrir(row),
    style: OutlinedButton.styleFrom(
      foregroundColor: _ink,
      backgroundColor: Colors.transparent,
      minimumSize: const Size(0, 38),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      side: const BorderSide(color: _line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontFamily: 'ConductorSans',
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
    child: Text(widget.base ? 'Abrir kit' : 'Ver detalle'),
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
            if (_selectable) _rowSelection(row),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.base
                        ? _display('nombre', row['nombre'])
                        : 'Lista ${_display('lista', row['lista'])}',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _display('cliente', row['cliente']),
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: _status(row['estado'])),
        const SizedBox(height: 12),
        if (widget.base) ...[
          Text(
            'SKU ${_display('sku', row['sku'])} · Lista ${_display('lista', row['lista'])}',
            style: const TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _display('descripcion', row['descripcion']),
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F6F7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item
                  in widget.base
                      ? [
                        ('Cantidad', 'cantidad'),
                        ('Validada', 'validado'),
                        ('Persona', 'numero_persona'),
                      ]
                      : [
                        ('Kits', 'kits_totales'),
                        ('Validados', 'kits_validados'),
                        ('Empacados', 'kits_empacados'),
                      ])
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$1,
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _display(item.$2, row[item.$2]),
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: ValueKey(
              'maestro-details-${widget.base ? row['id'] ?? row['sku'] : _id(row)}',
            ),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            title: const Text(
              'Ver todos los datos',
              style: TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            iconColor: _ink,
            collapsedIconColor: _muted,
            children: [
              for (final column in _columns)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          column.title,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _display(column.key, row[column.key]),
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Align(alignment: Alignment.centerRight, child: _open(row)),
      ],
    ),
  );
}
