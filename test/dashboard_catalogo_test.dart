import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/features/kardex/presentation/kardex_page.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
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
      final repo = InMemoryWmsRepository.seeded();
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wmsRepositoryProvider.overrideWithValue(repo),
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
              (ref) async => DatosCiclos(
                [
                  OrdenCiclo(
                    'OP-1',
                    'Cliente',
                    150,
                    DateTime.utc(2026, 9, 1),
                    [
                      for (var i = 0; i < 7; i++)
                        DateTime.utc(2026, 9, 3 + i * 3),
                    ],
                    {for (final p in ProcesoCiclo.values) p.name: p.name},
                  ),
                ],
                [
                  for (final p in ProcesoCiclo.values)
                    ParametroCiclo(
                      p.name,
                      p,
                      DateTime.utc(2026, 1, 1),
                      p.diasIniciales,
                      100,
                      500,
                    ),
                ],
                DateTime.utc(2026, 10, 9),
                '0',
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.kardex(TemaModo.corporativo),
            home: const KardexPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DrawerButton));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Dashboard'));
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('4'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Ver tiempos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver tiempos'));
      await tester.pumpAndSettle();
      expect(find.byType(CiclosPage), findsOneWidget);
      for (final vista in ['Capacidad', 'Detalle por OP', 'Resumen']) {
        await tester.ensureVisible(find.text(vista).first);
        await tester.tap(find.text(vista).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      tester.view.physicalSize = Size(ancho < 700 ? 1280 : 320, 850);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(BackButton)));
      await tester.pump(const Duration(seconds: 1));
      await tester.pageBack();
      await mouse.removePointer();
      await tester.pumpAndSettle();
      expect(find.byType(CiclosPage), findsNothing);
      expect(find.byType(DashboardCatalogoPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(KardexPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
