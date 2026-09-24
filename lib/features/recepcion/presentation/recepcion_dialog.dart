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
          _msg = FeedbackMessage.ok(
            '${linea.item.codigo} (${linea.item.talla}): ${value.estado.etiqueta}. Ingresada a $_ubicacion.',
          );
          _lineaId = null;
          _conteo = 0;
        });
      case Err(:final message):
        setState(() => _msg = FeedbackMessage.error(message));
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
                    return Card(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ListTile(
                        dense: true,
                        title: Text('${l.id} — ${l.totalLineas} producto(s)',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    return Card(
                      color: sel ? Colors.blue.shade50 : Colors.white,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: sel ? AppColors.primaryNavy : Colors.grey.shade300, width: sel ? 2 : 1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          '${linea.item.codigo} (${linea.item.talla}) - ${linea.item.descripcion}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: wmsInput('Cant. validada'),
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
              child: ActionButton(
                icon: Icons.check_circle,
                label: 'INGRESAR A ESTANTE & CONFIRMAR',
                color: AppColors.actionGreen,
                onPressed: onConfirmar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
