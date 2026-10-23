import 'transporte_app_bar.dart';
import 'menu_usuario_transporte.dart';
import '../../../shared/widgets/wms_alert.dart';
import 'perfil_transporte.dart';
import 'kit_semanal_page.dart';
import 'vista_evidencia_drive.dart';
import 'dart:convert';
import '../mantenimiento_preventivo.dart';
import '../notificaciones_guardadas_stub.dart'
    if (dart.library.js_interop) '../notificaciones_guardadas_web.dart'
    as notificaciones_guardadas;
import 'bandeja_notificaciones.dart';
import 'transporte_scaffold.dart';
import 'package:intl/intl.dart';
import 'flota_design.dart';
import '../../../shared/widgets/wms_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../conductor_repository.dart';
import '../conductor_model.dart';
import '../kit_semanal.dart';
import 'conductor_design.dart';
import 'revision_salida_page.dart';
import 'registro_conductor.dart';
import 'historial_conductor_view.dart';

class FlotaAdminPage extends ConsumerStatefulWidget {
  const FlotaAdminPage({super.key});
  @override
  ConsumerState<FlotaAdminPage> createState() => _FlotaAdminPageState();
}

class _FlotaAdminPageState extends ConsumerState<FlotaAdminPage> {
  List<Map<String, dynamic>> _flota = [];
  String? _id, _error;
  String _buscar = '', _filtro = 'Todos';
  bool _cargando = true;
  bool _soloSinLeer = false;
  final Set<String> _avisosLeidos = {};
  String get _claveAvisos =>
      'orbiloq.notificaciones.admin.${ref.read(conductorRepositoryProvider).client?.auth.currentUser?.id ?? 'demo'}';
  void _guardarLeidos() => notificaciones_guardadas.guardar(
    _claveAvisos,
    jsonEncode(_avisosLeidos.toList().reversed.take(500).toList()),
  );

  int _tab = 0, _nav = 0;
  Map<String, dynamic>? get _actual =>
      _flota.where((v) => v['id'] == _id).firstOrNull;
  @override
  void initState() {
    super.initState();
    try {
      final guardadas = notificaciones_guardadas.leer(_claveAvisos);
      if (guardadas != null) {
        _avisosLeidos.addAll(
          (jsonDecode(guardadas) as List).whereType<String>(),
        );
      }
    } catch (_) {}
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final data = await ref.read(conductorRepositoryProvider).flotaResumen();
      if (mounted) setState(() => _flota = data);
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error =
                  e is PostgrestException && e.code == 'PGRST202'
                      ? 'Falta activar el panel de flota en pruebas (migración 123).'
                      : 'No se pudo consultar la flota. Reintenta la carga.',
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  int _numero(Map v, String key) => (v[key] as num? ?? 0).toInt();
  int _avisos(Map v) {
    final datos = v['datos'] as Map? ?? {};
    return documentosConductor.where((d) {
      final f = DateTime.tryParse(datos[d]?.toString() ?? '');
      return f == null || diasRestantes(f, hoyColombia()) <= 30;
    }).length;
  }

  bool _cumple(Map v) => switch (_filtro) {
    'Por autorizar' => v['autorizacion'] == 'Pendiente de aprobación',
    'Pendientes' => _numero(v, 'pendientes') > 0,
    'Por verificar' => _numero(v, 'por_verificar') > 0,
    'Vencidas' => _numero(v, 'vencidas') > 0,
    'Documentos' => _avisos(v) > 0,
    _ => true,
  };
  Future<void> _revision(Map v) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => RevisionSalidaPage(
              vehiculo: v['id'],
              administrador: true,
              contextoVehiculo: Map<String, dynamic>.from(v),
            ),
      ),
    );
    if (mounted) await _cargar();
  }

  Future<void> _registrar(String tipo) async {
    final v = _actual;
    if (v == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => RegistroConductorPage(
              vehiculo: VehiculoConductor.fromJson(v),
              tipo: tipo,
            ),
      ),
    );
    if (mounted) await _cargar();
  }

  Future<void> _asignar([Map? v]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _AsignacionDialog(vehiculo: v),
    );
    if (result == true && mounted) await _cargar();
  }

  Widget _boton(
    String label,
    VoidCallback action, {
    IconData icon = Icons.arrow_forward,
  }) => OutlinedButton.icon(
    onPressed: action,
    icon: Icon(icon),
    label: Text(label),
  );
  static const _destinos = [
    TransporteDestino('Resumen', Icons.dashboard_outlined),
    TransporteDestino('Vehículos', Icons.local_shipping_outlined),
    TransporteDestino('Actividades', Icons.assignment_outlined),
    TransporteDestino('Mantenimiento', Icons.build_outlined),
    TransporteDestino('Documentos', Icons.description_outlined),
    TransporteDestino('Historial y reportes', Icons.history),
    TransporteDestino('Notificaciones', Icons.notifications_none),
  ];
  void _navegar(int index) => setState(() {
    _nav = index;
    _id = null;
    _buscar = '';
    _filtro = index == 2 ? 'Pendientes' : 'Todos';
  });
  void _abrirVehiculo(Map v, [int tab = 0]) => setState(() {
    _id = v['id'];
    _tab = tab;
  });
  Widget _vehiculoCard(Map<String, dynamic> v) => ConductorPanel(
    title: '${v['placa']}',
    icon: Icons.local_shipping_outlined,
    children: [
      Text(
        '${v['descripcion']}',
        style: const TextStyle(color: ConductorDesign.muted, fontSize: 12),
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: ConductorBadge('${v['autorizacion']}'),
      ),
      const SizedBox(height: 14),
      const Divider(height: 1),
      const SizedBox(height: 14),
      Row(
        children: [
          const CircleAvatar(
            radius: 17,
            backgroundColor: Color(0xFFE8EDC8),
            child: Icon(
              Icons.person_outline,
              color: ConductorDesign.navy,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${v['conductor_nombre']}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          Text(
            '${NumberFormat.decimalPattern('es_CO').format(v['km'] ?? 0)} km',
            style: const TextStyle(color: ConductorDesign.muted, fontSize: 12),
          ),
          Text(
            '${_numero(v, 'pendientes')} pendientes · ${_numero(v, 'por_verificar')} por verificar',
            style: const TextStyle(color: ConductorDesign.muted, fontSize: 12),
          ),
        ],
      ),
      if (_numero(v, 'vencidas') > 0)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ConductorBadge(
            '${v['vencidas']} actividades vencidas',
            error: true,
          ),
        ),
      const SizedBox(height: 14),
      _boton(
        _nav == 3
            ? 'Ver mantenimiento'
            : _nav == 4
            ? 'Ver documentos'
            : _nav == 5
            ? 'Ver historial'
            : 'Ver vehículo',
        () => _abrirVehiculo(
          v,
          _nav == 3
              ? 3
              : _nav == 4
              ? 4
              : _nav == 5
              ? 5
              : 0,
        ),
      ),
      if (_nav == 2)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FilledButton.icon(
            onPressed: () => _revision(v),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Revisar pendientes'),
          ),
        ),
    ],
  );

  List<Widget> _resumen() {
    final pendientes =
        _flota
            .where((v) => v['autorizacion'] == 'Pendiente de aprobación')
            .toList();
    final verificar =
        _flota.where((v) => _numero(v, 'por_verificar') > 0).toList();
    final docs = _flota.where((v) => _avisos(v) > 0).toList();
    return [
      const ConductorHeading(
        'Gestión de flota',
        'Una flota, todo bajo control. Prioriza lo que necesita tu atención.',
      ),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _boton(
            'Registrar vehículo / asignar conductor',
            () => _asignar(),
            icon: Icons.add,
          ),
        ],
      ),
      const SizedBox(height: 22),
      FlotaGrid(
        children: [
          FlotaMetric(
            'Vehículos activos',
            '${_flota.length}',
            detail: 'Registrados en la flota',
            icon: Icons.local_shipping_outlined,
            compact: true,
          ),
          FlotaMetric(
            'Por autorizar',
            '${pendientes.length}',
            detail: 'Requieren decisión de salida',
            icon: Icons.verified_user_outlined,
            compact: true,
          ),
          FlotaMetric(
            'Actividades pendientes',
            '${_flota.fold(0, (n, v) => n + _numero(v, 'pendientes'))}',
            detail:
                '${_flota.fold(0, (n, v) => n + _numero(v, 'por_verificar'))} por verificar',
            icon: Icons.assignment_outlined,
            compact: true,
          ),
          FlotaMetric(
            'Avisos documentales',
            '${docs.length}',
            detail: 'Vehículos con fechas pendientes o próximas',
            icon: Icons.event_outlined,
            compact: true,
          ),
        ],
      ),
      const SizedBox(height: 22),
      FlotaColumns(
        main: ConductorPanel(
          title: 'Necesita tu atención',
          children: [
            if (pendientes.isEmpty && verificar.isEmpty && docs.isEmpty)
              const TransporteAviso(
                'Todo al día',
                'No hay revisiones ni avisos documentales pendientes.',
              ),
            for (final v in pendientes.take(3))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.verified_user_outlined,
                  color: Color(0xFFA16416),
                ),
                title: Text('${v['placa']} · Revisión de salida'),
                subtitle: Text('${v['conductor_nombre']}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _revision(v),
              ),
            for (final v in verificar.take(3))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.fact_check_outlined,
                  color: ConductorDesign.cyan,
                ),
                title: Text(
                  '${v['placa']} · ${v['por_verificar']} actividades por verificar',
                ),
                subtitle: const Text(
                  'Revisa la evidencia enviada por el conductor',
                ),
                onTap: () => _revision(v),
              ),
            for (final v in docs.take(3))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: Text('${v['placa']} · Documentos'),
                subtitle: Text(
                  '${_avisos(v)} fechas pendientes, vencidas o próximas',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _abrirVehiculo(v, 4),
              ),
          ],
        ),
        aside: ConductorPanel(
          title: 'Hoy en transporte',
          children: [
            Text(
              DateFormat('dd / MM / yyyy').format(hoyColombia()),
              style: const TextStyle(color: ConductorDesign.muted),
            ),
            const SizedBox(height: 16),
            _resumenLinea(
              'Inicio registrado',
              _flota.where((v) => v['inicio'] == true).length,
              Icons.login,
            ),
            _resumenLinea(
              'Salidas autorizadas',
              _flota.where((v) => v['autorizacion'] == 'Autorizado').length,
              Icons.verified_user_outlined,
            ),
            _resumenLinea(
              'Jornadas cerradas',
              _flota.where((v) => v['fin'] == true).length,
              Icons.logout,
            ),
            const SizedBox(height: 12),
            _boton('Ver toda la flota', () => _navegar(1)),
          ],
        ),
      ),
      const SizedBox(height: 8),
      const ConductorHeading(
        'Estado de la flota',
        'Accede al expediente para revisar inspecciones, documentos e historial.',
      ),
      FlotaGrid(
        columns: 3,
        children: [for (final v in _flota) _vehiculoCard(v)],
      ),
      if (_flota.isEmpty)
        const TransporteAviso(
          'Sin vehículos registrados',
          'Registra un vehículo y asigna un conductor para comenzar.',
        ),
    ];
  }

  Widget _resumenLinea(String label, int count, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Icon(icon, size: 20, color: ConductorDesign.muted),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Text('$count', style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );

  List<Widget> _vehiculosGestion({
    required bool documentos,
    bool historial = false,
  }) => [
    ConductorHeading(
      historial
          ? 'Historial y reportes'
          : documentos
          ? 'Documentos'
          : 'Mantenimiento',
      historial
          ? 'Selecciona un vehículo para consultar su historial y exportar sus registros.'
          : documentos
          ? 'Selecciona un vehículo para consultar y actualizar su documentación.'
          : 'Selecciona un vehículo para consultar y registrar sus mantenimientos.',
    ),
    if (_flota.isEmpty)
      TransporteAviso(
        'Sin vehículos registrados',
        historial
            ? 'Los vehículos registrados aparecerán aquí para consultar su historial.'
            : documentos
            ? 'Los vehículos registrados aparecerán aquí para gestionar sus documentos.'
            : 'Los vehículos registrados aparecerán aquí para gestionar sus mantenimientos.',
      ),
    FlotaGrid(
      columns: 3,
      children: [
        for (final v in _flota)
          Semantics(
            button: true,
            label:
                'Gestionar ${historial
                    ? 'historial'
                    : documentos
                    ? 'documentos'
                    : 'mantenimiento'} de ${v['placa']}',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey(
                  '${historial
                      ? 'historial'
                      : documentos
                      ? 'documentos'
                      : 'mantenimiento'}-vehiculo-${v['id']}',
                ),
                borderRadius: BorderRadius.circular(16),
                onTap:
                    () => _abrirVehiculo(
                      v,
                      historial
                          ? 5
                          : documentos
                          ? 4
                          : 3,
                    ),
                child: ConductorPanel(
                  title: '${v['placa']}',
                  icon: Icons.local_shipping_outlined,
                  children: [
                    Text(
                      '${v['descripcion']}',
                      style: const TextStyle(color: ConductorDesign.muted),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Conductor: ${v['conductor_nombre'] ?? 'Sin asignar'}',
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Icon(
                          historial
                              ? Icons.history
                              : documentos
                              ? Icons.folder_open_outlined
                              : Icons.build_outlined,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            historial
                                ? 'Ver historial y reportes'
                                : documentos
                                ? 'Gestionar documentos'
                                : 'Gestionar mantenimiento',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  ];

  Map<String, dynamic> _kitVehiculo(Map<String, dynamic> v) =>
      Map<String, dynamic>.from(
        (v['datos'] as Map?)?['kit_semanal'] as Map? ?? {},
      );

  Future<void> _revisarKit(Map<String, dynamic> v) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => KitSemanalPage(vehiculo: VehiculoConductor.fromJson(v)),
      ),
    );
    if (guardado == true && mounted) await _cargar();
  }

  Widget _panelKit(Map<String, dynamic> v) {
    final kit = _kitVehiculo(v);
    final completa = kitSemanaCompleta(kit, hoyColombia());
    return FlotaPanel(
      title: 'Kit de carretera · revisión semanal',
      children: [
        ConductorBadge(
          completa
              ? 'Revisión de esta semana registrada'
              : 'Pendiente de revisión',
          warning: !completa,
        ),
        const SizedBox(height: 12),
        Text(
          '${v['placa']} · ${catalogoKit.length} puntos, incluido el kit antiderrames',
        ),
        Text('Última revisión: ${kit['fecha'] ?? 'Sin registrar'}'),
        for (final aviso in avisosKit(
          kit,
          hoyColombia(),
        ).where((a) => !a.startsWith('Revisión semanal pendiente')))
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(aviso)),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _revisarKit(v),
            icon: const Icon(Icons.medical_services_outlined),
            label: const Text('Revisar kit de carretera'),
          ),
        ),
      ],
    );
  }

  List<AvisoTransporte> _avisosAdministrativos() {
    final hoy = hoyColombia();
    return [
      for (final v in _flota) ...[
        for (final aviso in avisosKit(_kitVehiculo(v), hoy))
          AvisoTransporte(
            id: 'kit:${v['id']}:${fechaKit(lunesKit(hoy))}:$aviso',
            titulo: '${v['placa']} · Kit de carretera',
            detalle: aviso,
            accion: 'Realizar revisión semanal',
            icono: Icons.medical_services_outlined,
            abrir: () => _revisarKit(v),
          ),
        if (v['autorizacion'] == 'Pendiente de aprobación')
          AvisoTransporte(
            id: 'salida:${v['id']}:${fechaKit(hoy)}',
            titulo: '${v['placa']} · Salida pendiente de aprobación',
            detalle:
                '${v['conductor_nombre']} espera la revisión del checklist.',
            accion: 'Revisar y autorizar salida',
            icono: Icons.verified_user_outlined,
            abrir: () => _revision(v),
          ),
        for (final estado in ['por_verificar', 'pendientes'])
          if (_numero(v, estado) > 0)
            AvisoTransporte(
              id:
                  'actividad:${v['id']}:$estado:${_numero(v, estado)}:${v['vencidas']}:${fechaKit(hoy)}',
              titulo:
                  '${v['placa']} · ${_numero(v, estado)} actividades ${estado == 'por_verificar' ? 'por verificar' : 'pendientes'}',
              detalle:
                  estado == 'por_verificar'
                      ? 'El conductor envió evidencia. Revisa y confirma la solución.'
                      : '${_numero(v, 'vencidas')} vencidas · Conductor: ${v['conductor_nombre']}',
              accion:
                  estado == 'por_verificar'
                      ? 'Verificar actividades'
                      : 'Revisar actividades',
              icono: Icons.assignment_outlined,
              abrir: () => _revision(v),
            ),
        for (final d in documentosConductor)
          if (_diasDocumento(v, d) == null || _diasDocumento(v, d)! <= 30)
            AvisoTransporte(
              id:
                  'documento:${v['id']}:$d:${(v['datos'] as Map?)?[d]}:${_diasDocumento(v, d)}',
              titulo: '${v['placa']} · $d',
              detalle: _estadoDocumento(v, d),
              accion: 'Gestionar documentación',
              icono: Icons.description_outlined,
              abrir: () => _abrirVehiculo(v, 4),
            ),
        for (final c in controlesPreventivos(
          Map<String, dynamic>.from(v['datos'] as Map? ?? {}),
          (v['km'] as num? ?? 0).toInt(),
          hoy,
        ))
          if (c.alerta)
            AvisoTransporte(
              id: 'preventivo:${v['id']}:${c.clave}',
              titulo: '${v['placa']} · ${c.servicio.nombre}',
              detalle: c.detalle,
              accion: 'Gestionar mantenimiento',
              icono: Icons.build_outlined,
              abrir: () => _abrirVehiculo(v, 3),
            ),
      ],
    ];
  }

  List<Widget> _notificacionesVista() {
    final avisos = _avisosAdministrativos();
    final visibles =
        avisos
            .where((a) => !_soloSinLeer || !_avisosLeidos.contains(a.id))
            .toList();
    return [
      const ConductorHeading(
        'Notificaciones',
        'Avisos de la flota. Selecciona uno para atenderlo.',
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ChoiceChip(
            label: const Text('Todas'),
            selected: !_soloSinLeer,
            onSelected: (_) => setState(() => _soloSinLeer = false),
          ),
          ChoiceChip(
            label: const Text('Sin leer'),
            selected: _soloSinLeer,
            onSelected: (_) => setState(() => _soloSinLeer = true),
          ),
          Text(
            '${avisos.where((a) => !_avisosLeidos.contains(a.id)).length} sin leer',
          ),
          TextButton(
            onPressed:
                avisos.isEmpty
                    ? null
                    : () => setState(() {
                      _avisosLeidos.addAll(avisos.map((a) => a.id));
                      _guardarLeidos();
                    }),
            child: const Text('Marcar todas como leídas'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (visibles.isEmpty)
        const TransporteAviso(
          'Sin notificaciones',
          'No hay avisos para mostrar en este filtro.',
        ),
      for (final a in visibles)
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Material(
            color:
                _avisosLeidos.contains(a.id)
                    ? Colors.white
                    : const Color(0xFFEAF4FA),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: ValueKey('aviso-admin-${a.id}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _avisosLeidos.add(a.id);
                  _guardarLeidos();
                });
                a.abrir();
              },
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFE8EDC8),
                      child: Icon(a.icono, color: ConductorDesign.navy),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.titulo,
                            style: TextStyle(
                              fontWeight:
                                  _avisosLeidos.contains(a.id)
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            a.detalle,
                            style: const TextStyle(
                              color: ConductorDesign.muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            a.accion,
                            style: const TextStyle(
                              color: ConductorDesign.navy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_avisosLeidos.contains(a.id))
                      const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.circle,
                          size: 9,
                          color: ConductorDesign.cyan,
                        ),
                      ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _catalogoVehiculos() {
    final filas =
        _flota
            .where(
              (v) =>
                  '${v['placa']} ${v['descripcion']} ${v['conductor_nombre']}'
                      .toLowerCase()
                      .contains(_buscar.trim().toLowerCase()),
            )
            .toList();
    return [
      const ConductorHeading(
        'Vehículos',
        'Consulta la ficha de cada vehículo y administra su asignación.',
      ),
      TransporteCampos(
        children: [
          TextField(
            key: const ValueKey('buscar-catalogo-vehiculos'),
            decoration: const InputDecoration(
              hintText: 'Buscar placa, vehículo o conductor',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (valor) => setState(() => _buscar = valor),
          ),
          FilledButton.icon(
            onPressed: () => _asignar(),
            icon: const Icon(Icons.add),
            label: const Text('Registrar vehículo / asignar conductor'),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Text(
        '${filas.length} de ${_flota.length} vehículos',
        style: const TextStyle(color: ConductorDesign.muted),
      ),
      const SizedBox(height: 14),
      if (filas.isEmpty)
        const TransporteAviso(
          'Sin vehículos para mostrar',
          'Revisa la búsqueda o registra un vehículo.',
        ),
      FlotaGrid(
        columns: 3,
        children: [
          for (final v in filas)
            Container(
              key: ValueKey('catalogo-vehiculo-${v['id']}'),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ConductorDesign.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if ('${(v['datos'] as Map?)?['foto_frontal'] ?? ''}'
                      .isNotEmpty)
                    VistaEvidenciaDrive(
                      key: ValueKey('foto-catalogo-${v['id']}'),
                      vehiculo: '${v['id']}',
                      enlace: '${v['datos']['foto_frontal']}',
                      titulo: 'Foto del vehículo',
                      height: 150,
                      soloImagen: true,
                    )
                  else
                    Container(
                      height: 150,
                      color: const Color(0xFFEAF1F4),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            size: 48,
                            color: ConductorDesign.muted,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Sin foto registrada',
                            style: TextStyle(color: ConductorDesign.muted),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${v['placa']}',
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                            color: ConductorDesign.navy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${v['descripcion']}',
                          style: const TextStyle(color: ConductorDesign.muted),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 20,
                              color: ConductorDesign.muted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${v['conductor_nombre'] ?? 'Sin conductor asignado'}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.speed,
                              size: 20,
                              color: ConductorDesign.muted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${NumberFormat.decimalPattern('es_CO').format(v['km'] ?? 0)} km',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _boton(
                          'Ver ficha del vehículo',
                          () => _abrirVehiculo(v),
                          icon: Icons.arrow_forward,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ];
  }

  List<Widget> _inicio() {
    if (_nav == 0) return _resumen();
    if (_nav == 1) return _catalogoVehiculos();
    if (_nav == 6) return _notificacionesVista();
    if (_nav >= 3 && _nav <= 5) {
      return _vehiculosGestion(documentos: _nav == 4, historial: _nav == 5);
    }
    final filas =
        _flota
            .where(
              (v) =>
                  _cumple(v) &&
                  '${v['placa']} ${v['conductor_nombre']} ${v['descripcion']}'
                      .toLowerCase()
                      .contains(_buscar.toLowerCase()),
            )
            .toList();
    return [
      ConductorHeading(
        _destinos[_nav].label,
        _nav == 3
            ? 'Selecciona un vehículo para consultar y registrar intervenciones.'
            : _nav == 5
            ? 'Selecciona un vehículo para filtrar jornadas y exportar sus registros.'
            : 'Selecciona un vehículo para consultar su expediente y gestionar la operación.',
      ),
      TextField(
        key: ValueKey('buscar-$_nav'),
        decoration: const InputDecoration(
          hintText: 'Buscar placa o conductor',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (v) => setState(() => _buscar = v),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final f in [
            'Todos',
            'Por autorizar',
            'Pendientes',
            'Por verificar',
            'Vencidas',
            'Documentos',
          ])
            ChoiceChip(
              label: Text(f),
              selected: _filtro == f,
              onSelected: (_) => setState(() => _filtro = f),
            ),
        ],
      ),
      const SizedBox(height: 20),
      if (filas.isEmpty)
        const TransporteAviso(
          'Sin resultados',
          'No hay vehículos que coincidan con estos filtros.',
        ),
      FlotaGrid(
        columns: 3,
        children: [for (final v in filas) _vehiculoCard(v)],
      ),
    ];
  }

  List<Widget> _expediente(Map<String, dynamic> v) => [
    Align(
      alignment: Alignment.centerLeft,
      child: _boton(
        _nav == 4
            ? 'Volver a documentos'
            : _nav == 3
            ? 'Volver a mantenimiento'
            : _nav == 6
            ? 'Volver a notificaciones'
            : _nav == 5
            ? 'Volver a historial y reportes'
            : 'Volver a la flota',
        () => setState(() => _id = null),
        icon: Icons.arrow_back,
      ),
    ),
    const SizedBox(height: 12),
    Text(
      '${v['placa']} · ${v['descripcion']}',
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
    ),
    const SizedBox(height: 10),
    Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Conductor actual: ${v['conductor_nombre']}',
          style: const TextStyle(fontSize: 15, color: ConductorDesign.muted),
        ),
        ConductorBadge(v['autorizacion'].toString()),
      ],
    ),
    const SizedBox(height: 12),
    Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ConductorDesign.line)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final e
                in [
                  'Resumen',
                  'Inspecciones y salida',
                  'Actividades',
                  'Mantenimiento',
                  'Documentos',
                  'Historial',
                ].asMap().entries)
              Semantics(
                selected: _tab == e.key,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color:
                            _tab == e.key
                                ? ConductorDesign.lime
                                : Colors.transparent,
                        width: 4,
                      ),
                    ),
                  ),
                  child: TextButton(
                    onPressed: () => setState(() => _tab = e.key),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          _tab == e.key
                              ? ConductorDesign.navy
                              : ConductorDesign.muted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      e.value,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 16),
    if (_tab == 0) ...[
      _panelKit(v),
      const SizedBox(height: 16),
      FlotaGrid(
        children: [
          FlotaMetric(
            'Kilometraje',
            '${NumberFormat.decimalPattern('es_CO').format(v['km'] ?? 0)} km',
            compact: true,
            icon: Icons.speed,
          ),
          FlotaMetric(
            'Salida de hoy',
            '${v['autorizacion']}',
            compact: true,
            icon: Icons.verified_user_outlined,
          ),
          FlotaMetric(
            'Actividades pendientes',
            '${_numero(v, 'pendientes')}',
            compact: true,
            icon: Icons.assignment_outlined,
          ),
          FlotaMetric(
            'Por verificar',
            '${_numero(v, 'por_verificar')}',
            compact: true,
            icon: Icons.fact_check_outlined,
          ),
        ],
      ),
      const SizedBox(height: 12),
      FlotaColumns(
        main: FlotaPanel(
          compact: true,
          title: 'Salida de hoy',
          children: [
            Text(
              v['inicio'] == true
                  ? 'Consulta la inspección registrada y la decisión de salida. Las actividades correctivas se gestionan de forma independiente.'
                  : 'Aún no hay checklist de salida. Cuando el conductor lo registre, podrás revisar las novedades y autorizar la salida.',
              style: const TextStyle(
                fontSize: 16,
                color: ConductorDesign.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => _revision(v),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Abrir revisión y actividades'),
              ),
            ),
          ],
        ),
        aside: FlotaPanel(
          compact: true,
          title: 'Conductor actual',
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: ConductorDesign.navy,
                  child: Icon(Icons.person_outline, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    '${v['conductor_nombre']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _boton(
              'Cambiar conductor entre jornadas',
              () => _asignar(v),
              icon: Icons.swap_horiz,
            ),
            const SizedBox(height: 16),
            const Text(
              'El historial conserva quién realizó cada registro. Para reasignar, cierra primero la jornada abierta.',
              style: TextStyle(color: ConductorDesign.muted, height: 1.4),
            ),
          ],
        ),
      ),
    ],
    if (_tab == 1)
      FlotaPanel(
        title: 'Inspecciones y autorización',
        children: [
          FlotaGrid(
            columns: 3,
            children: [
              FlotaMetric(
                '1 · Inicio',
                v['inicio'] == true ? 'Registrado' : 'Pendiente',
                detail: 'Checklist al iniciar la jornada',
                icon: Icons.login,
              ),
              FlotaMetric(
                '2 · Autorización de salida',
                '${v['autorizacion']}',
                detail: 'Decisión del administrador antes de salir a ruta',
                icon: Icons.verified_user_outlined,
              ),
              FlotaMetric(
                '3 · Cierre',
                v['fin'] == true ? 'Registrado' : 'Pendiente',
                detail: 'Checklist al finalizar la jornada',
                icon: Icons.logout,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _revision(v),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Abrir revisión y actividades'),
            ),
          ),
        ],
      ),
    if (_tab == 2)
      FlotaPanel(
        title: 'Seguimiento de actividades',
        children: [
          FlotaGrid(
            columns: 3,
            children: [
              FlotaMetric(
                'Pendientes',
                '${_numero(v, 'pendientes')}',
                icon: Icons.build_outlined,
              ),
              FlotaMetric(
                'Por verificar',
                '${_numero(v, 'por_verificar')}',
                icon: Icons.fact_check_outlined,
              ),
              FlotaMetric(
                'Vencidas',
                '${_numero(v, 'vencidas')}',
                icon: Icons.event_busy_outlined,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _revision(v),
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Abrir revisión y actividades'),
            ),
          ),
        ],
      ),
    if (_tab == 3) ...[
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final tipo in [
            'Mantenimiento preventivo',
            'Mantenimiento correctivo',
          ])
            _boton(
              'Registrar $tipo',
              () => _registrar(tipo),
              icon: Icons.build_outlined,
            ),
        ],
      ),
      const SizedBox(height: 12),
      _HistorialMantenimiento(vehiculo: v['id']),
    ],
    if (_tab == 4)
      ConductorPanel(
        title: 'Documentos del vehículo y conductor asignado',
        children: [
          FlotaGrid(
            columns: 2,
            children: [
              for (final d in documentosConductor)
                ConductorPanel(
                  title: d,
                  icon: Icons.description_outlined,
                  children: [
                    const Text(
                      'Vigencia hasta',
                      style: TextStyle(
                        color: ConductorDesign.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (v['datos'] as Map?)?[d]?.toString() ??
                          'Sin fecha registrada',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ConductorBadge(
                        _estadoDocumento(v, d),
                        warning:
                            _diasDocumento(v, d) == null ||
                            (_diasDocumento(v, d) ?? 31) <= 30,
                        error: (_diasDocumento(v, d) ?? 1) < 0,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          _boton(
            'Actualizar documentos y vencimientos',
            () => _registrar('Documentos'),
            icon: Icons.edit_outlined,
          ),
        ],
      ),
    if (_tab == 5)
      HistorialConductorView(
        key: ValueKey('admin-hist-${v['id']}'),
        vehiculo: VehiculoConductor.fromJson(v),
        administrador: true,
      ),
  ];
  int? _diasDocumento(Map<String, dynamic> v, String d) {
    final fecha = DateTime.tryParse((v['datos'] as Map?)?[d]?.toString() ?? '');
    return fecha == null ? null : diasRestantes(fecha, hoyColombia());
  }

  String _estadoDocumento(Map<String, dynamic> v, String d) {
    final dias = _diasDocumento(v, d);
    if (dias == null) return 'Sin registrar';
    if (dias < 0) return 'Vencido';
    if (dias == 0) return 'Vence hoy';
    return dias <= 30 ? 'Vence en $dias días' : 'Vigente';
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ConductorDesign.theme(),
    child: TransporteScaffold(
      integratedNavigation: true,
      destinos: _destinos,
      selected: _nav,
      onSelected: _navegar,
      usuario: 'Administración de flota',
      mobileNavigation: Builder(
        builder:
            (ctx) => NavigationBar(
              selectedIndex: _nav <= 3 ? _nav : 3,
              onDestinationSelected:
                  (i) => i == 3 ? Scaffold.of(ctx).openDrawer() : _navegar(i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  label: 'Resumen',
                ),
                NavigationDestination(
                  icon: Icon(Icons.local_shipping_outlined),
                  label: 'Vehículos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.assignment_outlined),
                  label: 'Actividades',
                ),
                NavigationDestination(icon: Icon(Icons.menu), label: 'Más'),
              ],
            ),
      ),
      appBar: TransporteAppBar(
        actions: [
          IconButton(
            tooltip: 'Notificaciones',
            onPressed: () => _navegar(6),
            icon: Badge.count(
              count:
                  _avisosAdministrativos()
                      .where((a) => !_avisosLeidos.contains(a.id))
                      .length,
              isLabelVisible: _avisosAdministrativos().any(
                (a) => !_avisosLeidos.contains(a.id),
              ),
              child: const Icon(Icons.notifications_none),
            ),
          ),
          MenuUsuarioTransporte(
            oscuro: true,
            administrador: true,
            onPerfil:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => Theme(
                          data: ConductorDesign.theme(),
                          child: Scaffold(
                            appBar: AppBar(title: const Text('Perfil')),
                            body: const SafeArea(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.all(20),
                                child: PerfilTransporte(administrador: true),
                              ),
                            ),
                          ),
                        ),
                  ),
                ),
          ),
          IconButton(
            onPressed: _cargando ? null : _cargar,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar flota',
          ),
        ],
      ),
      body: SafeArea(
        child:
            _cargando
                ? const WmsLoadingPanel(label: 'Cargando flota…')
                : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    key: ValueKey(_id ?? 'flota-$_nav'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(
                      MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
                    ),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1440),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_error != null)
                                ConductorPanel(
                                  title: 'No se pudo cargar la flota',
                                  children: [
                                    AvisoFormulario(_error!),
                                    _boton('Reintentar', _cargar),
                                  ],
                                )
                              else
                                ...(_actual == null
                                    ? _inicio()
                                    : _expediente(_actual!)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    ),
  );
}

class _HistorialMantenimiento extends ConsumerWidget {
  const _HistorialMantenimiento({required this.vehiculo});
  final String vehiculo;
  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: ref.read(conductorRepositoryProvider).historial(vehiculo),
    builder: (context, s) {
      if (s.hasError) {
        return const Text('No se pudo consultar el mantenimiento.');
      }
      if (!s.hasData) {
        return const WmsLoadingPanel(
          label: 'Cargando mantenimientos del vehículo…',
        );
      }
      final filas =
          s.data!
              .where((r) => r['tipo'].toString().startsWith('Mantenimiento'))
              .toList();
      return ConductorPanel(
        title: 'Mantenimientos entre los últimos 100 registros',
        children: [
          if (filas.isEmpty)
            const Text(
              'Sin mantenimientos en este período de registros. Consulta Historial para buscar otras fechas.',
            ),
          for (final r in filas)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${r['tipo']} · ${r['datos']['fecha'] ?? ''}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  ConductorBadge(
                    '${r['datos']['origen_mantenimiento'] ?? 'Origen no disponible'}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${r['datos']['servicio'] ?? ''}\nResponsable: ${r['actor_nombre']} · Valor: ${r['datos']['valor'] ?? ''} COP',
                  ),
                  if ((r['datos']['novedades_origen'] as List? ?? [])
                      .isNotEmpty)
                    Text(
                      'Novedades del checklist: ${(r['datos']['novedades_origen'] as List).join(', ')}',
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

class _AsignacionDialog extends ConsumerStatefulWidget {
  const _AsignacionDialog({this.vehiculo});
  final Map? vehiculo;
  @override
  ConsumerState<_AsignacionDialog> createState() => _AsignacionDialogState();
}

class _AsignacionDialogState extends ConsumerState<_AsignacionDialog> {
  final _form = GlobalKey<FormState>();
  late final _placa = TextEditingController(text: widget.vehiculo?['placa']);
  late final _descripcion = TextEditingController(
    text: widget.vehiculo?['descripcion'],
  );
  late final _km = TextEditingController(
    text: widget.vehiculo?['km']?.toString(),
  );
  String? _numero;
  List<Map<String, dynamic>> _conductores = [];
  bool _cargandoConductores = true;
  String? _errorConductores;

  @override
  void initState() {
    super.initState();
    _cargarConductores();
  }

  Future<void> _cargarConductores() async {
    setState(() {
      _cargandoConductores = true;
      _errorConductores = null;
    });
    try {
      final filas =
          await ref.read(conductorRepositoryProvider).conductoresActivos();
      if (!mounted) return;
      setState(() {
        _conductores = filas;
        final actual = widget.vehiculo?['conductor_numero']?.toString();
        _numero =
            filas.any((u) => u['numero_usuario'].toString() == actual)
                ? actual
                : null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorConductores = 'No se pudieron cargar los conductores.',
        );
      }
    } finally {
      if (mounted) setState(() => _cargandoConductores = false);
    }
  }

  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _placa.dispose();
    _descripcion.dispose();
    _km.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(conductorRepositoryProvider)
          .crearVehiculo(
            _placa.text.trim(),
            _descripcion.text.trim(),
            int.parse(_km.text),
            _numero!,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error =
                  e is PostgrestException
                      ? e.message
                      : 'No se pudo guardar la asignación.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Asignar vehículo a conductor'),
      content:
          _busy
              ? const SizedBox(
                width: 340,
                height: 320,
                child: WmsLoadingPanel(
                  label: 'Guardando asignación del vehículo…',
                ),
              )
              : SingleChildScrollView(
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final e
                          in {
                            _placa: 'Placa',
                            _descripcion: 'Descripción',
                            _km: 'Kilometraje',
                          }.entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TextFormField(
                            controller: e.key,
                            enabled: !_busy,
                            readOnly:
                                widget.vehiculo != null && e.key == _placa,
                            decoration: InputDecoration(labelText: e.value),
                            validator:
                                (v) =>
                                    v == null || v.trim().isEmpty
                                        ? 'Obligatorio'
                                        : e.key == _km &&
                                            (int.tryParse(v) == null ||
                                                int.parse(v) < 0)
                                        ? 'Kilometraje inválido'
                                        : null,
                          ),
                        ),
                      if (_cargandoConductores)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: WmsLoadingStrip(
                            label: 'Cargando conductores…',
                          ),
                        )
                      else if (_errorConductores != null) ...[
                        AvisoFormulario(_errorConductores!),
                        TextButton(
                          onPressed: _cargarConductores,
                          child: const Text('Reintentar'),
                        ),
                      ] else if (_conductores.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text(
                            'No hay conductores activos. Crea o activa una cuenta con rol conductor en Usuarios.',
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: DropdownButtonFormField<String>(
                            initialValue: _numero,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Conductor',
                            ),
                            hint: const Text('Selecciona un conductor'),
                            items: [
                              for (final u in _conductores)
                                DropdownMenuItem(
                                  value: u['numero_usuario'].toString(),
                                  child: Text(
                                    u['nombre'].toString(),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged:
                                _busy
                                    ? null
                                    : (v) => setState(() => _numero = v),
                            validator:
                                (v) =>
                                    v == null
                                        ? 'Selecciona un conductor'
                                        : null,
                          ),
                        ),
                      const Text(
                        'La asignación anterior del conductor quedará libre. No se cambia mientras exista una jornada abierta.',
                      ),
                      if (_error != null) AvisoFormulario(_error!),
                    ],
                  ),
                ),
              ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed:
              _busy ||
                      _cargandoConductores ||
                      _errorConductores != null ||
                      _conductores.isEmpty
                  ? null
                  : _guardar,
          child: Text(_busy ? 'Guardando…' : 'Guardar asignación'),
        ),
      ],
    ),
  );
}
