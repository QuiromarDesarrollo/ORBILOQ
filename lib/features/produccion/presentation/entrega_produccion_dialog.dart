import '../../../shared/borrador_operativo.dart';
import '../../../shared/widgets/wms_camera_scanner.dart';
import '../../../shared/widgets/wms_empty_state.dart';
import '../../../shared/widgets/wms_scan_field.dart';
import '../../../application/auth_providers.dart';

import 'historial_produccion.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import '../../../domain/qr_prenda.dart';
import '../../../shared/widgets/action_button.dart';
import '../../../shared/widgets/feedback_banner.dart';

import '../../../shared/widgets/wms_dialog.dart';

Future<void> showEntregaProduccionDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const EntregaProduccionDialog());

class EntregaProduccionDialog extends ConsumerWidget {
  const EntregaProduccionDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return WmsDialogShell(
      title: 'Entregas de Producción',
      subtitle: 'Operario: ${ref.watch(nombreOperarioProvider)}',
      showHeaderIcon: true,
      mobileCatalog: true,
      icon: Icons.precision_manufacturing,
      iconColor: AppColors.actionGreen,
      expand: true,
      maxWidth: 1200,
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, c) {
                final tabs = TabBar(
                  isScrollable: false,
                  tabAlignment: TabAlignment.fill,
                  indicator: const UnderlineTabIndicator(
                    borderSide: BorderSide(color: Color(0xFFC4D600), width: 3),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  unselectedLabelColor: Color(0xFF64757C),
                  labelColor: Theme.of(context).colorScheme.primary,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: [
                    for (final tab in [
                      (
                        Icons.qr_code_scanner,
                        mobile ? 'Escanear' : 'Escanear QR',
                      ),
                      (
                        Icons.edit_outlined,
                        mobile ? 'Manual' : 'Entrega manual',
                      ),
                      (Icons.history, 'Historial'),
                    ])
                      Tab(
                        height: 38,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(tab.$1, size: 15),
                              const SizedBox(width: 6),
                              Text(
                                tab.$2,
                                style: TextStyle(fontSize: mobile ? 10 : 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
                return tabs;
              },
            ),
            const SizedBox(height: 8),
            const Expanded(
              child: TabBarView(
                children: [
                  _NuevaEntregaTab(),
                  _EntregaManualTab(),
                  HistorialProduccion(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado de UNA tarjeta de producto/talla dentro de la sesión de entrega
/// (por escaneo o manual). Varias pueden coexistir, cada una con su propio
/// conteo — pero se despachan TODAS JUNTAS bajo un mismo lote.
class _TarjetaEntrega {
  _TarjetaEntrega({required this.itemId})
    : cantidadCtrl = TextEditingController(text: '1');

  final String itemId;
  final TextEditingController cantidadCtrl;
  int conteo = 1;
  bool enviando = false;
  bool enviada = false;
  String? loteId;

  void dispose() => cantidadCtrl.dispose();
}

/// Valida todas las tarjetas pendientes y, si todas pasan, crea UN solo lote
/// con todas ellas (todo o nada — así también funciona la base de datos).
Future<Result<Lote>> _validarYCrearLote({
  required WidgetRef ref,
  required List<_TarjetaEntrega> pendientes,
  required String operario,
}) async {
  for (final t in pendientes) {
    final kardex = ref.read(wmsSnapshotProvider).value?.kardexPorId(t.itemId);
    if (kardex == null) {
      return const Err<Lote>(
        'Una prenda ya no está disponible. Revisa el lote antes de enviarlo.',
      );
    }
    final cantidad = int.tryParse(t.cantidadCtrl.text.trim()) ?? 0;
    if (cantidad <= 0) {
      return Err<Lote>(
        'La cantidad de "${kardex.item.descripcion} (${kardex.item.talla})" debe ser mayor a 0.',
      );
    }
    if (cantidad > kardex.pendienteProduccion) {
      return Err<Lote>(
        'LÍMITE EXCEDIDO en "${kardex.item.descripcion} (${kardex.item.talla})": '
        'solo faltan ${kardex.pendienteProduccion} Uds por producir.',
      );
    }
  }

  final items = [
    for (final t in pendientes)
      ItemCantidad(
        itemId: t.itemId,
        cantidad: int.tryParse(t.cantidadCtrl.text.trim()) ?? 0,
      ),
  ];
  return ref
      .read(wmsRepositoryProvider)
      .crearLote(items: items, operario: operario);
}

// ============================================================ pestaña 1: QR

class _NuevaEntregaTab extends ConsumerStatefulWidget {
  const _NuevaEntregaTab();

  @override
  ConsumerState<_NuevaEntregaTab> createState() => _NuevaEntregaTabState();
}

class _NuevaEntregaTabState extends ConsumerState<_NuevaEntregaTab>
    with AutomaticKeepAliveClientMixin, BorradorOperativo<_NuevaEntregaTab> {
  final _qrCtrl = TextEditingController();
  final _codigoManual = TextEditingController();
  final _manualFocus = FocusNode();
  final _qrFocus = FocusNode();
  final _qrFieldKey = GlobalKey();

  String get _operario => ref.read(nombreOperarioProvider);
  final List<_TarjetaEntrega> _tarjetas = [];
  FeedbackMessage? _msgGeneral;
  bool _despachandoTodo = false;

  @override
  String get borradorProceso => 'produccion-qr';
  @override
  bool get operacionEnCurso => _despachandoTodo;
  @override
  Iterable<TextEditingController> get controlesBorrador => [
    _codigoManual,
    ..._tarjetas.map((t) => t.cantidadCtrl),
  ];
  @override
  Map<String, dynamic> capturarBorrador() => {
    'busqueda': _codigoManual.text,
    'tarjetas': [
      for (final t in _tarjetas.where((t) => !t.enviada))
        {'id': t.itemId, 'cantidad': t.cantidadCtrl.text, 'conteo': t.conteo},
    ],
  };
  @override
  void recuperarBorrador(Map<String, dynamic> datos) {
    _codigoManual.text = datos['busqueda'] as String? ?? '';
    for (final t in _tarjetas) {
      t.dispose();
    }
    _tarjetas.clear();
    for (final d in (datos['tarjetas'] as List? ?? [])) {
      _tarjetas.add(
        _TarjetaEntrega(itemId: d['id'] as String)
          ..cantidadCtrl.text = d['cantidad'] as String
          ..conteo = (d['conteo'] as num).toInt(),
      );
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _qrCtrl.dispose();
    _codigoManual.dispose();
    _manualFocus.dispose();
    _qrFocus.dispose();
    for (final t in _tarjetas) {
      t.dispose();
    }
    super.dispose();
  }

  _TarjetaEntrega? _tarjetaActivaPara(String itemId) {
    for (final t in _tarjetas) {
      if (t.itemId == itemId && !t.enviada) return t;
    }
    return null;
  }

  void _errorGeneral(String texto) {
    setState(() => _msgGeneral = FeedbackMessage.error(texto));
    _qrFocus.requestFocus();
  }

  void _procesarQR(String raw) {
    _qrCtrl.clear();
    if (raw.trim().isEmpty) return;

    final qr = QrPrenda.tryParse(raw);
    if (qr == null) {
      _errorGeneral('QR inválido. Formato esperado: ${QrPrenda.formato}');
      return;
    }
    final kardex = ref
        .read(wmsSnapshotProvider)
        .value
        ?.kardexPorOpCodigo(qr.op, qr.codigo);
    if (kardex == null) {
      _errorGeneral(
        'La prenda no existe en el kardex (OP ${qr.op} · Código ${qr.codigo}).',
      );
      return;
    }

    setState(() {
      _msgGeneral = null;
      final existente = _tarjetaActivaPara(kardex.id);
      if (existente != null) {
        // Siempre sube al tope, para que se vea cuál fue la última escaneada.
        _tarjetas.remove(existente);
        _tarjetas.insert(0, existente);
        if (existente.conteo >= kardex.pendienteProduccion) {
          _msgGeneral = FeedbackMessage.error(
            'LÍMITE ALCANZADO: esta OP ya cumplió la cantidad pedida (${kardex.pendienteProduccion} Uds por entregar).',
          );
        } else {
          existente.conteo++;
          existente.cantidadCtrl.text = '${existente.conteo}';
        }
      } else if (kardex.pendienteProduccion <= 0) {
        _msgGeneral = FeedbackMessage.error(
          'LÍMITE ALCANZADO: esta OP ya cumplió la cantidad pedida (${kardex.pendienteProduccion} Uds por entregar).',
        );
      } else {
        _tarjetas.insert(0, _TarjetaEntrega(itemId: kardex.id));
      }
    });
    _qrFocus.requestFocus();
  }

  FeedbackMessage _leerCamara(String raw) {
    _procesarQR(raw);
    if (_msgGeneral != null) return _msgGeneral!;
    final qr = QrPrenda.tryParse(raw)!;
    final k =
        ref
            .read(wmsSnapshotProvider)
            .value!
            .kardexPorOpCodigo(qr.op, qr.codigo)!;
    final tarjeta = _tarjetaActivaPara(k.id)!;
    return FeedbackMessage.ok(
      'OP ${qr.op} · ${k.item.descripcion} (${k.item.talla}) · ${tarjeta.conteo} Uds en la tarjeta.',
    );
  }

  void _reiniciarConteo(_TarjetaEntrega t) {
    setState(() {
      t.conteo = 0;
      t.cantidadCtrl.text = '1';
    });
    _qrFocus.requestFocus();
  }

  void _quitarTarjeta(_TarjetaEntrega t) {
    setState(() {
      t.dispose();
      _tarjetas.remove(t);
    });
  }

  /// Despacha TODAS las tarjetas activas (no enviadas) como UN solo lote.
  Future<void> _despacharTodo() async {
    final pendientes = _tarjetas.where((t) => !t.enviada).toList();
    if (pendientes.isEmpty || _despachandoTodo || borradorBloqueado) return;
    setState(() {
      _despachandoTodo = true;
      _msgGeneral = null;
      for (final t in pendientes) {
        t.enviando = true;
      }
    });
    if (!await asegurarBorrador()) {
      if (mounted) setState(() => _despachandoTodo = false);
      return;
    }
    final res = await _validarYCrearLote(
      ref: ref,
      pendientes: pendientes,
      operario: _operario,
    );
    if (!mounted) return;
    setState(() {
      _despachandoTodo = false;
      for (final t in pendientes) {
        t.enviando = false;
      }
      switch (res) {
        case Ok(:final value):
          for (final t in pendientes) {
            t.enviada = true;
            t.loteId = value.id;
          }
          _msgGeneral = FeedbackMessage.ok(
            'Lote ${value.id} despachado a bodega (${pendientes.length} producto(s)).',
          );
        case Err(:final message):
          _msgGeneral = FeedbackMessage.error(message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final snapshot = ref.watch(wmsSnapshotProvider).value;
    final pendientes = _tarjetas.where((t) => !t.enviada).length;

    return _EntregaLayout(
      tarjetas: _tarjetas,
      ocupado: _despachandoTodo,
      operario: _operario,
      onDespachar: pendientes == 0 || borradorBloqueado ? null : _despacharTodo,
      estado: estadoBorrador(),
      bloqueado: borradorBloqueado,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msgGeneral != null) ...[
            FeedbackBanner(message: _msgGeneral!),
            const SizedBox(height: 12),
          ],

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F8F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2EBEF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Agregar prendas al lote',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, c) {
                    final camara = FilledButton.icon(
                      onPressed:
                          _despachandoTodo
                              ? null
                              : () => showDialog<void>(
                                context: context,
                                builder:
                                    (_) => WmsCameraScanner(
                                      onRead: _leerCamara,
                                      produccion: true,
                                      onManual:
                                          () => _manualFocus.requestFocus(),
                                    ),
                              ),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Escanear con cámara'),
                            Text(
                              'Apunta al QR de la etiqueta',
                              style: TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    );
                    final lector = WmsScanField(
                      key: _qrFieldKey,
                      mostrarIngresoManual: false,
                      controller: _qrCtrl,
                      focusNode: _qrFocus,
                      autofocus: true,
                      enabled: !_despachandoTodo,
                      onSubmitted: _procesarQR,
                    );
                    if (c.maxWidth < 600) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [camara, const SizedBox(height: 8), lector],
                      );
                    }
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: camara),
                          const SizedBox(width: 12),
                          Expanded(child: lector),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  'O escribe el código manualmente',
                  style: TextStyle(fontSize: 11, color: Color(0xFF57707C)),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codigoManual,
                        focusNode: _manualFocus,
                        enabled: !_despachandoTodo,
                        decoration: const InputDecoration(
                          hintText: 'Código de la etiqueta',
                          isDense: true,
                        ),
                        onSubmitted: (v) {
                          _procesarQR(v);
                          _codigoManual.clear();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed:
                          _despachandoTodo
                              ? null
                              : () {
                                _procesarQR(_codigoManual.text);
                                _codigoManual.clear();
                              },
                      child: const Text('Agregar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_tarjetas.isEmpty)
            Container(
              constraints: const BoxConstraints(minHeight: 210),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFDCE6EC)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xFFE3EDF1),
                    child: Icon(
                      Icons.qr_code_scanner,
                      color: Color(0xFF093E52),
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Escanea una prenda para empezar',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Puedes tener varias tallas u OP abiertas a la vez. Todas se despachan juntas en un mismo lote.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF57707C)),
                  ),
                ],
              ),
            )
          else ...[
            _ResumenEntrega(tarjetas: _tarjetas),
            const SizedBox(height: 10),
            for (final t in _tarjetas) ...[
              _TarjetaWidget(
                tarjeta: t,
                kardex: snapshot?.kardexPorId(t.itemId),
                onRecontear: () => _reiniciarConteo(t),
                onQuitar: () => _quitarTarjeta(t),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

// ==================================================== pestaña 2: manual

class _EntregaManualTab extends ConsumerStatefulWidget {
  const _EntregaManualTab();

  @override
  ConsumerState<_EntregaManualTab> createState() => _EntregaManualTabState();
}

class _EntregaManualTabState extends ConsumerState<_EntregaManualTab>
    with AutomaticKeepAliveClientMixin, BorradorOperativo<_EntregaManualTab> {
  final _opCtrl = TextEditingController();
  String get _operario => ref.read(nombreOperarioProvider);
  List<ItemKardex> _resultados = [];
  final Set<String> _seleccionados = {};
  final List<_TarjetaEntrega> _tarjetas = [];
  String? _errorBusqueda;
  FeedbackMessage? _msgGeneral;
  bool _despachandoTodo = false;

  @override
  String get borradorProceso => 'produccion-manual';
  @override
  bool get operacionEnCurso => _despachandoTodo;
  @override
  Iterable<TextEditingController> get controlesBorrador => [
    _opCtrl,
    ..._tarjetas.map((t) => t.cantidadCtrl),
  ];
  @override
  Map<String, dynamic> capturarBorrador() => {
    'busqueda': _opCtrl.text,
    'tarjetas': [
      for (final t in _tarjetas.where((t) => !t.enviada))
        {'id': t.itemId, 'cantidad': t.cantidadCtrl.text, 'conteo': t.conteo},
    ],
  };
  @override
  void recuperarBorrador(Map<String, dynamic> datos) {
    _opCtrl.text = datos['busqueda'] as String? ?? '';
    for (final t in _tarjetas) {
      t.dispose();
    }
    _tarjetas.clear();
    for (final d in (datos['tarjetas'] as List? ?? [])) {
      _tarjetas.add(
        _TarjetaEntrega(itemId: d['id'] as String)
          ..cantidadCtrl.text = d['cantidad'] as String
          ..conteo = (d['conteo'] as num).toInt(),
      );
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _opCtrl.dispose();
    for (final t in _tarjetas) {
      t.dispose();
    }
    super.dispose();
  }

  _TarjetaEntrega? _tarjetaActivaPara(String itemId) {
    for (final t in _tarjetas) {
      if (t.itemId == itemId && !t.enviada) return t;
    }
    return null;
  }

  void _buscar() {
    final op = _opCtrl.text.trim();
    final kardex =
        ref.read(wmsSnapshotProvider).value?.kardex ?? const <ItemKardex>[];
    setState(() {
      _seleccionados.clear();
      if (op.isEmpty) {
        _resultados = [];
        _errorBusqueda = 'Escribe un número de OP.';
        return;
      }
      _resultados =
          kardex
              .where((k) => k.item.op == op && k.pendienteProduccion > 0)
              .toList();
      _errorBusqueda =
          _resultados.isEmpty
              ? 'No se encontraron tallas con producción pendiente para la OP $op.'
              : null;
    });
  }

  void _agregarSeleccionadas() {
    setState(() {
      for (final id in _seleccionados) {
        if (_tarjetaActivaPara(id) != null) continue;
        _tarjetas.insert(0, _TarjetaEntrega(itemId: id));
      }
      _seleccionados.clear();
      _resultados = [];
      _opCtrl.clear();
    });
  }

  void _reiniciarConteo(_TarjetaEntrega t) {
    setState(() {
      t.conteo = 0;
      t.cantidadCtrl.text = '1';
    });
  }

  void _quitarTarjeta(_TarjetaEntrega t) {
    setState(() {
      t.dispose();
      _tarjetas.remove(t);
    });
  }

  Future<void> _despacharTodo() async {
    final pendientes = _tarjetas.where((t) => !t.enviada).toList();
    if (pendientes.isEmpty || _despachandoTodo || borradorBloqueado) return;
    setState(() {
      _despachandoTodo = true;
      _msgGeneral = null;
      for (final t in pendientes) {
        t.enviando = true;
      }
    });
    if (!await asegurarBorrador()) {
      if (mounted) setState(() => _despachandoTodo = false);
      return;
    }
    final res = await _validarYCrearLote(
      ref: ref,
      pendientes: pendientes,
      operario: _operario,
    );
    if (!mounted) return;
    setState(() {
      _despachandoTodo = false;
      for (final t in pendientes) {
        t.enviando = false;
      }
      switch (res) {
        case Ok(:final value):
          for (final t in pendientes) {
            t.enviada = true;
            t.loteId = value.id;
          }
          _msgGeneral = FeedbackMessage.ok(
            'Lote ${value.id} despachado a bodega (${pendientes.length} producto(s)).',
          );
        case Err(:final message):
          _msgGeneral = FeedbackMessage.error(message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final snapshot = ref.watch(wmsSnapshotProvider).value;
    final pendientes = _tarjetas.where((t) => !t.enviada).length;

    return _EntregaLayout(
      tarjetas: _tarjetas,
      ocupado: _despachandoTodo,
      operario: _operario,
      onDespachar: pendientes == 0 || borradorBloqueado ? null : _despacharTodo,
      estado: estadoBorrador(),
      bloqueado: borradorBloqueado,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msgGeneral != null) ...[
            FeedbackBanner(message: _msgGeneral!),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _opCtrl,
                  keyboardType: TextInputType.number,
                  decoration: wmsInput(
                    MediaQuery.sizeOf(context).width < 600
                        ? 'Número de OP'
                        : 'Agregar al lote por número de OP',
                    icon: Icons.tag,
                  ),
                  enabled: !_despachandoTodo,
                  onSubmitted: (_) => _buscar(),
                ),
              ),
              const SizedBox(width: 10),
              if (MediaQuery.sizeOf(context).width < 600)
                IconButton.filled(
                  tooltip: 'Buscar OP',
                  onPressed: _despachandoTodo ? null : _buscar,
                  icon: const Icon(Icons.search),
                )
              else
                ActionButton(
                  icon: Icons.search,
                  label: 'BUSCAR',
                  color: AppColors.actionGreen,
                  onPressed: _despachandoTodo ? null : _buscar,
                ),
            ],
          ),
          if (_errorBusqueda != null) ...[
            const SizedBox(height: 10),
            FeedbackBanner(message: FeedbackMessage.error(_errorBusqueda!)),
          ],
          if (_resultados.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  for (final r in _resultados)
                    CheckboxListTile(
                      dense: true,
                      value: _seleccionados.contains(r.id),
                      activeColor: AppColors.actionGreen,
                      onChanged:
                          (v) => setState(() {
                            if (v == true) {
                              _seleccionados.add(r.id);
                            } else {
                              _seleccionados.remove(r.id);
                            }
                          }),
                      title: Text(
                        '${r.item.codigo} — ${r.item.descripcion} (Talla ${r.item.talla})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Pendiente por producir: ${r.pendienteProduccion} Uds',
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ActionButton(
                icon: Icons.playlist_add,
                label: 'AGREGAR SELECCIONADAS (${_seleccionados.length})',
                color: AppColors.actionGreen,
                onPressed:
                    _seleccionados.isEmpty ? null : _agregarSeleccionadas,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_tarjetas.isEmpty && _resultados.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: WmsEmptyState(
                  title: 'Busca una orden de producción',
                  message:
                      'Escribe una OP y busca para ver sus tallas pendientes.',
                ),
              ),
            )
          else if (_tarjetas.isNotEmpty) ...[
            _ResumenEntrega(tarjetas: _tarjetas),
            const SizedBox(height: 10),
            for (final t in _tarjetas) ...[
              _TarjetaWidget(
                tarjeta: t,
                kardex: snapshot?.kardexPorId(t.itemId),
                onRecontear: () => _reiniciarConteo(t),
                onQuitar: () => _quitarTarjeta(t),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

// ==================================================== tarjeta (compartida)

class _TarjetaWidget extends StatelessWidget {
  const _TarjetaWidget({
    required this.tarjeta,
    required this.kardex,
    required this.onRecontear,
    required this.onQuitar,
  });

  final _TarjetaEntrega tarjeta;
  final ItemKardex? kardex;
  final VoidCallback onRecontear;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final k = kardex;
    if (k == null) return const SizedBox.shrink();
    final enviada = tarjeta.enviada;

    return AnimatedBuilder(
      animation: tarjeta.cantidadCtrl,
      builder: (context, _) {
        final cantidad = int.tryParse(tarjeta.cantidadCtrl.text) ?? 0;
        final maximo = k.pendienteProduccion;
        final bloqueado = enviada || tarjeta.enviando;
        void cambiar(int valor) {
          tarjeta.cantidadCtrl.text =
              '${valor.clamp(1, maximo > 0 ? maximo : 1)}';
        }

        final progreso =
            k.cantidadPedida > 0
                ? (k.producido / k.cantidadPedida).clamp(0.0, 1.0)
                : 0.0;
        final previsto =
            k.cantidadPedida > 0
                ? ((k.producido + cantidad) / k.cantidadPedida).clamp(0.0, 1.0)
                : 0.0;
        return Container(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 600 ? 12 : 16,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDDE3E5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final title = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'OP ${k.item.op}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD7E8FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Talla ${k.item.talla}',
                              style: const TextStyle(
                                color: Color(0xFF245C96),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        k.item.descripcion,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'OC ${k.item.oc} · ${k.item.cliente}',
                        style: const TextStyle(color: Color(0xFF64757C)),
                      ),
                    ],
                  );
                  final actions = Wrap(
                    spacing: 4,
                    runSpacing: 8,
                    children: [
                      Tooltip(
                        message: 'Recontar',
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF173E4C),
                          ),
                          onPressed: bloqueado ? null : onRecontear,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Recontar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: 'Quitar esta tarjeta',
                        onPressed: bloqueado ? null : onQuitar,
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.alertRed,
                          size: 18,
                        ),
                      ),
                    ],
                  );
                  if (constraints.maxWidth < 560) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        if (!enviada) ...[const SizedBox(height: 12), actions],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Expanded(child: title), if (!enviada) actions],
                  );
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 24,
                runSpacing: 10,
                children: [
                  for (final metric in [
                    (Icons.flag_outlined, 'Meta OP ${k.cantidadPedida}'),
                    (Icons.inventory_2_outlined, 'Entregadas ${k.producido}'),
                    (Icons.rule, 'Límite máximo $maximo'),
                  ])
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          metric.$1,
                          size: 17,
                          color: const Color(0xFF64757C),
                        ),
                        const SizedBox(width: 8),
                        Text(metric.$2),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 6,
                children: [
                  const Text(
                    'Avance de producción',
                    style: TextStyle(color: Color(0xFF64757C)),
                  ),
                  Text(
                    '${k.producido + (enviada ? 0 : cantidad)} de ${k.cantidadPedida} uds · ${((enviada ? progreso : previsto) * 100).round()} %',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    LinearProgressIndicator(
                      value: enviada ? progreso : previsto,
                      color: const Color(0xFFC4D600),
                      backgroundColor: const Color(0xFFF3F5F5),
                      minHeight: 8,
                    ),
                    LinearProgressIndicator(
                      value: progreso,
                      color: const Color(0xFF0C3D50),
                      backgroundColor: Colors.transparent,
                      minHeight: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'La franja lima es lo que sumarás con este envío.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64757C)),
              ),
              if (enviada)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('Enviada · ${tarjeta.loteId}'),
                )
              else ...[
                const Divider(height: 20, color: Color(0xFFDDE3E5)),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final label = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cantidad a enviar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Máximo $maximo unidades',
                          style: const TextStyle(color: Color(0xFF64757C)),
                        ),
                      ],
                    );
                    final allButton = FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC4D600),
                        foregroundColor: const Color(0xFF0C3D50),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed:
                          bloqueado || maximo <= 0
                              ? null
                              : () => cambiar(maximo),
                      child: Text('Todo ($maximo)'),
                    );
                    final controls = Row(
                      children: [
                        IconButton.outlined(
                          tooltip: 'Disminuir cantidad',
                          onPressed:
                              bloqueado || cantidad <= 1
                                  ? null
                                  : () => cambiar(cantidad - 1),
                          icon: const Icon(Icons.remove, size: 18),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: tarjeta.cantidadCtrl,
                            enabled: !bloqueado,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              isDense: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 5,
                              ),
                              errorText:
                                  cantidad > maximo ? 'Máx. $maximo' : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton.outlined(
                          tooltip: 'Aumentar cantidad',
                          onPressed:
                              bloqueado || cantidad >= maximo
                                  ? null
                                  : () => cambiar(cantidad + 1),
                          icon: const Icon(Icons.add, size: 18),
                        ),
                        const SizedBox(width: 6),
                        if (constraints.maxWidth >= 300) allButton,
                      ],
                    );
                    if (constraints.maxWidth < 600) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          label,
                          const SizedBox(height: 12),
                          controls,
                          if (constraints.maxWidth < 300) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: allButton,
                            ),
                          ],
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: label),
                        SizedBox(width: 350, child: controls),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ResumenEntrega extends StatelessWidget {
  const _ResumenEntrega({required this.tarjetas});
  final List<_TarjetaEntrega> tarjetas;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge(tarjetas.map((t) => t.cantidadCtrl)),
    builder: (context, _) {
      final pending = tarjetas.where((t) => !t.enviada).toList();
      final units = pending.fold<int>(
        0,
        (sum, t) => sum + (int.tryParse(t.cantidadCtrl.text) ?? 0),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Arma el lote de lo que producción entrega a logística.',
            style: TextStyle(color: Color(0xFF64757C)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final metric in [
                ('Productos en el lote', pending.length),
                ('Unidades a enviar', units),
              ])
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metric.$1,
                          style: const TextStyle(color: Color(0xFF64757C)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${metric.$2}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      );
    },
  );
}

class _EntregaLayout extends StatelessWidget {
  const _EntregaLayout({
    required this.tarjetas,
    required this.ocupado,
    required this.operario,
    required this.onDespachar,
    required this.child,
    required this.estado,
    required this.bloqueado,
  });
  final Widget estado;
  final bool bloqueado;
  final List<_TarjetaEntrega> tarjetas;
  final bool ocupado;
  final String operario;
  final VoidCallback? onDespachar;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      estado,
      Expanded(
        child: AbsorbPointer(
          absorbing: bloqueado,
          child: SingleChildScrollView(child: child),
        ),
      ),
      const Divider(height: 20),
      AnimatedBuilder(
        animation: Listenable.merge(tarjetas.map((t) => t.cantidadCtrl)),
        builder: (context, _) {
          final pendientes = tarjetas.where((t) => !t.enviada).toList();
          final unidades = pendientes.fold<int>(
            0,
            (total, t) => total + (int.tryParse(t.cantidadCtrl.text) ?? 0),
          );
          final mobile = MediaQuery.sizeOf(context).width < 600;
          final resumen = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${pendientes.length} productos · $unidades unidades',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!mobile)
                Text(
                  pendientes.isEmpty
                      ? 'Agrega al menos una prenda para despachar.'
                      : 'Se registrarán a nombre de $operario.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF57707C),
                  ),
                ),
            ],
          );
          final boton = ActionButton(
            icon: Icons.local_shipping_outlined,
            label: 'Despachar lote a logística',
            color: Theme.of(context).colorScheme.primary,
            busy: ocupado,
            onPressed: ocupado ? null : onDespachar,
          );
          return LayoutBuilder(
            builder:
                (context, c) =>
                    c.maxWidth < 600
                        ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [resumen, const SizedBox(height: 8), boton],
                        )
                        : Row(
                          children: [
                            Expanded(child: resumen),
                            const SizedBox(width: 12),
                            boton,
                          ],
                        ),
          );
        },
      ),
    ],
  );
}
