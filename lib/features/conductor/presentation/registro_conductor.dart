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
  });
  final VehiculoConductor vehiculo;
  final String tipo;
  @override
  ConsumerState<RegistroConductorPage> createState() =>
      _RegistroConductorPageState();
}

class _RegistroConductorPageState extends ConsumerState<RegistroConductorPage> {
  final _form = GlobalKey<FormState>();
  final _campos = <String, TextEditingController>{};
  final _respuestas = <String, String>{};
  bool _guardando = false;
  final _evidenciasOcupadas = <String>{};
  final _evidencias = <String, EvidenciaSeleccionada>{};
  String? _progresoSubida;
  bool get _ocupado => _guardando || _evidenciasOcupadas.isNotEmpty;
  bool _siniestro = false;
  String? _error;
  DateTime _fecha = DateTime.now();
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
            controller: _ctrl(key, valor),
            enabled: !_guardando,
            keyboardType:
                numero
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
            minLines: lineas,
            maxLines: lineas,
            decoration: InputDecoration(hintText: placeholder),
            validator: (v) {
              if (obligatorio && (v == null || v.trim().isEmpty)) {
                return 'Campo obligatorio';
              }
              if (numero &&
                  v != null &&
                  v.isNotEmpty &&
                  (double.tryParse(v) == null ||
                      !double.parse(v).isFinite ||
                      double.parse(v) < 0)) {
                return 'Ingresa un número válido';
              }
              return null;
            },
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
      setState(() => _error = fallo);
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
    setState(() {
      _guardando = true;
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
      await ref
          .read(conductorRepositoryProvider)
          .guardar(widget.vehiculo.id, widget.tipo, km, {
            for (final e in _campos.entries)
              if (e.key != 'km') e.key: e.value.text.trim(),
            for (final e in _evidencias.entries)
              if (e.value.enlace != null) e.key: e.value.enlace!,
            'fecha': DateFormat('yyyy-MM-dd').format(_fecha),
            if (_check) 'respuestas': _respuestas,
            if (widget.tipo == 'Fin de jornada') 'siniestro': _siniestro,
            if (_check)
              'resultado':
                  _respuestas.containsValue('Con novedad')
                      ? 'Requiere revisión'
                      : 'Sin novedades',
          });
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
            child: Scaffold(
              appBar: AppBar(
                title: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ORBILOQ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Grupo Quiromar · Portal del conductor',
                      style: TextStyle(fontSize: 11, color: Color(0xFFC0D7E0)),
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
                    constraints: BoxConstraints(
                      maxWidth: widget.tipo == 'Registro diario' ? 1160 : 850,
                    ),
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
                            Text(
                              'Fecha: ${DateFormat("dd/MM/yyyy").format(_fecha)}',
                            ),
                            if (!_check && !_documentos)
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
                          if (_documentos)
                            _seccion('Documentos y programación', [
                              for (final doc in documentosConductor)
                                _fechaDocumento(doc, '$doc · Vencimiento'),
                              _campo(
                                'licencia_transito',
                                'Número de licencia de tránsito',
                                valor:
                                    widget.vehiculo.datos['licencia_transito']
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
                            ]),
                          if (_check) ...[
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
                            for (final grupo in checklistConductor.entries)
                              _seccion(grupo.key, [
                                for (final pregunta in grupo.value)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      initialValue: _respuestas[pregunta],
                                      decoration: InputDecoration(
                                        labelText: pregunta,
                                      ),
                                      items:
                                          const ['Buen estado', 'Con novedad']
                                              .map(
                                                (r) => DropdownMenuItem(
                                                  value: r,
                                                  child: Text(r),
                                                ),
                                              )
                                              .toList(),
                                      onChanged:
                                          _guardando
                                              ? null
                                              : (r) => setState(
                                                () =>
                                                    _respuestas[pregunta] = r!,
                                              ),
                                      validator:
                                          (r) =>
                                              r == null
                                                  ? 'Revisa este punto'
                                                  : null,
                                    ),
                                  ),
                              ]),
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
                            ]),
                          if (_mantenimiento)
                            _seccion('Servicio realizado', [
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
                              _campo(
                                'proximo_km',
                                'Próximo control · km',
                                numero: true,
                              ),
                              _fechaDocumento(
                                'proxima_fecha',
                                'Próximo control · Fecha',
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
                              estilo: EstiloEvidencia.adicional,
                              ayuda:
                                  'Fotos o documentos que respalden el registro',
                            ),
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                _error!,
                                semanticsLabel: _error,
                                style: const TextStyle(color: Colors.red),
                              ),
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
