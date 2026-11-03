import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/conductor/presentation/transporte_scaffold.dart';
import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';
import 'package:orbiloq_wms/features/conductor/presentation/conductor_design.dart';

void main() {
  for (final width in [390.0, 800.0, 1440.0]) {
    testWidgets('Aviso hereda estilo corporativo fuera del Scaffold a $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      final font = FontLoader('ConductorSans')
        ..addFont(rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'));
      await font.load();
      final logoFont = FontLoader('Roboto')
        ..addFont(rootBundle.load('assets/fonts/LiberationSans-Bold.ttf'));
      await logoFont.load();
      const message = 'Preparando la subida de evidencias…';
      await tester.pumpWidget(
        MaterialApp(
          theme: ConductorDesign.theme(),
          home: RepaintBoundary(
            key: boundary,
            child: const WmsActionLoadingOverlay(
              label: message,
              child: Scaffold(
                body: Center(child: Text('Formulario de transporte')),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final rich = tester.widget<RichText>(
        find.descendant(
          of: find.text(message),
          matching: find.byType(RichText),
        ),
      );
      expect(rich.text.style!.fontSize, 16);
      expect(rich.text.style!.decoration, TextDecoration.none);
      expect(rich.text.style!.color, isNot(const Color(0xFFFF0000)));
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          'output/verificaciones/aviso-transporte-${width.toInt()}.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'Guardado usa loader grande, bloquea acciones y conserva el formulario',
    (tester) async {
      String? mensaje;
      late StateSetter actualizar;
      var clicks = 0;
      final controller = TextEditingController(text: 'Trabajo ingresado');
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                actualizar = setState;
                return TransporteScaffold(
                  loadingLabel: mensaje,
                  body: Column(
                    children: [
                      TextField(controller: controller),
                      TextButton(
                        onPressed: () => clicks++,
                        child: const Text('Otra acción'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      actualizar(() => mensaje = 'Subiendo evidencias 1 de 3…');
      await tester.pump();
      final loader = tester.widget<WmsLoader>(find.byType(WmsLoader));
      expect(loader.mode, OrbiloqLoaderMode.orbit);
      expect(loader.width, greaterThanOrEqualTo(200));
      expect(find.text('Subiendo evidencias 1 de 3…'), findsOneWidget);
      await tester.tap(find.text('Otra acción'), warnIfMissed: false);
      expect(clicks, 0);
      actualizar(() => mensaje = 'Enviando mantenimiento para validación…');
      await tester.pump();
      expect(find.text(mensaje!), findsOneWidget);
      actualizar(() => mensaje = null);
      await tester.pumpAndSettle();
      expect(controller.text, 'Trabajo ingresado');
      expect(find.byType(WmsLoader), findsNothing);
      await tester.tap(find.text('Otra acción'));
      expect(clicks, 1);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets('Loader grande se adapta a móvil horizontal y texto ampliado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(568, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(568, 320),
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: const TransporteScaffold(
              loadingLabel: 'Guardando revisión semanal del kit de carretera…',
              body: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(WmsLoadingPanel), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
