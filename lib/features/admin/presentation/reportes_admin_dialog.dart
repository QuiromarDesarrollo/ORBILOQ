import '../../../data/trazabilidad_op_exportador.dart';
import 'package:orbiloq_wms/shared/widgets/wms_alert.dart';
import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../core/utils/fecha.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/providers.dart';
import '../../../application/auth_providers.dart';
import '../../../domain/sesion.dart';
import '../../../data/reportes_admin_repository.dart';
import '../../../data/kardex_excel_exportador.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showReportesAdminDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const ReportesAdminDialog());

class ReportesAdminDialog extends ConsumerStatefulWidget {
  const ReportesAdminDialog({super.key});
  @override
  ConsumerState<ReportesAdminDialog> createState() => _ReportesState();
}

class _ReportesState extends ConsumerState<ReportesAdminDialog> {
  String _vista = 'resumen', _dimension = 'causal';
  final _op = TextEditingController(),
      _persona = TextEditingController(),
      _cliente = TextEditingController(),
      _causal = TextEditingController(),
      _tipo = TextEditingController();
  DateTimeRange? _rango;
  List<FilaReporte> _filas = [], _movimientosHoy = [];
  DateTime? _consultado;
  String? _errorMovimientos;
  FilaReporte _metricas = {};
  bool _cargando = false, _exportando = false;
  String? _error;
  int _pagina = 0, _solicitud = 0;
  bool get _admin =>
      !ref.read(usarSupabaseProvider) ||
      ref.read(usuarioSesionProvider).value?.rolCuenta == RolCuenta.admin;
  @override
  void initState() {
    super.initState();
    Future.microtask(_cargar);
  }

  @override
  void dispose() {
    for (final c in [_op, _persona, _cliente, _causal, _tipo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    if (!mounted || !_admin) return;
    final turno = ++_solicitud;
    setState(() {
      _cargando = true;
      _error = null;
      _filas = [];
      _metricas = {};
      _pagina = 0;
    });
    try {
      final repo = ref.read(reportesAdminProvider);
      if (repo == null) {
        throw const FormatException(
          'Reportes disponibles al conectar Supabase de pruebas y aplicar el SQL 062.',
        );
      }
      if (_vista == 'resumen') {
        final datos = await repo.resumen();
        if (!mounted || turno != _solicitud) return;
        setState(() {
          _metricas = datos;
          _consultado =
              fechaReporte(datos['actualizado_en']) ??
              fechaReporte(DateTime.now().toUtc().toIso8601String());
        });
        try {
          final movimientos = await repo.cargar('movimientos');
          if (!mounted || turno != _solicitud) return;
          setState(() {
            _movimientosHoy = filtrarReporte(
              movimientos,
              desde: _consultado,
              hasta: _consultado,
            );
            _errorMovimientos = null;
          });
        } catch (_) {
          if (mounted && turno == _solicitud) {
            setState(
              () =>
                  _errorMovimientos =
                      'No se pudieron cargar los movimientos de hoy.',
            );
          }
        }
      } else {
        final datos = await repo.cargar(_vista);
        if (!mounted || turno != _solicitud) return;
        setState(() {
          _filas = datos;
          _consultado = fechaReporte(DateTime.now().toUtc().toIso8601String());
        });
      }
    } catch (e) {
      if (mounted && turno == _solicitud) {
        setState(
          () =>
              _error =
                  'No se pudo cargar el reporte. Verifica que el SQL 062 esté aplicado en pruebas. $e',
        );
      }
    } finally {
      if (mounted && turno == _solicitud) setState(() => _cargando = false);
    }
  }

  List<FilaReporte> get _visibles =>
      filtrarReporte(
            _filas,
            op: _op.text,
            persona: _persona.text,
            cliente: _cliente.text,
            causal: _causal.text,
            tipo: _tipo.text,
            desde: _rango?.start,
            hasta: _rango?.end,
          )
          .where(
            (f) => [
              (_persona, 'persona'),
              (_cliente, 'cliente'),
              (_causal, 'causal'),
              (_tipo, 'tipo'),
            ].every(
              (e) =>
                  e.$1.text.isEmpty ||
                  _valor(f, e.$2).toLowerCase() == e.$1.text.toLowerCase(),
            ),
          )
          .toList();
  void _limpiar() {
    setState(() {
      for (final c in [_op, _persona, _cliente, _causal, _tipo]) {
        c.clear();
      }
      _rango = null;
      _pagina = 0;
    });
  }

  Future<void> _fechas() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      initialDateRange: _rango,
      helpText: 'Fechas del reporte',
      saveText: 'Aplicar',
      builder:
          (context, child) => Theme(
            data: Theme.of(context).copyWith(
              datePickerTheme: DatePickerTheme.of(context).copyWith(
                rangePickerHeaderHeadlineStyle: const TextStyle(fontSize: 16),
              ),
            ),
            child: child!,
          ),
    );
    if (r != null && mounted) {
      setState(() {
        _rango = r;
        _pagina = 0;
      });
    }
  }

  String _texto(dynamic v) =>
      v is Map || v is List ? jsonEncode(v) : '${v ?? ''}';
  List<List<Object?>> _hoja(List<FilaReporte> filas, List<String> campos) => [
    campos,
    for (final f in filas)
      [for (final c in campos) f[c] is num ? f[c] : _texto(f[c])],
  ];
  Future<void> _exportarTrazabilidad() async {
    if (!_admin || _exportando) return;
    setState(() => _exportando = true);
    try {
      final repo = ref.read(reportesAdminProvider);
      if (repo == null) {
        throw const FormatException(
          'Conecta la base de datos para exportar la trazabilidad.',
        );
      }
      final filas = await repo.trazabilidadOp();
      if (!mounted) return;
      await KardexExcelExportador.exportarReporte(
        'orbiloq_trazabilidad_op',
        hojasTrazabilidadOp(filas),
      );
    } catch (e) {
      if (mounted) {
        await mostrarAviso(
          context,
          'No se pudo exportar la trazabilidad. $e',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<void> _exportar() async {
    if (!_admin) return;
    setState(() => _exportando = true);
    try {
      final hojas = <String, List<List<Object?>>>{};
      if (_vista == 'resumen') {
        hojas['Resumen'] = [
          ['Métrica', 'Valor'],
          for (final e in _metricas.entries) [e.key, e.value],
        ];
      } else {
        final visibles = _visibles;
        hojas['Detalle'] = _hoja(visibles, _columnas);
        if (_vista == 'movimientos') {
          final crudos =
              visibles
                  .map(
                    (f) => Map<String, dynamic>.from(f['datos_crudos'] as Map),
                  )
                  .toList();
          final campos = crudos.expand((f) => f.keys).toSet().toList()..sort();
          hojas['Movimientos originales'] = _hoja(crudos, campos);
        }
        if (_vista == 'nc') {
          for (final d in [
            'causal',
            'persona',
            'cliente',
            'contraparte',
            'mes',
            'origen',
          ]) {
            hojas['Por $d'] = _hoja(resumirNoConforme(visibles, d), [
              'grupo',
              'reportes',
              'unidades',
            ]);
          }
        }
      }
      hojas['Criterios'] = [
        ['Criterio', 'Valor'],
        ['Reporte', _vista],
        ['Generado', DateTime.now().toUtc().toIso8601String()],
        ['Zona horaria', 'America/Bogota (UTC-5)'],
        ['OP o código', _op.text],
        ['Persona', _persona.text],
        ['Cliente', _cliente.text],
        ['Causal', _causal.text],
        ['Tipo', _tipo.text],
        ['Desde', _rango?.start.toIso8601String()],
        ['Hasta', _rango?.end.toIso8601String()],
        ['Alcance', 'Todas las coincidencias, no solo la página visible.'],
        [
          'Nota',
          'Operario reportante no implica responsable del defecto. Auditoría reúne fuentes y no debe sumarse como movimientos de stock.',
        ],
        [
          'Resumen',
          'OP activas: con unidades pendientes de despacho o NC. Atrasadas: fecha esperada vencida y saldo pendiente. Excluye líneas ocultas; sobrantes incluye todos los pendientes.',
        ],
      ];
      await KardexExcelExportador.exportarReporte('orbiloq_$_vista', hojas);
    } catch (e) {
      if (mounted) {
        mostrarAvisoSnack(
          context,
          SnackBar(content: Text('No se pudo exportar: $e')),
          tipo: TipoAviso.error,
        );
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  static const _columnas = [
    'fecha',
    'op',
    'codigo',
    'producto',
    'talla',
    'cliente',
    'persona',
    'origen',
    'tipo',
    'cantidad',
    'causal',
    'contraparte',
    'detalle',
    'registro',
  ];

  static const _navy = Color(0xff123e4f),
      _green = Color(0xff21805a),
      _border = Color(0xffdce6eb),
      _soft = Color(0xfff4f8f9);
  static const _criterios =
      'Cada OP cuenta una vez, sin duplicar por talla. Activas: con unidades pendientes de despacho o No Conforme. Atrasadas: producción o despacho pendiente con fecha esperada vencida. Sin fecha esperada no se clasifica como atraso. Se excluyen líneas ocultas; los sobrantes incluyen todos los pendientes.';
  void _cambiar(String vista) {
    setState(() => _vista = vista);
    _limpiar();
    _cargar();
  }

  Widget _panel(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Material(color: Colors.transparent, child: child),
  );
  Color _color(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('liber')) return const Color(0xff7057bd);
    if (t.contains('devol')) return const Color(0xffbe8500);
    if (t.contains('conforme') || t.contains('reporte')) {
      return const Color(0xffbc3434);
    }
    if (t.contains('recep')) return _green;
    if (t.contains('produ')) return const Color(0xff3187ae);
    return _navy;
  }

  Widget _chip(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: _color(t).withValues(alpha: .1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      t,
      style: TextStyle(
        color: _color(t),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
  String _valor(FilaReporte f, String k) =>
      '${f[k] ?? ''}'.trim().isEmpty ? 'Sin registrar' : '${f[k]}';
  int get _filtros =>
      [
        _persona,
        _cliente,
        _causal,
        _tipo,
      ].where((c) => c.text.isNotEmpty).length +
      (_rango == null ? 0 : 1);
  @override
  Widget build(BuildContext context) {
    final admin =
        !ref.watch(usarSupabaseProvider) ||
        ref.watch(usuarioSesionProvider).value?.rolCuenta == RolCuenta.admin;
    if (!admin) {
      return const WmsDialogShell(
        title: 'Reportes',
        iconColor: Colors.teal,
        icon: Icons.lock,
        child: Text('Acceso exclusivo del administrador.'),
      );
    }
    final movil =
        MediaQuery.sizeOf(context).width < 650 ||
        MediaQuery.sizeOf(context).height < 500;
    final visibles = _visibles;
    return WmsDialogShell(
      title: 'Reportes y auditoría',
      subtitle:
          movil
              ? 'Trazabilidad de cada prenda'
              : 'Quién hizo qué, cuándo y cuántas · Horas de Bogotá',
      icon: Icons.analytics_outlined,
      iconColor: _navy,
      expand: true,
      mobileCatalog: true,
      maxWidth: 1400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _consultado == null
                      ? 'Consultando…'
                      : 'Consultado ${formatFechaHora(_consultado)} · Bogotá',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
              IconButton(
                tooltip: 'Actualizar reporte',
                onPressed: _cargando ? null : _cargar,
                icon: const Icon(Icons.refresh, size: 18),
              ),
              if (movil)
                IconButton(
                  tooltip: 'Exportar trazabilidad de OP a Excel',
                  onPressed: _exportando ? null : _exportarTrazabilidad,
                  icon: const Icon(Icons.table_view_outlined, size: 18),
                )
              else
                TextButton.icon(
                  onPressed: _exportando ? null : _exportarTrazabilidad,
                  icon: const Icon(Icons.table_view_outlined, size: 18),
                  label: const Text('Trazabilidad OP'),
                ),
              if (movil)
                IconButton(
                  tooltip: 'Exportar reporte a Excel',
                  onPressed:
                      _cargando || _exportando || _error != null
                          ? null
                          : _exportar,
                  icon: const Icon(Icons.download_outlined, size: 18),
                )
              else
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                  ),
                  onPressed:
                      _cargando || _exportando || _error != null
                          ? null
                          : _exportar,
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: Text(_exportando ? 'Exportando…' : 'Exportar a Excel'),
                ),
            ],
          ),
          Row(
            children: [
              for (final t in [
                ('resumen', movil ? 'Métricas' : 'Métricas globales'),
                ('movimientos', 'Movimientos'),
                ('auditoria', movil ? 'Personas' : 'Actividad por persona'),
                ('nc', 'No conforme'),
              ])
                Expanded(
                  child: InkWell(
                    key: ValueKey('reporte-${t.$1}'),
                    onTap: _exportando ? null : () => _cambiar(t.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _vista == t.$1 ? _navy : _border,
                            width: _vista == t.$1 ? 2 : 1,
                          ),
                        ),
                      ),
                      child: Text(
                        t.$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: movil ? 10 : 12,
                          color: _navy,
                          fontWeight:
                              _vista == t.$1
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child:
                _cargando
                    ? const WmsLoadingPanel()
                    : _error != null
                    ? Center(
                      child: TextButton(
                        onPressed: _cargar,
                        child: Text(_error!),
                      ),
                    )
                    : ListView(
                      padding: const EdgeInsets.only(top: 12),
                      children: [
                        if (_vista == 'resumen')
                          _resumen()
                        else ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _op,
                                  onChanged: (_) => setState(() => _pagina = 0),
                                  decoration: const InputDecoration(
                                    hintText: 'Buscar OP o código',
                                    prefixIcon: Icon(Icons.search, size: 18),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              if (movil) ...[
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: _abrirFiltros,
                                  icon: const Icon(Icons.filter_list, size: 16),
                                  label: Text(
                                    'Filtros${_filtros == 0 ? '' : ' $_filtros'}',
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (!movil)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: _controles(),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${visibles.length} registros coincidentes · ${_rango == null ? 'Todas las fechas' : '${formatFecha(_rango!.start)} – ${formatFecha(_rango!.end)}'}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                if (_filtros > 0 || _op.text.isNotEmpty)
                                  TextButton(
                                    onPressed: _limpiar,
                                    child: const Text('Limpiar filtros'),
                                  ),
                              ],
                            ),
                          ),
                          if (_vista == 'auditoria') _personas(),
                          if (_vista == 'nc') _causales(visibles),
                          _tabla(visibles),
                        ],
                      ],
                    ),
          ),
          if (_vista != 'resumen' && !_cargando && _error == null)
            _paginacion(visibles.length),
        ],
      ),
    );
  }

  Widget _selector(TextEditingController c, String campo, String etiqueta) {
    final opciones =
        _filas.map((f) => _valor(f, campo)).toSet().toList()..sort();
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String>(
        key: ValueKey('$campo-${c.text}'),
        initialValue: opciones.contains(c.text) ? c.text : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: etiqueta, isDense: true),
        items: [
          const DropdownMenuItem(value: '', child: Text('Todas')),
          for (final o in opciones)
            DropdownMenuItem(
              value: o,
              child: Text(o, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged:
            (v) => setState(() {
              c.text = v ?? '';
              _pagina = 0;
            }),
      ),
    );
  }

  Widget _controles() => Wrap(
    spacing: 8,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      _selector(_persona, 'persona', 'Persona'),
      _selector(_cliente, 'cliente', 'Cliente'),
      if (_vista == 'nc') _selector(_causal, 'causal', 'Causal'),
      _selector(_tipo, 'tipo', 'Tipo de actividad'),
      OutlinedButton.icon(
        onPressed: _fechas,
        icon: const Icon(Icons.calendar_today_outlined, size: 16),
        label: const Text('Elegir fechas'),
      ),
      TextButton(
        onPressed:
            () => setState(() {
              final d = fechaReporte(DateTime.now().toUtc().toIso8601String())!;
              _rango = DateTimeRange(
                start: DateTime(d.year, d.month, d.day),
                end: DateTime(d.year, d.month, d.day),
              );
              _pagina = 0;
            }),
        child: const Text('Hoy'),
      ),
      if (_rango != null)
        TextButton(
          onPressed:
              () => setState(() {
                _rango = null;
                _pagina = 0;
              }),
          child: const Text('Quitar fecha'),
        ),
    ],
  );
  Future<void> _abrirFiltros() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, cambiar) => SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      16 + MediaQuery.viewInsetsOf(ctx).bottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Filtros del reporte',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _controles(),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Ver resultados'),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
    if (mounted) setState(() {});
  }

  Widget _resumen() {
    const metricas = [
      (
        'op_activas',
        'OP activas',
        'Con unidades pendientes de despacho o de No Conforme.',
      ),
      (
        'op_atrasadas',
        'OP atrasadas',
        'Fecha esperada vencida y saldo pendiente. Sin fecha no cuenta.',
      ),
      (
        'op_no_conforme',
        'OP con No Conforme pendiente',
        'OP con prendas reportadas sin liberar ni devolver.',
      ),
      (
        'sobrantes_pendientes',
        'Sobrantes sin resolver',
        'Prendas de más que nadie ha resuelto.',
      ),
      (
        'unidades_sobrantes',
        'Unidades sobrantes pendientes',
        'Total de prendas sobrantes de todos los pendientes.',
      ),
    ];
    final tipos = <String, int>{};
    for (final f in _movimientosHoy) {
      tipos.update(
        _valor(f, 'tipo'),
        (n) => n + ((f['cantidad'] as num?)?.toInt() ?? 0),
        ifAbsent: () => (f['cantidad'] as num?)?.toInt() ?? 0,
      );
    }
    final mayor = tipos.values.fold<int>(1, (a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder:
              (context, c) => Wrap(
                spacing: 8,
                runSpacing: 0,
                children: [
                  for (final m in metricas)
                    SizedBox(
                      width:
                          c.maxWidth < 650
                              ? m.$1 == 'unidades_sobrantes'
                                  ? c.maxWidth
                                  : (c.maxWidth - 8) / 2
                              : (c.maxWidth - 32) / 5,
                      child: _panel(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 42,
                              child: Text(
                                m.$2,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Text(
                              '${_metricas[m.$1] ?? '–'}',
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                                color:
                                    (_metricas[m.$1] ?? 0) == 0
                                        ? _green
                                        : _navy,
                              ),
                            ),
                            _chip(
                              m.$1 == 'op_activas'
                                  ? 'En curso'
                                  : (_metricas[m.$1] ?? 0) == 0
                                  ? 'Sin pendientes'
                                  : 'Por revisar',
                            ),
                            if (c.maxWidth >= 650)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  m.$3,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
        ),
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Movimientos de hoy por tipo',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ver movimientos',
                    onPressed: () {
                      _cambiar('movimientos');
                      final d = _consultado ?? DateTime.now();
                      setState(
                        () =>
                            _rango = DateTimeRange(
                              start: DateTime(d.year, d.month, d.day),
                              end: DateTime(d.year, d.month, d.day),
                            ),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward, size: 18),
                  ),
                ],
              ),
              if (_errorMovimientos != null)
                Text(_errorMovimientos!)
              else if (tipos.isEmpty)
                const Text('No hay movimientos registrados hoy.')
              else
                for (final t in tipos.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                t.key,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Text(
                              '${t.value} uds',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        LinearProgressIndicator(
                          value: (t.value / mayor).clamp(0, 1),
                          color: _color(t.key),
                          backgroundColor: _soft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        _panel(
          const ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Cómo se cuentan estas cifras',
              style: TextStyle(fontSize: 12),
            ),
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(_criterios, style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _personas() {
    final personas = <String, int>{};
    for (final f in _filas) {
      personas.update(_valor(f, 'persona'), (n) => n + 1, ifAbsent: () => 1);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final p in personas.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                  child: ActionChip(
                    avatar: CircleAvatar(child: Text(p.key.substring(0, 1))),
                    label: Text('${p.key} · ${p.value} registros'),
                    onPressed:
                        () => setState(() {
                          _persona.text = _persona.text == p.key ? '' : p.key;
                          _pagina = 0;
                        }),
                  ),
                ),
            ],
          ),
        ),
        _panel(
          const Text(
            'Una acción puede aparecer en varias fuentes. No sumes estas cantidades como inventario. Sin registrar significa que la fuente no identifica a quien hizo la acción. En recepciones se muestra el último acumulado por línea.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _causales(List<FilaReporte> filas) {
    final grupos = resumirNoConforme(filas, _dimension);
    final total = grupos.fold<int>(0, (n, g) => n + (g['unidades'] as int));
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButton<String>(
            value: _dimension,
            isExpanded: true,
            items: [
              for (final d
                  in {
                    'causal': 'Por causal',
                    'persona': 'Por operario reportante',
                    'cliente': 'Por cliente',
                    'contraparte': 'Por persona relacionada',
                    'mes': 'Tendencia mensual',
                    'origen': 'Por origen',
                  }.entries)
                DropdownMenuItem(value: d.key, child: Text(d.value)),
            ],
            onChanged: (v) => setState(() => _dimension = v!),
          ),
          for (final g in grupos)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${g['grupo']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Text(
                        '${g['unidades']} uds · ${g['reportes']} reportes',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: total <= 0 ? 0 : (g['unidades'] as int) / total,
                    color: const Color(0xffbc3434),
                    backgroundColor: _soft,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Cuenta reportes y unidades reportadas; no es tasa de defectos. Quien reporta no necesariamente causó el defecto.',
            style: TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _originalBoton(FilaReporte f) => IconButton(
    tooltip: 'Ver registro original',
    onPressed: () => _original(f),
    icon: const Icon(Icons.data_object, size: 18),
  );
  Widget _prenda(FilaReporte f) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'OP ${f['op'] ?? '–'} · Talla ${f['talla'] ?? '–'}',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
      Text(
        '${f['producto'] ?? ''} · ${f['cliente'] ?? ''}',
        style: const TextStyle(fontSize: 11),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );
  Widget _tabla(List<FilaReporte> filas) {
    if (filas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Sin registros para los filtros seleccionados.'),
      );
    }
    final pagina = filas.skip(_pagina * 50).take(50);
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 850) {
          return Column(
            children: [
              for (final f in pagina)
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _chip(
                                  _vista == 'nc'
                                      ? _valor(f, 'causal')
                                      : _valor(f, 'tipo'),
                                ),
                                Text(
                                  formatFechaHora(fechaReporte(f['fecha'])),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          _originalBoton(f),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(child: _prenda(f)),
                          Text(
                            '${f['cantidad'] ?? '–'} uds',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Por ${_valor(f, 'persona')}${_vista == 'auditoria' || _vista == 'nc' ? ' · ${_valor(f, 'origen')}' : ''}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      if ('${f['contraparte'] ?? ''}'.isNotEmpty)
                        Text(
                          'Recibido de: ${f['contraparte']}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      if ('${f['detalle'] ?? ''}'.isNotEmpty)
                        Text(
                          '${f['detalle']}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      if (_vista == 'nc' &&
                          f['datos_crudos'] is Map &&
                          f['datos_crudos']['estado'] != null)
                        _chip('${f['datos_crudos']['estado']}'),
                    ],
                  ),
                ),
            ],
          );
        }
        Widget celda(Widget child) =>
            Padding(padding: const EdgeInsets.all(9), child: child);
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(2.3),
              2: FlexColumnWidth(1.6),
              3: FlexColumnWidth(.6),
              4: FlexColumnWidth(1.3),
              5: FlexColumnWidth(2),
              6: FixedColumnWidth(44),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: const TableBorder(
              horizontalInside: BorderSide(color: _border),
            ),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: _soft),
                children: [
                  for (final h in [
                    'FECHA',
                    'PRENDA',
                    _vista == 'nc' ? 'CAUSAL' : 'ACTIVIDAD',
                    'CANT.',
                    'PERSONA',
                    _vista == 'auditoria' ? 'ORIGEN · DETALLE' : 'DETALLE',
                    '',
                  ])
                    celda(
                      Text(
                        h,
                        style: const TextStyle(fontSize: 10, color: _navy),
                      ),
                    ),
                ],
              ),
              for (final f in pagina)
                TableRow(
                  children: [
                    celda(
                      Text(
                        formatFechaHora(fechaReporte(f['fecha'])),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    celda(_prenda(f)),
                    celda(
                      _chip(
                        _vista == 'nc'
                            ? _valor(f, 'causal')
                            : _valor(f, 'tipo'),
                      ),
                    ),
                    celda(Text('${f['cantidad'] ?? '–'}')),
                    celda(
                      Text(
                        _valor(f, 'persona'),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    celda(
                      Text(
                        '${_vista == 'auditoria' ? '${f['origen']} · ' : ''}${f['detalle'] ?? ''}${_vista == 'nc' ? '\nRecibido de: ${f['contraparte'] ?? 'Sin registrar'}' : ''}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    _originalBoton(f),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _original(FilaReporte f) async {
    final crudo = f['datos_crudos'];
    final json = const JsonEncoder.withIndent('  ').convert(crudo);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder:
          (ctx) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * .85,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Registro original',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              spacing: 8,
                              children: [
                                _chip(_valor(f, 'tipo')),
                                Text(
                                  '${formatFechaHora(fechaReporte(f['fecha']))} · Bogotá',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _panel(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${f['cantidad'] ?? '–'} prendas · ${_valor(f, 'persona')}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('${f['detalle'] ?? 'Sin nota'}'),
                                ],
                              ),
                            ),
                            const Text(
                              'REFERENCIAS INTERNAS',
                              style: TextStyle(fontSize: 11),
                            ),
                            if (crudo is Map)
                              for (final e in crudo.entries.where(
                                (e) =>
                                    '${e.key}' == 'id' ||
                                    '${e.key}'.endsWith('_id'),
                              ))
                                Row(
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${e.key}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                            SelectableText(
                                              '${e.value ?? 'Sin valor'}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Copiar ${e.key}',
                                      onPressed:
                                          e.value == null
                                              ? null
                                              : () => Clipboard.setData(
                                                ClipboardData(
                                                  text: '${e.value}',
                                                ),
                                              ),
                                      icon: const Icon(
                                        Icons.copy_outlined,
                                        size: 16,
                                      ),
                                    ),
                                  ],
                                ),
                            ExpansionTile(
                              title: Text(
                                'Ver las ${crudo is Map ? crudo.length : ''} propiedades en JSON',
                                style: const TextStyle(fontSize: 12),
                              ),
                              children: [
                                SelectableText(
                                  json,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                () => Clipboard.setData(
                                  ClipboardData(text: json),
                                ),
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copiar JSON'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cerrar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _paginacion(int cantidad) => Row(
    children: [
      Expanded(
        child: Text(
          'Página ${_pagina + 1} de ${cantidad == 0 ? 1 : ((cantidad - 1) ~/ 50) + 1} · Bogotá',
          style: const TextStyle(fontSize: 11),
        ),
      ),
      IconButton(
        tooltip: 'Página anterior',
        onPressed: _pagina > 0 ? () => setState(() => _pagina--) : null,
        icon: const Icon(Icons.chevron_left),
      ),
      IconButton(
        tooltip: 'Página siguiente',
        onPressed:
            (_pagina + 1) * 50 < cantidad
                ? () => setState(() => _pagina++)
                : null,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}
