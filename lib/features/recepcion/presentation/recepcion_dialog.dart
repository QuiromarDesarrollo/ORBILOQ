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
  final _scanRemisionCtrl = TextEditingController();
  final _scanPrendaCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  final _scanPrendaFocus = FocusNode();

  String? _remisionId;
  String _ubicacion = WmsConstantes.ubicaciones.first;
  int _conteo = 0;
  FeedbackMessage? _msg;

  @override
  void dispose() {
    _scanRemisionCtrl.dispose();
    _scanPrendaCtrl.dispose();
    _cantidadCtrl.dispose();
    _notaCtrl.dispose();
    _scanPrendaFocus.dispose();
    super.dispose();
  }

  List<Remision> get _enTransito =>
      (ref.read(wmsSnapshotProvider).value?.remisiones ?? const <Remision>[]).where((r) => r.enTransito).toList();

  void _seleccionar(Remision r) {
    setState(() {
      _remisionId = r.id;
      _cantidadCtrl.text = '${r.cantidadEnviada}';
      _conteo = 0;
      _notaCtrl.clear();
      _msg = null;
    });
  }

  void _procesarScanRemision(String raw) {
    final query = raw.trim().toUpperCase();
    _scanRemisionCtrl.clear();
    if (query.isEmpty) return;
    final coincidencias = _enTransito.where((r) => r.id.toUpperCase() == query || r.item.op == query);
    if (coincidencias.isEmpty) {
      setState(() => _msg = const FeedbackMessage.error('Lote no encontrado en tránsito.'));
      return;
    }
    _seleccionar(coincidencias.first);
  }

  void _procesarScanPrenda(String raw, Remision remision) {
    _scanPrendaCtrl.clear();
    if (raw.trim().isEmpty) return;
    final qr = QrPrenda.tryParse(raw);
    if (qr == null) {
      setState(() => _msg = FeedbackMessage.error('QR inválido. Formato esperado: ${QrPrenda.formato}'));
    } else if (qr.itemId != remision.item.id) {
      setState(() => _msg = const FeedbackMessage.error('La prenda NO corresponde a esta remisión.'));
    } else {
      setState(() {
        _conteo++;
        _cantidadCtrl.text = '$_conteo';
        _msg = null;
      });
    }
    _scanPrendaFocus.requestFocus();
  }

  Future<void> _confirmar(Remision remision) async {
    final cantidad = int.tryParse(_cantidadCtrl.text.trim());
    if (cantidad == null) {
      setState(() => _msg = const FeedbackMessage.error('Ingresa una cantidad válida.'));
      return;
    }

    final res = await ref.read(wmsRepositoryProvider).recibirLote(
          remisionId: remision.id,
          cantidad: cantidad,
          ubicacion: _ubicacion,
          nota: _notaCtrl.text,
        );
    if (!mounted) return;

    switch (res) {
      case Ok(:final value):
        setState(() {
          _msg = FeedbackMessage.ok('${value.id}: ${value.estado.etiqueta}. Ingresada a $_ubicacion.');
          _remisionId = null;
          _conteo = 0;
        });
      case Err(:final message):
        setState(() => _msg = FeedbackMessage.error(message));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se observa el snapshot para reconstruir cuando cambian las remisiones.
    ref.watch(wmsSnapshotProvider);
    final enTransito = _enTransito;
    final seleccionada = enTransito.where((r) => r.id == _remisionId).firstOrNull;

    return WmsDialogShell(
      title: 'RECEPCIÓN DE LOTES Y REPORTE DE NOVEDADES',
      icon: Icons.move_to_inbox,
      iconColor: AppColors.primaryNavy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msg != null) ...[
            FeedbackBanner(message: _msg!),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _scanRemisionCtrl,
            autofocus: true,
            decoration: wmsInput('ESCANEAR REMISIÓN O BUSCAR OP (Ej. REM-101)', icon: Icons.qr_code_scanner),
            onSubmitted: _procesarScanRemision,
          ),
          const SizedBox(height: 12),
          if (enTransito.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('No hay transferencias pendientes.', style: TextStyle(color: Colors.grey))),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: enTransito.length,
                itemBuilder: (_, i) {
                  final r = enTransito[i];
                  final sel = r.id == _remisionId;
                  return Card(
                    color: sel ? Colors.blue.shade50 : Colors.white,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: sel ? AppColors.primaryNavy : Colors.grey.shade300, width: sel ? 2 : 1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        '${r.id} — ${r.item.codigo} (${r.item.talla}) - ${r.item.descripcion}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('OP: ${r.item.op} | OC: ${r.item.oc} | Envía: ${r.operario} | ${r.cantidadEnviada} Uds'),
                      trailing: ActionButton(
                        icon: Icons.qr_code,
                        label: 'VALIDAR',
                        color: AppColors.primaryNavy,
                        onPressed: () => _seleccionar(r),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (seleccionada != null) ...[
            const SizedBox(height: 12),
            _Validacion(
              remision: seleccionada,
              scanCtrl: _scanPrendaCtrl,
              scanFocus: _scanPrendaFocus,
              cantidadCtrl: _cantidadCtrl,
              notaCtrl: _notaCtrl,
              ubicacion: _ubicacion,
              onUbicacion: (v) => setState(() => _ubicacion = v),
              onScan: (raw) => _procesarScanPrenda(raw, seleccionada),
              onConfirmar: () => _confirmar(seleccionada),
            ),
          ],
        ],
      ),
    );
  }
}

class _Validacion extends StatelessWidget {
  const _Validacion({
    required this.remision,
    required this.scanCtrl,
    required this.scanFocus,
    required this.cantidadCtrl,
    required this.notaCtrl,
    required this.ubicacion,
    required this.onUbicacion,
    required this.onScan,
    required this.onConfirmar,
  });

  final Remision remision;
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
              'VALIDACIÓN: ${remision.id} (Declarado: ${remision.cantidadEnviada} Uds)',
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
