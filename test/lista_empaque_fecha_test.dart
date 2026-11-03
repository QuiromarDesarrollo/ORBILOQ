import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/despacho/presentation/lista_empaque_dialog.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('Calendario de salida acepta una fecha futura en $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      DateTime? elegida;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  elegida = await elegirFechaSalida(context, null);
                },
                child: const Text('Elegir fecha'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Elegir fecha'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(DatePickerDialog), findsOneWidget);

      final hoy = DateTime.now().toUtc().subtract(const Duration(hours: 5));
      final futuro = DateTime(hoy.year, hoy.month + 1, 15);
      await tester.tap(find.byIcon(Icons.chevron_right).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('15').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('OK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(elegida, DateTime(futuro.year, futuro.month, futuro.day));
      expect(tester.takeException(), isNull);
    });
  }
}
