import '../../../shared/widgets/wms_alert.dart';
import 'flota_design.dart';
import '../../../shared/widgets/wms_loader.dart';
import '../kit_semanal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/descargar_excel.dart';
import '../conductor_model.dart';
import '../conductor_repository.dart';
import '../historial_conductor.dart';
import 'conductor_design.dart';

class HistorialConductorView extends ConsumerStatefulWidget {
  const HistorialConductorView({
    super.key,
    required this.vehiculo,
    required this.administrador,
  });
  final VehiculoConductor vehiculo;
  final bool administrador;
  @override
  ConsumerState<HistorialConductorView> createState() =>
      _HistorialConductorViewState();
}

class _HistorialConductorViewState
    extends ConsumerState<HistorialConductorView> {
  late DateTimeRange _rango;
  List<JornadaConductor> _jornadas = [];
  final _seleccion = <String>{};
  bool _cargando = true, _exportando = false;
  String? _error;
  int _consulta = 0;
  String _estado = 'Todas', _periodo = 'Este mes';
  bool _recientes = true;
  static const _estados = [
    'Todas',
    'Completas',
    'Incompletas',
    'Inicio pendiente',
    'Cierre pendiente',
    'Sin inspecciones',
  ];
  List<JornadaConductor> get _visibles {
    final lista =
        _jornadas
            .where(
              (j) => switch (_estado) {
                'Completas' => j.inicio && j.fin,
                'Incompletas' => j.inspecciones < 2,
                'Inicio pendiente' => !j.inicio,
                'Cierre pendiente' => !j.fin,
                'Sin inspecciones' => j.inspecciones == 0,
                _ => true,
              },
            )
            .toList();
    lista.sort(
      (a, b) =>
          _recientes ? b.fecha.compareTo(a.fecha) : a.fecha.compareTo(b.fecha),
    );
    return lista;
  }

  Future<void> _periodoRapido(String periodo) async {
    final hoy = hoyColombia();
    final desde = switch (periodo) {
      'Hoy' => hoy,
      'Últimos 7 días' => hoy.subtract(const Duration(days: 6)),
      'Mes anterior' => DateTime(hoy.year, hoy.month - 1),
      _ => DateTime(hoy.year, hoy.month),
    };
    setState(() {
      _periodo = periodo;
      _rango = DateTimeRange(
        start: desde,
        end: periodo == 'Mes anterior' ? DateTime(hoy.year, hoy.month, 0) : hoy,
      );
    });
    await _cargar();
  }

  void _cambiarEstado(String estado) => setState(() {
    _estado = estado;
    // La exportación siempre corresponde a la lista que se ve en pantalla.
    _seleccion.clear();
  });

  @override
  void initState() {
    super.initState();
    final hoy = hoyColombia();
    _rango = DateTimeRange(
      start: DateTime(hoy.year, hoy.month),
      end: DateTime(hoy.year, hoy.month, hoy.day),
    );
    _cargar();
  }

  Future<void> _cargar() async {
    final consulta = ++_consulta;
    setState(() {
      _cargando = true;
      _error = null;
      _seleccion.clear();
      _jornadas = [];
    });
    try {
      final registros = await ref
          .read(conductorRepositoryProvider)
          .historialPeriodo(widget.vehiculo.id, _rango.start, _rango.end);
      if (!mounted || consulta != _consulta) return;
      setState(() => _jornadas = agruparJornadasConductor(registros));
    } catch (_) {
      if (mounted && consulta == _consulta) {
        setState(
          () =>
              _error =
                  'No se pudo cargar el historial. Revisa la conexión y vuelve a intentarlo.',
        );
      }
    } finally {
      if (mounted && consulta == _consulta) setState(() => _cargando = false);
    }
  }

  Future<void> _filtrar() async {
    final rango = await showDateRangePicker(
      context: context,
      initialDateRange: _rango,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Fechas del historial',
      saveText: 'Aplicar',
    );
    if (!mounted || rango == null) return;
    setState(() {
      _rango = rango;
      _periodo = 'Personalizado';
    });
    await _cargar();
  }

  Future<void> _exportar() async {
    if (!widget.administrador ||
        _seleccion.isEmpty ||
        _exportando ||
        _cargando) {
      return;
    }
    setState(() {
      _exportando = true;
      _error = null;
    });
    try {
      // Presenta el estado de exportación antes de generar el archivo.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final jornadas =
          _jornadas.where((j) => _seleccion.contains(j.fecha)).toList();
      final bytes = generarExcelHistorialConductor(widget.vehiculo, jornadas);
      final placa = widget.vehiculo.placa.replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'),
        '_',
      );
      await descargarExcel(
        bytes,
        'historial_${placa}_${DateFormat('yyyyMMdd').format(_rango.start)}_${DateFormat('yyyyMMdd').format(_rango.end)}.xlsx',
      );
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error =
                  e is FormatException
                      ? e.message
                      : 'No se pudo exportar el archivo. Tu selección se conserva; vuelve a intentarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _visibles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Historial del vehículo',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          widget.administrador
              ? 'Selecciona los días que quieres exportar. Se incluyen todas sus inspecciones y actividades.'
              : 'Consulta si registraste el inicio y el cierre de cada jornada.',
        ),
        const SizedBox(height: 16),
        ConductorPanel(
          title: 'Filtrar historial',
          icon: Icons.filter_list,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final periodo in [
                  'Hoy',
                  'Últimos 7 días',
                  'Este mes',
                  'Mes anterior',
                ])
                  ChoiceChip(
                    label: Text(periodo),
                    selected: _periodo == periodo,
                    onSelected:
                        _exportando ? null : (_) => _periodoRapido(periodo),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, c) {
                final ancho =
                    c.maxWidth < 650 ||
                            MediaQuery.textScalerOf(context).scale(14) > 21
                        ? c.maxWidth
                        : (c.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: ancho,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('estado-$_estado'),
                        initialValue: _estado,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Estado de la jornada',
                        ),
                        items: [
                          for (final e in _estados)
                            DropdownMenuItem(value: e, child: Text(e)),
                        ],
                        onChanged:
                            _exportando
                                ? null
                                : (e) {
                                  if (e != null) _cambiarEstado(e);
                                },
                      ),
                    ),
                    SizedBox(
                      width: ancho,
                      child: DropdownButtonFormField<bool>(
                        key: ValueKey('orden-$_recientes'),
                        initialValue: _recientes,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Ordenar por fecha',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: true,
                            child: Text('Más recientes primero'),
                          ),
                          DropdownMenuItem(
                            value: false,
                            child: Text('Más antiguas primero'),
                          ),
                        ],
                        onChanged:
                            _exportando
                                ? null
                                : (v) => setState(() => _recientes = v ?? true),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _exportando ? null : _filtrar,
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    '${DateFormat('dd/MM/yyyy').format(_rango.start)} – ${DateFormat('dd/MM/yyyy').format(_rango.end)}',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _cargando || _exportando ? null : _cargar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar'),
                ),
                TextButton.icon(
                  onPressed:
                      _exportando
                          ? null
                          : () {
                            setState(() {
                              _estado = 'Todas';
                              _recientes = true;
                            });
                            _periodoRapido('Este mes');
                          },
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Limpiar filtros'),
                ),
                if (widget.administrador) ...[
                  OutlinedButton(
                    onPressed:
                        _cargando || _exportando || visibles.isEmpty
                            ? null
                            : () => setState(() {
                              if (_seleccion.length == visibles.length) {
                                _seleccion.clear();
                              } else {
                                _seleccion.addAll(visibles.map((j) => j.fecha));
                              }
                            }),
                    child: Text(
                      visibles.isNotEmpty &&
                              _seleccion.length == visibles.length
                          ? 'Quitar selección'
                          : 'Seleccionar todos',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed:
                        _seleccion.isEmpty || _cargando || _exportando
                            ? null
                            : _exportar,
                    icon: const Icon(Icons.download_outlined),
                    label: Text(
                      _exportando
                          ? 'Generando Excel…'
                          : 'Exportar Excel (${_seleccion.length})',
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!_cargando)
          Text(
            'Mostrando ${visibles.length} de ${_jornadas.length} jornadas del período',
            style: const TextStyle(color: ConductorDesign.muted),
          ),
        const SizedBox(height: 16),
        if (_error != null)
          ConductorPanel(
            title: 'No se pudo completar',
            children: [
              AvisoFormulario(_error!),
              TextButton(
                onPressed: _cargando ? null : _cargar,
                child: const Text('Volver a cargar'),
              ),
            ],
          ),
        if (_exportando)
          const WmsLoadingPanel(
            label: 'Generando archivo Excel del historial…',
          ),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: WmsLoadingPanel(
              label: 'Consultando jornadas del período seleccionado…',
            ),
          )
        else if (_error == null && _jornadas.isEmpty)
          const ConductorPanel(
            title: 'Sin registros en estas fechas',
            children: [Text('Prueba con otro rango de fechas.')],
          )
        else if (_error == null && visibles.isEmpty)
          ConductorPanel(
            title: 'Sin coincidencias con estos filtros',
            children: [
              const Text(
                'Cambia el estado de la jornada o amplía el rango de fechas.',
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _cambiarEstado('Todas'),
                  child: const Text('Ver todos los estados'),
                ),
              ),
            ],
          )
        else if (_error == null || _jornadas.isNotEmpty)
          FlotaGrid(
            columns: 3,
            children: [for (final jornada in visibles) _tarjeta(jornada)],
          ),
      ],
    );
  }

  Widget _tarjeta(JornadaConductor jornada) {
    final fecha = DateTime.tryParse(jornada.fecha);
    return ConductorPanel(
      title:
          fecha == null
              ? jornada.fecha
              : DateFormat('dd/MM/yyyy').format(fecha),
      children: [
        if (widget.administrador)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              'Seleccionar día · ${jornada.registros.length} ${jornada.registros.length == 1 ? 'registro' : 'registros'}',
            ),
            value: _seleccion.contains(jornada.fecha),
            onChanged:
                _exportando
                    ? null
                    : (value) => setState(() {
                      if (value == true) {
                        _seleccion.add(jornada.fecha);
                      } else {
                        _seleccion.remove(jornada.fecha);
                      }
                    }),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            ConductorBadge(
              'Inicio: ${jornada.inicio ? 'registrado' : 'pendiente'}',
              warning: !jornada.inicio,
            ),
            ConductorBadge(
              'Cierre: ${jornada.fin ? 'registrado' : 'pendiente'}',
              warning: !jornada.fin,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${jornada.inspecciones} de 2 inspecciones completadas',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (jornada.registros.any((r) => r['tipo'] == tipoKitSemanal))
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: ConductorBadge('Kit semanal: registrado'),
          ),
        if (widget.administrador)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Ver registros del día'),
            children: [
              for (final registro in jornada.registros)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(),
                    Text(
                      registro['tipo']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${registro['actor_nombre'] ?? ''} · ${registro['km'] ?? ''} km',
                    ),
                    if (registro['creado'] != null)
                      Text('Registrado: ${registro['creado']}'),
                    for (final dato
                        in aplanarDatosConductor(
                          registro['datos'] as Map? ?? {},
                        ).entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: SelectableText(
                          '${etiquetasDatosConductor[dato.key] ?? dato.key}: ${dato.value ?? ''}',
                        ),
                      ),
                  ],
                ),
            ],
          ),
      ],
    );
  }
}
