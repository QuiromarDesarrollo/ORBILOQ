import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orbiloq_wms/features/conductor/conductor_repository.dart';
import 'package:orbiloq_wms/features/conductor/conductor_model.dart';
import 'package:orbiloq_wms/features/conductor/presentation/ficha_vehiculo_view.dart';
import 'package:orbiloq_wms/features/conductor/presentation/vista_evidencia_drive.dart';

class _Cliente extends Fake implements SupabaseClient {
  @override
  final _Funciones functions = _Funciones();
}

class _Funciones extends Fake implements FunctionsClient {
  final llamadas = <Map>[];
  bool falla = false;
  @override
  Future<FunctionResponse> invoke(
    String name, {
    Map<String, String>? headers,
    Object? body,
    Iterable<http.MultipartFile>? files,
    Map<String, dynamic>? queryParameters,
    HttpMethod method = HttpMethod.post,
    String? region,
    Future<void>? abortSignal,
  }) async {
    llamadas.add(body as Map);
    if (falla) throw Exception('Fallo simulado');
    return FunctionResponse(
      status: 200,
      data: {
        'mime': 'image/png',
        'base64': base64Encode(img.encodePng(img.Image(width: 12, height: 8))),
      },
    );
  }
}

void main() {
  testWidgets(
    'Las tres pestañas muestran previews autenticadas y permiten ampliar',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = _Cliente();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conductorRepositoryProvider.overrideWithValue(
              ConductorRepository(client),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FichaVehiculoView(
                  vehiculo: const VehiculoConductor(
                    id: 'car',
                    placa: 'TEST',
                    descripcion: 'Prueba',
                    km: 100,
                    datos: {
                      'foto_frontal':
                          'https://drive.google.com/file/d/CAR/view',
                      'foto_conductor':
                          'https://drive.google.com/file/d/DRIVER/view',
                      'conductor_documento': 'CC-123',
                      'doc_licencia':
                          'https://drive.google.com/file/d/LICENSE/view',
                      'doc_soat': 'https://drive.google.com/file/d/SOAT/view',
                    },
                  ),
                  conductor: 'Conductor prueba',
                  onEditar: () {},
                  onHistorial: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Conductor'));
      await tester.pumpAndSettle();
      expect(find.text('CC-123'), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(3));
      expect(
        client.functions.llamadas
            .where((p) => p['enlace'].contains('/CAR/'))
            .length,
        1,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Documentos'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNWidgets(3));
      final imagen = find.descendant(
        of: find.byType(VistaEvidenciaDrive).first,
        matching: find.byType(Image),
      );
      await tester.tap(imagen);
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar vista previa'));
      await tester.pumpAndSettle();
      expect(
        client.functions.llamadas.every(
          (p) => p['accion'] == 'preview' && p['vehiculo'] == 'car',
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Error de preview permite reintentar sin perder enlace', (
    tester,
  ) async {
    final client = _Cliente();
    client.functions.falla = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conductorRepositoryProvider.overrideWithValue(
            ConductorRepository(client),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: VistaEvidenciaDrive(
              vehiculo: 'car',
              enlace: 'https://drive.google.com/file/d/CAR/view',
              titulo: 'Foto',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Vista previa no disponible'), findsOneWidget);
    expect(find.text('Abrir original en Drive'), findsOneWidget);
    client.functions.falla = false;
    await tester.tap(find.text('Reintentar vista previa'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
