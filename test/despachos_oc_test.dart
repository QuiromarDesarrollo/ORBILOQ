import 'package:orbiloq_wms/data/seguimiento_entregas.dart';
import 'package:orbiloq_wms/data/destinatarios_empaque.dart';
import 'package:orbiloq_wms/domain/sesion.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/data/despachos_oc_repository.dart';
import 'package:orbiloq_wms/data/empaques_repository.dart';
import 'package:orbiloq_wms/data/excel_ordenes_parser.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/features/despacho/presentation/despacho_dialog.dart';
import 'package:orbiloq_wms/application/kardex_columnas.dart';
import 'package:orbiloq_wms/application/kardex_filters.dart';

class _Despachos extends DespachosOcRepository {
  final correcciones = <String>[];
  @override
  Future<void> corregir(
    String id,
    String version,
    String solicitud,
    String motivo,
    String cliente,
    String oc,
    List<Map<String, dynamic>> lineas,
    List<Map<String, dynamic>> empaques, {
    String? destinatarioId,
    String? destinatarioVersion,
  }) async {
    correcciones.add(id);
    planes.add(lineas);
    empaquesEnviados.add(empaques);
  }

  int? leNumero;
  String fase = 'despachado';
  final solicitudes = <String>[];
  final planes = <List<Map<String, dynamic>>>[];
  final empaquesEnviados = <List<Map<String, dynamic>>>[];
  bool fallarPrimera = false;
  @override
  Future<void> confirmar(
    String solicitud,
    String cliente,
    String oc,
    List<Map<String, dynamic>> lineas, {
    List<Map<String, dynamic>> empaques = const [],
    String? destinatarioId,
    String? destinatarioVersion,
  }) async {
    solicitudes.add(solicitud);
    planes.add(lineas);
    empaquesEnviados.add(empaques);
    if (fallarPrimera && solicitudes.length == 1) {
      throw Exception('Respuesta perdida');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> historial() async => [
    {
      'registro': 'h1',
      'fase': fase,
      if (leNumero != null) 'le_numero': leNumero,
      if (leNumero != null) 'despacho_oc_id': 'despacho1',
      'cliente': 'Cliente',
      'oc': 'OC1',
      'item_id': 'i',
      'op': '1',
      'producto': 'Camisa',
      'talla': 'M',
      'fecha': '2026-10-01T12:00:00Z',
      'cantidad': 4,
      'persona': 'Ana',
      'ubicacion': 'A',
      'nota': 'Entrega confirmada',
    },
  ];
}

ItemKardex prenda({
  int recibido = 10,
  int despachado = 0,
  Map<String, int> stock = const {'B': 6, 'A': 4},
  Map<String, int> reservas = const {},
}) => ItemKardex(
  item: const ItemOrden(
    id: 'i',
    op: '1',
    cliente: 'Cliente',
    oc: 'OC1',
    codigo: 'C',
    descripcion: 'Camisa',
    talla: 'M',
    cantidadPedida: 10,
  ),
  producido: 10,
  recibido: recibido,
  despachado: despachado,
  ubicaciones: stock,
  reservas: reservas,
);

void main() {
  for (final rol in [
    RolCuenta.despacho,
    RolCuenta.seguimiento,
    RolCuenta.admin,
  ]) {
    testWidgets('Pestañas de despacho según rol ${rol.name}', (tester) async {
      var consultasEntregas = 0;
      final repo = InMemoryWmsRepository.seeded();
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            usarSupabaseProvider.overrideWithValue(true),
            usuarioSesionProvider.overrideWith(
              (ref) async => UsuarioSesion(
                numeroUsuario: '1',
                nombre: 'Ana',
                rolCuenta: rol,
              ),
            ),
            wmsRepositoryProvider.overrideWithValue(repo),
            despachosOcProvider.overrideWithValue(_Despachos()),
            destinatariosEmpaqueProvider.overrideWith((ref) async => []),
            entregasProvider.overrideWith((ref) async {
              consultasEntregas++;
              return [];
            }),
          ],
          child: const MaterialApp(home: Scaffold(body: DespachoDialog())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Tab, 'Despacho'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Historial'), findsOneWidget);
      expect(
        find.widgetWithText(Tab, 'Seguimiento'),
        rol == RolCuenta.seguimiento ? findsOneWidget : findsNothing,
      );
      await tester.tap(find.widgetWithText(Tab, 'Despacho'));
      await tester.pumpAndSettle();
      expect(find.text('¿A quién va el empaque?'), findsOneWidget);
      await tester.tap(find.widgetWithText(Tab, 'Historial'));
      await tester.pumpAndSettle();
      if (rol == RolCuenta.despacho) {
        expect(consultasEntregas, 0);
        expect(find.text('Entregadas'), findsNothing);
      } else {
        expect(find.text('Entregadas'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Conserva destinatario al avanzar: habilita rótulos y revisión', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = InMemoryWmsRepository.seeded();
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          usarSupabaseProvider.overrideWithValue(true),
          wmsRepositoryProvider.overrideWithValue(repo),
          despachosOcProvider.overrideWithValue(_Despachos()),
          wmsSnapshotProvider.overrideWith(
            (ref) => Stream.value(WmsSnapshot(kardex: [prenda()], lotes: [])),
          ),
          empaquesProvider.overrideWith(
            (ref) async => [
              {
                'id': 'caja1',
                'nombre': 'Caja prueba',
                'categoria': 'CAJA',
                'largo_cm': 30,
                'ancho_cm': 20,
                'alto_cm': 10,
                'version': 'v1',
              },
            ],
          ),
          usuarioSesionProvider.overrideWith(
            (ref) async => const UsuarioSesion(
              numeroUsuario: '1',
              nombre: 'Ana',
              rolCuenta: RolCuenta.despacho,
            ),
          ),
          destinatariosEmpaqueProvider.overrideWith(
            (ref) async => [
              {
                'id': 'destino-1',
                'version': 'v1',
                'datos': {
                  'nombre': 'DESTINATARIO NORTE',
                  'sede': 'SEDE 1',
                  'direccion': 'CALLE 9',
                  'ciudad': 'Bogotá',
                },
              },
            ],
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: DespachoDialog())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Destino del empaque'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('destino-null')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('DESTINATARIO NORTE').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('destino-destino-1')), findsOneWidget);
    await tester.ensureVisible(
      find.widgetWithText(DropdownButtonFormField<String>, 'Cliente'),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'Cliente'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cliente').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir prendas'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Armar empaques'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'Agregar empaque'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Nuevo ·').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Prendas'), '5');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Generar rótulo 1',
            ),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Generar todos los rótulos'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Revisar empaque'));
    await tester.pumpAndSettle();
    expect(find.text('Revisa antes de confirmar'), findsOneWidget);
    expect(find.text('DESTINATARIO NORTE · Bogotá'), findsOneWidget);
    expect(
      find.text('Selecciona el destinatario antes de empacar.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  test('Reservas conservan stock físico y excluyen ubicaciones al empacar', () {
    final i = prenda(reservas: {'A': 4, 'B': 2});
    expect(i.stockDisponible, 10);
    expect(i.reservado, 6);
    expect(i.disponibleParaDespacho, 4);
    final plan = planificarDespacho([i], {'i': 4});
    expect(plan.single['ubicacion'], 'B');
    expect(plan.single['cantidad'], 4);
    expect(() => planificarDespacho([i], {'i': 5}), throwsFormatException);
  });
  testWidgets('Empacados aparecen en Seguimiento y no en Historial', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = InMemoryWmsRepository.seeded();
    addTearDown(repo.dispose);
    final despachos =
        _Despachos()
          ..leNumero = 2971
          ..fase = 'empacado';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          usarSupabaseProvider.overrideWithValue(false),
          wmsRepositoryProvider.overrideWithValue(repo),
          despachosOcProvider.overrideWithValue(despachos),
        ],
        child: const MaterialApp(home: Scaffold(body: DespachoDialog())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seguimiento'));
    await tester.pumpAndSettle();
    expect(find.text('LE N° 2971'), findsOneWidget);
    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(find.text('LE N° 2971'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Corrección precarga empaque, libera stock solo virtual y exige motivo',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = InMemoryWmsRepository.seeded();
      addTearDown(repo.dispose);
      final despachos = _Despachos();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            usarSupabaseProvider.overrideWithValue(false),
            wmsRepositoryProvider.overrideWithValue(repo),
            wmsSnapshotProvider.overrideWith(
              (ref) => Stream.value(
                WmsSnapshot(
                  kardex: [prenda(despachado: 10, stock: {})],
                  lotes: [],
                ),
              ),
            ),
            despachosOcProvider.overrideWithValue(despachos),
            empaquesProvider.overrideWith(
              (ref) async => [
                {
                  'id': 'caja1',
                  'nombre': 'Caja prueba',
                  'categoria': 'CAJA',
                  'version': 'v1',
                  'alto_cm': 10,
                  'largo_cm': 20,
                  'ancho_cm': 30,
                },
              ],
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder:
                  (context) => Scaffold(
                    body: TextButton(
                      child: const Text('Abrir corrección'),
                      onPressed:
                          () => showDialog<void>(
                            context: context,
                            builder:
                                (_) => const DespachoDialog(
                                  correccion: {
                                    'id': 'd1',
                                    'version': 'v1',
                                    'le_numero': 2971,
                                    'ediciones': 2,
                                    'cliente': 'Cliente',
                                    'oc': 'OC1',
                                    'detalle': [
                                      {
                                        'item_id': 'i',
                                        'op': '1',
                                        'cantidad': 10,
                                        'ubicacion': 'A',
                                      },
                                    ],
                                    'empaques': [
                                      {
                                        'id': 'caja1',
                                        'item_id': 'i',
                                        'numero': 1,
                                        'cantidad': 10,
                                      },
                                    ],
                                  },
                                ),
                          ),
                    ),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir corrección'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Corregir despacho'), findsOneWidget);

      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Prendas'),
            )
            .initialValue,
        '10',
      );
      final revisar = find.text('Revisar empaque');

      await tester.tap(revisar);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar empaque'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Indica el motivo de la corrección para guardar los cambios.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cerrar aviso'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Motivo de la corrección (obligatorio)'),
        'Cantidad equivocada',
      );
      await tester.tap(find.text('Atrás'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Prendas'),
        '7',
      );

      await tester.tap(revisar);
      await tester.pumpAndSettle();
      expect(find.text('7 prendas'), findsOneWidget);
      expect(despachos.correcciones, isEmpty);
      await tester.tap(find.text('Confirmar empaque'));
      await tester.pumpAndSettle();
      expect(despachos.correcciones, ['d1']);
      expect(despachos.planes.single.single['cantidad'], 7);
      expect(find.text('Abrir corrección'), findsOneWidget);
    },
  );
  testWidgets('Clientes de despacho: stock y pendiente, con actualización', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = InMemoryWmsRepository.seeded();
    addTearDown(repo.dispose);
    final snapshots = StreamController<WmsSnapshot>();
    addTearDown(snapshots.close);
    ItemKardex fila(
      String cliente,
      int recibido,
      int despachado, {
      bool eliminada = false,
    }) => ItemKardex(
      item: ItemOrden(
        id: cliente,
        op: cliente,
        cliente: cliente,
        oc: 'OC1',
        codigo: 'C',
        descripcion: 'Camisa',
        talla: 'M',
        cantidadPedida: 10,
      ),
      producido: recibido,
      recibido: recibido,
      despachado: despachado,
      eliminada: eliminada,
      ubicaciones: {'A': recibido - despachado},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          usarSupabaseProvider.overrideWithValue(false),
          wmsRepositoryProvider.overrideWithValue(repo),
          wmsSnapshotProvider.overrideWith((ref) => snapshots.stream),
          despachosOcProvider.overrideWithValue(_Despachos()),
        ],
        child: const MaterialApp(home: Scaffold(body: DespachoDialog())),
      ),
    );
    snapshots.add(
      WmsSnapshot(
        kardex: [
          fila('Disponible', 8, 3),
          fila('Sin stock', 5, 5),
          fila('Completo con sobrante', 15, 10),
          fila('Eliminado', 10, 0, eliminada: true),
        ],
        lotes: [],
      ),
    );
    await tester.pumpAndSettle();
    final selector = find.byType(DropdownButtonFormField<String>);
    expect(
      tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .items!
          .map((i) => i.value)
          .toList(),
      ['Disponible'],
    );
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disponible').last);
    await tester.pumpAndSettle();
    snapshots.add(WmsSnapshot(kardex: [fila('Disponible', 8, 8)], lotes: []));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .items,
      isEmpty,
    );
    expect(find.text('No hay prendas disponibles en bodega.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Selección, vista previa cancelable, reintento sin duplicar e historial plegado',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = InMemoryWmsRepository.seeded();
      addTearDown(repo.dispose);
      final despachos =
          _Despachos()
            ..fallarPrimera = true
            ..leNumero = 2971;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            usarSupabaseProvider.overrideWithValue(false),
            wmsRepositoryProvider.overrideWithValue(repo),
            wmsSnapshotProvider.overrideWith(
              (ref) => Stream.value(WmsSnapshot(kardex: [prenda()], lotes: [])),
            ),
            despachosOcProvider.overrideWithValue(despachos),
            empaquesProvider.overrideWith(
              (ref) async => [
                {
                  'id': 'caja1',
                  'nombre': 'Caja prueba',
                  'categoria': 'CAJA',
                  'largo_cm': 30,
                  'ancho_cm': 20,
                  'alto_cm': 10,
                  'peso_neto_kg': 1,
                  'peso_bruto_kg': 5,
                  'version': 'v1',
                },
              ],
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: DespachoDialog())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cliente').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir prendas'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Armar empaques'));
      await tester.pumpAndSettle();
      final agregar = find.widgetWithText(
        DropdownButtonFormField<String>,
        'Agregar empaque',
      );
      await tester.ensureVisible(agregar);
      await tester.pumpAndSettle();
      await tester.tap(agregar);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Caja prueba').last);
      await tester.pumpAndSettle();
      final cajas = find.widgetWithText(TextFormField, 'Prendas');
      await tester.enterText(cajas, '999');
      await tester.pump();
      expect(find.textContaining('Quedan -989 en bodega'), findsOneWidget);
      await tester.enterText(cajas, '3');
      await tester.ensureVisible(agregar);
      await tester.tap(agregar);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Caja prueba').last);
      await tester.pumpAndSettle();
      expect(cajas, findsNWidgets(2));
      await tester.enterText(cajas.last, '5');

      await tester.pumpAndSettle();
      await tester.tap(find.text('Revisar empaque'));
      await tester.pumpAndSettle();
      expect(find.textContaining('4 desde A'), findsOneWidget);
      expect(find.textContaining('4 desde B'), findsOneWidget);
      expect(despachos.solicitudes, isEmpty);
      await tester.tap(find.text('Atrás'));
      await tester.pumpAndSettle();
      expect(despachos.solicitudes, isEmpty);
      await tester.tap(find.text('Revisar empaque'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar empaque'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar aviso'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Reintentar mismo despacho'));
      await tester.tap(find.text('Reintentar mismo despacho'));
      await tester.pumpAndSettle();
      expect(find.text('Empaque confirmado'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(despachos.solicitudes.length, 2);
      expect(despachos.solicitudes.toSet().length, 1);
      expect(despachos.planes[0], despachos.planes[1]);
      expect(despachos.empaquesEnviados[0], despachos.empaquesEnviados[1]);
      expect(despachos.empaquesEnviados[0].map((e) => e['cantidad']), [3, 5]);
      expect(despachos.empaquesEnviados[0].map((e) => e['numero']), [1, 2]);
      expect(despachos.empaquesEnviados[0].map((e) => e['empaque_id']), [
        'caja1',
        'caja1',
      ]);
      expect(
        despachos.empaquesEnviados[0].every((e) => e['item_id'] == 'i'),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Empacar otra OC'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir prendas'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Armar empaques'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(agregar);
      await tester.pumpAndSettle();
      await tester.tap(agregar);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Caja prueba').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(cajas);
      await tester.enterText(cajas, '10');
      await tester.ensureVisible(find.text('Revisar empaque'));
      await tester.tap(find.text('Revisar empaque'));
      await tester.pumpAndSettle();
      expect(find.text('10 prendas'), findsOneWidget);
      expect(find.textContaining('6 desde B'), findsOneWidget);
      await tester.tap(find.text('Confirmar empaque'));
      await tester.pumpAndSettle();
      expect(despachos.solicitudes.length, 3);
      expect(despachos.solicitudes.last, isNot(despachos.solicitudes.first));
      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar por LE, OC u OP'),
        '9999',
      );
      await tester.pumpAndSettle();
      expect(find.text('LE N° 2971'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar por LE, OC u OP'),
        '2971',
      );
      await tester.pumpAndSettle();
      expect(find.text('LE N° 2971'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar por LE, OC u OP'),
        'oc1',
      );
      await tester.pumpAndSettle();
      expect(find.text('LE N° 2971'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar por LE, OC u OP'),
        'otra',
      );
      await tester.pumpAndSettle();
      expect(find.text('OP 1 · Camisa (M)'), findsNothing);
      expect(find.text('LE N° 2971'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar por LE, OC u OP'),
        '1',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Por: Ana'), findsNothing);
      await tester.ensureVisible(find.text('LE N° 2971'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LE N° 2971'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Por: Ana'), findsOneWidget);
    },
  );
  testWidgets('Comparte un empaque entre dos tallas sin duplicar su número', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = InMemoryWmsRepository.seeded();
    addTearDown(repo.dispose);
    final despachos = _Despachos();
    final otra = ItemKardex(
      item: const ItemOrden(
        id: 'j',
        op: '1',
        cliente: 'Cliente',
        oc: 'OC1',
        codigo: 'C',
        descripcion: 'Camisa',
        talla: 'L',
        cantidadPedida: 10,
      ),
      producido: 10,
      recibido: 10,
      despachado: 0,
      ubicaciones: const {'A': 10},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          usarSupabaseProvider.overrideWithValue(false),
          wmsRepositoryProvider.overrideWithValue(repo),
          wmsSnapshotProvider.overrideWith(
            (ref) =>
                Stream.value(WmsSnapshot(kardex: [prenda(), otra], lotes: [])),
          ),
          despachosOcProvider.overrideWithValue(despachos),
          empaquesProvider.overrideWith(
            (ref) async => [
              {
                'id': 'caja1',
                'nombre': 'Caja prueba',
                'categoria': 'CAJA',
                'largo_cm': 30,
                'ancho_cm': 20,
                'alto_cm': 10,
                'version': 'v1',
              },
            ],
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: DespachoDialog())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cliente').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir prendas'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Armar empaques'));
    await tester.pumpAndSettle();
    final agregar = find.widgetWithText(
      DropdownButtonFormField<String>,
      'Agregar empaque',
    );
    await tester.ensureVisible(agregar.first);
    await tester.pumpAndSettle();
    await tester.tap(agregar.first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Nuevo ·').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Prendas').first,
      '2',
    );
    await tester.ensureVisible(agregar.last);
    await tester.pumpAndSettle();
    await tester.tap(agregar.last);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Usar empaque 1').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Prendas').last,
      '3',
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisar empaque'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar empaque'));
    await tester.pumpAndSettle();
    expect(despachos.empaquesEnviados.single.map((e) => e['numero']), [1, 1]);
    expect(despachos.empaquesEnviados.single.map((e) => e['item_id']), [
      'i',
      'j',
    ]);
    expect(despachos.empaquesEnviados.single.map((e) => e['cantidad']), [2, 3]);
    expect(tester.takeException(), isNull);
  });
  test('Estado de OC considera todas las OP, aunque no tengan movimientos', () {
    final completa = prenda(despachado: 10);
    final pendiente = ItemKardex(
      item: const ItemOrden(
        id: 'otra',
        op: '2',
        cliente: 'Cliente',
        oc: 'OC1',
        codigo: 'D',
        descripcion: 'Otra',
        talla: 'S',
        cantidadPedida: 5,
      ),
      producido: 0,
      recibido: 0,
      despachado: 0,
      ubicaciones: const {},
    );
    expect(estadoDespachoOc([completa], 'Cliente', 'OC1'), 'Completo');
    expect(
      estadoDespachoOc([completa, pendiente], 'Cliente', 'OC1'),
      'Parcial',
    );
    expect(
      estadoDespachoOc([completa], 'Otro cliente', 'OC1'),
      'Sin datos actuales',
    );
  });
  test('Logística muestra fecha de despacho independiente de Producción', () {
    final k = ItemKardex(
      item: prenda().item,
      producido: 10,
      recibido: 10,
      despachado: 3,
      ubicaciones: const {},
      fechaEntrega: DateTime(2026, 9, 1),
      fechaDespacho: DateTime(2026, 10, 2),
    );
    expect(
      columnasDespacho[ColKardex.fechaEntregaBodega]!(k),
      isNot(columnasProduccion[ColKardex.fechaEntrega]!(k)),
    );
    expect(
      columnasDespacho[ColKardex.fechaEntregaBodega]!(prenda()),
      'Sin fecha',
    );
  });
  test('Distribuye entre estantes y no supera la cantidad solicitada', () {
    final plan = planificarDespacho([prenda()], {'i': 8});
    expect(plan.map((l) => l['ubicacion']), ['A', 'B']);
    expect(plan.map((l) => l['cantidad']), [4, 4]);
  });
  test(
    'Rechaza stock insuficiente global o por estantes y exceder pendiente',
    () {
      expect(
        () =>
            planificarDespacho([prenda(recibido: 5, despachado: 5)], {'i': 1}),
        throwsFormatException,
      );
      expect(
        () => planificarDespacho([prenda(recibido: 5)], {'i': 6}),
        throwsFormatException,
      );
      expect(
        () => planificarDespacho(
          [
            prenda(stock: {'A': 4}),
          ],
          {'i': 6},
        ),
        throwsFormatException,
      );
      expect(
        () => planificarDespacho([prenda(despachado: 5)], {'i': 6}),
        throwsFormatException,
      );
      expect(
        () => planificarDespacho([prenda()], {'i': 0}),
        throwsFormatException,
      );
      expect(
        () => planificarDespacho([prenda()], {'inexistente': 1}),
        throwsFormatException,
      );
    },
  );
  test(
    'Excel relaciona No. OC de Orden con todas sus tallas sin alterar cantidades',
    () {
      final libro = Excel.createExcel();
      libro['Orden'].appendRow([
        for (final s in ['Identificador', 'Cliente', 'No. OC'])
          TextCellValue(s),
      ]);
      libro['Orden'].appendRow([
        TextCellValue('1'),
        TextCellValue('Cliente'),
        TextCellValue('00027'),
      ]);
      libro['Tallas'].appendRow([
        for (final s in [
          'Identificador orden',
          'Código',
          'Tallas nombre',
          'Cantidad',
        ])
          TextCellValue(s),
      ]);
      for (final talla in ['M', 'S']) {
        libro['Tallas'].appendRow([
          TextCellValue('1'),
          TextCellValue('C'),
          TextCellValue(talla),
          IntCellValue(5),
        ]);
      }
      final datos = ExcelOrdenesParser.parsear(
        Uint8List.fromList(libro.encode()!),
      );
      expect(datos.tallas.map((t) => t['oc']), ['00027', '00027']);
      expect(datos.tallas.map((t) => t['cantidad']), ['5', '5']);
    },
  );
}
