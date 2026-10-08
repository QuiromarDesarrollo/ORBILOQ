import 'models.dart';

/// Las OP pesan igual en la OC; una OP completa requiere todas sus lineas.
class AvanceDespacho {
  AvanceDespacho(Iterable<ItemKardex> items)
    : lineas = items.where((i) => !i.eliminada).toList();

  final List<ItemKardex> lineas;
  int get pedidas => lineas.fold(0, (n, i) => n + i.cantidadPedida);
  int get despachadas => lineas.fold(0, (n, i) => n + i.despachado);
  double get fraccionUnidades =>
      pedidas <= 0
          ? 0
          : lineas.fold<int>(
                0,
                (n, i) => n + i.despachado.clamp(0, i.cantidadPedida),
              ) /
              pedidas;
  Set<String> get ops => lineas.map((i) => i.item.op).toSet();
  int get opsCompletas =>
      ops
          .where(
            (op) => lineas
                .where((i) => i.item.op == op)
                .every(
                  (i) =>
                      i.cantidadPedida > 0 && i.despachado >= i.cantidadPedida,
                ),
          )
          .length;

  /// Promedio del avance de cada OP, incluyendo despachos parciales.
  /// Cada OP pesa igual, aunque tenga distinto numero de unidades o tallas.
  double get fraccionOps {
    final ordenes = ops;
    if (ordenes.isEmpty) return 0;
    return ordenes.fold<double>(
          0,
          (total, op) =>
              total +
              AvanceDespacho(
                lineas.where((i) => i.item.op == op),
              ).fraccionUnidades,
        ) /
        ordenes.length;
  }
}
