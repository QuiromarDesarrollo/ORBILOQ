import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/application/kardex_filters.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/domain/models.dart';

ItemKardex fila(String id, {int? entrega, int? recibido, int? despacho}) => ItemKardex(
  item: ItemOrden(id: id, op: id, cliente: id, oc: id, codigo: id,
    descripcion: 'Camisa', talla: 'M', cantidadPedida: 20),
  producido: 10, recibido: 8, despachado: 3, ubicaciones: const {},
  fechaEntrega: entrega == null ? null : DateTime(2026, 10, entrega, 23, 59),
  fechaRecepcion: recibido == null ? null : DateTime(2026, 10, recibido, 23, 59),
  fechaDespacho: despacho == null ? null : DateTime(2026, 10, despacho, 23, 59),
);

void main() {
  test('Cada vista usa su fecha, incluye todo el día y filtra tarjetas y opciones', () {
    final c = ProviderContainer(overrides: [
      usarSupabaseProvider.overrideWithValue(false),
      kardexProvider.overrideWithValue([
        fila('A', entrega: 6, recibido: 7, despacho: 8),
        fila('B', entrega: 5, recibido: 6, despacho: 7),
        fila('C', entrega: 4, recibido: 5, despacho: 6),
        fila('sin fecha'),
      ]),
    ]);
    addTearDown(c.dispose);
    final esperado = {Rol.produccion: 'A', Rol.logistica: 'B', Rol.despacho: 'C'};
    for (final rol in Rol.values) {
      c.read(rolProvider.notifier).cambiar(rol);
      expect(c.read(kardexFiltersProvider).hayFiltros, isFalse);
      c.read(kardexPaginaProvider.notifier).ir(2);
      c.read(kardexFiltersProvider.notifier).setFechas(DateTime(2026, 10, 6), DateTime(2026, 10, 6));
      expect(c.read(kardexPaginaProvider), 0);
      expect(c.read(kardexFiltradoProvider).single.id, esperado[rol]);
      expect(c.read(kardexResumenProvider).unidadesPedidas, 20);
      expect(c.read(opcionesFiltroProvider).de(ColKardex.cliente), [esperado[rol]]);
      c.read(kardexFiltersProvider.notifier).setBusqueda('sin coincidencias');
      expect(c.read(kardexResumenProvider).unidadesPedidas, 0);
      expect(c.read(kardexFiltersProvider).desde, DateTime(2026, 10, 6));
    }
    c.read(kardexFiltersProvider.notifier).limpiar();
    expect(c.read(kardexFiltradoProvider), hasLength(4));
  });
  test('El rango conserva filtros de columna y se puede retirar por separado', () {
    final f = KardexFilters(desde: DateTime(2026,10,5), hasta: DateTime(2026,10,6))
        .conColumna(ColKardex.cliente, {'A'});
    final extractores = <String,String Function(ItemKardex)>{ColKardex.cliente: (i) => i.item.cliente};
    expect(f.aplica(fila('A', entrega: 5), extractores), isTrue);
    expect(f.aplica(fila('A', entrega: 6), extractores), isTrue);
    expect(f.aplica(fila('A', entrega: 7), extractores), isFalse);
    expect(f.aplica(fila('B', entrega: 6), extractores), isFalse);
    expect(f.conFechas(null,null).aplica(fila('A'), extractores), isTrue);
    expect(f.conFechas(null,null).valoresDe(ColKardex.cliente), {'A'});
  });
}
