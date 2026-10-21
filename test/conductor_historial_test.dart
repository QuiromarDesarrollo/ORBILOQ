import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/conductor/conductor_model.dart';
import 'package:orbiloq_wms/features/conductor/conductor_repository.dart';
import 'package:orbiloq_wms/features/conductor/historial_conductor.dart';
import 'package:orbiloq_wms/features/conductor/presentation/conductor_design.dart';
import 'package:orbiloq_wms/features/conductor/presentation/historial_conductor_view.dart';

const vehiculo = VehiculoConductor(
  id: 'v',
  placa: 'ABC123',
  descripcion: 'Furgón',
  km: 100,
);
final registros = [
  {
    'id': '1',
    'vehiculo_id': 'v',
    'actor_nombre': 'Ana',
    'tipo': 'Inicio de jornada',
    'km': 100,
    'creado': '2026-10-21T12:00:00Z',
    'datos': {
      'fecha': '2026-10-21',
      'notas': '=SUM(1,2)',
      'respuestas': {'Estado frenos': 'Buen estado'},
    },
  },
  {
    'id': '2',
    'vehiculo_id': 'v',
    'actor_nombre': 'Ana',
    'tipo': 'Fin de jornada',
    'km': 120,
    'creado': '2026-10-21T22:00:00Z',
    'datos': {
      'fecha': '2026-10-21',
      'siniestro': false,
      'enlace': 'https://drive.google.com/file/d/evidencia/view',
      'campo_futuro': {'detalle': 'Conservar'},
    },
  },
  {
    'id': '3',
    'vehiculo_id': 'v',
    'actor_nombre': 'Ana',
    'tipo': 'Tanqueo',
    'km': 110,
    'creado': '2026-10-21T16:00:00Z',
    'datos': {
      'fecha': '2026-10-21',
      'valor': '65000',
      'cantidad': '3',
      'foto_frontal': 'https://drive.google.com/file/d/foto/view',
    },
  },
  {
    'id': '4',
    'vehiculo_id': 'v',
    'actor_nombre': 'Ana',
    'tipo': 'Inicio de jornada',
    'km': 90,
    'creado': '2026-10-20T12:00:00Z',
    'datos': {'fecha': '2026-10-20'},
  },
];

class _Repo extends ConductorRepository {
  _Repo() : super(null);
  @override
  Future<List<Map<String, dynamic>>> historialPeriodo(
    String id,
    DateTime desde,
    DateTime hasta,
  ) async => registros;
}

void main() {
  test(
    'Consulta todas las páginas del período sin truncar en 100 registros',
    () async {
      final offsets = <int>[];
      final client = SupabaseClient(
        'https://igfuafcekcpugpmsoqbe.supabase.co',
        'test',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/rest/v1/rpc/conductor_historial');
          final body = jsonDecode(request.body) as Map;
          expect(body['p_desde'], '2026-10-01');
          expect(body['p_hasta'], '2026-10-21');
          final offset = body['p_offset'] as int;
          offsets.add(offset);
          return http.Response(
            jsonEncode(
              List.generate(
                offset == 400 ? 1 : 200,
                (i) => {
                  'id': '${offset + i}',
                  'tipo': 'Novedad',
                  'datos': {'fecha': '2026-10-21'},
                },
              ),
            ),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final registros = await ConductorRepository(
        client,
      ).historialPeriodo('v', DateTime(2026, 10), DateTime(2026, 10, 21));
      expect(registros.length, 401);
      expect(offsets, [0, 200, 400]);
      await client.dispose();
    },
  );
  test('Agrupa inicio/cierre y mantiene todas las actividades del día', () {
    final dias = agruparJornadasConductor(registros);
    expect(dias.length, 2);
    expect(dias.first.inspecciones, 2);
    expect(dias.first.registros.length, 3);
    expect(dias.last.inspecciones, 1);
    expect(
      fechaRegistroConductor({'creado': '2026-10-21T03:00:00Z'}),
      '2026-10-20',
    );
  });
  test(
    'Excel contiene solo días seleccionados, todas las columnas y enlaces literales',
    () {
      final dias = agruparJornadasConductor(registros);
      final libro = Excel.decodeBytes(
        generarExcelHistorialConductor(vehiculo, [dias.first]),
      );
      expect(libro.tables.keys, ['Jornadas', 'Checklist', 'Tanqueo']);
      expect(libro['Jornadas'].maxRows, 2);
      final sheet = libro['Checklist'];
      expect(sheet.maxRows, 3);
      expect(libro['Tanqueo'].maxRows, 2);
      expect(
        sheet.rows.first.map((c) => c?.value.toString()),
        isNot(contains('Valor · COP')),
      );
      Object? cell(String id, String columna) {
        final target = id == '3' ? libro['Tanqueo'] : sheet;
        final headers =
            target.rows.first.map((c) => c?.value.toString()).toList();
        final row = target.rows
            .skip(1)
            .firstWhere(
              (r) =>
                  r[headers.indexOf('ID del registro')]?.value.toString() == id,
            );
        return row[headers.indexOf(columna)]?.value;
      }

      expect(cell('1', 'Checklist · Estado frenos').toString(), 'Buen estado');
      expect(cell('1', 'Novedades / observaciones'), isA<TextCellValue>());
      expect(cell('1', 'Novedades / observaciones').toString(), '=SUM(1,2)');
      expect(
        cell('2', 'Evidencia / factura · enlace Drive').toString(),
        'https://drive.google.com/file/d/evidencia/view',
      );
      expect(cell('2', 'campo_futuro / detalle').toString(), 'Conservar');
      expect(cell('2', '¿Ocurrió un siniestro?').toString(), 'No');
      expect(
        cell('3', 'Foto frontal · enlace Drive').toString(),
        'https://drive.google.com/file/d/foto/view',
      );
      expect(cell('3', 'Valor · COP'), isA<IntCellValue>());
      expect(
        () => generarExcelHistorialConductor(vehiculo, []),
        throwsFormatException,
      );
    },
  );
  test(
    'Separa solicitudes y elimina columnas vacías por hoja, conservando cero y No',
    () {
      final entradas = <Map<String, dynamic>>[
        for (final tipo in [
          'Inicio de jornada',
          'Fin de jornada',
          'Registro diario',
          'Novedad',
        ])
          {
            'tipo': tipo,
            'id': tipo,
            'km': 0,
            'datos': {
              'fecha': '2026-10-21',
              'vacio': '   ',
              'nulo': null,
              'lista_vacia': [],
              'objeto_vacio': {'sin_dato': ''},
              if (tipo == 'Inicio de jornada')
                'respuestas': {'Estado frenos': 'Buen estado'},
              if (tipo == 'Fin de jornada') 'siniestro': false,
              if (tipo == 'Registro diario') ...{
                'foto_lateral_derecho':
                    'https://drive.google.com/file/d/derecho/view',
                'foto_lateral_izquierdo':
                    'https://drive.google.com/file/d/izquierdo/view',
              },
              if (tipo == 'Novedad') 'notas': 'Revisar espejo',
            },
          },
      ];
      final libro = Excel.decodeBytes(
        generarExcelHistorialConductor(
          vehiculo,
          agruparJornadasConductor(entradas),
        ),
      );
      expect(libro.tables.keys, [
        'Jornadas',
        'Checklist',
        'Registro diario',
        'Novedades',
      ]);
      expect(libro['Checklist'].maxRows, 3);
      for (final nombre in ['Checklist', 'Registro diario', 'Novedades']) {
        final sheet = libro[nombre];
        final headers =
            sheet.rows.first.map((c) => c?.value.toString()).toList();
        for (final vacio in [
          'vacio',
          'nulo',
          'lista_vacia',
          'objeto_vacio',
          'ID del usuario',
          'Conductor / usuario',
        ]) {
          expect(headers, isNot(contains(vacio)));
        }
        expect(headers, contains('Kilometraje'));
        expect(
          sheet.rows[1][headers.indexOf('Kilometraje')]!.value,
          IntCellValue(0),
        );
        expect(
          headers.contains('Foto lateral derecho · enlace Drive'),
          nombre == 'Registro diario',
        );
        expect(
          headers.contains('Foto lateral izquierdo · enlace Drive'),
          nombre == 'Registro diario',
        );
        expect(
          headers.contains('Novedades / observaciones'),
          nombre == 'Novedades',
        );
        expect(
          headers.contains('¿Ocurrió un siniestro?'),
          nombre == 'Checklist',
        );
      }
      final soloDiario = Excel.decodeBytes(
        generarExcelHistorialConductor(
          vehiculo,
          agruparJornadasConductor([entradas[2]]),
        ),
      );
      expect(soloDiario.tables.keys, ['Jornadas', 'Registro diario']);
    },
  );

  test(
    'Tipos adicionales tienen hojas válidas y no sobrescriben otras hojas',
    () {
      final tipos = [
        'Jornadas',
        'Sheet1',
        'Otros/archivos',
        'Otros:archivos',
        'Mantenimiento preventivo',
        'Un tipo de registro con nombre muy largo',
      ];
      final libro = Excel.decodeBytes(
        generarExcelHistorialConductor(
          vehiculo,
          agruparJornadasConductor([
            for (final tipo in tipos)
              {
                'tipo': tipo,
                'datos': {'fecha': '2026-10-21', 'notas': tipo},
              },
          ]),
        ),
      );
      expect(libro.tables.length, tipos.length + 1);
      for (final nombre in libro.tables.keys) {
        expect(nombre.length, lessThanOrEqualTo(31));
        expect(RegExp(r'[\[\]:*?/\\]').hasMatch(nombre), false);
      }
      expect(libro.tables.containsKey('Mantenimiento preventivo'), true);
    },
  );
  for (final admin in [false, true]) {
    testWidgets(
      'Historial ${admin ? 'administrador selecciona días' : 'conductor sin detalle'} a 320 px',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final font =
            FontLoader('ConductorSans')
              ..addFont(
                rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'),
              )
              ..addFont(
                rootBundle.load('assets/fonts/LiberationSans-Bold.ttf'),
              );
        await font.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
        final preview = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [conductorRepositoryProvider.overrideWithValue(_Repo())],
            child: MaterialApp(
              theme: ConductorDesign.theme(),
              home: RepaintBoundary(
                key: preview,
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: HistorialConductorView(
                        vehiculo: vehiculo,
                        administrador: admin,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('2 de 2 inspecciones completadas'), findsOneWidget);
        expect(find.text('1 de 2 inspecciones completadas'), findsOneWidget);
        if (admin) {
          expect(find.byType(CheckboxListTile), findsNWidgets(2));
          await tester.tap(find.text('Seleccionar todos'));
          await tester.pumpAndSettle();
          expect(find.text('Exportar Excel (2)'), findsOneWidget);
          await tester.tap(find.text('Quitar selección'));
          await tester.pumpAndSettle();
          expect(find.text('Exportar Excel (0)'), findsOneWidget);
        } else {
          expect(find.byType(ExpansionTile), findsNothing);
          expect(find.byType(CheckboxListTile), findsNothing);
          expect(find.textContaining('Exportar'), findsNothing);
          expect(find.textContaining('Ana'), findsNothing);
          expect(find.textContaining('drive.google.com'), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image = await (preview.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '.dart_tool/historial-${admin ? 'admin' : 'conductor'}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
