#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Mostrar el motivo en cada tarjeta de producto no conforme (v30)
# Requiere haber corrido antes orbiloq_wms_fix_ubicacion.sql en Supabase.
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_motivo_reproceso_v30.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi
echo "Agregando el motivo a cada tarjeta..."

echo "  - lib/features/reproceso/presentation/reproceso_dialog.dart"
mkdir -p "$(dirname 'lib/features/reproceso/presentation/reproceso_dialog.dart')"
cat > 'lib/features/reproceso/presentation/reproceso_dialog.dart' << 'ORBILOQ_EOF'
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
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showReprocesoDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const ReprocesoDialog());

class ReprocesoDialog extends StatelessWidget {
  const ReprocesoDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return WmsDialogShell(
      title: 'PRODUCTOS NO CONFORME',
      icon: Icons.report_gmailerrorred,
      iconColor: AppColors.alertRed,
      expand: true,
      maxWidth: 1100,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              labelColor: AppColors.primaryNavy,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primaryNavy,
              labelPadding: EdgeInsets.symmetric(vertical: 4),
              labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              unselectedLabelStyle: TextStyle(fontSize: 11),
              tabs: [
                Tab(height: 38, icon: Icon(Icons.report_problem_outlined, size: 16), text: 'NO CONFORME'),
                Tab(height: 38, icon: Icon(Icons.history, size: 16), text: 'HISTORIAL'),
              ],
            ),
            const SizedBox(height: 8),
            const Expanded(
              child: TabBarView(children: [_ListaTab(), _HistorialTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================ pestaña 1

class _ListaTab extends ConsumerStatefulWidget {
  const _ListaTab();

  @override
  ConsumerState<_ListaTab> createState() => _ListaTabState();
}

class _ListaTabState extends ConsumerState<_ListaTab> {
  final _opCtrl = TextEditingController();
  final _qrCtrl = TextEditingController();
  final Map<String, TextEditingController> _cantidadCtrls = {};
  final Map<String, bool> _liberando = {};
  String _operario = WmsConstantes.operarios.first;
  String _filtroOp = '';
  FeedbackMessage? _msgGeneral;
  late Future<Map<String, List<String>>> _motivosFuturo;

  @override
  void initState() {
    super.initState();
    _motivosFuturo = _cargarMotivos();
  }

  /// Agrupa los motivos (causales) ya reportados por producto, para
  /// mostrarlos en cada tarjeta. Una misma prenda puede tener más de un
  /// motivo si se reportó no conforme más de una vez por razones distintas.
  Future<Map<String, List<String>>> _cargarMotivos() async {
    final devoluciones = await ref.read(wmsRepositoryProvider).cargarDevoluciones();
    final mapa = <String, List<String>>{};
    for (final d in devoluciones) {
      final lista = mapa.putIfAbsent(d.item.id, () => []);
      if (!lista.contains(d.causal)) lista.add(d.causal);
    }
    return mapa;
  }

  @override
  void dispose() {
    _opCtrl.dispose();
    _qrCtrl.dispose();
    for (final c in _cantidadCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrlPara(ItemKardex k) =>
      _cantidadCtrls.putIfAbsent(k.id, () => TextEditingController(text: '${k.pendienteReproceso}'));

  void _buscarOp() => setState(() => _filtroOp = _opCtrl.text.trim());

  void _limpiarFiltro() => setState(() {
        _filtroOp = '';
        _opCtrl.clear();
      });

  void _procesarQR(String raw) {
    _qrCtrl.clear();
    if (raw.trim().isEmpty) return;
    final qr = QrPrenda.tryParse(raw);
    if (qr == null) {
      setState(() => _msgGeneral = FeedbackMessage.error('QR inválido. Formato esperado: ${QrPrenda.formato}'));
      return;
    }
    final kardex = ref.read(wmsSnapshotProvider).value?.kardexPorOpCodigo(qr.op, qr.codigo);
    if (kardex == null) {
      setState(() => _msgGeneral = FeedbackMessage.error('La prenda no existe en el kardex.'));
      return;
    }
    if (kardex.pendienteReproceso <= 0) {
      setState(() => _msgGeneral =
          FeedbackMessage.error('${kardex.item.descripcion} (${kardex.item.talla}) no tiene unidades no conformes.'));
      return;
    }
    setState(() {
      _msgGeneral = null;
      _filtroOp = kardex.item.op;
      _opCtrl.text = kardex.item.op;
    });
  }

  Future<void> _liberar(ItemKardex k) async {
    final ctrl = _ctrlPara(k);
    final cantidad = int.tryParse(ctrl.text.trim()) ?? 0;
    if (cantidad <= 0) {
      setState(() => _msgGeneral = const FeedbackMessage.error('Ingresa una cantidad mayor a 0.'));
      return;
    }
    if (cantidad > k.pendienteReproceso) {
      setState(() => _msgGeneral =
          FeedbackMessage.error('LÍMITE EXCEDIDO: solo hay ${k.pendienteReproceso} Uds pendientes por reprocesar.'));
      return;
    }

    setState(() {
      _msgGeneral = null;
      _liberando[k.id] = true;
    });
    final res = await ref.read(wmsRepositoryProvider).liberarNoConforme(
          itemId: k.id,
          cantidad: cantidad,
          operario: _operario,
        );
    if (!mounted) return;
    setState(() {
      _liberando[k.id] = false;
      switch (res) {
        case Ok():
          _msgGeneral = FeedbackMessage.ok(
            '${cantidad}u de ${k.item.descripcion} (${k.item.talla}) liberadas — vuelven a Entregado a Logística.',
          );
          _cantidadCtrls.remove(k.id)?.dispose();
        case Err(:final message):
          _msgGeneral = FeedbackMessage.error(message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final kardex = ref.watch(wmsSnapshotProvider).value?.kardex ?? const <ItemKardex>[];
    final noConformes = kardex.where((k) => k.pendienteReproceso > 0).toList()
      ..sort((a, b) => a.item.op.compareTo(b.item.op));
    final visibles =
        _filtroOp.isEmpty ? noConformes : noConformes.where((k) => k.item.op == _filtroOp).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_msgGeneral != null) ...[
          FeedbackBanner(message: _msgGeneral!),
          const SizedBox(height: 12),
        ],
        LabeledDropdown<String>(
          label: 'Liberado por',
          value: _operario,
          items: WmsConstantes.operarios,
          onChanged: (v) => setState(() => _operario = v),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _opCtrl,
                keyboardType: TextInputType.number,
                decoration: wmsInput('Buscar por número de OP', icon: Icons.tag),
                onSubmitted: (_) => _buscarOp(),
              ),
            ),
            const SizedBox(width: 8),
            ActionButton(icon: Icons.search, label: 'BUSCAR', color: AppColors.primaryNavy, onPressed: _buscarOp),
            if (_filtroOp.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton(tooltip: 'Quitar filtro', icon: const Icon(Icons.close), onPressed: _limpiarFiltro),
            ],
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _qrCtrl,
          decoration: wmsInput('O ESCANEAR QR PARA ENCONTRAR UNA PRENDA', icon: Icons.qr_code_scanner),
          onSubmitted: _procesarQR,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: visibles.isEmpty
              ? Center(
                  child: Text(
                    noConformes.isEmpty
                        ? 'No hay productos no conformes en este momento.'
                        : 'Ninguno coincide con la OP $_filtroOp.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              : FutureBuilder<Map<String, List<String>>>(
                  future: _motivosFuturo,
                  builder: (context, snapshotMotivos) {
                    final motivos = snapshotMotivos.data ?? const {};
                    return ListView.builder(
                      itemCount: visibles.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TarjetaNoConforme(
                          kardex: visibles[i],
                          cantidadCtrl: _ctrlPara(visibles[i]),
                          liberando: _liberando[visibles[i].id] ?? false,
                          motivos: motivos[visibles[i].id] ?? const [],
                          onLiberar: () => _liberar(visibles[i]),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TarjetaNoConforme extends StatelessWidget {
  const _TarjetaNoConforme({
    required this.kardex,
    required this.cantidadCtrl,
    required this.liberando,
    required this.motivos,
    required this.onLiberar,
  });

  final ItemKardex kardex;
  final TextEditingController cantidadCtrl;
  final bool liberando;
  final List<String> motivos;
  final VoidCallback onLiberar;

  @override
  Widget build(BuildContext context) {
    final k = kardex;
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${k.item.codigo} - ${k.item.descripcion} (${k.item.talla})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy),
            ),
            Text('OP: ${k.item.op} | OC: ${k.item.oc} | Cliente: ${k.item.cliente}'),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.report_problem_outlined, size: 16, color: AppColors.alertRed),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    motivos.isEmpty ? 'Motivo: sin registrar' : 'Motivo(s): ${motivos.join(', ')}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.alertRed,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            MetricWrap(children: [
              MetricCard(
                title: 'ENTREGADO A LOGÍSTICA',
                value: '${k.producido} Uds',
                color: AppColors.actionGreen,
                icon: Icons.check_circle,
              ),
              MetricCard(
                title: 'NO CONFORME',
                value: '${k.pendienteReproceso} Uds',
                color: AppColors.alertRed,
                icon: Icons.report_problem_outlined,
              ),
            ]),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: cantidadCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: wmsInput('Cantidad a liberar (máx ${k.pendienteReproceso} Uds)'),
                  ),
                ),
                const SizedBox(width: 10),
                ActionButton(
                  icon: Icons.check_circle_outline,
                  label: 'LIBERAR',
                  color: AppColors.actionGreen,
                  busy: liberando,
                  onPressed: onLiberar,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================== pestaña 2: historial

class _HistorialTab extends ConsumerStatefulWidget {
  const _HistorialTab();

  @override
  ConsumerState<_HistorialTab> createState() => _HistorialTabState();
}

class _HistorialTabState extends ConsumerState<_HistorialTab> {
  late Future<List<Liberacion>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = ref.read(wmsRepositoryProvider).cargarLiberaciones();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Liberacion>>(
      future: _futuro,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('No se pudo cargar el historial: ${snapshot.error}'));
        }
        final liberaciones = snapshot.data ?? const [];
        if (liberaciones.isEmpty) {
          return const Center(child: Text('Aún no hay liberaciones registradas.', style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          itemCount: liberaciones.length,
          itemBuilder: (_, i) {
            final l = liberaciones[i];
            return Card(
              child: ListTile(
                dense: true,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.actionGreen,
                  child: Icon(Icons.check, color: Colors.white, size: 18),
                ),
                title: Text(
                  '${l.item.codigo} (${l.item.talla}) — ${l.cantidad} Uds liberadas',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'OP: ${l.item.op} | Por: ${l.operario} | ${formatFechaHora(l.fecha)}'
                  '${l.nota.isNotEmpty ? ' | ${l.nota}' : ''}',
                ),
              ),
            );
          },
        );
      },
    );
  }
}
ORBILOQ_EOF

echo ""
echo "Listo. flutter analyze"
