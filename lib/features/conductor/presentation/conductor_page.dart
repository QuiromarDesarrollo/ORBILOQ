import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../application/auth_providers.dart';
import '../../../core/conductor_entorno.dart';
import '../../../domain/sesion.dart';
import '../../../shared/widgets/wms_loader.dart';
import '../conductor_model.dart';
import '../conductor_repository.dart';
import 'registro_conductor.dart';
import 'historial_conductor_view.dart';
import 'conductor_design.dart';

class ConductorPage extends ConsumerStatefulWidget {
  const ConductorPage({super.key});
  @override
  ConsumerState<ConductorPage> createState() => _ConductorPageState();
}

class _ConductorPageState extends ConsumerState<ConductorPage> {
  List<VehiculoConductor> _vehiculos = [];
  List<Map<String, dynamic>> _historial = [];
  VehiculoConductor? _vehiculo;
  bool _cargando = true;
  String? _error;
  int _tab = 0;
  String? _detalle;
  bool get _admin =>
      !ref.read(usarSupabaseProvider) ||
      ref.read(usuarioSesionProvider).value?.tieneRol(RolCuenta.admin) == true;
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (!conductorHabilitado()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final repo = ref.read(conductorRepositoryProvider);
      final vehiculos = await repo.vehiculos();
      final actual =
          vehiculos.where((v) => v.id == _vehiculo?.id).firstOrNull ??
          vehiculos.firstOrNull;
      final historial =
          actual == null
              ? <Map<String, dynamic>>[]
              : await repo.historial(actual.id);
      if (!mounted) return;
      setState(() {
        _vehiculos = vehiculos;
        _vehiculo = actual;
        _historial = historial;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error =
                  'No se pudo cargar la flota. Revisa la conexión o comunícate con el administrador.',
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _registrar(String tipo) async {
    final v = _vehiculo;
    if (v == null) return;
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RegistroConductorPage(vehiculo: v, tipo: tipo),
      ),
    );
    if (guardado == true) await _cargar();
  }

  Widget _card(String titulo, List<Widget> children) =>
      ConductorPanel(title: titulo, children: children);
  Widget _accion(String texto, IconData icono, VoidCallback accion) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: FilledButton.icon(
      onPressed: accion,
      icon: Icon(icono),
      label: Text(texto),
    ),
  );

  List<Widget> _avisos() {
    final v = _vehiculo!;
    final avisos = <Widget>[];
    for (final doc in documentosConductor) {
      final fecha = DateTime.tryParse(v.datos[doc]?.toString() ?? '');
      if (fecha == null) {
        avisos.add(
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: Text(doc),
            subtitle: const Text('Fecha pendiente de registrar'),
          ),
        );
      } else {
        final dias = diasRestantes(fecha, DateTime.now());
        if (dias <= 30) {
          avisos.add(
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                dias < 0
                    ? Icons.error_outline
                    : Icons.notifications_active_outlined,
                color: dias < 0 ? Colors.red.shade700 : Colors.orange.shade800,
              ),
              title: Text(doc),
              subtitle: Text(
                dias < 0
                    ? 'Vencido hace ${-dias} días'
                    : dias == 0
                    ? 'Vence hoy'
                    : 'Vence en $dias días',
              ),
            ),
          );
        }
      }
    }
    final aceite = int.tryParse(v.datos['proximo_aceite']?.toString() ?? '');
    if (aceite != null && aceite - v.km <= 1000) {
      avisos.add(
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.oil_barrel_outlined),
          title: const Text('Cambio de aceite'),
          subtitle: Text(
            aceite <= v.km
                ? 'Cambio pendiente por kilometraje'
                : 'Faltan ${aceite - v.km} km',
          ),
        ),
      );
    }
    return avisos.isEmpty
        ? [const Text('Sin vencimientos próximos registrados.')]
        : avisos;
  }

  Widget _indicador(String titulo, String valor, {bool warning = false}) =>
      Container(
        constraints: const BoxConstraints(minHeight: 84),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: warning ? const Color(0xFFE7D9B6) : ConductorDesign.line,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                color: ConductorDesign.muted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            if (titulo == 'Estado hoy')
              ConductorBadge(valor, warning: warning)
            else
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 22,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      );

  Widget _tarea(
    String titulo,
    String subtitulo,
    IconData icono,
    VoidCallback accion,
  ) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: accion,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5D7),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 16, color: ConductorDesign.navy),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitulo,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: ConductorDesign.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: ConductorDesign.muted,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _vencimientos({bool completo = false}) => LayoutBuilder(
    builder: (context, box) {
      final docs = completo ? documentosConductor : documentosConductor.take(3);
      final compact =
          box.maxWidth < 540 || MediaQuery.textScalerOf(context).scale(14) > 20;
      Widget cell(Widget child, {bool heading = false}) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: child,
      );
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      completo
                          ? 'Documentos y fechas'
                          : 'Próximos vencimientos',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed:
                        completo
                            ? () => _registrar('Documentos')
                            : () => _seleccionar(4),
                    child: Text(completo ? 'Actualizar' : 'Ver todos'),
                  ),
                ],
              ),
            ),
            if (compact)
              for (final doc in docs) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Vence: ${_vehiculo!.datos[doc]?.toString() ?? 'Sin registrar'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: ConductorDesign.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ConductorBadge(
                        _estadoDocumento(doc),
                        warning:
                            _diasDocumento(doc) == null ||
                            (_diasDocumento(doc) ?? 31) <= 30,
                        error: (_diasDocumento(doc) ?? 1) < 0,
                      ),
                    ],
                  ),
                ),
              ]
            else
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.2),
                  1: FlexColumnWidth(1.3),
                  2: FlexColumnWidth(1.2),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: const TableBorder(
                  horizontalInside: BorderSide(color: ConductorDesign.line),
                ),
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: Color(0xFFF6F8FA)),
                    children: [
                      for (final heading in [
                        'Documento',
                        'Vencimiento',
                        'Estado',
                      ])
                        cell(
                          Text(
                            heading,
                            style: const TextStyle(
                              fontSize: 11,
                              color: ConductorDesign.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          heading: true,
                        ),
                    ],
                  ),
                  for (final doc in docs)
                    TableRow(
                      children: [
                        cell(Text(doc, style: const TextStyle(fontSize: 13))),
                        cell(
                          Text(
                            _vehiculo!.datos[doc]?.toString() ??
                                'Sin registrar',
                            style: const TextStyle(
                              fontSize: 13,
                              color: ConductorDesign.muted,
                            ),
                          ),
                        ),
                        cell(
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ConductorBadge(
                              _estadoDocumento(doc),
                              warning:
                                  _diasDocumento(doc) == null ||
                                  (_diasDocumento(doc) ?? 31) <= 30,
                              error: (_diasDocumento(doc) ?? 1) < 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
          ],
        ),
      );
    },
  );

  Widget _responsivePair(Widget left, Widget right) => LayoutBuilder(
    builder:
        (context, box) =>
            box.maxWidth < 690
                ? Column(children: [left, right])
                : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: left),
                    const SizedBox(width: 14),
                    Expanded(flex: 2, child: right),
                  ],
                ),
  );

  List<Widget> _inicio() {
    final v = _vehiculo!;
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final registrosHoy = _historial.where((r) => r['datos']?['fecha'] == hoy);
    final inicio = registrosHoy.any((r) => r['tipo'] == 'Inicio de jornada');
    final fin = registrosHoy.any((r) => r['tipo'] == 'Fin de jornada');
    final requiereRevision = registrosHoy.any(
      (r) =>
          r['tipo'] == 'Inicio de jornada' &&
          (r['datos']?['resultado'] == 'Requiere revisión' ||
              r['revision_pendiente'] == true),
    );
    final foto = registrosHoy.any(
      (r) =>
          r['tipo'] == 'Registro diario' &&
          (r['evidencia_registrada'] == true ||
              enlaceDriveValido(r['datos']?['enlace']?.toString() ?? '') ||
              [
                'frontal',
                'lateral',
                'lateral_derecho',
                'lateral_izquierdo',
                'trasera',
                'tablero',
              ].any(
                (lado) => enlaceDriveValido(
                  r['datos']?['foto_$lado']?.toString() ?? '',
                ),
              )),
    );
    final nombre =
        ref.read(usarSupabaseProvider)
            ? ref.read(usuarioSesionProvider).value?.nombre.split(' ').first ??
                'conductor'
            : 'conductor';
    final proximos =
        documentosConductor.where((doc) {
          final d = _diasDocumento(doc);
          return d == null || d <= 30;
        }).toList();
    return [
      _encabezado(
        'Inicio',
        'Hola, $nombre',
        DateFormat('dd / MM / yyyy').format(DateTime.now()),
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, box) {
          final metrics = [
            _indicador('Vehículo', v.placa),
            _indicador('Km actual', NumberFormat.decimalPattern().format(v.km)),
            _indicador(
              'Estado hoy',
              fin
                  ? 'Jornada cerrada'
                  : requiereRevision
                  ? 'Requiere revisión'
                  : inicio
                  ? 'Salida registrada'
                  : 'Checklist pendiente',
              warning: !inicio || requiereRevision,
            ),
          ];
          final cols =
              box.maxWidth >= 600
                  ? 3
                  : box.maxWidth >= 320 &&
                      MediaQuery.textScalerOf(context).scale(14) < 21
                  ? 2
                  : 1;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final metric in metrics.asMap().entries)
                SizedBox(
                  width:
                      cols == 2 && metric.key == 2
                          ? box.maxWidth
                          : (box.maxWidth - (cols - 1) * 10) / cols,
                  child: metric.value,
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 14),
      _responsivePair(
        _card('Tu día de hoy', [
          _tarea(
            'Checklist de salida',
            requiereRevision
                ? 'Hay novedades por revisar'
                : inicio
                ? 'Inspección registrada'
                : 'Pendiente de completar',
            Icons.fact_check_outlined,
            () => _seleccionar(1),
          ),
          const Divider(height: 1),
          _tarea(
            'Seguimiento diario',
            foto ? 'Evidencia registrada' : 'Foto y estado pendientes',
            Icons.camera_alt_outlined,
            () => _seleccionar(2),
          ),
          const Divider(height: 1),
          _tarea(
            'Mantenimiento',
            v.datos['proximo_aceite'] == null
                ? 'Sin cambio de aceite programado'
                : 'Próximo cambio: ${v.datos['proximo_aceite']} km',
            Icons.build_outlined,
            () => _seleccionar(3),
          ),
          if (inicio && !fin) ...[
            const Divider(height: 1),
            _tarea(
              'Checklist de regreso',
              'Completa la inspección al finalizar',
              Icons.flag_outlined,
              () => _registrar('Fin de jornada'),
            ),
          ],
        ]),
        _card('Alertas recientes', [
          if (proximos.isEmpty && foto) const Text('No hay avisos pendientes.'),
          for (final doc in proximos.take(2))
            _tarea(
              doc,
              _estadoDocumento(doc),
              Icons.notification_important_outlined,
              () => _seleccionar(5),
            ),
          if (!foto)
            _tarea(
              'Foto del día pendiente',
              'Toma o selecciona una foto para tu registro',
              Icons.camera_alt_outlined,
              () => _seleccionar(2),
            ),
        ]),
      ),
      const SizedBox(height: 2),
      _vencimientos(),
    ];
  }

  Widget _encabezado(String seccion, String titulo, String? fecha) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conductor / $seccion',
              style: const TextStyle(
                color: ConductorDesign.muted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              titulo,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        if (fecha != null)
          Text(
            fecha,
            style: const TextStyle(color: ConductorDesign.muted, fontSize: 12),
          ),
      ],
    ),
  );

  List<Widget> _checklistVista() {
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final records = _historial.where((r) => r['datos']?['fecha'] == hoy);
    final inicio =
        records.where((r) => r['tipo'] == 'Inicio de jornada').firstOrNull;
    final fin = records.where((r) => r['tipo'] == 'Fin de jornada').firstOrNull;
    final requiereRevision =
        inicio?['datos']?['resultado'] == 'Requiere revisión' ||
        inicio?['revision_pendiente'] == true;
    final total = checklistConductor.values.expand((e) => e).length;
    return [
      _encabezado('Checklist', 'Inspección del vehículo', null),
      const Text(
        'Se completa al iniciar y al finalizar la jornada.',
        style: TextStyle(color: ConductorDesign.muted),
      ),
      const SizedBox(height: 16),
      _responsivePair(
        _card('Puntos de revisión', [
          for (final category in checklistConductor.entries) ...[
            Text(
              category.key,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: ConductorDesign.navy,
              ),
            ),
            const SizedBox(height: 6),
            for (final point in category.value)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.radio_button_unchecked,
                      size: 18,
                      color: ConductorDesign.cyan,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(point)),
                  ],
                ),
              ),
            const Divider(height: 1),
          ],
        ]),
        _card('Estado de hoy', [
          Text(
            'Salida: ${inicio == null
                ? 'Pendiente'
                : requiereRevision
                ? 'Requiere revisión'
                : 'Registrada'}',
          ),
          if (requiereRevision) ...[
            const SizedBox(height: 8),
            const Text(
              'Hay puntos con novedad. Coordina la revisión antes de salir a ruta.',
              style: TextStyle(color: Color(0xFF805100)),
            ),
          ],
          const SizedBox(height: 8),
          Text('Regreso: ${fin == null ? 'Pendiente' : 'Registrado'}'),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value:
                (inicio == null
                    ? 0
                    : fin == null
                    ? .5
                    : 1),
          ),
          const SizedBox(height: 10),
          Text(
            '$total puntos por inspección',
            style: const TextStyle(color: ConductorDesign.muted),
          ),
          const SizedBox(height: 12),
          if (inicio == null)
            _accion(
              'Iniciar checklist de salida',
              Icons.fact_check_outlined,
              () => _registrar('Inicio de jornada'),
            ),
          if (inicio != null && fin == null)
            _accion(
              'Finalizar jornada',
              Icons.flag_outlined,
              () => _registrar('Fin de jornada'),
            ),
          if (inicio != null)
            OutlinedButton.icon(
              onPressed: () => _seleccionar(6),
              icon: const Icon(Icons.history),
              label: const Text('Ver inspecciones guardadas'),
            ),
        ]),
      ),
    ];
  }

  List<Widget> _seguimientoVista() {
    final diarios =
        _historial.where((r) => r['tipo'] == 'Registro diario').toList();
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final registroHoy =
        diarios.where((r) => r['datos']?['fecha'] == hoy).firstOrNull;
    return [
      _encabezado('Seguimiento diario', 'Seguimiento diario', null),
      const SizedBox(height: 14),
      _responsivePair(
        _card('Estado y fotos del vehículo', [
          Text(
            '${_vehiculo!.placa} · ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
            style: const TextStyle(color: ConductorDesign.muted),
          ),
          const SizedBox(height: 12),
          const Text(
            'Frontal, lateral derecho, lateral izquierdo, trasera y tablero',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Registra el estado, toma fotos o selecciona archivos y súbelos a Google Drive.',
          ),
          const SizedBox(height: 12),
          if (!_admin && registroHoy?['evidencia_registrada'] == true)
            const ConductorBadge('Evidencia de hoy registrada'),
          if (_admin)
            ConductorGrid(
              children: [
                for (final lado in [
                  'frontal',
                  'lateral_derecho',
                  'lateral_izquierdo',
                  'trasera',
                  'tablero',
                  if (enlaceDriveValido(
                    registroHoy?['datos']?['foto_lateral']?.toString() ?? '',
                  ))
                    'lateral',
                ])
                  ConductorShortcut(
                    title:
                        lado == 'lateral'
                            ? 'Foto lateral (anterior)'
                            : 'Foto ${lado.replaceAll('_', ' ')}',
                    subtitle:
                        enlaceDriveValido(
                              registroHoy?['datos']?['foto_$lado']
                                      ?.toString() ??
                                  '',
                            )
                            ? 'Ver enlace en Drive'
                            : 'Sin enlace hoy',
                    icon:
                        enlaceDriveValido(
                              registroHoy?['datos']?['foto_$lado']
                                      ?.toString() ??
                                  '',
                            )
                            ? Icons.link
                            : Icons.camera_alt_outlined,
                    onTap: () {
                      final enlace =
                          registroHoy?['datos']?['foto_$lado']?.toString() ??
                          '';
                      if (_admin && enlaceDriveValido(enlace)) {
                        launchUrl(
                          Uri.parse(enlace),
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        _registrar('Registro diario');
                      }
                    },
                  ),
              ],
            ),
          const SizedBox(height: 12),
          _accion(
            'Nuevo seguimiento',
            Icons.camera_alt_outlined,
            () => _registrar('Registro diario'),
          ),
          const Text(
            'Las fotos se guardan en Drive; aquí se conserva el enlace.',
            style: TextStyle(color: ConductorDesign.cyan, fontSize: 12),
          ),
        ]),
        _card('Días anteriores', [
          if (!_admin)
            const Text(
              'Consulta las fechas y el cumplimiento de tus jornadas en Historial.',
            ),
          if (diarios.isEmpty) const Text('Sin registros diarios todavía.'),
          if (_admin)
            for (final r in diarios.take(8))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  r['datos']?['fecha']?.toString() ?? 'Fecha sin registrar',
                ),
                subtitle: Text('${r['km']} km'),
                trailing:
                    enlaceDriveValido(r['datos']?['enlace']?.toString() ?? '')
                        ? const Icon(Icons.link, color: ConductorDesign.cyan)
                        : null,
                onTap: () => _seleccionar(6),
              ),
        ]),
      ),
      _card('Actividades del recorrido', [
        for (final tipo in ['Tanqueo', 'Lavado', 'Novedad', 'Siniestro vial'])
          _tarea(
            tipo,
            'Registrar actividad y evidencia',
            Icons.add_circle_outline,
            () => _registrar(tipo),
          ),
      ]),
    ];
  }

  List<Widget> _vehiculoVista() => [
    _encabezado(
      'Mi vehículo',
      '${_vehiculo!.descripcion} · ${_vehiculo!.placa}',
      null,
    ),
    const SizedBox(height: 14),
    _vencimientos(completo: true),
    _card('Datos del vehículo', [
      Text(
        'Kilometraje actual: ${NumberFormat.decimalPattern().format(_vehiculo!.km)} km',
      ),
      const SizedBox(height: 6),
      Text(
        'Licencia de tránsito: ${_vehiculo!.datos['licencia_transito']?.toString() ?? 'Sin registrar'}',
      ),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: () => _seleccionar(6),
        icon: const Icon(Icons.history),
        label: const Text('Ver historial del vehículo'),
      ),
    ]),
  ];

  List<Widget> _documentosVista() => [
    const ConductorHeading(
      'Documentos y vencimientos',
      'Revisa las fechas antes de salir.',
    ),
    for (final doc in documentosConductor)
      _card(doc, [
        Align(
          alignment: Alignment.centerLeft,
          child: ConductorBadge(
            _estadoDocumento(doc),
            warning:
                _diasDocumento(doc) == null ||
                (_diasDocumento(doc) ?? 31) <= 30,
            error: (_diasDocumento(doc) ?? 1) < 0,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Vigencia hasta',
          style: TextStyle(color: ConductorDesign.muted, fontSize: 13),
        ),
        Text(
          _vehiculo!.datos[doc]?.toString() ?? 'Fecha pendiente de registrar',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ]),
    _card('Licencia de tránsito', [
      Text(
        _vehiculo!.datos['licencia_transito']?.toString() ??
            'Número sin registrar',
      ),
    ]),
    _accion(
      'Actualizar documentos',
      Icons.edit_outlined,
      () => _registrar('Documentos'),
    ),
  ];
  int? _diasDocumento(String doc) {
    final fecha = DateTime.tryParse(_vehiculo!.datos[doc]?.toString() ?? '');
    return fecha == null ? null : diasRestantes(fecha, DateTime.now());
  }

  String _estadoDocumento(String doc) {
    final dias = _diasDocumento(doc);
    if (dias == null) return 'Sin registrar';
    if (dias < 0) return 'Vencido';
    if (dias == 0) return 'Vence hoy';
    return dias <= 30 ? 'Vence en $dias días' : 'Vigente';
  }

  List<Widget> _mantenimientosVista() {
    final v = _vehiculo!;
    final proximo = int.tryParse(v.datos['proximo_aceite']?.toString() ?? '');
    final servicios =
        _historial
            .where((r) => r['tipo'].toString().startsWith('Mantenimiento'))
            .toList();
    return [
      _encabezado('Mantenimiento', 'Mantenimiento', null),
      const SizedBox(height: 14),
      _responsivePair(
        _card('Nuevo registro', [
          const Text(
            'Conserva el trabajo realizado, kilometraje, costo y enlace de la factura.',
          ),
          const SizedBox(height: 14),
          _accion(
            'Preventivo',
            Icons.build_outlined,
            () => _registrar('Mantenimiento preventivo'),
          ),
          _accion(
            'Correctivo',
            Icons.handyman_outlined,
            () => _registrar('Mantenimiento correctivo'),
          ),
          OutlinedButton.icon(
            onPressed: () => _registrar('Reposición de fluidos'),
            icon: const Icon(Icons.water_drop_outlined),
            label: const Text('Limpieza y niveles de fluidos'),
          ),
        ]),
        _card('Cambio de aceite', [
          Text(
            proximo == null ? 'Sin programar' : 'A los $proximo km',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (proximo != null)
            ConductorBadge(
              proximo <= v.km
                  ? 'Cambio pendiente'
                  : '${proximo - v.km} km restantes',
              warning: proximo - v.km <= 1000,
            ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value:
                proximo == null || proximo == 0
                    ? 0
                    : (v.km / proximo).clamp(0.0, 1.0),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => _registrar('Documentos'),
            child: const Text('Actualizar programación'),
          ),
        ]),
      ),
      if (_admin)
        _card('Historial de servicios', [
          if (servicios.isEmpty)
            const Text('Todavía no hay servicios registrados.'),
          for (final r in servicios)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.build_circle_outlined,
                color: ConductorDesign.cyan,
              ),
              title: Text(
                r['datos']?['servicio']?.toString() ?? r['tipo'].toString(),
              ),
              subtitle: Text('${r['datos']?['fecha'] ?? ''} · ${r['km']} km'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _seleccionar(6),
            ),
        ]),
    ];
  }

  List<Widget> _actividad() => [
    HistorialConductorView(
      key: ValueKey('historial-${_vehiculo!.id}-$_admin'),
      vehiculo: _vehiculo!,
      administrador: _admin,
    ),
  ];

  Future<void> _crear() async {
    final campos = <String, TextEditingController>{
      for (final key in [
        'Placa',
        'Descripción',
        'Kilometraje',
        'Número de usuario del conductor',
      ])
        key: TextEditingController(),
    };
    String? error;
    bool ocupado = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, actualizar) => AlertDialog(
                  title: const Text('Asignar vehículo'),
                  content: SizedBox(
                    width: 420,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Si la placa ya existe, se cambia su conductor conservando el historial.',
                          ),
                          for (final e in campos.entries)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: TextField(
                                controller: e.value,
                                decoration: InputDecoration(labelText: e.key),
                              ),
                            ),
                          if (error != null)
                            Text(
                              error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: ocupado ? null : () => Navigator.pop(ctx),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed:
                          ocupado
                              ? null
                              : () async {
                                final km = int.tryParse(
                                  campos['Kilometraje']!.text,
                                );
                                if (km == null ||
                                    km < 0 ||
                                    campos.values.any(
                                      (c) => c.text.trim().isEmpty,
                                    )) {
                                  actualizar(
                                    () =>
                                        error =
                                            'Completa todos los campos y un kilometraje válido.',
                                  );
                                  return;
                                }
                                actualizar(() {
                                  ocupado = true;
                                  error = null;
                                });
                                try {
                                  await ref
                                      .read(conductorRepositoryProvider)
                                      .crearVehiculo(
                                        campos['Placa']!.text
                                            .trim()
                                            .toUpperCase(),
                                        campos['Descripción']!.text.trim(),
                                        km,
                                        campos['Número de usuario del conductor']!
                                            .text
                                            .trim(),
                                      );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  await _cargar();
                                } catch (_) {
                                  actualizar(() {
                                    ocupado = false;
                                    error =
                                        'No se pudo asignar. Verifica el usuario conductor y los datos.';
                                  });
                                }
                              },
                      child: Text(ocupado ? 'Guardando…' : 'Asignar'),
                    ),
                  ],
                ),
          ),
    );
    // Los campos pertenecen al diálogo; esperar su animación de cierre.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final c in campos.values) {
      c.dispose();
    }
  }

  static const _titulos = [
    'Inicio',
    'Checklist',
    'Seguimiento',
    'Mantenimiento',
    'Mi vehículo',
    'Alertas',
    'Historial',
    'Perfil',
  ];
  static const _iconos = [
    Icons.dashboard_outlined,
    Icons.fact_check_outlined,
    Icons.camera_alt_outlined,
    Icons.build_outlined,
    Icons.local_shipping_outlined,
    Icons.notifications_none,
    Icons.history,
    Icons.person_outline,
  ];

  void _seleccionar(int indice) => setState(() {
    _tab = indice;
    _detalle = null;
  });

  void _mostrarMas() => showModalBottomSheet<void>(
    context: context,
    builder:
        (ctx) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (var i = 3; i < _titulos.length; i++)
                ListTile(
                  leading: Icon(_iconos[i]),
                  title: Text(_titulos[i]),
                  onTap: () {
                    Navigator.pop(ctx);
                    _seleccionar(i);
                  },
                ),
            ],
          ),
        ),
  );

  Widget _menu(bool desktop) => Container(
    key: desktop ? const ValueKey('conductor-sidebar') : null,
    width: desktop ? 184 : null,
    color: ConductorDesign.navy,
    padding: const EdgeInsets.all(10),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _titulos.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Material(
                color: i == _tab ? const Color(0xFF31596A) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    _seleccionar(i);
                    if (!desktop) Navigator.maybePop(context);
                  },
                  child: Container(
                    decoration:
                        i == _tab
                            ? const BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: ConductorDesign.lime,
                                  width: 3,
                                ),
                              ),
                            )
                            : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Icon(_iconos[i], color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _titulos[i],
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight:
                                  i == _tab ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (Navigator.canPop(context)) ...[
            const Divider(color: Color(0xFF597681)),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              minLeadingWidth: 18,
              horizontalTitleGap: 10,
              leading: const Icon(
                Icons.arrow_back,
                size: 18,
                color: Colors.white,
              ),
              title: const Text(
                'Volver al WMS',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ],
      ),
    ),
  );

  List<Widget> _perfilVista(dynamic usuario) => [
    _encabezado('Perfil', 'Mi perfil', null),
    _card(usuario?.nombre ?? 'Usuario de demostración', [
      Text(usuario?.etiquetas ?? 'Administrador · Demostración'),
      if (_vehiculo != null) ...[
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: ConductorBadge(_vehiculo!.placa),
        ),
      ],
      const SizedBox(height: 12),
      const Text(
        'Los avisos se actualizan al abrir o refrescar el portal. Los enlaces de Drive se agregan al registrar la evidencia.',
      ),
      if (ref.read(usarSupabaseProvider))
        TextButton(
          onPressed: () => ref.read(authRepositoryProvider)?.cerrarSesion(),
          child: const Text('Cerrar sesión'),
        ),
    ]),
    if (_admin)
      _card('Coordinación de flota', [
        if (_vehiculos.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: _vehiculo?.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Vehículo'),
            items:
                _vehiculos
                    .map(
                      (v) =>
                          DropdownMenuItem(value: v.id, child: Text(v.placa)),
                    )
                    .toList(),
            onChanged: (id) {
              _vehiculo = _vehiculos.firstWhere((v) => v.id == id);
              _cargar();
            },
          ),
        const SizedBox(height: 12),
        _accion('Asignar vehículo a conductor', Icons.add, _crear),
      ]),
  ];

  List<Widget> _pantalla(dynamic usuario) {
    if (_detalle == 'documentos') return _documentosVista();
    if (_detalle == 'mantenimiento') return _mantenimientosVista();
    if (_detalle == 'avisos') {
      return [
        _encabezado('Alertas', 'Alertas', null),
        _card('Avisos del vehículo', _avisos()),
      ];
    }
    if (_detalle == 'cuidados') {
      return [
        _encabezado('Seguimiento', 'Tanqueo y lavado', null),
        _card('Actividades', [
          for (final tipo in ['Tanqueo', 'Lavado', 'Reposición de fluidos'])
            _accion(
              tipo,
              Icons.local_gas_station_outlined,
              () => _registrar(tipo),
            ),
        ]),
      ];
    }
    if (_detalle == 'novedades') {
      return [
        _encabezado('Seguimiento', 'Novedades del recorrido', null),
        _card('Tipo de reporte', [
          for (final tipo in ['Novedad', 'Siniestro vial'])
            _accion(tipo, Icons.report_outlined, () => _registrar(tipo)),
        ]),
      ];
    }
    if (_vehiculo == null) {
      return [
        _card('Sin vehículo asignado', [
          const Text(
            'Solicita al administrador que asigne tu placa para iniciar.',
          ),
          if (_admin)
            TextButton(
              onPressed: _crear,
              child: const Text('Asignar vehículo'),
            ),
        ]),
      ];
    }
    return switch (_tab) {
      0 => _inicio(),
      1 => _checklistVista(),
      2 => _seguimientoVista(),
      3 => _mantenimientosVista(),
      4 => _vehiculoVista(),
      5 => [
        _encabezado('Alertas', 'Alertas', null),
        _card('Próximos vencimientos y tareas', _avisos()),
        _accion(
          'Actualizar fechas',
          Icons.event_outlined,
          () => _registrar('Documentos'),
        ),
      ],
      6 => _actividad(),
      _ => _perfilVista(usuario),
    };
  }

  Widget _contenido(dynamic usuario) =>
      _cargando
          ? const Center(child: WmsLoader())
          : RefreshIndicator(
            onRefresh: _cargar,
            child: ListView(
              key: ValueKey('conductor-$_tab${_detalle ?? ''}'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 420 ? 16 : 22,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!ref.read(usarSupabaseProvider))
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'DEMOSTRACIÓN LOCAL · Datos temporales',
                              style: TextStyle(
                                fontSize: 11,
                                color: ConductorDesign.muted,
                              ),
                            ),
                          ),
                        if (_error != null)
                          _card('No se pudo cargar', [
                            Text(_error!),
                            TextButton(
                              onPressed: _cargar,
                              child: const Text('Reintentar'),
                            ),
                          ]),
                        if (_detalle != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => setState(() => _detalle = null),
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Volver'),
                            ),
                          ),
                        ..._pantalla(usuario),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );

  @override
  Widget build(BuildContext context) {
    if (!conductorHabilitado()) {
      return const Scaffold(
        body: Center(child: Text('Disponible únicamente en pruebas.')),
      );
    }
    final usuario =
        ref.watch(usarSupabaseProvider)
            ? ref.watch(usuarioSesionProvider).value
            : null;
    if (ref.watch(usarSupabaseProvider) &&
        (usuario == null ||
            (!usuario.tieneRol(RolCuenta.admin) &&
                !usuario.tieneRol(RolCuenta.conductor)))) {
      return const Scaffold(
        body: Center(child: Text('Sin permiso para este módulo.')),
      );
    }
    return Theme(
      data: ConductorDesign.theme(),
      child: Builder(
        builder:
            (context) => LayoutBuilder(
              builder: (context, box) {
                final desktop = box.maxWidth >= 900;
                return Scaffold(
                  drawer:
                      desktop
                          ? null
                          : Drawer(child: SafeArea(child: _menu(false))),
                  appBar: AppBar(
                    automaticallyImplyLeading: !desktop,
                    toolbarHeight: 60,
                    titleSpacing: 12,
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: ConductorDesign.lime,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.local_shipping_outlined,
                            color: ConductorDesign.navy,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'ORBILOQ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Grupo Quiromar',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFC0D7E0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      IconButton(
                        tooltip: 'Alertas',
                        onPressed:
                            _vehiculo == null ? null : () => _seleccionar(5),
                        icon: const Icon(Icons.notifications_none),
                      ),
                      if (desktop)
                        Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: TextButton.icon(
                            onPressed: () => _seleccionar(7),
                            icon: const CircleAvatar(
                              radius: 15,
                              backgroundColor: ConductorDesign.lime,
                              child: Icon(
                                Icons.person_outline,
                                size: 17,
                                color: ConductorDesign.navy,
                              ),
                            ),
                            label: Text(
                              usuario?.nombre.split(' ').first ?? 'Conductor',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                  bottomNavigationBar:
                      desktop
                          ? null
                          : NavigationBar(
                            selectedIndex: _tab <= 2 ? _tab : 3,
                            onDestinationSelected:
                                (i) => i == 3 ? _mostrarMas() : _seleccionar(i),
                            destinations: const [
                              NavigationDestination(
                                icon: Icon(Icons.dashboard_outlined),
                                label: 'Inicio',
                              ),
                              NavigationDestination(
                                icon: Icon(Icons.fact_check_outlined),
                                label: 'Checklist',
                              ),
                              NavigationDestination(
                                icon: Icon(Icons.camera_alt_outlined),
                                label: 'Seguimiento',
                              ),
                              NavigationDestination(
                                icon: Icon(Icons.menu),
                                label: 'Más',
                              ),
                            ],
                          ),
                  body: SafeArea(
                    child:
                        desktop
                            ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _menu(true),
                                Expanded(child: _contenido(usuario)),
                              ],
                            )
                            : _contenido(usuario),
                  ),
                );
              },
            ),
      ),
    );
  }
}
