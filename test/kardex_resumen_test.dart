import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/kardex_filters.dart';
import 'package:orbiloq_wms/application/kardex_columnas.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/domain/models.dart';

ItemKardex fila({
  String id = '1',
  String cliente = 'Cliente A',
  int recibido = 40,
  int despachado = 15,
  bool eliminada = false,
}) => ItemKardex(
  item: ItemOrden(
    id: id,
    op: id,
    cliente: cliente,
    oc: 'OC-$id',
    codigo: 'C-$id',
    descripcion: 'Camisa',
    talla: 'M',
    cantidadPedida: 100,
  ),
  producido: 60,
  recibido: recibido,
  despachado: despachado,
  ubicaciones: const {},
  eliminada: eliminada,
);

void main() {
  test('Bodega descuenta despachos sin alterar el acumulado recibido', () {
    for (final cantidad in [0, 2, 5]) {
      final item = fila(recibido: 5, despachado: cantidad);
      expect(columnasBodega[ColKardex.bodega]!(item), '${5 - cantidad}');
      expect(columnasDespacho[ColKardex.despachadas]!(item), '$cantidad');
      expect(item.recibido, 5);
    }
  });
  test('La tarjeta cuenta bodega pendiente, no lo pendiente de la orden', () {
    final item = fila();
    final resumen = KardexResumen.desde([item]);
    expect(resumen.pendientePorDespachar, 25);
    expect(resumen.unidadesPedidas, 100);
    expect(resumen.recibidoEnBodega, 40);
    expect(resumen.pendientePorEntregar, 40);
    // El saldo de la orden sigue controlando cumplimiento y límites de despacho.
    expect(item.pendienteDespacho, 85);
  });

  test('Sin recepción o con toda la bodega despachada el resumen es cero', () {
    expect(
      KardexResumen.desde([
        fila(recibido: 0, despachado: 0),
      ]).pendientePorDespachar,
      0,
    );
    expect(
      KardexResumen.desde([
        fila(recibido: 40, despachado: 40),
      ]).pendientePorDespachar,
      0,
    );
    expect(KardexResumen.desde([]).pendientePorDespachar, 0);
  });

  test(
    'Una corrección que deje saldo negativo no resta stock de otra fila',
    () {
      final resumen = KardexResumen.desde([
        fila(),
        fila(id: '2', recibido: 10, despachado: 20),
      ]);
      expect(resumen.pendientePorDespachar, 25);
    },
  );

  test('El resumen respeta filtros y excluye líneas eliminadas', () {
    final container = ProviderContainer(
      overrides: [
        kardexProvider.overrideWithValue([
          fila(),
          fila(id: '2', cliente: 'Cliente B', recibido: 30, despachado: 10),
          fila(id: '3', recibido: 80, despachado: 0, eliminada: true),
        ]),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(kardexResumenProvider).pendientePorDespachar, 45);
    container.read(kardexFiltersProvider.notifier).setColumna(
      ColKardex.cliente,
      {'Cliente A'},
    );
    expect(container.read(kardexResumenProvider).pendientePorDespachar, 25);
    container.read(kardexFiltersProvider.notifier).setBusqueda('inexistente');
    expect(container.read(kardexResumenProvider).pendientePorDespachar, 0);
  });
}
