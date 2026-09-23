#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Tema oscuro + selector de perfil arriba + filtro de OP (v14)
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_tema_oscuro_v14.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi

echo "Aplicando el tema oscuro..."

echo "  - lib/core/theme/app_theme.dart"
mkdir -p "$(dirname 'lib/core/theme/app_theme.dart')"
cat > 'lib/core/theme/app_theme.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primaryNavy = Color(0xFF173559);
  static const secondaryNavy = Color(0xFF1F436E);
  static const actionGreen = Color(0xFF2E8B57);
  static const actionOrange = Color(0xFFF37021);
  static const alertRed = Color(0xFFD32F2F);
  static const accentCyan = Color(0xFF00A8CC);
  static const background = Color(0xFFF4F6F9);

  // ---- Paleta del rediseño del Kardex (pantalla principal) ----
  static const tealPrimary = Color(0xFF0F766E);
  static const tealDark = Color(0xFF0B5750);
  static const tealSoft = Color(0xFFE6F4F2);
  static const slate900 = Color(0xFF0F172A);
  static const slate600 = Color(0xFF475569);
  static const slate400 = Color(0xFF94A3B8);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate50 = Color(0xFFF8FAFC);
  static const cardBorder = Color(0xFFE5E9F0);
  static const amberChip = Color(0xFFB45309);
  static const amberChipBg = Color(0xFFFFF7ED);
  static const redChipBg = Color(0xFFFEF2F2);
  static const greenChipBg = Color(0xFFECFDF5);
  static const blueChipBg = Color(0xFFEFF6FF);
  static const blueChip = Color(0xFF1D4ED8);

  // ---- Paleta oscura (rediseño del Kardex, tema dark) ----
  static const darkBg = Color(0xFF0B1220);
  static const darkHeader = Color(0xFF0E1729);
  static const darkCard = Color(0xFF141B2D);
  static const darkCardBorder = Color(0xFF232D42);
  static const darkInput = Color(0xFF0F1729);
  static const darkTextPrimary = Color(0xFFF1F5F9);
  static const darkTextSecondary = Color(0xFF8895AC);
  static const darkTextMuted = Color(0xFF5B6B85);
  static const tealAccent = Color(0xFF2DD4BF);
  static const chipRedBgDark = Color(0xFF3B1219);
  static const chipRedDark = Color(0xFFFCA5A5);
  static const chipGreenBgDark = Color(0xFF0F2E22);
  static const chipGreenDark = Color(0xFF6EE7B7);
  static const chipNeutralBgDark = Color(0xFF1B2438);
  static const chipNeutralDark = Color(0xFF94A3B8);
}

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryNavy),
        scaffoldBackgroundColor: AppColors.background,
      );
}

/// Decoración estándar de campos de texto.
InputDecoration wmsInput(String label, {IconData? icon, String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon),
    border: const OutlineInputBorder(),
    isDense: true,
  );
}
ORBILOQ_EOF

echo "  - lib/application/kardex_filters.dart"
mkdir -p "$(dirname 'lib/application/kardex_filters.dart')"
cat > 'lib/application/kardex_filters.dart' << 'ORBILOQ_EOF'
import '../domain/models.dart';

/// Filtros del kardex: búsqueda libre + cliente + estado + selección
/// específica de OP (columna). Todos opcionales / combinables.
class KardexFilters {
  const KardexFilters({
    this.busqueda = '',
    this.cliente,
    this.estado,
    this.ops = const {},
  });

  final String busqueda;
  final String? cliente;
  final String? estado; // etiqueta de EstadoItem, o null = todos
  final Set<String> ops; // vacío = todas las OP

  bool get hayFiltros =>
      busqueda.trim().isNotEmpty || cliente != null || estado != null || ops.isNotEmpty;

  KardexFilters copyWith({
    String? busqueda,
    Object? cliente = _sinCambio,
    Object? estado = _sinCambio,
    Set<String>? ops,
  }) {
    return KardexFilters(
      busqueda: busqueda ?? this.busqueda,
      cliente: identical(cliente, _sinCambio) ? this.cliente : cliente as String?,
      estado: identical(estado, _sinCambio) ? this.estado : estado as String?,
      ops: ops ?? this.ops,
    );
  }

  bool aplica(ItemKardex i) {
    if (ops.isNotEmpty && !ops.contains(i.item.op)) return false;
    if (cliente != null && i.item.cliente != cliente) return false;
    if (estado != null && i.estadoEtiqueta != estado) return false;
    final q = busqueda.trim().toLowerCase();
    if (q.isNotEmpty) {
      final texto = '${i.item.op} ${i.item.cliente} ${i.item.oc} ${i.item.codigo} '
              '${i.item.descripcion} ${i.item.talla}'
          .toLowerCase();
      if (!texto.contains(q)) return false;
    }
    return true;
  }
}

const _sinCambio = Object();

/// Valores disponibles en los desplegables/popups de filtro.
class OpcionesFiltro {
  const OpcionesFiltro({required this.clientes, required this.estados, required this.ops});
  final List<String> clientes;
  final List<String> estados;
  final List<String> ops;
}

/// Totales agregados para las tarjetas de resumen, calculados sobre la lista
/// que se le pase (normalmente la ya filtrada, para que reaccionen a los
/// filtros activos).
class KardexResumen {
  const KardexResumen({
    required this.unidadesPedidas,
    required this.cantidadOrdenes,
    required this.enProduccion,
    required this.recibidoEnBodega,
    required this.pendientePorDespachar,
  });

  final int unidadesPedidas;
  final int cantidadOrdenes;
  final int enProduccion;
  final int recibidoEnBodega;
  final int pendientePorDespachar;

  double get porcentajeProduccion => unidadesPedidas == 0 ? 0 : enProduccion / unidadesPedidas * 100;
  double get porcentajeBodega => unidadesPedidas == 0 ? 0 : recibidoEnBodega / unidadesPedidas * 100;

  factory KardexResumen.desde(List<ItemKardex> items) {
    var pedidas = 0, prod = 0, bodega = 0, pendiente = 0;
    final ops = <String>{};
    for (final i in items) {
      pedidas += i.cantidadPedida;
      prod += i.producido;
      bodega += i.recibido;
      pendiente += i.pendienteDespacho;
      ops.add(i.item.op);
    }
    return KardexResumen(
      unidadesPedidas: pedidas,
      cantidadOrdenes: ops.length,
      enProduccion: prod,
      recibidoEnBodega: bodega,
      pendientePorDespachar: pendiente,
    );
  }
}
ORBILOQ_EOF

echo "  - lib/application/providers.dart"
mkdir -p "$(dirname 'lib/application/providers.dart')"
cat > 'lib/application/providers.dart' << 'ORBILOQ_EOF'
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_importador_ordenes.dart';
import '../domain/models.dart';
import '../domain/wms_repository.dart';
import 'kardex_filters.dart';

/// Debe sobrescribirse en `main.dart` (o en tests) con la implementación deseada.
final wmsRepositoryProvider = Provider<WmsRepository>(
  (ref) => throw UnimplementedError('Sobrescribe wmsRepositoryProvider en main.dart'),
);

/// Solo disponible cuando la app corre contra Supabase; `null` en modo memoria
/// (la importación de Excel no tiene sentido sin una base de datos real detrás).
final importadorOrdenesProvider = Provider<SupabaseImportadorOrdenes?>((ref) => null);

final wmsSnapshotProvider = StreamProvider<WmsSnapshot>(
  (ref) => ref.watch(wmsRepositoryProvider).watch(),
);

final kardexProvider = Provider<List<ItemKardex>>(
  (ref) => ref.watch(wmsSnapshotProvider).value?.kardex ?? const <ItemKardex>[],
);

// ------------------------------------------------------------------- rol

class RolNotifier extends Notifier<Rol> {
  @override
  Rol build() => Rol.produccion;

  void cambiar(Rol rol) {
    if (rol == state) return;
    state = rol;
  }
}

final rolProvider = NotifierProvider<RolNotifier, Rol>(RolNotifier.new);

// --------------------------------------------------------------- filtros

class KardexFiltersNotifier extends Notifier<KardexFilters> {
  @override
  KardexFilters build() => const KardexFilters();

  void setBusqueda(String v) => state = state.copyWith(busqueda: v);
  void setCliente(String? v) => state = state.copyWith(cliente: v);
  void setEstado(String? v) => state = state.copyWith(estado: v);
  void setOps(Set<String> v) => state = state.copyWith(ops: v);
  void limpiar() => state = const KardexFilters();
}

final kardexFiltersProvider =
    NotifierProvider<KardexFiltersNotifier, KardexFilters>(KardexFiltersNotifier.new);

final kardexFiltradoProvider = Provider<List<ItemKardex>>((ref) {
  final kardex = ref.watch(kardexProvider);
  final filtros = ref.watch(kardexFiltersProvider);
  if (!filtros.hayFiltros) return kardex;
  return kardex.where(filtros.aplica).toList(growable: false);
});

final kardexResumenProvider = Provider<KardexResumen>((ref) {
  // Reacciona a lo que esté visible según los filtros activos.
  return KardexResumen.desde(ref.watch(kardexFiltradoProvider));
});

final opcionesFiltroProvider = Provider<OpcionesFiltro>((ref) {
  final kardex = ref.watch(kardexProvider);
  List<String> unicos(String Function(ItemKardex) f) => (kardex.map(f).toSet().toList()..sort());
  return OpcionesFiltro(
    clientes: unicos((i) => i.item.cliente),
    estados: unicos((i) => i.estadoEtiqueta),
    ops: unicos((i) => i.item.op),
  );
});

// ----------------------------------------------------------- paginación

const kardexFilasPorPagina = 25;

class KardexPaginaNotifier extends Notifier<int> {
  @override
  int build() {
    // Cualquier cambio en los filtros vuelve a la página 1, para no quedar
    // "perdido" en una página que ya no existe tras filtrar.
    ref.listen(kardexFiltersProvider, (_, __) => state = 0);
    return 0;
  }

  void ir(int pagina) => state = pagina;
}

final kardexPaginaProvider = NotifierProvider<KardexPaginaNotifier, int>(KardexPaginaNotifier.new);

final kardexPaginaActualProvider = Provider<List<ItemKardex>>((ref) {
  final filtrado = ref.watch(kardexFiltradoProvider);
  final pagina = ref.watch(kardexPaginaProvider);
  final desde = pagina * kardexFilasPorPagina;
  if (desde >= filtrado.length) return const [];
  final hasta = (desde + kardexFilasPorPagina).clamp(0, filtrado.length);
  return filtrado.sublist(desde, hasta);
});
ORBILOQ_EOF

echo "  - lib/features/kardex/presentation/kardex_filters_bar.dart"
mkdir -p "$(dirname 'lib/features/kardex/presentation/kardex_filters_bar.dart')"
cat > 'lib/features/kardex/presentation/kardex_filters_bar.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';

/// Barra de filtros: búsqueda libre + cliente + estado (tema oscuro).
class KardexFiltersBar extends ConsumerStatefulWidget {
  const KardexFiltersBar({super.key});

  @override
  ConsumerState<KardexFiltersBar> createState() => _KardexFiltersBarState();
}

class _KardexFiltersBarState extends ConsumerState<KardexFiltersBar> {
  late final TextEditingController _busquedaCtrl;

  @override
  void initState() {
    super.initState();
    _busquedaCtrl = TextEditingController(text: ref.read(kardexFiltersProvider).busqueda);
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtros = ref.watch(kardexFiltersProvider);
    final opciones = ref.watch(opcionesFiltroProvider);
    final notifier = ref.read(kardexFiltersProvider.notifier);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkCardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final estrecho = constraints.maxWidth < 760;
          final campos = <Widget>[
            SizedBox(
              width: estrecho ? double.infinity : 320,
              child: TextField(
                controller: _busquedaCtrl,
                onChanged: notifier.setBusqueda,
                style: const TextStyle(color: AppColors.darkTextPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Buscar por OP, cliente, OC o producto',
                  hintStyle: const TextStyle(color: AppColors.darkTextMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.darkTextMuted),
                  filled: true,
                  fillColor: AppColors.darkInput,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.darkCardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.darkCardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.tealAccent),
                  ),
                ),
              ),
            ),
            _Desplegable(
              ancho: estrecho ? double.infinity : 200,
              etiquetaTodos: 'Todos los clientes',
              valor: filtros.cliente,
              opciones: opciones.clientes,
              onChanged: notifier.setCliente,
            ),
            _Desplegable(
              ancho: estrecho ? double.infinity : 190,
              etiquetaTodos: 'Todos los estados',
              valor: filtros.estado,
              opciones: opciones.estados,
              onChanged: notifier.setEstado,
            ),
            OutlinedButton.icon(
              onPressed: () {
                _busquedaCtrl.clear();
                notifier.limpiar();
              },
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Limpiar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkTextSecondary,
                side: const BorderSide(color: AppColors.darkCardBorder),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ];

          return Wrap(spacing: 12, runSpacing: 12, children: campos);
        },
      ),
    );
  }
}

class _Desplegable extends StatelessWidget {
  const _Desplegable({
    required this.ancho,
    required this.etiquetaTodos,
    required this.valor,
    required this.opciones,
    required this.onChanged,
  });

  final double ancho;
  final String etiquetaTodos;
  final String? valor;
  final List<String> opciones;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.darkInput,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.darkCardBorder),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            isExpanded: true,
            isDense: true,
            value: valor,
            dropdownColor: AppColors.darkCard,
            hint: Text(etiquetaTodos,
                style: const TextStyle(fontSize: 13, color: AppColors.darkTextSecondary)),
            icon: const Icon(Icons.expand_more, size: 18, color: AppColors.darkTextMuted),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(etiquetaTodos,
                    style: const TextStyle(fontSize: 13, color: AppColors.darkTextPrimary)),
              ),
              for (final o in opciones)
                DropdownMenuItem<String?>(
                  value: o,
                  child: Text(o,
                      style: const TextStyle(fontSize: 13, color: AppColors.darkTextPrimary),
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
ORBILOQ_EOF

echo "  - lib/features/kardex/presentation/kardex_summary_cards.dart"
mkdir -p "$(dirname 'lib/features/kardex/presentation/kardex_summary_cards.dart')"
cat > 'lib/features/kardex/presentation/kardex_summary_cards.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';

class KardexSummaryCards extends ConsumerWidget {
  const KardexSummaryCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(kardexResumenProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final anchoTarjeta = constraints.maxWidth >= 900
            ? (constraints.maxWidth - 3 * 16) / 4
            : constraints.maxWidth >= 500
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: anchoTarjeta,
              child: _SummaryCard(
                titulo: 'UNIDADES PEDIDAS',
                valor: '${r.unidadesPedidas}',
                subtitulo: '+${r.cantidadOrdenes} órdenes',
                subtituloColor: AppColors.darkTextSecondary,
                icono: Icons.bar_chart_rounded,
              ),
            ),
            SizedBox(
              width: anchoTarjeta,
              child: _SummaryCard(
                titulo: 'EN PRODUCCIÓN',
                valor: '${r.enProduccion}',
                subtitulo: '${r.porcentajeProduccion.toStringAsFixed(1)}% del total',
                subtituloColor: AppColors.darkTextSecondary,
                icono: Icons.autorenew_rounded,
              ),
            ),
            SizedBox(
              width: anchoTarjeta,
              child: _SummaryCard(
                titulo: 'RECIBIDO EN BODEGA',
                valor: '${r.recibidoEnBodega}',
                subtitulo: '${r.porcentajeBodega.toStringAsFixed(1)}% del total',
                subtituloColor: AppColors.darkTextSecondary,
                icono: Icons.warehouse_rounded,
              ),
            ),
            SizedBox(
              width: anchoTarjeta,
              child: _SummaryCard(
                titulo: 'PENDIENTE POR DESPACHAR',
                valor: '${r.pendientePorDespachar}',
                subtitulo: r.pendientePorDespachar > 0 ? 'Requiere seguimiento' : 'Al día',
                subtituloColor: r.pendientePorDespachar > 0 ? AppColors.chipRedDark : AppColors.chipGreenDark,
                icono: Icons.inventory_2_rounded,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.titulo,
    required this.valor,
    required this.subtitulo,
    required this.subtituloColor,
    required this.icono,
  });

  final String titulo;
  final String valor;
  final String subtitulo;
  final Color subtituloColor;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkTextSecondary,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Icon(icono, size: 18, color: AppColors.tealAccent),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            valor,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.darkTextPrimary),
          ),
          const SizedBox(height: 4),
          Text(subtitulo, style: TextStyle(fontSize: 12, color: subtituloColor, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
ORBILOQ_EOF

echo "  - lib/features/kardex/presentation/kardex_table.dart"
mkdir -p "$(dirname 'lib/features/kardex/presentation/kardex_table.dart')"
cat > 'lib/features/kardex/presentation/kardex_table.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/multi_select_filter.dart';
import 'observacion_dialog.dart';

const List<double> _kAnchos = [110, 250, 190, 90, 100, 90, 110, 170, 130];
const List<String> _kEtiquetas = [
  'OP / OBSERVACIÓN', 'PRODUCTO', 'CLIENTE / OC', 'PEDIDAS',
  'PRODUCCIÓN', 'BODEGA', 'DESPACHADAS', 'AVANCE', 'ENTREGA',
];

const _kPaletaProducto = [
  Color(0xFF2DD4BF), Color(0xFF60A5FA), Color(0xFFA78BFA), Color(0xFFFBBF24),
  Color(0xFFF472B6), Color(0xFFFB923C), Color(0xFF34D399), Color(0xFF94A3B8),
];

Color _colorProducto(String codigo) => _kPaletaProducto[codigo.hashCode.abs() % _kPaletaProducto.length];

const _mesesEs = [
  '', 'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
];
String _fechaCorta(DateTime d) => '${d.day} ${_mesesEs[d.month]}';

/// Tabla del kardex, paginada y con tema oscuro. Cada página construye solo
/// sus propias filas, así que sigue escalando bien con miles de registros.
class KardexTable extends ConsumerWidget {
  const KardexTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filas = ref.watch(kardexPaginaActualProvider);
    final total = ref.watch(kardexFiltradoProvider).length;
    final pagina = ref.watch(kardexPaginaProvider);
    final totalPaginas = total == 0 ? 1 : ((total - 1) ~/ kardexFilasPorPagina) + 1;
    final anchoTabla = _kAnchos.fold<double>(0, (a, b) => a + b);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkCardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: anchoTabla,
              child: Column(
                children: [
                  Container(
                    color: AppColors.darkHeader,
                    child: Row(
                      children: [
                        for (var i = 0; i < _kEtiquetas.length; i++)
                          _Celda(
                            i,
                            i == 0
                                ? const _EncabezadoOp()
                                : Text(
                                    _kEtiquetas[i],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.darkTextSecondary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.darkCardBorder),
                  if (filas.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text('Sin resultados para los filtros aplicados.',
                            style: TextStyle(color: AppColors.darkTextMuted)),
                      ),
                    )
                  else
                    for (final item in filas) _KardexRow(item: item),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.darkCardBorder),
          _BarraPaginacion(pagina: pagina, totalPaginas: totalPaginas, total: total, filas: filas.length),
        ],
      ),
    );
  }
}

/// Encabezado de la columna OP con el ícono de embudo que abre el filtro de
/// selección múltiple, reutilizando el mismo diálogo de búsqueda+casillas
/// que ya usan los demás filtros (probado y corregido recientemente).
class _EncabezadoOp extends ConsumerWidget {
  const _EncabezadoOp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtros = ref.watch(kardexFiltersProvider);
    final opciones = ref.watch(opcionesFiltroProvider);
    final activo = filtros.ops.isNotEmpty;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'OP / OBSERVACIÓN',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.darkTextSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () async {
            final r = await showMultiSelectFilter<String>(
              context,
              title: 'Filtrar por OP',
              options: opciones.ops,
              selected: filtros.ops,
              labelOf: (v) => '#$v',
            );
            if (r != null) ref.read(kardexFiltersProvider.notifier).setOps(r);
          },
          child: Icon(
            Icons.filter_alt,
            size: 14,
            color: activo ? AppColors.tealAccent : AppColors.darkTextMuted,
          ),
        ),
      ],
    );
  }
}

class _BarraPaginacion extends ConsumerWidget {
  const _BarraPaginacion({
    required this.pagina,
    required this.totalPaginas,
    required this.total,
    required this.filas,
  });

  final int pagina;
  final int totalPaginas;
  final int total;
  final int filas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(kardexPaginaProvider.notifier);
    final desde = total == 0 ? 0 : pagina * kardexFilasPorPagina + 1;
    final hasta = pagina * kardexFilasPorPagina + filas;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Mostrando $desde-$hasta de $total registros',
            style: const TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: pagina > 0 ? () => notifier.ir(pagina - 1) : null,
                icon: const Icon(Icons.chevron_left, size: 18),
                label: const Text('Anterior'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.darkTextSecondary,
                  side: const BorderSide(color: AppColors.darkCardBorder),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: pagina + 1 < totalPaginas ? () => notifier.ir(pagina + 1) : null,
                icon: const Icon(Icons.chevron_right, size: 18),
                label: const Text('Siguiente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tealPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.darkCardBorder,
                  disabledForegroundColor: AppColors.darkTextMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Celda extends StatelessWidget {
  const _Celda(this.col, this.child, {this.alignment = Alignment.centerLeft});

  final int col;
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kAnchos[col],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Align(alignment: alignment, child: child),
      ),
    );
  }
}

class _KardexRow extends StatelessWidget {
  const _KardexRow({required this.item});

  final ItemKardex item;

  @override
  Widget build(BuildContext context) {
    final o = item.item;
    final completado = item.cantidadPedida > 0 && item.despachado >= item.cantidadPedida;
    final avance = item.cantidadPedida == 0
        ? 0.0
        : (item.recibido / item.cantidadPedida).clamp(0.0, 1.0);

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.darkCardBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Celda(
            0,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => showObservacionDialog(context, item),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.darkTextMuted),
                  ),
                ),
                Text('#${o.op}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.tealAccent)),
              ],
            ),
          ),
          _Celda(
            1,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 8, top: 2),
                  decoration: BoxDecoration(color: _colorProducto(o.codigo), borderRadius: BorderRadius.circular(3)),
                ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(o.descripcion,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.darkTextPrimary)),
                      Text('Talla ${o.talla}',
                          style: const TextStyle(fontSize: 11, color: AppColors.darkTextMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _Celda(
            2,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(o.cliente, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.darkTextPrimary)),
                if (o.oc.isNotEmpty)
                  Text('OC ${o.oc}', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.darkTextMuted)),
              ],
            ),
          ),
          _Celda(3, Text('${item.cantidadPedida}',
                  style: const TextStyle(fontSize: 13, color: AppColors.darkTextPrimary)),
              alignment: Alignment.center),
          _Celda(4, Text('${item.producido}', style: const TextStyle(fontSize: 13, color: AppColors.tealAccent)),
              alignment: Alignment.center),
          _Celda(5, Text('${item.recibido}', style: const TextStyle(fontSize: 13, color: Color(0xFF60A5FA))),
              alignment: Alignment.center),
          _Celda(6, Text('${item.despachado}', style: const TextStyle(fontSize: 13, color: Color(0xFFFBBF24))),
              alignment: Alignment.center),
          _Celda(7, _Avance(porcentaje: avance, completado: completado)),
          _Celda(8, _ChipEntrega(item: item, completado: completado)),
        ],
      ),
    );
  }
}

class _Avance extends StatelessWidget {
  const _Avance({required this.porcentaje, required this.completado});

  final double porcentaje;
  final bool completado;

  @override
  Widget build(BuildContext context) {
    final color = completado ? AppColors.chipGreenDark : AppColors.tealAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: completado ? 1 : porcentaje,
            minHeight: 6,
            backgroundColor: AppColors.darkCardBorder,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          completado ? 'Completado' : '${(porcentaje * 100).toStringAsFixed(0)}% recibido',
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ChipEntrega extends StatelessWidget {
  const _ChipEntrega({required this.item, required this.completado});

  final ItemKardex item;
  final bool completado;

  @override
  Widget build(BuildContext context) {
    if (completado) {
      return _chip('ENTREGADO', AppColors.chipGreenDark, AppColors.chipGreenBgDark, Icons.check_circle_outline);
    }
    final fecha = item.fechaEntregaLogistica;
    if (fecha == null) {
      return _chip('Sin fecha', AppColors.darkTextMuted, AppColors.chipNeutralBgDark, Icons.event_outlined);
    }
    final vencida = fecha.isBefore(DateTime.now());
    return _chip(
      _fechaCorta(fecha),
      vencida ? AppColors.chipRedDark : AppColors.darkTextSecondary,
      vencida ? AppColors.chipRedBgDark : AppColors.chipNeutralBgDark,
      Icons.event_outlined,
    );
  }

  Widget _chip(String texto, Color color, Color fondo, IconData icono) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 12, color: color),
          const SizedBox(width: 4),
          Text(texto, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
ORBILOQ_EOF

echo "  - lib/features/kardex/presentation/kardex_page.dart"
mkdir -p "$(dirname 'lib/features/kardex/presentation/kardex_page.dart')"
cat > 'lib/features/kardex/presentation/kardex_page.dart' << 'ORBILOQ_EOF'
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
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkHeader,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        toolbarHeight: 72,
        surfaceTintColor: AppColors.darkHeader,
        shape: const Border(bottom: BorderSide(color: AppColors.darkCardBorder)),
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkTextPrimary),
                    children: [
                      TextSpan(text: 'ORBILOQ '),
                      TextSpan(
                        text: '| KARDEX MAESTRO',
                        style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.tealAccent),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'CONTROL OPERATIVO DE BODEGA Y PRODUCCIÓN',
                  style: TextStyle(fontSize: 10, color: AppColors.darkTextMuted, letterSpacing: 0.4),
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
              foregroundColor: AppColors.darkTextSecondary,
              side: const BorderSide(color: AppColors.darkCardBorder),
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
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.tealAccent)),
        error: (e, _) => Center(
          child: Text('Error cargando datos: $e', style: const TextStyle(color: AppColors.darkTextPrimary)),
        ),
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

/// Botón-píldora "PERFIL DE TRABAJO" que abre un menú con los roles
/// disponibles. Solo muestra los 2 que funcionan hoy (Producción y Bodega).
class _SelectorPerfil extends ConsumerWidget {
  const _SelectorPerfil({required this.rol});

  final Rol rol;

  IconData _icono(Rol r) => r == Rol.produccion ? Icons.content_cut : Icons.warehouse_outlined;
  String _etiqueta(Rol r) => r == Rol.produccion ? 'Producción' : 'Bodega';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<Rol>(
      color: AppColors.darkCard,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.darkCardBorder),
      ),
      onSelected: (r) => ref.read(rolProvider.notifier).cambiar(r),
      itemBuilder: (context) => [
        const PopupMenuItem<Rol>(
          enabled: false,
          height: 32,
          child: Text(
            'PERFIL DE TRABAJO',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.darkTextMuted, letterSpacing: 0.5),
          ),
        ),
        for (final r in Rol.values)
          PopupMenuItem<Rol>(
            value: r,
            child: Row(
              children: [
                Icon(_icono(r), size: 18, color: r == rol ? AppColors.tealAccent : AppColors.darkTextSecondary),
                const SizedBox(width: 10),
                Text(_etiqueta(r),
                    style: TextStyle(
                      color: r == rol ? AppColors.tealAccent : AppColors.darkTextPrimary,
                      fontWeight: r == rol ? FontWeight.bold : FontWeight.normal,
                    )),
                if (r == rol) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 16, color: AppColors.tealAccent),
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
            Icon(_icono(rol), size: 16, color: AppColors.tealAccent),
            const SizedBox(width: 8),
            Text(_etiqueta(rol),
                style: const TextStyle(color: AppColors.tealAccent, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 16, color: AppColors.tealAccent),
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
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Órdenes activas',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.darkTextPrimary),
            ),
            SizedBox(height: 2),
            Text(
              'Producción, bodega y despachos en un solo tablero',
              style: TextStyle(fontSize: 13, color: AppColors.darkTextSecondary),
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
        foregroundColor: AppColors.tealAccent,
        side: const BorderSide(color: AppColors.tealPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
ORBILOQ_EOF

echo ""
echo "Listo. Siguiente paso:"
echo "  flutter analyze"
echo "  flutter test"
