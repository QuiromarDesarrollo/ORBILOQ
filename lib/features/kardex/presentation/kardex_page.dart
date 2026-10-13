import '../../../shared/widgets/selector_tema.dart';
import 'package:orbiloq_wms/shared/widgets/wms_alert.dart';
import '../../ciclos/presentation/dashboard_catalogo.dart';
import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';
import '../../admin/presentation/reportes_admin_dialog.dart';
import '../../admin/presentation/catalogos_dialog.dart';
import 'package:orbiloq_wms/shared/descargar_excel.dart';
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
  bool _sincronizando = false, _falloSincronizacion = false;
  DateTime? _ultimaActualizacion;

  Future<void> _cambiarArea() async {
    final area = await showModalBottomSheet<Rol>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(title: Text('Cambiar área')),
                for (final opcion in [
                  (
                    Rol.produccion,
                    'Producción',
                    Icons.precision_manufacturing_outlined,
                  ),
                  (Rol.logistica, 'Bodega', Icons.warehouse_outlined),
                  (Rol.despacho, 'Despacho', Icons.local_shipping_outlined),
                ])
                  if (!ref.read(usarSupabaseProvider) ||
                      (ref
                              .read(usuarioSesionProvider)
                              .value
                              ?.areas
                              .contains(opcion.$1) ??
                          false))
                    ListTile(
                      leading: Icon(opcion.$3),
                      title: Text(opcion.$2),
                      onTap: () => Navigator.pop(context, opcion.$1),
                    ),
              ],
            ),
          ),
    );
    if (mounted && area != null) ref.read(rolProvider.notifier).cambiar(area);
  }

  Future<void> _sincronizar() async {
    if (_sincronizando) return;
    setState(() {
      _sincronizando = true;
      _falloSincronizacion = false;
    });
    try {
      await ref.read(wmsRepositoryProvider).refrescar();
      if (mounted) setState(() => _ultimaActualizacion = DateTime.now());
    } catch (_) {
      if (mounted) setState(() => _falloSincronizacion = true);
    } finally {
      if (mounted) setState(() => _sincronizando = false);
    }
  }

  Widget _menuUsuario(UsuarioSesion? sesion, bool conectado, bool admin) {
    final nombre = sesion?.nombre ?? 'Usuario de demostración';
    final nav = palNavegacion(context);
    return PopupMenuButton<String>(
      tooltip: 'Menú de usuario',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (v) {
        if (v.startsWith('tema-')) {
          ref
              .read(temaProvider.notifier)
              .seleccionar(TemaModo.values.byName(v.substring(5)));
        }
        if (v == 'sync') _sincronizar();
        if (v == 'salir') ref.read(authRepositoryProvider)?.cerrarSesion();
        if (v == 'ordenes') showImportarOrdenesDialog(context);
      },
      itemBuilder:
          (_) => [
            PopupMenuItem<String>(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    sesion?.etiquetas ?? 'Administrador',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              enabled: false,
              height: 28,
              child: Text('Tema', style: TextStyle(fontSize: 11)),
            ),
            for (final tema in TemaModo.values)
              PopupMenuItem(
                value: 'tema-${tema.name}',
                child: Text(SelectorTema.nombres[tema]!),
              ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'sync',
              enabled: !_sincronizando,
              child: const Row(
                children: [
                  Icon(Icons.sync, size: 18),
                  SizedBox(width: 10),
                  Text('Sincronizar ahora'),
                ],
              ),
            ),
            if (admin)
              const PopupMenuItem(
                value: 'ordenes',
                child: Text('Importar órdenes ERP'),
              ),
            if (conectado)
              const PopupMenuItem(
                value: 'salir',
                child: Text(
                  'Cerrar sesión',
                  style: TextStyle(color: Color(0xffb42318)),
                ),
              ),
          ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xffe7efa2),
              child: Text(
                nombre.trim().isEmpty ? '?' : nombre.trim()[0].toUpperCase(),
                style: const TextStyle(
                  color: Color(0xff123e4f),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 9),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: nav.textPrimary,
                    ),
                  ),
                  Text(
                    sesion?.etiquetas ?? 'Administrador',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: nav.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.expand_more, size: 16, color: nav.textSecondary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = palOf(context);
    final nav = palNavegacion(context);
    final usarSupabase = ref.watch(usarSupabaseProvider);
    final sesion = usarSupabase ? ref.watch(usuarioSesionProvider).value : null;
    if (sesion?.soloGerencia == true) {
      return const DashboardCatalogoPage();
    }
    final rol = ref.watch(rolProvider);
    ref.listen(wmsSnapshotProvider, (_, siguiente) {
      if (siguiente.hasValue && !siguiente.hasError && !siguiente.isLoading) {
        _ultimaActualizacion = DateTime.now();
      }
    });
    final snapshot = ref.watch(wmsSnapshotProvider);
    final area = switch (rol) {
      Rol.produccion => 'Producción',
      Rol.logistica => 'Bodega',
      Rol.despacho => 'Despacho',
    };
    final falloSync = snapshot.hasError || _falloSincronizacion;
    final estadoSync =
        _sincronizando
            ? 'Sincronizando...'
            : falloSync
            ? 'Error de sincronización'
            : snapshot.hasValue
            ? 'Sincronizado'
            : 'Cargando datos';
    final esAdmin = !usarSupabase || sesion?.rolCuenta == RolCuenta.admin;
    final puedeCambiarArea = !usarSupabase || (sesion?.areas.length ?? 0) > 1;

    final compacto = MediaQuery.sizeOf(context).width < 1200;
    return Scaffold(
      backgroundColor: pal.bg,
      drawerEnableOpenDragGesture: false,
      drawer:
          esAdmin
              ? _AdminDrawer(
                rol: rol,
                kardex: snapshot.value?.kardex ?? const [],
                datosDisponibles: snapshot.hasValue,
                pageContext: context,
              )
              : null,
      appBar: AppBar(
        backgroundColor: nav.header,
        foregroundColor: nav.textPrimary,
        elevation: 0,
        toolbarHeight: compacto ? 68 : 64,
        surfaceTintColor: nav.header,
        shape: Border(bottom: BorderSide(color: nav.cardBorder)),
        titleSpacing: compacto ? 4 : 20,
        leadingWidth: compacto ? 44 : 56,
        bottom:
            (_sincronizando || falloSync)
                ? PreferredSize(
                  preferredSize: Size.fromHeight(falloSync ? 64 : 3),
                  child:
                      falloSync
                          ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            color: const Color(0xFFFFF3DB),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.wifi_off,
                                  size: 15,
                                  color: Color(0xff865100),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'No se pudieron actualizar los datos. Revisa la conexión.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xff865100),
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed:
                                      _sincronizando ? null : _sincronizar,
                                  icon: const Icon(Icons.refresh, size: 14),
                                  label: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          )
                          : const LinearProgressIndicator(
                            minHeight: 3,
                            color: AppColors.lima,
                            backgroundColor: Color(0xFF315B6A),
                          ),
                )
                : null,
        title:
            compacto
                ? Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 36,
                        height: 36,
                        color: Colors.white,
                        child: Image.asset(
                          'assets/images/logo_orbiloq.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap:
                            puedeCambiarArea && !_sincronizando
                                ? _cambiarArea
                                : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ORBILOQ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .5,
                                color: nav.textPrimary,
                              ),
                            ),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _sincronizando ? 'Sincronizando...' : area,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          _sincronizando
                                              ? AppColors.lima
                                              : nav.textSecondary,
                                    ),
                                  ),
                                ),
                                if (puedeCambiarArea && !_sincronizando)
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 15,
                                    color: nav.textSecondary,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
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
                          errorBuilder:
                              (context, error, stack) => Container(
                                color: AppColors.tealPrimary,
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 240,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium!.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: nav.textPrimary,
                              ),
                              text: 'ORBILOQ',
                            ),
                          ),
                          Text(
                            'Control operativo de bodega y producción',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: nav.textMuted,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Container(height: 28, width: 1, color: nav.cardBorder),
                    const SizedBox(width: 12),
                    _SelectorPerfil(rol: rol),
                  ],
                ),
        actions:
            compacto
                ? [
                  IconButton(
                    tooltip: '$estadoSync · Sincronizar',
                    onPressed: _sincronizando ? null : _sincronizar,
                    icon:
                        _sincronizando
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: WmsLoader(),
                            )
                            : Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(Icons.sync),
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          falloSync
                                              ? Colors.amber
                                              : snapshot.hasValue
                                              ? const Color(0xFF7ED957)
                                              : Colors.blueGrey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Menú',
                    position: PopupMenuPosition.under,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (v) {
                      if (v.startsWith('tema-')) {
                        ref
                            .read(temaProvider.notifier)
                            .seleccionar(
                              TemaModo.values.byName(v.substring(5)),
                            );
                      }
                      if (v == 'area' && puedeCambiarArea) _cambiarArea();
                      if (v == 'indicadores' &&
                          sesion?.puedeVerDashboards == true) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DashboardCatalogoPage(),
                          ),
                        );
                      }
                      if (v == 'ordenes') showImportarOrdenesDialog(context);
                      if (v == 'salir') {
                        ref.read(authRepositoryProvider)?.cerrarSesion();
                      }
                      if (v == 'produccion') {
                        ref.read(rolProvider.notifier).cambiar(Rol.produccion);
                      }
                      if (v == 'despacho') {
                        ref.read(rolProvider.notifier).cambiar(Rol.despacho);
                      }
                      if (v == 'logistica') {
                        ref.read(rolProvider.notifier).cambiar(Rol.logistica);
                      }
                    },
                    itemBuilder:
                        (_) => [
                          PopupMenuItem<String>(
                            enabled: false,
                            child: Row(
                              children: [
                                const Icon(Icons.person_outline, size: 20),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sesion?.nombre ??
                                            'Usuario de demostración',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        _ultimaActualizacion == null
                                            ? estadoSync
                                            : 'Actualizado a las ${TimeOfDay.fromDateTime(_ultimaActualizacion!).format(context)}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (puedeCambiarArea)
                            const PopupMenuItem(
                              value: 'area',
                              child: Row(
                                children: [
                                  Icon(Icons.warehouse_outlined, size: 20),
                                  SizedBox(width: 10),
                                  Text('Cambiar área'),
                                ],
                              ),
                            ),
                          if (!esAdmin && sesion?.puedeVerDashboards == true)
                            const PopupMenuItem(
                              value: 'indicadores',
                              child: Text('Indicadores de gestión'),
                            ),
                          const PopupMenuDivider(),
                          for (final tema in TemaModo.values)
                            PopupMenuItem(
                              value: 'tema-${tema.name}',
                              child: Text(SelectorTema.nombres[tema]!),
                            ),
                          if (esAdmin) ...[
                            const PopupMenuItem(
                              value: 'ordenes',
                              child: Text('Importar órdenes ERP'),
                            ),
                          ],
                          if (usarSupabase)
                            const PopupMenuItem(
                              value: 'salir',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.logout,
                                    color: Color(0xFFB42318),
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Cerrar sesión',
                                    style: TextStyle(color: Color(0xFFB42318)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                  ),
                ]
                : [
                  OutlinedButton.icon(
                    onPressed: _sincronizando ? null : _sincronizar,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: nav.textPrimary,
                      side: BorderSide(color: nav.cardBorder),
                      shape: const StadiumBorder(),
                    ),
                    icon: Icon(
                      Icons.sync,
                      size: 18,
                      color:
                          falloSync
                              ? Colors.amber
                              : _sincronizando
                              ? AppColors.lima
                              : const Color(0xff7ed957),
                    ),
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(estadoSync, style: const TextStyle(fontSize: 11)),
                        if (_ultimaActualizacion != null && !_sincronizando)
                          Text(
                            'Última: ${TimeOfDay.fromDateTime(_ultimaActualizacion!).format(context)}',
                            style: const TextStyle(fontSize: 9),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const SelectorTema(),
                  const SizedBox(width: 8),
                  Container(height: 28, width: 1, color: nav.cardBorder),
                  if (!esAdmin && sesion?.puedeVerDashboards == true)
                    IconButton(
                      tooltip: 'Indicadores de gestión',
                      icon: const Icon(Icons.insights),
                      onPressed:
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DashboardCatalogoPage(),
                            ),
                          ),
                    ),
                  _menuUsuario(sesion, usarSupabase, esAdmin),
                ],
      ),
      body: snapshot.when(
        loading: () => WmsLoadingPanel(),
        error:
            (e, _) => Center(
              child: Text(
                'Error cargando datos: $e',
                style: TextStyle(color: pal.textPrimary),
              ),
            ),
        data:
            (s) => Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(compacto ? 12 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final titulo = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: pal.accent,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'OPERACIONES / ${rol == Rol.produccion
                                                ? 'PRODUCCIÓN'
                                                : rol == Rol.logistica
                                                ? 'BODEGA'
                                                : 'DESPACHO'}',
                                            style: TextStyle(
                                              color: pal.textSecondary,
                                              fontSize: 11,
                                              letterSpacing: 1,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Control de operaciones',
                                            style:
                                                Theme.of(
                                                  context,
                                                ).textTheme.headlineLarge,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Visibilidad del taller, seguimiento de órdenes y movimientos.',
                                  style: TextStyle(color: pal.textSecondary),
                                ),
                              ],
                            );
                            final acciones = _Cabecera(
                              rol: rol,
                              enTransito: s.lotesConPendientes,
                            );
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
                          },
                        ),
                        const SizedBox(height: 20),
                        const KardexSummaryCards(),
                        const SizedBox(height: 20),
                        Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: pal.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: pal.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  20,
                                  20,
                                  0,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.table_rows_outlined,
                                      color: pal.accent,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Órdenes y seguimiento',
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                      ),
                                    ),
                                    Text(
                                      '${s.kardex.where((i) => !i.eliminada).length} líneas',
                                      style: TextStyle(
                                        color: pal.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const KardexFiltersBar(integrada: true),
                              const KardexTable(integrada: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
      r == Rol.produccion
          ? Icons.content_cut
          : r == Rol.despacho
          ? Icons.local_shipping_outlined
          : Icons.warehouse_outlined;
  String _etiqueta(Rol r) =>
      r == Rol.produccion
          ? 'Producción'
          : r == Rol.logistica
          ? 'Bodega'
          : 'Despacho';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usarSupabase = ref.watch(usarSupabaseProvider);
    final sesion = usarSupabase ? ref.watch(usuarioSesionProvider).value : null;

    final pal = palNavegacion(context);

    return (!usarSupabase || (sesion?.areas.length ?? 0) > 1)
        ? _pastillaDesplegable(context, ref, pal)
        : _pastillaFija(_etiqueta(rol), pal);
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
          Text(
            nombre,
            style: TextStyle(
              color: pal.accent,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// Administrador (o modo memoria sin login): puede alternar entre vistas.
  Widget _pastillaDesplegable(
    BuildContext context,
    WidgetRef ref,
    AppPalette pal,
  ) {
    return PopupMenuButton<Rol>(
      color: pal.card,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: pal.cardBorder),
      ),
      onSelected: (r) => ref.read(rolProvider.notifier).cambiar(r),
      itemBuilder:
          (context) => [
            PopupMenuItem<Rol>(
              enabled: false,
              height: 32,
              child: Text(
                'CAMBIAR ÁREA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: pal.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            for (final r in Rol.values)
              if (!ref.read(usarSupabaseProvider) ||
                  (ref.read(usuarioSesionProvider).value?.areas.contains(r) ??
                      false))
                PopupMenuItem<Rol>(
                  value: r,
                  child: Row(
                    children: [
                      Icon(
                        _icono(r),
                        size: 18,
                        color: r == rol ? pal.accent : pal.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _etiqueta(r),
                        style: TextStyle(
                          color: r == rol ? pal.accent : pal.textPrimary,
                          fontWeight:
                              r == rol ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
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
            Text(
              _etiqueta(rol),
              style: TextStyle(
                color: pal.accent,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 16, color: pal.accent),
          ],
        ),
      ),
    );
  }
}

class _AdminDrawer extends ConsumerWidget {
  const _AdminDrawer({
    required this.rol,
    required this.kardex,
    required this.datosDisponibles,
    required this.pageContext,
  });

  final Rol rol;
  final List<ItemKardex> kardex;
  final bool datosDisponibles;
  final BuildContext pageContext;

  Future<void> _exportar(BuildContext context, WidgetRef ref) async {
    mostrarAvisoSnack(
      context,
      const SnackBar(
        content: Text('Generando el archivo de Excel…'),
        duration: Duration(seconds: 2),
      ),
      tipo: TipoAviso.informacion,
    );
    try {
      final service = ref.read(importadorKardexProvider);
      if (service != null) {
        final archivo = await service.exportar(rol);
        await descargarExcel(
          ExcelKardex.generar(archivo),
          'orbiloq_${rol.name}.xlsx',
          titulo: 'Guardar tabla completa',
        );
        return;
      }
      if (rol == Rol.produccion) {
        await KardexExcelExportador.exportarProduccion(kardex);
      } else {
        await KardexExcelExportador.exportarBodega(kardex);
      }
    } catch (e) {
      if (context.mounted) {
        mostrarAvisoSnack(
          context,
          SnackBar(
            content: Text('No se pudo exportar: $e'),
            backgroundColor: AppColors.alertRed,
          ),
          tipo: TipoAviso.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = palNavegacion(context);
    final nombre = ref.watch(nombreOperarioProvider);
    final area = switch (rol) {
      Rol.produccion => 'Producción',
      Rol.logistica => 'Bodega',
      Rol.despacho => 'Despacho',
    };
    final usuario = nombre.trim().isEmpty ? 'Administrador' : nombre;
    final iniciales =
        usuario
            .split(RegExp(r'\s+'))
            .take(2)
            .map((p) => p.substring(0, 1))
            .join()
            .toUpperCase();
    Widget seccion(String titulo) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 6),
      child: Text(
        titulo,
        style: TextStyle(
          color: pal.textPrimary.withValues(alpha: .65),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
    return Drawer(
      width:
          MediaQuery.sizeOf(context).width < 380
              ? MediaQuery.sizeOf(context).width - 24
              : 340,
      backgroundColor: pal.header,
      semanticLabel: 'Menú del administrador',
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 8, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: pal.accent,
                    foregroundColor: pal.header,
                    child: Text(
                      iniciales,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          usuario,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: pal.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Acceso completo · $area',
                          style: TextStyle(
                            color: pal.textPrimary.withValues(alpha: .8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar menú',
                    onPressed: () => Scaffold.of(context).closeDrawer(),
                    icon: Icon(Icons.close, color: pal.textPrimary, size: 21),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: pal.textPrimary.withValues(alpha: .2)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  seccion('CONFIGURACIÓN'),
                  _enlace(
                    context,
                    Icons.manage_accounts_outlined,
                    'Administración',
                    'Catálogos, usuarios y personal',
                    () => showCatalogosDialog(pageContext),
                    destacado: true,
                  ),
                  seccion('ANÁLISIS'),
                  _enlace(
                    context,
                    Icons.dashboard_outlined,
                    'Dashboard',
                    'Resumen, tiempos y capacidad',
                    () => Navigator.of(pageContext).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DashboardCatalogoPage(),
                      ),
                    ),
                  ),
                  _enlace(
                    context,
                    Icons.analytics_outlined,
                    'Reportes y auditoría',
                    'Quién cambió qué y cuándo',
                    () => showReportesAdminDialog(pageContext),
                  ),
                  seccion('DATOS EN EXCEL'),
                  _enlace(
                    context,
                    Icons.upload_file_outlined,
                    'Importar tabla',
                    'Actualiza muchas OP a la vez',
                    () => showImportarKardexDialog(pageContext, rol),
                  ),
                  _enlace(
                    context,
                    Icons.file_download_outlined,
                    'Exportar tabla',
                    'Descarga todas las OP',
                    datosDisponibles ? () => _exportar(pageContext, ref) : null,
                  ),
                  _enlace(
                    context,
                    Icons.event_available_outlined,
                    'Importar fechas',
                    'Fechas esperadas por OP',
                    () => showImportarFechasDialog(pageContext),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: pal.textPrimary.withValues(alpha: .15)),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 4,
              ),
              leading: const Icon(
                Icons.logout,
                size: 19,
                color: Color(0xFFFFB4AB),
              ),
              title: const Text(
                'Cerrar sesión',
                style: TextStyle(
                  color: Color(0xFFFFB4AB),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Scaffold.of(context).closeDrawer();
                ref.read(authRepositoryProvider)?.cerrarSesion();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _enlace(
    BuildContext context,
    IconData icono,
    String texto,
    String descripcion,
    VoidCallback? accion, {
    bool destacado = false,
  }) {
    final pal = palNavegacion(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        tileColor: destacado ? pal.textPrimary.withValues(alpha: .09) : null,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:
                destacado ? pal.accent : pal.textPrimary.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icono,
            size: 19,
            color: destacado ? pal.header : pal.accent,
          ),
        ),
        title: Text(
          texto,
          style: TextStyle(
            color: pal.textPrimary.withValues(alpha: accion == null ? .45 : 1),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          descripcion,
          style: TextStyle(
            color: pal.textPrimary.withValues(
              alpha: accion == null ? .35 : .75,
            ),
            fontSize: 11,
          ),
        ),
        enabled: accion != null,
        onTap:
            accion == null
                ? null
                : () {
                  Scaffold.of(context).closeDrawer();
                  accion();
                },
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
    final pal = palOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'ACCIONES ${rol == Rol.produccion
              ? 'DE PRODUCCIÓN'
              : rol == Rol.logistica
              ? 'DE BODEGA'
              : 'DE DESPACHO'}',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
            color: pal.textSecondary,
          ),
        ),
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
              if (rol == Rol.logistica)
                _BotonAccion(
                  icono: Icons.move_to_inbox_outlined,
                  texto: 'Recibir lote ($enTransito)',
                  principal: true,
                  onPressed: () => showRecepcionDialog(context),
                ),
              if (rol == Rol.logistica)
                _BotonAccion(
                  icono: Icons.report_gmailerrorred_outlined,
                  texto: 'Producto no conforme',
                  onPressed: () => showNoConformeDialog(context),
                ),
              if (rol == Rol.despacho)
                _BotonAccion(
                  icono: Icons.local_shipping_outlined,
                  texto: 'Despacho por orden',
                  onPressed: () => showDespachoDialog(context),
                ),
              if (rol == Rol.despacho)
                _BotonAccion(
                  icono: Icons.domain_outlined,
                  texto: 'Estantes y tickets',
                  onPressed: () => showUbicacionesDialog(context),
                ),
              if (rol == Rol.logistica)
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
  const _BotonAccion({
    required this.icono,
    required this.texto,
    required this.onPressed,
    this.principal = false,
  });

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
            esCorporativo(context)
                ? AppColors.lima
                : principal
                ? Theme.of(context).colorScheme.primary
                : palOf(context).card,
        foregroundColor:
            esCorporativo(context)
                ? AppColors.petroleo
                : principal
                ? Colors.white
                : palOf(context).textPrimary,
        side: BorderSide(color: palOf(context).cardBorder),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
