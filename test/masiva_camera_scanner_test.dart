import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/masiva/presentation/masiva_camera_scanner.dart';
import 'package:orbiloq_wms/shared/widgets/feedback_banner.dart';

void main() {
  setUpAll(() async {
    final fonts = Platform.environment['MASIVA_FONT_DIR'];
    if (fonts == null) return;
    for (final entry
        in {
          'Roboto': 'roboto-regular.ttf',
          'MaterialIcons': 'MaterialIcons-Regular.otf',
        }.entries) {
      final loader = FontLoader(entry.key);
      loader.addFont(
        File(
          '$fonts/${entry.value}',
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
      await loader.load();
    }
  });
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1024, 600),
  ]) {
    testWidgets('Pausa, bloquea duplicados y rearma en $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late ValueChanged<List<String>> detect;
      final pending = Completer<FeedbackMessage>();
      final reads = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: MasivaCameraScanner(
            title: 'Escanear prenda',
            subtitle: 'Recepción de compra · OP 123',
            instruction:
                'Enfoca el código de una prenda para agregar una unidad.',
            onRead: (code) {
              reads.add(code);
              return reads.length == 1
                  ? pending.future
                  : Future.value(const FeedbackMessage.error('Código ajeno'));
            },
            previewBuilder: (_, callback) {
              detect = callback;
              return const SizedBox();
            },
          ),
        ),
      );
      detect([' A ']);
      detect(['A']);
      await tester.pump();
      expect(reads, ['A']);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Cerrar cámara',
              ),
            )
            .onPressed,
        isNull,
      );
      pending.complete(const FeedbackMessage.ok('Unidad agregada'));
      await tester.pumpAndSettle();
      detect(['B']);
      await tester.pump();
      expect(reads, ['A']);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      detect(['B']);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      detect(['B']);
      await tester.pump();
      expect(reads, ['A'], reason: 'Volver a la app no debe rearmar una lectura pausada.');
      expect(find.text('Unidad agregada'), findsOneWidget);
      if (Platform.environment['MASIVA_CAPTURE'] == '1' && size.width == 390) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary).first,
          );
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '.dart_tool/masiva-camera-phone.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.ensureVisible(find.text('Escanear siguiente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Escanear siguiente'));
      await tester.pumpAndSettle();
      detect(['B']);
      await tester.pumpAndSettle();
      expect(reads, ['A', 'B']);
      expect(find.text('Código ajeno'), findsOneWidget);
      detect(['B']);
      await tester.pump();
      expect(reads.length, 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Manual cierra; documento espera éxito antes de cerrar', (
    tester,
  ) async {
    late ValueChanged<List<String>> detect;
    var manual = false;
    var closeOnSuccess = false;
    String? returned;
    var fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    returned = await showDialog<String>(
                      context: context,
                      builder:
                          (_) => MasivaCameraScanner(
                            title: 'Documento',
                            subtitle: 'Recepción',
                            instruction: 'Enfoca un documento',
                            closeOnSuccess: closeOnSuccess,
                            onManual: () => manual = true,
                            onRead:
                                (_) async =>
                                    fail
                                        ? const FeedbackMessage.error(
                                          'Sin resultados',
                                        )
                                        : const FeedbackMessage.ok(
                                          'Documento encontrado',
                                        ),
                            previewBuilder: (_, callback) {
                              detect = callback;
                              return const SizedBox();
                            },
                          ),
                    );
                  },
                  child: const Text('Abrir'),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ingresar código manualmente'));
    await tester.tap(find.text('Ingresar código manualmente'));
    await tester.pumpAndSettle();
    expect(manual, isTrue);
    expect(find.byType(MasivaCameraScanner), findsNothing);
    closeOnSuccess = true;
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    detect(['DOC']);
    await tester.pumpAndSettle();
    expect(find.byType(MasivaCameraScanner), findsOneWidget);
    fail = false;
    await tester.ensureVisible(find.text('Escanear siguiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escanear siguiente'));
    await tester.pumpAndSettle();
    detect(['DOC']);
    await tester.pumpAndSettle();
    expect(returned, 'DOC');
    expect(find.byType(MasivaCameraScanner), findsNothing);
  });
}
