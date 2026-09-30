#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Bandeja de Sobrantes (v52, parte 2/2)
# Ejecutar DESPUES de apply_recepcion_parcial_v51.sh
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_bandeja_sobrantes_v52.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi
echo "Aplicando la Bandeja de Sobrantes..."

echo "  - lib/features/sobrantes/presentation/sobrantes_dialog.dart"
mkdir -p "$(dirname 'lib/features/sobrantes/presentation/sobrantes_dialog.dart')"
cat > 'lib/features/sobrantes/presentation/sobrantes_dialog.dart' << 'ORBILOQ_EOF'
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
ORBILOQ_EOF

echo "  - lib/features/kardex/presentation/kardex_page.dart"
mkdir -p "$(dirname 'lib/features/kardex/presentation/kardex_page.dart')"
cat > 'lib/features/kardex/presentation/kardex_page.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/auth_providers.dart';
import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/kardex_excel_exportador.dart';
import '../../../domain/models.dart';
import '../../../domain/sesion.dart';
import '../../aliados_no_conforme/presentation/aliados_no_conforme_dialog.dart';
import '../../despacho/presentation/despacho_dialog.dart';
import '../../importacion/presentation/importar_ordenes_dialog.dart';
import '../../importacion_fechas/presentation/importar_fechas_dialog.dart';
import '../../no_conforme/presentation/no_conforme_dialog.dart';
import '../../produccion/presentation/entrega_produccion_dialog.dart';
import '../../recepcion/presentation/recepcion_dialog.dart';
import '../../reproceso/presentation/reproceso_dialog.dart';
import '../../sobrantes/presentation/sobrantes_dialog.dart';
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
    final pal = palOf(context);
    final modoTema = ref.watch(temaProvider);

    return Scaffold(
      backgroundColor: pal.bg,
      appBar: AppBar(
        backgroundColor: pal.header,
        foregroundColor: pal.textPrimary,
        elevation: 0,
        toolbarHeight: 72,
        surfaceTintColor: pal.header,
        shape: Border(bottom: BorderSide(color: pal.cardBorder)),
        titleSpacing: 20,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 40,
                height: 40,
                color: Colors.white,
                child: Image.asset(
                  'assets/images/logo_orbiloq.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    color: AppColors.tealPrimary,
                    child: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: pal.textPrimary),
                    children: [
                      const TextSpan(text: 'ORBILOQ '),
                      TextSpan(
                        text: '| KARDEX MAESTRO',
                        style: TextStyle(fontWeight: FontWeight.w500, color: pal.accent),
                      ),
                    ],
                  ),
                ),
                Text(
                  'CONTROL OPERATIVO DE BODEGA Y PRODUCCIÓN',
                  style: TextStyle(fontSize: 10, color: pal.textMuted, letterSpacing: 0.4),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: modoTema == TemaModo.claro ? 'Cambiar a tema oscuro' : 'Cambiar a tema claro',
            onPressed: () => ref.read(temaProvider.notifier).alternar(),
            icon: Icon(
              modoTema == TemaModo.claro ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              color: pal.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          OutlinedButton.icon(
            onPressed: () => showImportarOrdenesDialog(context),
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: const Text('Importar Excel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: pal.textSecondary,
              side: BorderSide(color: pal.cardBorder),
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
          const SizedBox(width: 10),
          _SelectorPerfil(rol: rol),
          const SizedBox(width: 20),
        ],
      ),
      body: snapshot.when(
        loading: () => Center(child: CircularProgressIndicator(color: pal.accent)),
        error: (e, _) => Center(
          child: Text('Error cargando datos: $e', style: TextStyle(color: pal.textPrimary)),
        ),
        data: (s) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cabecera(rol: rol, enTransito: s.lotesConPendientes, kardex: s.kardex),
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

/// Botón-píldora "PERFIL DE TRABAJO" que abre un menú con los roles
/// disponibles. Solo muestra los 2 que funcionan hoy (Producción y Bodega).
class _SelectorPerfil extends ConsumerWidget {
  const _SelectorPerfil({required this.rol});

  final Rol rol;

  IconData _icono(Rol r) => r == Rol.produccion ? Icons.content_cut : Icons.warehouse_outlined;
  String _etiqueta(Rol r) => r == Rol.produccion ? 'Producción' : 'Bodega';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usarSupabase = ref.watch(usarSupabaseProvider);
    final sesion = usarSupabase ? ref.watch(usuarioSesionProvider).value : null;
    final esAdmin = !usarSupabase || sesion?.rolCuenta == RolCuenta.admin;
    final pal = palOf(context);

    final pastilla = esAdmin
        ? _pastillaDesplegable(context, ref, pal)
        : _pastillaFija(sesion?.nombre ?? _etiqueta(rol), pal);

    if (!usarSupabase) return pastilla; // modo memoria: sin sesión que cerrar

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pastilla,
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Cerrar sesión',
          icon: Icon(Icons.logout, size: 18, color: pal.textMuted),
          onPressed: () => ref.read(authRepositoryProvider)?.cerrarSesion(),
        ),
      ],
    );
  }

  /// Producción o Logística: no pueden cambiar de rol, solo ven quiénes son.
  Widget _pastillaFija(String nombre, AppPalette pal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.tealPrimary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.tealPrimary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icono(rol), size: 16, color: pal.accent),
          const SizedBox(width: 8),
          Text(nombre, style: TextStyle(color: pal.accent, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  /// Administrador (o modo memoria sin login): puede alternar entre vistas.
  Widget _pastillaDesplegable(BuildContext context, WidgetRef ref, AppPalette pal) {
    return PopupMenuButton<Rol>(
      color: pal.card,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: pal.cardBorder),
      ),
      onSelected: (r) => ref.read(rolProvider.notifier).cambiar(r),
      itemBuilder: (context) => [
        PopupMenuItem<Rol>(
          enabled: false,
          height: 32,
          child: Text(
            'PERFIL DE TRABAJO',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: pal.textMuted, letterSpacing: 0.5),
          ),
        ),
        for (final r in Rol.values)
          PopupMenuItem<Rol>(
            value: r,
            child: Row(
              children: [
                Icon(_icono(r), size: 18, color: r == rol ? pal.accent : pal.textSecondary),
                const SizedBox(width: 10),
                Text(_etiqueta(r),
                    style: TextStyle(
                      color: r == rol ? pal.accent : pal.textPrimary,
                      fontWeight: r == rol ? FontWeight.bold : FontWeight.normal,
                    )),
                if (r == rol) ...[
                  const Spacer(),
                  Icon(Icons.check, size: 16, color: pal.accent),
                ],
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.tealPrimary.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.tealPrimary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icono(rol), size: 16, color: pal.accent),
            const SizedBox(width: 8),
            Text(_etiqueta(rol),
                style: TextStyle(color: pal.accent, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 16, color: pal.accent),
          ],
        ),
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.rol, required this.enTransito, required this.kardex});

  final Rol rol;
  final int enTransito;
  final List<ItemKardex> kardex;

  Future<void> _exportar(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generando el archivo de Excel…'), duration: Duration(seconds: 2)),
    );
    try {
      if (rol == Rol.produccion) {
        await KardexExcelExportador.exportarProduccion(kardex);
      } else {
        await KardexExcelExportador.exportarBodega(kardex);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo exportar: $e'), backgroundColor: AppColors.alertRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = palOf(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Órdenes activas',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: pal.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              'Producción, bodega y despachos en un solo tablero',
              style: TextStyle(fontSize: 13, color: pal.textSecondary),
            ),
          ],
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (rol == Rol.produccion) ...[
              _BotonAccion(
                icono: Icons.history,
                texto: 'Entregar lote y ver historial',
                onPressed: () => showEntregaProduccionDialog(context),
              ),
              _BotonAccion(
                icono: Icons.report_gmailerrorred_outlined,
                texto: 'Productos no conforme',
                onPressed: () => showReprocesoDialog(context),
              ),
              _BotonAccion(
                icono: Icons.handshake_outlined,
                texto: 'Productos No Conformes de Aliados',
                onPressed: () => showAliadosNoConformeDialog(context),
              ),
              _BotonAccion(
                icono: Icons.file_download_outlined,
                texto: 'Exportar a Excel',
                onPressed: () => _exportar(context),
              ),
            ] else ...[
              _BotonAccion(
                icono: Icons.move_to_inbox_outlined,
                texto: 'Recibir lote ($enTransito)',
                onPressed: () => showRecepcionDialog(context),
              ),
              _BotonAccion(
                icono: Icons.report_gmailerrorred_outlined,
                texto: 'Producto no conforme',
                onPressed: () => showNoConformeDialog(context),
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
              _BotonAccion(
                icono: Icons.event_available_outlined,
                texto: 'Importar fechas',
                onPressed: () => showImportarFechasDialog(context),
              ),
              _BotonAccion(
                icono: Icons.add_box_outlined,
                texto: 'Bandeja de Sobrantes',
                onPressed: () => showSobrantesDialog(context),
              ),
              _BotonAccion(
                icono: Icons.file_download_outlined,
                texto: 'Exportar a Excel',
                onPressed: () => _exportar(context),
              ),
            ],
          ],
        ),
      ],
    );
  }
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
        foregroundColor: palOf(context).accent,
        side: const BorderSide(color: AppColors.tealPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
ORBILOQ_EOF

echo ""
echo "Listo. Ahora si: flutter analyze"
