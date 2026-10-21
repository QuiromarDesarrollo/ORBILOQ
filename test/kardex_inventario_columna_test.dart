import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/application/kardex_columnas.dart';
import 'package:orbiloq_wms/application/kardex_filters.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/features/kardex/presentation/kardex_table.dart';

void main() {
 testWidgets('Inventario junto a Bodega muestra saldos separados y menú compacto', (tester) async {
  tester.view.physicalSize = const Size(1920, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repo = InMemoryWmsRepository.seeded();
  addTearDown(repo.dispose);
  final original = (await repo.watch().first).kardex.first;
  final fila = ItemKardex(item: original.item, producido: 10, recibido: 10, despachado: 0, stockInventario: 4, ubicaciones: const {'A':6});
  expect(columnasBodega[ColKardex.bodega]!(fila), '6');
  expect(columnasBodega[ColKardex.inventario]!(fila), '4');
  await tester.pumpWidget(ProviderScope(overrides: [
    usarSupabaseProvider.overrideWithValue(false),
    wmsRepositoryProvider.overrideWithValue(repo),
    kardexProvider.overrideWithValue([fila]),
  ], child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: KardexTable())))));
  final container = ProviderScope.containerOf(tester.element(find.byType(KardexTable)));
  container.read(rolProvider.notifier).cambiar(Rol.logistica);
  await tester.pumpAndSettle();
  expect(find.text('INVENTARIO'), findsOneWidget);
  expect(tester.getCenter(find.text('INVENTARIO')).dx, greaterThan(tester.getCenter(find.text('BODEGA')).dx));
  expect(tester.getCenter(find.text('INVENTARIO')).dx, lessThan(tester.getCenter(find.text('PRODUCTO NO CONFORME')).dx));
  expect(find.text('4'), findsOneWidget);
  expect(find.text('6'), findsOneWidget);
  expect(find.byIcon(Icons.delete_outline), findsNothing);
  await tester.tap(find.byTooltip('Acciones de la fila'));
  await tester.pumpAndSettle();
  expect(find.text('Editar'), findsOneWidget);
  expect(find.text('Eliminar'), findsOneWidget);
  expect(tester.takeException(), isNull);
 });
}
