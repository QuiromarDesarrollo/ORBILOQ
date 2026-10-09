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

import '../../../shared/widgets/status_chip.dart';
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
      subtitle:
          mobile
              ? 'Operario: ${ref.watch(nombreOperarioProvider)}'
              : 'Arma el lote de lo que producción entrega a logística.',
      showHeaderIcon: !mobile,
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
                  isScrollable: !mobile,
                  tabAlignment: mobile ? TabAlignment.fill : TabAlignment.start,
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
                final actor = Consumer(
                  builder:
                      (context, ref, _) => Chip(
                        avatar: const Icon(Icons.person_outline, size: 14),
                        label: Text(
                          'Operario: ${ref.watch(nombreOperarioProvider)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        side: BorderSide.none,
                      ),
                );
                if (mobile) return tabs;
                return c.maxWidth < 650
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        tabs,
                        Align(alignment: Alignment.centerRight, child: actor),
                      ],
                    )
                    : Row(
                      children: [
                        Expanded(child: tabs),
                        const SizedBox(width: 10),
                        actor,
                      ],
                    );
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
    if (kardex == null) continue;
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
    with AutomaticKeepAliveClientMixin {
  final _qrCtrl = TextEditingController();
  final _codigoManual = TextEditingController();
  final _manualFocus = FocusNode();
  final _qrFocus = FocusNode();

  String get _operario => ref.read(nombreOperarioProvider);
  final List<_TarjetaEntrega> _tarjetas = [];
  FeedbackMessage? _msgGeneral;
  bool _despachandoTodo = false;

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
    if (pendientes.isEmpty) return;
    setState(() {
      _despachandoTodo = true;
      _msgGeneral = null;
      for (final t in pendientes) {
        t.enviando = true;
      }
    });
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
      onDespachar: pendientes == 0 ? null : _despacharTodo,
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
            Text(
              'Lote para logística · $pendientes productos',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
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
    with AutomaticKeepAliveClientMixin {
  final _opCtrl = TextEditingController();
  String get _operario => ref.read(nombreOperarioProvider);
  List<ItemKardex> _resultados = [];
  final Set<String> _seleccionados = {};
  final List<_TarjetaEntrega> _tarjetas = [];
  String? _errorBusqueda;
  FeedbackMessage? _msgGeneral;
  bool _despachandoTodo = false;

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
    if (pendientes.isEmpty) return;
    setState(() {
      _despachandoTodo = true;
      _msgGeneral = null;
      for (final t in pendientes) {
        t.enviando = true;
      }
    });
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
      onDespachar: pendientes == 0 ? null : _despacharTodo,
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
                  color: AppColors.primaryNavy,
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
            Text(
              'Lote para logística · $pendientes productos',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
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
        final metricas = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                for (final texto in [
                  'Meta OP ${k.cantidadPedida}',
                  'Entregadas ${k.producido}',
                  'Límite máximo $maximo',
                  'Avance ${(progreso * 100).toStringAsFixed(0)} %',
                ])
                  Text(
                    texto,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF425F6D),
                    ),
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
                    minHeight: 7,
                    color: const Color(0xFFCBE7D7),
                    backgroundColor: const Color(0xFFE3EDF1),
                  ),
                  LinearProgressIndicator(
                    value: progreso,
                    minHeight: 7,
                    color: const Color(0xFF62AF86),
                    backgroundColor: Colors.transparent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'La franja clara muestra lo que sumarás con este envío.',
              style: TextStyle(fontSize: 10, color: Color(0xFF57707C)),
            ),
          ],
        );
        final cantidadWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cantidad a enviar · máx. $maximo',
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                IconButton.outlined(
                  tooltip: 'Disminuir cantidad',
                  onPressed:
                      bloqueado || cantidad <= 1
                          ? null
                          : () => cambiar(cantidad - 1),
                  icon: const Icon(Icons.remove, size: 16),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: tarjeta.cantidadCtrl,
                    enabled: !bloqueado,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 5,
                      ),
                      errorText: cantidad > maximo ? 'Máx. $maximo' : null,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton.outlined(
                  tooltip: 'Aumentar cantidad',
                  onPressed:
                      bloqueado || cantidad >= maximo
                          ? null
                          : () => cambiar(cantidad + 1),
                  icon: const Icon(Icons.add, size: 16),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed:
                      bloqueado || maximo <= 0 ? null : () => cambiar(maximo),
                  child: Text(
                    'Todo ($maximo)',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        );
        if (MediaQuery.sizeOf(context).width < 600) {
          final botonStyle = IconButton.styleFrom(
            minimumSize: const Size(32, 36),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDCE6EC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 3,
                            children: [
                              Text(
                                'OP ${k.item.op}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Talla ${k.item.talla}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                          Text(
                            k.item.descripcion,
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'OC ${k.item.oc} · ${k.item.cliente}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF57707C),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!enviada) ...[
                      IconButton.outlined(
                        tooltip: 'Recontar',
                        style: botonStyle,
                        onPressed: bloqueado ? null : onRecontear,
                        icon: const Icon(Icons.refresh, size: 15),
                      ),
                      IconButton(
                        tooltip: 'Quitar esta tarjeta',
                        style: botonStyle,
                        onPressed: bloqueado ? null : onQuitar,
                        icon: const Icon(
                          Icons.close,
                          size: 15,
                          color: AppColors.alertRed,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 7),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  children: [
                    Text(
                      'Entregadas ${k.producido} de ${k.cantidadPedida}',
                      style: const TextStyle(fontSize: 10),
                    ),
                    Text(
                      'Límite $maximo · ${(progreso * 100).toStringAsFixed(0)} %',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF57707C),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Stack(
                  children: [
                    LinearProgressIndicator(
                      value: enviada ? progreso : previsto,
                      minHeight: 5,
                      color: const Color(0xFFCBE7D7),
                      backgroundColor: const Color(0xFFE3EDF1),
                    ),
                    LinearProgressIndicator(
                      value: progreso,
                      minHeight: 5,
                      color: const Color(0xFF62AF86),
                      backgroundColor: Colors.transparent,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (enviada)
                  Text(
                    'Enviada · ${tarjeta.loteId}',
                    style: const TextStyle(fontSize: 11),
                  )
                else
                  Row(
                    children: [
                      const Text('Enviar', style: TextStyle(fontSize: 11)),
                      const Spacer(),
                      IconButton.outlined(
                        tooltip: 'Disminuir cantidad',
                        style: botonStyle,
                        onPressed:
                            bloqueado || cantidad <= 1
                                ? null
                                : () => cambiar(cantidad - 1),
                        icon: const Icon(Icons.remove, size: 14),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 45,
                        child: TextField(
                          controller: tarjeta.cantidadCtrl,
                          enabled: !bloqueado,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 9,
                              horizontal: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton.outlined(
                        tooltip: 'Aumentar cantidad',
                        style: botonStyle,
                        onPressed:
                            bloqueado || cantidad >= maximo
                                ? null
                                : () => cambiar(cantidad + 1),
                        icon: const Icon(Icons.add, size: 14),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(36, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        onPressed:
                            bloqueado || maximo <= 0
                                ? null
                                : () => cambiar(maximo),
                        child: const Text(
                          'Todo',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                if (!enviada && cantidad > maximo)
                  Text(
                    'La cantidad supera el máximo de $maximo.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.alertRed,
                    ),
                  ),
              ],
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: enviada ? const Color(0xFFF5F8F9) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDCE6EC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, c) {
                  final titulo = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'OP ${k.item.op} · ${k.item.descripcion}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          StatusChip(
                            label: 'Talla ${k.item.talla}',
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          if (enviada)
                            StatusChip(
                              label: 'Enviada · ${tarjeta.loteId}',
                              color: AppColors.actionGreen,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'OC ${k.item.oc} · ${k.item.cliente}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF57707C),
                        ),
                      ),
                    ],
                  );
                  final acciones = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: bloqueado ? null : onRecontear,
                        icon: const Icon(Icons.refresh, size: 15),
                        label: const Text('Recontar'),
                      ),
                      IconButton(
                        tooltip: 'Quitar esta tarjeta',
                        onPressed: bloqueado ? null : onQuitar,
                        icon: const Icon(
                          Icons.close,
                          size: 17,
                          color: AppColors.alertRed,
                        ),
                      ),
                    ],
                  );
                  if (c.maxWidth < 550) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        titulo,
                        if (!enviada)
                          Align(
                            alignment: Alignment.centerRight,
                            child: acciones,
                          ),
                      ],
                    );
                  }
                  return Row(
                    children: [Expanded(child: titulo), if (!enviada) acciones],
                  );
                },
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) {
                  if (enviada) return metricas;
                  if (c.maxWidth < 600) {
                    return Column(
                      children: [
                        metricas,
                        const SizedBox(height: 12),
                        cantidadWidget,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: metricas),
                      const SizedBox(width: 20),
                      SizedBox(width: 255, child: cantidadWidget),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EntregaLayout extends StatelessWidget {
  const _EntregaLayout({
    required this.tarjetas,
    required this.ocupado,
    required this.operario,
    required this.onDespachar,
    required this.child,
  });
  final List<_TarjetaEntrega> tarjetas;
  final bool ocupado;
  final String operario;
  final VoidCallback? onDespachar;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(child: SingleChildScrollView(child: child)),
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
