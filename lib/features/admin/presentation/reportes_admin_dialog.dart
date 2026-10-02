import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';
import 'dart:convert';
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
  List<FilaReporte> _filas = [];
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
            'Reportes disponibles al conectar Supabase de pruebas y aplicar el SQL 062.');
      }
      if (_vista == 'resumen') {
        final datos = await repo.resumen();
        if (!mounted || turno != _solicitud) return;
        setState(() => _metricas = datos);
      } else {
        final datos = await repo.cargar(_vista);
        if (!mounted || turno != _solicitud) return;
        setState(() => _filas = datos);
      }
    } catch (e) {
      if (mounted && turno == _solicitud) {
        setState(() => _error =
            'No se pudo cargar el reporte. Verifica que el SQL 062 esté aplicado en pruebas. $e');
      }
    } finally {
      if (mounted && turno == _solicitud) setState(() => _cargando = false);
    }
  }

  List<FilaReporte> get _visibles => filtrarReporte(_filas,
      op: _op.text,
      persona: _persona.text,
      cliente: _cliente.text,
      causal: _causal.text,
      tipo: _tipo.text,
      desde: _rango?.start,
      hasta: _rango?.end);
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
        builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
                datePickerTheme: DatePickerTheme.of(context).copyWith(
                    rangePickerHeaderHeadlineStyle:
                        const TextStyle(fontSize: 16))),
            child: child!));
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
  Future<void> _exportar() async {
    if (!_admin) return;
    setState(() => _exportando = true);
    try {
      final hojas = <String, List<List<Object?>>>{};
      if (_vista == 'resumen') {
        hojas['Resumen'] = [
          ['Métrica', 'Valor'],
          for (final e in _metricas.entries) [e.key, e.value]
        ];
      } else {
        final visibles = _visibles;
        hojas['Detalle'] = _hoja(visibles, _columnas);
        if (_vista == 'movimientos') {
          final crudos = visibles
              .map((f) => Map<String, dynamic>.from(f['datos_crudos'] as Map))
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
            'origen'
          ]) {
            hojas['Por $d'] = _hoja(resumirNoConforme(visibles, d),
                ['grupo', 'reportes', 'unidades']);
          }
        }
      }
      hojas['Criterios'] = [
        ['Criterio', 'Valor'],
        ['Reporte', _vista],
        ['Generado', DateTime.now().toUtc().toIso8601String()],
        ['Zona horaria', 'America/Bogota (UTC-5)'],
        ['OP', _op.text],
        ['Persona', _persona.text],
        ['Cliente', _cliente.text],
        ['Causal', _causal.text],
        ['Tipo', _tipo.text],
        ['Desde', _rango?.start.toIso8601String()],
        ['Hasta', _rango?.end.toIso8601String()],
        ['Alcance', 'Todas las coincidencias, no solo la página visible.'],
        [
          'Nota',
          'Operario reportante no implica responsable del defecto. Auditoría reúne fuentes y no debe sumarse como movimientos de stock.'
        ],
        [
          'Resumen',
          'OP activas: con unidades pendientes de despacho o NC. Atrasadas: fecha esperada vencida y saldo pendiente. Excluye líneas ocultas; sobrantes incluye todos los pendientes.'
        ]
      ];
      await KardexExcelExportador.exportarReporte('orbiloq_$_vista', hojas);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo exportar: $e')));
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
    'registro'
  ];
  @override
  Widget build(BuildContext context) {
    final admin = !ref.watch(usarSupabaseProvider) ||
        ref.watch(usuarioSesionProvider).value?.rolCuenta == RolCuenta.admin;
    if (!admin) {
      return const WmsDialogShell(
          title: 'Reportes',
          iconColor: Colors.teal,
          icon: Icons.lock,
          child: Text('Acceso exclusivo del administrador.'));
    }
    final visibles = _visibles;
    return WmsDialogShell(
        title: 'REPORTES Y AUDITORÍA',
        iconColor: Colors.teal,
        icon: Icons.analytics_outlined,
        expand: true,
        maxWidth: 1400,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .35),
              child: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                              width: 240,
                              child: DropdownButtonFormField<String>(
                                  initialValue: _vista,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                      labelText: 'Reporte'),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'resumen',
                                        child: Text('Métricas globales')),
                                    DropdownMenuItem(
                                        value: 'movimientos',
                                        child: Text('Movimientos completos')),
                                    DropdownMenuItem(
                                        value: 'nc',
                                        child: Text('No Conforme consolidado')),
                                    DropdownMenuItem(
                                        value: 'auditoria',
                                        child: Text('Actividad por persona'))
                                  ],
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setState(() => _vista = v);
                                    _limpiar();
                                    _cargar();
                                  })),
                          IconButton(
                              tooltip: 'Actualizar reporte',
                              onPressed: _cargando ? null : _cargar,
                              icon: const Icon(Icons.refresh)),
                          OutlinedButton.icon(
                              onPressed:
                                  _cargando || _exportando || _error != null
                                      ? null
                                      : _exportar,
                              icon: const Icon(Icons.download),
                              label: Text(_exportando
                                  ? 'Exportando…'
                                  : 'Exportar reporte a Excel')),
                        ]),
                    const SizedBox(height: 8),
                    if (_vista != 'resumen')
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _campo(_op, 'OP'),
                        _campo(_persona, 'Persona / operario'),
                        _campo(_cliente, 'Cliente'),
                        if (_vista == 'nc') _campo(_causal, 'Causal'),
                        _campo(_tipo, 'Tipo de actividad'),
                        OutlinedButton.icon(
                            onPressed: _fechas,
                            icon: const Icon(Icons.date_range),
                            label: Text(_rango == null
                                ? 'Filtrar fechas'
                                : '${_rango!.start.day}/${_rango!.start.month}/${_rango!.start.year} – ${_rango!.end.day}/${_rango!.end.month}/${_rango!.end.year}')),
                        if (_rango != null)
                          IconButton(
                              tooltip: 'Quitar fecha',
                              onPressed: () => setState(() {
                                    _rango = null;
                                    _pagina = 0;
                                  }),
                              icon: const Icon(Icons.event_busy)),
                        TextButton(
                            onPressed: _limpiar,
                            child: const Text('Limpiar filtros')),
                      ]),
                    if (_vista != 'resumen')
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                              '${visibles.length} registros coincidentes · Fechas de Bogotá · La exportación incluye todas las coincidencias.',
                              style: const TextStyle(fontSize: 12))),
                  ]))),
          if (_cargando)
            const Expanded(child: Center(child: WmsLoader()))
          else if (_error != null)
            Expanded(child: SingleChildScrollView(child: Text(_error!)))
          else if (_vista == 'resumen')
            Expanded(child: _resumen())
          else
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Expanded(
                      child: _vista == 'nc'
                          ? ListView(children: [
                              const Text(
                                  'Cantidad de reportes y unidades reportadas; no son unidades únicas ni tasa de defectos. El reportante no necesariamente causó el defecto.',
                                  style: TextStyle(fontSize: 12)),
                              DropdownButton<String>(
                                  value: _dimension,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'causal',
                                        child: Text('Por causal')),
                                    DropdownMenuItem(
                                        value: 'persona',
                                        child: Text('Por operario reportante')),
                                    DropdownMenuItem(
                                        value: 'cliente',
                                        child: Text('Por cliente')),
                                    DropdownMenuItem(
                                        value: 'contraparte',
                                        child: Text(
                                            'Por persona / Aliado relacionado')),
                                    DropdownMenuItem(
                                        value: 'mes',
                                        child: Text('Tendencia mensual')),
                                    DropdownMenuItem(
                                        value: 'origen',
                                        child: Text('Por origen'))
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _dimension = v!)),
                              for (final g
                                  in resumirNoConforme(visibles, _dimension))
                                ListTile(
                                    title: Text('${g['grupo']}'),
                                    subtitle: Text(
                                        '${g['reportes']} reportes · ${g['unidades']} Uds')),
                              const Divider(),
                              const Text('Detalle de los reportes'),
                              _tabla(visibles, embebida: true),
                            ])
                          : _tabla(visibles)),
                  _paginacion(visibles.length),
                ])),
        ]));
  }

  Widget _campo(TextEditingController controller, String label) => SizedBox(
      width: 170,
      child: TextField(
          controller: controller,
          onChanged: (_) => setState(() => _pagina = 0),
          decoration: InputDecoration(labelText: label, isDense: true)));
  Widget _resumen() {
    const etiquetas = {
      'op_activas': 'OP activas',
      'op_atrasadas': 'OP atrasadas',
      'op_no_conforme': 'OP con No Conforme pendiente',
      'sobrantes_pendientes': 'Sobrantes sin resolver',
      'unidades_sobrantes': 'Unidades sobrantes pendientes'
    };
    return ListView(children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (final e in etiquetas.entries)
          SizedBox(
              width: 230,
              child: Card(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.value),
                            Text('${_metricas[e.key] ?? 0}',
                                style: const TextStyle(
                                    fontSize: 32, fontWeight: FontWeight.bold))
                          ]))))
      ]),
      const SizedBox(height: 12),
      const Text(
          'OP únicas, sin duplicar por talla. Activas: con unidades pendientes de despacho o No Conforme. Atrasadas: entrega de Producción o despacho pendiente con fecha esperada vencida. Sin fecha esperada no se clasifica como atraso. Se excluyen líneas ocultas del kardex; los sobrantes incluyen todos los pendientes.'),
      Text(
          'Consultado: ${fechaReporte(_metricas['actualizado_en']) ?? ''} (Bogotá)'),
    ]);
  }

  Widget _tabla(List<FilaReporte> filas, {bool embebida = false}) {
    if (filas.isEmpty) {
      return const Padding(
          padding: EdgeInsets.all(20),
          child: Text('Sin registros para los filtros seleccionados.'));
    }
    final inicio = _pagina * 50;
    final pagina = filas.skip(inicio).take(50);
    final tabla = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(columns: [
          for (final c in _columnas.where((c) => c != 'registro'))
            DataColumn(label: Text(c)),
          const DataColumn(label: Text('Original'))
        ], rows: [
          for (final f in pagina)
            DataRow(cells: [
              for (final c in _columnas.where((c) => c != 'registro'))
                DataCell(SizedBox(
                    width: c == 'detalle' ? 240 : 130,
                    child: Text(
                        c == 'fecha'
                            ? '${fechaReporte(f[c]) ?? ''}'
                            : _texto(f[c]),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis))),
              DataCell(IconButton(
                  tooltip: 'Ver registro original',
                  icon: const Icon(Icons.data_object),
                  onPressed: () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                              title: const Text('Registro original'),
                              content: SingleChildScrollView(
                                  child: SelectableText(
                                      const JsonEncoder.withIndent('  ')
                                          .convert(f['datos_crudos']))),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cerrar'))
                              ])))),
            ])
        ]));
    return embebida
        ? tabla
        : SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                if (_vista == 'auditoria')
                  const Text(
                      'Fuentes operativas y auditorías. Una acción puede aparecer en varias fuentes; no sumar como stock. Sin registrar significa que la fuente no identifica al actor. Recepciones: último acumulado por línea.',
                      style: TextStyle(fontSize: 12)),
                tabla
              ]));
  }

  Widget _paginacion(int cantidad) => Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
                'Página ${_pagina + 1} de ${cantidad == 0 ? 1 : ((cantidad - 1) ~/ 50) + 1}'),
            IconButton(
                tooltip: 'Página anterior',
                onPressed: _pagina > 0 ? () => setState(() => _pagina--) : null,
                icon: const Icon(Icons.chevron_left)),
            IconButton(
                tooltip: 'Página siguiente',
                onPressed: (_pagina + 1) * 50 < cantidad
                    ? () => setState(() => _pagina++)
                    : null,
                icon: const Icon(Icons.chevron_right)),
          ]);
}
