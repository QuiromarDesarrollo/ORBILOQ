#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Exportar a Excel el historico completo de cada vista (v50)
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_exportar_excel_v50.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi
echo "Aplicando la exportacion a Excel..."

echo "  - lib/features/kardex/presentation/kardex_table.dart"
mkdir -p "$(dirname 'lib/features/kardex/presentation/kardex_table.dart')"
cat > 'lib/features/kardex/presentation/kardex_table.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/kardex_filters.dart';
import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/multi_select_filter.dart';
import 'observacion_dialog.dart';

// Columnas para el rol Producción (Taller). Todas tienen filtro por columna.
const List<double> _kAnchosProduccion = [100, 160, 150, 95, 140, 95, 140, 170, 110, 110, 115];
const List<String> kEtiquetasProduccion = [
  'OP / OBS.', 'PRODUCTO', 'CLIENTE / OC', 'CANTIDAD',
  'ENTREGADO A LOGÍSTICA', 'PENDIENTE', 'PRODUCTO NO CONFORME',
  'ESTADOS', 'FECHA DE ENTREGA', 'FECHA ESPERADA', 'DÍAS FALTANTES',
];
// A qué columna de filtro corresponde cada encabezado de Producción (por
// índice). `null` = sin filtro en esa columna.
const List<String?> kColumnasProduccion = [
  ColKardex.op, ColKardex.producto, ColKardex.cliente, ColKardex.cantidad,
  ColKardex.entregado, ColKardex.pendiente, ColKardex.noConforme,
  ColKardex.estadoProduccion, ColKardex.fechaEntrega, ColKardex.fechaEsperada, ColKardex.diasFaltantes,
];

// Columnas para el rol Logística (Bodega). Todas tienen filtro por columna.
const List<double> _kAnchosBodega = [100, 150, 150, 90, 135, 135, 85, 120, 120, 95, 100, 100, 105];
const List<String> kEtiquetasBodega = [
  'OP / OBS.', 'PRODUCTO', 'CLIENTE / OC', 'PEDIDAS',
  'ENTREGADO POR PRODUCCIÓN', 'PENDIENTE POR PRODUCCIÓN', 'BODEGA', 'DESPACHADAS',
  'PRODUCTO NO CONFORME', 'ESTADOS', 'FECHA DE ENTREGA', 'FECHA ESPERADA', 'DÍAS FALTANTES',
];
const List<String?> kColumnasBodega = [
  ColKardex.op, ColKardex.producto, ColKardex.cliente, ColKardex.pedidas,
  ColKardex.produccion, ColKardex.pendienteProduccionBodega, ColKardex.bodega, ColKardex.despachadas,
  ColKardex.noConformeBodega, ColKardex.estadoBodega, ColKardex.fechaEntregaBodega,
  ColKardex.fechaEsperadaBodega, ColKardex.diasFaltantesBodega,
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

/// Tabla del kardex, paginada, con columnas distintas según el rol.
class KardexTable extends ConsumerWidget {
  const KardexTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filas = ref.watch(kardexPaginaActualProvider);
    final total = ref.watch(kardexFiltradoProvider).length;
    final pagina = ref.watch(kardexPaginaProvider);
    final rol = ref.watch(rolProvider);
    final esProduccion = rol == Rol.produccion;
    final anchos = esProduccion ? _kAnchosProduccion : _kAnchosBodega;
    final etiquetas = esProduccion ? kEtiquetasProduccion : kEtiquetasBodega;
    final columnas = esProduccion ? kColumnasProduccion : kColumnasBodega;
    final totalPaginas = total == 0 ? 1 : ((total - 1) ~/ kardexFilasPorPagina) + 1;
    final anchoTabla = anchos.fold<double>(0, (a, b) => a + b);
    final pal = palOf(context);

    return Container(
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.cardBorder),
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
                    color: pal.header,
                    child: Row(
                      children: [
                        for (var i = 0; i < etiquetas.length; i++)
                          _Celda(
                            i,
                            anchos,
                            columnas[i] == null
                                ? Text(
                                    etiquetas[i],
                                    maxLines: 2,
                                    softWrap: true,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: pal.textSecondary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                      letterSpacing: 0.1,
                                      height: 1.2,
                                    ),
                                  )
                                : _EncabezadoConFiltro(
                                    columna: columnas[i]!,
                                    etiqueta: etiquetas[i],
                                    esOp: columnas[i] == ColKardex.op,
                                  ),
                          ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: pal.cardBorder),
                  if (filas.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text('Sin resultados para los filtros aplicados.',
                            style: TextStyle(color: pal.textMuted)),
                      ),
                    )
                  else
                    for (final item in filas) _KardexRow(item: item, anchos: anchos, esProduccion: esProduccion),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: pal.cardBorder),
          _BarraPaginacion(pagina: pagina, totalPaginas: totalPaginas, total: total, filas: filas.length),
        ],
      ),
    );
  }
}

/// Encabezado de columna con el ícono de embudo que abre el filtro de
/// selección múltiple (búsqueda + casillas), para cualquier columna.
class _EncabezadoConFiltro extends ConsumerWidget {
  const _EncabezadoConFiltro({required this.columna, required this.etiqueta, this.esOp = false});

  final String columna;
  final String etiqueta;
  final bool esOp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtros = ref.watch(kardexFiltersProvider);
    final opciones = ref.watch(opcionesFiltroProvider);
    final activo = filtros.valoresDe(columna).isNotEmpty;
    final pal = palOf(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            etiqueta,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: pal.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 0.1,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () async {
            final r = await showMultiSelectFilter<String>(
              context,
              title: 'Filtrar por $etiqueta',
              options: opciones.de(columna),
              selected: filtros.valoresDe(columna),
              labelOf: esOp ? (v) => '#$v' : (v) => v,
            );
            if (r != null) ref.read(kardexFiltersProvider.notifier).setColumna(columna, r);
          },
          child: Icon(
            Icons.filter_alt,
            size: 14,
            color: activo ? pal.accent : pal.textMuted,
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
    final pal = palOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Mostrando $desde-$hasta de $total registros',
            style: TextStyle(fontSize: 12, color: pal.textSecondary),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: pagina > 0 ? () => notifier.ir(pagina - 1) : null,
                icon: const Icon(Icons.chevron_left, size: 18),
                label: const Text('Anterior'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: pal.textSecondary,
                  side: BorderSide(color: pal.cardBorder),
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
                  disabledBackgroundColor: pal.cardBorder,
                  disabledForegroundColor: pal.textMuted,
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
  const _Celda(this.col, this.anchos, this.child, {this.alignment = Alignment.centerLeft});

  final int col;
  final List<double> anchos;
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: anchos[col],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Align(alignment: alignment, child: child),
      ),
    );
  }
}

class _KardexRow extends StatelessWidget {
  const _KardexRow({required this.item, required this.anchos, required this.esProduccion});

  final ItemKardex item;
  final List<double> anchos;
  final bool esProduccion;

  @override
  Widget build(BuildContext context) {
    final pal = palOf(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: pal.cardBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _celdaOp(pal),
          _celdaProducto(pal),
          _celdaClienteOc(pal),
          if (esProduccion) ..._celdasProduccion(pal) else ..._celdasBodega(pal),
        ],
      ),
    );
  }

  Widget _celdaOp(AppPalette pal) {
    final o = item.item;
    return _Celda(
      0,
      anchos,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder: (context) => InkWell(
              onTap: () => showObservacionDialog(context, item),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.chat_bubble_outline, size: 16, color: pal.textMuted),
              ),
            ),
          ),
          Text('#${o.op}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: pal.accent)),
        ],
      ),
    );
  }

  Widget _celdaProducto(AppPalette pal) {
    final o = item.item;
    return _Celda(
      1,
      anchos,
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
            child: Builder(
              builder: (context) => InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => _mostrarProductoCompleto(context, o),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(o.descripcion,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: pal.textPrimary)),
                    Text('Talla ${o.talla}', style: TextStyle(fontSize: 11, color: pal.textMuted)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarProductoCompleto(BuildContext context, ItemOrden o) {
    final pal = palOf(context);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: pal.card,
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: _colorProducto(o.codigo), borderRadius: BorderRadius.circular(3)),
            ),
            Expanded(
              child: Text('Producto', style: TextStyle(color: pal.textPrimary)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              o.descripcion,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: pal.textPrimary),
            ),
            const SizedBox(height: 12),
            _filaDato('Código', o.codigo, pal),
            _filaDato('Talla', o.talla, pal),
            _filaDato('OP', o.op, pal),
            if (o.oc.isNotEmpty) _filaDato('OC', o.oc, pal),
            _filaDato('Cliente', o.cliente, pal),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CERRAR')),
        ],
      ),
    );
  }

  Widget _filaDato(String etiqueta, String valor, AppPalette pal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 13, color: pal.textSecondary),
          children: [
            TextSpan(text: '$etiqueta: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: valor, style: TextStyle(color: pal.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _celdaClienteOc(AppPalette pal) {
    final o = item.item;
    return _Celda(
      2,
      anchos,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(o.cliente,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: pal.textPrimary)),
          if (o.oc.isNotEmpty)
            Text('OC ${o.oc}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: pal.textMuted)),
        ],
      ),
    );
  }

  // ------------------------------------------------------- vista Producción

  List<Widget> _celdasProduccion(AppPalette pal) {
    final noConforme = item.pendienteReproceso;
    return [
      _Celda(3, anchos, Text('${item.cantidadPedida}', style: TextStyle(fontSize: 13, color: pal.textPrimary)),
          alignment: Alignment.center),
      _Celda(4, anchos, Text('${item.producido}', style: TextStyle(fontSize: 13, color: pal.accent)),
          alignment: Alignment.center),
      _Celda(
        5,
        anchos,
        Text('${item.pendienteProduccion}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: item.pendienteProduccion > 0 ? pal.chipRed : pal.textMuted,
            )),
        alignment: Alignment.center,
      ),
      _Celda(
        6,
        anchos,
        Text(
          '$noConforme',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: noConforme > 0 ? pal.warning : pal.textMuted,
          ),
        ),
        alignment: Alignment.center,
      ),
      _Celda(7, anchos, _celdaEstado(pal)),
      _Celda(8, anchos, _chipFecha(item.fechaEntrega, pal)),
      _Celda(9, anchos, _chipFecha(item.fechaEsperadaProduccion, pal)),
      _Celda(10, anchos, _chipDiasFaltantes(item.fechaEsperadaProduccion, pal)),
    ];
  }

  Widget _celdaEstado(AppPalette pal) {
    final e = item.estadoProduccion;
    final Color color;
    final Color fondo;
    final IconData icono;
    switch (e) {
      case EstadoProduccion.completado:
        color = pal.chipGreen;
        fondo = pal.chipGreenBg;
        icono = Icons.check_circle_outline;
      case EstadoProduccion.parcialPorRetardo:
        color = pal.chipRed;
        fondo = pal.chipRedBg;
        icono = Icons.warning_amber_outlined;
      case EstadoProduccion.parcialPorEntregar:
        color = pal.textSecondary;
        fondo = pal.chipNeutralBg;
        icono = Icons.hourglass_bottom;
    }
    return _chip(e.etiqueta, color, fondo, icono);
  }

  Widget _chipFecha(DateTime? fecha, AppPalette pal) {
    if (fecha == null) {
      return _chip('Sin fecha', pal.textMuted, pal.chipNeutralBg, Icons.event_outlined);
    }
    return _chip(_fechaCorta(fecha), pal.textSecondary, pal.chipNeutralBg, Icons.event_outlined);
  }

  // ------------------------------------------------------- vista Bodega

  List<Widget> _celdasBodega(AppPalette pal) {
    final noConforme = item.pendienteReproceso;
    return [
      _Celda(3, anchos, Text('${item.cantidadPedida}', style: TextStyle(fontSize: 13, color: pal.textPrimary)),
          alignment: Alignment.center),
      _Celda(4, anchos, Text('${item.producido}', style: TextStyle(fontSize: 13, color: pal.accent)),
          alignment: Alignment.center),
      _Celda(
        5,
        anchos,
        Text('${item.pendienteProduccion}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: item.pendienteProduccion > 0 ? pal.chipRed : pal.textMuted,
            )),
        alignment: Alignment.center,
      ),
      _Celda(6, anchos, Text('${item.recibido}', style: TextStyle(fontSize: 13, color: pal.info)),
          alignment: Alignment.center),
      _Celda(7, anchos, Text('${item.despachado}', style: TextStyle(fontSize: 13, color: pal.warning)),
          alignment: Alignment.center),
      _Celda(
        8,
        anchos,
        Text(
          '$noConforme',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: noConforme > 0 ? pal.warning : pal.textMuted,
          ),
        ),
        alignment: Alignment.center,
      ),
      _Celda(9, anchos, _celdaEstadoLogistica(pal)),
      _Celda(10, anchos, _chipFecha(item.fechaEntrega, pal)),
      _Celda(11, anchos, _chipFecha(item.fechaEsperadaLogistica, pal)),
      _Celda(12, anchos, _chipDiasFaltantes(item.fechaEsperadaLogistica, pal)),
    ];
  }

  Widget _chipDiasFaltantes(DateTime? esperada, AppPalette pal) {
    if (esperada == null) {
      return _chip('Sin fecha', pal.textMuted, pal.chipNeutralBg, Icons.hourglass_empty);
    }
    final hoy = DateTime.now();
    final soloHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final soloEsperada = DateTime(esperada.year, esperada.month, esperada.day);
    final dias = soloEsperada.difference(soloHoy).inDays;
    if (dias < 0) {
      return _chip('Vencido ${-dias}d', pal.chipRed, pal.chipRedBg, Icons.warning_amber_outlined);
    }
    if (dias == 0) {
      return _chip('HOY', pal.warning, pal.chipNeutralBg, Icons.today_outlined);
    }
    return _chip('Faltan ${dias}d', pal.textSecondary, pal.chipNeutralBg, Icons.hourglass_bottom);
  }

  Widget _celdaEstadoLogistica(AppPalette pal) {
    final e = item.estadoLogistica;
    final Color color;
    final Color fondo;
    final IconData icono;
    switch (e) {
      case EstadoLogistica.completado:
        color = pal.chipGreen;
        fondo = pal.chipGreenBg;
        icono = Icons.check_circle_outline;
      case EstadoLogistica.pendienteRecibir:
        color = pal.textSecondary;
        fondo = pal.chipNeutralBg;
        icono = Icons.hourglass_bottom;
      case EstadoLogistica.pendientePorDespachar:
        color = pal.warning;
        fondo = pal.chipNeutralBg;
        icono = Icons.local_shipping_outlined;
    }
    return _chip(e.etiqueta, color, fondo, icono);
  }

  Widget _chip(String texto, Color color, Color fondo, IconData icono) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 11, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
ORBILOQ_EOF

echo "  - lib/data/kardex_excel_exportador.dart"
mkdir -p "$(dirname 'lib/data/kardex_excel_exportador.dart')"
cat > 'lib/data/kardex_excel_exportador.dart' << 'ORBILOQ_EOF'
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import '../application/kardex_columnas.dart';
import '../domain/models.dart';
import '../features/kardex/presentation/kardex_table.dart';

/// Exporta el kardex a un .xlsx con exactamente las mismas columnas, en el
/// mismo orden y con los mismos valores que se ven en la tabla — reutiliza
/// las listas de encabezados/columnas de `kardex_table.dart` y los mismos
/// extractores de valor de `kardex_columnas.dart` (los que ya usa el filtro
/// por columna), así nunca se puede desincronizar de lo que se ve en pantalla.
///
/// Siempre exporta TODO el histórico de esa vista, sin importar los filtros
/// que estén activos en ese momento en la tabla.
class KardexExcelExportador {
  const KardexExcelExportador._();

  static Future<void> exportarProduccion(List<ItemKardex> todosLosItems) => _exportar(
        items: todosLosItems,
        etiquetas: kEtiquetasProduccion,
        columnas: kColumnasProduccion,
        extractores: columnasProduccion,
        nombreBase: 'orbiloq_produccion',
      );

  static Future<void> exportarBodega(List<ItemKardex> todosLosItems) => _exportar(
        items: todosLosItems,
        etiquetas: kEtiquetasBodega,
        columnas: kColumnasBodega,
        extractores: columnasBodega,
        nombreBase: 'orbiloq_bodega',
      );

  static Future<void> _exportar({
    required List<ItemKardex> items,
    required List<String> etiquetas,
    required List<String?> columnas,
    required Map<String, ExtractorColumna> extractores,
    required String nombreBase,
  }) async {
    final libro = Excel.createExcel();
    final nombreHoja = libro.getDefaultSheet()!;
    final hoja = libro[nombreHoja];

    for (var c = 0; c < etiquetas.length; c++) {
      hoja.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).value = TextCellValue(etiquetas[c]);
    }

    for (var f = 0; f < items.length; f++) {
      final item = items[f];
      for (var c = 0; c < columnas.length; c++) {
        final columna = columnas[c];
        final valor = columna == null ? '' : (extractores[columna]?.call(item) ?? '');
        hoja.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: f + 1)).value = TextCellValue(valor);
      }
    }

    final bytes = libro.save();
    if (bytes == null) {
      throw Exception('No se pudo generar el archivo de Excel.');
    }

    final hoy = DateTime.now();
    final sufijo =
        '${hoy.year}${hoy.month.toString().padLeft(2, '0')}${hoy.day.toString().padLeft(2, '0')}';

    await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar histórico',
      fileName: '${nombreBase}_$sufijo.xlsx',
      bytes: Uint8List.fromList(bytes),
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
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
echo "Listo. flutter analyze"
