import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/action_button.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/labeled_dropdown.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showUbicacionesDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const UbicacionesDialog());

typedef _Existencia = ({ItemKardex item, int cantidad});

class UbicacionesDialog extends ConsumerStatefulWidget {
  const UbicacionesDialog({super.key});

  @override
  ConsumerState<UbicacionesDialog> createState() => _UbicacionesDialogState();
}

class _UbicacionesDialogState extends ConsumerState<UbicacionesDialog> {
  String _ubicacion = WmsConstantes.ubicaciones.first;
  FeedbackMessage? _msg;

  Future<void> _imprimir(List<_Existencia> items, int total) async {
    final imprimir = await showDialog<bool>(
      context: context,
      builder: (_) => dialogoClaro(_TicketDialog(ubicacion: _ubicacion, items: items, total: total)),
    );
    if (imprimir == true && mounted) {
      setState(() => _msg = FeedbackMessage.ok('Ticket de $_ubicacion enviado a impresora térmica.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final kardex = ref.watch(kardexProvider);
    final items = <_Existencia>[
      for (final k in kardex)
        if (k.stockEn(_ubicacion) > 0) (item: k, cantidad: k.stockEn(_ubicacion)),
    ];
    final total = items.fold<int>(0, (s, e) => s + e.cantidad);

    return WmsDialogShell(
      title: 'CONSULTA DE EXISTENCIAS POR ESTANTE',
      icon: Icons.domain,
      iconColor: AppColors.primaryNavy,
      maxWidth: 850,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msg != null) ...[
            FeedbackBanner(message: _msg!),
            const SizedBox(height: 12),
          ],
          LabeledDropdown<String>(
            label: 'Seleccionar estante / rack',
            value: _ubicacion,
            items: WmsConstantes.ubicaciones,
            onChanged: (v) => setState(() {
              _ubicacion = v;
              _msg = null;
            }),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total en $_ubicacion: $total unidades disponibles',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                  ),
                ),
                ActionButton(
                  icon: Icons.print,
                  label: 'TICKET',
                  color: AppColors.actionGreen,
                  onPressed: items.isEmpty ? null : () => _imprimir(items, total),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Este estante no tiene existencias.')),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final e = items[i];
                  return ListTile(
                    dense: true,
                    title: Text(
                      '${e.item.item.codigo} - ${e.item.item.descripcion} (${e.item.item.talla})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('OP: ${e.item.item.op} | OC: ${e.item.item.oc} | Cliente: ${e.item.item.cliente}'),
                    trailing: Text(
                      '${e.cantidad} Uds',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.actionGreen),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TicketDialog extends StatelessWidget {
  const _TicketDialog({required this.ubicacion, required this.items, required this.total});

  final String ubicacion;
  final List<_Existencia> items;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 380, maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 2)),
                    child: Column(
                      children: [
                        const Text('ORBILOQ WMS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Text('RÓTULO DE UBICACIÓN FÍSICA', style: TextStyle(fontSize: 11)),
                        const Divider(thickness: 1.5, color: Colors.black),
                        Text(ubicacion, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          height: 110,
                          width: 110,
                          decoration: BoxDecoration(color: Colors.grey.shade200, border: Border.all(color: Colors.black)),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_2, size: 70),
                              Text('SCAN UBICACIÓN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('QR ID: LOC-$ubicacion', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                        const Divider(color: Colors.black),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('CONTENIDO ALMACENADO:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 4),
                        for (final e in items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${e.item.item.codigo} (${e.item.item.talla}) OP:${e.item.item.op}',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                                Text('${e.cantidad} Uds', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        const Divider(color: Colors.black),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('TOTAL EN ESTANTE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('$total UDS', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cerrar')),
                  const SizedBox(width: 8),
                  ActionButton(
                    icon: Icons.print,
                    label: 'IMPRIMIR',
                    color: AppColors.actionGreen,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
