import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/domain/avance_despacho.dart';
import 'package:orbiloq_wms/domain/models.dart';

ItemKardex linea(String op, int pedidas, int despachadas) => ItemKardex(
  item: ItemOrden(
    id: '$op-$pedidas',
    op: op,
    cliente: 'Cliente',
    oc: 'OC1',
    codigo: 'C',
    descripcion: 'Prenda',
    talla: 'M',
    cantidadPedida: pedidas,
  ),
  producido: pedidas,
  recibido: pedidas,
  despachado: despachadas,
  ubicaciones: const {},
);

void main() {
  test('OC con una OP parcialmente despachada refleja 5 de 20 = 25%', () {
    final a = AvanceDespacho([linea('90003', 20, 5)]);
    expect(a.fraccionOps, 0.25);
    expect(a.opsCompletas, 0);
  });
  test('Promedia OP, sin ponderar por unidades ni contar tallas como OP', () {
    final a = AvanceDespacho([
      linea('1', 10, 10),
      linea('2', 20, 20),
      linea('2', 80, 30),
      linea('3', 200, 0),
    ]);
    expect(a.fraccionOps, 0.5);
    expect(a.opsCompletas, 1);
  });
  test('La OC cuenta OP completas sin ponderarlas por sus unidades', () {
    final a = AvanceDespacho([
      linea('1', 10, 10),
      linea('2', 100, 100),
      linea('3', 20, 0),
    ]);
    expect(a.opsCompletas, 2);
    expect(a.fraccionOps, closeTo(2 / 3, 0.0001));
  });
  test('Una OP con varias tallas requiere completar cada una', () {
    final a = AvanceDespacho([linea('1', 10, 10), linea('1', 30, 10)]);
    expect(a.ops.length, 1);
    expect(a.opsCompletas, 0);
    expect(a.fraccionUnidades, 0.5);
  });
  test('El exceso de una talla no completa otra ni supera 100 por ciento', () {
    final a = AvanceDespacho([linea('1', 10, 20), linea('1', 20, 10)]);
    expect(a.opsCompletas, 0);
    expect(a.fraccionUnidades, closeTo(2 / 3, 0.0001));
    expect(AvanceDespacho([linea('1', 10, 20)]).fraccionUnidades, 1);
    expect(AvanceDespacho([]).fraccionOps, 0);
    expect(AvanceDespacho([]).fraccionUnidades, 0);
  });
}
