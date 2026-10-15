import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/data/excel_ciclos.dart';
import 'package:orbiloq_wms/data/excel_ciclos_async.dart';

void main() {
  test('Plantilla de 13 columnas y lectura en segundo plano', () async {
    final libro = Excel.createExcel();
    final hoja = libro['Historicos'];
    hoja.appendRow([
      for (final c in [
        ...ExcelCiclos.columnas,
        ...ExcelCiclos.columnasReferencia,
      ])
        TextCellValue(c),
    ]);
    hoja.appendRow([
      TextCellValue('OP-1'),
      TextCellValue('Cliente'),
      IntCellValue(10),
      for (var n = 1; n <= 8; n++)
        TextCellValue('2026-01-${n.toString().padLeft(2, '0')}'),
      TextCellValue('2026-02-01'),
      TextCellValue('4, 5'),
    ]);
    final filas = await leerCiclosAsync(Uint8List.fromList(libro.encode()!));
    expect(filas.single['fecha_comprometida_entrega'], '2026-02-01');
    expect(filas.single['fila_original'], '4, 5');
    expect((filas.single['fines'] as Map)['logistica'], '2026-01-08');
  });
  test('Lectura en segundo plano propaga errores sin guardado', () async {
    await expectLater(
      leerCiclosAsync(Uint8List.fromList([1, 2, 3])),
      throwsA(anything),
    );
  });
  test(
    'Importa 2000 OP y omite auditoría sin reconstruir la matriz por celda',
    () {
      final libro = Excel.createExcel();
      final hoja = libro['Historicos'];
      hoja.appendRow([for (final c in ExcelCiclos.columnas) TextCellValue(c)]);
      for (var n = 0; n < 2000; n++) {
        hoja.appendRow([
          TextCellValue('OP-$n'),
          TextCellValue('Cliente'),
          IntCellValue(n + 1),
          for (var p = 0; p < 8; p++)
            TextCellValue('2026-01-${(p + 1).toString().padLeft(2, '0')}'),
        ]);
      }
      libro['Cambios'].appendRow([
        TextCellValue('FILA ORIGINAL'),
        TextCellValue('CAMBIO'),
      ]);
      final bytes = Uint8List.fromList(libro.encode()!);
      final tiempo = Stopwatch()..start();
      final filas = ExcelCiclos.leer(bytes);
      tiempo.stop();
      expect(filas.length, 2000);
      expect(filas.last['cantidad'], 2000);
      expect((filas.last['fines'] as Map)['logistica'], '2026-01-08');
      // Umbral holgado: la implementación cuadrática tardaba varios minutos.
      expect(tiempo.elapsed, lessThan(const Duration(seconds: 30)));
    },
  );
}
