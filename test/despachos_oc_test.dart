import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/data/despachos_oc_repository.dart';
import 'package:orbiloq_wms/data/excel_ordenes_parser.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/features/despacho/presentation/despacho_dialog.dart';
import 'package:orbiloq_wms/application/kardex_columnas.dart';
import 'package:orbiloq_wms/application/kardex_filters.dart';

class _Despachos extends DespachosOcRepository {
  final solicitudes = <String>[];
  final planes = <List<Map<String, dynamic>>>[];
  bool fallarPrimera = false;
  @override
  Future<void> confirmar(String solicitud, String cliente, String oc,
      List<Map<String, dynamic>> lineas) async {
    solicitudes.add(solicitud);
    planes.add(lineas);
    if (fallarPrimera && solicitudes.length == 1) {
      throw Exception('Respuesta perdida');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> historial() async => [
        {
          'registro': 'h1',
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
        }
      ];
}

ItemKardex prenda(
        {int recibido = 10,
        int despachado = 0,
        Map<String, int> stock = const {'B': 6, 'A': 4}}) =>
    ItemKardex(
        item: const ItemOrden(
            id: 'i',
            op: '1',
            cliente: 'Cliente',
            oc: 'OC1',
            codigo: 'C',
            descripcion: 'Camisa',
            talla: 'M',
            cantidadPedida: 10),
        producido: 10,
        recibido: recibido,
        despachado: despachado,
        ubicaciones: stock);

void main() {
  testWidgets(
      'Selección, vista previa cancelable, reintento sin duplicar e historial plegado',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = InMemoryWmsRepository.seeded();
    addTearDown(repo.dispose);
    final despachos = _Despachos()..fallarPrimera = true;
    await tester.pumpWidget(ProviderScope(overrides: [
      usarSupabaseProvider.overrideWithValue(false),
      wmsRepositoryProvider.overrideWithValue(repo),
      wmsSnapshotProvider.overrideWith(
          (ref) => Stream.value(WmsSnapshot(kardex: [prenda()], lotes: []))),
      despachosOcProvider.overrideWithValue(despachos),
    ], child: const MaterialApp(home: Scaffold(body: DespachoDialog()))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cliente').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OC: OC1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    final cantidad = find.widgetWithText(TextField, 'Cantidad (0 para omitir)');
    await tester.enterText(cantidad, '8');
    await tester.tap(find.text('Revisar y despachar selección'));
    await tester.pumpAndSettle();
    expect(find.textContaining('4 Uds desde A'), findsOneWidget);
    expect(find.textContaining('4 Uds desde B'), findsOneWidget);
    expect(despachos.solicitudes, isEmpty);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(despachos.solicitudes, isEmpty);
    await tester.tap(find.text('Revisar y despachar selección'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar despacho'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reintentar mismo despacho'));
    await tester.tap(find.text('Reintentar mismo despacho'));
    await tester.pumpAndSettle();
    expect(despachos.solicitudes.length, 2);
    expect(despachos.solicitudes.toSet().length, 1);
    expect(despachos.planes[0], despachos.planes[1]);
    await tester.tap(find.text('Despachar todo lo pendiente de esta OC'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Total: 10 Uds'), findsOneWidget);
    expect(find.textContaining('6 Uds desde B'), findsOneWidget);
    await tester.tap(find.text('Confirmar despacho'));
    await tester.pumpAndSettle();
    expect(despachos.solicitudes.length, 3);
    expect(despachos.solicitudes.last, isNot(despachos.solicitudes.first));
    await tester.tap(find.text('HISTORIAL'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Buscar por OC'), 'oc1');
    await tester.pumpAndSettle();
    expect(find.textContaining('Estado actual: Parcial'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Buscar por OP'), 'otra');
    await tester.pumpAndSettle();
    expect(find.text('OP 1 · Camisa (M)'), findsNothing);
    expect(find.textContaining('Estado actual: Parcial'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Buscar por OP'), '1');
    await tester.pumpAndSettle();
    expect(find.textContaining('Por: Ana'), findsNothing);
    await tester.tap(find.text('OP 1 · Camisa (M)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Por: Ana'), findsOneWidget);
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
            cantidadPedida: 5),
        producido: 0,
        recibido: 0,
        despachado: 0,
        ubicaciones: const {});
    expect(estadoDespachoOc([completa], 'Cliente', 'OC1'), 'Completo');
    expect(
        estadoDespachoOc([completa, pendiente], 'Cliente', 'OC1'), 'Parcial');
    expect(estadoDespachoOc([completa], 'Otro cliente', 'OC1'),
        'Sin datos actuales');
  });
  test('Logística muestra fecha de despacho independiente de Producción', () {
    final k = ItemKardex(
        item: prenda().item,
        producido: 10,
        recibido: 10,
        despachado: 3,
        ubicaciones: const {},
        fechaEntrega: DateTime(2026, 9, 1),
        fechaDespacho: DateTime(2026, 10, 2));
    expect(columnasBodega[ColKardex.fechaEntregaBodega]!(k),
        isNot(columnasProduccion[ColKardex.fechaEntrega]!(k)));
    expect(
        columnasBodega[ColKardex.fechaEntregaBodega]!(prenda()), 'Sin fecha');
  });
  test('Distribuye entre estantes y no supera la cantidad solicitada', () {
    final plan = planificarDespacho([prenda()], {'i': 8});
    expect(plan.map((l) => l['ubicacion']), ['A', 'B']);
    expect(plan.map((l) => l['cantidad']), [4, 4]);
  });
  test('Rechaza stock insuficiente global o por estantes y exceder pendiente',
      () {
    expect(() => planificarDespacho([prenda(recibido: 5)], {'i': 6}),
        throwsFormatException);
    expect(
        () => planificarDespacho([
              prenda(stock: {'A': 4})
            ], {
              'i': 6
            }),
        throwsFormatException);
    expect(() => planificarDespacho([prenda(despachado: 5)], {'i': 6}),
        throwsFormatException);
    expect(
        () => planificarDespacho([prenda()], {'i': 0}), throwsFormatException);
    expect(() => planificarDespacho([prenda()], {'inexistente': 1}),
        throwsFormatException);
  });
  test(
      'Excel relaciona No. OC de Orden con todas sus tallas sin alterar cantidades',
      () {
    final libro = Excel.createExcel();
    libro['Orden'].appendRow([
      for (final s in ['Identificador', 'Cliente', 'No. OC']) TextCellValue(s)
    ]);
    libro['Orden'].appendRow(
        [TextCellValue('1'), TextCellValue('Cliente'), TextCellValue('00027')]);
    libro['Tallas'].appendRow([
      for (final s in [
        'Identificador orden',
        'Código',
        'Tallas nombre',
        'Cantidad'
      ])
        TextCellValue(s)
    ]);
    for (final talla in ['M', 'S']) {
      libro['Tallas'].appendRow([
        TextCellValue('1'),
        TextCellValue('C'),
        TextCellValue(talla),
        IntCellValue(5)
      ]);
    }
    final datos =
        ExcelOrdenesParser.parsear(Uint8List.fromList(libro.encode()!));
    expect(datos.tallas.map((t) => t['oc']), ['00027', '00027']);
    expect(datos.tallas.map((t) => t['cantidad']), ['5', '5']);
  });
}
