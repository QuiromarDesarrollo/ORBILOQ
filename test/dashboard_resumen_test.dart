import 'package:orbiloq_wms/features/admin/presentation/dashboard_volumen_barras.dart';
import 'package:orbiloq_wms/application/dashboard_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/features/admin/presentation/dashboard_ejecutivo_page.dart';
import 'package:orbiloq_wms/features/admin/presentation/dashboard_resumen.dart';
import 'dashboard_ejecutivo_test.dart' show ReportesDashboardPrueba;
import 'dashboard_atencion_test.dart' show demoAtencion;

void main() {
  for (final modo in TemaModo.values) {
    for (final size in [
      const Size(1366, 768),
      const Size(768, 1024),
      const Size(320, 800),
    ]) {
      testWidgets('Cuadrícula, ayuda y filtros $modo $size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              usarSupabaseProvider.overrideWithValue(false),
              reportesAdminProvider.overrideWithValue(
                ReportesDashboardPrueba(),
              ),
              dashboardSnapshotProvider.overrideWith(
                (ref) =>
                    Future.value(WmsSnapshot(kardex: demoAtencion, lotes: [])),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.kardex(modo),
              home: const DashboardEjecutivoPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PanelResumen), findsNWidgets(6));
        expect(tester.takeException(), isNull);
        for (final titulo in [
          'Volumen por semana',
          'Despachos por cliente',
          'Salud de clientes',
          'Órdenes de producción hoy',
          'Calidad en recepción',
          'Atención requerida',
        ]) {
          final boton = find.byTooltip('Cómo se calcula: $titulo');
          await tester.ensureVisible(boton);
          await tester.pumpAndSettle();
          await tester.tap(boton);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          await tester.tap(find.text('Entendido'));
          await tester.pumpAndSettle();
        }
        final selector = find.byType(DropdownButtonFormField<String>);
        await tester.ensureVisible(selector);
        await tester.pumpAndSettle();
        await tester.tap(selector);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cliente 12').last);
        await tester.pumpAndSettle();
        final grafica = tester.widget<DashboardVolumenBarras>(
          find.byType(DashboardVolumenBarras),
        );
        expect(grafica.datos.fold(0, (n, s) => n + s.unidades[2]), 1690);
        await tester.ensureVisible(find.text('Día'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Día'));
        await tester.pumpAndSettle();
        final diaria = tester.widget<DashboardVolumenBarras>(
          find.byType(DashboardVolumenBarras),
        );
        expect(diaria.porSemana, isFalse);
        expect(diaria.datos.fold(0, (n, s) => n + s.unidades[2]), 1690);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byTooltip('Ampliar Salud de clientes'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Ampliar Salud de clientes'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.text('Buscar cliente'), findsOneWidget);
        await tester.tap(find.byTooltip('Cerrar detalle'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
