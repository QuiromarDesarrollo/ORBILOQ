import '../../../shared/widgets/wms_alert.dart';
import '../mantenimiento_preventivo.dart';
import '../conductor_model.dart';
import 'registro_conductor.dart';
import 'transporte_scaffold.dart';
import '../../../shared/widgets/wms_loader.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../conductor_repository.dart';
import '../evidencia_conductor.dart';
import '../kit_semanal.dart';
import 'conductor_design.dart';
import 'evidencia_conductor_field.dart';

class ActividadConductorForm extends ConsumerStatefulWidget {
  const ActividadConductorForm({
    super.key,
    required this.vehiculo,
    this.registro,
    this.tarea,
  });
  final String vehiculo;
  final Map? registro, tarea;
  @override
  ConsumerState<ActividadConductorForm> createState() =>
      _ActividadConductorFormState();
}

class _ActividadConductorFormState
    extends ConsumerState<ActividadConductorForm> {
  final _texto = TextEditingController();
  final _trabajo = TextEditingController();
  String _tipo = 'Mantenimiento correctivo';
  String? _servicioId;
  Future<List<VehiculoConductor>>? _vehiculosEntrega;
  final _foto = EvidenciaSeleccionada();
  final _motivos = <String>{};
  DateTime _fecha = hoyColombia();
  bool _guardando = false, _procesando = false;
  String _etapaGuardado = 'Guardando actividad…';
  String? _error;
  bool get _independiente => widget.registro == null && !_entrega;
  bool get _entrega => widget.tarea != null;
  bool get _ocupado => _guardando || _procesando;
  List<Map<String, dynamic>> _actividades = [];
  bool _cargando = true;
  bool _consultaCorrecta = false;
  Set<String> get _asignados => {
    for (final t in _actividades)
      for (final m in (t['motivos'] as List? ?? [t['punto']])) m.toString(),
  };
  bool get _hayDisponibles =>
      _independiente ||
      (widget.registro?['datos']['respuestas'] as Map? ?? {}).entries.any(
        (e) =>
            !_asignados.contains(e.key) &&
            (e.value == 'Con novedad' ||
                (e.value is Map && e.value['estado'] == 'Con novedad')),
      );

  @override
  void initState() {
    super.initState();
    if (!_entrega) {
      _cargarActividades();
    } else {
      _cargando = false;
      if (widget.tarea?['mantenimiento_tipo'] != null) {
        _vehiculosEntrega = ref.read(conductorRepositoryProvider).vehiculos();
      }
    }
  }

  Future<void> _cargarActividades() async {
    setState(() {
      _cargando = true;
      _consultaCorrecta = false;
    });
    try {
      final resumen = await ref
          .read(conductorRepositoryProvider)
          .revisionSalida(widget.vehiculo, detalle: true);
      if (resumen['version'] != 2) {
        throw const FormatException(
          'Falta activar las actividades. Contacta al administrador.',
        );
      }
      final tareas =
          (resumen['tareas'] as List? ?? [])
              .where(
                (t) =>
                    _independiente ||
                    t['registro_id'] == widget.registro!['id'],
              )
              .map((t) => Map<String, dynamic>.from(t as Map))
              .toList();
      if (mounted) {
        setState(() {
          _actividades = tareas;
          _consultaCorrecta = true;
          _motivos.removeAll(_asignados);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error =
                  'No se pudo consultar el seguimiento. Pulsa Actualizar para reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _momento(dynamic value) {
    final d = DateTime.tryParse(value?.toString() ?? '');
    return d == null
        ? 'Sin registrar'
        : '${DateFormat('dd/MM/yyyy HH:mm').format(d.toUtc().subtract(const Duration(hours: 5)))} · Colombia';
  }

  @override
  void dispose() {
    _texto.dispose();
    _trabajo.dispose();
    _foto.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_ocupado || (!_entrega && (!_consultaCorrecta || _cargando))) return;
    if (_texto.text.trim().isEmpty ||
        (!_entrega && !_independiente && _motivos.isEmpty) ||
        (_entrega && _foto.archivo == null)) {
      setState(
        () =>
            _error =
                _entrega
                    ? 'Describe la solución y adjunta una foto.'
                    : 'Selecciona los motivos y describe la actividad.',
      );
      return;
    }
    if (!_entrega &&
        ((_tipo == 'Mantenimiento preventivo' && _servicioId == null) ||
            (_tipo == 'Mantenimiento correctivo' &&
                _trabajo.text.trim().isEmpty))) {
      setState(
        () => _error = 'Selecciona o escribe el mantenimiento asignado.',
      );
      return;
    }
    setState(() {
      _guardando = true;
      _etapaGuardado =
          _entrega ? 'Subiendo foto a Drive…' : 'Guardando actividad…';
      _error = null;
    });
    try {
      final repo = ref.read(conductorRepositoryProvider);
      if (_entrega) {
        await _foto.subir(
          repo.client,
          widget.vehiculo,
          'enlace',
          'Mantenimiento correctivo',
        );
        if (mounted) setState(() => _etapaGuardado = 'Registrando entrega…');
        await repo.entregarActividad(
          widget.tarea!['id'],
          _texto.text.trim(),
          _foto.enlace!,
        );
      } else {
        await repo.crearActividadMantenimiento(
          widget.vehiculo,
          widget.registro?['id'],
          _motivos.toList(),
          _texto.text.trim(),
          fechaKit(_fecha),
          _tipo,
          _tipo == 'Mantenimiento preventivo'
              ? serviciosPreventivos
                  .firstWhere((s) => s.id == _servicioId)
                  .nombre
              : _trabajo.text.trim(),
          servicioId: _servicioId,
        );
      }
      if (!mounted) return;
      if (_entrega) {
        Navigator.pop(context, true);
      } else {
        _texto.clear();
        _trabajo.clear();
        _motivos.clear();
        await _cargarActividades();
      }
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error =
                  e is PostgrestException
                      ? e.message
                      : e is FormatException
                      ? e.message
                      : 'No se pudo guardar. Se conservan los datos y la foto para reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_vehiculosEntrega != null) {
      return FutureBuilder<List<VehiculoConductor>>(
        future: _vehiculosEntrega,
        builder: (context, snapshot) {
          final vehiculo =
              snapshot.data?.where((v) => v.id == widget.vehiculo).firstOrNull;
          if (vehiculo != null) {
            return RegistroConductorPage(
              vehiculo: vehiculo,
              tipo: widget.tarea!['mantenimiento_tipo'],
              servicioPreventivo: widget.tarea!['servicio_id'],
              actividad: Map<String, dynamic>.from(widget.tarea!),
            );
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Mantenimiento asignado')),
            body: Center(
              child:
                  snapshot.connectionState == ConnectionState.waiting
                      ? const WmsLoadingPanel(
                        label: 'Cargando mantenimiento asignado…',
                      )
                      : TextButton(
                        onPressed:
                            () => setState(() {
                              _vehiculosEntrega =
                                  ref
                                      .read(conductorRepositoryProvider)
                                      .vehiculos();
                            }),
                        child: const Text(
                          'No se pudo cargar el vehículo. Reintentar',
                        ),
                      ),
            ),
          );
        },
      );
    }
    return Theme(
      data: ConductorDesign.theme(),
      child: PopScope(
        canPop: !_ocupado,
        child: TransporteScaffold(
          loadingLabel:
              _guardando
                  ? _etapaGuardado
                  : (!_entrega && _cargando
                      ? 'Cargando novedades y actividades asignadas…'
                      : null),
          appBar: AppBar(
            title: Text(_entrega ? 'Entregar actividad' : 'Asignar actividad'),
            actions: [
              if (!_entrega)
                IconButton(
                  onPressed:
                      _ocupado || _cargando
                          ? null
                          : () {
                            setState(() => _error = null);
                            _cargarActividades();
                          },
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualizar seguimiento',
                ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!_entrega && _consultaCorrecta && !_hayDisponibles)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Todos los motivos de este checklist ya tienen actividad asignada. Consulta su seguimiento abajo.',
                      ),
                    ),
                  ConductorPanel(
                    title:
                        _entrega
                            ? 'Solución realizada'
                            : _independiente
                            ? 'Actividad independiente'
                            : 'Motivos de la actividad',
                    children: [
                      if (_entrega) ...[
                        Text(widget.tarea!['descripcion'].toString()),
                        Text(
                          'Motivos: ${(widget.tarea!['motivos'] as List? ?? [widget.tarea!['punto']]).join(', ')}',
                        ),
                      ] else if (!_independiente) ...[
                        const Text(
                          'Selecciona los puntos con novedad que se resolverán en esta actividad.',
                        ),
                        for (final e
                            in (widget.registro!['datos']['respuestas'] as Map)
                                .entries)
                          if (_consultaCorrecta &&
                              !_asignados.contains(e.key) &&
                              (e.value == 'Con novedad' ||
                                  (e.value is Map &&
                                      e.value['estado'] == 'Con novedad')))
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(e.key.toString()),
                              value: _motivos.contains(e.key),
                              onChanged:
                                  _ocupado
                                      ? null
                                      : (v) => setState(() {
                                        v == true
                                            ? _motivos.add(e.key.toString())
                                            : _motivos.remove(e.key);
                                      }),
                            ),
                      ],
                      if (_entrega ||
                          (_consultaCorrecta && _hayDisponibles)) ...[
                        const SizedBox(height: 16),
                        if (!_entrega) ...[
                          DropdownButtonFormField<String>(
                            value: _tipo,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Tipo de mantenimiento',
                            ),
                            items: [
                              for (final tipo in [
                                'Mantenimiento preventivo',
                                'Mantenimiento correctivo',
                              ])
                                DropdownMenuItem(
                                  value: tipo,
                                  child: Text(
                                    tipo,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged:
                                _ocupado
                                    ? null
                                    : (v) => setState(() {
                                      _tipo = v!;
                                      _servicioId = null;
                                    }),
                          ),
                          const SizedBox(height: 16),
                          if (_tipo == 'Mantenimiento preventivo')
                            DropdownButtonFormField<String>(
                              value: _servicioId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Mantenimiento asignado',
                              ),
                              items: [
                                for (final servicio in serviciosPreventivos)
                                  DropdownMenuItem(
                                    value: servicio.id,
                                    child: Text(
                                      servicio.nombre,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged:
                                  _ocupado
                                      ? null
                                      : (v) => setState(() => _servicioId = v),
                            )
                          else
                            TextField(
                              controller: _trabajo,
                              enabled: !_ocupado,
                              maxLength: 1000,
                              decoration: const InputDecoration(
                                labelText: 'Mantenimiento asignado',
                                hintText:
                                    'Trabajo que debe realizar el conductor',
                              ),
                            ),
                          const SizedBox(height: 16),
                        ],
                        TextField(
                          controller: _texto,
                          enabled: !_ocupado,
                          maxLength: 1000,
                          minLines: 3,
                          maxLines: 6,
                          decoration: InputDecoration(
                            labelText:
                                _entrega
                                    ? 'Describe la solución'
                                    : 'Instrucciones de la actividad',
                          ),
                        ),
                        if (!_entrega) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_month),
                            label: Text('Fecha límite: ${fechaKit(_fecha)}'),
                            onPressed:
                                _ocupado
                                    ? null
                                    : () async {
                                      final d = await showDatePicker(
                                        context: context,
                                        initialDate: _fecha,
                                        firstDate: hoyColombia(),
                                        lastDate: DateTime(2100),
                                      );
                                      if (d != null && mounted) {
                                        setState(() => _fecha = d);
                                      }
                                    },
                          ),
                        ],
                        if (_entrega) ...[
                          const SizedBox(height: 16),
                          EvidenciaConductorField(
                            controller: _foto,
                            etiqueta: 'Foto de la actividad realizada',
                            soloFoto: true,
                            obligatorio: true,
                            enabled: !_ocupado,
                            onBusy: (v) => setState(() => _procesando = v),
                          ),
                          const Text(
                            'La foto se sube automáticamente al enviar. Se registra la fecha y hora de entrega y queda por verificar por el administrador.',
                          ),
                        ],
                        if (_error != null) AvisoFormulario(_error!),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _ocupado ? null : _guardar,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(
                            _guardando
                                ? 'Guardando…'
                                : _entrega
                                ? 'Enviar para verificación'
                                : 'Crear actividad',
                          ),
                        ),
                      ],
                      if (!_entrega &&
                          _error != null &&
                          (!_consultaCorrecta || !_hayDisponibles))
                        AvisoFormulario(_error!),
                    ],
                  ),
                  if (!_entrega) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Seguimiento de actividades',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    for (final t in _actividades)
                      ConductorPanel(
                        title: t['descripcion'].toString(),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ConductorBadge(
                              t['estado'] == 'Cerrada'
                                  ? 'Completada'
                                  : t['estado'].toString(),
                              warning: t['estado'] != 'Cerrada',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Motivos: ${(t['motivos'] as List? ?? [t['punto']]).join(', ')}',
                          ),
                          Text(
                            'Fecha límite: ${t['fecha_limite'] ?? 'Sin plazo'}',
                          ),
                          if (t['entregado_en'] != null)
                            Text(
                              'Entregada por el conductor: ${_momento(t['entregado_en'])}',
                            ),
                          if (t['solucion'] != null)
                            Text('Solución: ${t['solucion']}'),
                          if (t['respuesta'] != null)
                            Text('Revisión: ${t['respuesta']}'),
                          if (t['estado'] == 'Cerrada')
                            Text('Cierre: ${_momento(t['actualizado'])}'),
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
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
