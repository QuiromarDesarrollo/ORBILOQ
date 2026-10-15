import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/data/excel_ordenes_parser.dart';
import 'package:orbiloq_wms/data/facturacion_le.dart';
import 'package:orbiloq_wms/features/despacho/presentation/facturacion_panel.dart';

class _Repo implements FacturacionRepository {
  final fila = <String, dynamic>{
    'id': 'd1',
    'revision': 0,
    'version': 0,
    'version_seguimiento': 1,
    'le': 2989,
    'cliente': 'CLIENTE A',
    'oc': 'OC-1',
    'recibido': '2026-10-15',
    'remision': '',
    'id_oc': '12345',
    'ids_erp': ['12345'],
  };
  @override
  Future<List<Map<String, dynamic>>> listar(bool completas) async {
    final completa =
        '${fila['remision']}'.trim().isNotEmpty &&
        '${fila['id_oc']}'.trim().isNotEmpty;
    return completa == completas ? [Map.of(fila)] : [];
  }

  @override
  Future<void> guardar(
    Map<String, dynamic> f,
    String remision,
    String idOc,
  ) async {
    fila['remision'] = remision.trim();
    fila['id_oc'] = idOc.trim();
    fila['version'] = (fila['version'] as int) + 1;
  }
}

void main() {
  test('ID. OC se lee de Orden independientemente del OC ID de Tallas', () {
    final libro = Excel.createExcel();
    libro['Orden'].appendRow([
      TextCellValue('Identificador'),
      TextCellValue('Cliente'),
      TextCellValue('No. OC'),
      TextCellValue('ID. OC'),
    ]);
    libro['Orden'].appendRow([
      TextCellValue('26241'),
      TextCellValue('CLIENTE'),
      TextCellValue('OC-1'),
      IntCellValue(12345),
    ]);
    libro['Tallas'].appendRow([
      TextCellValue('Identificador orden'),
      TextCellValue('Código'),
      TextCellValue('Tallas nombre'),
      TextCellValue('Cantidad'),
      TextCellValue('OC ID'),
    ]);
    libro['Tallas'].appendRow([
      TextCellValue('26241'),
      TextCellValue('COD'),
      TextCellValue('L'),
      IntCellValue(10),
      IntCellValue(999),
    ]);
    final datos = ExcelOrdenesParser.parsear(
      Uint8List.fromList(libro.encode()!),
    );
    expect(datos.ordenes.single['oc_id_erp'], '12345');
  });
  for (final width in [320.0, 1000.0]) {
    testWidgets('Facturacion edita y cambia de vista a $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repo();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [facturacionRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: Scaffold(body: FacturacionPanel())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lista de empaque 2989'), findsOneWidget);
      expect(find.text('12345'), findsOneWidget);
      final inputs = find.byType(TextField);
      await tester.enterText(inputs.at(1), 'REM-10');
      await tester.enterText(inputs.at(2), 'OC-ID-EDITADO');
      await tester.ensureVisible(find.text('Guardar cambios'));
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(find.text('Lista de empaque 2989'), findsNothing);
      await tester.tap(find.text('Facturadas completas'));
      await tester.pumpAndSettle();
      expect(find.text('REM-10'), findsOneWidget);
      expect(find.text('OC-ID-EDITADO'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(1), '');
      await tester.ensureVisible(find.text('Guardar cambios'));
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Facturadas sin completar'));
      await tester.pumpAndSettle();
      expect(find.text('Lista de empaque 2989'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
