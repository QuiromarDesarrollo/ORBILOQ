import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orbiloq_wms/features/conductor/evidencia_conductor.dart';
import 'package:orbiloq_wms/features/conductor/presentation/evidencia_conductor_field.dart';

class _Picker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    PlatformFile(
      name: 'factura.pdf',
      size: 3,
      bytes: Uint8List.fromList([1, 2, 3]),
    ),
  ]);
}

class _SubidaPrueba extends SubidaEvidencia {
  _SubidaPrueba(super.archivo);
  int intentos = 0;
  bool fallar = false;
  @override
  Future<String> subir(
    SupabaseClient? client,
    String vehiculo,
    String campo,
    String tipo,
  ) async {
    intentos++;
    if (fallar) throw const FormatException('Sin conexión');
    return 'https://drive.google.com/file/d/$campo/view';
  }
}

void main() {
  test(
    'Lote conserva éxitos y reintenta solo pendientes; descartar excluye archivos',
    () async {
      final subidas = <_SubidaPrueba>[];
      EvidenciaSeleccionada nueva() => EvidenciaSeleccionada(
        crearSubida: (archivo) {
          final subida = _SubidaPrueba(archivo);
          subidas.add(subida);
          return subida;
        },
      );
      final archivo = ArchivoEvidencia(
        'a.pdf',
        'application/pdf',
        Uint8List.fromList([1]),
      );
      final campos = {
        'frontal': nueva(),
        'trasera': nueva(),
        'siniestro': nueva(),
      };
      for (final e in campos.values) {
        e.seleccionar(archivo);
      }
      campos['siniestro']!.descartar();
      subidas[1].fallar = true;
      final progreso = <String>[];
      Future<void> subir() => subirEvidenciasConductor(
        campos,
        client: null,
        vehiculo: 'demo',
        tipo: 'Registro diario',
        onProgress: (actual, total) => progreso.add('$actual/$total'),
      );
      await expectLater(subir(), throwsFormatException);
      expect(campos['frontal']!.enlace, isNotNull);
      expect(campos['trasera']!.pendiente, true);
      expect(progreso, ['1/2', '2/2']);
      subidas[1].fallar = false;
      await subir();
      // También reutiliza las URLs si falló el guardado posterior en base de datos.
      await subir();
      expect(subidas.map((s) => s.intentos).toList(), [1, 2, 0]);
      expect(progreso.last, '1/1');
      campos['frontal']!.seleccionar(archivo);
      expect(campos['frontal']!.enlace, isNull);
      await subir();
      expect(subidas.last.intentos, 1);
      for (final e in campos.values) {
        e.dispose();
      }
    },
  );
  testWidgets('Selección válida sin subida manual y sin entrada de enlaces', (
    tester,
  ) async {
    FilePicker.platform = _Picker();
    final controller = EvidenciaSeleccionada();
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(
              key: form,
              child: EvidenciaConductorField(
                controller: controller,
                etiqueta: 'Factura',
                obligatorio: true,
                onBusy: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Seleccionar archivo'));
    await tester.pumpAndSettle();
    expect(controller.pendiente, true);
    expect(form.currentState!.validate(), true);
    expect(find.text('Subir a Drive'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.textContaining('factura.pdf'), findsOneWidget);
    expect(controller.enlace, isNull);
    await tester.tap(find.text('Quitar archivo'));
    await tester.pumpAndSettle();
    expect(controller.pendiente, false);
    expect(form.currentState!.validate(), false);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  test('Comprime fotos y rechaza archivos incompatibles o excesivos', () async {
    final original = img.Image(width: 2000, height: 1000);
    final file = await prepararEvidencia(
      'foto.png',
      Uint8List.fromList(img.encodePng(original)),
    );
    final decoded = img.decodeJpg(file.bytes)!;
    expect(decoded.width, 1600);
    expect(decoded.height, 800);
    expect(file.mime, 'image/jpeg');
    expect(file.nombre, 'foto.jpg');
    await expectLater(
      prepararEvidencia('foto.jpg', Uint8List(0)),
      throwsFormatException,
    );
    await expectLater(
      prepararEvidencia('foto.jpg', Uint8List(maxEvidenciaBytes + 1)),
      throwsFormatException,
    );
    await expectLater(
      prepararEvidencia('archivo.html', Uint8List.fromList([1])),
      throwsFormatException,
    );
    await expectLater(
      prepararEvidencia('foto.jpg', Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });

  test(
    'Envía solo metadatos a Supabase y recupera respuesta perdida sin duplicar',
    () async {
      var sesiones = 0, consultas = 0, puts = 0;
      final archivo = ArchivoEvidencia(
        'factura.pdf',
        'application/pdf',
        Uint8List.fromList([1, 2, 3]),
      );
      final client = SupabaseClient(
        'https://igfuafcekcpugpmsoqbe.supabase.co',
        'test',
        httpClient: MockClient((request) async {
          sesiones++;
          final body = jsonDecode(request.body) as Map;
          expect(body['bytes'], 3);
          expect(body.containsKey('base64'), false);
          expect(body.containsKey('archivo'), false);
          return http.Response(
            jsonEncode({
              'uploadUrl':
                  'https://www.googleapis.com/upload/drive/v3/files?upload_id=test',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final upload = SubidaEvidencia(
        archivo,
        transporte: MockClient((r) async {
          expect(r.url.host, 'www.googleapis.com');
          expect(r.headers.containsKey('Authorization'), false);
          if (r.headers['Content-Range'] == 'bytes */3') {
            consultas++;
            return http.Response('{"id":"drive-file"}', 200);
          }
          puts++;
          expect(r.bodyBytes, [1, 2, 3]);
          throw http.ClientException('Respuesta perdida');
        }),
      );
      await expectLater(
        upload.subir(client, 'vehiculo', 'enlace', 'Tanqueo'),
        throwsA(isA<http.ClientException>()),
      );
      expect(consultas, 0); // No consulta Drive antes del primer envío.
      expect(
        await upload.subir(client, 'vehiculo', 'enlace', 'Tanqueo'),
        'https://drive.google.com/file/d/drive-file/view',
      );
      expect(sesiones, 1);
      expect(consultas, 1);
      expect(puts, 1);
      upload.dispose();
      await client.dispose();
    },
  );

  test(
    'Una sesión de carga nunca puede enviar archivos a otro dominio',
    () async {
      var enviado = false;
      final client = SupabaseClient(
        'https://igfuafcekcpugpmsoqbe.supabase.co',
        'test',
        httpClient: MockClient(
          (r) async => http.Response(
            '{"uploadUrl":"https://evil.example/upload"}',
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      final upload = SubidaEvidencia(
        ArchivoEvidencia('a.pdf', 'application/pdf', Uint8List.fromList([1])),
        transporte: MockClient((r) async {
          enviado = true;
          return http.Response('', 200);
        }),
      );
      await expectLater(
        upload.subir(client, 'vehiculo', 'enlace', 'Tanqueo'),
        throwsFormatException,
      );
      expect(enviado, false);
      upload.dispose();
      await client.dispose();
    },
  );

  testWidgets('Cámara y archivos caben en celular sin campo de enlace', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 750);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final ctrl = EvidenciaSeleccionada();
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: form,
                child: EvidenciaConductorField(
                  controller: ctrl,
                  etiqueta: 'Evidencia del mantenimiento',
                  onBusy: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Tomar foto'), findsOneWidget);
    expect(find.text('Seleccionar archivo'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(form.currentState!.validate(), true);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    ctrl.dispose();
  });
}
