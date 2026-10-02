import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/kardex_columnas.dart';
import 'package:orbiloq_wms/application/kardex_filters.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/features/kardex/presentation/kardex_filters_bar.dart';
import 'package:orbiloq_wms/shared/widgets/multi_select_filter.dart';

void main() {
  for (final columnas in [columnasProduccion, columnasBodega]) {
    test(
        'Opciones dependen de cliente, OP y búsqueda, sin limitar su propia selección: ${columnas.keys.last}',
        () async {
      final repo = InMemoryWmsRepository.seeded();
      addTearDown(repo.dispose);
      final items = (await repo.watch().first).kardex;
      final container = ProviderContainer(overrides: [
        kardexProvider.overrideWithValue(items),
        extractoresColumnaProvider.overrideWithValue(columnas),
      ]);
      addTearDown(container.dispose);
      final filtros = container.read(kardexFiltersProvider.notifier);
      filtros.setColumna(ColKardex.cliente, {'ENEL'});
      final enel = items.where((i) => i.item.cliente == 'ENEL').toList();
      var opciones = container.read(opcionesFiltroProvider);
      for (final c
          in columnas.entries.where((c) => c.key != ColKardex.cliente)) {
        expect(opciones.de(c.key),
            orderedEquals(enel.map(c.value).toSet().toList()..sort()));
      }
      expect(opciones.de(ColKardex.cliente), contains('MEDICALL'));
      filtros.setColumna(ColKardex.op, {'19249'});
      expect(container.read(opcionesFiltroProvider).de(ColKardex.cliente),
          ['ENEL']);
      filtros.setBusqueda('2025289515');
      opciones = container.read(opcionesFiltroProvider);
      expect(opciones.de(ColKardex.producto), [enel.first.item.descripcion]);
      expect(container.read(kardexFiltradoProvider), hasLength(1));
      filtros.setBusqueda('sin coincidencias');
      expect(container.read(opcionesFiltroProvider).de(ColKardex.op), isEmpty);
      filtros.limpiar();
      expect(container.read(opcionesFiltroProvider).de(ColKardex.op),
          containsAll(['19249', '18348', '18353']));
      expect(container.read(kardexFiltradoProvider), hasLength(items.length));
    });
  }

  testWidgets(
      'Una selección incompatible sigue visible y no rompe los desplegables',
      (tester) async {
    final repo = InMemoryWmsRepository.seeded();
    addTearDown(repo.dispose);
    final items = (await repo.watch().first).kardex;
    final container =
        ProviderContainer(overrides: [kardexProvider.overrideWithValue(items)]);
    addTearDown(container.dispose);
    container
        .read(kardexFiltersProvider.notifier)
        .setColumna(ColKardex.cliente, {'ENEL'});
    container.read(kardexFiltersProvider.notifier).setBusqueda('MEDICALL');
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: KardexFiltersBar()))));
    expect(find.text('ENEL (sin coincidencias)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Limpiar'));
    await tester.pumpAndSettle();
    expect(container.read(kardexFiltersProvider).hayFiltros, false);
  });

  testWidgets(
      'Aplicar todas las opciones disponibles conserva la selección explícita',
      (tester) async {
    Set<String>? resultado;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async {
                        resultado = await showMultiSelectFilter(context,
                            title: 'Productos',
                            options: ['Producto A'],
                            selected: <String>{},
                            labelOf: (String v) => v);
                      },
                      child: const Text('Abrir')),
                ))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Producto A'));
    await tester.tap(find.text('APLICAR FILTRO'));
    await tester.pumpAndSettle();
    expect(resultado, {'Producto A'});
  });
}
