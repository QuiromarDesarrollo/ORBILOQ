import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orbiloq_wms/features/conductor/conductor_model.dart';
import 'package:orbiloq_wms/features/conductor/borrador_local.dart';
import 'package:orbiloq_wms/features/conductor/conductor_repository.dart';
import 'package:orbiloq_wms/features/conductor/evidencia_conductor.dart';
import 'package:orbiloq_wms/features/conductor/presentation/evidencia_conductor_field.dart';
import 'package:orbiloq_wms/features/conductor/presentation/registro_conductor.dart';

class _Cliente extends Fake implements SupabaseClient {
  @override
  final _Funciones functions = _Funciones();
}

class _Funciones extends Fake implements FunctionsClient {
  int sesiones = 0;
  @override
  Future<FunctionResponse> invoke(
    String functionName, {
    Map<String, String>? headers,
    Object? body,
    Iterable<http.MultipartFile>? files,
    Map<String, dynamic>? queryParameters,
    HttpMethod method = HttpMethod.post,
    String? region,
    Future<void>? abortSignal,
  }) async {
    sesiones++;
    final campo = (body as Map)['campo'];
    return FunctionResponse(
      status: 200,
      data: {
        'uploadUrl':
            'https://www.googleapis.com/upload/drive/v3/files?campo=$campo',
      },
    );
  }
}

class _Repository extends ConductorRepository {
  _Repository(super.client);
  int intentos = 0;
  Map<String, dynamic>? guardado;
  @override
  Future<void> guardar(
    String id,
    String tipo,
    int km,
    Map<String, dynamic> datos,
  ) async {
    intentos++;
    if (intentos == 1) throw StateError('Fallo temporal al guardar');
    guardado = datos;
  }
}

void main() {
  testWidgets(
    'Guardar valida, sube todas las fotos y reusa URLs si falla el registro',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var archivos = 0;
      final client = _Cliente();
      final repo = _Repository(client);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conductorRepositoryProvider.overrideWithValue(repo),
            transporteBorradorUsuarioProvider.overrideWithValue(null),
          ],
          child: MaterialApp(
            home: Builder(
              builder:
                  (context) => Scaffold(
                    body: TextButton(
                      onPressed:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => const RegistroConductorPage(
                                    vehiculo: VehiculoConductor(
                                      id: 'demo',
                                      placa: 'ABC123',
                                      descripcion: 'Prueba',
                                      km: 100,
                                    ),
                                    tipo: 'Registro diario',
                                  ),
                            ),
                          ),
                      child: const Text('Abrir'),
                    ),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      final campos =
          tester
              .widgetList<EvidenciaConductorField>(
                find.byType(EvidenciaConductorField),
              )
              .take(3)
              .toList();
      expect(campos.length, 3);
      final foto = ArchivoEvidencia(
        'foto.png',
        'image/png',
        Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 2))),
      );
      http.runWithClient(
        () {
          for (final campo in campos) {
            campo.controller.seleccionar(foto);
          }
        },
        () => MockClient((request) async {
          if (request.headers['Content-Range']!.startsWith('bytes */')) {
            return http.Response('', 308);
          }
          archivos++;
          return http.Response(jsonEncode({'id': 'foto-$archivos'}), 200);
        }),
      );
      await tester.pumpAndSettle();
      // Un formulario inválido no inicia cargas ni guarda datos.
      await tester.enterText(find.byType(TextFormField).first, '-1');
      await tester.tap(find.text('Guardar registro'));
      await tester.pumpAndSettle();
      expect(client.functions.sesiones, 0);
      expect(repo.intentos, 0);
      await tester.enterText(find.byType(TextFormField).first, '100');
      await tester.tap(find.text('Guardar registro'));
      await tester.pumpAndSettle();
      expect(archivos, 3);
      expect(repo.intentos, 1);
      expect(repo.guardado, isNull);
      await tester.tap(find.text('Cerrar aviso'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar registro'));
      await tester.pumpAndSettle();
      expect(client.functions.sesiones, 3);
      expect(archivos, 3);
      expect(repo.intentos, 2);
      expect(
        repo.guardado!['foto_frontal'],
        'https://drive.google.com/file/d/foto-1/view',
      );
      expect(
        repo.guardado!['foto_lateral_derecho'],
        'https://drive.google.com/file/d/foto-2/view',
      );
      expect(
        repo.guardado!['foto_lateral_izquierdo'],
        'https://drive.google.com/file/d/foto-3/view',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
