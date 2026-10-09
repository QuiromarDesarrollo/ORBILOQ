@TestOn('browser')
library;

import 'dart:js_interop';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:orbiloq_wms/data/kardex_excel_exportador.dart';

void main() {
  test('El reporte descarga un XLSX legible con nombre, hojas y cantidades', () async {
    String? url;
    String? nombre;
    var descargas = 0;
    final listener = ((web.Event event) {
      final target = event.target;
      if (target != null && target.isA<web.HTMLAnchorElement>()) {
        final enlace = target as web.HTMLAnchorElement;
        descargas++;
        nombre = enlace.download;
        url = enlace.href;
        event.preventDefault();
      }
    }).toJS;
    web.document.addEventListener('click', listener);
    addTearDown(() => web.document.removeEventListener('click', listener));
    await KardexExcelExportador.exportarReporte('trazabilidad', {
      'Trazabilidad OP': [['OP', 'Cantidad'], ['90003', 15]],
      'Resumen': [['Total'], [15]],
    });
    expect(nombre, 'trazabilidad.xlsx');
    expect(descargas, 1);
    expect(url, startsWith('blob:'));
    final response = await web.window.fetch(url!.toJS).toDart;
    expect(response.headers.get('Content-Type'),
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final buffer = await response.arrayBuffer().toDart;
    final libro = Excel.decodeBytes(buffer.toDart.asUint8List());
    expect(libro.tables.keys, ['Trazabilidad OP', 'Resumen']);
    expect(libro['Trazabilidad OP'].rows[1][1]!.value, IntCellValue(15));
    expect(web.document.querySelector('a[download="trazabilidad.xlsx"]'), isNull);
  });
}
