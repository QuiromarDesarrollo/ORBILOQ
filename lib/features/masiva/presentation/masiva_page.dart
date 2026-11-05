import '../../../shared/borrador_operativo.dart';
import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import '../../../application/auth_providers.dart';
import '../../../core/masiva_entorno.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/sesion.dart';
import '../../../data/empaques_repository.dart' show textoEmpaque;
import '../../../shared/descargar_pdf.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/wms_alert.dart';
import 'masiva_camera_scanner.dart';
import '../../../shared/widgets/wms_loader.dart';
import '../../../shared/widgets/wms_dialog.dart';
import '../../../shared/widgets/wms_empty_state.dart';
import '../masiva_documentos.dart';
import '../masiva_importador.dart';
import '../masiva_repository.dart';
import '../../admin/presentation/empaque_editor.dart';
import 'masiva_recepcion_tabla.dart';
import 'masiva_maestro_tabla.dart';
import 'widgets/masiva_receipt_card.dart';

part 'masiva_acciones.dart';
part 'masiva_componentes.dart';
part 'masiva_recepcion.dart';
part 'masiva_validacion.dart';
part 'masiva_validacion_vista.dart';
part 'masiva_maestro.dart';
part 'masiva_operacion.dart';

const _ink = AppColors.petroleo;
const _lime = AppColors.lima;
const _muted = Color(0xFF627D89);
const _line = Color(0xFFDCE7EC);
const _bg = Color(0xFFF2F6F7);
const _sections = <(String, IconData, String)>[
  ('Resumen', Icons.space_dashboard_outlined, 'resumen'),
  ('Recepción', Icons.move_to_inbox_outlined, 'inventario'),
  ('Listado maestro', Icons.view_list_outlined, 'listado'),
  ('Validación', Icons.qr_code_scanner, 'kits'),
  ('Listas y documentos', Icons.description_outlined, 'documentos'),
  ('Indicadores', Icons.bar_chart_rounded, 'indicadores'),
  ('Auditoría', Icons.history_rounded, 'auditoria'),
  ('Configuración', Icons.tune_rounded, 'configuracion'),
  ('Base de datos maestra', Icons.table_chart_outlined, 'base'),
  ('Conciliación', Icons.compare_arrows_rounded, 'conciliacion'),
];

class MasivaPage extends ConsumerStatefulWidget {
  const MasivaPage({super.key});
  @override
  ConsumerState<MasivaPage> createState() => _MasivaPageState();
}

class _MasivaPageState extends ConsumerState<MasivaPage>
    with BorradorOperativo<MasivaPage> {
  @override
  String get borradorProceso => 'masiva';
  @override
  Future<void> alRecuperarBorrador() => _load();
  @override
  bool get operacionEnCurso => _busy != null || _scanning;
  @override
  Iterable<TextEditingController> get controlesBorrador => [
    _search,
    _list,
    _packNumber,
    _receiptSupport,
    _receiptNote,
    ..._receiptDrafts.map((d) => d.quantity),
  ];
  @override
  MasivaJson capturarBorrador() => {
    'operacion': _operationId,
    'seccion': _section,
    'buscar': _search.text,
    'lista': _list.text,
    'kit': _kit['id'],
    'tipo': _packType,
    'numero': _packNumber.text,
    'empacador': _validationPackerId,
    'remision': _receiptSupport.text,
    'nota': _receiptNote.text,
    'proveedor': _receiptSupplier,
    'orden': _receiptOrder,
    'recepciones': [
      for (final d in _receiptDrafts)
        {
          'item': d.item,
          'operacion': d.operation,
          'soporte': d.support,
          'nota': d.note,
          'cantidad': d.quantity.text,
        },
    ],
  };
  @override
  void recuperarBorrador(MasivaJson d) {
    _operationId = d['operacion'] as String?;
    _section = (d['seccion'] as int? ?? 0).clamp(0, _sections.length - 1);
    _search.text = d['buscar'] as String? ?? '';
    _list.text = d['lista'] as String? ?? '';
    _kit = d['kit'] == null ? {} : {'id': d['kit']};
    _packType = d['tipo'] as String?;
    _packNumber.text = d['numero'] as String? ?? '';
    _validationPackerId = d['empacador'] as String?;
    _receiptSupport.text = d['remision'] as String? ?? '';
    _receiptNote.text = d['nota'] as String? ?? '';
    _receiptSupplier = d['proveedor'] as String?;
    _receiptOrder = d['orden'] == null ? null : mapaMasiva(d['orden']);
    for (final r in _receiptDrafts) {
      r.quantity.dispose();
    }
    _receiptDrafts.clear();
    for (final r in filasMasiva(d['recepciones'])) {
      _receiptDrafts.add(
        _ReceiptDraft(
          mapaMasiva(r['item']),
          r['operacion'] as String,
          r['soporte'] as String,
          r['nota'] as String,
        )..quantity.text = r['cantidad'] as String,
      );
    }
  }

  final _search = TextEditingController();
  final _list = TextEditingController();
  final _sku = TextEditingController();
  final _packNumber = TextEditingController();
  String? _packType;
  String? _validationPackerId;
  final _receiptSku = TextEditingController();
  final _receiptSupport = TextEditingController();
  final _receiptNote = TextEditingController();
  final _receiptHistorySearch = TextEditingController();
  final _receiptFocus = FocusNode();
  final _receiptRevision = ValueNotifier<int>(0);
  bool _receiptDialogOpen = false;
  int _receiptTab = 0, _receiptHistoryPage = 1, _receiptHistoryTotal = 0;
  int _receiptHistoryEpoch = 0;
  bool _receiptHistoryLoading = false;
  String? _receiptHistoryError;
  List<MasivaJson> _receiptHistory = [];
  List<MasivaJson> _receiptOrders = [];
  String? _receiptSupplier, _receiptMessage;
  bool _receiptError = false;
  int _receiptReads = 0;
  final List<_ReceiptDraft> _receiptDrafts = [];
  String _balanceStatus = '';
  final _scanFocus = FocusNode();
  final _personFocus = FocusNode();
  final _validationPackerFocus = FocusNode();
  final List<String> _scanQueue = [];
  bool _scanning = false, _scanAlert = false, _cameraOpen = false;
  String? _scanFeedback, _lastScanSku;
  final _scaffold = GlobalKey<ScaffoldState>();
  Timer? _timer;
  int _section = 0, _page = 1, _epoch = 0;
  bool _loading = true, _dialog = false;
  String? _operationId, _error, _busy;
  double? _progress;
  DateTime? _updated;
  List<MasivaJson> _operations = [],
      _people = [],
      _packages = [],
      _assignments = [];
  MasivaJson _data = {}, _kit = {};
  MasivaJson _masterLoadedQuery = {};
  MasivaJson _balanceLoadedQuery = {};
  final Map<String, Set<String>> _receptionFilters = {};
  final Map<String, Set<String>> _masterFilters = {};
  final Set<String> _selectedLists = {};
  int _masterPageSize = 30;
  String _masterDateType = 'fecha_carga';
  DateTime? _masterFrom, _masterUntil;
  bool get _isMaster => _section == 2 || _section == 8;
  MasivaJson? _receiptOrder;
  MasivaRepository get _repo => ref.read(masivaRepositoryProvider);
  void _redraw(VoidCallback change) {
    if (!mounted) return;
    setState(change);
    if (_receiptDialogOpen) _receiptRevision.value++;
  }

  bool get _admin =>
      !ref.read(usarSupabaseProvider) ||
      ref.read(usuarioSesionProvider).valueOrNull?.tieneRol(RolCuenta.admin) ==
          true;
  MasivaJson get _operation => mapaMasiva(_data['operacion']);
  bool get _archived => ['cerrada', 'archivada'].contains(_operation['estado']);
  bool get _editable =>
      _repo.conectado &&
      !_archived &&
      _error == null &&
      _busy == null &&
      _repo.movimientoPendiente == null;
  List<MasivaJson> get _rows => filasMasiva(_data['filas']);
  List<MasivaJson> get _validationPackages {
    final active = _packages.where((p) => p['activo'] != false).toList();
    final id = _kit['empaque_id']?.toString();
    if (_kit['caja'] == null || id == null) {
      return active;
    }
    final snapshot = mapaMasiva(_kit['empaque_snapshot']);
    if (snapshot.isEmpty) return active;
    return [
      ...active.where((p) => '${p['id']}' != id),
      {
        ...snapshot,
        'id': id,
        'nombre': snapshot['nombre'] ?? _kit['caja_nombre'],
        'tipo': snapshot['tipo'] ?? '${snapshot['categoria']}'.toLowerCase(),
        'largo': snapshot['largo'] ?? snapshot['largo_cm'],
        'ancho': snapshot['ancho'] ?? snapshot['ancho_cm'],
        'alto': snapshot['alto'] ?? snapshot['alto_cm'],
        'peso_vacio': snapshot['peso_vacio'] ?? snapshot['peso_neto_kg'],
        'peso_lleno':
            snapshot['peso_lleno'] ?? snapshot['peso_promedio_masiva_kg'],
      },
    ];
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_dialog &&
          !_cameraOpen &&
          !_scanning &&
          _busy == null &&
          !_loading) {
        _load(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    _list.dispose();
    _sku.dispose();
    _packNumber.dispose();
    for (final draft in _receiptDrafts) {
      draft.quantity.dispose();
    }
    _receiptSku.dispose();
    _receiptSupport.dispose();
    _receiptNote.dispose();
    _receiptHistorySearch.dispose();
    _receiptFocus.dispose();
    _receiptRevision.dispose();
    _scanFocus.dispose();
    _personFocus.dispose();
    _validationPackerFocus.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_scanning) return;
    final serial = ++_epoch;
    if (!silent && mounted) _redraw(() => _loading = true);
    try {
      final operations = await _repo.consultar();
      if (!mounted || serial != _epoch) return;
      final available = filasMasiva(operations['operaciones']);
      final id =
          available.any((o) => o['id'] == _operationId)
              ? _operationId
              : available.firstOrNull?['id']?.toString();
      MasivaJson data = {};
      MasivaJson masterQuery = {};
      MasivaJson? selectedKit;
      List<MasivaJson> people = [], packages = [], assignments = [];
      if (id != null) {
        if (id != _operationId) {
          _receptionFilters.clear();
          _receiptOrder = null;
          _masterFilters.clear();
          _selectedLists.clear();
        }
        if (_isMaster) {
          masterQuery = {
            'buscar': _search.text.trim(),
            'filtros': _masterQueryFilters,
            'fecha_tipo': _masterDateType,
            'desde': _masterDateParam(_masterFrom),
            'hasta': _masterDateParam(_masterUntil),
          };
        }
        final result = await Future.wait([
          _isMaster
              ? _repo.consultarMaestro(
                operacion: id,
                vista: _section == 2 ? 'listado' : 'base',
                buscar: _search.text.trim(),
                filtros: _masterQueryFilters,
                pagina: _page,
                tamano: _masterPageSize,
                fechaTipo: _masterDateType,
                desde: _masterDateParam(_masterFrom),
                hasta: _masterDateParam(_masterUntil),
              )
              : _section == 9
              ? _repo.consultarConciliacion(
                operacion: id,
                buscar: _search.text.trim(),
                estado: _balanceStatus,
                pagina: _page,
              )
              : _repo.consultar(
                operacion: id,
                vista: _section == 1 ? 'resumen' : _sections[_section].$3,
                buscar: _search.text.trim(),
                lista: _list.text.trim(),
                pagina: _page,
              ),
          _repo.consultar(operacion: id, vista: 'personal'),
          _repo.consultar(operacion: id, vista: 'empaques'),
          if (_section == 1)
            _repo.consultarRecepcion(
              operacion: id,
              buscar: _search.text.trim(),
              filtros: _receiptOrder == null ? _receptionFilters : const {},
              pagina: _page,
              proveedor: _receiptOrder?['proveedor']?.toString(),
              pedido: _receiptOrder?['pedido']?.toString(),
            ),
          if (_section == 1) _repo.consultarPuesto(id),
          if (_section == 2)
            _repo.consultar(
              operacion: id,
              vista: 'asignaciones',
              lista: _list.text.trim(),
            ),
        ]);
        if (!mounted || serial != _epoch) return;
        if (_section == 9) {
          _balanceLoadedQuery = {
            'buscar': _search.text.trim(),
            'estado': _balanceStatus,
          };
        }
        data = {
          'operacion': available.firstWhere((o) => o['id'] == id),
          ...result[0],
        };
        if (_section == 1) {
          _receiptOrders = filasMasiva(result[4]['pedidos']);
          final reception = result[3];
          data = {
            ...data,
            ...reception,
            'metricas': {
              ...mapaMasiva(data['metricas']),
              ...mapaMasiva(reception['metricas']),
            },
          };
        }
        people = filasMasiva(result[1]['filas']);
        packages = filasMasiva(result[2]['filas']);
        if (_section == 2) assignments = filasMasiva(result[3]['filas']);
        if (_section == 3 && _kit.isNotEmpty) {
          selectedKit =
              filasMasiva(
                data['filas'],
              ).where((r) => r['id'] == _kit['id']).firstOrNull;
          if (selectedKit == null) {
            final selected = await _repo.consultar(
              operacion: id,
              vista: 'kits',
              buscar: '${_kit['id']}',
            );
            selectedKit =
                filasMasiva(
                  selected['filas'],
                ).where((r) => r['id'] == _kit['id']).firstOrNull;
          }
        }
      }
      if (!mounted || serial != _epoch) return;
      if (_isMaster && id != null) {
        final lastPage = (numeroMasiva(data['total']) / _masterPageSize)
            .ceil()
            .clamp(1, 100000);
        if (_page > lastPage) {
          _page = lastPage;
          await _load(silent: silent);
          return;
        }
      }
      _redraw(() {
        _operations = available;
        _operationId = id;
        _data = data;
        _masterLoadedQuery = masterQuery;
        _people = people;
        _packages = packages;
        _assignments = assignments;
        _error = null;
        _loading = false;
        _updated = DateTime.now();
        if (_kit.isNotEmpty) {
          _kit = selectedKit ?? {};
        }
      });
    } catch (e) {
      if (!mounted || serial != _epoch) return;
      _redraw(() {
        _loading = false;
        _error = errorMasiva(e);
      });
    }
  }

  Future<void> _select(
    int index, {
    String lista = '',
    String buscar = '',
  }) async {
    if (_scanning || _scanAlert) return;
    setState(() {
      _section = index;
      _page = 1;
      _kit = {};
      _validationPackerId = null;
      _data = {};
      _masterLoadedQuery = {};
      _search.text = buscar;
      _list.text = lista;
      _sku.clear();
      _scanFeedback = null;
      _lastScanSku = null;
      _receiptOrder = null;
      _receiptSupplier = null;
      _receiptSupport.clear();
      _receiptNote.clear();
      _receiptReads = 0;
      _receiptMessage = null;
      _balanceStatus = '';
      _receptionFilters.clear();
      _masterFilters.clear();
      _selectedLists.clear();
      _masterFrom = null;
      _masterUntil = null;
      _masterDateType = index == 2 ? 'ultima_validacion' : 'fecha_carga';
    });
    await _load();
    if (index == 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _section == 3 && !_scanAlert && !_scanning) {
          _personFocus.requestFocus();
        }
      });
    }
  }

  Future<void> _work(
    String label,
    Future<void> Function() task, {
    bool refresh = true,
  }) async {
    if (_busy != null || _scanning || _scanAlert) return;
    ++_epoch;
    _redraw(() {
      _busy = label;
      _progress = null;
    });
    try {
      await task();
    } catch (e) {
      if (mounted) {
        // Nunca repetir un descuento automáticamente si se perdió su respuesta.
        await mostrarAviso(context, errorMasiva(e), error: true);
      }
    } finally {
      if (mounted) {
        _redraw(() {
          _busy = null;
          _progress = null;
        });
        if (refresh) await _load(silent: true);
      }
    }
  }

  Future<void> _execute(
    String action,
    MasivaJson data, {
    String label = 'Guardando cambios…',
  }) => _work(label, () async {
    await _repo.ejecutar(action, {'operacion_id': _operationId, ...data});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cambios guardados'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final remote = ref.watch(usarSupabaseProvider);
    final user = remote ? ref.watch(usuarioSesionProvider).valueOrNull : null;
    if (!masivaHabilitada() ||
        (remote &&
            user?.tieneRol(RolCuenta.admin) != true &&
            user?.tieneRol(RolCuenta.masiva) != true)) {
      return const Scaffold(
        body: Center(child: Text('No tienes acceso a Masiva.')),
      );
    }
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 1080;
    return Theme(
      data: _masivaTheme(),
      child: PopScope(
        canPop: _busy == null && !_scanning,
        child: Scaffold(
          key: _scaffold,
          backgroundColor: _bg,
          drawer:
              desktop
                  ? null
                  : Drawer(
                    backgroundColor: _ink,
                    child: SafeArea(child: _navigation(true)),
                  ),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: _ink,
            foregroundColor: Colors.white,
            surfaceTintColor: _ink,
            toolbarHeight: 72,
            titleSpacing: desktop ? 20 : 8,
            leading:
                desktop
                    ? null
                    : IconButton(
                      tooltip: 'Abrir menú',
                      icon: const Icon(Icons.menu),
                      onPressed: () => _scaffold.currentState?.openDrawer(),
                    ),
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/logo_orbiloq.png',
                    width: 42,
                    height: 42,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ORBILOQ',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Grupo Quiromar',
                      style: TextStyle(fontSize: 11, color: Color(0xFFC0D7E0)),
                    ),
                  ],
                ),
                if (width > 600) ...[
                  const SizedBox(width: 26),
                  _pill('MASIVA', dark: true),
                ],
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Actualizar datos',
                onPressed: _busy == null && !_scanning ? () => _load() : null,
                icon: const Icon(Icons.sync),
              ),
              PopupMenuButton<String>(
                enabled: !_scanning && !_scanAlert && _busy == null,
                tooltip: 'Menú de usuario',
                onSelected: (v) {
                  if (v == 'salir') {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    ref.read(authRepositoryProvider)?.cerrarSesion();
                  }
                  if (v == 'volver') Navigator.of(context).maybePop();
                },
                itemBuilder:
                    (_) => [
                      PopupMenuItem(
                        enabled: false,
                        child: Text(user?.nombre ?? 'Vista local'),
                      ),
                      if (Navigator.of(context).canPop())
                        const PopupMenuItem(
                          value: 'volver',
                          child: Text('Cambiar área'),
                        ),
                      if (remote)
                        const PopupMenuItem(
                          value: 'salir',
                          child: Text('Cerrar sesión'),
                        ),
                    ],
                child: Padding(
                  padding: const EdgeInsets.only(right: 18, left: 6),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: _lime,
                        child: Icon(
                          Icons.person_outline,
                          color: _ink,
                          size: 20,
                        ),
                      ),
                      if (width > 700) ...[
                        const SizedBox(width: 9),
                        Text(
                          user?.nombre ?? 'Vista local',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        const Icon(Icons.expand_more, size: 18),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (desktop)
                    SizedBox(
                      width: 232,
                      child: ColoredBox(color: _ink, child: _navigation(false)),
                    ),
                  Expanded(child: _body(width - (desktop ? 232 : 0))),
                ],
              ),
              if (_busy != null)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.white.withValues(alpha: .96),
                    child: WmsLoadingPanel(label: _busy!, value: _progress),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navigation(bool drawer) => Column(
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(22, 26, 22, 18),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'OPERACIÓN MASIVA',
            style: TextStyle(
              color: Color(0xFF91B4C2),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final i in [0, 1, 9, 2, 8, 3, 4, 5, 6, 7])
              if (i != 7 || _admin)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color:
                        _section == i
                            ? const Color(0xFF21566A)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap:
                          _busy == null
                              ? () {
                                if (drawer) Navigator.pop(context);
                                _select(i);
                              }
                              : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: _section == i ? _lime : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _sections[i].$2,
                              size: 20,
                              color:
                                  _section == i
                                      ? _lime
                                      : const Color(0xFFB7CED8),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _sections[i].$1,
                                style: TextStyle(
                                  color:
                                      _section == i
                                          ? Colors.white
                                          : const Color(0xFFC2D7DF),
                                  fontSize: 13,
                                  fontWeight:
                                      _section == i
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(color: Color(0xFF315B6C)),
            const SizedBox(height: 12),
            Text(
              masivaNombreEntorno(),
              style: const TextStyle(
                color: Color(0xFFB0CBD6),
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _repo.conectado
                  ? 'Datos de la operación'
                  : 'Vista local · sin conexión',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
            if (Navigator.of(context).canPop())
              TextButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, size: 16, color: _lime),
                label: const Text(
                  'Cambiar área',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _body(double width) =>
      _section == 3
          ? _validationWorkspace(width)
          : SingleChildScrollView(
            padding: EdgeInsets.all(width < 600 ? 16 : 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    estadoBorrador(),
                    if (_operations.isNotEmpty) _operationBar(),
                    if (_repo.movimientoPendiente != null) ...[
                      _notice(
                        'Hay un movimiento sin confirmación de red. Recupera su respuesta para continuar sin duplicar cantidades.',
                        Icons.sync_problem,
                        action: TextButton(
                          onPressed:
                              () => _work(
                                'Recuperando la confirmación original…',
                                () async {
                                  await _repo.recuperarConfirmacion();
                                },
                              ),
                          child: const Text('Recuperar'),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_archived) ...[
                      _notice(
                        'Operación archivada. Puedes consultar su historial, indicadores y documentos.',
                        Icons.lock_outline,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_error != null) ...[
                      _notice(
                        _error!,
                        Icons.wifi_off,
                        action: TextButton(
                          onPressed: () => _load(),
                          child: const Text('Reintentar'),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_loading)
                      const SizedBox(
                        height: 350,
                        child: WmsLoadingPanel(label: 'Actualizando Masiva…'),
                      )
                    else if (_operationId == null)
                      _onboarding()
                    else ...[
                      if (_section == 0)
                        _summary(width)
                      else if (_section == 7)
                        _settings(width)
                      else if (_section == 5)
                        _indicators(width)
                      else if (_section == 9)
                        _balanceView(width)
                      else ...[
                        if (_section == 1) _receptionStation(width),
                        if (_isMaster)
                          _masterToolbar(width)
                        else
                          _toolbar(width),
                        const SizedBox(height: 18),
                        if (_isMaster) ...[
                          _masterRecords(width),
                          _masterPagination(),
                          if (_section == 2 && _assignments.isNotEmpty)
                            ExpansionTile(
                              title: const Text(
                                'Asignaciones y tiempos de empaque',
                              ),
                              children: [_assignmentPanel()],
                            ),
                        ],
                        if (_isMaster)
                          const SizedBox.shrink()
                        else if (_section == 1) ...[
                          _receptionRecords(width),
                          _pagination(),
                        ] else if (_rows.isEmpty)
                          _empty(
                            _section == 1
                                ? 'Aún no hay prendas en el plan de recepción'
                                : 'No hay resultados',
                            _section == 1
                                ? 'Carga el Excel de proveedores para registrar las cantidades iniciales.'
                                : 'Prueba con otra lista o búsqueda. Los registros aparecerán aquí al avanzar la operación.',
                          )
                        else ...[
                          _records(width),
                          _pagination(),
                        ],
                      ],
                    ],
                    const SizedBox(height: 24),
                    if (_updated != null && _operationId != null)
                      Text(
                        'Última actualización: ${_updated!.hour.toString().padLeft(2, '0')}:${_updated!.minute.toString().padLeft(2, '0')} · Actualización automática cada 30 s',
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                  ],
                ),
              ),
            ),
          );

  Widget _operationBar() => _panel(
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 340,
          child: DropdownButtonFormField<String>(
            key: ValueKey(_operationId),
            initialValue: _operationId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Operación',
              prefixIcon: Icon(Icons.layers_outlined),
            ),
            items:
                _operations
                    .map(
                      (o) => DropdownMenuItem(
                        value: '${o['id']}',
                        child: Text(
                          '${o['nombre']} · ${o['cliente']}${o['estado'] == 'activa' ? '' : ' · ${o['estado']}'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
            onChanged:
                _scanning || _scanAlert
                    ? null
                    : (v) {
                      setState(() {
                        _operationId = v;
                        _receiptSupplier = null;
                        _receiptSupport.clear();
                        _receiptNote.clear();
                        _receiptSku.clear();
                        _receiptMessage = null;
                        _receiptReads = 0;
                        _receiptOrders = [];
                        _balanceStatus = '';
                        _page = 1;
                        _kit = {};
                        _validationPackerId = null;
                        _data = {};
                        _receiptOrder = null;
                        _receptionFilters.clear();
                        _masterFilters.clear();
                        _selectedLists.clear();
                        _masterFrom = null;
                        _masterUntil = null;
                        _search.clear();
                        _list.clear();
                      });
                      _load();
                    },
          ),
        ),
        _pill(
          _archived ? 'Archivada' : 'En operación',
          color: _archived ? _muted : const Color(0xFF17764C),
        ),
        if (_admin)
          OutlinedButton.icon(
            onPressed: _repo.conectado ? _newOperation : null,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nueva masiva'),
          ),
      ],
    ),
  );

  Widget _onboarding() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.inventory_2_outlined, color: _ink, size: 42),
        const SizedBox(height: 18),
        const Text(
          'Tu próxima masiva comienza aquí',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Crea la operación, carga el plan de recepción y luego la base del personal. Cada masiva mantiene su propio inventario e historial.',
          style: TextStyle(color: _muted, height: 1.6),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final step in [
              '01  Recepción',
              '02  Listado maestro',
              '03  Validación',
              '04  Documentos',
            ])
              _pill(step),
          ],
        ),
        const SizedBox(height: 24),
        if (_admin)
          FilledButton.icon(
            onPressed: _repo.conectado ? _newOperation : null,
            icon: const Icon(Icons.add),
            label: const Text('Crear primera masiva'),
          ),
        if (!_repo.conectado) ...[
          const SizedBox(height: 16),
          _notice(
            'Vista local. Conecta el entorno DEV para crear operaciones. No se han cargado los archivos de ejemplo.',
            Icons.info_outline,
          ),
        ],
      ],
    ),
  );

  Widget _toolbar(double width) => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width < 600 ? double.infinity : 320,
              child: TextField(
                key: _section == 3 ? const ValueKey('masiva-persona') : null,
                controller: _search,
                focusNode: _section == 3 ? _personFocus : null,
                enabled: !_scanning && !_scanAlert,
                decoration: InputDecoration(
                  labelText: _section == 3 ? '1. Documento / cédula' : 'Buscar',
                  hintText:
                      _section == 1
                          ? 'Orden de compra, SKU o proveedor'
                          : _section == 3
                          ? 'Escanea o escribe; también puedes buscar por nombre'
                          : 'Escribe para filtrar',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Buscar',
                    onPressed: _scanning || _scanAlert ? null : _searchRecords,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ),
                onSubmitted: (_) => _searchRecords(),
              ),
            ),
            if (_section != 1)
              SizedBox(
                width: width < 600 ? double.infinity : 170,
                child: TextField(
                  controller: _list,
                  enabled: !_scanning && !_scanAlert,
                  decoration: const InputDecoration(
                    labelText: 'Lista de empaque',
                    hintText: 'Todas las listas',
                  ),
                  onSubmitted: (_) {
                    _searchRecords();
                  },
                ),
              ),
            TextButton.icon(
              onPressed:
                  _scanning || _scanAlert
                      ? null
                      : () {
                        _search.clear();
                        _list.clear();
                        _page = 1;
                        _receptionFilters.clear();
                        _load();
                      },
              icon: const Icon(Icons.filter_alt_off_outlined, size: 17),
              label: const Text('Limpiar'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (_section == 1) ...[
              FilledButton.icon(
                key: const ValueKey('open-receipt-station'),
                onPressed:
                    _repo.conectado && !_archived && _busy == null && !_scanning
                        ? _openReceiptStation
                        : null,
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: Text(
                  _receiptDrafts.any((d) => d.operation == _operationId)
                      ? 'Continuar recepción'
                      : 'Recibir prendas',
                ),
              ),
              TextButton.icon(
                onPressed:
                    !_scanning && _busy == null ? () => _select(9) : null,
                icon: const Icon(Icons.compare_arrows, size: 18),
                label: const Text('Ver conciliación'),
              ),
            ],
            if (_admin && (_section == 1 || _section == 2))
              FilledButton.icon(
                onPressed:
                    _editable
                        ? () =>
                            _import(_section == 1 ? 'recepcion' : 'personal')
                        : null,
                icon: const Icon(Icons.upload_file, size: 18),
                label: Text(
                  _section == 1
                      ? 'Cargar plan de recepción'
                      : 'Cargar base del personal',
                ),
              ),
            if (_section == 2)
              OutlinedButton.icon(
                onPressed: _editable ? _assign : null,
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Asignar kits'),
              ),
            if (_section == 1 && _receiptOrder != null && _admin)
              OutlinedButton.icon(
                onPressed: _editable ? _editReceiptOrder : null,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Horario y novedad'),
              ),
            if (_section == 2)
              OutlinedButton.icon(
                onPressed: _editable ? _time : null,
                icon: const Icon(Icons.timer_outlined, size: 18),
                label: const Text('Registrar tiempo'),
              ),
            if (_section == 4) ...[
              FilledButton.icon(
                onPressed: _editable ? () => _document('lista') : null,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Generar lista'),
              ),
              OutlinedButton.icon(
                onPressed: _editable ? () => _document('rotulo') : null,
                icon: const Icon(Icons.label_outline, size: 18),
                label: const Text('Generar rótulos'),
              ),
            ],
            if (_section == 1 || _section == 2 || _section == 3)
              TextButton.icon(
                onPressed: _rows.isEmpty || _error != null ? null : _export,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Exportar Excel'),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _records(double width) {
    final headings = switch (_section) {
      1 => [
        'SKU',
        'Prenda',
        'Pendiente por recibir',
        'A recibir',
        'Recibida',
        'Saldo en esta orden',
        '',
      ],
      2 => ['Lista', 'Kits', 'Armados', 'Validados', 'Responsable', ''],
      3 => ['Persona', 'Lista · n.º', 'Armador', 'Estado', 'Empaque', ''],
      4 => ['Lista', 'Documento', 'Versión', 'Fecha', ''],
      _ => ['Acción', 'Responsable', 'Fecha', 'Detalle'],
    };
    List<String> values(MasivaJson r) => switch (_section) {
      1 => [
        '${r['sku']}',
        '${r['descripcion']}',
        '${r['pendiente'] ?? 0}',
        '${r['esperado'] ?? 0}',
        '${r['recibido'] ?? 0}',
        r['saldo_oc_sku'] == null ? 'Por cruzar' : '${r['saldo_oc_sku']}',
      ],
      2 => [
        '${r['lista']}',
        '${r['kits'] ?? 0}',
        '${r['armados'] ?? 0}',
        '${r['validados'] ?? 0}',
        '${r['responsable'] ?? 'Sin elegir'}',
      ],
      3 => [
        '${r['nombre']}\n${r['cedula']}',
        '${r['lista']} · ${r['numero_persona']}',
        '${r['empacador'] ?? _personName(r['empacador_id'])}',
        '${r['estado']}',
        '${r['caja'] ?? 'Sin ubicar'}',
      ],
      4 => [
        '${r['lista']}',
        r['tipo'] == 'rotulo' ? 'Rótulos' : 'Lista de empaque',
        '${r['version']}',
        _date(r['created_at'] ?? r['fecha']),
      ],
      _ => [
        '${r['accion'] ?? ''}',
        '${r['actor_nombre'] ?? r['actor'] ?? ''}',
        _date(r['created_at'] ?? r['creado'] ?? r['fecha']),
        _auditDetail(r),
      ],
    };
    Widget action(MasivaJson r) => switch (_section) {
      1 => OutlinedButton(
        onPressed:
            _editable &&
                    numeroMasiva(r['recibido']) < numeroMasiva(r['esperado'])
                ? () => _receive(r)
                : null,
        child: const Text('Recibir'),
      ),
      2 => TextButton(
        onPressed: () {
          _select(3);
          _list.text = '${r['lista']}';
          _load();
        },
        child: const Text('Ver kits'),
      ),
      3 => OutlinedButton(
        onPressed: _scanning || _scanAlert ? null : () => _openValidation(r),
        child: const Text('Abrir kit'),
      ),
      4 => TextButton.icon(
        onPressed: () => _reprint(r),
        icon: const Icon(Icons.download, size: 16),
        label: const Text('PDF'),
      ),
      _ => const SizedBox.shrink(),
    };
    if (width < 900) {
      return Column(
        children: [
          for (final r in _rows)
            _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    values(r).first,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _ink,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 20,
                    runSpacing: 12,
                    children: [
                      for (var i = 1; i < values(r).length; i++)
                        SizedBox(
                          width: 140,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                headings[i],
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _muted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                values(r)[i],
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  action(r),
                ],
              ),
            ),
        ],
      );
    }
    return _panel(
      padding: 0,
      child: LayoutBuilder(
        builder:
            (context, constraints) => ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(
                      _section == 1 ? AppColors.petroleo : _bg,
                    ),
                    headingRowHeight: 56,
                    dividerThickness: .6,
                    border:
                        _section == 1
                            ? const TableBorder(
                              horizontalInside: BorderSide(
                                color: _line,
                                width: .6,
                              ),
                            )
                            : null,
                    dataRowMinHeight: _section == 1 ? 60 : 66,
                    dataRowMaxHeight: _section == 1 ? 76 : 90,
                    columnSpacing: 24,
                    horizontalMargin: 20,
                    columns:
                        headings
                            .map(
                              (h) => DataColumn(
                                label: Text(
                                  h,
                                  style: TextStyle(
                                    color:
                                        _section == 1 ? Colors.white : _muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                    rows:
                        _rows
                            .map(
                              (r) => DataRow(
                                color:
                                    _section == 1
                                        ? WidgetStateProperty.resolveWith(
                                          (states) =>
                                              states.contains(
                                                    WidgetState.hovered,
                                                  )
                                                  ? const Color(0xFFE8F2F5)
                                                  : _rows.indexOf(r).isEven
                                                  ? Colors.white
                                                  : const Color(0xFFF4F8FA),
                                        )
                                        : null,
                                cells: [
                                  for (final v in values(r))
                                    DataCell(
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: _section == 6 ? 300 : 200,
                                        ),
                                        child: Text(
                                          v,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: _ink,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (_section != 6) DataCell(action(r)),
                                ],
                              ),
                            )
                            .toList(),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  String _personName(dynamic id) =>
      _people.where((p) => p['id'] == id).firstOrNull?['nombre']?.toString() ??
      'Sin asignar';

  Widget _pagination() {
    final total = numeroMasiva(_data['total']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '$total registros · Página $_page',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          IconButton(
            tooltip: 'Página anterior',
            onPressed:
                _page > 1
                    ? () {
                      _page--;
                      _load();
                    }
                    : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Página siguiente',
            onPressed:
                _page * 50 < total
                    ? () {
                      _page++;
                      _load();
                    }
                    : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
