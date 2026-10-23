import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart' as x;
import 'package:orbiloq_wms/features/conductor/kit_semanal.dart';
import 'package:orbiloq_wms/features/conductor/conductor_model.dart';
import 'package:orbiloq_wms/features/conductor/conductor_repository.dart';
import 'package:orbiloq_wms/features/conductor/historial_conductor.dart';
import 'package:orbiloq_wms/features/conductor/presentation/kit_semanal_page.dart';

Map<String, dynamic> datosKit(DateTime hoy) => {
  'inspector': 'Inspector',
  'fecha': fechaKit(hoy),
  'respuestas': {
    for (final p in catalogoKit) p['nombre']: {'estado': 'Buen estado'},
  },
};
void main() {
  test(
    'Sin migración mantiene el portal disponible; no oculta errores de permisos',
    () async {
      var codigo = 'PGRST202';
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        httpClient: MockClient((r) async {
          if (r.url.path.endsWith('/conductor_vehiculos')) {
            return http.Response(
              jsonEncode([
                {
                  'id': '00000000-0000-0000-0000-000000000001',
                  'placa': 'TEST',
                  'descripcion': 'Prueba',
                  'km': 10,
                  'datos': {},
                },
              ]),
              200,
              headers: {'content-type': 'application/json'},
              request: r,
            );
          }
          return http.Response(
            jsonEncode({
              'code': codigo,
              'message': 'RPC no disponible',
              'details': null,
              'hint': null,
            }),
            404,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }),
      );
      final repo = ConductorRepository(client);
      expect(
        (await repo.vehiculos()).single.datos['kit_semanal_disponible'],
        false,
      );
      codigo = '42501';
      await expectLater(repo.vehiculos(), throwsA(isA<PostgrestException>()));
      await client.dispose();
    },
  );
  final hoy = DateTime(2026, 10, 22);
  test('Catálogo 51 puntos, once categorías y coincidencia servidor', () {
    expect(catalogoKit.length, 51);
    expect(catalogoKit.map((p) => p['nombre']).toSet().length, 51);
    expect(catalogoKit.map((p) => p['categoria']).toSet().length, 11);
    final sql =
        File('sql/pruebas/128_conductor_kit_admin_epp.sql').readAsStringSync();
    for (final p in catalogoKit) {
      expect(sql, contains('"nombre": "${p['nombre']}"'));
    }
  });
  test('Valida completo, novedad con detalle y No aplica solo opcionales', () {
    final d = datosKit(hoy);
    expect(validarKit(d, hoy), isNull);
    d['respuestas']['Gato para elevar el vehículo'] = {'estado': 'No aplica'};
    expect(validarKit(d, hoy), isNotNull);
    d['respuestas']['Gato para elevar el vehículo'] = {'estado': 'Con novedad'};
    expect(validarKit(d, hoy), contains('Describe'));
    d['respuestas']['Gato para elevar el vehículo']['detalle'] = 'Falta';
    d['respuestas']['Agua potable'] = {'estado': 'No aplica'};
    expect(validarKit(d, hoy), isNull);
  });
  test('No permite omitir ambas alternativas de señalización', () {
    final d = datosKit(hoy);
    d['respuestas']['Lámparas amarillas intermitentes'] = {
      'estado': 'No aplica',
    };
    d['respuestas']['Triángulo reflectivo N.º 1'] = {'estado': 'No aplica'};
    expect(validarKit(d, hoy), contains('triángulos'));
  });
  test('Vencimientos y semanas con hora Colombia', () {
    final d = datosKit(hoy);
    d['respuestas']['Gasas estériles']['vencimiento'] = '2026-10-21';
    expect(validarKit(d, hoy), contains('vencido'));
    d['respuestas']['Gasas estériles'] = {
      'estado': 'Con novedad',
      'detalle': 'Reemplazar',
      'vencimiento': '2026-10-21',
    };
    expect(validarKit(d, hoy), isNull);
    expect(kitSemanaCompleta({'fecha': '2026-10-18'}, hoy), false);
    expect(kitSemanaCompleta({'fecha': '2026-10-19'}, hoy), true);
    expect(fechaKit(hoyColombia(DateTime.utc(2026, 10, 19, 3))), '2026-10-18');
    for (final dias in [0, 7, 15, 30]) {
      expect(
        avisosKit({
          'fecha': fechaKit(hoy),
          'vencimientos': {'Gasas': fechaKit(hoy.add(Duration(days: dias)))},
        }, hoy),
        hasLength(1),
      );
    }
    expect(
      avisosKit({
        'fecha': fechaKit(hoy),
        'vencimientos': {'Gasas': '2026-11-22'},
      }, hoy),
      isEmpty,
    );
  });
  test(
    'Guarda por vehículo, exporta hoja semanal y conserva kilometraje',
    () async {
      final repo = ConductorRepository(null);
      final v = (await repo.vehiculos()).single;
      await repo.guardarKit(v.id, datosKit(hoyColombia()));
      final nuevo = (await repo.vehiculos()).single;
      expect(nuevo.km, v.km);
      expect(
        kitSemanaCompleta(nuevo.datos['kit_semanal'], hoyColombia()),
        true,
      );
      final r = await repo.historial(v.id);
      final jornadas = agruparJornadasConductor(r);
      final libro = x.Excel.decodeBytes(
        generarExcelHistorialConductor(v, jornadas),
      );
      expect(libro.tables.keys, contains('Kit semanal'));
    },
  );
  for (final ancho in [390.0, 1440.0]) {
    testWidgets('Formulario responsive $ancho', (tester) async {
      tester.view.physicalSize = Size(ancho, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final font = FontLoader('ConductorSans')
        ..addFont(rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: RepaintBoundary(
              key: boundary,
              child: const KitSemanalPage(
                vehiculo: VehiculoConductor(
                  id: 'demo',
                  placa: 'TEST01',
                  descripcion: 'Vehículo de prueba',
                  km: 100,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Guardar revisión semanal'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Revisa:'), findsOneWidget);
      expect(find.byKey(const ValueKey('aviso-global')), findsOneWidget);
      await tester.tap(find.text('Cerrar aviso'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '.dart_tool/kit-${ancho.toInt()}.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
      await tester.drag(
        find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView && w.scrollDirection == Axis.vertical,
        ),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
