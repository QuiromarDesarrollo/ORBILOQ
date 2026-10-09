import 'package:orbiloq_wms/shared/widgets/wms_alert.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../data/ciclos_repository.dart';
import '../../../data/excel_ciclos.dart';
import '../../../domain/ciclos.dart';

Future<bool> importarCiclos(
  BuildContext context,
  CiclosRepository repo,
  DatosCiclos datos,
) async {
  final archivo = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
    withData: true,
  );
  if (archivo == null) return false;
  final file = archivo.files.single;
  if (file.bytes == null) {
    throw const FormatException('No se pudo leer el archivo.');
  }
  final filas = ExcelCiclos.leer(file.bytes!);
  final resumen = await repo.importar(filas, datos.revision, false, file.name);
  if (!context.mounted) return false;
  final confirmar = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('Revisar importación de ciclos'),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${file.name}\n${resumen['total']} OP · ${resumen['nuevas']} nuevas · ${resumen['actualizadas']} actualizadas',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${resumen['fechas_borradas']} fechas existentes pasarán a vacío.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Las filas incluidas reemplazan los datos anteriores, incluso las fechas vacías. Las OP ausentes se conservan. Cada importación queda auditada.',
                  ),
                  const Divider(),
                  for (final f in filas.take(15))
                    Text(
                      '${f['op']} · ${f['cliente']} · ${f['cantidad']} unidades · Inicio: ${f['inicio'] ?? 'Sin fecha'}',
                    ),
                  if (filas.length > 15)
                    Text('… y ${filas.length - 15} OP más.'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar importación'),
            ),
          ],
        ),
  );
  if (confirmar != true) return false;
  await repo.importar(filas, datos.revision, true, file.name);
  return true;
}

class ParametrosCiclosDialog extends StatefulWidget {
  const ParametrosCiclosDialog({
    super.key,
    required this.repo,
    required this.datos,
  });
  final CiclosRepository repo;
  final DatosCiclos datos;
  @override
  State<ParametrosCiclosDialog> createState() => _ParametrosState();
}

class _ParametrosState extends State<ParametrosCiclosDialog> {
  ProcesoCiclo _proceso = ProcesoCiclo.compras;
  late DatosCiclos _datos = widget.datos;
  final _dias = TextEditingController(),
      _diaria = TextEditingController(),
      _semanal = TextEditingController(),
      _cola = TextEditingController();
  DateTime? _desde;
  String? _error;
  bool _ocupado = false, _cambio = false;
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    final v = parametroVigente(_datos.parametros, _proceso, _datos.hoy);
    _cola.text =
        (v == null && _proceso == ProcesoCiclo.trazo ? 45 : v?.umbralCola)
            ?.toString() ??
        '';
    _dias.text = '${v?.dias ?? _proceso.diasIniciales}';
    _diaria.text = v?.diaria?.toString() ?? '';
    _semanal.text =
        (v == null ? _proceso.semanalInicial : v.semanal)?.toString() ?? '';
  }

  @override
  void dispose() {
    _dias.dispose();
    _diaria.dispose();
    _semanal.dispose();
    _cola.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    try {
      final dias = int.tryParse(_dias.text),
          diaria = int.tryParse(_diaria.text),
          semanal = int.tryParse(_semanal.text);
      final cola = int.tryParse(_cola.text);
      if ((_cola.text.isNotEmpty && (cola == null || cola <= 0)) ||
          _desde == null ||
          dias == null ||
          dias < 0 ||
          dias > 3650 ||
          (_diaria.text.isNotEmpty && (diaria == null || diaria <= 0)) ||
          (_semanal.text.isNotEmpty && (semanal == null || semanal <= 0))) {
        throw const FormatException(
          'Indica la fecha de vigencia, días de 0 a 3650 y capacidades enteras positivas o vacías.',
        );
      }
      setState(() => _ocupado = true);
      await widget.repo.configurar(
        _proceso,
        _desde!,
        dias,
        diaria,
        semanal,
        _datos.revision,
        umbralCola: _proceso == ProcesoCiclo.trazo ? cola : null,
      );
      _cambio = true;
      final nuevos = await widget.repo.cargar();
      if (!mounted) return;
      setState(() {
        _datos = nuevos;
        _error = null;
        _desde = null;
      });
      mostrarAvisoSnack(context, const SnackBar(content: Text('Versión guardada.')), tipo: TipoAviso.exito);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado,
    child: AlertDialog(
      title: const Text('Parámetros de tiempos y capacidad'),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cada cambio crea una versión con fecha de vigencia. Conservamos las versiones históricas. Los plazos se cuentan de lunes a viernes sin festivos nacionales de Colombia.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ProcesoCiclo>(
                initialValue: _proceso,
                decoration: const InputDecoration(labelText: 'Proceso'),
                items: [
                  for (final p in ProcesoCiclo.values)
                    DropdownMenuItem(value: p, child: Text(p.titulo)),
                ],
                onChanged:
                    _ocupado
                        ? null
                        : (p) => setState(() {
                          _proceso = p!;
                          _cargar();
                        }),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  _desde == null
                      ? 'Elegir fecha de vigencia'
                      : fechaCiclo(_desde!),
                ),
                onPressed:
                    _ocupado
                        ? null
                        : () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _datos.hoy,
                            firstDate: DateTime(1900),
                            lastDate: DateTime(2200, 12, 31),
                          );
                          if (d != null && mounted) {
                            setState(() => _desde = diaCiclo(d));
                          }
                        },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dias,
                enabled: !_ocupado,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Días hábiles de ciclo',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _diaria,
                enabled: !_ocupado,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Capacidad diaria (${_proceso.unidad})',
                  helperText: 'Vacío: sin capacidad configurada',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _semanal,
                enabled: !_ocupado,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Capacidad semanal (${_proceso.unidad})',
                  helperText: 'Límite independiente de la capacidad diaria',
                ),
              ),
              const SizedBox(height: 12),
              if (_proceso == ProcesoCiclo.trazo)
                TextField(
                  controller: _cola,
                  enabled: !_ocupado,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Umbral de cola diaria (OP)',
                    helperText:
                        'Alerta por OP pendientes; no es capacidad de producción',
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'Reserva total: 3 días hábiles adicionales a la suma de los procesos.',
              ),
              if (_error != null)
                AvisoFormulario(_error!),
              const Divider(),
              const Text('Versiones guardadas'),
              for (final p
                  in _datos.parametros
                      .where((v) => v.proceso == _proceso)
                      .toList()
                    ..sort((a, b) => b.desde.compareTo(a.desde)))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '${fechaCiclo(p.desde)} · ${p.dias} días · Diaria: ${p.diaria ?? '—'} · Semanal: ${p.semanal ?? '—'} · Umbral de cola: ${p.umbralCola ?? '—'}',
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _ocupado ? null : () => Navigator.pop(context, _cambio),
          child: const Text('Cerrar'),
        ),
        FilledButton(
          onPressed: _ocupado ? null : _guardar,
          child: Text(_ocupado ? 'Guardando…' : 'Guardar nueva versión'),
        ),
      ],
    ),
  );
}
