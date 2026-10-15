import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/domain/ciclos.dart';
import 'package:orbiloq_wms/domain/ciclos_indicadores.dart';
import 'package:orbiloq_wms/features/ciclos/presentation/ciclos_resumen_compacto.dart';
import 'package:orbiloq_wms/features/ciclos/presentation/grafica_intercambiable.dart';

void main() {
  for (final ancho in [390.0, 1366.0]) {
    testWidgets('Ruta permite alternar estilos y conserva controles a $ancho', (
      tester,
    ) async {
      tester.view.physicalSize = Size(ancho, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final datos = DatosCiclos(
        [
          for (final dias in [2, 6])
            OrdenCiclo('OP$dias', 'Cliente', 10, DateTime.utc(2026, 9, 1), [
              DateTime.utc(2026, 9, 1 + dias),
              ...List<DateTime?>.filled(6, null),
            ], {}),
        ],
        [],
        DateTime.utc(2026, 10, 14),
        '0',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CiclosResumenCompacto(
                indicadores: IndicadoresCiclos(datos),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Análisis de tiempos'));
      await tester.tap(find.text('Análisis de tiempos'));
      await tester.pumpAndSettle();
      final menu = find.byTooltip(
        'Tipo de gráfica: Ruta de una OP por proceso',
      );
      expect(menu, findsOneWidget);
      for (final estilo in [
        'Barras horizontales',
        'Columnas',
        'Líneas',
        'Área',
        'Donas',
      ]) {
        await tester.ensureVisible(menu);
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.text(estilo).last);
        await tester.pumpAndSettle();
        final graficas =
            tester
                .widgetList<GraficaIntercambiable>(
                  find.byType(GraficaIntercambiable),
                )
                .where((g) => !g.selectorVisible)
                .toList();
        expect(graficas, hasLength(2));
        expect(graficas[0].tipoSeleccionado, graficas[1].tipoSeleccionado);
        expect(graficas[0].datos.unidad, 'días hábiles');
        expect(graficas[1].datos.unidad, '%');
        final p80 = graficas[0].datos.valores.first;
        await tester.ensureVisible(find.text('P50').first);
        await tester.tap(find.text('P50').first);
        await tester.pumpAndSettle();
        final duracion = tester
            .widgetList<GraficaIntercambiable>(
              find.byType(GraficaIntercambiable),
            )
            .firstWhere((g) => !g.selectorVisible);
        expect(duracion.datos.valores.first, lessThan(p80!));
        await tester.tap(find.text('P80').first);
        await tester.tap(find.text('Actual').first);
        await tester.pumpAndSettle();
        expect(find.text('Histórico'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.ensureVisible(menu);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vista inicial'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Suma de procesos:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
