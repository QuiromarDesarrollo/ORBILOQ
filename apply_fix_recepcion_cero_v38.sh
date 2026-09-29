#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - BUGFIX: recibir con cantidad 0 cerraba la linea sin registrar
# nada (v38). Cambio quirurgico: solo el flujo de recepcion de lotes.
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_fix_recepcion_cero_v38.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi
echo "Aplicando el arreglo del bug de recepcion con cantidad 0..."

echo "  - lib/features/recepcion/presentation/recepcion_dialog.dart"
mkdir -p "$(dirname 'lib/features/recepcion/presentation/recepcion_dialog.dart')"
cat > 'lib/features/recepcion/presentation/recepcion_dialog.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/constants.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import '../../../domain/qr_prenda.dart';
import '../../../shared/widgets/action_button.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/labeled_dropdown.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showRecepcionDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const RecepcionDialog());

/// Empareja una línea con su lote de origen — solo para mostrar la
/// referencia ("LOTE-101") en la lista plana; no cambia el modelo de datos.
class _LineaConLote {
  const _LineaConLote(this.lote, this.linea);
  final Lote lote;
  final LoteLinea linea;
}

class RecepcionDialog extends ConsumerStatefulWidget {
  const RecepcionDialog({super.key});

  @override
  ConsumerState<RecepcionDialog> createState() => _RecepcionDialogState();
}

class _RecepcionDialogState extends ConsumerState<RecepcionDialog> {
  final _scanCtrl = TextEditingController();
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
  String _ubicacion = WmsConstantes.ubicaciones.first;
  bool _confirmando = false;
  FeedbackMessage? _msg;

  @override
  void dispose() {
    _scanCtrl.dispose();
    _scanFocus.dispose();
    _scrollController.dispose();
    _cantidadCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  List<_LineaConLote> get _todasPendientes {
    final lotes = ref.read(wmsSnapshotProvider).value?.lotes ?? const <Lote>[];
    final resultado = <_LineaConLote>[];
    for (final l in lotes) {
      for (final li in l.lineas) {
        if (li.enTransito) resultado.add(_LineaConLote(l, li));
      }
    }
    return resultado;
  }

  List<_LineaConLote> _ordenar(List<_LineaConLote> items) {
    final restantes = [...items]..sort((a, b) => a.linea.item.op.compareTo(b.linea.item.op));
    final resultado = <_LineaConLote>[];
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
      _ubicacion = WmsConstantes.ubicaciones.first;
      _msg = null;
    });
  }

  void _subirAlTope(String lineaId) {
    _ordenManual.remove(lineaId);
    _ordenManual.insert(0, lineaId);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _procesarEntrada(String raw) {
    _scanCtrl.clear();
    if (raw.trim().isEmpty) return;
    final todas = _todasPendientes;

    final qr = QrPrenda.tryParse(raw);
    if (qr != null) {
      final encontrada = todas
          .where((e) => e.linea.item.op == qr.op && e.linea.item.codigo == qr.codigo)
          .map((e) => e.linea)
          .firstOrNull;
      if (encontrada == null) {
        setState(() => _msg = const FeedbackMessage.error('No hay ninguna línea pendiente por recibir para esta prenda.'));
        _scanFocus.requestFocus();
        return;
      }

      final actual = _conteos[encontrada.id] ?? 0;
      if (actual >= encontrada.cantidadEnviada) {
        setState(() => _msg = FeedbackMessage.error(
              'LÍMITE ALCANZADO: ya se contaron las ${encontrada.cantidadEnviada} Uds declaradas de esta prenda.',
            ));
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
          _ubicacion = WmsConstantes.ubicaciones.first;
        }
      });
      _scanFocus.requestFocus();
      return;
    }

    // No es un QR: se interpreta como número de OP — sube todas sus líneas.
    final op = raw.trim();
    final coincidencias = todas.where((e) => e.linea.item.op == op).toList();
    if (coincidencias.isEmpty) {
      setState(() => _msg = FeedbackMessage.error('No hay líneas pendientes por recibir para la OP $op.'));
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
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    _scanFocus.requestFocus();
  }

  Future<void> _confirmar(LoteLinea linea) async {
    final cantidad = int.tryParse(_cantidadCtrl.text.trim());
    if (cantidad == null || cantidad <= 0) {
      setState(() => _msg = const FeedbackMessage.error('Ingresa una cantidad mayor a 0 para confirmar la recepción.'));
      return;
    }

    setState(() {
      _confirmando = true;
      _msg = null;
    });
    final res = await ref.read(wmsRepositoryProvider).recibirLoteLinea(
          loteLineaId: linea.id,
          cantidad: cantidad,
          ubicacion: _ubicacion,
          nota: _notaCtrl.text,
        );
    if (!mounted) return;

    switch (res) {
      case Ok(:final value):
        setState(() {
          _confirmando = false;
          _msg = FeedbackMessage.ok(
            '${linea.item.codigo} (${linea.item.talla}): ${value.estado.etiqueta}. Ingresada a $_ubicacion.',
          );
          _lineaAbiertaId = null;
          _ordenManual.remove(linea.id);
          _conteos.remove(linea.id);
        });
      case Err(:final message):
        setState(() {
          _confirmando = false;
          _msg = FeedbackMessage.error(message);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se observa el snapshot para reconstruir cuando cambian los lotes.
    ref.watch(wmsSnapshotProvider);
    final pendientes = _ordenar(_todasPendientes);

    return WmsDialogShell(
      title: 'RECEPCIÓN Y REPORTE DE NOVEDADES',
      icon: Icons.move_to_inbox,
      iconColor: AppColors.primaryNavy,
      expand: true,
      maxWidth: 1000,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_msg != null) ...[
                FeedbackBanner(message: _msg!),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _scanCtrl,
                focusNode: _scanFocus,
                autofocus: true,
                decoration: wmsInput('ESCANEAR PRENDA O BUSCAR POR OP', icon: Icons.qr_code_scanner),
                onSubmitted: _procesarEntrada,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: pendientes.isEmpty
                    ? const Center(
                        child: Text('No hay nada pendiente por recibir en este momento.',
                            style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: pendientes.length,
                        itemBuilder: (_, i) {
                          final e = pendientes[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TarjetaLinea(
                              lote: e.lote,
                              linea: e.linea,
                              abierta: e.linea.id == _lineaAbiertaId,
                              onValidar: () => _abrirValidacion(e.linea),
                              onCerrar: () => setState(() => _lineaAbiertaId = null),
                              cantidadCtrl: _cantidadCtrl,
                              notaCtrl: _notaCtrl,
                              ubicacion: _ubicacion,
                              onUbicacion: (v) => setState(() => _ubicacion = v),
                              onConfirmar: () => _confirmar(e.linea),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          if (_confirmando)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LogoLoader(size: 72),
                      SizedBox(height: 16),
                      Text(
                        'Procesando…',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _TarjetaLinea extends StatelessWidget {
  const _TarjetaLinea({
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
  });

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

  @override
  Widget build(BuildContext context) {
    final colorBase = linea.esReproceso ? Colors.amber.shade50 : Colors.white;
    return Card(
      color: abierta ? Colors.green.shade50 : colorBase,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: abierta
              ? AppColors.actionGreen
              : linea.esReproceso
                  ? Colors.amber.shade700
                  : Colors.grey.shade300,
          width: abierta ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(
                            'OP: ${linea.item.op} (${linea.item.talla}) - ${linea.item.descripcion}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryNavy),
                          ),
                          if (linea.esReproceso)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade700,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('PRODUCTO REPROCESADO',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      Text(
                        'No. OC: ${linea.item.oc} | ${linea.cantidadEnviada} Uds | '
                        'Lote: ${lote.id} (${lote.operario})',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                if (!abierta)
                  ActionButton(icon: Icons.qr_code, label: 'VALIDAR', color: AppColors.primaryNavy, onPressed: onValidar)
                else
                  IconButton(tooltip: 'Cerrar', icon: const Icon(Icons.close), onPressed: onCerrar),
              ],
            ),
            if (abierta) ...[
              const Divider(),
              if (linea.esReproceso) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    children: [
                      Icon(Icons.autorenew, size: 16, color: Colors.amber.shade900),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Esta prenda era producto no conforme, ya fue reprocesada por Producción.',
                          style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.w600, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: LabeledDropdown<String>(
                      label: 'Estante físico',
                      value: ubicacion,
                      items: WmsConstantes.ubicaciones,
                      onChanged: onUbicacion,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: cantidadCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _MaxValorFormatter(linea.cantidadEnviada),
                      ],
                      decoration: wmsInput('Cant. validada (máx ${linea.cantidadEnviada})'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notaCtrl,
                decoration: wmsInput('Nota de novedad para Producción (opcional)', icon: Icons.warning_amber),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: onConfirmar,
                  icon: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  label: const Text('INGRESAR A ESTANTE & CONFIRMAR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.actionGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Impide que el campo acepte un número mayor al máximo permitido.
class _MaxValorFormatter extends TextInputFormatter {
  _MaxValorFormatter(this.maximo);
  final int maximo;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final valor = int.tryParse(newValue.text);
    if (valor == null || valor > maximo) return oldValue;
    return newValue;
  }
}

/// Logo de ORBILOQ girando, usado como loader de pantalla completa.
class _LogoLoader extends StatefulWidget {
  const _LogoLoader({this.size = 20});
  final double size;

  @override
  State<_LogoLoader> createState() => _LogoLoaderState();
}

class _LogoLoaderState extends State<_LogoLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: ClipOval(
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          padding: EdgeInsets.all(widget.size * 0.08),
          child: Image.asset(
            'assets/images/logo_orbiloq.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => SizedBox(
              width: widget.size,
              height: widget.size,
              child: const CircularProgressIndicator(strokeWidth: 3, color: AppColors.tealAccent),
            ),
          ),
        ),
      ),
    );
  }
}
ORBILOQ_EOF

echo "  - lib/data/in_memory_wms_repository.dart"
mkdir -p "$(dirname 'lib/data/in_memory_wms_repository.dart')"
cat > 'lib/data/in_memory_wms_repository.dart' << 'ORBILOQ_EOF'
import 'dart:async';

import '../core/constants.dart';
import '../core/result.dart';
import '../domain/models.dart';
import '../domain/wms_repository.dart';

class _Acumulado {
  int producido = 0;
  int recibido = 0;
  int despachado = 0;
  int pendienteReproceso = 0;
  final Map<String, int> ubicaciones = {};
  DateTime? fechaEntrega;
  DateTime? fechaRecepcion;
}

/// Implementación en memoria basada en un libro de movimientos (ledger).
/// Todos los saldos se derivan de los movimientos: no hay contadores que puedan divergir.
class InMemoryWmsRepository implements WmsRepository {
  InMemoryWmsRepository._();

  factory InMemoryWmsRepository.seeded() => InMemoryWmsRepository._().._sembrar();

  /// Base de numeración automática de lotes (en Supabase: secuencia de Postgres).
  static const _baseSecuencia = 101;

  final Map<String, ItemOrden> _items = {};
  final List<Movimiento> _movimientos = [];
  final List<Lote> _lotes = []; // más recientes primero
  final List<Liberacion> _liberaciones = []; // más recientes primero
  int _correlativoLiberacion = 0;
  final List<Devolucion> _devoluciones = []; // más recientes primero
  int _correlativoDevolucion = 0;
  final List<String> _personalLogistica = ['RECEPCIÓN BODEGA'];
  final List<String> _personalProduccion = ['SUPERVISOR PLANTA'];
  final StreamController<WmsSnapshot> _controller = StreamController.broadcast();

  // ---------------------------------------------------------------- lectura

  @override
  Stream<WmsSnapshot> watch() async* {
    yield _snapshot();
    yield* _controller.stream;
  }

  @override
  Future<void> refrescar() async => _emitir();

  @override
  void dispose() {
    _controller.close();
  }

  void _emitir() {
    if (!_controller.isClosed) _controller.add(_snapshot());
  }

  WmsSnapshot _snapshot() {
    final acc = {for (final id in _items.keys) id: _Acumulado()};

    for (final m in _movimientos) {
      final a = acc[m.itemId];
      if (a == null) continue;
      switch (m.tipo) {
        case TipoMovimiento.entregaProduccion:
          a.producido += m.cantidad;
          a.fechaEntrega = _masReciente(a.fechaEntrega, m.fecha);
        case TipoMovimiento.recepcion:
          a.recibido += m.cantidad;
          a.fechaRecepcion = _masReciente(a.fechaRecepcion, m.fecha);
          a.ubicaciones.update(m.ubicacion!, (v) => v + m.cantidad, ifAbsent: () => m.cantidad);
        case TipoMovimiento.despacho:
          a.despachado += m.cantidad;
          a.ubicaciones.update(m.ubicacion!, (v) => v - m.cantidad, ifAbsent: () => -m.cantidad);
        case TipoMovimiento.devolucionProduccion:
          a.producido -= m.cantidad;
          a.pendienteReproceso += m.cantidad;
        case TipoMovimiento.liberacionNoConforme:
          a.producido += m.cantidad;
          a.pendienteReproceso -= m.cantidad;
      }
    }

    final kardex = [
      for (final e in _items.entries) _aKardex(e.value, acc[e.key]!),
    ];

    return WmsSnapshot(
      kardex: List.unmodifiable(kardex),
      lotes: List.unmodifiable(_lotes),
    );
  }

  ItemKardex _aKardex(ItemOrden item, _Acumulado a) {
    return ItemKardex(
      item: item,
      producido: a.producido,
      recibido: a.recibido,
      despachado: a.despachado,
      ubicaciones: Map.unmodifiable({
        for (final e in a.ubicaciones.entries)
          if (e.value > 0) e.key: e.value,
      }),
      fechaEntrega: a.fechaEntrega,
      fechaRecepcion: a.fechaRecepcion,
      pendienteReproceso: a.pendienteReproceso,
    );
  }

  DateTime _masReciente(DateTime? actual, DateTime nueva) =>
      actual == null || nueva.isAfter(actual) ? nueva : actual;

  String _proximoNumero() {
    var n = _baseSecuencia;
    while (_lotes.any((l) => l.id == 'LOTE-$n')) {
      n++;
    }
    return 'LOTE-$n';
  }

  int _pendienteProduccion(String itemId) => _snapshot().kardexPorId(itemId)?.pendienteProduccion ?? 0;

  // -------------------------------------------------------------- comandos

  @override
  Future<Result<Lote>> crearLote({
    required List<ItemCantidad> items,
    required String operario,
    String? numeroLote,
  }) async {
    if (items.isEmpty) return Err<Lote>('El lote no tiene productos.');

    // Validar TODO antes de crear nada (todo o nada).
    for (final linea in items) {
      final item = _items[linea.itemId];
      if (item == null) return Err<Lote>('Uno de los productos del lote no existe en el kardex.');
      if (linea.cantidad <= 0) return Err<Lote>('Cantidad inválida en uno de los productos del lote.');
      final pendiente = _pendienteProduccion(linea.itemId);
      if (linea.cantidad > pendiente) {
        return Err<Lote>('LÍMITE EXCEDIDO en uno de los productos: solo faltan $pendiente Uds por producir.');
      }
    }

    var numero = (numeroLote ?? '').trim().toUpperCase();
    if (numero.isEmpty) {
      numero = _proximoNumero();
    } else if (_lotes.any((l) => l.id == numero)) {
      return Err<Lote>('El lote $numero ya existe.');
    }

    final lote = _aplicarEntregaLote(items, operario, numero, DateTime.now());
    _emitir();
    return Ok<Lote>(lote);
  }

  @override
  Future<Result<LoteLinea>> recibirLoteLinea({
    required String loteLineaId,
    required int cantidad,
    required String ubicacion,
    String nota = '',
  }) async {
    Lote? loteEncontrado;
    LoteLinea? lineaEncontrada;
    for (final lote in _lotes) {
      for (final linea in lote.lineas) {
        if (linea.id == loteLineaId) {
          loteEncontrado = lote;
          lineaEncontrada = linea;
          break;
        }
      }
      if (lineaEncontrada != null) break;
    }
    if (loteEncontrado == null || lineaEncontrada == null) {
      return Err<LoteLinea>('La línea del lote no existe.');
    }
    if (!lineaEncontrada.enTransito) {
      return Err<LoteLinea>('Esta línea ya fue recibida.');
    }
    if (cantidad <= 0) return Err<LoteLinea>('La cantidad debe ser mayor a 0.');
    if (!WmsConstantes.ubicaciones.contains(ubicacion)) {
      return Err<LoteLinea>('Ubicación no válida: $ubicacion.');
    }

    final diff = cantidad - lineaEncontrada.cantidadEnviada;
    var novedad = '';
    if (diff < 0) {
      novedad = 'FALTANTE: Se recibieron $cantidad de ${lineaEncontrada.cantidadEnviada} Uds (faltaron ${-diff}).';
    } else if (diff > 0) {
      novedad = 'SOBRANTE: Se recibieron $cantidad de ${lineaEncontrada.cantidadEnviada} Uds (+$diff).';
    }
    final obs = nota.trim();
    if (obs.isNotEmpty) {
      novedad = novedad.isEmpty ? 'Obs: $obs' : '$novedad Obs: $obs';
    }

    final lineaActualizada = _aplicarRecepcionLinea(
      loteEncontrado, lineaEncontrada, cantidad, ubicacion, novedad, DateTime.now(),
    );
    _emitir();
    return Ok<LoteLinea>(lineaActualizada);
  }

  @override
  Future<Result<void>> despachar({
    required String itemId,
    required int cantidad,
    required String ubicacion,
  }) async {
    final item = _items[itemId];
    if (item == null) return Err<void>('El producto no existe en el kardex.');
    if (cantidad <= 0) return Err<void>('La cantidad debe ser mayor a 0.');

    final kardex = _snapshot().kardexPorId(itemId)!;
    final stock = kardex.stockEn(ubicacion);
    if (cantidad > stock) {
      return Err<void>('Stock insuficiente en $ubicacion (disponible: $stock).');
    }
    if (cantidad > kardex.pendienteDespacho) {
      return Err<void>(
        'LÍMITE EXCEDIDO: solo faltan ${kardex.pendienteDespacho} Uds por despachar según la orden.',
      );
    }

    _aplicarDespacho(item, cantidad, ubicacion, DateTime.now());
    _emitir();
    return const Ok<void>(null);
  }

  @override
  Future<List<Causal>> cargarCausales() async => [
        for (final nombre in WmsConstantes.causales) Causal(id: nombre, nombre: nombre),
      ];

  @override
  Future<List<String>> cargarPersonalLogistica() async => List.unmodifiable(_personalLogistica);

  @override
  Future<Result<String>> agregarPersonalLogistica(String nombre) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) return Err<String>('El nombre no puede estar vacío.');
    final existente = _personalLogistica.firstWhere(
      (n) => n.toLowerCase() == limpio.toLowerCase(),
      orElse: () => '',
    );
    if (existente.isNotEmpty) return Ok<String>(existente);
    _personalLogistica.add(limpio);
    return Ok<String>(limpio);
  }

  @override
  Future<List<String>> cargarPersonalProduccion() async => List.unmodifiable(_personalProduccion);

  @override
  Future<Result<String>> agregarPersonalProduccion(String nombre) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) return Err<String>('El nombre no puede estar vacío.');
    final existente = _personalProduccion.firstWhere(
      (n) => n.toLowerCase() == limpio.toLowerCase(),
      orElse: () => '',
    );
    if (existente.isNotEmpty) return Ok<String>(existente);
    _personalProduccion.add(limpio);
    return Ok<String>(limpio);
  }

  @override
  Future<Result<void>> registrarNoConforme({
    required String itemId,
    required int cantidad,
    required String causalId,
    required String operario,
    required String recibidoDeProduccion,
    String nota = '',
  }) async {
    final item = _items[itemId];
    if (item == null) return Err<void>('El producto no existe en el kardex.');
    if (cantidad <= 0) return Err<void>('La cantidad debe ser mayor a 0.');
    if (recibidoDeProduccion.trim().isEmpty) {
      return Err<void>('Debes indicar quién de Producción entregó esta prenda.');
    }
    final producido = _snapshot().kardexPorId(itemId)?.producido ?? 0;
    if (cantidad > producido) {
      return Err<void>('LÍMITE EXCEDIDO: solo hay $producido Uds entregadas por Producción para este producto.');
    }

    final fecha = DateTime.now();
    _devoluciones.insert(
      0,
      Devolucion(
        id: 'DEV-${_correlativoDevolucion++}',
        item: item,
        cantidad: cantidad,
        causal: causalId, // en modo memoria, el id de la causal ES su nombre
        operario: operario,
        fecha: fecha,
        nota: nota,
        recibidoDeProduccion: recibidoDeProduccion.trim(),
      ),
    );
    _movimientos.add(Movimiento(
      tipo: TipoMovimiento.devolucionProduccion,
      itemId: item.id,
      cantidad: cantidad,
      fecha: fecha,
      nota: '$causalId${nota.trim().isEmpty ? '' : ' - ${nota.trim()}'}',
    ));
    _emitir();
    return const Ok<void>(null);
  }

  @override
  Future<List<Devolucion>> cargarDevoluciones() async => List.unmodifiable(_devoluciones);

  @override
  Future<Result<void>> liberarNoConforme({
    required String itemId,
    required int cantidad,
    required String operario,
    required String recibidoPorLogistica,
    String nota = '',
  }) async {
    final item = _items[itemId];
    if (item == null) return Err<void>('El producto no existe en el kardex.');
    if (cantidad <= 0) return Err<void>('La cantidad debe ser mayor a 0.');
    if (recibidoPorLogistica.trim().isEmpty) {
      return Err<void>('Debes indicar quién de Logística recibió esta prenda.');
    }
    final pendienteReproceso = _snapshot().kardexPorId(itemId)?.pendienteReproceso ?? 0;
    if (cantidad > pendienteReproceso) {
      return Err<void>('LÍMITE EXCEDIDO: solo hay $pendienteReproceso Uds pendientes por reprocesar.');
    }

    final fecha = DateTime.now();
    _liberaciones.insert(
      0,
      Liberacion(
        id: 'LIB-${_correlativoLiberacion++}',
        item: item,
        cantidad: cantidad,
        operario: operario,
        fecha: fecha,
        nota: nota,
        recibidoPorLogistica: recibidoPorLogistica.trim(),
      ),
    );

    // Crea un lote real (igual que una entrega normal) para que Bodega lo
    // reciba explícitamente por "Recibir lote", marcado como reproceso.
    final numero = _proximoNumero();
    final linea = LoteLinea(id: _nuevoIdLinea(), item: item, cantidadEnviada: cantidad, esReproceso: true);
    _lotes.insert(0, Lote(id: numero, operario: operario, fechaEnvio: fecha, lineas: [linea]));

    _movimientos.add(Movimiento(
      tipo: TipoMovimiento.liberacionNoConforme,
      itemId: item.id,
      cantidad: cantidad,
      fecha: fecha,
      loteId: numero,
      nota: nota,
    ));
    _emitir();
    return const Ok<void>(null);
  }

  @override
  Future<List<Liberacion>> cargarLiberaciones() async => List.unmodifiable(_liberaciones);

  // ------------------------------------------------ mutaciones sin validar
  // (usadas por los comandos y por la siembra de datos)

  int _correlativoLinea = 0;
  String _nuevoIdLinea() => 'LI-${_correlativoLinea++}';

  Lote _aplicarEntregaLote(List<ItemCantidad> items, String operario, String numero, DateTime fecha) {
    final lineas = <LoteLinea>[];
    for (final linea in items) {
      final item = _items[linea.itemId]!;
      lineas.add(LoteLinea(id: _nuevoIdLinea(), item: item, cantidadEnviada: linea.cantidad));
      _movimientos.add(Movimiento(
        tipo: TipoMovimiento.entregaProduccion,
        itemId: item.id,
        cantidad: linea.cantidad,
        fecha: fecha,
        loteId: numero,
      ));
    }
    final lote = Lote(id: numero, operario: operario, fechaEnvio: fecha, lineas: lineas);
    _lotes.insert(0, lote);
    return lote;
  }

  LoteLinea _aplicarRecepcionLinea(
    Lote lote, LoteLinea linea, int cantidad, String ubicacion, String novedad, DateTime fecha,
  ) {
    final lineaActualizada = linea.copyWith(
      estado: novedad.isEmpty ? EstadoLineaLote.recibidoConforme : EstadoLineaLote.recibidoConNovedad,
      cantidadRecibida: cantidad,
      ubicacionDestino: ubicacion,
      novedad: novedad,
      fechaRecepcion: fecha,
    );

    final idxLote = _lotes.indexWhere((l) => l.id == lote.id);
    final nuevasLineas = [
      for (final l in _lotes[idxLote].lineas) l.id == linea.id ? lineaActualizada : l,
    ];
    final pendientes = nuevasLineas.where((l) => l.enTransito).length;
    _lotes[idxLote] = Lote(
      id: lote.id,
      operario: lote.operario,
      fechaEnvio: lote.fechaEnvio,
      lineas: nuevasLineas,
      estado: pendientes == 0 ? EstadoLote.recibidoCompleto : EstadoLote.recibidoParcial,
    );

    if (cantidad > 0) {
      _movimientos.add(Movimiento(
        tipo: TipoMovimiento.recepcion,
        itemId: linea.item.id,
        cantidad: cantidad,
        fecha: fecha,
        ubicacion: ubicacion,
        loteId: lote.id,
        loteLineaId: linea.id,
        nota: novedad,
      ));
    }
    return lineaActualizada;
  }

  void _aplicarDespacho(ItemOrden item, int cantidad, String ubicacion, DateTime fecha) {
    _movimientos.add(Movimiento(
      tipo: TipoMovimiento.despacho,
      itemId: item.id,
      cantidad: cantidad,
      fecha: fecha,
      ubicacion: ubicacion,
    ));
  }

  // ---------------------------------------------------------------- datos demo

  void _sembrar() {
    final xs = ItemOrden(
      id: buildItemId('19249', 'ORD-001-ENE', '2025289514', 'XS'),
      op: '19249', cliente: 'ENEL', oc: 'ORD-001-ENE', codigo: '2025289514',
      descripcion: 'TSHIRT MANGA CORTA', talla: 'XS', cantidadPedida: 9,
      observacionOp: 'MARQUILLA DOT TEJIDA 2025 - PECHO IZQ',
    );
    final s = ItemOrden(
      id: buildItemId('19249', 'ORD-001-ENE', '2025289515', 'S'),
      op: '19249', cliente: 'ENEL', oc: 'ORD-001-ENE', codigo: '2025289515',
      descripcion: 'TSHIRT MANGA CORTA', talla: 'S', cantidadPedida: 264,
      observacionOp: 'TELA AZUL CONFECCIÓN NORMAL - CUELLO REDONDO',
    );
    final m = ItemOrden(
      id: buildItemId('19249', 'ORD-001-ENE', '2025289516', 'M'),
      op: '19249', cliente: 'ENEL', oc: 'ORD-001-ENE', codigo: '2025289516',
      descripcion: 'TSHIRT MANGA CORTA', talla: 'M', cantidadPedida: 841,
      observacionOp: 'DESPACHO PRIORITARIO BOGOTÁ',
    );
    final blusa = ItemOrden(
      id: buildItemId('18348', 'OC-40012', 'MTHBMMCCV', 'M'),
      op: '18348', cliente: 'MEDICALL', oc: 'OC-40012', codigo: 'MTHBMMCCV',
      descripcion: 'BLUSA MUJER', talla: 'M', cantidadPedida: 160,
      observacionOp: 'BORDADO EN BOLSILLO DELANTERO',
    );
    final bata = ItemOrden(
      id: buildItemId('18353', 'OC-9920', 'CLSBAOCD20', 'L'),
      op: '18353', cliente: 'COLSUBSIDIO', oc: 'OC-9920', codigo: 'CLSBAOCD20',
      descripcion: 'BATA MÉDICA', talla: 'L', cantidadPedida: 45,
      observacionOp: 'BOTONES ANTIFLUIDO BLANCO',
    );
    for (final i in [xs, s, m, blusa, bata]) {
      _items[i.id] = i;
    }

    const op = 'OPERARIO CONFECCIÓN 1';

    // MEDICALL: 160 producidas, recibidas y despachadas por completo.
    final lote095 = _aplicarEntregaLote(
      [ItemCantidad(itemId: blusa.id, cantidad: 160)], op, 'LOTE-095', DateTime(2026, 8, 15, 10),
    );
    _aplicarRecepcionLinea(lote095, lote095.lineas.first, 160, 'ESTANTE A1', '', DateTime(2026, 8, 16, 11, 20));
    _aplicarDespacho(blusa, 160, 'ESTANTE A1', DateTime(2026, 8, 16, 15));

    // ENEL M + ENEL S (100 producidas de golpe): un lote con 2 productos,
    // para que el modo demo también muestre un lote agrupado.
    final lote096 = _aplicarEntregaLote(
      [ItemCantidad(itemId: m.id, cantidad: 841), ItemCantidad(itemId: s.id, cantidad: 50)],
      op, 'LOTE-096', DateTime(2026, 8, 17, 15),
    );
    _aplicarRecepcionLinea(
      lote096, lote096.lineas[0], 841, 'ESTANTE B2', '', DateTime(2026, 8, 17, 16),
    );
    _aplicarRecepcionLinea(
      lote096, lote096.lineas[1], 50, 'ESTANTE A1', '', DateTime(2026, 8, 17, 19, 15),
    );
    _aplicarDespacho(s, 20, 'ESTANTE A1', DateTime(2026, 8, 17, 20));
    _aplicarEntregaLote([ItemCantidad(itemId: s.id, cantidad: 50)], op, 'LOTE-102', DateTime(2026, 8, 18, 9));

    // ENEL XS: 9 producidas (5 recibidas + 4 en tránsito).
    final lote098 = _aplicarEntregaLote(
      [ItemCantidad(itemId: xs.id, cantidad: 5)], op, 'LOTE-098', DateTime(2026, 8, 17, 17, 30),
    );
    _aplicarRecepcionLinea(lote098, lote098.lineas.first, 5, 'ESTANTE A1', '', DateTime(2026, 8, 17, 18, 30));
    _aplicarEntregaLote([ItemCantidad(itemId: xs.id, cantidad: 4)], op, 'LOTE-101', DateTime(2026, 8, 17, 18, 30));

    // COLSUBSIDIO: 20 producidas, en tránsito.
    _aplicarEntregaLote([ItemCantidad(itemId: bata.id, cantidad: 20)], op, 'LOTE-103', DateTime(2026, 8, 20, 8));
  }
}
ORBILOQ_EOF

echo "  - test/wms_rules_test.dart"
mkdir -p "$(dirname 'test/wms_rules_test.dart')"
cat > 'test/wms_rules_test.dart' << 'ORBILOQ_EOF'
import 'dart:typed_data';

import 'package:excel/excel.dart' as xlsx;
import 'package:flutter_test/flutter_test.dart';

import 'package:orbiloq_wms/core/result.dart';
import 'package:orbiloq_wms/data/excel_ordenes_parser.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/domain/qr_prenda.dart';

const _xs = '19249|ORD-001-ENE|2025289514|XS'; // pedida 9, producido 9 (límite alcanzado)
const _s = '19249|ORD-001-ENE|2025289515|S'; // pedida 264, producido 100, stock A1 = 30
const _bata = '18353|OC-9920|CLSBAOCD20|L'; // pedida 45, producido 20, pendiente 25

void main() {
  group('QrPrenda', () {
    test('parsea un QR válido con el formato real de la marquilla', () {
      final qr = QrPrenda.tryParse(
        'https://orbiloq.app/qr?;19249;2025289514;TSHIRT MANGA CORTA T. XS;ENEL;ORD-001-ENE;ID0001',
      );
      expect(qr, isNotNull);
      expect(qr!.op, '19249');
      expect(qr.codigo, '2025289514');
      expect(qr.cliente, 'ENEL');
      expect(qr.noOc, 'ORD-001-ENE');
    });

    test('parsea un QR real donde la OP queda pegada a la URL, sin ; de por medio', () {
      // Caso real detectado: el '?' no va seguido de ';', la OP queda directo
      // pegada al final de la URL.
      final qr = QrPrenda.tryParse(
        'https://www.atom.bio/grupoquiromarsas?25079;202674809;'
        'BLUSA ADMINISTRATIVA DAMA  T. S/8;TV COLOMBIA DIGITAL;PEDIDO AGOSTO;ID0016',
      );
      expect(qr, isNotNull);
      expect(qr!.op, '25079');
      expect(qr.codigo, '202674809');
      expect(qr.cliente, 'TV COLOMBIA DIGITAL');
      expect(qr.noOc, 'PEDIDO AGOSTO');
    });

    test('rechaza QR incompleto o con OP/Código vacíos', () {
      expect(QrPrenda.tryParse('url;ENEL'), isNull);
      expect(QrPrenda.tryParse('url;;2025289514;TSHIRT;ENEL;ORD-001-ENE'), isNull);
    });
  });

  group('Reglas de negocio', () {
    late InMemoryWmsRepository repo;

    setUp(() => repo = InMemoryWmsRepository.seeded());
    tearDown(() => repo.dispose());

    Future<ItemKardex> kardex(String id) async =>
        (await repo.watch().first).kardexPorId(id)!;

    test('producción no puede superar la cantidad pedida', () async {
      expect(await repo.crearLote(items: [ItemCantidad(itemId: _xs, cantidad: 1)], operario: 'X'), isA<Err>());
      expect(await repo.crearLote(items: [ItemCantidad(itemId: _s, cantidad: 165)], operario: 'X'), isA<Err>());
      expect(await repo.crearLote(items: [ItemCantidad(itemId: _s, cantidad: 164)], operario: 'X'), isA<Ok>());
    });

    test('no se entrega un producto inexistente ni cantidades <= 0', () async {
      expect(await repo.crearLote(items: [ItemCantidad(itemId: 'nope', cantidad: 1)], operario: 'X'), isA<Err>());
      expect(await repo.crearLote(items: [ItemCantidad(itemId: _s, cantidad: 0)], operario: 'X'), isA<Err>());
    });

    test('no permite lotes duplicados', () async {
      final r = await repo.crearLote(
        items: [ItemCantidad(itemId: _s, cantidad: 1)], operario: 'X', numeroLote: 'LOTE-096',
      );
      expect(r, isA<Err>());
    });

    test('crear_lote es todo o nada: si un producto falla, no se crea ninguna línea', () async {
      final antes = await kardex(_xs);
      final res = await repo.crearLote(
        items: [
          ItemCantidad(itemId: _s, cantidad: 1), // válido por sí solo
          ItemCantidad(itemId: _xs, cantidad: 999), // excede el límite
        ],
        operario: 'X',
      );
      expect(res, isA<Err>());
      final despues = await kardex(_xs);
      expect(despues.producido, antes.producido); // nada cambió, ni siquiera lo válido
    });

    test('la numeración automática no colisiona', () async {
      final a = await repo.crearLote(items: [ItemCantidad(itemId: _s, cantidad: 1)], operario: 'X');
      final b = await repo.crearLote(items: [ItemCantidad(itemId: _s, cantidad: 1)], operario: 'X');
      expect((a as Ok<Lote>).value.id, isNot((b as Ok<Lote>).value.id));
    });

    test('un lote con varias líneas queda parcial hasta que se reciben todas sus líneas', () async {
      final creado = await repo.crearLote(
        items: [ItemCantidad(itemId: _s, cantidad: 5), ItemCantidad(itemId: _bata, cantidad: 5)],
        operario: 'X',
      );
      final lote = (creado as Ok<Lote>).value;
      expect(lote.lineas.length, 2);
      expect(lote.lineasPendientes, 2);

      await repo.recibirLoteLinea(loteLineaId: lote.lineas[0].id, cantidad: 5, ubicacion: 'ESTANTE A1');
      final snap1 = await repo.watch().first;
      expect(snap1.lotes.firstWhere((l) => l.id == lote.id).estado, EstadoLote.recibidoParcial);

      await repo.recibirLoteLinea(loteLineaId: lote.lineas[1].id, cantidad: 5, ubicacion: 'ESTANTE A1');
      final snap2 = await repo.watch().first;
      expect(snap2.lotes.firstWhere((l) => l.id == lote.id).estado, EstadoLote.recibidoCompleto);
    });

    test('la recepción con faltante genera novedad y actualiza el stock', () async {
      final snap = await repo.watch().first;
      final linea = snap.lotes.firstWhere((l) => l.id == 'LOTE-101').lineas.first;

      final res = await repo.recibirLoteLinea(loteLineaId: linea.id, cantidad: 3, ubicacion: 'RACK C3');
      final actualizada = (res as Ok<LoteLinea>).value;
      expect(actualizada.estado, EstadoLineaLote.recibidoConNovedad);
      expect(actualizada.novedad, contains('FALTANTE'));

      final k = await kardex(_xs);
      expect(k.recibido, 8);
      expect(k.stockEn('RACK C3'), 3);
    });

    test('una línea de lote no se puede recibir dos veces', () async {
      final snap = await repo.watch().first;
      final linea = snap.lotes.firstWhere((l) => l.id == 'LOTE-101').lineas.first;

      await repo.recibirLoteLinea(loteLineaId: linea.id, cantidad: 4, ubicacion: 'RACK C3');
      final again = await repo.recibirLoteLinea(loteLineaId: linea.id, cantidad: 4, ubicacion: 'RACK C3');
      expect(again, isA<Err>());
    });

    test('recibir con cantidad 0 se rechaza y la línea sigue pendiente (regresión)', () async {
      final snap = await repo.watch().first;
      final linea = snap.lotes.firstWhere((l) => l.id == 'LOTE-101').lineas.first;

      final res = await repo.recibirLoteLinea(loteLineaId: linea.id, cantidad: 0, ubicacion: 'RACK C3');
      expect(res, isA<Err>());

      // La línea no debe haber cambiado de estado ni haberse "cerrado".
      final snapDespues = await repo.watch().first;
      final lineaDespues = snapDespues.lotes.firstWhere((l) => l.id == 'LOTE-101').lineas.first;
      expect(lineaDespues.enTransito, isTrue);
      expect(lineaDespues.cantidadRecibida, isNull);

      // Tampoco debe haber sumado nada al recibido del kardex.
      final k = await kardex(_xs);
      expect(k.recibido, 5); // el seed ya tenía 5 recibidas antes de este intento
    });

    test('el despacho valida el stock de la ubicación', () async {
      expect(await repo.despachar(itemId: _s, cantidad: 31, ubicacion: 'ESTANTE A1'), isA<Err>());
      expect(await repo.despachar(itemId: _s, cantidad: 1, ubicacion: 'RACK C3'), isA<Err>());
      expect(await repo.despachar(itemId: _s, cantidad: 30, ubicacion: 'ESTANTE A1'), isA<Ok>());

      final k = await kardex(_s);
      expect(k.despachado, 50);
      expect(k.stockDisponible, 0);
      expect(k.ubicaciones.containsKey('ESTANTE A1'), isFalse);
    });

    test('stockDisponible siempre coincide con la suma de ubicaciones', () async {
      final snap = await repo.watch().first;
      for (final k in snap.kardex) {
        expect(k.ubicaciones.values.fold<int>(0, (a, b) => a + b), k.stockDisponible);
      }
    });
  });

  group('ExcelOrdenesParser (bytes reales de .xlsx)', () {
    // Esta prueba existe porque un bug real (encabezados que no se
    // reconocían por diferencias de mayúsculas/tildes) pasó sin detectarse
    // porque nunca se probó el parser contra un archivo Excel de verdad,
    // solo contra texto. Aquí se construye un .xlsx real en memoria.
    List<int> construirXlsxDePrueba() {
      final libro = xlsx.Excel.createExcel();

      final orden = libro['Orden'];
      // Encabezados con mayúsculas/espacios distintos a los del diccionario
      // interno, a propósito, para probar la normalización.
      orden.appendRow([
        xlsx.TextCellValue('IDENTIFICADOR'),
        xlsx.TextCellValue(' Cliente '),
        xlsx.TextCellValue('CANTIDAD'),
      ]);
      orden.appendRow([
        xlsx.IntCellValue(25079),
        xlsx.TextCellValue('TV COLOMBIA DIGITAL'),
        xlsx.IntCellValue(15),
      ]);

      final tallas = libro['Tallas'];
      tallas.appendRow([
        xlsx.TextCellValue('identificador orden'), // minúsculas
        xlsx.TextCellValue('CODIGO'), // sin tilde, mayúsculas (la clave real es "Código")
        xlsx.TextCellValue('TALLAS NOMBRE'),
        xlsx.TextCellValue('cantidad'),
      ]);
      tallas.appendRow([
        xlsx.IntCellValue(25079),
        // Código como celda numérica con decimales, para probar que no
        // quede guardado como "202674809.0".
        xlsx.DoubleCellValue(202674809),
        xlsx.TextCellValue('S/8'),
        xlsx.IntCellValue(15),
      ]);

      libro.delete('Sheet1');
      final bytes = libro.encode();
      if (bytes == null) {
        fail('No se pudo generar el .xlsx de prueba');
      }
      return bytes;
    }

    test('reconoce encabezados aunque vengan con mayúsculas/tildes distintas', () {
      final bytes = Uint8List.fromList(construirXlsxDePrueba());
      final parseado = ExcelOrdenesParser.parsear(bytes);

      expect(parseado.ordenes.length, 1);
      expect(parseado.ordenes.first['identificador'], '25079');
      expect(parseado.ordenes.first['cliente'], 'TV COLOMBIA DIGITAL');

      expect(parseado.tallas.length, 1);
      expect(parseado.tallas.first['identificador_orden'], '25079');
      expect(parseado.tallas.first['talla'], 'S/8');
    });

    test('un código numérico no queda con ".0" pegado al final', () {
      final bytes = Uint8List.fromList(construirXlsxDePrueba());
      final parseado = ExcelOrdenesParser.parsear(bytes);

      expect(parseado.tallas.first['codigo'], '202674809');
    });

    test('avisa claramente si falta una columna requerida, en vez de fallar en silencio', () {
      final libro = xlsx.Excel.createExcel();
      final orden = libro['Orden'];
      // Sin columna "Identificador": debe fallar de forma explícita.
      orden.appendRow([xlsx.TextCellValue('Cliente'), xlsx.TextCellValue('Cantidad')]);
      orden.appendRow([xlsx.TextCellValue('ACME'), xlsx.IntCellValue(1)]);
      libro['Tallas'].appendRow([xlsx.TextCellValue('Identificador orden')]);
      libro.delete('Sheet1');
      final bytes = Uint8List.fromList(libro.encode()!);

      expect(
        () => ExcelOrdenesParser.parsear(bytes),
        throwsA(isA<ExcelOrdenesParseException>()),
      );
    });
  });
}
ORBILOQ_EOF

echo ""
echo "Listo. flutter analyze / flutter test"
