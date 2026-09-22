import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import '../../despacho/presentation/despacho_dialog.dart';
import '../../importacion/presentation/importar_ordenes_dialog.dart';
import '../../produccion/presentation/entrega_produccion_dialog.dart';
import '../../recepcion/presentation/recepcion_dialog.dart';
import '../../ubicaciones/presentation/ubicaciones_dialog.dart';
import 'kardex_filters_bar.dart';
import 'kardex_summary_cards.dart';
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

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
        toolbarHeight: 72,
        surfaceTintColor: Colors.white,
        shape: const Border(bottom: BorderSide(color: AppColors.cardBorder)),
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.tealPrimary, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
                    children: [
                      TextSpan(text: 'ORBILOQ '),
                      TextSpan(
                        text: '| KARDEX MAESTRO',
                        style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.slate600),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'CONTROL OPERATIVO DE BODEGA Y PRODUCCIÓN',
                  style: TextStyle(fontSize: 10, color: AppColors.slate400, letterSpacing: 0.4),
                ),
              ],
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => showImportarOrdenesDialog(context),
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: const Text('Importar Excel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.slate600,
              side: const BorderSide(color: AppColors.cardBorder),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _sincronizando ? null : _sincronizar,
            icon: _sincronizando
                ? const SizedBox(
                    width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.sync, size: 18),
            label: Text(_sincronizando ? 'Sincronizando...' : 'Sincronizar BD'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tealPrimary,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error cargando datos: $e')),
        data: (s) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cabecera(rol: rol, enTransito: s.remisionesEnTransito),
              const SizedBox(height: 20),
              const KardexSummaryCards(),
              const SizedBox(height: 20),
              const KardexFiltersBar(),
              const SizedBox(height: 16),
              const KardexTable(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cabecera extends ConsumerWidget {
  const _Cabecera({required this.rol, required this.enTransito});

  final Rol rol;
  final int enTransito;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _SelectorPerfil(rol: rol),
            const SizedBox(height: 2),
            const Text(
              'Órdenes activas',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate900),
            ),
          ],
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (rol == Rol.produccion)
              _BotonAccion(
                icono: Icons.history,
                texto: 'Entregar lote y ver historial',
                onPressed: () => showEntregaProduccionDialog(context),
              )
            else ...[
              _BotonAccion(
                icono: Icons.move_to_inbox_outlined,
                texto: 'Recibir remisión ($enTransito)',
                onPressed: () => showRecepcionDialog(context),
              ),
              _BotonAccion(
                icono: Icons.local_shipping_outlined,
                texto: 'Despacho por orden',
                onPressed: () => showDespachoDialog(context),
              ),
              _BotonAccion(
                icono: Icons.domain_outlined,
                texto: 'Estantes y tickets',
                onPressed: () => showUbicacionesDialog(context),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Se ve como una etiqueta de texto ("Perfil: X"), pero sigue siendo un
/// desplegable funcional para cambiar de rol — necesario mientras no exista
/// login real con el rol del usuario autenticado.
class _SelectorPerfil extends ConsumerWidget {
  const _SelectorPerfil({required this.rol});

  final Rol rol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<Rol>(
        value: rol,
        isDense: true,
        icon: const Icon(Icons.expand_more, size: 16, color: AppColors.slate400),
        style: const TextStyle(fontSize: 12, color: AppColors.slate600, fontWeight: FontWeight.w500),
        items: [
          for (final r in Rol.values)
            DropdownMenuItem(value: r, child: Text('Perfil: ${_etiquetaCorta(r)}')),
        ],
        onChanged: (r) {
          if (r != null) ref.read(rolProvider.notifier).cambiar(r);
        },
      ),
    );
  }

  String _etiquetaCorta(Rol r) => r == Rol.produccion ? 'Producción (Taller)' : 'Logística (Bodega)';
}

class _BotonAccion extends StatelessWidget {
  const _BotonAccion({required this.icono, required this.texto, required this.onPressed});

  final IconData icono;
  final String texto;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icono, size: 16),
      label: Text(texto),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.tealPrimary,
        side: const BorderSide(color: AppColors.tealPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
