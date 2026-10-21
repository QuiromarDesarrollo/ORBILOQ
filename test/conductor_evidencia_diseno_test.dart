import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:orbiloq_wms/features/conductor/evidencia_conductor.dart';
import 'package:orbiloq_wms/features/conductor/presentation/conductor_design.dart';
import 'package:orbiloq_wms/features/conductor/presentation/evidencia_conductor_field.dart';
import 'package:orbiloq_wms/features/conductor/presentation/observaciones_evidencia_conductor.dart';

void main() {
  for (final ancho in [1440.0, 850.0, 520.0, 390.0, 320.0]) {
    testWidgets('Evidencias adaptables a $ancho: progreso, selección y descarte', (
      tester,
    ) async {
      tester.view.physicalSize = Size(ancho, ancho >= 850 ? 900 : 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final font =
          FontLoader('ConductorSans')
            ..addFont(
              rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'),
            )
            ..addFont(rootBundle.load('assets/fonts/LiberationSans-Bold.ttf'));
      await font.load();
      await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final fotos = {
        for (final lado in fotosVehiculoConductor.keys)
          lado: EvidenciaSeleccionada(),
      };
      final adicional = EvidenciaSeleccionada();
      final preview = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ConductorDesign.theme(),
          home: RepaintBoundary(
            key: preview,
            child: Scaffold(
              body: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1160),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        child: ObservacionesEvidenciaConductor(
                          fotos: fotos.values.toList(),
                          fotoBuilder:
                              (lado, titulo, ayuda) => EvidenciaConductorField(
                                key: ValueKey(lado),
                                controller: fotos[lado]!,
                                etiqueta: titulo,
                                soloFoto: true,
                                estilo: EstiloEvidencia.foto,
                                ayuda: ayuda,
                                onBusy: (_) {},
                              ),
                          observaciones: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Novedades / observaciones',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                minLines: 4,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  hintText:
                                      'Describe daños, faltantes o cualquier novedad del vehículo…',
                                ),
                              ),
                            ],
                          ),
                          adicional: EvidenciaConductorField(
                            controller: adicional,
                            etiqueta: 'Evidencia adicional',
                            estilo: EstiloEvidencia.adicional,
                            ayuda:
                                'Fotos o documentos que respalden el registro',
                            onBusy: (_) {},
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0 de 5 fotos'), findsOneWidget);
      expect(find.text('Tomar'), findsNWidgets(5));
      expect(find.text('Lateral derecho'), findsOneWidget);
      expect(find.text('Lateral izquierdo'), findsOneWidget);
      expect(find.text('Subir a Drive'), findsNothing);
      expect(tester.takeException(), isNull);
      final frontal = tester.getTopLeft(find.byKey(const ValueKey('frontal')));
      final lateral = tester.getTopLeft(
        find.byKey(const ValueKey('lateral_derecho')),
      );
      final trasera = tester.getTopLeft(find.byKey(const ValueKey('trasera')));
      if (ancho >= 1440) {
        expect(trasera.dy, frontal.dy);
      } else if (ancho >= 390) {
        expect(lateral.dy, frontal.dy);
        expect(trasera.dy, greaterThan(frontal.dy));
      } else {
        expect(lateral.dy, greaterThan(frontal.dy));
      }
      await tester.runAsync(() async {
        final picture =
            await (preview.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '.dart_tool/evidencia-diseno-${ancho.toInt()}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
      fotos['frontal']!.seleccionar(
        ArchivoEvidencia(
          'foto.png',
          'image/png',
          Uint8List.fromList(img.encodePng(img.Image(width: 10, height: 10))),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 de 5 fotos'), findsOneWidget);
      expect(find.text('Lista'), findsOneWidget);
      expect(find.text('Se subirá al guardar.'), findsOneWidget);
      await tester.tap(find.text('Quitar'));
      await tester.pumpAndSettle();
      expect(find.text('0 de 5 fotos'), findsOneWidget);
      expect(fotos['frontal']!.archivo, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      for (final f in fotos.values) {
        f.dispose();
      }
      adicional.dispose();
    });
  }
}
