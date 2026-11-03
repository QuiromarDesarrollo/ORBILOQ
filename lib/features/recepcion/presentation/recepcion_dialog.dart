import '../../../shared/borrador_operativo.dart';
import '../../../application/historial_recepciones.dart';
import '../../inventario/presentation/inventario_page.dart';
import '../../../shared/widgets/wms_expandable_alert_dialog.dart';
import 'dart:convert';
import 'historial_recepcion_vista.dart';
import '../../../shared/widgets/wms_scan_field.dart';
import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';
import '../../../application/auth_providers.dart';
import '../../../data/inventario_repository.dart';
import '../../../data/despachos_oc_repository.dart';
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

import '../../../shared/widgets/wms_dialog.dart';

Future<void> showRecepcionDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const RecepcionDialog());

class RecepcionDialog extends ConsumerStatefulWidget {
  const RecepcionDialog({super.key});
  @override
  ConsumerState<RecepcionDialog> createState() => _RecepcionDialogState();
}

class _RecepcionDialogState extends ConsumerState<RecepcionDialog> {
  bool _enEdicion = false;
  @override
  Widget build(BuildContext context) {
    final conInventario = ref.watch(inventarioRepositoryProvider) != null;
    return WmsDialogShell(
      title: 'Recepción y novedades',
      subtitle: 'Recibe: ${ref.watch(nombreOperarioProvider)}',
      mobileCatalog: true,
      compactHeader: true,
      showHeaderIcon: true,
      icon: Icons.move_to_inbox,
      iconColor: AppColors.primaryNavy,
      expand: true,
      maxWidth: 1000,
      child: DefaultTabController(
        length: conInventario ? 3 : 2,
        child: Column(
          children: [
            if (!_enEdicion)
              TabBar(
                isScrollable: false,
                labelColor: AppColors.primaryNavy,
                unselectedLabelColor: Colors.grey,
                indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(color: Color(0xFFC8DB00), width: 3),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelPadding: EdgeInsets.symmetric(horizontal: 12),
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: TextStyle(fontSize: 14),
                tabs: [
                  const Tab(height: 36, text: 'Pendientes'),
                  if (conInventario)
                    const Tab(height: 36, text: 'A inventario'),
                  Tab(height: 36, text: 'Historial'),
                ],
              ),
            if (!_enEdicion) const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                physics:
                    _enEdicion ? const NeverScrollableScrollPhysics() : null,
                children: [
                  _PendientesTab(
                    onEdicion: (valor) {
                      if (mounted && _enEdicion != valor) {
                        setState(() => _enEdicion = valor);
                      }
                    },
                  ),
                  if (conInventario) const TransferirInventarioTab(),
                  const _HistorialTab(),
                ],
              ),
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
  const _PendientesTab({required this.onEdicion});
  final ValueChanged<bool> onEdicion;

  @override
  ConsumerState<_PendientesTab> createState() => _PendientesTabState();
}

class _PendientesTabState extends ConsumerState<_PendientesTab>
    with BorradorOperativo<_PendientesTab> {
  @override
  String get borradorProceso => 'recepcion-pendientes';
  @override
  bool get operacionEnCurso => _confirmando;
  @override
  Iterable<TextEditingController> get controlesBorrador => [
    _busquedaCtrl,
    _cantidadCtrl,
    _notaCtrl,
  ];
  @override
  Map<String, dynamic> capturarBorrador() => {
    'busqueda': _busquedaCtrl.text,
    'cantidad': _cantidadCtrl.text,
    'nota': _notaCtrl.text,
    'orden': _ordenManual,
    'linea': _lineaAbiertaId,
    'conteos': _conteos,
    'ubicacion': _ubicacion,
    'solicitud': _solicitudRecepcion,
    'pedido': _pedidoRecepcion,
  };
  @override
  void recuperarBorrador(Map<String, dynamic> d) {
    _busquedaCtrl.text = d['busqueda'] as String? ?? '';
    _cantidadCtrl.text = d['cantidad'] as String? ?? '';
    _notaCtrl.text = d['nota'] as String? ?? '';
    _ordenManual
      ..clear()
      ..addAll((d['orden'] as List? ?? []).cast<String>());
    _lineaAbiertaId = d['linea'] as String?;
    _conteos
      ..clear()
      ..addAll(Map<String, int>.from(d['conteos'] as Map? ?? {}));
    _ubicacion = d['ubicacion'] as String? ?? '';
    _solicitudRecepcion = d['solicitud'] as String?;
    _pedidoRecepcion = d['pedido'] as String?;
  }

  final _scanCtrl = TextEditingController();
  final _busquedaCtrl = TextEditingController();
  final _scanFocus = FocusNode();
  final _scrollController = ScrollController();
  final _cantidadCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  String? _solicitudRecepcion, _pedidoRecepcion;

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
  bool _notificoEdicion = false;
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
    if (_confirmando || borradorBloqueado) return;
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
    final inventario = ref.read(inventarioRepositoryProvider);
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
      if (inventario != null) {
        final parametros = <String, dynamic>{
          'p_plan': [
            for (final parte in plan)
              {'linea': parte.lineaId, 'cantidad': parte.cantidad},
          ],
          'p_ubicacion': ubicacion,
          'p_recibido_por': operario,
          'p_nota': nota,
          'p_inventario': 0,
        };
        final firma = jsonEncode(parametros);
        if (_pedidoRecepcion != firma) {
          _pedidoRecepcion = firma;
          _solicitudRecepcion = nuevaSolicitudDespacho();
        }
        if (!await asegurarBorrador()) {
          throw StateError('No se pudo conservar la solicitud');
        }
        await inventario.ejecutar('inventario_recibir', {
          ...parametros,
          'p_solicitud': _solicitudRecepcion,
        });
        recibidas = cantidad;
        await repo.refrescar();
        _pedidoRecepcion = null;
        _solicitudRecepcion = null;
      } else {
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
      }
    } catch (e) {
      error = 'No se pudo completar o confirmar la recepción: $e';
    }
    if (error != null) {
      try {
        await repo.refrescar();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _confirmando = false;
      if (error == null) {
        _cantidadCtrl.text = '0';
        _lineaAbiertaId = null;
      }
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
  Widget build(BuildContext context) => envolverBorrador(_contenido(context));

  Widget _contenido(BuildContext context) {
    ref.watch(wmsSnapshotProvider);
    final pendientes = agruparRecepcionPendiente(_ordenar(_todasPendientes));
    final mobile = MediaQuery.sizeOf(context).width < 600;
    final activo =
        pendientes
            .where((g) => g.lineas.any((e) => e.linea.id == _lineaAbiertaId))
            .firstOrNull;
    final enfocado = activo != null;
    final modoEdicion = enfocado && !borradorBloqueado;
    if (_notificoEdicion != modoEdicion) {
      _notificoEdicion = modoEdicion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onEdicion(modoEdicion);
      });
    }
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
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  label: const Text('Volver a entregas'),
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    for (final dato in [
                      ('Entregas por recibir', pendientes.length),
                      (
                        'Unidades pendientes',
                        pendientes.fold<int>(
                          0,
                          (n, g) => n + g.cantidadPendiente,
                        ),
                      ),
                    ])
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F9FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dato.$1,
                                style: const TextStyle(
                                  color: Colors.blueGrey,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${dato.$2}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
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
                          );
                        },
                      ),
            ),
            if (enfocado)
              Padding(
                padding: const EdgeInsets.only(top: 4),
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

  @override
  Widget build(BuildContext context) {
    final compacto = MediaQuery.sizeOf(context).height < 700;
    const navy = Color(0xFF14354A);
    const muted = Color(0xFF647F94);
    final secondary = OutlinedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: navy,
      side: const BorderSide(color: Color(0xFFCCDCE6)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    );
    void ajustar(int delta) =>
        cantidadCtrl.text =
            ((int.tryParse(cantidadCtrl.text) ?? 0) + delta)
                .clamp(0, grupo.cantidadPendiente)
                .toString();
    Widget badge(String texto, Color fondo, Color color, {IconData? icon}) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
              ],
              Text(
                texto,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
    final control = Row(
      children: [
        IconButton.outlined(
          tooltip: 'Reducir cantidad',
          style: secondary.copyWith(
            fixedSize: const WidgetStatePropertyAll(Size(40, 40)),
            minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          ),
          onPressed: () => ajustar(-1),
          icon: const Icon(Icons.remove, size: 18),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: TextField(
            controller: cantidadCtrl,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton.outlined(
          tooltip: 'Aumentar cantidad',
          style: secondary.copyWith(
            fixedSize: const WidgetStatePropertyAll(Size(40, 40)),
            minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          ),
          onPressed: () => ajustar(1),
          icon: const Icon(Icons.add, size: 18),
        ),
      ],
    );
    final todo = OutlinedButton(
      style: secondary.copyWith(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
        foregroundColor: const WidgetStatePropertyAll(Color(0xFF16714C)),
        backgroundColor: const WidgetStatePropertyAll(Color(0xFFF2F9F5)),
      ),
      onPressed: () => cantidadCtrl.text = '${grupo.cantidadPendiente}',
      child: const Text('Recibir todo', style: TextStyle(fontSize: 12)),
    );
    final cantidad = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          runSpacing: 2,
          children: [
            const Text(
              'Cantidad a recibir',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: navy,
                fontSize: 13,
              ),
            ),
            Text(
              'Máximo: ${grupo.cantidadPendiente}',
              style: const TextStyle(fontSize: 12, color: muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder:
              (context, c) =>
                  c.maxWidth < 280
                      ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [control, const SizedBox(height: 6), todo],
                      )
                      : Row(
                        children: [
                          Expanded(child: control),
                          const SizedBox(width: 8),
                          todo,
                        ],
                      ),
        ),
      ],
    );
    final estante = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Estante de destino *',
          style: TextStyle(fontWeight: FontWeight.w600, color: navy),
        ),
        const SizedBox(height: 6),
        CatalogoUbicacionDropdown(
          label: 'Estante',
          value: ubicacion,
          onChanged: onUbicacion,
        ),
      ],
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE6EC)),
        boxShadow: [
          if (abierta)
            const BoxShadow(
              color: Color(0x0C14354A),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(compacto ? 10 : 12),
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
                          if (abierta && !compacto)
                            const Text(
                              'RECEPCIÓN DE PRODUCCIÓN',
                              style: TextStyle(
                                letterSpacing: 1.5,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: muted,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 14,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'OP ${linea.item.op}',
                                style: TextStyle(
                                  fontSize: abierta ? 24 : 18,
                                  fontWeight: FontWeight.w800,
                                  color: navy,
                                ),
                              ),
                              badge(
                                'Talla ${linea.item.talla}',
                                const Color(0xFFEAF2F8),
                                muted,
                              ),
                              if (linea.esReproceso)
                                badge(
                                  'Reprocesado',
                                  const Color(0xFFFFF2D1),
                                  const Color(0xFF996000),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            linea.item.descripcion,
                            style: const TextStyle(fontSize: 13, color: navy),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            linea.item.oc,
                            style: const TextStyle(color: muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (abierta)
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: onCerrar,
                        icon: const Icon(Icons.close, color: muted),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    badge(
                      '${grupo.cantidadRecibida} recibidas',
                      Colors.white,
                      navy,
                      icon: Icons.inventory_2_outlined,
                    ),
                    badge(
                      '${grupo.cantidadPendiente} pendientes',
                      const Color(0xFFFFF2CF),
                      const Color(0xFFA76500),
                      icon: Icons.schedule,
                    ),
                  ],
                ),
                if (!abierta) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Avance de recepción',
                          style: TextStyle(color: muted),
                        ),
                      ),
                      Text(
                        '${grupo.cantidadRecibida} de ${grupo.cantidadRecibida + grupo.cantidadPendiente} uds',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value:
                        grupo.cantidadRecibida /
                        (grupo.cantidadRecibida + grupo.cantidadPendiente),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(6),
                    color: const Color(0xFF1B7550),
                    backgroundColor: const Color(0xFFF1F4F5),
                  ),
                  const Divider(height: 28),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        style: secondary,
                        onPressed: onValidar,
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Reportar novedad'),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0B2C3C),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: onValidar,
                        icon: const Icon(Icons.fact_check_outlined, size: 18),
                        label: const Text('Validar recepción'),
                      ),
                    ],
                  ),
                ],
                if (abierta) ...[
                  const Divider(height: 12, color: Color(0xFFDCE6EC)),
                  if (linea.esReproceso)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text('Vuelve corregida de producto no conforme.'),
                    ),
                  LayoutBuilder(
                    builder:
                        (context, c) =>
                            c.maxWidth < 650
                                ? Column(
                                  children: [
                                    estante,
                                    const SizedBox(height: 8),
                                    cantidad,
                                  ],
                                )
                                : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 1, child: estante),
                                    const SizedBox(width: 24),
                                    Expanded(flex: 1, child: cantidad),
                                  ],
                                ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Novedad para Producción',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: navy,
                        ),
                      ),
                      const Text(
                        'Opcional',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notaCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Escribe una observación, si aplica...',
                      prefixIcon: Icon(Icons.chat_bubble_outline),
                      isDense: true,
                    ),
                  ),
                  const Divider(height: 12, color: Color(0xFFDCE6EC)),
                  Wrap(
                    spacing: 16,
                    runSpacing: 10,
                    children: [
                      if (grupo.cantidadRecibida > 0)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: AppColors.alertRed,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          onPressed: onCerrarConFaltante,
                          icon: const Icon(Icons.block, size: 20),
                          label: const Text('Cerrar con faltante'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
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
      final valido = n > 0 && n <= pendiente;
      final completo = valido && n == pendiente;
      final resumen = Row(
        children: [
          Icon(
            completo ? Icons.check_circle : Icons.info_outline,
            color: const Color(0xFF18774F),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n > pendiente
                      ? 'La cantidad supera el pendiente'
                      : n < 0
                      ? 'Ingresa una cantidad válida'
                      : completo
                      ? 'Con esta recepción no quedan unidades pendientes.'
                      : 'Quedan ${pendiente - n} pendientes de esta entrega',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF14354A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Destino: ${ubicacion.isEmpty ? 'Selecciona un estante' : ubicacion}',
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
      final boton = FilledButton.icon(
        onPressed: valido ? confirmar : null,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF18724D),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        icon: const Icon(Icons.check_circle),
        label: Text(
          'Confirmar recepción · $n unidades',
          textAlign: TextAlign.center,
        ),
      );
      return Container(
        color: const Color(0xFFF0F8F3),
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder:
              (context, c) =>
                  c.maxWidth < 650
                      ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [resumen, const SizedBox(height: 8), boton],
                      )
                      : Row(
                        children: [
                          Expanded(child: resumen),
                          const SizedBox(width: 20),
                          boton,
                        ],
                      ),
        ),
      );
    },
  );
}

// Recepciones individuales: cantidades y fechas del libro de movimientos.
final _recepcionesHistorialProvider =
    FutureProvider.autoDispose<List<GrupoHistorial>>((ref) async {
      final snapshot = await ref.watch(wmsSnapshotProvider.future);
      final movimientos =
          await ref.watch(wmsRepositoryProvider).cargarRecepciones();
      return historialRecepcionesDiarias(movimientos, snapshot);
    });

class _HistorialTab extends ConsumerWidget {
  const _HistorialTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recepciones = ref.watch(_recepcionesHistorialProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: recepciones.when(
        loading:
            () => const Center(
              child: WmsLoadingStrip(
                label: 'Cargando movimientos de recepción…',
              ),
            ),
        error:
            (error, stack) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'No se pudieron cargar las recepciones del historial.',
                  ),
                  const Text(
                    'No se muestran acumulados como si fueran movimientos del día.',
                  ),
                  TextButton.icon(
                    onPressed:
                        () => ref.invalidate(_recepcionesHistorialProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
        data:
            (grupos) => HistorialRecepcionVista(
              grupos: grupos,
              novedades: const {},
              parciales: const {},
              movimientosReales: true,
            ),
      ),
    );
  }
}
