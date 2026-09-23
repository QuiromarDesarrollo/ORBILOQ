#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Columnas propias para la vista de Produccion (v18)
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_columnas_produccion_v18.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi
echo "Aplicando columnas de Produccion..."

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

// Columnas para el rol Producción (Taller).
const List<double> _kAnchosProduccion = [110, 240, 180, 90, 170, 110, 170, 130, 140];
const List<String> _kEtiquetasProduccion = [
  'OP / OBS.', 'PRODUCTO', 'CLIENTE / OC', 'CANTIDAD',
  'ENTREGADO A LOGÍSTICA', 'PENDIENTE', 'PRODUCTO NO CONFORME',
  'FECHA DE ENTREGA', 'FECHA ESPERADA',
];

// Columnas para el rol Logística (Bodega).
const List<double> _kAnchosBodega = [110, 250, 190, 90, 100, 90, 110, 170, 130];
const List<String> _kEtiquetasBodega = [
  'OP / OBS.', 'PRODUCTO', 'CLIENTE / OC', 'PEDIDAS',
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
    final etiquetas = esProduccion ? _kEtiquetasProduccion : _kEtiquetasBodega;
    final totalPaginas = total == 0 ? 1 : ((total - 1) ~/ kardexFilasPorPagina) + 1;
    final anchoTabla = anchos.fold<double>(0, (a, b) => a + b);

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
                        for (var i = 0; i < etiquetas.length; i++)
                          _Celda(
                            i,
                            anchos,
                            i == 0
                                ? const _EncabezadoOp()
                                : Text(
                                    etiquetas[i],
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
                    for (final item in filas) _KardexRow(item: item, anchos: anchos, esProduccion: esProduccion),
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
/// que ya usan los demás filtros.
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
        const Flexible(
          child: Text(
            'OP / OBS.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.darkTextSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.darkCardBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _celdaOp(),
          _celdaProducto(),
          _celdaClienteOc(),
          if (esProduccion) ..._celdasProduccion() else ..._celdasBodega(),
        ],
      ),
    );
  }

  Widget _celdaOp() {
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
              child: const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.darkTextMuted),
              ),
            ),
          ),
          Text('#${o.op}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.tealAccent)),
        ],
      ),
    );
  }

  Widget _celdaProducto() {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(o.descripcion,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.darkTextPrimary)),
                Text('Talla ${o.talla}', style: const TextStyle(fontSize: 11, color: AppColors.darkTextMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _celdaClienteOc() {
    final o = item.item;
    return _Celda(
      2,
      anchos,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(o.cliente, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.darkTextPrimary)),
          if (o.oc.isNotEmpty)
            Text('OC ${o.oc}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.darkTextMuted)),
        ],
      ),
    );
  }

  // ------------------------------------------------------- vista Producción

  List<Widget> _celdasProduccion() {
    final noConforme = item.pendienteReproceso;
    return [
      _Celda(3, anchos, Text('${item.cantidadPedida}', style: const TextStyle(fontSize: 13, color: AppColors.darkTextPrimary)),
          alignment: Alignment.center),
      _Celda(4, anchos, Text('${item.producido}', style: const TextStyle(fontSize: 13, color: AppColors.tealAccent)),
          alignment: Alignment.center),
      _Celda(
        5,
        anchos,
        Text('${item.pendienteProduccion}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: item.pendienteProduccion > 0 ? AppColors.chipRedDark : AppColors.darkTextMuted,
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
            color: noConforme > 0 ? Color(0xFFFBBF24) : AppColors.darkTextMuted,
          ),
        ),
        alignment: Alignment.center,
      ),
      _Celda(7, anchos, _chipFecha(item.fechaEntrega)),
      // "Fecha esperada": aún sin fuente de datos definida — placeholder
      // visual hasta que se conecte (el usuario indicará el origen luego).
      _Celda(8, anchos, _chipFecha(null)),
    ];
  }

  Widget _chipFecha(DateTime? fecha) {
    if (fecha == null) {
      return _chip('Sin fecha', AppColors.darkTextMuted, AppColors.chipNeutralBgDark, Icons.event_outlined);
    }
    return _chip(_fechaCorta(fecha), AppColors.darkTextSecondary, AppColors.chipNeutralBgDark, Icons.event_outlined);
  }

  // ------------------------------------------------------- vista Bodega

  List<Widget> _celdasBodega() {
    final completado = item.cantidadPedida > 0 && item.despachado >= item.cantidadPedida;
    final avance = item.cantidadPedida == 0 ? 0.0 : (item.recibido / item.cantidadPedida).clamp(0.0, 1.0);
    return [
      _Celda(3, anchos, Text('${item.cantidadPedida}', style: const TextStyle(fontSize: 13, color: AppColors.darkTextPrimary)),
          alignment: Alignment.center),
      _Celda(4, anchos, Text('${item.producido}', style: const TextStyle(fontSize: 13, color: AppColors.tealAccent)),
          alignment: Alignment.center),
      _Celda(5, anchos, Text('${item.recibido}', style: const TextStyle(fontSize: 13, color: Color(0xFF60A5FA))),
          alignment: Alignment.center),
      _Celda(6, anchos, Text('${item.despachado}', style: const TextStyle(fontSize: 13, color: Color(0xFFFBBF24))),
          alignment: Alignment.center),
      _Celda(7, anchos, _Avance(porcentaje: avance, completado: completado)),
      _Celda(8, anchos, _ChipEntrega(item: item, completado: completado)),
    ];
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
      return _chipEstatico('ENTREGADO', AppColors.chipGreenDark, AppColors.chipGreenBgDark, Icons.check_circle_outline);
    }
    final fecha = item.fechaEntregaLogistica;
    if (fecha == null) {
      return _chipEstatico('Sin fecha', AppColors.darkTextMuted, AppColors.chipNeutralBgDark, Icons.event_outlined);
    }
    final vencida = fecha.isBefore(DateTime.now());
    return _chipEstatico(
      _fechaCorta(fecha),
      vencida ? AppColors.chipRedDark : AppColors.darkTextSecondary,
      vencida ? AppColors.chipRedBgDark : AppColors.chipNeutralBgDark,
      Icons.event_outlined,
    );
  }

  Widget _chipEstatico(String texto, Color color, Color fondo, IconData icono) {
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

echo ""
echo "Listo. flutter analyze / flutter test"
