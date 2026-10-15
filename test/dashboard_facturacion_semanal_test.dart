import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/admin/presentation/dashboard_facturacion_semanal.dart';

void main() {
  testWidgets('dona calcula porcentaje y permite cambiar de semana', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: DonaFacturacionSemanal(
              datos: [
                {'semana': '2026-10-05', 'total': 10, 'completas': 6},
                {'semana': '2026-10-12', 'total': 4, 'completas': 1},
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('25.0 %'), findsOneWidget);
    expect(
      find.text('Pendientes de completar: 3', findRichText: true),
      findsNothing,
    );
    expect(find.textContaining('Pendientes de completar: 3'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('05/10/2026 – 09/10/2026').last);
    await tester.pumpAndSettle();
    expect(find.text('60.0 %'), findsOneWidget);
    expect(find.text('Total de despachos: 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('semana vacía no indica cumplimiento y cabe en móvil', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            height: 240,
            child: DonaFacturacionSemanal(
              datos: [
                {'semana': '2026-10-12', 'total': 0, 'completas': 0},
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('—'), findsOneWidget);
    expect(find.text('Sin despachos en esta semana.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
