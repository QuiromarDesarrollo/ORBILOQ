import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/masiva/presentation/masiva_camera_scanner.dart';
import 'masiva_validacion_test.dart' show ValidacionFixture, openValidation;
import 'masiva_operacion_test.dart' show OperacionFixture, receipt;

Future<MasivaCameraScanner> openCamera(WidgetTester tester, String key) async {
  final button = find.byKey(ValueKey(key));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
  return tester.widget<MasivaCameraScanner>(find.byType(MasivaCameraScanner));
}

void main() {
  for (final size in [const Size(390, 844), const Size(768, 1024)]) {
    testWidgets('Cámara documento y validación conservan flujo $size', (
      tester,
    ) async {
      final repo = ValidacionFixture(validated: 0);
      await openValidation(tester, repo, size: size, search: false);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('masiva-sku-camera')))
            .onPressed,
        isNull,
      );
      final document = await openCamera(tester, 'masiva-documento-camera');
      expect(document.closeOnSuccess, isTrue);
      final documentResult = await document.onRead('DEMO-01');
      expect(documentResult.isError, isFalse);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cerrar cámara'));
      await tester.pumpAndSettle();
      final camera = await openCamera(tester, 'masiva-sku-camera');
      expect((await camera.onRead('NO-PERTENECE')).isError, isTrue);
      expect(repo.writes, isEmpty);
      expect((await camera.onRead('000123')).isError, isFalse);
      await tester.pumpAndSettle();
      expect(repo.validated, 1);
      expect((await camera.onRead('000123')).isError, isFalse);
      await tester.pumpAndSettle();
      expect(repo.validated, 2);
      expect((await camera.onRead('000123')).isError, isTrue);
      expect(repo.validated, 2);
      await tester.tap(find.text('Ingresar código manualmente'));
      await tester.pumpAndSettle();
      expect(find.byType(MasivaCameraScanner), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('masiva-sku')))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await openCamera(tester, 'masiva-documento-camera');
      await tester.tap(find.text('Ingresar código manualmente'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('masiva-persona')))
            .focusNode!
            .hasFocus,
        isTrue,
      );
    });
  }

  testWidgets('Cámara recepción respeta soporte y no confirma inventario', (
    tester,
  ) async {
    final repo = OperacionFixture();
    await receipt(tester, repo);
    var camera = await openCamera(tester, 'masiva-recepcion-camera');
    expect((await camera.onRead('000123')).isError, isTrue);
    expect(repo.writes, isEmpty);
    await tester.tap(find.text('Ingresar código manualmente'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (w) =>
            w is TextField && w.decoration?.labelText == 'Remisión o soporte',
      ),
      'REM-CAMERA',
    );
    camera = await openCamera(tester, 'masiva-recepcion-camera');
    expect((await camera.onRead('000123')).isError, isFalse);
    await tester.pumpAndSettle();
    expect(repo.writes, isEmpty);
    expect(repo.received, 1);
    await tester.tap(find.text('Ingresar código manualmente'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('receipt-card-inv1')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('receipt-quantity-inv1')),
          )
          .controller!
          .text,
      '1',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
