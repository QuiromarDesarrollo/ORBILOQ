import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/features/no_conforme/presentation/no_conforme_dialog.dart';
import 'package:orbiloq_wms/features/no_conforme/presentation/historial_no_conforme.dart';
import 'package:orbiloq_wms/shared/widgets/wms_scan_field.dart';

void main() {
  for (final width in [320.0, 1100.0]) {
    testWidgets('PNC: tarjeta, resumen e historial $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = InMemoryWmsRepository.seeded();
      addTearDown(repo.dispose);
      final antes = await repo.cargarSnapshot();
      final cantidadReportes = (await repo.cargarDevoluciones()).length;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [wmsRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: AppTheme.kardex(TemaModo.corporativo),
            home: const Scaffold(body: NoConformeDialog()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester
          .widget<WmsScanField>(find.byType(WmsScanField))
          .onSubmitted(
            'https://etiqueta?19249;2025289515;TSHIRT;ENEL;ORD-001-ENE;1',
          );
      await tester.pumpAndSettle();
      expect(
        find.text('Reportar no conformidad').hitTestable(),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byTooltip('Aumentar cantidad'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect((await repo.cargarDevoluciones()).length, cantidadReportes);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistorialNoConforme(
              devoluciones: [
                Devolucion(
                  id: 'prueba',
                  item: antes.kardex.first.item,
                  cantidad: 5,
                  causal: 'Talla incorrecta',
                  operario: 'Administrador',
                  fecha: DateTime(2026, 10, 9),
                  recibidoDeProduccion: 'Juan Prueba',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('5 uds'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Juan Prueba'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
