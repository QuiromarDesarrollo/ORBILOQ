import '../../../application/auth_providers.dart';
import '../../../shared/widgets/operario_actual.dart';
import '../../../shared/widgets/historial_agrupado.dart';
import '../../../shared/widgets/catalogo_ubicacion_dropdown.dart';
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
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/status_chip.dart';
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

class RecepcionDialog extends StatelessWidget {
  const RecepcionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return WmsDialogShell(
      title: 'RECEPCIÓN Y REPORTE DE NOVEDADES',
      icon: Icons.move_to_inbox,
      iconColor: AppColors.primaryNavy,
      expand: true,
      maxWidth: 1000,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primaryNavy,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primaryNavy,
              labelPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              unselectedLabelStyle: TextStyle(fontSize: 11),
              tabs: [
                Tab(height: 38, icon: Icon(Icons.move_to_inbox_outlined, size: 16), text: 'PENDIENTES'),
                Tab(height: 38, icon: Icon(Icons.history, size: 16), text: 'HISTORIAL'),
              ],
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
      _ubicacion = '';
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
    if(!(ref.read(ubicacionesProvider).value??[]).contains(_ubicacion)){
      setState(()=>_msg=const FeedbackMessage.error('Selecciona un estante activo antes de recibir.'));
      return;
    }
    final cantidad = int.tryParse(_cantidadCtrl.text.trim());
    if (cantidad == null || cantidad <= 0) {
      setState(() => _msg = const FeedbackMessage.error('Ingresa una cantidad mayor a 0 para confirmar la recepción.'));
      return;
    }
    if (_recibidoPor == null || _recibidoPor!.trim().isEmpty) {
      setState(() => _msg = const FeedbackMessage.error('Selecciona quién de Logística está recibiendo.'));
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
          recibidoPor: _recibidoPor!,
          nota: _notaCtrl.text,
        );
    if (!mounted) return;

    switch (res) {
      case Ok(:final value):
        setState(() {
          _confirmando = false;
          if (value.enTransito) {
            // Recepción parcial: la tarjeta se queda en Pendientes.
            _msg = FeedbackMessage.ok(
              '${linea.item.codigo} (${linea.item.talla}): recibidas $cantidad Uds — faltan ${value.cantidadPendiente} Uds.',
            );
            _cantidadCtrl.text = '0';
            _conteos[linea.id] = 0;
          } else {
            _msg = FeedbackMessage.ok(
              '${linea.item.codigo} (${linea.item.talla}): ${value.estado.etiqueta}. Ingresada a $_ubicacion.',
            );
            _lineaAbiertaId = null;
            _ordenManual.remove(linea.id);
            _conteos.remove(linea.id);
          }
        });
      case Err(:final message):
        setState(() {
          _confirmando = false;
          _msg = FeedbackMessage.error(message);
        });
    }
  }

  Future<void> _cerrarConFaltante(LoteLinea linea) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cerrar con faltante?'),
        content: Text(
          'Faltan ${linea.cantidadPendiente} Uds de ${linea.item.descripcion} (${linea.item.talla}) que nunca llegaron. '
          'Al cerrar, esas unidades van a volver a aparecer como pendientes por entregar en Producción. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('CERRAR CON FALTANTE', style: TextStyle(color: AppColors.alertRed)),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    if (!mounted) return;

    setState(() => _confirmando = true);
    final res = await ref.read(wmsRepositoryProvider).cerrarLoteItemConFaltante(
          loteLineaId: linea.id,
          nota: _notaCtrl.text,
        );
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reportar sobrante'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¿Cuántas unidades de más llegaron de ${linea.item.descripcion} (${linea.item.talla})?'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrlCantidad,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: wmsInput('Cantidad de sobra'),
            ),
            const SizedBox(height: 10),
            TextField(controller: ctrlNota, decoration: wmsInput('Nota (opcional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('CANCELAR')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('REGISTRAR')),
        ],
      ),
    );
    if (confirmado != true) return;
    final cantidad = int.tryParse(ctrlCantidad.text.trim());
    if (cantidad == null || cantidad <= 0) {
      if (!mounted) return;
      setState(() => _msg = const FeedbackMessage.error('Ingresa una cantidad de sobrante mayor a 0.'));
      return;
    }
    if (!mounted) return;

    final res = await ref.read(wmsRepositoryProvider).registrarSobrante(
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

  @override
  Widget build(BuildContext context) {
    // Se observa el snapshot para reconstruir cuando cambian los lotes.
    ref.watch(wmsSnapshotProvider);
    final pendientes = _ordenar(_todasPendientes);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_msg != null) ...[
              FeedbackBanner(message: _msg!),
              const SizedBox(height: 12),
            ],
            const OperarioActual(label: 'Recibido por (Logística)'),
            const SizedBox(height: 10),
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
                            onCerrarConFaltante: () => _cerrarConFaltante(e.linea),
                            onReportarSobrante: () => _reportarSobrante(e.linea),
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
    );
  }
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
    required this.onCerrarConFaltante,
    required this.onReportarSobrante,
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
  final VoidCallback onCerrarConFaltante;
  final VoidCallback onReportarSobrante;

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
            ResponsiveRow(
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
                      if ((linea.cantidadRecibida ?? 0) > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              'Ya recibidas: ${linea.cantidadRecibida} · Faltan: ${linea.cantidadPendiente} Uds',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                            ),
                          ),
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
                  child: ResponsiveRow(
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
              ResponsiveRow(
                children: [
                  Expanded(
                    flex: 2,
                    child: CatalogoUbicacionDropdown(
                      label: 'Estante físico',
                      value: ubicacion,

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
                        _MaxValorFormatter(linea.cantidadPendiente),
                      ],
                      decoration: wmsInput('Cant. a recibir ahora (máx ${linea.cantidadPendiente})'),
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
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
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
                  OutlinedButton.icon(
                    onPressed: onReportarSobrante,
                    icon: const Icon(Icons.add_box_outlined, size: 18),
                    label: const Text('¿Llegó de más? Reportar sobrante'),
                  ),
                  if ((linea.cantidadRecibida ?? 0) > 0)
                    TextButton.icon(
                      onPressed: onCerrarConFaltante,
                      icon: const Icon(Icons.block, size: 18, color: AppColors.alertRed),
                      label: const Text('Cerrar con faltante', style: TextStyle(color: AppColors.alertRed)),
                    ),
                ],
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

// ==================================================== pestaña 2: historial
// Reutiliza datos que YA están cargados en memoria (WmsSnapshot.lotes trae
// todo, no solo lo pendiente) — no hace ninguna consulta nueva.

class _HistorialTab extends ConsumerWidget {
  const _HistorialTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lotes = ref.watch(wmsSnapshotProvider).value?.lotes ?? const <Lote>[];
    final registros = [for (final lote in lotes) for (final linea in lote.lineas) if (!linea.enTransito || linea.fechaRecepcion != null || (linea.cantidadRecibida ?? 0) > 0) (lote: lote, linea: linea)];
    return HistorialAgrupado(grupos: agruparHistorial(registros, (e) => e.linea.item,
      (e) => EventoHistorial(id: e.linea.id, fecha: e.linea.fechaRecepcion, cantidad: e.linea.cantidadRecibida ?? 0,
        titulo: 'Recepción acumulada · ${e.linea.cantidadRecibida ?? 0} Uds · ${e.linea.estado.etiqueta}',
        detalle: 'Lote: ${e.lote.id} | Operario: ${e.lote.operario}\n'
          'Enviadas: ${e.linea.cantidadEnviada} Uds | Recibidas: ${e.linea.cantidadRecibida ?? 0} Uds | Estante: ${e.linea.ubicacionDestino ?? '—'}\n'
          'Última recepción registrada por: ${e.linea.recibidoPor.isEmpty ? 'Sin registrar' : e.linea.recibidoPor}'
          '${e.linea.novedad.isEmpty ? '' : '\nNovedad: ${e.linea.novedad}'}',
        color: colorDeEstadoLinea(e.linea.estado))));
  }
}
