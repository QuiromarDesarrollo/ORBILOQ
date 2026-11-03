import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/shared/widgets/wms_scan_field.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'Teclado manual disponible en $platform aunque el lector oculte la opción',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = TextEditingController();
        final focus = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focus.dispose);
        final recibidos = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WmsScanField(
                controller: controller,
                focusNode: focus,
                mostrarIngresoManual: false,
                onSubmitted: recibidos.add,
              ),
            ),
          ),
        );
        await tester.tap(find.text('Ingresar código manualmente'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).keyboardType,
          TextInputType.text,
        );
        expect(tester.testTextInput.isVisible, isTrue);
        await tester.enterText(find.byType(TextField), '90005');
        expect(recibidos, isEmpty);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(recibidos, ['90005']);
        await tester.tap(find.text('Usar lector'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).keyboardType,
          TextInputType.none,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
  testWidgets('Limpia la captura y recupera el foco tras procesar el lector', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    final termina = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WmsScanField(
            controller: controller,
            focusNode: focus,
            autofocus: true,
            onSubmitted: (_) => termina.future,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'captura');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Procesando lectura…'), findsOneWidget);
    termina.complete();
    await tester.pump();
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(focus.hasFocus, true);
    expect(find.text('Leyendo código…'), findsNothing);
  });
  testWidgets(
    'Oculta la captura parcial y envía una sola lectura completa al recibir Enter',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final recibidos = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WmsScanField(
              controller: controller,
              autofocus: true,
              onSubmitted: (valor) {
                recibidos.add(valor);
                controller.clear();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'https://qr?123;COD');
      await tester.pump();
      expect(find.text('Leyendo código…'), findsOneWidget);
      expect(recibidos, isEmpty);
      final opacidad = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byType(TextField),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacidad.opacity, 0);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(recibidos, ['https://qr?123;COD']);
      expect(controller.text, isEmpty);
      await tester.enterText(find.byType(TextField), 'segunda');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(recibidos, ['https://qr?123;COD', 'segunda']);
    },
  );
  testWidgets(
    'Permite ingresar OP manual y muestra espera mientras termina la búsqueda',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final termina = Completer<void>();
      String? recibido;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WmsScanField(
              controller: controller,
              permiteManual: true,
              onSubmitted: (valor) async {
                recibido = valor;
                await termina.future;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ingresar OP o código'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '90001');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(recibido, '90001');
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
      termina.complete();
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, true);
    },
  );
}
