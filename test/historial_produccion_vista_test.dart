import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/features/produccion/presentation/historial_produccion.dart';

void main() {
  for (final width in [280.0, 390.0, 1000.0]) {
    testWidgets('Historial: detalle y filtro $width', (tester) async {
      tester.view.physicalSize = Size(width, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = InMemoryWmsRepository.seeded();
      addTearDown(repo.dispose);
      final k = (await repo.cargarSnapshot()).kardex.firstWhere((k) => k.pendienteProduccion >= 2);
      await repo.crearLote(items: [ItemCantidad(itemId: k.id, cantidad: 2)], operario: 'Operario de prueba');
      await tester.pumpWidget(ProviderScope(overrides: [wmsRepositoryProvider.overrideWithValue(repo)], child: MaterialApp(theme: AppTheme.kardex(TemaModo.corporativo), home: const Scaffold(body: HistorialProduccion()))));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), k.item.op);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Por recibir').last);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('OP ${k.item.op}').first);
      await tester.pumpAndSettle();
      expect(find.text('Operario de prueba'), findsOneWidget);
      expect(find.text('Entrega de 2 unidades'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'inexistente');
      await tester.pumpAndSettle();
      expect(find.text('No hay entregas con estos filtros.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
