import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/constants.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/fecha.dart';
import '../../../domain/qr_prenda.dart';
import '../../../shared/widgets/action_button.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/labeled_dropdown.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showEntregaProduccionDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const EntregaProduccionDialog());

class EntregaProduccionDialog extends StatelessWidget {
  const EntregaProduccionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return WmsDialogShell(
      title: 'PRODUCCIÓN: ENTREGA CON LÍMITES E HISTORIAL',
      icon: Icons.precision_manufacturing,
      iconColor: AppColors.actionGreen,
      expand: true,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              labelColor: AppColors.primaryNavy,
              indicatorColor: AppColors.primaryNavy,
              tabs: [
                Tab(icon: Icon(Icons.add_box), text: 'NUEVA ENTREGA CON LÍMITES'),
                Tab(icon: Icon(Icons.history), text: 'HISTORIAL DE REMISIONES'),
              ],
            ),
            const SizedBox(height: 10),
            const Expanded(
              child: TabBarView(children: [_NuevaEntregaTab(), _HistorialTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

class _NuevaEntregaTab extends ConsumerStatefulWidget {
  const _NuevaEntregaTab();

  @override
  ConsumerState<_NuevaEntregaTab> createState() => _NuevaEntregaTabState();
}

class _NuevaEntregaTabState extends ConsumerState<_NuevaEntregaTab>
    with AutomaticKeepAliveClientMixin {
  final _remisionCtrl = TextEditingController();
  final _qrCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController(text: '1');
  final _qrFocus = FocusNode();

  String _operario = WmsConstantes.operarios.first;
  String? _itemId;
  int _conteo = 0;
  FeedbackMessage? _msg;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _remisionCtrl.dispose();
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
    final kardex = ref.read(wmsSnapshotProvider).value?.kardexPorId(qr.itemId);
    if (kardex == null) {
      _error('La prenda no existe en el kardex (OP ${qr.op} · OC ${qr.oc} · ${qr.codigo} · ${qr.talla}).');
      return;
    }

    // Al cambiar de producto el conteo se reinicia.
    final base = _itemId == qr.itemId ? _conteo : 0;
    if (base >= kardex.pendienteProduccion) {
      _error('LÍMITE ALCANZADO: esta OP ya cumplió la cantidad pedida (${kardex.pendienteProduccion} Uds por entregar).');
      return;
    }

    setState(() {
      _itemId = qr.itemId;
      _conteo = base + 1;
      _cantidadCtrl.text = '$_conteo';
      _msg = null;
    });
    _qrFocus.requestFocus();
  }

  void _reiniciarConteo() {
    setState(() {
      _conteo = 0;
      _cantidadCtrl.text = '1';
    });
    _qrFocus.requestFocus();
  }

  Future<void> _confirmar() async {
    final itemId = _itemId;
    if (itemId == null) return;
    final cantidad = int.tryParse(_cantidadCtrl.text.trim()) ?? 0;

    final res = await ref.read(wmsRepositoryProvider).entregarLote(
          itemId: itemId,
          cantidad: cantidad,
          operario: _operario,
          numeroRemision: _remisionCtrl.text,
        );
    if (!mounted) return;

    switch (res) {
      case Ok(:final value):
        setState(() {
          _msg = FeedbackMessage.ok('Remisión ${value.id} de ${value.cantidadEnviada} Uds despachada a bodega.');
          _itemId = null;
          _conteo = 0;
          _remisionCtrl.clear();
          _cantidadCtrl.text = '1';
        });
      case Err(:final message):
        setState(() => _msg = FeedbackMessage.error(message));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final snapshot = ref.watch(wmsSnapshotProvider).value;
    final k = _itemId == null ? null : snapshot?.kardexPorId(_itemId!);
    final proxima = snapshot?.proximaRemision;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msg != null) ...[
            FeedbackBanner(message: _msg!),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _remisionCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: wmsInput(
                    'N° Remisión / Lote',
                    hint: proxima == null ? 'Automático' : 'Automático ($proxima)',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LabeledDropdown<String>(
                  label: 'Operario de Producción',
                  value: _operario,
                  items: WmsConstantes.operarios,
                  onChanged: (v) => setState(() => _operario = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qrCtrl,
            focusNode: _qrFocus,
            autofocus: true,
            decoration: wmsInput('PISTOLEE O ESCANEE QR DE PRENDA A ENTREGAR', icon: Icons.qr_code_scanner),
            onSubmitted: _procesarQR,
          ),
          const SizedBox(height: 12),
          if (k != null)
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${k.item.codigo} - ${k.item.descripcion} (${k.item.talla})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy),
                              ),
                              Text('OP: ${k.item.op} | OC: ${k.item.oc} | Cliente: ${k.item.cliente}'),
                            ],
                          ),
                        ),
                        ActionButton(
                          icon: Icons.refresh,
                          label: 'RECONTEAR',
                          color: Colors.amber.shade900,
                          onPressed: _reiniciarConteo,
                        ),
                      ],
                    ),
                    const Divider(),
                    MetricWrap(children: [
                      MetricCard(title: 'META OP', value: '${k.cantidadPedida} Uds', color: Colors.blueGrey, icon: Icons.flag),
                      MetricCard(title: 'ENTREGADAS', value: '${k.producido} Uds', color: AppColors.actionGreen, icon: Icons.check_circle),
                      MetricCard(
                        title: 'LÍMITE MÁXIMO',
                        value: '${k.pendienteProduccion} Uds',
                        color: k.pendienteProduccion > 0 ? AppColors.alertRed : Colors.grey,
                        icon: Icons.lock_clock,
                      ),
                      MetricCard(
                        title: 'AVANCE',
                        value: '${((k.producido / k.cantidadPedida).clamp(0.0, 1.0) * 100).toStringAsFixed(1)}%',
                        color: AppColors.accentCyan,
                        icon: Icons.donut_large,
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cantidadCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: wmsInput('Cantidad a enviar (máx ${k.pendienteProduccion} Uds)'),
                            onSubmitted: (_) => _confirmar(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ActionButton(
                          icon: Icons.local_shipping,
                          label: 'DESPACHAR A BODEGA',
                          color: AppColors.actionGreen,
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

class _HistorialTab extends ConsumerWidget {
  const _HistorialTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remisiones = ref.watch(wmsSnapshotProvider).value?.remisiones ?? const [];
    if (remisiones.isEmpty) {
      return const Center(child: Text('Aún no hay remisiones.', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      itemCount: remisiones.length,
      itemBuilder: (_, i) {
        final r = remisiones[i];
        return Card(
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryNavy,
              child: Text('#${remisiones.length - i}', style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
            title: Text(
              '${r.id} — OP: ${r.item.op} | ${r.item.codigo} (${r.item.talla})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Enviadas: ${r.cantidadEnviada} Uds | Fecha: ${formatFechaHora(r.fechaEnvio)}'
                    '${r.cantidadRecibida != null ? ' | Recibidas: ${r.cantidadRecibida}' : ''}'),
                if (r.novedad.isNotEmpty)
                  Text('Novedad: ${r.novedad}', style: const TextStyle(color: AppColors.alertRed, fontWeight: FontWeight.bold)),
              ],
            ),
            trailing: StatusChip(label: r.estado.etiqueta, color: colorDeEstadoRemision(r.estado)),
          ),
        );
      },
    );
  }
}
