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
import '../../../shared/widgets/labeled_dropdown.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showDespachoDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const DespachoDialog());

class DespachoDialog extends ConsumerStatefulWidget {
  const DespachoDialog({super.key});

  @override
  ConsumerState<DespachoDialog> createState() => _DespachoDialogState();
}

class _DespachoDialogState extends ConsumerState<DespachoDialog> {
  final _qrCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController(text: '1');
  final _qrFocus = FocusNode();

  String? _itemId;
  String? _ubicacion;
  FeedbackMessage? _msg;

  @override
  void dispose() {
    _qrCtrl.dispose();
    _cantidadCtrl.dispose();
    _qrFocus.dispose();
    super.dispose();
  }

  void _error(String texto) {
    setState(() => _msg = FeedbackMessage.error(texto));
    _qrFocus.requestFocus();
  }

  void _procesarQR(String raw) {
    _qrCtrl.clear();
    if (raw.trim().isEmpty) return;

    final qr = QrPrenda.tryParse(raw);
    if (qr == null) {
      _error('QR inválido. Formato esperado: ${QrPrenda.formato}');
      return;
    }
    final k = ref.read(wmsSnapshotProvider).value?.kardexPorOpCodigo(qr.op, qr.codigo);
    if (k == null) {
      _error('La prenda no está registrada en el kardex.');
      return;
    }
    if (k.stockDisponible <= 0 || k.ubicaciones.isEmpty) {
      _error('La prenda no tiene stock disponible en bodega.');
      return;
    }
    setState(() {
      _itemId = k.id;
      _ubicacion = k.ubicaciones.keys.first;
      _cantidadCtrl.text = '1';
      _msg = null;
    });
  }

  /// Ubicación efectiva: la elegida si aún tiene stock; si no, la primera con stock.
  String? _ubicacionEfectiva(ItemKardex? k) {
    final opciones = k?.ubicaciones.keys.toList() ?? const <String>[];
    if (opciones.isEmpty) return null;
    return opciones.contains(_ubicacion) ? _ubicacion : opciones.first;
  }

  Future<void> _confirmar() async {
    final itemId = _itemId;
    if (itemId == null) return;
    final ubicacion = _ubicacionEfectiva(ref.read(wmsSnapshotProvider).value?.kardexPorId(itemId));
    if (ubicacion == null) return;
    final cantidad = int.tryParse(_cantidadCtrl.text.trim()) ?? 0;

    final res = await ref.read(wmsRepositoryProvider).despachar(
          itemId: itemId,
          cantidad: cantidad,
          ubicacion: ubicacion,
        );
    if (!mounted) return;

    switch (res) {
      case Ok():
        setState(() {
          _msg = FeedbackMessage.ok('Despacho de $cantidad Uds desde $ubicacion registrado.');
          _itemId = null;
          _ubicacion = null;
          _cantidadCtrl.text = '1';
        });
        _qrFocus.requestFocus();
      case Err(:final message):
        setState(() => _msg = FeedbackMessage.error(message));
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(wmsSnapshotProvider).value;
    final k = _itemId == null ? null : snapshot?.kardexPorId(_itemId!);
    final opciones = k?.ubicaciones.keys.toList() ?? const <String>[];
    final ubicacion = _ubicacionEfectiva(k);

    return WmsDialogShell(
      title: 'LOGÍSTICA: PICKING Y DESPACHO A CLIENTE',
      icon: Icons.local_shipping,
      iconColor: AppColors.actionOrange,
      maxWidth: 800,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msg != null) ...[
            FeedbackBanner(message: _msg!),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _qrCtrl,
            focusNode: _qrFocus,
            autofocus: true,
            decoration: wmsInput('ESCANEAR QR DE PRENDA A DESPACHAR', icon: Icons.qr_code_scanner),
            onSubmitted: _procesarQR,
          ),
          const SizedBox(height: 12),
          if (k != null)
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OP: ${k.item.op} - ${k.item.descripcion} (${k.item.talla})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text('No. OC: ${k.item.oc} | Cliente: ${k.item.cliente}'),
                    Text(
                      'Pendiente por despachar según la orden: ${k.pendienteDespacho} Uds',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.actionOrange),
                    ),
                    const Divider(),
                    if (ubicacion == null)
                      const Text('Sin stock disponible en ninguna ubicación.')
                    else
                      Row(
                        children: [
                          Expanded(
                            child: LabeledDropdown<String>(
                              label: 'Retirar del estante',
                              value: ubicacion,
                              items: opciones,
                              itemLabel: (u) => '$u (Disp: ${k.stockEn(u)})',
                              onChanged: (v) => setState(() => _ubicacion = v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: _cantidadCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: wmsInput('Cant.'),
                              onSubmitted: (_) => _confirmar(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ActionButton(
                            icon: Icons.upload,
                            label: 'DESPACHAR',
                            color: AppColors.actionOrange,
                            onPressed: _confirmar,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
