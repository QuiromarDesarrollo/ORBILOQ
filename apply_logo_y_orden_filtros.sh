#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Logo real en la barra + orden asc/desc en filtros de columna
# El logo ya existe en assets/images/logo_orbiloq.png (declarado en
# pubspec.yaml) y ya se usa en el login, asi que no hace falta agregar
# ningun archivo de imagen nuevo, solo este cambio de codigo.
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_logo_y_orden_filtros.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi
if [ ! -f "assets/images/logo_orbiloq.png" ]; then
  echo "ERROR: no se encontro assets/images/logo_orbiloq.png. Este script asume que ya existe (se usa en el login)."
  exit 1
fi

echo "Aplicando logo real + orden asc/desc en filtros..."

echo "  - lib/features/kardex/presentation/kardex_page.dart"
mkdir -p "$(dirname 'lib/features/kardex/presentation/kardex_page.dart')"
cat > 'lib/features/kardex/presentation/kardex_page.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/auth_providers.dart';
import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import '../../../domain/sesion.dart';
import '../../despacho/presentation/despacho_dialog.dart';
import '../../importacion/presentation/importar_ordenes_dialog.dart';
import '../../importacion_fechas/presentation/importar_fechas_dialog.dart';
import '../../no_conforme/presentation/no_conforme_dialog.dart';
import '../../produccion/presentation/entrega_produccion_dialog.dart';
import '../../recepcion/presentation/recepcion_dialog.dart';
import '../../reproceso/presentation/reproceso_dialog.dart';
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
              _Cabecera(rol: rol, enTransito: s.lotesConPendientes),
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
  const _Cabecera({required this.rol, required this.enTransito});

  final Rol rol;
  final int enTransito;

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

echo "  - lib/shared/widgets/multi_select_filter.dart"
mkdir -p "$(dirname 'lib/shared/widgets/multi_select_filter.dart')"
cat > 'lib/shared/widgets/multi_select_filter.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Diálogo de filtro con búsqueda y casillas. Devuelve el conjunto elegido
/// (vacío = sin filtro / TODOS) o `null` si se cancela.
Future<Set<T>?> showMultiSelectFilter<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required Set<T> selected,
  required String Function(T) labelOf,
}) {
  return showDialog<Set<T>>(
    context: context,
    builder: (_) => _MultiSelectDialog<T>(
      title: title,
      options: options,
      selected: selected,
      labelOf: labelOf,
    ),
  );
}

class _MultiSelectDialog<T> extends StatefulWidget {
  const _MultiSelectDialog({
    required this.title,
    required this.options,
    required this.selected,
    required this.labelOf,
  });

  final String title;
  final List<T> options;
  final Set<T> selected;
  final String Function(T) labelOf;

  @override
  State<_MultiSelectDialog<T>> createState() => _MultiSelectDialogState<T>();
}

enum _Orden { ninguno, ascendente, descendente }

class _MultiSelectDialogState<T> extends State<_MultiSelectDialog<T>> {
  late Set<T> _sel;
  String _query = '';
  _Orden _orden = _Orden.ninguno;

  @override
  void initState() {
    super.initState();
    // Si no hay filtro activo, se empieza sin nada marcado: así buscar y
    // marcar un ítem funciona desde el primer clic (antes se empezaba con
    // TODO marcado, y marcar un ítem buscado en realidad lo desmarcaba de
    // un conjunto ya completo — el resultado se veía "igual que antes").
    // Si se está reabriendo un filtro ya aplicado, se respeta esa selección.
    _sel = <T>{...widget.selected};
  }

  /// Compara por número si ambas etiquetas lo son (para que "2" quede antes
  /// que "10"), y si no, alfabéticamente sin distinguir mayúsculas.
  int _comparar(T a, T b) {
    final la = widget.labelOf(a);
    final lb = widget.labelOf(b);
    final na = num.tryParse(la);
    final nb = num.tryParse(lb);
    if (na != null && nb != null) return na.compareTo(nb);
    return la.toLowerCase().compareTo(lb.toLowerCase());
  }

  void _alternarOrden(_Orden tocado) {
    setState(() => _orden = _orden == tocado ? _Orden.ninguno : tocado);
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final visibles = widget.options.where((o) => widget.labelOf(o).toLowerCase().contains(q)).toList();
    if (_orden != _Orden.ninguno) {
      visibles.sort(_comparar);
      if (_orden == _Orden.descendente) {
        final invertidos = visibles.reversed.toList();
        visibles
          ..clear()
          ..addAll(invertidos);
      }
    }
    final todos = _sel.length == widget.options.length;
    final ninguno = _sel.isEmpty;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: Row(
        children: [
          const Icon(Icons.filter_alt, color: AppColors.primaryNavy),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar en lista...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Ordenar:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 8),
                _BotonOrden(
                  icono: Icons.arrow_upward,
                  etiqueta: 'Ascendente',
                  activo: _orden == _Orden.ascendente,
                  onPressed: () => _alternarOrden(_Orden.ascendente),
                ),
                const SizedBox(width: 6),
                _BotonOrden(
                  icono: Icons.arrow_downward,
                  etiqueta: 'Descendente',
                  activo: _orden == _Orden.descendente,
                  onPressed: () => _alternarOrden(_Orden.descendente),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              dense: true,
              tristate: true,
              activeColor: AppColors.primaryNavy,
              title: const Text('SELECCIONAR TODOS', style: TextStyle(fontWeight: FontWeight.bold)),
              value: todos ? true : (ninguno ? false : null),
              onChanged: (_) => setState(() {
                _sel = todos ? <T>{} : <T>{...widget.options};
              }),
            ),
            const Divider(height: 1),
            SizedBox(
              height: 240,
              child: visibles.isEmpty
                  ? const Center(child: Text('Sin coincidencias', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: visibles.length,
                      itemBuilder: (_, i) {
                        final opt = visibles[i];
                        return CheckboxListTile(
                          dense: true,
                          activeColor: AppColors.actionGreen,
                          title: Text(widget.labelOf(opt)),
                          value: _sel.contains(opt),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _sel.add(opt);
                            } else {
                              _sel.remove(opt);
                            }
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, (todos || ninguno) ? <T>{} : _sel),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryNavy,
            foregroundColor: Colors.white,
          ),
          child: const Text('APLICAR FILTRO', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

/// Botón pequeño tipo "chip" para elegir orden ascendente/descendente.
class _BotonOrden extends StatelessWidget {
  const _BotonOrden({
    required this.icono,
    required this.etiqueta,
    required this.activo,
    required this.onPressed,
  });

  final IconData icono;
  final String etiqueta;
  final bool activo;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: etiqueta,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: activo ? AppColors.primaryNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: activo ? AppColors.primaryNavy : Colors.grey.shade400),
          ),
          child: Icon(icono, size: 16, color: activo ? Colors.white : Colors.grey.shade700),
        ),
      ),
    );
  }
}
ORBILOQ_EOF

echo "Listo. Revisa el diff con: git diff --stat"
