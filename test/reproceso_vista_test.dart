import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/features/reproceso/presentation/reproceso_dialog.dart';
import 'package:orbiloq_wms/shared/widgets/addable_person_dropdown.dart';

void main() {
  for (final width in [280.0, 320.0, 1100.0]) {
    testWidgets('Liberación responsive y validaciones $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = InMemoryWmsRepository.seeded();
      addTearDown(repo.dispose);
      await repo.agregarPersonalLogistica('Ana Prueba');
      final item = (await repo.cargarSnapshot()).kardex.firstWhere(
        (k) => k.producido >= 5,
      );
      await repo.registrarNoConforme(
        itemId: item.id,
        cantidad: 5,
        causalId: 'Talla incorrecta',
        operario: 'Administrador',
        recibidoDeProduccion: 'Producción',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            usarSupabaseProvider.overrideWithValue(false),
            wmsRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.kardex(TemaModo.corporativo),
            home: const Scaffold(body: ReprocesoDialog()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, item.item.codigo);
      await tester.pumpAndSettle();
      expect(find.textContaining('Causal: Talla incorrecta'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Reducir cantidad'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reducir cantidad'));
      await tester.pumpAndSettle();
      expect(find.textContaining('4 unidades por liberar'), findsOneWidget);
      await tester.tap(find.text('Liberar a logística'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Indica quién de Logística'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar aviso'));
      await tester.pumpAndSettle();
      final persona = tester.widget<AddablePersonDropdown>(
        find.byType(AddablePersonDropdown),
      );
      persona.onChanged('Ana Prueba');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Liberar a logística'));
      await tester.pumpAndSettle();
      expect(
        (await repo.cargarSnapshot()).kardexPorId(item.id)!.pendienteReproceso,
        1,
      );
      await tester.tap(find.byTooltip('Cerrar aviso'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      expect(find.text('4 uds'), findsOneWidget);
      expect(find.text('Ana Prueba'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
