import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/dashboard_acceso.dart';
import 'package:orbiloq_wms/application/ciclos_providers.dart';
import 'package:orbiloq_wms/domain/sesion.dart';
import 'package:orbiloq_wms/domain/ciclos.dart';
import 'package:orbiloq_wms/features/ciclos/presentation/dashboard_catalogo.dart';
import 'package:orbiloq_wms/features/ciclos/presentation/ciclos_page.dart';

void main() {
  for (final ancho in [280.0, 390.0, 844.0, 1440.0]) {
    testWidgets('Indicadores responsive y acceso a tiempos $ancho', (
      tester,
    ) async {
      tester.view.physicalSize = Size(ancho, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardAccesoProvider.overrideWithValue((
              'test',
              RolCuenta.admin,
            )),
            indicadoresResumenProvider.overrideWith(
              (ref) async => {
                'op_activas': 4,
                'op_atrasadas': 2,
                'op_no_conforme': 3,
                'actualizado_en': '2026-10-09T16:00:00Z',
              },
            ),
            ciclosProvider.overrideWith(
              (ref) async =>
                  DatosCiclos([], [], DateTime.utc(2026, 10, 9), '0'),
            ),
          ],
          child: const MaterialApp(home: DashboardCatalogoPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('4'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Sin OP completas evaluables'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Ver tiempos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver tiempos'));
      await tester.pumpAndSettle();
      expect(find.byType(CiclosPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
