import '../../../shared/widgets/wms_alert.dart';
import '../mantenimiento_preventivo.dart';
import '../ficha_vehiculo.dart';
import 'transporte_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../conductor_model.dart';
import '../conductor_repository.dart';
import '../evidencia_conductor.dart';
import 'conductor_design.dart';
import 'evidencia_conductor_field.dart';
import 'observaciones_evidencia_conductor.dart';

class RegistroConductorPage extends ConsumerStatefulWidget {
  const RegistroConductorPage({
    super.key,
    required this.vehiculo,
    required this.tipo,
    this.servicioPreventivo,
    this.actividad,
  });
  final VehiculoConductor vehiculo;
  final String tipo;
  final String? servicioPreventivo;
  final Map<String, dynamic>? actividad;
  @override
  ConsumerState<RegistroConductorPage> createState() =>
      _RegistroConductorPageState();
}

class _RegistroConductorPageState extends ConsumerState<RegistroConductorPage> {
  final _form = GlobalKey<FormState>();
  final _campos = <String, TextEditingController>{};
  final _respuestas = <String, String>{};
  bool _guardando = false;
  int _categoria = 0;
  final _evidenciasOcupadas = <String>{};
  final _evidencias = <String, EvidenciaSeleccionada>{};
  String? _progresoSubida;
  bool get _ocupado => _guardando || _evidenciasOcupadas.isNotEmpty;
  bool _siniestro = false;
  String? _error;
  DateTime _fecha = DateTime.now();
  TimeOfDay _horaMantenimiento = TimeOfDay.now();
  DateTime _fechaFin = DateTime.now();
  TimeOfDay _horaFin = TimeOfDay.now();
  ServicioPreventivo? _servicio;
  @override
  void initState() {
    super.initState();
    if (widget.actividad != null) {
      _ctrl('servicio', widget.actividad!['mantenimiento_trabajo'].toString());
    }
    for (final s in serviciosPreventivos) {
      if (s.id == widget.servicioPreventivo) _servicio = s;
    }
  }

  bool get _preventivo => widget.tipo == 'Mantenimiento preventivo';
  bool get _tanqueoPreventivo => _preventivo && _servicio?.id == 'combustible';
  String _horaTexto(TimeOfDay h) =>
      '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';
  DateTime _instante(DateTime d, TimeOfDay h) =>
      DateTime(d.year, d.month, d.day, h.hour, h.minute);

  bool get _check =>
      widget.tipo == 'Inicio de jornada' || widget.tipo == 'Fin de jornada';
  bool get _documentos => widget.tipo == 'Documentos';
  bool get _mantenimiento => widget.tipo.startsWith('Mantenimiento');
  TextEditingController _ctrl(String key, [String valor = '']) =>
      _campos.putIfAbsent(key, () => TextEditingController(text: valor));

  Widget _evidencia(
    String campo,
    String etiqueta, {
    bool obligatorio = false,
    bool soloFoto = false,
    EstiloEvidencia estilo = EstiloEvidencia.normal,
    String? ayuda,
  }) => EvidenciaConductorField(
    key: ValueKey('evidencia-$campo'),
    controller: _evidencias.putIfAbsent(campo, EvidenciaSeleccionada.new),
    etiqueta: etiqueta,
    enabled: !_ocupado,
    obligatorio: obligatorio,
    soloFoto: soloFoto,
    estilo: estilo,
    ayuda: ayuda,
    onBusy:
        (busy) => setState(() {
          if (busy) {
            _evidenciasOcupadas.add(campo);
          } else {
            _evidenciasOcupadas.remove(campo);
          }
        }),
  );
  @override
  void dispose() {
    for (final e in _evidencias.values) {
      e.dispose();
    }
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _campo(
    String key,
    String etiqueta, {
    bool obligatorio = false,
    bool numero = false,
    String valor = '',
    int lineas = 1,
    String? placeholder,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          etiqueta + (obligatorio ? ' *' : ''),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ConductorDesign.ink,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: etiqueta,
          child: TextFormField(
            key: ValueKey('campo-$key'),
            controller: _ctrl(key, valor),
            enabled: !_guardando,
            readOnly: key == 'servicio' && widget.actividad != null,
            keyboardType:
                numero
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
            minLines: lineas,
            maxLines: lineas,
            decoration: InputDecoration(hintText: placeholder),
            validator: (v) {
              if (key == 'galones') {
                final cantidad = double.tryParse(
                  (v ?? '').trim().replaceAll(',', '.'),
                );
                if (cantidad == null || !cantidad.isFinite || cantidad <= 0) {
                  return 'Ingresa una cantidad de galones mayor que cero';
                }
              }
              if (obligatorio && (v == null || v.trim().isEmpty)) {
                return 'Campo obligatorio';
              }
              if (numero &&
                  v != null &&
                  v.isNotEmpty &&
                  (double.tryParse(
                            key == 'galones' ? v.replaceAll(',', '.') : v,
                          ) ==
                          null ||
                      !double.parse(
                        key == 'galones' ? v.replaceAll(',', '.') : v,
                      ).isFinite ||
                      double.parse(
                            key == 'galones' ? v.replaceAll(',', '.') : v,
                          ) <
                          0)) {
                return 'Ingresa un número válido';
              }
              return null;
            },
          ),
        ),
      ],
    ),
  );

  Widget _fechaHoraMantenimiento() => TransporteCampos(
    children: [
      for (final fin in [false, true]) ...[
        TextFormField(
          key: ValueKey(
            'fecha-${fin ? 'fin' : 'inicio'}-${fin ? _fechaFin : _fecha}',
          ),
          initialValue: DateFormat(
            'dd/MM/yyyy',
          ).format(fin ? _fechaFin : _fecha),
          readOnly: true,
          enabled: !_ocupado,
          decoration: InputDecoration(
            labelText: fin ? 'Fecha fin' : 'Fecha de inicio',
            suffixIcon: const Icon(Icons.calendar_month_outlined),
          ),
          onTap: () async {
            final fecha = await showDatePicker(
              context: context,
              initialDate: fin ? _fechaFin : _fecha,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (fecha != null && mounted) {
              setState(() {
                if (fin) {
                  _fechaFin = fecha;
                } else {
                  _fecha = fecha;
                }
              });
            }
          },
        ),
        TextFormField(
          key: ValueKey(
            'hora-${fin ? 'fin' : 'inicio'}-${fin ? _horaFin : _horaMantenimiento}',
          ),
          initialValue: (fin ? _horaFin : _horaMantenimiento).format(context),
          readOnly: true,
          enabled: !_ocupado,
          decoration: InputDecoration(
            labelText: fin ? 'Hora fin' : 'Hora de inicio',
            suffixIcon: const Icon(Icons.schedule_outlined),
          ),
          onTap: () async {
            final hora = await showTimePicker(
              context: context,
              initialTime: fin ? _horaFin : _horaMantenimiento,
            );
            if (hora != null && mounted) {
              setState(() {
                if (fin) {
                  _horaFin = hora;
                } else {
                  _horaMantenimiento = hora;
                }
              });
            }
          },
        ),
      ],
    ],
  );

  Widget _selectorServicio() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Mantenimiento realizado *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ConductorDesign.ink,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Mantenimiento realizado',
          child: DropdownButtonFormField<ServicioPreventivo>(
            initialValue: _servicio,
            isExpanded: true,
            decoration: const InputDecoration(),
            items: [
              for (final s in serviciosPreventivos)
                DropdownMenuItem(
                  value: s,
                  child: Text(s.nombre, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _ocupado ? null : (s) => setState(() => _servicio = s),
            validator:
                (s) =>
                    s == null ? 'Selecciona el mantenimiento realizado' : null,
          ),
        ),
      ],
    ),
  );

  Widget _fechaDocumento(String key, String etiqueta) {
    final controller = _ctrl(key, widget.vehiculo.datos[key]?.toString() ?? '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: etiqueta,
          suffixIcon: const Icon(Icons.calendar_month),
        ),
        onTap:
            _guardando
                ? null
                : () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate:
                        DateTime.tryParse(controller.text) ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null && mounted) {
                    setState(
                      () =>
                          controller.text = DateFormat('yyyy-MM-dd').format(d),
                    );
                  }
                },
      ),
    );
  }

  Widget _campoFicha(CampoFichaVehiculo campo) {
    final actual = widget.vehiculo.datos[campo.key]?.toString() ?? '';
    if (campo.fecha) return _fechaDocumento(campo.key, campo.label);
    if (campo.opciones.isNotEmpty) {
      final controller = _ctrl(campo.key, actual);
      return DropdownButtonFormField<String>(
        key: ValueKey('ficha-${campo.key}'),
        isExpanded: true,
        initialValue: controller.text.isEmpty ? null : controller.text,
        decoration: InputDecoration(
          labelText: campo.label,
          hintText: 'Sin registrar',
        ),
        items:
            {
              ...campo.opciones,
              if (actual.isNotEmpty) actual,
            }.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: _ocupado ? null : (value) => controller.text = value ?? '',
      );
    }
    return _campo(campo.key, campo.label, numero: campo.numero, valor: actual);
  }

  Widget _seccion(String titulo, List<Widget> campos) => ConductorPanel(
    title: titulo,
    icon: switch (titulo) {
      'Datos del registro' => Icons.assignment_outlined,
      'Documentos y programación' => Icons.event_note_outlined,
      'Observaciones y evidencia' => Icons.camera_alt_outlined,
      'Combustible' => Icons.local_gas_station_outlined,
      'Servicio realizado' => Icons.build_outlined,
      'Seguridad del recorrido' => Icons.health_and_safety_outlined,
      _ => Icons.checklist_outlined,
    },
    children: campos,
  );

  Future<void> _guardar() async {
    if (_ocupado) return;
    if (!_form.currentState!.validate()) return;
    if (_mantenimiento &&
        _instante(
          _fechaFin,
          _horaFin,
        ).isBefore(_instante(_fecha, _horaMantenimiento))) {
      setState(
        () =>
            _error = 'La fecha y hora fin no pueden ser anteriores al inicio.',
      );
      return;
    }
    final km = int.tryParse(_ctrl('km', widget.vehiculo.km.toString()).text);
    if (km == null) {
      setState(() => _error = 'El kilometraje debe ser entero.');
      return;
    }
    final notas = _ctrl('notas').text;
    final enlace = _evidencias['enlace']?.enlace ?? '';
    final fallo = validarRegistroConductor(
      tipo: widget.tipo,
      km: km,
      ultimoKm: widget.vehiculo.km,
      respuestas: _respuestas,
      notas: notas,
      enlace: enlace,
    );
    if (fallo != null) {
      setState(() {
        _error = fallo;
        if (_check) {
          final faltante = checklistConductor.entries.toList().indexWhere(
            (g) => g.value.any((p) => !_respuestas.containsKey(p)),
          );
          if (faltante >= 0) _categoria = faltante;
        }
      });
      return;
    }
    if (_siniestro && _ctrl('hecho').text.trim().isEmpty) {
      setState(() => _error = 'Describe el siniestro ocurrido.');
      return;
    }
    if (_siniestro && _evidencias['evidencia_siniestro']?.archivo == null) {
      setState(() => _error = 'Agrega la evidencia del siniestro.');
      return;
    }
    if (widget.actividad != null &&
        _evidencias['enlace']?.archivo == null &&
        _evidencias['enlace']?.enlace == null) {
      setState(
        () => _error = 'Adjunta una evidencia del mantenimiento realizado.',
      );
      return;
    }
    setState(() {
      _guardando = true;
      _progresoSubida =
          _evidencias.values.any((e) => e.archivo != null)
              ? 'Preparando la subida de evidencias…'
              : null;
      _error = null;
    });
    var subiendo = true;
    try {
      await subirEvidenciasConductor(
        _evidencias,
        client: ref.read(conductorRepositoryProvider).client,
        vehiculo: widget.vehiculo.id,
        tipo: widget.tipo,
        onProgress: (actual, total) {
          if (mounted) {
            setState(
              () => _progresoSubida = 'Subiendo evidencias $actual de $total…',
            );
          }
        },
      );
      subiendo = false;
      if (!mounted) return;
      setState(() => _progresoSubida = null);
      await ref.read(conductorRepositoryProvider).guardar(
        widget.vehiculo.id,
        widget.tipo,
        km,
        {
          for (final e in _campos.entries)
            if (e.key != 'km' && e.key != 'galones') e.key: e.value.text.trim(),
          if (_tanqueoPreventivo)
            'galones': _ctrl('galones').text.trim().replaceAll(',', '.'),
          for (final e in _evidencias.entries)
            if (e.value.enlace != null) e.key: e.value.enlace!,
          if (widget.actividad != null) 'actividad_id': widget.actividad!['id'],
          'fecha': DateFormat('yyyy-MM-dd').format(_fecha),
          if (_mantenimiento)
            'hora_mantenimiento':
                '${_horaMantenimiento.hour.toString().padLeft(2, '0')}:${_horaMantenimiento.minute.toString().padLeft(2, '0')}',
          if (_mantenimiento) ...{
            'fecha_inicio': DateFormat('yyyy-MM-dd').format(_fecha),
            'hora_inicio': _horaTexto(_horaMantenimiento),
            'fecha_fin': DateFormat('yyyy-MM-dd').format(_fechaFin),
            'hora_fin': _horaTexto(_horaFin),
          },
          if (_preventivo && _servicio != null) ...{
            'servicio_id': _servicio!.id,
            'servicio': _servicio!.nombre,
          },
          if (_check) 'respuestas': _respuestas,
          if (widget.tipo == 'Fin de jornada') 'siniestro': _siniestro,
          if (_check)
            'resultado':
                _respuestas.containsValue('Con novedad')
                    ? 'Requiere revisión'
                    : 'Sin novedades',
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _progresoSubida = null;
          _error =
              subiendo
                  ? '${e is FormatException ? e.message : 'No se pudieron subir todas las evidencias.'} Las selecciones se conservan. Pulsa Guardar registro para reintentar.'
                  : 'No se guardó el registro. Actualiza el vehículo: pudo cambiar la asignación, el kilometraje o el estado de la jornada.';
          _guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ConductorDesign.theme(),
    child: Builder(
      builder:
          (context) => PopScope(
            canPop: !_ocupado,
            child: TransporteScaffold(
              loadingLabel:
                  _guardando
                      ? (_progresoSubida ??
                          (widget.actividad != null
                              ? 'Enviando mantenimiento para validación…'
                              : _check
                              ? 'Guardando inspección del vehículo…'
                              : _documentos
                              ? 'Guardando documentos del vehículo…'
                              : _mantenimiento
                              ? 'Guardando mantenimiento…'
                              : 'Guardando ${widget.tipo.toLowerCase()}…'))
                      : null,
              appBar: AppBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.tipo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      widget.vehiculo.placa,
                      style: const TextStyle(
                        fontSize: 11,
                        color: ConductorDesign.muted,
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: ConductorDesign.line)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      heightFactor: 1,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth:
                              widget.tipo == 'Registro diario' ? 1128 : 820,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _ocupado ? null : _guardar,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(
                              _guardando
                                  ? (_progresoSubida ?? 'Guardando…')
                                  : _evidenciasOcupadas.isNotEmpty
                                  ? 'Procesando evidencia…'
                                  : widget.actividad != null
                                  ? 'Enviar para validación'
                                  : 'Guardar registro',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              body: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1160),
                    child: Form(
                      key: _form,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          ConductorHeading(
                            widget.tipo,
                            'Registra el estado y conserva la trazabilidad de tu vehículo.',
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ConductorBadge(widget.vehiculo.placa),
                              ConductorBadge(
                                DateFormat('dd/MM/yyyy').format(_fecha),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _seccion('Datos del registro', [
                            if (_mantenimiento)
                              _fechaHoraMantenimiento()
                            else
                              Text(
                                'Fecha: ${DateFormat("dd/MM/yyyy").format(_fecha)}',
                              ),
                            if (!_check && !_documentos && !_mantenimiento)
                              TextButton.icon(
                                onPressed:
                                    _ocupado
                                        ? null
                                        : () async {
                                          final d = await showDatePicker(
                                            context: context,
                                            initialDate: _fecha,
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime.now(),
                                          );
                                          if (d != null && mounted) {
                                            setState(() => _fecha = d);
                                          }
                                        },
                                icon: const Icon(Icons.calendar_month),
                                label: const Text(
                                  'Cambiar fecha de la actividad',
                                ),
                              ),
                            const SizedBox(height: 16),
                            _campo(
                              'km',
                              _check
                                  ? 'Kilometraje de la jornada'
                                  : 'Kilometraje actual',
                              numero: true,
                              obligatorio: true,
                              valor: widget.vehiculo.km.toString(),
                            ),
                            const Text(
                              'Conductor, placa y hora de registro se guardan automáticamente.',
                            ),
                          ]),
                          if (_documentos) ...[
                            for (final grupo in fichaVehiculoCampos.entries)
                              _seccion(grupo.key, [
                                TransporteCampos(
                                  children: [
                                    for (final campo in grupo.value)
                                      _campoFicha(campo),
                                  ],
                                ),
                              ]),
                            _seccion('Foto del vehículo', [
                              const Text(
                                'Puedes tomar una foto o elegirla. Se sube a Drive al guardar; se conserva únicamente el enlace.',
                              ),
                              const SizedBox(height: 12),
                              _evidencia(
                                'foto_frontal',
                                'Foto del vehículo',
                                soloFoto: true,
                              ),
                            ]),
                          ],
                          if (_documentos) ...[
                            _seccion('Datos del conductor', [
                              _campo(
                                'conductor_documento',
                                'Número de documento del conductor',
                                valor:
                                    widget.vehiculo.datos['conductor_documento']
                                        ?.toString() ??
                                    '',
                              ),
                              _evidencia(
                                'foto_conductor',
                                'Foto del conductor',
                                soloFoto: true,
                              ),
                            ]),
                            for (final d in documentosFicha.entries)
                              _seccion(d.value, [
                                TransporteCampos(
                                  children: [
                                    _fechaDocumento(
                                      '${d.key}_desde',
                                      'Vigencia desde',
                                    ),
                                    _fechaDocumento(d.value, 'Vigencia hasta'),
                                    _fechaDocumento(
                                      '${d.key}_expedido',
                                      'Fecha de expedición',
                                    ),
                                    _campo(
                                      '${d.key}_valor',
                                      'Valor · COP',
                                      numero: true,
                                      valor:
                                          widget
                                              .vehiculo
                                              .datos['${d.key}_valor']
                                              ?.toString() ??
                                          '',
                                    ),
                                  ],
                                ),
                                _campo(
                                  '${d.key}_observaciones',
                                  'Observaciones',
                                  lineas: 2,
                                  valor:
                                      widget
                                          .vehiculo
                                          .datos['${d.key}_observaciones']
                                          ?.toString() ??
                                      '',
                                ),
                                _evidencia(
                                  'doc_${d.key}',
                                  'Archivo de ${d.value}',
                                ),
                              ]),
                          ],
                          if (_documentos)
                            _seccion('Documentos y programación', [
                              TransporteCampos(
                                children: [
                                  _campo(
                                    'licencia_transito',
                                    'Número de licencia de tránsito',
                                    valor:
                                        widget
                                            .vehiculo
                                            .datos['licencia_transito']
                                            ?.toString() ??
                                        '',
                                  ),
                                  _campo(
                                    'proximo_aceite',
                                    'Próximo cambio de aceite · km',
                                    numero: true,
                                    valor:
                                        widget.vehiculo.datos['proximo_aceite']
                                            ?.toString() ??
                                        '',
                                  ),
                                ],
                              ),
                            ]),
                          if (_check) ...[
                            if (widget.tipo == 'Inicio de jornada')
                              const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: Text(
                                  'Al guardar, la salida quedará pendiente de aprobación del administrador. Espera su confirmación antes de salir a ruta.',
                                ),
                              ),
                            LinearProgressIndicator(
                              value:
                                  _respuestas.length /
                                  checklistConductor.values
                                      .expand((p) => p)
                                      .length,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                '${_respuestas.length} de ${checklistConductor.values.expand((p) => p).length} puntos revisados',
                              ),
                            ),
                            TransporteCategorias(
                              labels: checklistConductor.keys.toList(),
                              selected: _categoria,
                              enabled: !_ocupado,
                              onSelected: (i) => setState(() => _categoria = i),
                              child: _seccion(
                                checklistConductor.keys.elementAt(_categoria),
                                [
                                  for (final pregunta in checklistConductor
                                      .values
                                      .elementAt(_categoria))
                                    Container(
                                      key: ValueKey('punto-$pregunta'),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: ConductorDesign.line,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pregunta,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              for (final estado in const [
                                                'Buen estado',
                                                'Con novedad',
                                              ])
                                                ChoiceChip(
                                                  label: Text(estado),
                                                  selected:
                                                      _respuestas[pregunta] ==
                                                      estado,
                                                  onSelected:
                                                      _ocupado
                                                          ? null
                                                          : (_) => setState(
                                                            () =>
                                                                _respuestas[pregunta] =
                                                                    estado,
                                                          ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      TextButton(
                                        onPressed:
                                            _categoria > 0 && !_ocupado
                                                ? () =>
                                                    setState(() => _categoria--)
                                                : null,
                                        child: const Text('Anterior'),
                                      ),
                                      TextButton(
                                        onPressed:
                                            _categoria <
                                                        checklistConductor
                                                                .length -
                                                            1 &&
                                                    !_ocupado
                                                ? () =>
                                                    setState(() => _categoria++)
                                                : null,
                                        child: const Text(
                                          'Siguiente categoría',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (_respuestas.containsValue('Con novedad'))
                              const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: Text(
                                  'Hay novedades. El resultado requerirá revisión; no equivale a una autorización de salida.',
                                  style: TextStyle(color: Colors.deepOrange),
                                ),
                              ),
                          ],
                          if (widget.tipo == 'Fin de jornada')
                            _seccion('Seguridad del recorrido', [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  '¿Ocurrió algún siniestro vial durante el recorrido?',
                                ),
                                value: _siniestro,
                                onChanged:
                                    _ocupado
                                        ? null
                                        : (v) => setState(() {
                                          _siniestro = v;
                                          if (!v) {
                                            _evidencias['evidencia_siniestro']
                                                ?.descartar();
                                            _ctrl(
                                              'evidencia_siniestro',
                                            ).clear();
                                            _ctrl('hecho').clear();
                                          }
                                        }),
                              ),
                              if (_siniestro) ...[
                                _campo(
                                  'hecho',
                                  'Describe brevemente el hecho',
                                  obligatorio: true,
                                  lineas: 3,
                                ),
                                _evidencia(
                                  'evidencia_siniestro',
                                  'Evidencia del siniestro',
                                  obligatorio: true,
                                ),
                              ],
                            ]),
                          if (widget.tipo == 'Tanqueo')
                            _seccion('Combustible', [
                              TransporteCampos(
                                children: [
                                  _campo(
                                    'km_tanqueo',
                                    'Kilometraje del tanqueo',
                                    numero: true,
                                    obligatorio: true,
                                    valor: widget.vehiculo.km.toString(),
                                  ),
                                  _campo(
                                    'cantidad',
                                    'Cantidad de combustible · litros',
                                    numero: true,
                                    obligatorio: true,
                                  ),
                                  _campo(
                                    'valor',
                                    'Valor del tanqueo · COP',
                                    numero: true,
                                    obligatorio: true,
                                  ),
                                  _campo('estacion', 'Estación de servicio'),
                                ],
                              ),
                            ]),
                          if (_mantenimiento)
                            _seccion('Servicio realizado', [
                              if (widget.actividad != null) ...[
                                Text(
                                  'Asignado por el administrador: ${widget.actividad!['descripcion']}',
                                ),
                                const Text(
                                  'El mantenimiento asignado no se puede modificar. La entrega quedará pendiente de validación.',
                                ),
                                const SizedBox(height: 16),
                              ],
                              TransporteCampos(
                                children: [
                                  if (_preventivo && widget.actividad == null)
                                    _selectorServicio()
                                  else
                                    _campo(
                                      'servicio',
                                      'Mantenimiento realizado',
                                      obligatorio: true,
                                    ),
                                  _campo(
                                    'taller',
                                    'Taller o responsable',
                                    obligatorio: true,
                                  ),
                                  _campo(
                                    'valor',
                                    'Valor total mantenimientos · COP',
                                    obligatorio: true,
                                    numero: true,
                                  ),
                                  if (_tanqueoPreventivo)
                                    _campo(
                                      'galones',
                                      'Galones del tanqueo',
                                      obligatorio: true,
                                      numero: true,
                                      placeholder: 'Ej. 12,5',
                                    ),
                                  if (!_preventivo)
                                    _campo(
                                      'proximo_km',
                                      'Próximo control · km',
                                      numero: true,
                                    ),
                                  if (!_preventivo)
                                    _fechaDocumento(
                                      'proxima_fecha',
                                      'Próximo control · Fecha',
                                    ),
                                ],
                              ),
                            ]),
                          if (widget.tipo == 'Reposición de fluidos')
                            _seccion('Llenado de niveles', [
                              _campo(
                                'fluido',
                                'Fluido repuesto',
                                obligatorio: true,
                              ),
                              _campo(
                                'cantidad',
                                'Cantidad y unidad',
                                obligatorio: true,
                              ),
                            ]),
                          if (widget.tipo == 'Lavado')
                            _seccion('Limpieza del vehículo', [
                              _campo(
                                'servicio',
                                'Limpieza realizada',
                                obligatorio: true,
                              ),
                              _campo('valor', 'Valor · COP', numero: true),
                            ]),
                          ObservacionesEvidenciaConductor(
                            fotos:
                                widget.tipo == 'Registro diario'
                                    ? [
                                      for (final lado
                                          in fotosVehiculoConductor.keys)
                                        _evidencias.putIfAbsent(
                                          'foto_$lado',
                                          EvidenciaSeleccionada.new,
                                        ),
                                    ]
                                    : const [],
                            fotoBuilder:
                                (lado, titulo, ayuda) => _evidencia(
                                  'foto_$lado',
                                  titulo,
                                  soloFoto: true,
                                  estilo: EstiloEvidencia.foto,
                                  ayuda: ayuda,
                                ),
                            observaciones: _campo(
                              'notas',
                              widget.tipo == 'Siniestro vial'
                                  ? 'Describe brevemente el hecho'
                                  : 'Novedades / observaciones',
                              lineas: 4,
                              placeholder:
                                  'Describe daños, faltantes o cualquier novedad del vehículo…',
                            ),
                            adicionalObligatorio: widget.actividad != null,
                            tituloAdicional:
                                widget.tipo == 'Tanqueo'
                                    ? 'Factura del tanqueo'
                                    : _mantenimiento
                                    ? 'Evidencia de mantenimiento'
                                    : 'Evidencia adicional',
                            adicional: _evidencia(
                              'enlace',
                              widget.tipo == 'Tanqueo'
                                  ? 'Factura del tanqueo'
                                  : _mantenimiento
                                  ? 'Evidencia de mantenimiento'
                                  : 'Fotos o documento de evidencia',
                              obligatorio: widget.actividad != null,
                              estilo: EstiloEvidencia.adicional,
                              ayuda:
                                  'Fotos o documentos que respalden el registro',
                            ),
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: AvisoFormulario(_error!),
                            ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
    ),
  );
}
