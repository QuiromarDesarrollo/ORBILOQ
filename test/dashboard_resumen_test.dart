import 'package:orbiloq_wms/features/admin/presentation/dashboard_volumen_barras.dart';
import 'package:orbiloq_wms/application/dashboard_despachos_mensuales.dart';
import 'package:orbiloq_wms/features/admin/presentation/dashboard_despachos_mensuales.dart';
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
import 'dashboard_atencion_test.dart' show demoAtencion, lineaAtencion;

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
              puntualidadMensualProvider.overrideWith(
                (ref, filtro) async => [
                  {
                    'mes': '2026-09-01',
                    'total': filtro.cliente == null ? 10 : 3,
                    'a_tiempo': 1,
                    'con_retraso': 1,
                    'sin_fecha': filtro.cliente == null ? 8 : 1,
                  },
                ],
              ),
              despachosMensualesProvider.overrideWith(
                (ref, filtro) async => [
                  {
                    'mes': '2026-09-01',
                    'total': filtro.cliente == null ? 7 : 2,
                    'sin_contratiempo': 1,
                    'con_contratiempo': 1,
                  },
                  {
                    'mes': '2026-10-01',
                    'total': 3,
                    'sin_contratiempo': 2,
                    'con_contratiempo': 0,
                  },
                ],
              ),
              reportesAdminProvider.overrideWithValue(
                ReportesDashboardPrueba(),
              ),
              dashboardSnapshotProvider.overrideWith(
                (ref) => Future.value(
                  WmsSnapshot(
                    kardex: [
                      ...demoAtencion,
                      lineaAtencion('90006', fecha: DateTime(2026, 9, 29)),
                    ],
                    lotes: [],
                  ),
                ),
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
        expect(
          tester
              .widget<DashboardDespachosMensuales>(
                find.byWidgetPredicate(
                  (w) =>
                      w is DashboardDespachosMensuales &&
                      w.key != const ValueKey('puntualidad-mensual'),
                ),
              )
              .datos
              .first['total'],
          7,
        );
        expect(find.textContaining('Avance acumulado actual'), findsNothing);
        expect(find.textContaining('OP con despacho superior'), findsNothing);
        expect(find.text('Recibido en Bodega'), findsOneWidget);
        expect(find.text('Unidades pedidas'), findsOneWidget);
        expect(find.text('Pendiente por entregar a Logística'), findsOneWidget);
        expect(
          find.textContaining('Acumulado · Todos los clientes'),
          findsOneWidget,
        );
        expect(find.text('50 % de lo recibido'), findsOneWidget);
        expect(find.text('Despachadas'), findsOneWidget);
        expect(find.text('Alertas'), findsNothing);
        expect(find.text('Conformidad de recepción'), findsNothing);
        expect(find.text('Tasa de sobrantes'), findsNothing);
        expect(tester.takeException(), isNull);
        final verAlertas = find.text('Ver las 3 alertas');
        await tester.ensureVisible(verAlertas);
        await tester.pumpAndSettle();
        await tester.tap(verAlertas);
        await tester.pumpAndSettle();
        expect(find.text('Atención requerida · 3 alertas'), findsOneWidget);
        expect(find.textContaining('90005').last, findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Cerrar alertas'));
        await tester.pumpAndSettle();
        for (final titulo in [
          'Volumen por semana',
          'Despachos por cliente',
          'Puntualidad de despachos por mes',
          'Despachos por mes',
          'Facturación de despachos semanales',
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
        expect(
          tester
              .widget<DashboardDespachosMensuales>(
                find.byWidgetPredicate(
                  (w) =>
                      w is DashboardDespachosMensuales &&
                      w.key != const ValueKey('puntualidad-mensual'),
                ),
              )
              .datos
              .first['total'],
          2,
        );
        expect(find.textContaining('Acumulado · Cliente 12'), findsOneWidget);
        expect(find.text('— de lo recibido'), findsOneWidget);
        expect(find.text('50 % de lo recibido'), findsNothing);
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
        final puntualidad = tester.widget<DashboardDespachosMensuales>(
          find.byKey(const ValueKey('puntualidad-mensual')),
        );
        expect(puntualidad.datos.single['total'], 3);
        expect(puntualidad.claves, ['total', 'a_tiempo', 'con_retraso']);
        expect(
          find.textContaining('1 sin fecha esperada completa'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
