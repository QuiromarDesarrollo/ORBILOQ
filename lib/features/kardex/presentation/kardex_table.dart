import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/fecha.dart';
import '../../../domain/models.dart';
import '../../../application/kardex_filters.dart';
import '../../../shared/widgets/status_chip.dart';
import 'observacion_dialog.dart';

const double _kAltoFila = 48;

/// Anchos por columna (mismo orden que las celdas de cabecera y de fila).
const List<double> _kAnchos = [
  64, 80, 120, 120, 120, 210, 80, 100, 120, 110, 110, 110, 140, 230, 180,
];

/// Tabla virtualizada: solo construye las filas visibles, por lo que escala a miles de registros.
class KardexTable extends StatefulWidget {
  const KardexTable({super.key, required this.rows, required this.rol});

  final List<ItemKardex> rows;
  final Rol rol;

  @override
  State<KardexTable> createState() => _KardexTableState();
}

class _KardexTableState extends State<KardexTable> {
  final ScrollController _horizontal = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _kAnchos.fold<double>(0, (a, b) => a + b);
    final esProduccion = widget.rol == Rol.produccion;
    final etiquetas = <String>[
      'OBS.', 'OP', 'CLIENTE', 'N° OC', 'CÓDIGO', 'DESCRIPCIÓN / TALLA', 'PEDIDAS',
      'PRODUCCIÓN', 'RECIBIDO BODEGA', 'PEND. BODEGA', 'DESPACHADAS', 'DISP. ESTANTE',
      esProduccion ? 'FECHA ENTREGA' : 'FECHA RECEPCIÓN', 'UBICACIÓN(ES)', 'ESTADO',
    ];

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        controller: _horizontal,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _horizontal,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: total,
            child: Column(
              children: [
                Container(
                  height: 44,
                  color: AppColors.primaryNavy,
                  child: Row(
                    children: [
                      for (var i = 0; i < etiquetas.length; i++)
                        _Celda(
                          i,
                          Text(
                            etiquetas[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: widget.rows.isEmpty
                      ? const Center(child: Text('Sin resultados para los filtros aplicados.', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemExtent: _kAltoFila,
                          itemCount: widget.rows.length,
                          itemBuilder: (_, i) => _KardexRow(item: widget.rows[i], rol: widget.rol, zebra: i.isOdd),
                        ),
                ),
              ],
            ),
          ),
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(alignment: alignment, child: child),
      ),
    );
  }
}

class _KardexRow extends StatelessWidget {
  const _KardexRow({required this.item, required this.rol, required this.zebra});

  final ItemKardex item;
  final Rol rol;
  final bool zebra;

  Text _t(String s, {FontWeight? w, Color? c, double? size}) => Text(
        s,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: w, color: c, fontSize: size),
      );

  @override
  Widget build(BuildContext context) {
    final o = item.item;
    final fecha = fechaSegunRol(item, rol);
    return Container(
      decoration: BoxDecoration(
        color: zebra ? const Color(0xFFF7F9FC) : Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          _Celda(
            0,
            IconButton(
              icon: const Icon(Icons.comment, color: AppColors.accentCyan, size: 20),
              tooltip: 'Ver observación OP',
              onPressed: () => showObservacionDialog(context, item),
            ),
          ),
          _Celda(1, _t(o.op, w: FontWeight.bold)),
          _Celda(2, _t(o.cliente)),
          _Celda(3, _t(o.oc, w: FontWeight.w600, c: AppColors.secondaryNavy)),
          _Celda(4, _t(o.codigo)),
          _Celda(5, _t('${o.descripcion} (${o.talla})')),
          _Celda(6, _t('${item.cantidadPedida}'), alignment: Alignment.center),
          _Celda(7, _t('${item.producido}', w: FontWeight.bold, c: AppColors.actionGreen), alignment: Alignment.center),
          _Celda(
            8,
            _t('${item.recibido}', w: FontWeight.bold, c: item.excedente > 0 ? AppColors.actionOrange : AppColors.accentCyan),
            alignment: Alignment.center,
          ),
          _Celda(
            9,
            _t('${item.pendienteRecibir}', w: FontWeight.bold, c: item.pendienteRecibir > 0 ? AppColors.alertRed : Colors.grey),
            alignment: Alignment.center,
          ),
          _Celda(10, _t('${item.despachado}', w: FontWeight.bold, c: AppColors.actionOrange), alignment: Alignment.center),
          _Celda(
            11,
            _t('${item.stockDisponible}', w: FontWeight.bold, c: item.stockDisponible > 0 ? AppColors.primaryNavy : Colors.grey),
            alignment: Alignment.center,
          ),
          _Celda(12, _t(formatFechaHora(fecha), size: 12)),
          _Celda(
            13,
            Tooltip(message: item.ubicacionesFormateadas, child: _t(item.ubicacionesFormateadas, w: FontWeight.w500)),
          ),
          _Celda(14, StatusChip(label: item.estadoEtiqueta, color: AppColors.primaryNavy)),
        ],
      ),
    );
  }
}
