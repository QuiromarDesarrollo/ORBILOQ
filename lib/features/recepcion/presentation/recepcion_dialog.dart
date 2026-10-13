import '../../../shared/widgets/wms_expandable_alert_dialog.dart';
import 'historial_recepcion_vista.dart';
import '../../../shared/widgets/wms_scan_field.dart';
import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';
import '../../../application/auth_providers.dart';
import '../../../shared/widgets/wms_camera_scanner.dart';
import '../../../shared/widgets/historial_agrupado.dart';
import '../../../shared/widgets/catalogo_ubicacion_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import '../../../domain/recepcion_agrupada.dart';
import '../../../domain/qr_prenda.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showRecepcionDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const RecepcionDialog());

class RecepcionDialog extends ConsumerWidget {
  const RecepcionDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WmsDialogShell(
      title: 'Recepción y novedades',
      subtitle: 'Recibe: ${ref.watch(nombreOperarioProvider)}',
      mobileCatalog: true,
      icon: Icons.move_to_inbox,
      iconColor: AppColors.primaryNavy,
      expand: true,
      maxWidth: 1000,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              isScrollable: false,
              labelColor: AppColors.primaryNavy,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primaryNavy,
              labelPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              unselectedLabelStyle: TextStyle(fontSize: 11),
              tabs: [Tab(text: 'Pendientes'), Tab(text: 'Historial')],
            ),
            const SizedBox(height: 8),
            const Expanded(
              child: TabBarView(children: [_PendientesTab(), _HistorialTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ============================================================ pestaña 1: pendientes
// (flujo actual, sin cambios de comportamiento — solo se agrega "Recibido por")

class _PendientesTab extends ConsumerStatefulWidget {
  const _PendientesTab();

  @override
  ConsumerState<_PendientesTab> createState() => _PendientesTabState();
}

class _PendientesTabState extends ConsumerState<_PendientesTab> {
  final _scanCtrl = TextEditingController();
  final _busquedaCtrl = TextEditingController();
  final _scanFocus = FocusNode();
  final _scrollController = ScrollController();
  final _cantidadCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();

  /// Ids de línea que se han escaneado/buscado, más reciente primero — así
  /// se arma el orden "la última que pistoleaste sube al tope".
  final List<String> _ordenManual = [];

  String? _lineaAbiertaId;

  /// Cuántas unidades se han pistoleado por línea (sube de a 1 en cada
  /// escaneo, hasta el máximo declarado).
  final Map<String, int> _conteos = {};
  String _ubicacion = '';

  /// Quién de Logística está recibiendo — se mantiene entre tarjetas (lo
  /// normal es que sea la misma persona recibiendo varias seguidas), pero
  /// es obligatorio tener uno seleccionado para poder confirmar cualquiera.
  String? get _recibidoPor => ref.read(nombreOperarioProvider);

  bool _confirmando = false;
  FeedbackMessage? _msg;

  @override
  void dispose() {
    _scanCtrl.dispose();
    _busquedaCtrl.dispose();
    _scanFocus.dispose();
    _scrollController.dispose();
    _cantidadCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  List<LineaRecepcionPendiente> get _todasPendientes {
    final lotes = ref.read(wmsSnapshotProvider).value?.lotes ?? const <Lote>[];
    final resultado = <LineaRecepcionPendiente>[];
    for (final l in lotes) {
      for (final li in l.lineas) {
        if (li.enTransito && li.cantidadPendiente > 0) {
          resultado.add(LineaRecepcionPendiente(l, li));
        }
      }
    }
    return resultado;
  }

  List<LineaRecepcionPendiente> _ordenar(List<LineaRecepcionPendiente> items) {
    final restantes = [...items]
      ..sort((a, b) => a.linea.item.op.compareTo(b.linea.item.op));
    final resultado = <LineaRecepcionPendiente>[];
    for (final id in _ordenManual) {
      final idx = restantes.indexWhere((e) => e.linea.id == id);
      if (idx != -1) resultado.add(restantes.removeAt(idx));
    }
    resultado.addAll(restantes);
    return resultado;
  }

  void _abrirValidacion(LoteLinea linea) {
    setState(() {
      _lineaAbiertaId = linea.id;
      _cantidadCtrl.text = '${_conteos[linea.id] ?? 0}';
      _notaCtrl.clear();
      _ubicacion = '';
      _msg = null;
    });
  }

  void _subirAlTope(String lineaId) {
    _ordenManual.remove(lineaId);
    _ordenManual.insert(0, lineaId);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _procesarEntrada(String raw) {
    _scanCtrl.clear();
    if (raw.trim().isEmpty) return;
    final todas = _todasPendientes;

    final qr = QrPrenda.tryParse(raw);
    if (qr != null) {
      final coincidenciasQr =
          todas
              .where(
                (e) =>
                    e.linea.item.op == qr.op &&
                    e.linea.item.codigo == qr.codigo,
              )
              .map((e) => e.linea)
              .toList();
      final encontrada =
          coincidenciasQr.where((e) => e.id == _lineaAbiertaId).firstOrNull ??
          coincidenciasQr.firstOrNull;
      if (encontrada == null) {
        setState(
          () =>
              _msg = const FeedbackMessage.error(
                'No hay ninguna línea pendiente por recibir para esta prenda.',
              ),
        );
        _scanFocus.requestFocus();
        return;
      }

      final totalGrupo =
          agruparRecepcionPendiente(todas)
              .firstWhere(
                (g) => g.lineas.any((e) => e.linea.id == encontrada.id),
              )
              .cantidadPendiente;
      final actual = _conteos[encontrada.id] ?? 0;
      if (actual >= totalGrupo) {
        setState(
          () =>
              _msg = FeedbackMessage.error(
                'LÍMITE ALCANZADO: ya se contaron las $totalGrupo Uds pendientes de esta prenda.',
              ),
        );
        _scanFocus.requestFocus();
        return;
      }

      final mismaLineaYaAbierta = _lineaAbiertaId == encontrada.id;
      setState(() {
        _msg = null;
        _conteos[encontrada.id] = actual + 1;
        _subirAlTope(encontrada.id);
        _lineaAbiertaId = encontrada.id;
        _cantidadCtrl.text = '${_conteos[encontrada.id]}';
        if (!mismaLineaYaAbierta) {
          _notaCtrl.clear();
          _ubicacion = '';
        }
      });
      _scanFocus.requestFocus();
      return;
    }

    // No es un QR: se interpreta como número de OP — sube todas sus líneas.
    final op = raw.trim();
    final coincidencias = todas.where((e) => e.linea.item.op == op).toList();
    if (coincidencias.isEmpty) {
      setState(
        () =>
            _msg = FeedbackMessage.error(
              'No hay líneas pendientes por recibir para la OP $op.',
            ),
      );
      _scanFocus.requestFocus();
      return;
    }
    setState(() {
      _msg = null;
      for (final c in coincidencias.reversed) {
        _subirAlTope(c.linea.id);
      }
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    _scanFocus.requestFocus();
  }

  FeedbackMessage _leerCamara(String raw) {
    _procesarEntrada(raw);
    if (_msg != null) return _msg!;
    final qr = QrPrenda.tryParse(raw);
    if (qr == null) {
      return FeedbackMessage.ok(
        'OP ${raw.trim()} · Tarjetas pendientes localizadas.',
      );
    }
    return FeedbackMessage.ok(
      'OP ${qr.op} · ${qr.codigo} · ${_conteos[_lineaAbiertaId] ?? 0} Uds contadas en la tarjeta.',
    );
  }

  Future<void> _confirmar(GrupoRecepcionPendiente grupo) async {
    final linea = grupo.lineas.first.linea;
    if (!(ref.read(ubicacionesProvider).value ?? []).contains(_ubicacion)) {
      setState(
        () =>
            _msg = const FeedbackMessage.error(
              'Selecciona un estante activo antes de recibir.',
            ),
      );
      return;
    }
    final cantidad = int.tryParse(_cantidadCtrl.text.trim());
    if (cantidad == null || cantidad <= 0) {
      setState(
        () =>
            _msg = const FeedbackMessage.error(
              'Ingresa una cantidad mayor a 0 para confirmar la recepción.',
            ),
      );
      return;
    }
    if (_recibidoPor == null || _recibidoPor!.trim().isEmpty) {
      setState(
        () =>
            _msg = const FeedbackMessage.error(
              'Selecciona quién de Logística está recibiendo.',
            ),
      );
      return;
    }

    if (cantidad > grupo.cantidadPendiente) {
      setState(
        () =>
            _msg = const FeedbackMessage.error(
              'La cantidad supera el pendiente por recibir.',
            ),
      );
      return;
    }
    final repo = ref.read(wmsRepositoryProvider);
    final plan = grupo.distribuir(cantidad);
    final ubicacion = _ubicacion,
        operario = _recibidoPor!,
        nota = _notaCtrl.text;
    setState(() {
      _confirmando = true;
      _msg = null;
    });
    var recibidas = 0;
    String? error;
    try {
      for (final parte in plan) {
        final res = await repo.recibirLoteLinea(
          loteLineaId: parte.lineaId,
          cantidad: parte.cantidad,
          ubicacion: ubicacion,
          recibidoPor: operario,
          nota: nota,
        );
        if (res case Err(:final message)) {
          error = message;
          break;
        }
        recibidas += parte.cantidad;
      }
    } catch (e) {
      error = 'No se pudo confirmar la respuesta del servidor.';
    }
    if (error != null) {
      try {
        await repo.refrescar();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _confirmando = false;
      _cantidadCtrl.text = '0';
      _lineaAbiertaId = null;
      for (final e in grupo.lineas) {
        _conteos.remove(e.linea.id);
        _ordenManual.remove(e.linea.id);
      }
      _msg =
          error == null
              ? FeedbackMessage.ok(
                '${linea.item.codigo} (${linea.item.talla}): recibidas $recibidas Uds — quedan ${grupo.cantidadPendiente - recibidas} Uds pendientes.',
              )
              : FeedbackMessage.error(
                'Se confirmaron $recibidas Uds. $error Revisa el saldo actualizado antes de ingresar otra cantidad.',
              );
    });
  }

  Future<void> _cerrarConFaltante(GrupoRecepcionPendiente grupo) async {
    final linea = grupo.lineas.first.linea;
    final confirmado = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => WmsExpandableAlertDialog(
            title: const Text('¿Cerrar con faltante?'),
            content: Text(
              'Faltan ${grupo.cantidadPendiente} Uds de ${linea.item.descripcion} (${linea.item.talla}) que nunca llegaron. '
              'Al cerrar, esas unidades van a volver a aparecer como pendientes por entregar en Producción. Esta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('CANCELAR'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text(
                  'CERRAR CON FALTANTE',
                  style: TextStyle(color: AppColors.alertRed),
                ),
              ),
            ],
          ),
    );
    if (confirmado != true) return;
    if (!mounted) return;

    setState(() => _confirmando = true);
    Result<void> res = const Ok(null);
    for (final e in grupo.lineas) {
      res = await ref
          .read(wmsRepositoryProvider)
          .cerrarLoteItemConFaltante(
            loteLineaId: e.linea.id,
            nota: _notaCtrl.text,
          );
      if (res is Err<void>) break;
    }
    if (!mounted) return;
    setState(() {
      _confirmando = false;
      switch (res) {
        case Ok():
          _msg = FeedbackMessage.ok(
            '${linea.item.codigo} (${linea.item.talla}): cerrada con faltante — vuelve a estar pendiente por entregar en Producción.',
          );
          _lineaAbiertaId = null;
          _ordenManual.remove(linea.id);
          _conteos.remove(linea.id);
        case Err(:final message):
          _msg = FeedbackMessage.error(message);
      }
    });
  }

  Future<void> _reportarSobrante(LoteLinea linea) async {
    final ctrlCantidad = TextEditingController();
    final ctrlNota = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => WmsExpandableAlertDialog(
            title: const Text('Reportar sobrante'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '¿Cuántas unidades de más llegaron de ${linea.item.descripcion} (${linea.item.talla})?',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrlCantidad,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: wmsInput('Cantidad de sobra'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrlNota,
                  decoration: wmsInput('Nota (opcional)'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('CANCELAR'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('REGISTRAR'),
              ),
            ],
          ),
    );
    if (confirmado != true) return;
    final cantidad = int.tryParse(ctrlCantidad.text.trim());
    if (cantidad == null || cantidad <= 0) {
      if (!mounted) return;
      setState(
        () =>
            _msg = const FeedbackMessage.error(
              'Ingresa una cantidad de sobrante mayor a 0.',
            ),
      );
      return;
    }
    if (!mounted) return;

    final res = await ref
        .read(wmsRepositoryProvider)
        .registrarSobrante(
          itemId: linea.item.id,
          loteLineaId: linea.id,
          cantidad: cantidad,
          operario: _recibidoPor ?? '',
          nota: ctrlNota.text,
        );
    if (!mounted) return;
    setState(() {
      switch (res) {
        case Ok():
          _msg = FeedbackMessage.ok(
            '$cantidad Uds de sobrante registradas — revísalas en la Bandeja de Sobrantes.',
          );
        case Err(:final message):
          _msg = FeedbackMessage.error(message);
      }
    });
  }

  Future<void> _camara() => showDialog<void>(
    context: context,
    builder: (_) => WmsCameraScanner(onRead: _leerCamara),
  );
  Future<void> _lector() => showDialog<void>(
    context: context,
    builder:
        (ctx) => WmsExpandableAlertDialog(
          title: const Text('Escanear con lector'),
          content: SizedBox(
            width: 360,
            child: WmsScanField(
              controller: _scanCtrl,
              focusNode: _scanFocus,
              autofocus: true,
              mostrarIngresoManual: false,
              onSubmitted: (raw) {
                _procesarEntrada(raw);
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

  @override
  Widget build(BuildContext context) {
    ref.watch(wmsSnapshotProvider);
    final pendientes = agruparRecepcionPendiente(_ordenar(_todasPendientes));
    final mobile = MediaQuery.sizeOf(context).width < 600;
    final activo =
        pendientes
            .where((g) => g.lineas.any((e) => e.linea.id == _lineaAbiertaId))
            .firstOrNull;
    final enfocado = mobile && activo != null;
    final visibles = enfocado ? [activo] : pendientes;
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_msg != null) FeedbackBanner(message: _msg!),
            if (enfocado)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _lineaAbiertaId = null),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Validar entrega · Volver'),
                ),
              )
            else ...[
              if (mobile)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton.icon(
                    onPressed: _confirmando ? null : _camara,
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('Escanear con cámara'),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _busquedaCtrl,
                      decoration: const InputDecoration(
                        hintText: 'OP o código de etiqueta',
                        prefixIcon: Icon(Icons.tag, size: 17),
                        isDense: true,
                      ),
                      onSubmitted: _procesarEntrada,
                    ),
                  ),
                  if (!mobile) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _procesarEntrada(_busquedaCtrl.text),
                      child: const Text('Buscar'),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Cámara',
                      onPressed: _camara,
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    ),
                  ],
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'Lector',
                    onPressed: _lector,
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Por recibir · ${pendientes.length} entregas · ${pendientes.fold<int>(0, (n, g) => n + g.cantidadPendiente)} uds',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
            Expanded(
              child:
                  pendientes.isEmpty
                      ? const Center(
                        child: Text(
                          'No hay nada pendiente por recibir en este momento.',
                          textAlign: TextAlign.center,
                        ),
                      )
                      : ListView.builder(
                        controller: _scrollController,
                        itemCount: visibles.length,
                        itemBuilder: (_, i) {
                          final grupo = visibles[i];
                          final e =
                              grupo.lineas
                                  .where((e) => e.linea.id == _lineaAbiertaId)
                                  .firstOrNull ??
                              grupo.lineas.first;
                          return _TarjetaLinea(
                            grupo: grupo,
                            lote: e.lote,
                            linea: e.linea,
                            abierta: e.linea.id == _lineaAbiertaId,
                            onValidar: () => _abrirValidacion(e.linea),
                            onCerrar:
                                () => setState(() => _lineaAbiertaId = null),
                            cantidadCtrl: _cantidadCtrl,
                            notaCtrl: _notaCtrl,
                            ubicacion: _ubicacion,
                            onUbicacion: (v) => setState(() => _ubicacion = v),
                            onConfirmar: () => _confirmar(grupo),
                            onCerrarConFaltante:
                                () => _cerrarConFaltante(grupo),
                            onReportarSobrante:
                                () => _reportarSobrante(e.linea),
                          );
                        },
                      ),
            ),
            if (enfocado)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _AccionRecepcion(
                  cantidad: _cantidadCtrl,
                  pendiente: activo.cantidadPendiente,
                  ubicacion: _ubicacion,
                  confirmar: () => _confirmar(activo),
                ),
              ),
          ],
        ),
        if (_confirmando)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x66000000),
              child: Center(
                child: WmsLoader(mode: OrbiloqLoaderMode.orbit, width: 220),
              ),
            ),
          ),
      ],
    );
  }
}

class _TarjetaLinea extends StatelessWidget {
  const _TarjetaLinea({
    required this.grupo,
    required this.lote,
    required this.linea,
    required this.abierta,
    required this.onValidar,
    required this.onCerrar,
    required this.cantidadCtrl,
    required this.notaCtrl,
    required this.ubicacion,
    required this.onUbicacion,
    required this.onConfirmar,
    required this.onCerrarConFaltante,
    required this.onReportarSobrante,
  });

  final GrupoRecepcionPendiente grupo;
  final Lote lote;
  final LoteLinea linea;
  final bool abierta;
  final VoidCallback onValidar;
  final VoidCallback onCerrar;
  final TextEditingController cantidadCtrl;
  final TextEditingController notaCtrl;
  final String ubicacion;
  final ValueChanged<String> onUbicacion;
  final VoidCallback onConfirmar;
  final VoidCallback onCerrarConFaltante;
  final VoidCallback onReportarSobrante;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 600;
    void ajustar(int delta) {
      cantidadCtrl.text =
          ((int.tryParse(cantidadCtrl.text) ?? 0) + delta)
              .clamp(0, grupo.cantidadPendiente)
              .toString();
    }

    final cantidad = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Cantidad que llegó · máx. ${grupo.cantidadPendiente}',
          style: const TextStyle(fontSize: 11),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            IconButton.outlined(
              tooltip: 'Reducir cantidad',
              onPressed: () => ajustar(-1),
              icon: const Icon(Icons.remove, size: 16),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: cantidadCtrl,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _MaxValorFormatter(grupo.cantidadPendiente),
                ],
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
              onPressed: () => ajustar(1),
              icon: const Icon(Icons.add, size: 16),
            ),
            TextButton(
              onPressed: () => cantidadCtrl.text = '${grupo.cantidadPendiente}',
              child: const Text('Todo'),
            ),
          ],
        ),
      ],
    );
    final estante = CatalogoUbicacionDropdown(
      label: 'Estante donde queda *',
      value: ubicacion,
      onChanged: onUbicacion,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: abierta ? AppColors.primaryNavy : const Color(0xFFDCE6EC),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            'OP ${linea.item.op}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Talla ${linea.item.talla}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          if (linea.esReproceso)
                            const Text(
                              'Reprocesado',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF9E6400),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        linea.item.descripcion,
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        linea.item.oc,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.blueGrey,
                        ),
                      ),
                      if (grupo.cantidadRecibida > 0)
                        Text(
                          'Ya recibidas: ${grupo.cantidadRecibida}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.blueGrey,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    Text(
                      '${grupo.cantidadPendiente}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'pendientes',
                      style: TextStyle(fontSize: 10, color: Colors.blueGrey),
                    ),
                  ],
                ),
                if (abierta && !mobile)
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: onCerrar,
                    icon: const Icon(Icons.close, size: 18),
                  ),
              ],
            ),
            if (!abierta) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onValidar,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Validar'),
              ),
            ],
            if (abierta) ...[
              const Divider(height: 24),
              if (linea.esReproceso)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Vuelve corregida de producto no conforme.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9E6400)),
                  ),
                ),
              LayoutBuilder(
                builder:
                    (context, c) =>
                        c.maxWidth < 600
                            ? Column(
                              children: [
                                estante,
                                const SizedBox(height: 14),
                                cantidad,
                              ],
                            )
                            : Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(child: estante),
                                const SizedBox(width: 16),
                                SizedBox(width: 245, child: cantidad),
                              ],
                            ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: notaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Novedad para Producción · opcional',
                  hintText: 'Ej.: llegaron 2 cajas abiertas',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onReportarSobrante,
                icon: const Icon(Icons.add_box_outlined, size: 16),
                label: const Text(
                  '¿Llegó de más? Reportar sobrante',
                  textAlign: TextAlign.center,
                ),
              ),
              if (grupo.cantidadRecibida > 0)
                TextButton.icon(
                  onPressed: onCerrarConFaltante,
                  icon: const Icon(
                    Icons.block,
                    size: 16,
                    color: AppColors.alertRed,
                  ),
                  label: const Text(
                    'Cerrar con faltante',
                    style: TextStyle(color: AppColors.alertRed),
                  ),
                ),
              if (!mobile)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _AccionRecepcion(
                    cantidad: cantidadCtrl,
                    pendiente: grupo.cantidadPendiente,
                    ubicacion: ubicacion,
                    confirmar: onConfirmar,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccionRecepcion extends StatelessWidget {
  const _AccionRecepcion({
    required this.cantidad,
    required this.pendiente,
    required this.ubicacion,
    required this.confirmar,
  });
  final TextEditingController cantidad;
  final int pendiente;
  final String ubicacion;
  final VoidCallback confirmar;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: cantidad,
    builder: (_, __) {
      final n = int.tryParse(cantidad.text) ?? 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Quedan ${(pendiente - n).clamp(0, pendiente)} pendientes de esta entrega',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
          ),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: confirmar,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1B7048),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: Text(
              'Recibir $n${ubicacion.isEmpty ? '' : ' en $ubicacion'}',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    },
  );
}

/// Impide que el campo acepte un número mayor al máximo permitido.
class _MaxValorFormatter extends TextInputFormatter {
  _MaxValorFormatter(this.maximo);
  final int maximo;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final valor = int.tryParse(newValue.text);
    if (valor == null || valor > maximo) return oldValue;
    return newValue;
  }
}

// ==================================================== pestaña 2: historial
// Reutiliza datos que YA están cargados en memoria (WmsSnapshot.lotes trae
// todo, no solo lo pendiente) — no hace ninguna consulta nueva.

final _recepcionesHistorialProvider =
    FutureProvider.autoDispose<List<GrupoHistorial>>((ref) async {
      final snapshot = ref.watch(wmsSnapshotProvider).value;
      final items = <String, ItemOrden>{
        for (final fila in snapshot?.kardex ?? <ItemKardex>[])
          fila.item.id: fila.item,
        for (final lote in snapshot?.lotes ?? <Lote>[])
          for (final linea in lote.lineas) linea.item.id: linea.item,
      };
      final movimientos =
          await ref.watch(wmsRepositoryProvider).cargarRecepciones();
      if (movimientos.any((m) => !items.containsKey(m.itemId))) {
        throw StateError(
          'Faltan órdenes para calcular el total de recepciones.',
        );
      }
      return agruparHistorial(
        movimientos,
        (m) => items[m.itemId]!,
        (m) => EventoHistorial(
          id: '${m.itemId}-${m.fecha}',
          titulo: 'Recepción',
          detalle: m.nota,
          fecha: m.fecha,
          cantidad: m.cantidad,
        ),
      );
    });

class _HistorialTab extends ConsumerWidget {
  const _HistorialTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lotes = ref.watch(wmsSnapshotProvider).value?.lotes ?? const <Lote>[];
    final recepciones = ref.watch(_recepcionesHistorialProvider);
    final registros = [
      for (final lote in lotes)
        for (final linea in lote.lineas)
          if (!linea.enTransito ||
              linea.fechaRecepcion != null ||
              (linea.cantidadRecibida ?? 0) > 0)
            (lote: lote, linea: linea),
    ];
    return Column(
      children: [
        if (recepciones.isLoading)
          const WmsLoadingStrip(label: 'Calculando prendas recibidas…'),
        if (recepciones.hasError)
          TextButton.icon(
            onPressed: () => ref.invalidate(_recepcionesHistorialProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('No se pudo calcular el total. Reintentar'),
          ),
        Expanded(
          child: HistorialRecepcionVista(
            parciales: {
              for (final e in registros)
                if (e.linea.enTransito) e.linea.id,
            },
            novedades: {
              for (final e in registros)
                if (e.linea.estado == EstadoLineaLote.recibidoConNovedad ||
                    e.linea.novedad.isNotEmpty)
                  e.linea.id,
            },
            totales:
                recepciones.isLoading || recepciones.hasError
                    ? null
                    : recepciones.value,
            grupos: agruparHistorial(
              registros,
              (e) => e.linea.item,
              (e) => EventoHistorial(
                id: e.linea.id,
                fecha: e.linea.fechaRecepcion,
                cantidad: e.linea.cantidadRecibida ?? 0,
                titulo:
                    'Recepción acumulada · ${e.linea.cantidadRecibida ?? 0} Uds · ${e.linea.estado.etiqueta}',
                detalle:
                    'Lote: ${e.lote.id} | Operario: ${e.lote.operario}\n'
                    'Enviadas: ${e.linea.cantidadEnviada} Uds | Recibidas: ${e.linea.cantidadRecibida ?? 0} Uds | Estante: ${e.linea.ubicacionDestino ?? '—'}\n'
                    'Última recepción registrada por: ${e.linea.recibidoPor.isEmpty ? 'Sin registrar' : e.linea.recibidoPor}'
                    '${e.linea.novedad.isEmpty ? '' : '\nNovedad: ${e.linea.novedad}'}',
                color: colorDeEstadoLinea(e.linea.estado),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
