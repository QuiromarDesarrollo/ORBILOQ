import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/data/seguimiento_entregas.dart';
import 'package:orbiloq_wms/features/despacho/presentation/placa_quiromar_field.dart';

void main() {
  testWidgets('Reintenta carga de placas sin perder la placa histórica', (
    tester,
  ) async {
    var intentos = 0;
    String? seleccion;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placasSeguimientoProvider.overrideWith((ref) async {
            if (++intentos == 1) throw StateError('Sin conexión');
            return ['JOU797'];
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PlacaQuiromarField(
              value: 'ANT123',
              onChanged: (v) => seleccion = v,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('ANT123'), findsOneWidget);
    await tester.tap(find.text('Reintentar placas'));
    await tester.pumpAndSettle();
    expect(find.text('ANT123 · anterior'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JOU797').last);
    await tester.pumpAndSettle();
    expect(seleccion, 'JOU797');
    expect(tester.takeException(), isNull);
  });
  testWidgets('Catálogo vacío se explica sin permitir inventar placas', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [placasSeguimientoProvider.overrideWith((ref) async => [])],
        child: MaterialApp(
          home: Scaffold(
            body: PlacaQuiromarField(value: '', onChanged: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No hay vehículos registrados en Transporte.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .onChanged,
      isNull,
    );
  });
}
