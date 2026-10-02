import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';
import '../../admin/presentation/reportes_admin_dialog.dart';
import '../../admin/presentation/dashboard_ejecutivo_page.dart';
import '../../admin/presentation/catalogos_dialog.dart';
import 'package:file_picker/file_picker.dart';
import '../../../data/excel_kardex.dart';
import '../../importacion/presentation/importar_kardex_dialog.dart';
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
    final usarSupabase = ref.watch(usarSupabaseProvider);
    final sesion = usarSupabase ? ref.watch(usuarioSesionProvider).value : null;
    final esAdmin = !usarSupabase || sesion?.rolCuenta == RolCuenta.admin;

    final compacto = MediaQuery.sizeOf(context).width < 1200;
    return Scaffold(
      backgroundColor: pal.bg,
      drawerEnableOpenDragGesture: false,
      drawer: esAdmin
          ? _AdminDrawer(
              rol: rol,
              kardex: snapshot.value?.kardex ?? const [],
              datosDisponibles: snapshot.hasValue,
              pageContext: context)
          : null,
      appBar: AppBar(
        backgroundColor: pal.header,
        foregroundColor: pal.textPrimary,
        elevation: 0,
        toolbarHeight: 72,
        surfaceTintColor: pal.header,
        shape: Border(bottom: BorderSide(color: pal.cardBorder)),
        titleSpacing: 20,
        title: compacto
            ? const Text('ORBILOQ', style: TextStyle(fontSize: 18))
            : Row(
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
                          child: const Icon(Icons.inventory_2_outlined,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium!
                              .copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: pal.textPrimary),
                          children: [
                            const TextSpan(text: 'ORBILOQ '),
                            TextSpan(
                              text: '| KARDEX MAESTRO',
                              style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: pal.accent),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'CONTROL OPERATIVO DE BODEGA Y PRODUCCIÓN',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10,
                            color: pal.textMuted,
                            letterSpacing: 0.4),
                      ),
                    ],
                  )),
                ],
              ),
        actions: compacto
            ? [
                IconButton(
                    tooltip: 'Sincronizar',
                    onPressed: _sincronizando ? null : _sincronizar,
                    icon: const Icon(Icons.sync)),
                PopupMenuButton<String>(
                    tooltip: 'Menú',
                    onSelected: (v) {
                      if (v == 'tema') {
                        ref.read(temaProvider.notifier).alternar();
                      }
                      if (v == 'ordenes') showImportarOrdenesDialog(context);
                      if (v == 'salir') {
                        ref.read(authRepositoryProvider)?.cerrarSesion();
                      }
                      if (v == 'produccion') {
                        ref.read(rolProvider.notifier).cambiar(Rol.produccion);
                      }
                      if (v == 'logistica') {
                        ref.read(rolProvider.notifier).cambiar(Rol.logistica);
                      }
                    },
                    itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'tema', child: Text('Cambiar tema')),
                          if (esAdmin) ...[
                            const PopupMenuItem(
                                value: 'produccion',
                                child: Text('Vista Producción')),
                            const PopupMenuItem(
                                value: 'logistica',
                                child: Text('Vista Logística')),
                            const PopupMenuItem(
                                value: 'ordenes',
                                child: Text('Importar órdenes ERP')),
                          ],
                          if (usarSupabase)
                            const PopupMenuItem(
                                value: 'salir', child: Text('Cerrar sesión')),
                        ]),
              ]
            : [
                IconButton(
                  tooltip: modoTema == TemaModo.claro
                      ? 'Cambiar a tema oscuro'
                      : 'Cambiar a tema claro',
                  onPressed: () => ref.read(temaProvider.notifier).alternar(),
                  icon: Icon(
                    modoTema == TemaModo.claro
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                    color: pal.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                if (esAdmin) ...[
                  OutlinedButton.icon(
                    onPressed: () => showImportarOrdenesDialog(context),
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Importar órdenes ERP'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: pal.textSecondary,
                      side: BorderSide(color: pal.cardBorder),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                ElevatedButton.icon(
                  onPressed: _sincronizando ? null : _sincronizar,
                  icon: _sincronizando
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: WmsLoader(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sync, size: 18),
                  label: Text(
                      _sincronizando ? 'Sincronizando...' : 'Sincronizar BD'),
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
        loading: () => Center(child: WmsLoader(color: pal.accent)),
        error: (e, _) => Center(
          child: Text('Error cargando datos: $e',
              style: TextStyle(color: pal.textPrimary)),
        ),
        data: (s) => Column(
          children: [
            Expanded(
                child: SingleChildScrollView(
              padding: EdgeInsets.all(compacto ? 12 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(builder: (context, constraints) {
                    final titulo = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                                width: 4,
                                height: 38,
                                decoration: BoxDecoration(
                                    color: pal.accent,
                                    borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(
                                      'OPERACIONES / ${rol == Rol.produccion ? 'PRODUCCIÓN' : 'LOGÍSTICA'}',
                                      style: TextStyle(
                                          color: pal.textSecondary,
                                          fontSize: 11,
                                          letterSpacing: 1,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text('Control de operaciones',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineLarge),
                                ])),
                          ]),
                          const SizedBox(height: 8),
                          Text(
                              'Visibilidad del taller, seguimiento de órdenes y movimientos.',
                              style: TextStyle(color: pal.textSecondary)),
                        ]);
                    final acciones =
                        _Cabecera(rol: rol, enTransito: s.lotesConPendientes);
                    if (constraints.maxWidth < 1100) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          titulo,
                          const SizedBox(height: 16),
                          acciones,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(flex: 4, child: titulo),
                        const SizedBox(width: 24),
                        Expanded(flex: 6, child: acciones),
                      ],
                    );
                  }),
                  const SizedBox(height: 20),
                  const KardexSummaryCards(),
                  const SizedBox(height: 20),
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                        color: pal.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: pal.cardBorder)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                              child: Row(children: [
                                Icon(Icons.table_rows_outlined,
                                    color: pal.accent, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text('Órdenes y seguimiento',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium)),
                                Text(
                                    '${s.kardex.where((i) => !i.eliminada).length} líneas',
                                    style: TextStyle(
                                        color: pal.textSecondary,
                                        fontSize: 12)),
                              ])),
                          const KardexFiltersBar(integrada: true),
                          const KardexTable(integrada: true),
                        ]),
                  ),
                ],
              ),
            )),
          ],
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

  IconData _icono(Rol r) =>
      r == Rol.produccion ? Icons.content_cut : Icons.warehouse_outlined;
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
          Text(nombre,
              style: TextStyle(
                  color: pal.accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ],
      ),
    );
  }

  /// Administrador (o modo memoria sin login): puede alternar entre vistas.
  Widget _pastillaDesplegable(
      BuildContext context, WidgetRef ref, AppPalette pal) {
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
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: pal.textMuted,
                letterSpacing: 0.5),
          ),
        ),
        for (final r in Rol.values)
          PopupMenuItem<Rol>(
            value: r,
            child: Row(
              children: [
                Icon(_icono(r),
                    size: 18, color: r == rol ? pal.accent : pal.textSecondary),
                const SizedBox(width: 10),
                Text(_etiqueta(r),
                    style: TextStyle(
                      color: r == rol ? pal.accent : pal.textPrimary,
                      fontWeight:
                          r == rol ? FontWeight.bold : FontWeight.normal,
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
                style: TextStyle(
                    color: pal.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 16, color: pal.accent),
          ],
        ),
      ),
    );
  }
}

class _AdminDrawer extends ConsumerWidget {
  const _AdminDrawer(
      {required this.rol,
      required this.kardex,
      required this.datosDisponibles,
      required this.pageContext});

  final Rol rol;
  final List<ItemKardex> kardex;
  final bool datosDisponibles;
  final BuildContext pageContext;

  Future<void> _exportar(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Generando el archivo de Excel…'),
          duration: Duration(seconds: 2)),
    );
    try {
      final service = ref.read(importadorKardexProvider);
      if (service != null) {
        final archivo = await service.exportar(rol);
        await FilePicker.platform.saveFile(
            dialogTitle: 'Guardar tabla completa',
            fileName: 'orbiloq_${rol.name}.xlsx',
            bytes: ExcelKardex.generar(archivo),
            type: FileType.custom,
            allowedExtensions: ['xlsx']);
        return;
      }
      if (rol == Rol.produccion) {
        await KardexExcelExportador.exportarProduccion(kardex);
      } else {
        await KardexExcelExportador.exportarBodega(kardex);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('No se pudo exportar: $e'),
              backgroundColor: AppColors.alertRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = palOf(context);
    return Drawer(
      backgroundColor: pal.header,
      semanticLabel: 'Menú del administrador',
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 8),
              child: Row(children: [
                Expanded(
                    child: Text('Menú del administrador',
                        style: TextStyle(
                            color: pal.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold))),
                IconButton(
                    tooltip: 'Cerrar menú',
                    onPressed: () => Scaffold.of(context).closeDrawer(),
                    icon: const Icon(Icons.close)),
              ]),
            ),
            const Divider(),
            _enlace(context, Icons.manage_accounts_outlined, 'Administración',
                () => showCatalogosDialog(pageContext)),
            _enlace(context, Icons.analytics_outlined, 'Reportes y auditoría',
                () => showReportesAdminDialog(pageContext)),
            _enlace(context, Icons.dashboard_outlined, 'Dashboard ejecutivo',
                () => Navigator.of(pageContext).push(MaterialPageRoute<void>(builder: (_) => const DashboardEjecutivoPage()))),
            _enlace(context, Icons.upload_file_outlined, 'Importar tabla',
                () => showImportarKardexDialog(pageContext, rol)),
            _enlace(context, Icons.file_download_outlined, 'Extraer tabla',
                datosDisponibles ? () => _exportar(pageContext, ref) : null),
            _enlace(context, Icons.event_available_outlined, 'Importar fechas',
                () => showImportarFechasDialog(pageContext)),
          ],
        ),
      ),
    );
  }

  Widget _enlace(BuildContext context, IconData icono, String texto,
      VoidCallback? accion) {
    return ListTile(
      leading: Icon(icono, color: palOf(context).accent),
      title: Text(texto),
      enabled: accion != null,
      onTap: accion == null
          ? null
          : () {
              Scaffold.of(context).closeDrawer();
              accion();
            },
    );
  }
}

class _Cabecera extends ConsumerWidget {
  const _Cabecera({required this.rol, required this.enTransito});

  final Rol rol;
  final int enTransito;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = palOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
            'ACCIONES ${rol == Rol.produccion ? 'DE PRODUCCIÓN' : 'DE LOGÍSTICA'}',
            style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: pal.textSecondary)),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 10,
          runSpacing: 10,
          children: [
            if (rol == Rol.produccion) ...[
              _BotonAccion(
                icono: Icons.history,
                texto: 'Entregar lote y ver historial',
                principal: true,
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
            ] else ...[
              _BotonAccion(
                icono: Icons.move_to_inbox_outlined,
                texto: 'Recibir lote ($enTransito)',
                principal: true,
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
                icono: Icons.add_box_outlined,
                texto: 'Bandeja de Sobrantes',
                onPressed: () => showSobrantesDialog(context),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _BotonAccion extends StatelessWidget {
  const _BotonAccion(
      {required this.icono,
      required this.texto,
      required this.onPressed,
      this.principal = false});

  final IconData icono;
  final bool principal;
  final String texto;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icono, size: 16),
      label: Text(texto),
      style: OutlinedButton.styleFrom(
        backgroundColor:
            principal ? AppColors.tealPrimary : palOf(context).card,
        foregroundColor: principal ? Colors.white : palOf(context).textPrimary,
        side: BorderSide(color: palOf(context).cardBorder),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
