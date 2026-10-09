import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/features/produccion/presentation/entrega_produccion_dialog.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(1100, 850)]) {
    testWidgets('Entrega: cantidades y resumen fijo $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = InMemoryWmsRepository.seeded();
      addTearDown(repo.dispose);
      final item = (await repo.cargarSnapshot()).kardex.firstWhere(
        (k) => k.pendienteProduccion > 1,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [wmsRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: AppTheme.kardex(TemaModo.corporativo),
            home: const Scaffold(body: EntregaProduccionDialog()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Despachar lote a logística').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(
        find.text(size.width < 600 ? 'Manual' : 'Entrega manual'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, item.item.op);
      await tester.tap(
        size.width < 600 ? find.byTooltip('Buscar OP') : find.text('BUSCAR'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('AGREGAR SELECCIONADAS (1)'));
      await tester.tap(find.text('AGREGAR SELECCIONADAS (1)'));
      await tester.pumpAndSettle();
      expect(find.text('1 productos · 1 unidades'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Aumentar cantidad'));
      await tester.tap(find.byTooltip('Aumentar cantidad'));
      await tester.pumpAndSettle();
      expect(find.text('1 productos · 2 unidades'), findsOneWidget);
      expect(
        find.text('Despachar lote a logística').hitTestable(),
        findsOneWidget,
      );
      await tester.ensureVisible(
        (size.width < 600 ? find.byTooltip('Recontar') : find.text('Recontar')),
      );
      await tester.tap(
        (size.width < 600 ? find.byTooltip('Recontar') : find.text('Recontar')),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 productos · 1 unidades'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
