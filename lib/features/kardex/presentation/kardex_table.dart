import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import 'observacion_dialog.dart';

const List<double> _kAnchos = [110, 250, 190, 90, 100, 90, 110, 170, 130];
const List<String> _kEtiquetas = [
  'OP / OBSERVACIÓN', 'PRODUCTO', 'CLIENTE / OC', 'PEDIDAS',
  'PRODUCCIÓN', 'BODEGA', 'DESPACHADAS', 'AVANCE', 'ENTREGA',
];

const _kPaletaProducto = [
  Color(0xFF0F172A), Color(0xFF0F766E), Color(0xFF7C3AED), Color(0xFFB45309),
  Color(0xFF1D4ED8), Color(0xFF991B1B), Color(0xFF15803D), Color(0xFF334155),
];

Color _colorProducto(String codigo) => _kPaletaProducto[codigo.hashCode.abs() % _kPaletaProducto.length];

const _mesesEs = [
  '', 'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
];
String _fechaCorta(DateTime d) => '${d.day} ${_mesesEs[d.month]}';

/// Tabla del kardex, paginada. Cada página construye solo sus propias filas,
/// así que sigue escalando bien con miles de registros en total.
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
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
                    color: AppColors.slate50,
                    child: Row(
                      children: [
                        for (var i = 0; i < _kEtiquetas.length; i++)
                          _Celda(
                            i,
                            Text(
                              _kEtiquetas[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.slate600,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.cardBorder),
                  if (filas.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text('Sin resultados para los filtros aplicados.',
                            style: TextStyle(color: AppColors.slate400)),
                      ),
                    )
                  else
                    for (final item in filas) _KardexRow(item: item),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.cardBorder),
          _BarraPaginacion(pagina: pagina, totalPaginas: totalPaginas, total: total, filas: filas.length),
        ],
      ),
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
            style: const TextStyle(fontSize: 12, color: AppColors.slate600),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: pagina > 0 ? () => notifier.ir(pagina - 1) : null,
                icon: const Icon(Icons.chevron_left, size: 18),
                label: const Text('Anterior'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.slate600),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: pagina + 1 < totalPaginas ? () => notifier.ir(pagina + 1) : null,
                icon: const Icon(Icons.chevron_right, size: 18),
                label: const Text('Siguiente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tealPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.slate200,
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
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
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
                    child: Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.slate400),
                  ),
                ),
                Text('#${o.op}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      Text('Talla ${o.talla}', style: const TextStyle(fontSize: 11, color: AppColors.slate400)),
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
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                if (o.oc.isNotEmpty)
                  Text('OC ${o.oc}', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.slate400)),
              ],
            ),
          ),
          _Celda(3, Text('${item.cantidadPedida}', style: const TextStyle(fontSize: 13)),
              alignment: Alignment.center),
          _Celda(4, Text('${item.producido}', style: const TextStyle(fontSize: 13, color: AppColors.tealPrimary)),
              alignment: Alignment.center),
          _Celda(5, Text('${item.recibido}', style: const TextStyle(fontSize: 13, color: AppColors.blueChip)),
              alignment: Alignment.center),
          _Celda(6, Text('${item.despachado}', style: const TextStyle(fontSize: 13, color: AppColors.amberChip)),
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
    final color = completado ? AppColors.actionGreen : AppColors.tealPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: completado ? 1 : porcentaje,
            minHeight: 6,
            backgroundColor: AppColors.slate200,
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
      return _chip('ENTREGADO', AppColors.actionGreen, AppColors.greenChipBg, Icons.check_circle_outline);
    }
    final fecha = item.fechaEntregaLogistica;
    if (fecha == null) {
      return _chip('Sin fecha', AppColors.slate400, AppColors.slate50, Icons.event_outlined);
    }
    final vencida = fecha.isBefore(DateTime.now());
    return _chip(
      _fechaCorta(fecha),
      vencida ? AppColors.alertRed : AppColors.slate600,
      vencida ? AppColors.redChipBg : AppColors.slate50,
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
