#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Limite de cantidad maxima + loader con el logo (v32)
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_limite_loader_v32.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi
echo "Aplicando limite de cantidad + loader..."

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

class RecepcionDialog extends ConsumerStatefulWidget {
  const RecepcionDialog({super.key});

  @override
  ConsumerState<RecepcionDialog> createState() => _RecepcionDialogState();
}

class _RecepcionDialogState extends ConsumerState<RecepcionDialog> {
  final _scanLoteCtrl = TextEditingController();
  final _scanPrendaCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  final _scanPrendaFocus = FocusNode();

  String? _loteId;
  String? _lineaId;
  String _ubicacion = WmsConstantes.ubicaciones.first;
  int _conteo = 0;
  bool _confirmando = false;
  FeedbackMessage? _msg;

  @override
  void dispose() {
    _scanLoteCtrl.dispose();
    _scanPrendaCtrl.dispose();
    _cantidadCtrl.dispose();
    _notaCtrl.dispose();
    _scanPrendaFocus.dispose();
    super.dispose();
  }

  List<Lote> get _lotesEnTransito =>
      (ref.read(wmsSnapshotProvider).value?.lotes ?? const <Lote>[]).where((l) => l.tienePendientes).toList();

  void _seleccionarLote(Lote l) {
    setState(() {
      _loteId = l.id;
      _lineaId = null;
      _msg = null;
    });
  }

  void _volverALotes() {
    setState(() {
      _loteId = null;
      _lineaId = null;
      _msg = null;
    });
  }

  void _seleccionarLinea(LoteLinea l) {
    setState(() {
      _lineaId = l.id;
      _cantidadCtrl.text = '${l.cantidadEnviada}';
      _conteo = 0;
      _notaCtrl.clear();
      _msg = null;
    });
  }

  void _procesarScanLote(String raw) {
    final query = raw.trim().toUpperCase();
    _scanLoteCtrl.clear();
    if (query.isEmpty) return;
    final coincidencias = _lotesEnTransito.where(
      (l) => l.id.toUpperCase() == query || l.lineas.any((linea) => linea.item.op == query),
    );
    if (coincidencias.isEmpty) {
      setState(() => _msg = const FeedbackMessage.error('Lote no encontrado en tránsito.'));
      return;
    }
    _seleccionarLote(coincidencias.first);
  }

  void _procesarScanPrenda(String raw, LoteLinea linea) {
    _scanPrendaCtrl.clear();
    if (raw.trim().isEmpty) return;
    final qr = QrPrenda.tryParse(raw);
    if (qr == null) {
      setState(() => _msg = FeedbackMessage.error('QR inválido. Formato esperado: ${QrPrenda.formato}'));
    } else if (qr.op != linea.item.op || qr.codigo != linea.item.codigo) {
      setState(() => _msg = const FeedbackMessage.error('La prenda NO corresponde a esta línea.'));
    } else {
      setState(() {
        _conteo++;
        _cantidadCtrl.text = '$_conteo';
        _msg = null;
      });
    }
    _scanPrendaFocus.requestFocus();
  }

  Future<void> _confirmar(LoteLinea linea) async {
    final cantidad = int.tryParse(_cantidadCtrl.text.trim());
    if (cantidad == null) {
      setState(() => _msg = const FeedbackMessage.error('Ingresa una cantidad válida.'));
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
          _lineaId = null;
          _conteo = 0;
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
    final lotesEnTransito = _lotesEnTransito;
    final loteSeleccionado = lotesEnTransito.where((l) => l.id == _loteId).firstOrNull;
    final lineasPendientes = loteSeleccionado?.lineas.where((l) => l.enTransito).toList() ?? const [];
    final lineaSeleccionada = lineasPendientes.where((l) => l.id == _lineaId).firstOrNull;

    return WmsDialogShell(
      title: 'RECEPCIÓN DE LOTES Y REPORTE DE NOVEDADES',
      icon: Icons.move_to_inbox,
      iconColor: AppColors.primaryNavy,
      maxWidth: 1000,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msg != null) ...[
            FeedbackBanner(message: _msg!),
            const SizedBox(height: 12),
          ],
          if (loteSeleccionado == null) ...[
            TextField(
              controller: _scanLoteCtrl,
              autofocus: true,
              decoration: wmsInput('ESCANEAR LOTE O BUSCAR OP (Ej. LOTE-101)', icon: Icons.qr_code_scanner),
              onSubmitted: _procesarScanLote,
            ),
            const SizedBox(height: 12),
            if (lotesEnTransito.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('No hay lotes pendientes.', style: TextStyle(color: Colors.grey))),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: lotesEnTransito.length,
                  itemBuilder: (_, i) {
                    final l = lotesEnTransito[i];
                    final esReproceso = l.lineas.any((li) => li.esReproceso);
                    return Card(
                      color: esReproceso ? Colors.amber.shade50 : null,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: esReproceso ? Colors.amber.shade700 : Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ListTile(
                        dense: true,
                        title: Row(
                          children: [
                            Flexible(
                              child: Text('${l.id} — ${l.totalLineas} producto(s)',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            if (esReproceso) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade700,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('REPROCESO',
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text('Envía: ${l.operario} | ${l.lineasPendientes} pendiente(s) por recibir'),
                        trailing: ActionButton(
                          icon: Icons.qr_code,
                          label: 'ABRIR',
                          color: AppColors.primaryNavy,
                          onPressed: () => _seleccionarLote(l),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ] else ...[
            Row(
              children: [
                IconButton(
                  tooltip: 'Volver a la lista de lotes',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _volverALotes,
                ),
                Expanded(
                  child: Text(
                    '${loteSeleccionado.id} — ${loteSeleccionado.operario}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy),
                  ),
                ),
              ],
            ),
            const Divider(),
            if (lineasPendientes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('Ya se recibieron todas las líneas de este lote.',
                    style: TextStyle(color: Colors.grey))),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: lineasPendientes.length,
                  itemBuilder: (_, i) {
                    final linea = lineasPendientes[i];
                    final sel = linea.id == _lineaId;
                    final colorBase = linea.esReproceso ? Colors.amber.shade50 : Colors.white;
                    return Card(
                      color: sel ? Colors.blue.shade50 : colorBase,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: sel
                              ? AppColors.primaryNavy
                              : linea.esReproceso
                                  ? Colors.amber.shade700
                                  : Colors.grey.shade300,
                          width: sel ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ListTile(
                        dense: true,
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${linea.item.codigo} (${linea.item.talla}) - ${linea.item.descripcion}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (linea.esReproceso) ...[
                              const SizedBox(width: 8),
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
                          ],
                        ),
                        subtitle: Text('OP: ${linea.item.op} | OC: ${linea.item.oc} | ${linea.cantidadEnviada} Uds'),
                        trailing: ActionButton(
                          icon: Icons.qr_code,
                          label: 'VALIDAR',
                          color: AppColors.primaryNavy,
                          onPressed: () => _seleccionarLinea(linea),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (lineaSeleccionada != null) ...[
              const SizedBox(height: 12),
              _Validacion(
                linea: lineaSeleccionada,
                scanCtrl: _scanPrendaCtrl,
                scanFocus: _scanPrendaFocus,
                cantidadCtrl: _cantidadCtrl,
                notaCtrl: _notaCtrl,
                ubicacion: _ubicacion,
                confirmando: _confirmando,
                onUbicacion: (v) => setState(() => _ubicacion = v),
                onScan: (raw) => _procesarScanPrenda(raw, lineaSeleccionada),
                onConfirmar: () => _confirmar(lineaSeleccionada),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Impide que el campo acepte un número mayor al máximo permitido — rechaza
/// la edición en vez de solo recortar, para que no "salte" a un valor raro.
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _Validacion extends StatelessWidget {
  const _Validacion({
    required this.linea,
    required this.scanCtrl,
    required this.scanFocus,
    required this.cantidadCtrl,
    required this.notaCtrl,
    required this.ubicacion,
    required this.confirmando,
    required this.onUbicacion,
    required this.onScan,
    required this.onConfirmar,
  });

  final LoteLinea linea;
  final TextEditingController scanCtrl;
  final FocusNode scanFocus;
  final TextEditingController cantidadCtrl;
  final TextEditingController notaCtrl;
  final String ubicacion;
  final bool confirmando;
  final ValueChanged<String> onUbicacion;
  final ValueChanged<String> onScan;
  final VoidCallback onConfirmar;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'VALIDACIÓN: ${linea.item.codigo} (Declarado: ${linea.cantidadEnviada} Uds)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy),
            ),
            if (linea.esReproceso) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    Icon(Icons.autorenew, size: 16, color: Colors.amber.shade900),
                    const SizedBox(width: 6),
                    Text(
                      'Esta prenda era producto no conforme, ya fue reprocesada por Producción.',
                      style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.w600, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(),
            TextField(
              controller: scanCtrl,
              focusNode: scanFocus,
              decoration: wmsInput('PISTOLEADO 1 A 1 PARA RECONTEO (SUBE CONTADOR)', icon: Icons.flash_on),
              onSubmitted: onScan,
            ),
            const SizedBox(height: 10),
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
                onPressed: confirmando ? null : onConfirmar,
                icon: confirmando
                    ? const _LogoLoader(size: 18)
                    : const Icon(Icons.check_circle, color: Colors.white, size: 20),
                label: Text(confirmando ? 'PROCESANDO…' : 'INGRESAR A ESTANTE & CONFIRMAR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.actionGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.actionGreen.withValues(alpha: 0.7),
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo de ORBILOQ girando, usado como loader mientras se procesa una acción.
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
        child: Image.asset(
          'assets/images/logo_orbiloq.png',
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => SizedBox(
            width: widget.size,
            height: widget.size,
            child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
ORBILOQ_EOF

echo ""
echo "Listo. flutter analyze"
