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
  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
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
    setState(() => _rango = rango);
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
  Widget build(BuildContext context) => Column(
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
          if (widget.administrador) ...[
            OutlinedButton(
              onPressed:
                  _cargando || _exportando || _jornadas.isEmpty
                      ? null
                      : () => setState(() {
                        if (_seleccion.length == _jornadas.length) {
                          _seleccion.clear();
                        } else {
                          _seleccion.addAll(_jornadas.map((j) => j.fecha));
                        }
                      }),
              child: Text(
                _jornadas.isNotEmpty && _seleccion.length == _jornadas.length
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
      const SizedBox(height: 16),
      if (_error != null)
        ConductorPanel(
          title: 'No se pudo completar',
          children: [
            Text(_error!),
            TextButton(
              onPressed: _cargando ? null : _cargar,
              child: const Text('Volver a cargar'),
            ),
          ],
        ),
      if (_cargando)
        const LinearProgressIndicator(semanticsLabel: 'Cargando historial')
      else if (_error == null && _jornadas.isEmpty)
        const ConductorPanel(
          title: 'Sin registros en estas fechas',
          children: [Text('Prueba con otro rango de fechas.')],
        )
      else if (_error == null || _jornadas.isNotEmpty)
        for (final jornada in _jornadas) _tarjeta(jornada),
    ],
  );

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
