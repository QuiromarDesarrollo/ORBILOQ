#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Tarjetas independientes en Entrega de Produccion (v20)
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_tarjetas_entrega_v20.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi
echo "Aplicando tarjetas independientes..."

echo "  - lib/features/produccion/presentation/entrega_produccion_dialog.dart"
mkdir -p "$(dirname 'lib/features/produccion/presentation/entrega_produccion_dialog.dart')"
cat > 'lib/features/produccion/presentation/entrega_produccion_dialog.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/constants.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/fecha.dart';
import '../../../domain/models.dart';
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

/// Estado de UNA tarjeta de producto/talla dentro de la sesión de escaneo.
/// Varias pueden coexistir: escanear una OP/talla nueva crea una tarjeta
/// aparte, sin perder el conteo de las demás.
class _TarjetaEntrega {
  _TarjetaEntrega({required this.itemId}) : cantidadCtrl = TextEditingController(text: '1');

  final String itemId;
  final TextEditingController cantidadCtrl;
  int conteo = 1;
  bool enviando = false;
  bool enviada = false;
  String? remisionId;
  FeedbackMessage? mensaje;

  void dispose() => cantidadCtrl.dispose();
}

class _NuevaEntregaTab extends ConsumerStatefulWidget {
  const _NuevaEntregaTab();

  @override
  ConsumerState<_NuevaEntregaTab> createState() => _NuevaEntregaTabState();
}

class _NuevaEntregaTabState extends ConsumerState<_NuevaEntregaTab> with AutomaticKeepAliveClientMixin {
  final _qrCtrl = TextEditingController();
  final _qrFocus = FocusNode();

  String _operario = WmsConstantes.operarios.first;
  final List<_TarjetaEntrega> _tarjetas = [];
  FeedbackMessage? _msgGeneral;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _qrCtrl.dispose();
    _qrFocus.dispose();
    for (final t in _tarjetas) {
      t.dispose();
    }
    super.dispose();
  }

  /// La tarjeta activa (aún no enviada) para este producto, si existe.
  /// Si ya se envió una tarjeta de este mismo producto, un nuevo escaneo
  /// abre una tarjeta nueva (un lote nuevo), no reutiliza la ya cerrada.
  _TarjetaEntrega? _tarjetaActivaPara(String itemId) {
    for (final t in _tarjetas) {
      if (t.itemId == itemId && !t.enviada) return t;
    }
    return null;
  }

  void _errorGeneral(String texto) {
    setState(() => _msgGeneral = FeedbackMessage.error(texto));
    _qrFocus.requestFocus();
  }

  void _procesarQR(String raw) {
    _qrCtrl.clear();
    if (raw.trim().isEmpty) return;

    final qr = QrPrenda.tryParse(raw);
    if (qr == null) {
      _errorGeneral('QR inválido. Formato esperado: ${QrPrenda.formato}');
      return;
    }
    final kardex = ref.read(wmsSnapshotProvider).value?.kardexPorOpCodigo(qr.op, qr.codigo);
    if (kardex == null) {
      _errorGeneral('La prenda no existe en el kardex (OP ${qr.op} · Código ${qr.codigo}).');
      return;
    }

    setState(() {
      _msgGeneral = null;
      final existente = _tarjetaActivaPara(kardex.id);
      if (existente != null) {
        if (existente.conteo >= kardex.pendienteProduccion) {
          existente.mensaje = FeedbackMessage.error(
            'LÍMITE ALCANZADO: esta OP ya cumplió la cantidad pedida (${kardex.pendienteProduccion} Uds por entregar).',
          );
        } else {
          existente.conteo++;
          existente.cantidadCtrl.text = '${existente.conteo}';
          existente.mensaje = null;
        }
      } else if (kardex.pendienteProduccion <= 0) {
        _msgGeneral = FeedbackMessage.error(
          'LÍMITE ALCANZADO: esta OP ya cumplió la cantidad pedida (${kardex.pendienteProduccion} Uds por entregar).',
        );
      } else {
        _tarjetas.insert(0, _TarjetaEntrega(itemId: kardex.id));
      }
    });
    _qrFocus.requestFocus();
  }

  void _reiniciarConteo(_TarjetaEntrega t) {
    setState(() {
      t.conteo = 0;
      t.cantidadCtrl.text = '1';
      t.mensaje = null;
    });
    _qrFocus.requestFocus();
  }

  void _quitarTarjeta(_TarjetaEntrega t) {
    setState(() {
      t.dispose();
      _tarjetas.remove(t);
    });
  }

  Future<void> _despachar(_TarjetaEntrega t) async {
    final kardex = ref.read(wmsSnapshotProvider).value?.kardexPorId(t.itemId);
    if (kardex == null) return;
    final cantidad = int.tryParse(t.cantidadCtrl.text.trim()) ?? 0;

    if (cantidad <= 0) {
      setState(() => t.mensaje = const FeedbackMessage.error('Ingresa una cantidad mayor a 0.'));
      return;
    }
    if (cantidad > kardex.pendienteProduccion) {
      setState(() => t.mensaje = FeedbackMessage.error(
            'LÍMITE EXCEDIDO: solo faltan ${kardex.pendienteProduccion} Uds por producir.',
          ));
      return;
    }

    setState(() => t.enviando = true);
    final res = await ref.read(wmsRepositoryProvider).entregarLote(
          itemId: t.itemId,
          cantidad: cantidad,
          operario: _operario,
        );
    if (!mounted) return;
    setState(() {
      t.enviando = false;
      switch (res) {
        case Ok(:final value):
          t.enviada = true;
          t.remisionId = value.id;
          t.mensaje = FeedbackMessage.ok('Remisión ${value.id} de ${value.cantidadEnviada} Uds despachada a bodega.');
        case Err(:final message):
          t.mensaje = FeedbackMessage.error(message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final snapshot = ref.watch(wmsSnapshotProvider).value;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msgGeneral != null) ...[
            FeedbackBanner(message: _msgGeneral!),
            const SizedBox(height: 12),
          ],
          LabeledDropdown<String>(
            label: 'Operario de Producción',
            value: _operario,
            items: WmsConstantes.operarios,
            onChanged: (v) => setState(() => _operario = v),
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
          if (_tarjetas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Escanea una prenda para empezar. Puedes tener varias tallas u OP\n'
                  'abiertas a la vez — cada una lleva su propio conteo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            for (final t in _tarjetas) ...[
              _TarjetaWidget(
                tarjeta: t,
                kardex: snapshot?.kardexPorId(t.itemId),
                onRecontear: () => _reiniciarConteo(t),
                onQuitar: () => _quitarTarjeta(t),
                onDespachar: () => _despachar(t),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

/// Una tarjeta individual: activa (editable, con conteo) o ya enviada
/// (se queda visible, marcada, sin controles de edición).
class _TarjetaWidget extends StatelessWidget {
  const _TarjetaWidget({
    required this.tarjeta,
    required this.kardex,
    required this.onRecontear,
    required this.onQuitar,
    required this.onDespachar,
  });

  final _TarjetaEntrega tarjeta;
  final ItemKardex? kardex;
  final VoidCallback onRecontear;
  final VoidCallback onQuitar;
  final VoidCallback onDespachar;

  @override
  Widget build(BuildContext context) {
    final k = kardex;
    if (k == null) return const SizedBox.shrink();
    final enviada = tarjeta.enviada;

    return Card(
      color: enviada ? Colors.grey.shade100 : Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                            '${k.item.codigo} - ${k.item.descripcion} (${k.item.talla})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: enviada ? Colors.grey.shade600 : AppColors.primaryNavy,
                            ),
                          ),
                          if (enviada)
                            StatusChip(label: 'ENVIADA · ${tarjeta.remisionId}', color: AppColors.actionGreen),
                        ],
                      ),
                      Text(
                        'OP: ${k.item.op} | OC: ${k.item.oc} | Cliente: ${k.item.cliente}',
                        style: TextStyle(color: enviada ? Colors.grey.shade600 : null),
                      ),
                    ],
                  ),
                ),
                if (!enviada) ...[
                  ActionButton(
                    icon: Icons.refresh,
                    label: 'RECONTEAR',
                    color: Colors.amber.shade900,
                    onPressed: onRecontear,
                  ),
                  IconButton(
                    tooltip: 'Quitar esta tarjeta',
                    icon: const Icon(Icons.close, color: AppColors.alertRed),
                    onPressed: onQuitar,
                  ),
                ],
              ],
            ),
            const Divider(),
            if (tarjeta.mensaje != null) ...[
              FeedbackBanner(message: tarjeta.mensaje!),
              const SizedBox(height: 10),
            ],
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
            if (!enviada) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: tarjeta.cantidadCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: wmsInput('Cantidad a enviar (máx ${k.pendienteProduccion} Uds)'),
                      onSubmitted: (_) => onDespachar(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ActionButton(
                    icon: Icons.local_shipping,
                    label: 'DESPACHAR A BODEGA',
                    color: AppColors.actionGreen,
                    busy: tarjeta.enviando,
                    onPressed: onDespachar,
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
ORBILOQ_EOF

echo ""
echo "Listo. flutter analyze / flutter test"
