import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/shared/widgets/feedback_banner.dart';
import 'package:orbiloq_wms/shared/widgets/wms_camera_scanner.dart';

void main() {
  testWidgets(
      'Mantiene cámara abierta, evita duplicados y permite repetir explícitamente',
      (tester) async {
    late ValueChanged<List<String>> detectar;
    final leidos = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: WmsCameraScanner(
      onRead: (v) {
        leidos.add(v);
        return FeedbackMessage.ok('Tarjeta $v actualizada');
      },
      previewBuilder: (_, callback) {
        detectar = callback;
        return const SizedBox();
      },
    )));
    detectar(['OP1']);
    await tester.pump();
    detectar(['OP1']);
    await tester.pump();
    detectar(['OP2']);
    await tester.pump();
    detectar(['OP1']);
    await tester.pump();
    expect(leidos, ['OP1', 'OP2']);
    expect(find.text('Tarjeta OP2 actualizada'), findsOneWidget);
    expect(find.text('2 lectura(s) aceptada(s)'), findsOneWidget);
    expect(find.byType(WmsCameraScanner), findsOneWidget);
    await tester.tap(find.text('Releer mismo código'));
    await tester.pump();
    detectar(['OP2']);
    await tester.pump();
    expect(leidos, ['OP1', 'OP2', 'OP2']);
    await tester.tap(find.text('Pausar'));
    await tester.pump();
    detectar(['OP3']);
    expect(leidos.length, 3);
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    detectar(['OP3']);
    await tester.pump();
    expect(leidos.last, 'OP3');
  });

  testWidgets(
      'No procesa dos lecturas simultáneas ni presenta errores como éxito',
      (tester) async {
    late ValueChanged<List<String>> detectar;
    final espera = Completer<FeedbackMessage>();
    var llamadas = 0;
    await tester.pumpWidget(MaterialApp(
        home: WmsCameraScanner(
      onRead: (_) {
        llamadas++;
        return espera.future;
      },
      previewBuilder: (_, callback) {
        detectar = callback;
        return const SizedBox();
      },
    )));
    detectar(['a', 'b']);
    await tester.pump();
    expect(llamadas, 0);
    detectar(['a']);
    detectar(['b']);
    await tester.pump();
    expect(llamadas, 1);
    expect(find.text('Actualizando tarjeta…'), findsOneWidget);
    espera.complete(const FeedbackMessage.error('Límite alcanzado'));
    await tester.pump();
    expect(find.text('Límite alcanzado'), findsOneWidget);
    expect(find.text('0 lectura(s) aceptada(s)'), findsOneWidget);
  });

  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(768, 1024)
  ]) {
    testWidgets('Cámara adaptable a $size y cierre con tarjetas conservadas',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late ValueChanged<List<String>> detectar;
      var lecturas = 0;
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => WmsCameraScanner(
                                  onRead: (_) {
                                    lecturas++;
                                    return const FeedbackMessage.ok(
                                        'OP 90001 · CAMISETA (M) · 2 Uds en la tarjeta.');
                                  },
                                  previewBuilder: (_, callback) {
                                    detectar = callback;
                                    return const SizedBox();
                                  },
                                )),
                        child: const Text('Abrir')),
                  ))));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      detectar(['etiqueta']);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Ver tarjetas'));
      await tester.pumpAndSettle();
      expect(find.byType(WmsCameraScanner), findsNothing);
      expect(lecturas, 1);
    });
  }
}
