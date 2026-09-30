import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/fecha.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showSobrantesDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const SobrantesDialog());

class SobrantesDialog extends StatelessWidget {
  const SobrantesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return WmsDialogShell(
      title: 'BANDEJA DE SOBRANTES',
      icon: Icons.add_box_outlined,
      iconColor: AppColors.primaryNavy,
      expand: true,
      maxWidth: 1000,
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
                Tab(height: 38, icon: Icon(Icons.hourglass_top_outlined, size: 16), text: 'PENDIENTES'),
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

// ============================================================ pestaña 1: pendientes

class _PendientesTab extends ConsumerStatefulWidget {
  const _PendientesTab();

  @override
  ConsumerState<_PendientesTab> createState() => _PendientesTabState();
}

class _PendientesTabState extends ConsumerState<_PendientesTab> {
  final Map<String, TextEditingController> _resolucionCtrls = {};
  final Map<String, bool> _resolviendo = {};
  FeedbackMessage? _msg;

  @override
  void dispose() {
    for (final c in _resolucionCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrlPara(String id) => _resolucionCtrls.putIfAbsent(id, TextEditingController.new);

  Future<void> _resolver(SobranteBodega s) async {
    final resolucion = _ctrlPara(s.id).text.trim();
    if (resolucion.isEmpty) {
      setState(() => _msg = const FeedbackMessage.error('Escribe qué se decidió hacer con este sobrante.'));
      return;
    }

    setState(() {
      _msg = null;
      _resolviendo[s.id] = true;
    });
    final res = await ref.read(wmsRepositoryProvider).resolverSobrante(id: s.id, resolucion: resolucion);
    if (!mounted) return;
    setState(() {
      _resolviendo[s.id] = false;
      switch (res) {
        case Ok():
          _msg = FeedbackMessage.ok('Sobrante de ${s.item.descripcion} (${s.item.talla}) resuelto.');
          _resolucionCtrls.remove(s.id)?.dispose();
          ref.invalidate(sobrantesProvider);
        case Err(:final message):
          _msg = FeedbackMessage.error(message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(sobrantesProvider);
    return todos.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.alertRed))),
      data: (lista) {
        final pendientes = lista.where((s) => s.pendiente).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_msg != null) ...[FeedbackBanner(message: _msg!), const SizedBox(height: 12)],
            Expanded(
              child: pendientes.isEmpty
                  ? const Center(child: Text('No hay sobrantes pendientes por resolver.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: pendientes.length,
                      itemBuilder: (_, i) {
                        final s = pendientes[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Card(
                            color: Colors.blue.shade50,
                            shape: RoundedRectangleBorder(side: BorderSide(color: Colors.blue.shade300), borderRadius: BorderRadius.circular(8)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('OP: ${s.item.op} - ${s.item.descripcion} (${s.item.talla})',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                                  Text('${s.cantidad} Uds de más | Registrado por: ${s.operario} | ${formatFechaHora(s.fecha)}',
                                      style: const TextStyle(fontSize: 12)),
                                  if (s.nota.isNotEmpty)
                                    Text('Nota: ${s.nota}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                                  const Divider(),
                                  TextField(
                                    controller: _ctrlPara(s.id),
                                    decoration: wmsInput('¿Qué se decidió hacer con este sobrante?', icon: Icons.edit_note),
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: ElevatedButton.icon(
                                      onPressed: (_resolviendo[s.id] ?? false) ? null : () => _resolver(s),
                                      icon: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                                      label: const Text('RESOLVER'),
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.actionGreen, foregroundColor: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================ pestaña 2: historial

class _HistorialTab extends ConsumerWidget {
  const _HistorialTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = ref.watch(sobrantesProvider);
    return todos.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.alertRed))),
      data: (lista) {
        if (lista.isEmpty) {
          return const Center(child: Text('Aún no hay sobrantes registrados.', style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          itemCount: lista.length,
          itemBuilder: (_, i) {
            final s = lista[i];
            return Card(
              color: s.pendiente ? Colors.blue.shade50 : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('OP: ${s.item.op} - ${s.item.descripcion} (${s.item.talla})',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                        ),
                        StatusChip(
                          label: s.pendiente ? 'PENDIENTE' : 'RESUELTO',
                          color: s.pendiente ? Colors.blue.shade700 : AppColors.actionGreen,
                        ),
                      ],
                    ),
                    Text('${s.cantidad} Uds de más | Registrado por: ${s.operario} | ${formatFechaHora(s.fecha)}',
                        style: const TextStyle(fontSize: 12)),
                    if (s.nota.isNotEmpty)
                      Text('Nota: ${s.nota}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                    if (!s.pendiente)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Resuelto: ${s.resolucion} | ${s.fechaResolucion != null ? formatFechaHora(s.fechaResolucion) : ""}',
                          style: const TextStyle(fontSize: 12, color: AppColors.actionGreen, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
