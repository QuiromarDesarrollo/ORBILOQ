import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/action_button.dart';
import '../../despacho/presentation/despacho_dialog.dart';
import '../../produccion/presentation/entrega_produccion_dialog.dart';
import '../../recepcion/presentation/recepcion_dialog.dart';
import '../../ubicaciones/presentation/ubicaciones_dialog.dart';
import 'kardex_filters_bar.dart';
import 'kardex_table.dart';

class KardexPage extends ConsumerStatefulWidget {
  const KardexPage({super.key});

  @override
  ConsumerState<KardexPage> createState() => _KardexPageState();
}

class _KardexPageState extends ConsumerState<KardexPage> {
  bool _sincronizando = false;

  Future<void> _sincronizar() async {
    setState(() => _sincronizando = true);
    await ref.read(wmsRepositoryProvider).refrescar();
    if (!mounted) return;
    setState(() => _sincronizando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Datos sincronizados'),
        backgroundColor: AppColors.actionGreen,
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rol = ref.watch(rolProvider);
    final snapshot = ref.watch(wmsSnapshotProvider);
    final filas = ref.watch(kardexFiltradoProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
        elevation: 2,
        titleSpacing: 12,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.public, color: AppColors.primaryNavy, size: 22),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'ORBILOQ WMS - KARDEX MAESTRO Y CONTROL BODEGA',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: AppColors.secondaryNavy, borderRadius: BorderRadius.circular(20)),
            child: DropdownButton<Rol>(
              value: rol,
              dropdownColor: AppColors.secondaryNavy,
              underline: const SizedBox(),
              icon: const Icon(Icons.switch_account, color: AppColors.accentCyan),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              items: [
                for (final r in Rol.values)
                  DropdownMenuItem(value: r, child: Text('Perfil: ${r.etiqueta}')),
              ],
              onChanged: (r) {
                if (r != null) ref.read(rolProvider.notifier).cambiar(r);
              },
            ),
          ),
          const SizedBox(width: 12),
          ActionButton(
            icon: Icons.sync,
            label: _sincronizando ? 'SINCRONIZANDO...' : 'SINCRONIZAR BD',
            color: AppColors.accentCyan,
            busy: _sincronizando,
            onPressed: _sincronizar,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error cargando datos: $e')),
        data: (s) => Column(
          children: [
            _BarraAcciones(rol: rol, enTransito: s.remisionesEnTransito),
            const KardexFiltersBar(),
            Expanded(child: KardexTable(rows: filas, rol: rol)),
          ],
        ),
      ),
    );
  }
}

class _BarraAcciones extends ConsumerWidget {
  const _BarraAcciones({required this.rol, required this.enTransito});

  final Rol rol;
  final int enTransito;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: AppColors.secondaryNavy,
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (rol == Rol.produccion) ...[
            ActionButton(
              icon: Icons.send_and_archive,
              label: 'ENTREGAR LOTE & VER HISTORIAL',
              color: AppColors.actionGreen,
              onPressed: () => showEntregaProduccionDialog(context),
            ),
            const Text(
              'Modo Producción: límite estricto por OP, control de faltantes e historial de remisiones.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ] else ...[
            ActionButton(
              icon: Icons.move_to_inbox,
              label: '1. RECIBIR Y REPORTAR NOVEDADES ($enTransito)',
              color: AppColors.actionGreen,
              onPressed: () => showRecepcionDialog(context),
            ),
            ActionButton(
              icon: Icons.local_shipping,
              label: '2. DESPACHO POR ORDEN',
              color: AppColors.actionOrange,
              onPressed: () => showDespachoDialog(context),
            ),
            ActionButton(
              icon: Icons.domain,
              label: '3. ESTANTES & TICKETS',
              color: Colors.indigo.shade700,
              onPressed: () => showUbicacionesDialog(context),
            ),
          ],
          ActionButton(
            icon: Icons.cleaning_services,
            label: 'LIMPIAR FILTROS',
            color: Colors.blueGrey.shade700,
            onPressed: () => ref.read(kardexFiltersProvider.notifier).limpiar(),
          ),
        ],
      ),
    );
  }
}
