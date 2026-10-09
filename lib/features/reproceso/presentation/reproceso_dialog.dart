import '../../../shared/widgets/wms_scan_field.dart';
import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';
import '../../../application/auth_providers.dart';
import '../../../shared/widgets/wms_camera_scanner.dart';
import 'historial_liberaciones.dart';
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

Future<void> showReprocesoDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const ReprocesoDialog());

class ReprocesoDialog extends ConsumerWidget {
  const ReprocesoDialog({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nombre = ref.watch(nombreOperarioProvider);
    final pendientes =
        ref
            .watch(wmsSnapshotProvider)
            .value
            ?.kardex
            .where((k) => k.pendienteReproceso > 0)
            .length ??
        0;
    return WmsDialogShell(
      title: 'Productos no conformes',
      subtitle:
          MediaQuery.sizeOf(context).width < 600
              ? 'Libera: $nombre'
              : 'Libera a logística las prendas que producción ya corrigió. · Libera: $nombre',
      icon: Icons.report_gmailerrorred,
      iconColor: AppColors.alertRed,
      mobileCatalog: true,
      expand: true,
      maxWidth: 1100,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              labelColor: AppColors.primaryNavy,
              unselectedLabelColor: Colors.blueGrey,
              indicatorColor: AppColors.primaryNavy,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                Tab(text: 'Por liberar · $pendientes'),
                const Tab(text: 'Historial'),
              ],
            ),
            const SizedBox(height: 12),
            const Expanded(
              child: TabBarView(children: [_ListaTab(), _HistorialTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================ pestaña 1

class _ListaTab extends ConsumerStatefulWidget {
  const _ListaTab();

  @override
  ConsumerState<_ListaTab> createState() => _ListaTabState();
}

class _ListaTabState extends ConsumerState<_ListaTab> {
  final _opCtrl = TextEditingController();
  final _qrCtrl = TextEditingController();
  final Map<String, TextEditingController> _cantidadCtrls = {};
  final Map<String, bool> _liberando = {};
  final Map<String, String?> _recibidoPorLogistica = {};
  String get _operario => ref.read(nombreOperarioProvider);
  String _filtroOp = '';
  FeedbackMessage? _msgGeneral;
  late Future<Map<String, List<String>>> _motivosFuturo;

  @override
  void initState() {
    super.initState();
    _motivosFuturo = _cargarMotivos();
  }

  /// Agrupa los motivos (causales) ya reportados por producto, para
  /// mostrarlos en cada tarjeta. Una misma prenda puede tener más de un
  /// motivo si se reportó no conforme más de una vez por razones distintas.
  Future<Map<String, List<String>>> _cargarMotivos() async {
    final devoluciones =
        await ref.read(wmsRepositoryProvider).cargarDevoluciones();
    final mapa = <String, List<String>>{};
    for (final d in devoluciones) {
      final lista = mapa.putIfAbsent(d.item.id, () => []);
      if (!lista.contains(d.causal)) lista.add(d.causal);
    }
    return mapa;
  }

  @override
  void dispose() {
    _opCtrl.dispose();
    _qrCtrl.dispose();
    for (final c in _cantidadCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrlPara(ItemKardex k) => _cantidadCtrls.putIfAbsent(
    k.id,
    () => TextEditingController(text: '${k.pendienteReproceso}'),
  );

  void _buscarOp() {
    final raw = _opCtrl.text.trim();
    if (QrPrenda.tryParse(raw) != null) {
      _procesarQR(raw);
    } else {
      setState(() => _filtroOp = raw);
    }
  }

  Future<void> _camara() => showDialog<void>(
    context: context,
    builder:
        (_) => WmsCameraScanner(
          onRead: (raw) async {
            _procesarQR(raw);
            return _msgGeneral ??
                FeedbackMessage.ok('OP $_filtroOp · Prenda localizada.');
          },
        ),
  );

  Future<void> _lector() => showDialog<void>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: const Text('Escanear con lector'),
          content: SizedBox(
            width: 360,
            child: WmsScanField(
              controller: _qrCtrl,
              autofocus: true,
              mostrarIngresoManual: false,
              onSubmitted: (raw) {
                _procesarQR(raw);
                Navigator.pop(ctx);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
  );

  void _limpiarFiltro() => setState(() {
    _filtroOp = '';
    _opCtrl.clear();
  });

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
              'La prenda no existe en el kardex.',
            ),
      );
      return;
    }
    if (kardex.pendienteReproceso <= 0) {
      setState(
        () =>
            _msgGeneral = FeedbackMessage.error(
              '${kardex.item.descripcion} (${kardex.item.talla}) no tiene unidades no conformes.',
            ),
      );
      return;
    }
    setState(() {
      _msgGeneral = null;
      _filtroOp = kardex.item.op;
      _opCtrl.text = kardex.item.op;
    });
  }

  Future<void> _liberar(ItemKardex k) async {
    final ctrl = _ctrlPara(k);
    final cantidad = int.tryParse(ctrl.text.trim()) ?? 0;
    if (cantidad <= 0) {
      setState(
        () =>
            _msgGeneral = const FeedbackMessage.error(
              'Ingresa una cantidad mayor a 0.',
            ),
      );
      return;
    }
    if (cantidad > k.pendienteReproceso) {
      setState(
        () =>
            _msgGeneral = FeedbackMessage.error(
              'LÍMITE EXCEDIDO: solo hay ${k.pendienteReproceso} Uds pendientes por reprocesar.',
            ),
      );
      return;
    }
    final recibidoPor = _recibidoPorLogistica[k.id]?.trim() ?? '';
    if (recibidoPor.isEmpty) {
      setState(
        () =>
            _msgGeneral = const FeedbackMessage.error(
              'Indica quién de Logística recibió esta prenda antes de liberar.',
            ),
      );
      return;
    }

    setState(() {
      _msgGeneral = null;
      _liberando[k.id] = true;
    });
    final res = await ref
        .read(wmsRepositoryProvider)
        .liberarNoConforme(
          itemId: k.id,
          cantidad: cantidad,
          operario: _operario,
          recibidoPorLogistica: recibidoPor,
        );
    if (!mounted) return;
    setState(() {
      _liberando[k.id] = false;
      switch (res) {
        case Ok():
          ref.invalidate(liberacionesProduccionProvider);
          _msgGeneral = FeedbackMessage.ok(
            '${cantidad}u de ${k.item.descripcion} (${k.item.talla}) liberadas — vuelven a Entregado a Logística.',
          );
          _cantidadCtrls.remove(k.id)?.dispose();
          _recibidoPorLogistica.remove(k.id);
        case Err(:final message):
          _msgGeneral = FeedbackMessage.error(message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final datos = ref.watch(wmsSnapshotProvider);
    if (datos.isLoading && !datos.hasValue) return const WmsLoadingPanel();
    if (datos.hasError && !datos.hasValue) {
      return Center(
        child: TextButton(
          onPressed: () => ref.invalidate(wmsSnapshotProvider),
          child: const Text('No se pudo cargar · Reintentar'),
        ),
      );
    }
    final kardex = datos.value?.kardex ?? const <ItemKardex>[];
    final noConformes =
        kardex.where((k) => k.pendienteReproceso > 0).toList()
          ..sort((a, b) => a.item.op.compareTo(b.item.op));
    final filtro = _filtroOp.toLowerCase();
    final visibles =
        noConformes
            .where(
              (k) =>
                  filtro.isEmpty ||
                  k.item.op.toLowerCase().contains(filtro) ||
                  k.item.codigo.toLowerCase().contains(filtro),
            )
            .toList();
    final mobile = MediaQuery.sizeOf(context).width < 600;
    final busy = _liberando.values.any((v) => v);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_msgGeneral != null) FeedbackBanner(message: _msgGeneral!),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _opCtrl,
                decoration: InputDecoration(
                  hintText:
                      mobile
                          ? 'OP o código'
                          : 'Buscar por OP o código de etiqueta',
                  isDense: true,
                  prefixIcon: const Icon(Icons.tag, size: 16),
                  suffixIcon:
                      _filtroOp.isEmpty
                          ? null
                          : IconButton(
                            tooltip: 'Quitar filtro',
                            onPressed: _limpiarFiltro,
                            icon: const Icon(Icons.close, size: 16),
                          ),
                ),
                onChanged: (_) => _buscarOp(),
                onSubmitted: (_) => _buscarOp(),
              ),
            ),
            if (!mobile) ...[
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _buscarOp, child: const Text('Buscar')),
            ],
            const SizedBox(width: 6),
            IconButton.filled(
              tooltip: 'Cámara',
              onPressed: busy ? null : _camara,
              icon: const Icon(Icons.photo_camera_outlined, size: 20),
            ),
            const SizedBox(width: 4),
            IconButton.outlined(
              tooltip: 'Lector',
              onPressed: busy ? null : _lector,
              icon: const Icon(Icons.qr_code_scanner, size: 20),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            'Por liberar · ${visibles.length} tallas',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        Expanded(
          child:
              visibles.isEmpty
                  ? const Center(
                    child: Text(
                      'No hay productos no conformes con este filtro.',
                      textAlign: TextAlign.center,
                    ),
                  )
                  : FutureBuilder<Map<String, List<String>>>(
                    future: _motivosFuturo,
                    builder:
                        (context, motivos) => ListView.builder(
                          itemCount: visibles.length,
                          itemBuilder: (_, i) {
                            final k = visibles[i];
                            return _TarjetaNoConforme(
                              kardex: k,
                              cantidadCtrl: _ctrlPara(k),
                              liberando: busy,
                              motivos: motivos.data?[k.id] ?? const [],
                              recibidoPorLogistica: _recibidoPorLogistica[k.id],
                              onRecibidoPorLogisticaChanged:
                                  (v) => setState(
                                    () => _recibidoPorLogistica[k.id] = v,
                                  ),
                              onLiberar: () => _liberar(k),
                              mostrarAccion: visibles.length > 1,
                            );
                          },
                        ),
                  ),
        ),
        if (visibles.length == 1) ...[
          const Divider(height: 20),
          AnimatedBuilder(
            animation: _ctrlPara(visibles.single),
            builder: (context, _) {
              final k = visibles.single;
              final resumen = Text(
                '${_ctrlPara(k).text} unidades por liberar'
                '${_recibidoPorLogistica[k.id] == null ? '' : ' · Las recibe ${_recibidoPorLogistica[k.id]}'}',
                style: const TextStyle(fontSize: 12),
                textAlign: mobile ? TextAlign.center : TextAlign.start,
              );
              final boton = ActionButton(
                icon: Icons.check_circle_outline,
                label: 'Liberar a logística',
                color: const Color(0xFF1B7048),
                busy: busy,
                onPressed: () => _liberar(k),
              );
              return mobile
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
                  );
            },
          ),
        ],
      ],
    );
  }
}

class _TarjetaNoConforme extends StatelessWidget {
  const _TarjetaNoConforme({
    required this.kardex,
    required this.cantidadCtrl,
    required this.liberando,
    required this.motivos,
    required this.recibidoPorLogistica,
    required this.onRecibidoPorLogisticaChanged,
    required this.onLiberar,
    required this.mostrarAccion,
  });
  final ItemKardex kardex;
  final TextEditingController cantidadCtrl;
  final bool liberando, mostrarAccion;
  final List<String> motivos;
  final String? recibidoPorLogistica;
  final ValueChanged<String?> onRecibidoPorLogisticaChanged;
  final VoidCallback onLiberar;

  @override
  Widget build(BuildContext context) {
    final k = kardex;
    void ajustar(int delta) {
      cantidadCtrl.text =
          ((int.tryParse(cantidadCtrl.text) ?? 0) + delta)
              .clamp(1, k.pendienteReproceso)
              .toString();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDCE6EC)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final mobile = c.maxWidth < 600;
          final persona = AddablePersonDropdown(
            label: 'Quién de logística la recibe *',
            valor: recibidoPorLogistica,
            onChanged: liberando ? (_) {} : onRecibidoPorLogisticaChanged,
            itemsProvider: personalLogisticaProvider,
            onAgregar:
                (ref, nombre) => ref
                    .read(wmsRepositoryProvider)
                    .agregarPersonalLogistica(nombre),
            tituloDialogo: 'Agregar persona de Logística',
          );
          final cantidad = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cantidad a liberar · máx. ${k.pendienteReproceso}',
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  IconButton.outlined(
                    tooltip: 'Reducir cantidad',
                    onPressed: liberando ? null : () => ajustar(-1),
                    icon: const Icon(Icons.remove, size: 16),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: cantidadCtrl,
                      enabled: !liberando,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.outlined(
                    tooltip: 'Aumentar cantidad',
                    onPressed: liberando ? null : () => ajustar(1),
                    icon: const Icon(Icons.add, size: 16),
                  ),
                  TextButton(
                    onPressed:
                        liberando
                            ? null
                            : () =>
                                cantidadCtrl.text = '${k.pendienteReproceso}',
                    child: const Text('Todo'),
                  ),
                ],
              ),
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'OP ${k.item.op}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Talla ${k.item.talla}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(k.item.descripcion),
              Text(
                '${k.item.oc} · ${k.item.cliente}',
                style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
              ),
              const SizedBox(height: 6),
              Text(
                motivos.isEmpty
                    ? 'Causal: sin registrar'
                    : 'Causal: ${motivos.join(', ')}',
                style: const TextStyle(fontSize: 11, color: AppColors.alertRed),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final dato in [
                    (k.producido, 'en logística', const Color(0xFF1B7048)),
                    (k.pendienteReproceso, 'no conformes', AppColors.alertRed),
                  ])
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F8F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${dato.$1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: dato.$3,
                              ),
                            ),
                            Text(
                              dato.$2,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (mobile) ...[
                persona,
                const SizedBox(height: 12),
                cantidad,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: persona),
                    const SizedBox(width: 16),
                    SizedBox(width: 240, child: cantidad),
                  ],
                ),
              if (!mobile)
                AnimatedBuilder(
                  animation: cantidadCtrl,
                  builder: (_, __) {
                    final n = int.tryParse(cantidadCtrl.text) ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Al liberar $n, quedarán ${(k.pendienteReproceso - n).clamp(0, k.pendienteReproceso)} no conformes. Las prendas liberadas vuelven a logística.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.blueGrey,
                        ),
                      ),
                    );
                  },
                ),
              if (mostrarAccion)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ActionButton(
                    icon: Icons.check_circle_outline,
                    label: 'Liberar a logística',
                    color: const Color(0xFF1B7048),
                    busy: liberando,
                    onPressed: onLiberar,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ==================================================== pestaña 2: historial

class _HistorialTab extends ConsumerWidget {
  const _HistorialTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(liberacionesProduccionProvider)
        .when(
          loading: () => const WmsLoadingPanel(),
          error:
              (error, _) =>
                  Center(child: Text('No se pudo cargar el historial: $error')),
          data:
              (liberaciones) => HistorialLiberaciones(
                liberaciones: liberaciones,
                pendientesPorItem:
                    ref.watch(wmsSnapshotProvider).value == null
                        ? null
                        : {
                          for (final k
                              in ref.watch(wmsSnapshotProvider).value!.kardex)
                            k.id: k.pendienteReproceso,
                        },
              ),
        );
  }
}
