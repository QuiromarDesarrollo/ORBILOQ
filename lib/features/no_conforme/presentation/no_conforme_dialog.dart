import 'historial_no_conforme.dart';
import '../../../shared/widgets/wms_camera_scanner.dart';
import '../../admin/presentation/catalogo_form_widgets.dart';
import '../../../shared/widgets/wms_scan_field.dart';
import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';
import '../../../application/auth_providers.dart';

import '../../../shared/widgets/responsive_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import '../../../domain/qr_prenda.dart';
import '../../../shared/widgets/action_button.dart';
import '../../../shared/widgets/addable_person_dropdown.dart';
import '../../../shared/widgets/feedback_banner.dart';

import '../../../shared/widgets/wms_dialog.dart';

Future<void> showNoConformeDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const NoConformeDialog());

class NoConformeDialog extends ConsumerWidget {
  const NoConformeDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return WmsDialogShell(
      title: 'Producto no conforme',
      subtitle:
          mobile
              ? 'Reporta: ${ref.watch(nombreOperarioProvider)}'
              : 'Reporta prendas recibidas en bodega que llegaron con defectos.',
      mobileCatalog: true,
      showHeaderIcon: !mobile,
      icon: Icons.report_gmailerrorred,
      iconColor: AppColors.alertRed,
      expand: true,
      maxWidth: 1100,
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TabBar(
                    isScrollable: !mobile,
                    tabAlignment:
                        mobile ? TabAlignment.fill : TabAlignment.start,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    tabs: [
                      for (final tab in [
                        (
                          Icons.qr_code_scanner,
                          mobile ? 'Escanear' : 'Escanear QR',
                        ),
                        (Icons.search, mobile ? 'Buscar' : 'Búsqueda manual'),
                        (Icons.history, 'Historial'),
                      ])
                        Tab(
                          height: 38,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              children: [
                                Icon(tab.$1, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  tab.$2,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!mobile)
                  Chip(
                    avatar: const Icon(Icons.lock_outline, size: 13),
                    label: Text(
                      'Reporta: ${ref.watch(nombreOperarioProvider)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Expanded(
              child: TabBarView(
                children: [_EscanearTab(), _ManualTab(), _HistorialTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una tarjeta = un producto que se va a reportar como no conforme, con su
/// propia cantidad, causal y nota. Independiente de cualquier lote.
class _TarjetaNoConforme {
  _TarjetaNoConforme({required this.itemId})
    : cantidadCtrl = TextEditingController(text: '1'),
      notaCtrl = TextEditingController();

  final String itemId;
  final TextEditingController cantidadCtrl;
  final TextEditingController notaCtrl;
  int conteo = 1;
  String? causalId;
  String? recibidoDeProduccion;
  bool enviando = false;
  bool enviada = false;

  void dispose() {
    cantidadCtrl.dispose();
    notaCtrl.dispose();
  }
}

Future<void> _reportarTodo({
  required WidgetRef ref,
  required List<_TarjetaNoConforme> pendientes,
  required String operario,
  required void Function(void Function()) setStateFn,
  required bool Function() estaMontado,
  required void Function(FeedbackMessage?) setMensaje,
}) async {
  for (final t in pendientes) {
    if (t.causalId == null) {
      setMensaje(
        const FeedbackMessage.error('Hay una tarjeta sin causal seleccionada.'),
      );
      return;
    }
    if (t.recibidoDeProduccion == null ||
        t.recibidoDeProduccion!.trim().isEmpty) {
      setMensaje(
        const FeedbackMessage.error(
          'Hay una tarjeta sin indicar quién de Producción entregó la prenda.',
        ),
      );
      return;
    }
    final cantidad = int.tryParse(t.cantidadCtrl.text.trim()) ?? 0;
    final actual = ref
        .read(wmsSnapshotProvider)
        .valueOrNull
        ?.kardexPorId(t.itemId);
    if (actual == null || cantidad > actual.disponibleParaDespacho) {
      setMensaje(
        const FeedbackMessage.error(
          'La cantidad supera las prendas disponibles sin reservar. Actualiza el kardex.',
        ),
      );
      return;
    }
    if (cantidad <= 0) {
      setMensaje(
        const FeedbackMessage.error('Hay una tarjeta con cantidad inválida.'),
      );
      return;
    }
  }

  setStateFn(() {
    setMensaje(null);
    for (final t in pendientes) {
      t.enviando = true;
    }
  });

  var okCount = 0;
  String? primerError;
  for (final t in pendientes) {
    final cantidad = int.tryParse(t.cantidadCtrl.text.trim()) ?? 0;
    final res = await ref
        .read(wmsRepositoryProvider)
        .registrarNoConforme(
          itemId: t.itemId,
          cantidad: cantidad,
          causalId: t.causalId!,
          operario: operario,
          recibidoDeProduccion: t.recibidoDeProduccion!.trim(),
          nota: t.notaCtrl.text,
        );
    if (!estaMontado()) return;
    switch (res) {
      case Ok():
        okCount++;
        setStateFn(() {
          t.enviando = false;
          t.enviada = true;
        });
      case Err(:final message):
        primerError ??= message;
        setStateFn(() => t.enviando = false);
    }
  }

  setStateFn(() {
    if (primerError != null) {
      setMensaje(
        FeedbackMessage.error(
          okCount == 0
              ? primerError
              : '$okCount reportado(s) — falló al menos uno: $primerError',
        ),
      );
    } else {
      setMensaje(
        FeedbackMessage.ok(
          '$okCount producto(s) reportado(s) como no conforme.',
        ),
      );
    }
  });
}

class _CausalDropdown extends ConsumerWidget {
  const _CausalDropdown({required this.valor, required this.onChanged});

  final String? valor;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final causales = ref.watch(causalesProvider);
    return causales.when(
      loading: () => const WmsLoadingStrip(),
      error:
          (e, _) => Text(
            'No se pudieron cargar las causales: $e',
            style: const TextStyle(color: AppColors.alertRed),
          ),
      data: (lista) {
        final valida = lista.any((c) => c.id == valor);
        if (valor != null && !valida) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) onChanged(null);
          });
        }
        return DropdownButtonFormField<String>(
          isExpanded: true,
          key: ValueKey('${lista.map((c) => c.id).join('|')}::$valor'),
          initialValue: valida ? valor : null,
          decoration: wmsInput(
            'Causal de la no conformidad',
            icon: Icons.report_problem_outlined,
          ),
          items: [
            for (final c in lista)
              DropdownMenuItem(value: c.id, child: Text(c.nombre)),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

// ============================================================ pestaña 1: QR

class _EscanearTab extends ConsumerStatefulWidget {
  const _EscanearTab();

  @override
  ConsumerState<_EscanearTab> createState() => _EscanearTabState();
}

class _EscanearTabState extends ConsumerState<_EscanearTab>
    with AutomaticKeepAliveClientMixin {
  final _qrCtrl = TextEditingController();
  final _manualCtrl = TextEditingController();
  final _qrFocus = FocusNode();
  String get _operario => ref.read(nombreOperarioProvider);
  final List<_TarjetaNoConforme> _tarjetas = [];
  FeedbackMessage? _msgGeneral;
  bool _enviandoTodo = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _qrCtrl.dispose();
    _manualCtrl.dispose();
    _qrFocus.dispose();
    for (final t in _tarjetas) {
      t.dispose();
    }
    super.dispose();
  }

  _TarjetaNoConforme? _tarjetaActivaPara(String itemId) {
    for (final t in _tarjetas) {
      if (t.itemId == itemId && !t.enviada) return t;
    }
    return null;
  }

  void _procesarQR(String raw) {
    _qrCtrl.clear();
    if (raw.trim().isEmpty) return;
    final qr = QrPrenda.tryParse(raw);
    if (qr == null) {
      setState(
        () =>
            _msgGeneral = FeedbackMessage.error(
              'QR inválido. Formato esperado: ${QrPrenda.formato}',
            ),
      );
      return;
    }
    final kardex = ref
        .read(wmsSnapshotProvider)
        .value
        ?.kardexPorOpCodigo(qr.op, qr.codigo);
    if (kardex == null) {
      setState(
        () =>
            _msgGeneral = FeedbackMessage.error(
              'La prenda no existe en el kardex (OP ${qr.op} · Código ${qr.codigo}).',
            ),
      );
      return;
    }
    setState(() {
      _msgGeneral = null;
      final existente = _tarjetaActivaPara(kardex.id);
      if (existente != null) {
        _tarjetas.remove(existente);
        _tarjetas.insert(0, existente);
        existente.conteo++;
        existente.cantidadCtrl.text = '${existente.conteo}';
      } else {
        _tarjetas.insert(0, _TarjetaNoConforme(itemId: kardex.id));
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
    return FeedbackMessage.ok(
      'OP ${qr.op} · ${k.item.descripcion} (${k.item.talla}) · ${_tarjetaActivaPara(k.id)!.conteo} Uds en la tarjeta.',
    );
  }

  void _quitar(_TarjetaNoConforme t) {
    setState(() {
      t.dispose();
      _tarjetas.remove(t);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final snapshot = ref.watch(wmsSnapshotProvider).value;
    final pendientes = _tarjetas.where((t) => !t.enviada).toList();

    return _ReporteLayout(
      tarjetas: _tarjetas,
      operario: _operario,
      accion: ActionButton(
        icon: Icons.report_gmailerrorred,
        label: 'Reportar no conformidad',
        color: AppColors.alertRed,
        busy: _enviandoTodo,
        onPressed:
            pendientes.isEmpty
                ? null
                : () async {
                  setState(() => _enviandoTodo = true);
                  await _reportarTodo(
                    ref: ref,
                    pendientes: pendientes,
                    operario: _operario,
                    setStateFn: setState,
                    estaMontado: () => mounted,
                    setMensaje: (m) => _msgGeneral = m,
                  );
                  if (mounted) setState(() => _enviandoTodo = false);
                },
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msgGeneral != null) ...[
            _ResultadoReporte(message: _msgGeneral!),
            const SizedBox(height: 12),
          ],

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F8F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Buscar la prenda con defecto',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, c) {
                    final camara = FilledButton.icon(
                      onPressed:
                          _enviandoTodo
                              ? null
                              : () => showDialog<void>(
                                context: context,
                                builder:
                                    (_) =>
                                        WmsCameraScanner(onRead: _leerCamara),
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
                      controller: _qrCtrl,
                      focusNode: _qrFocus,
                      autofocus: true,
                      mostrarIngresoManual: false,
                      onSubmitted: _procesarQR,
                      enabled: !_enviandoTodo,
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
                          const SizedBox(width: 10),
                          Expanded(child: lector),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  'O escribe el código de la etiqueta',
                  style: TextStyle(fontSize: 11),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualCtrl,
                        enabled: !_enviandoTodo,
                        decoration: const InputDecoration(
                          hintText: 'Código de la etiqueta',
                          isDense: true,
                        ),
                        onSubmitted: (v) {
                          _procesarQR(v);
                          _manualCtrl.clear();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed:
                          _enviandoTodo
                              ? null
                              : () {
                                _procesarQR(_manualCtrl.text);
                                _manualCtrl.clear();
                              },
                      child: const Text('Agregar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (pendientes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 70, horizontal: 12),
              child: Center(
                child: Text(
                  'No hay prendas por reportar.\nEscanea la etiqueta de la prenda con defecto.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else ...[
            Text(
              'Por reportar · ${pendientes.length} tallas',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            for (final t in pendientes) ...[
              _TarjetaWidget(
                tarjeta: t,
                kardex: snapshot?.kardexPorId(t.itemId),
                onQuitar: () => _quitar(t),
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

class _ManualTab extends ConsumerStatefulWidget {
  const _ManualTab();

  @override
  ConsumerState<_ManualTab> createState() => _ManualTabState();
}

class _ManualTabState extends ConsumerState<_ManualTab>
    with AutomaticKeepAliveClientMixin {
  final _opCtrl = TextEditingController();
  String get _operario => ref.read(nombreOperarioProvider);
  List<ItemKardex> _resultados = [];
  final Set<String> _seleccionados = {};
  final List<_TarjetaNoConforme> _tarjetas = [];
  String? _errorBusqueda;
  FeedbackMessage? _msgGeneral;
  bool _enviandoTodo = false;

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

  _TarjetaNoConforme? _tarjetaActivaPara(String itemId) {
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
      // Solo tiene sentido reportar productos que YA están recibidos en Bodega
      // (así la resta de "Bodega" que hace el PNC siempre es segura).
      _resultados =
          kardex
              .where((k) => k.item.op == op && k.disponibleParaDespacho > 0)
              .toList();
      _errorBusqueda =
          _resultados.isEmpty
              ? 'No se encontraron tallas con unidades disponibles sin reservar en Bodega para la OP $op.'
              : null;
    });
  }

  void _agregarSeleccionadas() {
    setState(() {
      for (final id in _seleccionados) {
        if (_tarjetaActivaPara(id) != null) continue;
        _tarjetas.insert(0, _TarjetaNoConforme(itemId: id));
      }
      _seleccionados.clear();
      _resultados = [];
      _opCtrl.clear();
    });
  }

  void _quitar(_TarjetaNoConforme t) {
    setState(() {
      t.dispose();
      _tarjetas.remove(t);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final snapshot = ref.watch(wmsSnapshotProvider).value;
    final pendientes = _tarjetas.where((t) => !t.enviada).toList();

    return _ReporteLayout(
      tarjetas: _tarjetas,
      operario: _operario,
      accion: ActionButton(
        icon: Icons.report_gmailerrorred,
        label: 'Reportar no conformidad',
        color: AppColors.alertRed,
        busy: _enviandoTodo,
        onPressed:
            pendientes.isEmpty
                ? null
                : () async {
                  setState(() => _enviandoTodo = true);
                  await _reportarTodo(
                    ref: ref,
                    pendientes: pendientes,
                    operario: _operario,
                    setStateFn: setState,
                    estaMontado: () => mounted,
                    setMensaje: (m) => _msgGeneral = m,
                  );
                  if (mounted) setState(() => _enviandoTodo = false);
                },
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msgGeneral != null) ...[
            _ResultadoReporte(message: _msgGeneral!),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _opCtrl,
                  keyboardType: TextInputType.number,
                  decoration: wmsInput('Número de OP', icon: Icons.tag),
                  onSubmitted: (_) => _buscar(),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                tooltip: 'Buscar OP',
                icon: const Icon(Icons.search),
                onPressed: _buscar,
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
                      activeColor: AppColors.alertRed,
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
                        'Disponibles sin reservar: ${r.disponibleParaDespacho} Uds',
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
                label: 'Agregar al reporte (${_seleccionados.length})',
                color: AppColors.primaryNavy,
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
                child: Text(
                  'Escribe una OP y busca para ver sus tallas entregadas.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else if (_tarjetas.isNotEmpty) ...[
            Text(
              'Por reportar · ${pendientes.length} tallas',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            for (final t in pendientes) ...[
              _TarjetaWidget(
                tarjeta: t,
                kardex: snapshot?.kardexPorId(t.itemId),
                onQuitar: () => _quitar(t),
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

class _TarjetaWidget extends StatefulWidget {
  const _TarjetaWidget({
    required this.tarjeta,
    required this.kardex,
    required this.onQuitar,
  });

  final _TarjetaNoConforme tarjeta;
  final ItemKardex? kardex;
  final VoidCallback onQuitar;

  @override
  State<_TarjetaWidget> createState() => _TarjetaWidgetState();
}

class _TarjetaWidgetState extends State<_TarjetaWidget> {
  @override
  Widget build(BuildContext context) {
    final k = widget.kardex;
    final t = widget.tarjeta;
    if (k == null) return const SizedBox.shrink();
    final enviada = t.enviada;

    return Card(
      color: enviada ? Colors.grey.shade100 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFDCE6EC)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveRow(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OP: ${k.item.op} - ${k.item.descripcion} (${k.item.talla})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color:
                              enviada
                                  ? Colors.grey.shade600
                                  : AppColors.primaryNavy,
                        ),
                      ),
                      Text(
                        'No. OC: ${k.item.oc} | Disponibles sin reservar: ${k.disponibleParaDespacho} Uds',
                        style: TextStyle(
                          color: enviada ? Colors.grey.shade600 : null,
                        ),
                      ),
                    ],
                  ),
                ),
                if (enviada)
                  const Icon(Icons.check_circle, color: AppColors.actionGreen)
                else if (t.enviando)
                  const SizedBox(
                    width: 48,
                    height: 30,
                    child: WmsLoader(strokeWidth: 2),
                  )
                else
                  IconButton(
                    tooltip: 'Quitar esta tarjeta',
                    icon: const Icon(Icons.close, color: AppColors.alertRed),
                    onPressed: widget.onQuitar,
                  ),
              ],
            ),
            const Divider(),
            if (!enviada) ...[
              CatalogoCampos(
                children: [
                  _CausalDropdown(
                    valor: t.causalId,
                    onChanged: (v) => setState(() => t.causalId = v),
                  ),
                  AddablePersonDropdown(
                    label: 'Quién de Producción entregó la prenda *',
                    valor: t.recibidoDeProduccion,
                    onChanged:
                        (v) => setState(() => t.recibidoDeProduccion = v),
                    itemsProvider: personalProduccionProvider,
                    onAgregar:
                        (ref, nombre) => ref
                            .read(wmsRepositoryProvider)
                            .agregarPersonalProduccion(nombre),
                    tituloDialogo: 'Agregar persona de Producción',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ResponsiveRow(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Cantidad no conforme · máx. ${k.disponibleParaDespacho}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            IconButton.outlined(
                              tooltip: 'Disminuir cantidad',
                              onPressed:
                                  t.enviando
                                      ? null
                                      : () {
                                        final n =
                                            int.tryParse(t.cantidadCtrl.text) ??
                                            1;
                                        if (n > 1) {
                                          t.cantidadCtrl.text = '${n - 1}';
                                        }
                                      },
                              icon: const Icon(Icons.remove, size: 16),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: TextField(
                                controller: t.cantidadCtrl,
                                enabled: !t.enviando,
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            IconButton.outlined(
                              tooltip: 'Aumentar cantidad',
                              onPressed:
                                  t.enviando
                                      ? null
                                      : () {
                                        final n =
                                            int.tryParse(t.cantidadCtrl.text) ??
                                            0;
                                        if (n < k.disponibleParaDespacho) {
                                          t.cantidadCtrl.text = '${n + 1}';
                                        }
                                      },
                              icon: const Icon(Icons.add, size: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: t.notaCtrl,
                      decoration: wmsInput(
                        'Nota (opcional)',
                        icon: Icons.note_outlined,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedBuilder(
                animation: t.cantidadCtrl,
                builder: (context, _) {
                  final cantidad = int.tryParse(t.cantidadCtrl.text) ?? 0;
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F7F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      cantidad > k.disponibleParaDespacho
                          ? 'La cantidad supera las unidades disponibles sin reservar.'
                          : 'Después del reporte: ${k.disponibleParaDespacho - cantidad} disponibles sin reservar en bodega · ${k.pendienteReproceso + cantidad} no conformes.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF57707C),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================================================== pestaña 3: historial

class _HistorialTab extends ConsumerStatefulWidget {
  const _HistorialTab();

  @override
  ConsumerState<_HistorialTab> createState() => _HistorialTabState();
}

class _HistorialTabState extends ConsumerState<_HistorialTab> {
  late Future<List<Devolucion>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = ref.read(wmsRepositoryProvider).cargarDevoluciones();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Devolucion>>(
      future: _futuro,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const WmsLoadingPanel();
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('No se pudo cargar el historial: ${snapshot.error}'),
          );
        }
        final devoluciones = snapshot.data ?? const [];
        return HistorialNoConforme(devoluciones: devoluciones);
      },
    );
  }
}

class _ReporteLayout extends StatelessWidget {
  const _ReporteLayout({
    required this.tarjetas,
    required this.operario,
    required this.accion,
    required this.child,
  });
  final List<_TarjetaNoConforme> tarjetas;
  final String operario;
  final Widget accion, child;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(child: SingleChildScrollView(child: child)),
      if (tarjetas.any((t) => !t.enviada)) ...[
        const Divider(height: 20),
        AnimatedBuilder(
          animation: Listenable.merge(tarjetas.map((t) => t.cantidadCtrl)),
          builder: (context, _) {
            final pendientes = tarjetas.where((t) => !t.enviada).toList();
            final cantidad = pendientes.fold<int>(
              0,
              (s, t) => s + (int.tryParse(t.cantidadCtrl.text) ?? 0),
            );
            final resumen = Text(
              '${pendientes.length} tallas · $cantidad unidades no conformes\nSe registra a nombre de $operario.',
              style: const TextStyle(fontSize: 11),
            );
            return LayoutBuilder(
              builder:
                  (context, c) =>
                      c.maxWidth < 600
                          ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              resumen,
                              const SizedBox(height: 8),
                              accion,
                            ],
                          )
                          : Row(
                            children: [
                              Expanded(child: resumen),
                              const SizedBox(width: 12),
                              accion,
                            ],
                          ),
            );
          },
        ),
      ],
    ],
  );
}

class _ResultadoReporte extends StatelessWidget {
  const _ResultadoReporte({required this.message});
  final FeedbackMessage message;
  @override
  Widget build(BuildContext context) {
    final color =
        message.isError ? const Color(0xFFB42318) : const Color(0xFF299D64);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        border: Border.all(color: color.withValues(alpha: .25)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            message.isError ? Icons.error_outline : Icons.check_circle,
            color: color,
          ),
          Text(
            message.isError ? 'Revisa el reporte' : 'Reporte guardado',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Text(message.text, style: const TextStyle(fontSize: 12)),
          if (!message.isError)
            TextButton(
              onPressed: () => DefaultTabController.of(context).animateTo(2),
              child: const Text('Ver en historial'),
            ),
        ],
      ),
    );
  }
}
