import 'transporte_app_bar.dart';
import 'menu_usuario_transporte.dart';
import '../../../shared/widgets/wms_alert.dart';
import 'perfil_transporte.dart';
import '../mantenimiento_preventivo.dart';
import 'dart:convert';
import '../notificaciones_guardadas_stub.dart'
    if (dart.library.js_interop) '../notificaciones_guardadas_web.dart'
    as notificaciones_guardadas;
import 'bandeja_notificaciones.dart';
import 'vista_evidencia_drive.dart';
import 'actividad_notificacion_page.dart';
import 'ficha_vehiculo_view.dart';
import 'flota_admin_page.dart';
import 'flota_design.dart';
import 'transporte_scaffold.dart';
import 'dart:async';
import 'revision_salida_page.dart';
import '../kit_semanal.dart';
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
  List<Map<String, dynamic>> _historial = [];
  VehiculoConductor? _vehiculo;
  Map<String, dynamic> _revision = {};
  Timer? _revisionTimer;
  bool _consultandoRevision = false;
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
    _revisionTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _actualizarRevision(),
    );
  }

  @override
  void dispose() {
    _revisionTimer?.cancel();
    super.dispose();
  }

  Future<void> _actualizarRevision() async {
    final id = _vehiculo?.id;
    if (id == null ||
        _consultandoRevision ||
        _cargando ||
        !mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _consultandoRevision = true;
    try {
      final datos = await ref
          .read(conductorRepositoryProvider)
          .revisionSalida(id);
      if (mounted && _vehiculo?.id == id) setState(() => _revision = datos);
    } catch (_) {
      if (mounted && _vehiculo?.id == id) {
        setState(
          () => _revision = {'estado': 'No se pudo verificar la autorización'},
        );
      }
    } finally {
      _consultandoRevision = false;
    }
  }

  Future<void> _abrirRevision() async {
    if (_vehiculo == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => RevisionSalidaPage(
              vehiculo: _vehiculo!.id,
              administrador: _admin,
            ),
      ),
    );
    if (mounted) await _cargar();
  }

  ButtonStyle get _botonInspeccion => OutlinedButton.styleFrom(
    minimumSize: const Size(0, 44),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );

  Widget _panelRevision() {
    final estado = _revision['estado']?.toString() ?? 'Pendiente de aprobación';
    final autorizado = estado == 'Autorizado';
    final rechazado = estado == 'No autorizado' || estado == 'Rechazado';
    final color =
        autorizado
            ? const Color(0xFF18754B)
            : rechazado
            ? const Color(0xFFB13D3D)
            : const Color(0xFF946000);
    final icono =
        autorizado
            ? Icons.verified_user_outlined
            : rechazado
            ? Icons.gpp_bad_outlined
            : Icons.pending_actions_outlined;
    final observacion = _revision['observacion']?.toString().trim() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ConductorDesign.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 4,
            color: autorizado ? ConductorDesign.lime : color,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, c) {
                final resumen = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icono, color: color, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Autorización de salida',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: ConductorDesign.muted,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            estado,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            autorizado
                                ? 'Tu salida a ruta está autorizada.'
                                : rechazado
                                ? 'Salida no autorizada. Consulta la indicación del administrador.'
                                : 'Espera la confirmación del administrador antes de salir a ruta.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: ConductorDesign.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final boton = OutlinedButton.icon(
                  style: _botonInspeccion,
                  onPressed: _abrirRevision,
                  icon: const Icon(
                    Icons.assignment_turned_in_outlined,
                    size: 20,
                  ),
                  label: Text(
                    _admin
                        ? 'Revisar checklists y actividades'
                        : 'Ver autorización y actividades',
                  ),
                );
                if (c.maxWidth >= 850 &&
                    MediaQuery.textScalerOf(context).scale(14) < 21) {
                  return Row(
                    children: [
                      Expanded(child: resumen),
                      const SizedBox(width: 24),
                      boton,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    resumen,
                    const SizedBox(height: 14),
                    Align(alignment: Alignment.centerLeft, child: boton),
                  ],
                );
              },
            ),
          ),
          if (observacion.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F8FA),
                border: Border(top: BorderSide(color: ConductorDesign.line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 18,
                    color: ConductorDesign.muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Observación del administrador',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: ConductorDesign.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          observacion,
                          style: const TextStyle(
                            fontSize: 13,
                            color: ConductorDesign.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _cargar() async {
    if (!conductorHabilitado() || (ref.read(usarSupabaseProvider) && _admin)) {
      return;
    }
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
      final revision =
          actual == null
              ? <String, dynamic>{}
              : await repo.revisionSalida(actual.id);
      if (!mounted) return;
      setState(() {
        _revision = revision;
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

  Future<void> _registrar(String tipo, {String? servicioPreventivo}) async {
    final v = _vehiculo;
    if (v == null) return;
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (_) => RegistroConductorPage(
              servicioPreventivo: servicioPreventivo,
              vehiculo: v,
              tipo: tipo,
            ),
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

  Future<void> _abrirActividad(Map tarea) async {
    final vehiculo = _vehiculo;
    final id = tarea['id']?.toString();
    if (vehiculo == null || id == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (_) =>
                ActividadNotificacionPage(vehiculo: vehiculo.id, actividad: id),
      ),
    );
    if (mounted) await _cargar();
  }

  String get _claveNotificaciones =>
      'orbiloq.notificaciones.${ref.read(conductorRepositoryProvider).client?.auth.currentUser?.id ?? 'demo'}.${_vehiculo?.id}';
  String? _claveLeidas;
  final Set<String> _notificacionesLeidas = {};
  void _leerNotificaciones() {
    if (_claveLeidas == _claveNotificaciones) return;
    _claveLeidas = _claveNotificaciones;
    _notificacionesLeidas.clear();
    try {
      _notificacionesLeidas.addAll(
        List<String>.from(
          jsonDecode(
            notificaciones_guardadas.leer(_claveNotificaciones) ?? '[]',
          ),
        ),
      );
    } catch (_) {}
  }

  List<AvisoTransporte> _notificaciones() {
    final v = _vehiculo;
    if (v == null) return [];
    final hoy = hoyColombia();
    return [
      for (final t in (_revision['tareas'] as List? ?? []))
        if (t['estado'] == 'Pendiente' || t['estado'] == 'Por verificar')
          AvisoTransporte(
            id:
                'actividad:${t['id']}:${t['estado']}:${t['fecha_limite']}:${plazoActividad(t, hoy)}',
            titulo:
                t['estado'] == 'Pendiente'
                    ? 'Tienes una actividad pendiente: ${t['descripcion']}'
                    : 'Tu actividad está por verificar: ${t['descripcion']}',
            detalle: plazoActividad(t, hoy),
            accion: 'Ver actividad',
            icono: Icons.assignment_outlined,
            abrir: () => _abrirActividad(t),
          ),
      if (_revision['estado'] == 'Autorizado' ||
          _revision['estado'] == 'No autorizado' ||
          _revision['estado'] == 'Rechazado')
        AvisoTransporte(
          id:
              'salida:${fechaKit(hoy)}:${_revision['estado']}:${_revision['observacion']}',
          titulo: 'Salida de hoy: ${_revision['estado']}',
          detalle:
              _revision['observacion']?.toString() ??
              'Consulta la decisión del administrador.',
          accion: 'Ver autorización',
          icono: Icons.verified_user_outlined,
          abrir: _abrirRevision,
        ),
      for (final doc in documentosConductor)
        if (_diasDocumento(doc) == null || _diasDocumento(doc)! <= 30)
          AvisoTransporte(
            id: 'documento:$doc:${v.datos[doc]}:${_diasDocumento(doc)}',
            titulo: doc,
            detalle:
                _diasDocumento(doc) == null
                    ? 'Falta registrar su fecha de vencimiento'
                    : _diasDocumento(doc)! < 0
                    ? 'Vencido hace ${-_diasDocumento(doc)!} días'
                    : _diasDocumento(doc) == 0
                    ? 'Vence hoy'
                    : _diasDocumento(doc) == 1
                    ? 'Vence mañana'
                    : 'Vence en ${_diasDocumento(doc)} días',
            accion: 'Actualizar documento',
            icono: Icons.description_outlined,
            abrir: () => _registrar('Documentos'),
          ),
      for (final c in controlesPreventivos(v.datos, v.km, hoy))
        if (c.alerta)
          AvisoTransporte(
            id: 'preventivo:${c.clave}',
            titulo: c.servicio.nombre,
            detalle: c.detalle,
            accion: 'Registrar mantenimiento',
            icono: Icons.build_outlined,
            abrir:
                () => _registrar(
                  'Mantenimiento preventivo',
                  servicioPreventivo: c.servicio.id,
                ),
          ),
      if ((v.datos['mantenimientos_preventivos'] as Map?)?['aceite'] == null &&
          (int.tryParse(v.datos['proximo_aceite']?.toString() ?? '') ??
                      v.km + 1001) -
                  v.km <=
              1000)
        AvisoTransporte(
          id: 'aceite:${v.datos['proximo_aceite']}',
          titulo: 'Programa el cambio de aceite',
          detalle: 'Revisa el mantenimiento por kilometraje.',
          accion: 'Registrar mantenimiento',
          icono: Icons.oil_barrel_outlined,
          abrir: () => _registrar('Mantenimiento preventivo'),
        ),
    ];
  }

  Future<void> _abrirNotificaciones() async {
    _leerNotificaciones();
    final avisos = _notificaciones();
    final seleccionado = await showDialog<AvisoTransporte>(
      context: context,
      builder: (ctx) {
        final movil = MediaQuery.sizeOf(ctx).width < 600;
        final contenido = BandejaNotificaciones(
          avisos: avisos,
          leidas: _notificacionesLeidas,
          alLeer: () {
            notificaciones_guardadas.guardar(
              _claveNotificaciones,
              jsonEncode(
                _notificacionesLeidas
                    .toList()
                    .reversed
                    .take(500)
                    .toList()
                    .reversed
                    .toList(),
              ),
            );
            if (mounted) setState(() {});
          },
        );
        return Theme(
          data: ConductorDesign.theme(),
          child:
              movil
                  ? Dialog.fullscreen(child: SafeArea(child: contenido))
                  : Dialog(
                    alignment: Alignment.topRight,
                    insetPadding: const EdgeInsets.only(
                      top: 72,
                      right: 20,
                      bottom: 20,
                      left: 20,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(width: 450, height: 620, child: contenido),
                  ),
        );
      },
    );
    if (mounted && seleccionado != null) seleccionado.abrir();
  }

  Widget _campanaNotificaciones() {
    _leerNotificaciones();
    final sinLeer =
        _notificaciones()
            .where((a) => !_notificacionesLeidas.contains(a.id))
            .length;
    return IconButton(
      tooltip: 'Notificaciones',
      onPressed: _vehiculo == null ? null : _abrirNotificaciones,
      icon: Badge(
        isLabelVisible: sinLeer > 0,
        label: Text(sinLeer > 99 ? '99+' : '$sinLeer'),
        child: const Icon(Icons.notifications_none),
      ),
    );
  }

  List<Widget> _avisos() {
    final v = _vehiculo!;
    final avisos = <Widget>[
      ListTile(
        leading: const Icon(Icons.verified_user_outlined),
        title: const Text('Autorización de salida'),
        subtitle: Text(
          _revision['estado']?.toString() ?? 'Pendiente de aprobación',
        ),
        onTap: _abrirRevision,
      ),
      for (final tarea in (_revision['tareas'] as List? ?? []))
        ListTile(
          leading: const Icon(
            Icons.assignment_late_outlined,
            color: Colors.orange,
          ),
          title: Text('Actividad: ${tarea['descripcion']}'),
          subtitle: Text(plazoActividad(tarea, hoyColombia())),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _abrirActividad(tarea),
        ),
    ];
    for (final doc in documentosConductor) {
      final fecha = DateTime.tryParse(v.datos[doc]?.toString() ?? '');
      if (fecha == null) {
        avisos.add(
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: Text(doc),
            subtitle: const Text('Fecha pendiente de registrar'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => _detalle = 'documentos'),
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
              onTap: () => setState(() => _detalle = 'documentos'),
              trailing: const Icon(Icons.chevron_right),
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
    for (final c in controlesPreventivos(v.datos, v.km, hoyColombia())) {
      if (c.alerta && c.servicio.id != 'aceite') {
        avisos.add(
          ListTile(
            leading: const Icon(Icons.build_outlined),
            title: Text(c.servicio.nombre),
            subtitle: Text(c.detalle),
            trailing: const Icon(Icons.chevron_right),
            onTap:
                () => _registrar(
                  'Mantenimiento preventivo',
                  servicioPreventivo: c.servicio.id,
                ),
          ),
        );
      }
    }
    final aceite = int.tryParse(v.datos['proximo_aceite']?.toString() ?? '');
    if (aceite != null && aceite - v.km <= 1000) {
      avisos.add(
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.oil_barrel_outlined),
          title: const Text('Cambio de aceite'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _seleccionar(3),
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
    final proximos =
        documentosConductor.where((doc) {
          final d = _diasDocumento(doc);
          return d == null || d <= 30;
        }).toList();
    return [
      _encabezado(
        'Inicio',
        'Tu jornada de hoy',
        DateFormat('dd / MM / yyyy').format(DateTime.now()),
      ),
      FlotaColumns(
        main: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 16, bottom: 18),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ConductorDesign.navy,
                borderRadius: BorderRadius.circular(16),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final informacion = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Expanded(
                            child: Text(
                              'TU VEHÍCULO ASIGNADO',
                              style: TextStyle(
                                color: Color(0xFFBFD0D8),
                                fontSize: 11,
                                letterSpacing: 1.3,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.local_shipping_outlined,
                            color: ConductorDesign.lime,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        v.placa,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        v.descripcion,
                        style: const TextStyle(color: Color(0xFFBFD0D8)),
                      ),
                      const Divider(height: 20, color: Color(0xFF315A6A)),
                      Wrap(
                        spacing: 48,
                        runSpacing: 12,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Kilometraje actual',
                                style: TextStyle(
                                  color: Color(0xFFBFD0D8),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${NumberFormat.decimalPattern().format(v.km)} km',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Inspección de hoy',
                                style: TextStyle(
                                  color: Color(0xFFBFD0D8),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                fin
                                    ? 'Jornada cerrada'
                                    : inicio
                                    ? 'Salida registrada'
                                    : 'Pendiente',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed:
                                inicio
                                    ? () => _seleccionar(1)
                                    : () => _registrar('Inicio de jornada'),
                            icon: const Icon(Icons.fact_check_outlined),
                            label: Text(
                              inicio
                                  ? 'Ver inspección de hoy'
                                  : 'Iniciar checklist de salida',
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              disabledForegroundColor: const Color(0xFF8CA8B5),
                              side: const BorderSide(color: Color(0xFF527483)),
                            ),
                            onPressed:
                                inicio && !fin
                                    ? () => _registrar('Fin de jornada')
                                    : null,
                            icon: const Icon(Icons.flag_outlined),
                            label: const Text('Finalizar jornada'),
                          ),
                        ],
                      ),
                    ],
                  );
                  final imagen = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: VistaEvidenciaDrive(
                          vehiculo: v.id,
                          enlace: v.datos['foto_frontal']?.toString() ?? '',
                          titulo: 'Foto de ${v.placa}',
                          height: 160,
                          soloImagen: true,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _registrar('Documentos'),
                        icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                        label: Text(
                          enlaceDriveValido(
                                v.datos['foto_frontal']?.toString() ?? '',
                              )
                              ? 'Cambiar foto'
                              : 'Agregar foto del vehículo',
                        ),
                      ),
                    ],
                  );
                  if (constraints.maxWidth >= 560 &&
                      MediaQuery.textScalerOf(context).scale(14) < 21) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(flex: 3, child: informacion),
                        const SizedBox(width: 28),
                        Expanded(flex: 2, child: imagen),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [imagen, const SizedBox(height: 16), informacion],
                  );
                },
              ),
            ),
            _panelRevision(),
            _card('Actividades pendientes', [
              if (_revision['version'] != 2)
                const Text(
                  'Las actividades están pendientes de activación. Contacta al administrador.',
                )
              else if ((_revision['tareas'] as List? ?? []).isEmpty)
                const Text('No tienes actividades pendientes.')
              else
                for (final t in (_revision['tareas'] as List))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.assignment_late_outlined),
                    title: Text(t['descripcion'].toString()),
                    subtitle: Text(plazoActividad(t, hoyColombia())),
                    onTap: () => _abrirActividad(t),
                  ),
            ]),
          ],
        ),
        aside: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            _card('Tu día de hoy', [
              _tarea(
                'Checklist de salida',
                inicio
                    ? (_revision['estado']?.toString() ??
                        'Pendiente de aprobación')
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
              if (proximos.isEmpty && foto)
                const Text('No hay avisos pendientes.'),
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
          ],
        ),
      ),
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
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _encabezado('Checklist', 'Inspección del vehículo', null),
              const Text(
                'Se completa al iniciar y al finalizar la jornada.',
                style: TextStyle(color: ConductorDesign.muted),
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConductorPanel(
                    title: 'Estado de hoy',
                    icon: Icons.fact_check_outlined,
                    children: [
                      Text(
                        '$total puntos por inspección · ${DateFormat('dd/MM/yyyy').format(hoyColombia())}',
                        style: const TextStyle(
                          color: ConductorDesign.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, c) {
                          Widget paso(
                            String titulo,
                            String estado,
                            IconData icono,
                            bool registrado,
                          ) => Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F7F8),
                              border: Border.all(color: ConductorDesign.line),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color:
                                        registrado
                                            ? const Color(0xFFE0F1E7)
                                            : const Color(0xFFE5EDF1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    icono,
                                    color: ConductorDesign.navy,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        titulo,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: ConductorDesign.muted,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        estado,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: ConductorDesign.navy,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (registrado)
                                  const Icon(
                                    Icons.check_circle_outline,
                                    color: Color(0xFF18754B),
                                    size: 20,
                                  ),
                              ],
                            ),
                          );
                          final salida = paso(
                            '01 · Inspección de salida',
                            inicio == null
                                ? 'Pendiente'
                                : requiereRevision
                                ? 'Registrada con novedades'
                                : 'Registrada',
                            Icons.login,
                            inicio != null,
                          );
                          final regreso = paso(
                            '02 · Inspección de regreso',
                            fin == null ? 'Pendiente' : 'Registrada',
                            Icons.flag_outlined,
                            fin != null,
                          );
                          if (c.maxWidth < 620)
                            return Column(
                              children: [
                                salida,
                                const SizedBox(height: 10),
                                regreso,
                              ],
                            );
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: salida),
                              const SizedBox(width: 12),
                              Expanded(child: regreso),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value:
                              inicio == null
                                  ? 0
                                  : fin == null
                                  ? .5
                                  : 1,
                          color: ConductorDesign.lime,
                          backgroundColor: ConductorDesign.line,
                        ),
                      ),
                      if (requiereRevision)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _revision['estado'] == 'Autorizado'
                                ? 'La inspección contiene novedades. Consulta las indicaciones del administrador en la autorización.'
                                : 'Hay puntos con novedad. Espera la autorización del administrador antes de salir a ruta.',
                            style: const TextStyle(
                              color: Color(0xFF805100),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          if (inicio == null)
                            FilledButton.icon(
                              style: _botonInspeccion.copyWith(
                                backgroundColor: const WidgetStatePropertyAll(
                                  ConductorDesign.lime,
                                ),
                                foregroundColor: const WidgetStatePropertyAll(
                                  ConductorDesign.navy,
                                ),
                              ),
                              onPressed: () => _registrar('Inicio de jornada'),
                              icon: const Icon(Icons.fact_check_outlined),
                              label: const Text('Iniciar checklist de salida'),
                            ),
                          if (inicio != null && fin == null)
                            FilledButton.icon(
                              style: _botonInspeccion.copyWith(
                                backgroundColor: const WidgetStatePropertyAll(
                                  ConductorDesign.lime,
                                ),
                                foregroundColor: const WidgetStatePropertyAll(
                                  ConductorDesign.navy,
                                ),
                              ),
                              onPressed: () => _registrar('Fin de jornada'),
                              icon: const Icon(Icons.flag_outlined),
                              label: const Text('Finalizar jornada'),
                            ),
                          if (inicio != null)
                            OutlinedButton.icon(
                              style: _botonInspeccion,
                              onPressed: () => _seleccionar(6),
                              icon: const Icon(Icons.history),
                              label: const Text('Ver inspecciones guardadas'),
                            ),
                        ],
                      ),
                    ],
                  ),
                  _panelRevision(),
                ],
              ),
            ],
          ),
        ),
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
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _encabezado('Seguimiento diario', 'Seguimiento diario', null),
              const SizedBox(height: 6),
              const Text(
                'Documenta el estado de tu vehículo y consulta tus registros.',
                style: TextStyle(color: ConductorDesign.muted),
              ),
              const SizedBox(height: 18),
              ConductorPanel(
                title: 'Estado y fotos del vehículo',
                icon: Icons.camera_alt_outlined,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ConductorBadge(_vehiculo!.placa),
                      ConductorBadge(
                        DateFormat('dd/MM/yyyy').format(DateTime.now()),
                      ),
                      if (!_admin &&
                          registroHoy?['evidencia_registrada'] == true)
                        const ConductorBadge('Evidencia de hoy registrada'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Fotografías del seguimiento',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Toma una foto o adjunta un archivo de cada vista.',
                    style: TextStyle(color: ConductorDesign.muted),
                  ),
                  const SizedBox(height: 12),
                  if (!_admin)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns =
                            constraints.maxWidth >= 700
                                ? 5
                                : constraints.maxWidth >= 420
                                ? 3
                                : 2;
                        const vistas = [
                          'Frontal',
                          'Lateral derecho',
                          'Lateral izquierdo',
                          'Trasera',
                          'Tablero',
                        ];
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (var i = 0; i < vistas.length; i++)
                              Container(
                                width:
                                    (constraints.maxWidth -
                                        (columns - 1) * 10) /
                                    columns,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: ConductorDesign.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: ConductorDesign.line,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          i == 4
                                              ? Icons.speed_outlined
                                              : Icons.directions_car_outlined,
                                          color: ConductorDesign.navy,
                                          size: 22,
                                        ),
                                        const Spacer(),
                                        Text(
                                          '0${i + 1}',
                                          style: const TextStyle(
                                            color: ConductorDesign.muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      vistas[i],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
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
                            registroHoy?['datos']?['foto_lateral']
                                    ?.toString() ??
                                '',
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
                                  registroHoy?['datos']?['foto_$lado']
                                      ?.toString() ??
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

                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      style: _botonInspeccion.copyWith(
                        backgroundColor: const WidgetStatePropertyAll(
                          ConductorDesign.lime,
                        ),
                        foregroundColor: const WidgetStatePropertyAll(
                          ConductorDesign.navy,
                        ),
                      ),
                      onPressed: () => _registrar('Registro diario'),
                      icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                      label: const Text('Nuevo seguimiento'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ConductorPanel(
                title: 'Días anteriores',
                icon: Icons.history_outlined,
                children: [
                  Text(
                    diarios.isEmpty
                        ? 'Tus registros aparecerán aquí cuando completes el primer seguimiento.'
                        : 'Consulta las fechas y el cumplimiento de tus jornadas en el historial.',
                    style: const TextStyle(color: ConductorDesign.muted),
                  ),
                  if (_admin)
                    for (final r in diarios.take(8))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          r['datos']?['fecha']?.toString() ??
                              'Fecha sin registrar',
                        ),
                        subtitle: Text('${r['km']} km'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _seleccionar(6),
                      ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      style: _botonInspeccion,
                      onPressed: () => _seleccionar(6),
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text('Ver historial'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _vehiculoVista() => [
    const ConductorHeading(
      'Mi vehículo',
      'Ficha técnica, conductor y documentos de tu vehículo asignado.',
    ),
    FichaVehiculoView(
      key: ValueKey('ficha-${_vehiculo!.id}'),
      vehiculo: _vehiculo!,
      conductor:
          ref.read(usuarioSesionProvider).value?.nombre ??
          _vehiculo!.datos['conductor_nombre']?.toString() ??
          'Sin registrar',
      onEditar: () => _registrar('Documentos'),
      onHistorial: () => _seleccionar(6),
    ),
  ];

  List<Widget> _documentosVista() => [
    const ConductorHeading(
      'Documentos y vencimientos',
      'Revisa las fechas antes de salir.',
    ),
    FlotaGrid(
      columns: 2,
      children: [
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
              _vehiculo!.datos[doc]?.toString() ??
                  'Fecha pendiente de registrar',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ]),
      ],
    ),
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
      _card('Programación preventiva', [
        const Text(
          'Cada servicio se calcula desde su última finalización. Avisamos el día anterior y mientras esté vencido; para aceite, desde 1.000 km antes.',
        ),
        for (final c in controlesPreventivos(v.datos, v.km, hoyColombia()))
          ListTile(
            title: Text(c.servicio.nombre),
            subtitle: Text(c.detalle),
            leading: Icon(
              c.alerta ? Icons.warning_amber : Icons.build_outlined,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap:
                () => _registrar(
                  'Mantenimiento preventivo',
                  servicioPreventivo: c.servicio.id,
                ),
          ),
      ]),
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
              subtitle: Text(
                '${r['datos']?['fecha'] ?? ''} · ${r['km']} km\n${r['datos']?['origen_mantenimiento'] ?? 'Origen no disponible'}',
              ),
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
                          if (error != null) AvisoFormulario(error!),
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

  List<Widget> _perfilVista(dynamic usuario) => [
    PerfilTransporte(vehiculo: _vehiculo),
  ];

  List<Widget> _pantalla(dynamic usuario) {
    if (_tab == 7) return _perfilVista(usuario);
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
          ? const WmsLoadingPanel(
            label: 'Cargando tu vehículo y el estado de la jornada…',
          )
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
                            AvisoFormulario(_error!),
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
    if (usuario?.tieneRol(RolCuenta.admin) == true) {
      return const FlotaAdminPage();
    }
    return Theme(
      data: ConductorDesign.theme(),
      child: TransporteScaffold(
        sidebarKey: const ValueKey('conductor-sidebar'),
        integratedNavigation: true,
        usuario: usuario?.nombre ?? 'Conductor',
        destinos: [
          for (var i = 0; i < _titulos.length; i++)
            TransporteDestino(_titulos[i], _iconos[i]),
        ],
        selected: _tab,
        onSelected: _seleccionar,
        appBar: TransporteAppBar(
          actions: [
            _campanaNotificaciones(),
            MenuUsuarioTransporte(
              oscuro: true,
              onPerfil: () => _seleccionar(7),
            ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _cargando ? null : _cargar,
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
          ],
        ),
        mobileNavigation: NavigationBar(
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
            NavigationDestination(icon: Icon(Icons.menu), label: 'Más'),
          ],
        ),
        body: SafeArea(child: _contenido(usuario)),
      ),
    );
  }
}
