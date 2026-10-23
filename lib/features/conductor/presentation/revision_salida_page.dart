import '../../../shared/widgets/wms_alert.dart';
import 'transporte_scaffold.dart';
import 'flota_design.dart';
import '../../../shared/widgets/wms_loader.dart';
import 'actividad_conductor_form.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../conductor_repository.dart';
import '../kit_semanal.dart';
import 'conductor_design.dart';

class RevisionSalidaPage extends ConsumerStatefulWidget {
  const RevisionSalidaPage({
    super.key,
    required this.vehiculo,
    required this.administrador,
    this.contextoVehiculo,
  });
  final String vehiculo;
  final Map<String, dynamic>? contextoVehiculo;
  final bool administrador;
  @override
  ConsumerState<RevisionSalidaPage> createState() => _RevisionSalidaPageState();
}

class _RevisionSalidaPageState extends ConsumerState<RevisionSalidaPage> {
  Map<String, dynamic>? _datos;
  String? _error;
  bool _ocupado = false;
  String _accionCarga = 'Guardando cambios…';
  bool _actualizandoHistorial = false;
  DateTimeRange? _rangoHistorial;
  String _tipoHistorial = 'Todos', _resultadoHistorial = 'Todos';

  int _contarPuntos(Map registro, String estado) =>
      ((registro['datos'] as Map?)?['respuestas'] as Map? ?? {}).values
          .where((v) => v == estado)
          .length;

  bool _coincideHistorial(Map r) {
    if (_tipoHistorial != 'Todos' && r['tipo'] != _tipoHistorial) return false;
    final respuestas = (r['datos'] as Map?)?['respuestas'] as Map?;
    if (_resultadoHistorial == 'Con novedad' &&
        _contarPuntos(r, 'Con novedad') == 0)
      return false;
    if (_resultadoHistorial == 'Sin novedades' &&
        (respuestas == null ||
            respuestas.isEmpty ||
            respuestas.values.any((v) => v != 'Buen estado')))
      return false;
    if (_rangoHistorial != null) {
      final fecha = DateTime.tryParse(
        '${(r['datos'] as Map?)?['fecha'] ?? ''}',
      );
      if (fecha == null) return false;
      final dia = DateTime(fecha.year, fecha.month, fecha.day);
      if (dia.isBefore(_rangoHistorial!.start) ||
          dia.isAfter(_rangoHistorial!.end))
        return false;
    }
    return true;
  }

  Widget _filtrosHistorial() => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      OutlinedButton.icon(
        icon: const Icon(Icons.date_range),
        label: Text(
          _rangoHistorial == null
              ? 'Fecha: todas'
              : '${fechaKit(_rangoHistorial!.start)} — ${fechaKit(_rangoHistorial!.end)}',
        ),
        onPressed: () async {
          final rango = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            initialDateRange: _rangoHistorial,
          );
          if (rango != null && mounted) setState(() => _rangoHistorial = rango);
        },
      ),
      SizedBox(
        width: 200,
        child: DropdownButtonFormField<String>(
          key: ValueKey('tipo-historial-$_tipoHistorial'),
          initialValue: _tipoHistorial,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Tipo de jornada'),
          items: [
            for (final t in ['Todos', 'Inicio de jornada', 'Fin de jornada'])
              DropdownMenuItem(value: t, child: Text(t)),
          ],
          onChanged: (v) => setState(() => _tipoHistorial = v ?? 'Todos'),
        ),
      ),
      SizedBox(
        width: 190,
        child: DropdownButtonFormField<String>(
          key: ValueKey('resultado-historial-$_resultadoHistorial'),
          initialValue: _resultadoHistorial,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Resultado'),
          items: [
            for (final t in ['Todos', 'Sin novedades', 'Con novedad'])
              DropdownMenuItem(value: t, child: Text(t)),
          ],
          onChanged: (v) => setState(() => _resultadoHistorial = v ?? 'Todos'),
        ),
      ),
      OutlinedButton.icon(
        icon: const Icon(Icons.refresh),
        label: Text(
          _actualizandoHistorial ? 'Actualizando…' : 'Actualizar historial',
        ),
        onPressed:
            _actualizandoHistorial
                ? null
                : () async {
                  setState(() => _actualizandoHistorial = true);
                  try {
                    await _cargar();
                  } finally {
                    if (mounted) setState(() => _actualizandoHistorial = false);
                  }
                },
      ),
      TextButton(
        onPressed:
            () => setState(() {
              _rangoHistorial = null;
              _tipoHistorial = 'Todos';
              _resultadoHistorial = 'Todos';
            }),
        child: const Text('Limpiar filtros'),
      ),
    ],
  );
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final datos = await ref
          .read(conductorRepositoryProvider)
          .revisionSalida(widget.vehiculo, detalle: widget.administrador);
      if (mounted) {
        setState(() {
          _datos = datos;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo consultar la revisión. Vuelve a intentar.',
        );
      }
    }
  }

  Future<void> _formActividad({Map? registro, Map? tarea}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (_) => ActividadConductorForm(
              vehiculo: widget.vehiculo,
              registro: registro,
              tarea: tarea,
            ),
      ),
    );
    if (mounted) await _cargar();
  }

  Widget _actividadesAgrupadas() {
    final tareas = List<Map>.from(_datos?['tareas'] as List? ?? []);
    if (tareas.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final grupo in const [
          ('Pendiente', 'Pendientes', Icons.assignment_outlined),
          ('Por verificar', 'Por verificar', Icons.fact_check_outlined),
          ('Cerrada', 'Completadas', Icons.task_alt),
        ])
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: ConductorDesign.line),
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              key: PageStorageKey('actividades-${grupo.$1}'),
              initiallyExpanded: grupo.$1 != 'Cerrada',
              shape: const Border(),
              collapsedShape: const Border(),
              leading: Icon(grupo.$3, color: ConductorDesign.navy),
              title: Text(
                grupo.$2,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${tareas.where((t) => t['estado'] == grupo.$1).length} actividades',
              ),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              children: [
                if (!tareas.any((t) => t['estado'] == grupo.$1))
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Sin actividades en este grupo'),
                  ),
                for (final t
                    in (tareas.where((t) => t['estado'] == grupo.$1).toList()
                      ..sort(
                        (a, b) => (a['fecha_limite']?.toString() ?? '9999')
                            .compareTo(b['fecha_limite']?.toString() ?? '9999'),
                      )))
                  _tarjetaActividad(t),
              ],
            ),
          ),
      ],
    );
  }

  Widget _tarjetaActividad(Map t) => FlotaPanel(
    compact: true,
    title: t['descripcion']?.toString() ?? 'Actividad',
    children: [
      if (t['mantenimiento_tipo'] != null) ...[
        Text(
          t['mantenimiento_tipo'].toString(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text('Trabajo asignado: ${t['mantenimiento_trabajo']}'),
      ],
      Text(
        t['registro_id'] == null
            ? 'Actividad independiente'
            : 'Motivos: ${(t['motivos'] as List? ?? [t['punto']]).join(', ')}',
      ),
      if (t['mantenimiento_datos'] is Map)
        for (final campo
            in {
              'taller': 'Taller o responsable',
              'fecha_inicio': 'Fecha de inicio',
              'hora_inicio': 'Hora de inicio',
              'fecha_fin': 'Fecha de fin',
              'hora_fin': 'Hora de fin',
              'valor': 'Valor · COP',
              'galones': 'Galones',
              'notas': 'Observaciones',
            }.entries)
          if (t['mantenimiento_datos'][campo.key]?.toString().isNotEmpty ==
              true)
            Text('${campo.value}: ${t['mantenimiento_datos'][campo.key]}'),
      Text('Fecha límite: ${t['fecha_limite'] ?? 'Sin plazo registrado'}'),
      if (t['solucion'] != null) Text('Solución: ${t['solucion']}'),
      if (t['entregado_en'] != null)
        Text('Entregada: ${_momento(t['entregado_en'])}'),
      if (t['evidencia'] != null)
        TextButton.icon(
          onPressed:
              () => launchUrl(
                Uri.parse(t['evidencia']),
                mode: LaunchMode.externalApplication,
              ),
          icon: const Icon(Icons.photo_outlined),
          label: const Text('Ver foto de la solución'),
        ),
      const SizedBox(height: 8),
      if (t['respuesta'] != null) Text('Última observación: ${t['respuesta']}'),
      const SizedBox(height: 12),
      if (t['estado'] == 'Pendiente')
        FilledButton(
          onPressed: _ocupado ? null : () => _formActividad(tarea: t),
          child: Text(
            t['mantenimiento_tipo'] != null
                ? 'Realizar mantenimiento'
                : 'Informar solución',
          ),
        ),
      if (widget.administrador && t['estado'] == 'Por verificar')
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed:
                  _ocupado
                      ? null
                      : () =>
                          _accion(t['registro_id'], 'Cerrada', tarea: t['id']),
              child: const Text('Verificar y cerrar'),
            ),
            OutlinedButton(
              onPressed:
                  _ocupado
                      ? null
                      : () => _accion(
                        t['registro_id'],
                        'Pendiente',
                        tarea: t['id'],
                      ),
              child: const Text('Solicitar corrección'),
            ),
          ],
        ),
    ],
  );

  String _momento(dynamic valor) {
    final fecha = DateTime.tryParse(valor?.toString() ?? '');
    return fecha == null
        ? 'Sin entrega'
        : '${DateFormat('dd/MM/yyyy HH:mm').format(fecha.toUtc().subtract(const Duration(hours: 5)))} · Colombia';
  }

  Future<void> _accion(
    String? registro,
    String accion, {
    String? punto,
    String? tarea,
  }) async {
    final controller = TextEditingController();
    final texto = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(accion),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (punto != null) Text(punto),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLength: 1000,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText:
                          accion == 'Crear actividad'
                              ? 'Trabajo que debe realizar el conductor'
                              : 'Observación / detalle',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    Navigator.pop(context, controller.text.trim());
                  }
                },
                child: const Text('Confirmar'),
              ),
            ],
          ),
    );
    // El diálogo termina su animación antes de liberar el controlador.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (texto == null || !mounted) return;
    setState(() {
      _ocupado = true;
      _accionCarga =
          accion == 'Cerrada'
              ? 'Validando y cerrando actividad…'
              : accion == 'Pendiente'
              ? 'Solicitando corrección de la actividad…'
              : 'Guardando autorización de salida…';
      _error = null;
    });
    try {
      await ref
          .read(conductorRepositoryProvider)
          .revisionAccion(registro, accion, texto, punto: punto, tarea: tarea);
      await _cargar();
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error =
                  e is PostgrestException
                      ? e.message
                      : e is FormatException
                      ? e.message
                      : 'No se pudo guardar. Actualiza y vuelve a intentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  List<Map> get _checklists =>
      (_datos?['checklists'] as List? ?? []).whereType<Map>().toList()..sort(
        (a, b) => '${b['datos']['fecha']}'.compareTo('${a['datos']['fecha']}'),
      );
  Map? get _inicioHoy =>
      _checklists
          .where(
            (r) =>
                r['tipo'] == 'Inicio de jornada' &&
                r['datos']['fecha'] == fechaKit(hoyColombia()),
          )
          .firstOrNull;
  int get _pendientes =>
      (_datos?['tareas'] as List? ?? [])
          .where((t) => t['estado'] == 'Pendiente')
          .length;
  int get _porVerificar =>
      (_datos?['tareas'] as List? ?? [])
          .where((t) => t['estado'] == 'Por verificar')
          .length;

  Widget _chip(String text, {bool good = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: good ? const Color(0xFFDDF3E4) : const Color(0xFFFFF1D0),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: good ? const Color(0xFF14602F) : const Color(0xFF7A4B00),
      ),
    ),
  );

  Widget _linea(String title, String subtitle, bool good) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor:
              good ? const Color(0xFFDDF3E4) : const Color(0xFFFFF1D0),
          child: Icon(
            good ? Icons.check : Icons.schedule,
            size: 20,
            color: good ? const Color(0xFF14602F) : const Color(0xFF7A4B00),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: ConductorDesign.muted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  String _estadoPunto(dynamic valor) =>
      valor is Map ? '${valor['estado'] ?? ''}' : '$valor';

  Widget _grupoChecklist(
    String titulo,
    List<MapEntry<dynamic, dynamic>> puntos, {
    required Color color,
    required IconData icono,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: ConductorDesign.line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icono, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: ConductorDesign.navy,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${puntos.length}',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (puntos.isEmpty)
          const Text(
            'No hay puntos en este grupo.',
            style: TextStyle(color: ConductorDesign.muted),
          )
        else
          LayoutBuilder(
            builder: (context, c) {
              final columnas =
                  c.maxWidth >= 520 &&
                          MediaQuery.textScalerOf(context).scale(14) < 21
                      ? 2
                      : 1;
              return Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  for (final e in puntos)
                    SizedBox(
                      width: (c.maxWidth - (columnas - 1) * 10) / columnas,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F7F8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icono, size: 17, color: color),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${e.key}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: ConductorDesign.ink,
                                    ),
                                  ),
                                  if (e.value is Map)
                                    for (final d in (e.value as Map).entries
                                        .where(
                                          (d) =>
                                              d.key != 'estado' &&
                                              d.value != null &&
                                              '${d.value}'.isNotEmpty,
                                        ))
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '${d.key}: ${d.value}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: ConductorDesign.muted,
                                          ),
                                        ),
                                      ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    ),
  );

  Future<void> _verChecklist(Map r) async {
    final puntos = (r['datos']['respuestas'] as Map? ?? {}).entries.toList();
    final novedades =
        puntos.where((e) => _estadoPunto(e.value) == 'Con novedad').toList();
    final buenos =
        puntos.where((e) => _estadoPunto(e.value) == 'Buen estado').toList();
    final otros =
        puntos
            .where(
              (e) =>
                  ![
                    'Con novedad',
                    'Buen estado',
                  ].contains(_estadoPunto(e.value)),
            )
            .toList();
    final asignar = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            clipBehavior: Clip.antiAlias,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            titlePadding: EdgeInsets.zero,
            contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            title: Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: ConductorDesign.navy,
                border: Border(
                  bottom: BorderSide(color: ConductorDesign.lime, width: 4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ConductorDesign.lime,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.fact_check_outlined,
                      color: ConductorDesign.navy,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DETALLE DE INSPECCIÓN',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            color: Color(0xFFB6D0DB),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${r['tipo']} · ${r['datos']['fecha'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Registrado por ${r['actor_nombre'] ?? 'Sin nombre'}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFCCE0E7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            content: SizedBox(
              width: 760,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _grupoChecklist(
                      'Con novedad',
                      novedades,
                      color: const Color(0xFF9A5700),
                      icono: Icons.warning_amber_rounded,
                    ),
                    _grupoChecklist(
                      'Buen estado',
                      buenos,
                      color: const Color(0xFF18754B),
                      icono: Icons.check_circle_outline,
                    ),
                    if (otros.isNotEmpty)
                      _grupoChecklist(
                        'Sin clasificar',
                        otros,
                        color: ConductorDesign.muted,
                        icono: Icons.help_outline,
                      ),
                    if ('${r['datos']['notas'] ?? ''}'.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F7F8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Observaciones',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: ConductorDesign.navy,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('${r['datos']['notas']}'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cerrar'),
              ),
              if ((r['datos']['respuestas'] as Map? ?? {}).values.any(
                (v) =>
                    v == 'Con novedad' ||
                    (v is Map && v['estado'] == 'Con novedad'),
              ))
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: ConductorDesign.lime,
                    foregroundColor: ConductorDesign.navy,
                  ),
                  onPressed:
                      _ocupado ? null : () => Navigator.pop(context, true),
                  icon: const Icon(Icons.add_task),
                  label: const Text(
                    'Seleccionar novedades y asignar actividad',
                  ),
                ),
            ],
          ),
    );
    if (asignar == true && mounted) await _formActividad(registro: r);
  }

  Widget _salida() {
    final inicio = _inicioHoy;
    final ultimo =
        _checklists.where((r) => r['tipo'] == 'Inicio de jornada').firstOrNull;
    final autorizado = _datos!['estado'] == 'Autorizado';
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ConductorDesign.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: ConductorDesign.lime),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    const Text(
                      'SALIDA DE HOY',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: .5,
                        fontWeight: FontWeight.w700,
                        color: ConductorDesign.muted,
                      ),
                    ),
                    _chip(
                      autorizado
                          ? 'Salida autorizada'
                          : _datos!['estado'] == 'No autorizado'
                          ? 'Salida no autorizada'
                          : '${_datos!['estado']}'.startsWith('Sin checklist')
                          ? 'Esperando checklist'
                          : 'Pendiente de autorización',
                      good: autorizado,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${_datos!['estado']}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.administrador
                      ? 'Revisa el checklist de inicio de hoy para decidir si el vehículo puede salir a ruta.'
                      : 'Consulta aquí la decisión del administrador antes de salir a ruta.',
                  style: const TextStyle(
                    color: ConductorDesign.muted,
                    height: 1.5,
                  ),
                ),
                if (_datos!['observacion'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('${_datos!['observacion']}'),
                  ),
                const SizedBox(height: 12),
                if (widget.administrador) ...[
                  const Divider(height: 1),
                  _linea(
                    'Checklist de inicio de hoy',
                    inicio != null
                        ? 'Registrado por ${inicio['actor_nombre'] ?? 'el conductor'}'
                        : ultimo == null
                        ? 'Aún no registrado.'
                        : 'Aún no registrado. El último es del ${ultimo['datos']['fecha']}',
                    inicio != null,
                  ),
                ],
                const Divider(height: 1),
                _linea(
                  'Actividades de mantenimiento',
                  _pendientes == 0 && _porVerificar == 0
                      ? 'Sin actividades pendientes'
                      : '$_pendientes pendientes · $_porVerificar por verificar',
                  _pendientes == 0 && _porVerificar == 0,
                ),
                if (widget.administrador &&
                    inicio != null &&
                    _datos!['version'] == 2) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton(
                        onPressed:
                            _ocupado
                                ? null
                                : () => _accion(inicio['id'], 'Autorizado'),
                        child: const Text('Autorizar salida'),
                      ),
                      OutlinedButton(
                        onPressed:
                            _ocupado
                                ? null
                                : () => _accion(inicio['id'], 'No autorizado'),
                        child: const Text('No autorizar salida'),
                      ),
                      OutlinedButton(
                        onPressed: () => _verChecklist(inicio),
                        child: const Text('Ver checklist de inicio'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _historial() {
    final registros = _checklists.where(_coincideHistorial).toList();
    final fechas =
        registros.map((r) => '${r['datos']['fecha'] ?? 'Sin fecha'}').toSet();
    return FlotaPanel(
      compact: true,
      title: 'Historial de checklists',
      children: [
        Text(
          '${registros.length} de ${_checklists.length} registros · filtros sobre los últimos 100',
          style: TextStyle(color: ConductorDesign.muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _filtrosHistorial(),
        if (registros.isEmpty) ...[
          const SizedBox(height: 14),
          const Text('No hay inspecciones que coincidan con los filtros'),
          const Text(
            'Los checklists aparecerán aquí cuando el conductor los complete.',
            style: TextStyle(color: ConductorDesign.muted),
          ),
        ],
        for (final fecha in fechas) ...[
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 8),
            child: Text(
              fecha,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: ConductorDesign.muted,
              ),
            ),
          ),
          for (final r in registros.where(
            (r) => '${r['datos']['fecha'] ?? 'Sin fecha'}' == fecha,
          )) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: LayoutBuilder(
                builder: (context, c) {
                  final info = Row(
                    children: [
                      _chip(
                        r['tipo'] == 'Fin de jornada' ? 'Fin' : 'Inicio',
                        good: r['tipo'] == 'Fin de jornada',
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r['tipo']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Registrado por ${r['actor_nombre'] ?? 'Sin nombre'}',
                              style: const TextStyle(
                                color: ConductorDesign.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  final boton = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (((r['datos'] as Map?)?['respuestas'] as Map? ?? {})
                          .isEmpty)
                        const Text('Sin detalle de puntos')
                      else ...[
                        _chip(
                          '${_contarPuntos(r, 'Buen estado')} en buen estado',
                          good: true,
                        ),
                        _chip('${_contarPuntos(r, 'Con novedad')} con novedad'),
                      ],
                      OutlinedButton(
                        onPressed: () => _verChecklist(r),
                        child: const Text('Ver checklist'),
                      ),
                    ],
                  );
                  return c.maxWidth < 800
                      ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [info, const SizedBox(height: 10), boton],
                      )
                      : Row(
                        children: [
                          Expanded(child: info),
                          const SizedBox(width: 12),
                          boton,
                        ],
                      );
                },
              ),
            ),
          ],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ConductorDesign.theme(),
    child: TransporteScaffold(
      loadingLabel:
          _ocupado
              ? _accionCarga
              : (_actualizandoHistorial
                  ? 'Actualizando historial de inspecciones…'
                  : null),
      appBar: AppBar(
        title: const Text('Autorización y actividades'),
        actions: [
          IconButton(
            onPressed: _ocupado ? null : _cargar,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: ListView(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
            ),
            children: [
              if (widget.contextoVehiculo != null) ...[
                Text(
                  'Flota / ${widget.contextoVehiculo!['placa']} / Autorización y actividades',
                  style: const TextStyle(
                    fontSize: 13,
                    color: ConductorDesign.muted,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const ConductorHeading(
                'Autorización y actividades',
                'Revisión de salida y seguimiento de las correcciones del vehículo',
              ),
              FlotaColumns(
                aside:
                    widget.contextoVehiculo == null
                        ? null
                        : FlotaPanel(
                          compact: true,
                          title: 'Vehículo',
                          children: [
                            Text(
                              '${widget.contextoVehiculo!['placa']} · ${widget.contextoVehiculo!['descripcion']}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: ConductorDesign.navy,
                                  child: Icon(
                                    Icons.person_outline,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${widget.contextoVehiculo!['conductor_nombre']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Text(
                                        'Conductor actual',
                                        style: TextStyle(
                                          color: ConductorDesign.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            FlotaMetric(
                              'Kilometraje',
                              '${NumberFormat.decimalPattern('es_CO').format(widget.contextoVehiculo!['km'] ?? 0)} km',
                              compact: true,
                              icon: Icons.speed,
                            ),
                          ],
                        ),
                main: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) AvisoFormulario(_error!),
                    if (_datos == null && _error == null)
                      const WmsLoadingPanel(
                        label: 'Cargando autorizaciones y actividades…',
                      ),
                    if (_datos != null) ...[
                      _salida(),
                      if (_datos!['version'] != 2)
                        const Text(
                          'No se pudieron consultar las actividades. Verifica la configuración del módulo y vuelve a intentar.',
                        ),
                      if (_datos!['version'] == 2) ...[
                        if (widget.administrador)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: FilledButton.icon(
                                onPressed:
                                    _ocupado ? null : () => _formActividad(),
                                icon: const Icon(Icons.add),
                                label: const Text(
                                  'Crear actividad independiente',
                                ),
                              ),
                            ),
                          ),
                        if ((_datos!['tareas'] as List? ?? []).isEmpty)
                          FlotaPanel(
                            compact: true,
                            title: 'Actividades de mantenimiento',
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF6FAFA),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: _linea(
                                  'Todo al día',
                                  'No hay actividades pendientes.',
                                  true,
                                ),
                              ),
                            ],
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Actividades de mantenimiento',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        _actividadesAgrupadas(),

                        if (widget.administrador) _historial(),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
