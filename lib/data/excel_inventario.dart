import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';

class ExcelInventario {
  static const columnas = [
    'NOMBRE FICHA TECNICA',
    'CLIENTE',
    'CODIGO',
    'DESCRIPCION',
    'TALLAS NOMBRE',
    'CANTIDAD',
    'ESTANTE',
  ];
  static String normalizar(String s) =>
      s.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
  static Uint8List plantilla() {
    final libro = Excel.createExcel();
    libro.rename(libro.getDefaultSheet()!, 'Inventario');
    libro['Inventario'].appendRow(columnas.map(TextCellValue.new).toList());
    return Uint8List.fromList(libro.encode()!);
  }

  static Map<String, dynamic> leer(Uint8List bytes) {
    if (bytes.length > 10 * 1024 * 1024) {
      throw const FormatException('El archivo supera 10 MB.');
    }
    final libro = Excel.decodeBytes(bytes);
    final candidatas =
        libro.tables.values
            .where(
              (s) =>
                  s.rows.isNotEmpty &&
                  columnas
                      .take(6)
                      .every(
                        (c) => s.rows.first
                            .map((d) => normalizar(d?.value?.toString() ?? ''))
                            .contains(c),
                      ),
            )
            .toList();
    if (candidatas.length != 1) {
      throw const FormatException(
        'Debe existir una sola hoja con las seis columnas requeridas (ESTANTE es opcional), en la primera fila.',
      );
    }
    final hoja = candidatas.single;
    final headers =
        hoja.rows.first
            .map((d) => normalizar(d?.value?.toString() ?? ''))
            .toList();
    if (columnas.any((c) => headers.where((h) => h == c).length > 1)) {
      throw const FormatException('Hay columnas requeridas duplicadas.');
    }
    final grupos = <String, Map<String, dynamic>>{};
    var leidas = 0;
    for (var n = 1; n < hoja.rows.length; n++) {
      final row = hoja.rows[n];
      if (row.every((d) => (d?.value?.toString().trim() ?? '').isEmpty)) {
        continue;
      }
      leidas++;
      if (leidas > 5000) {
        throw const FormatException(
          'Máximo 5000 filas por archivo. Divide el archivo antes de cargarlo.',
        );
      }
      String valor(String c) {
        final idx = headers.indexOf(c);
        final value = idx >= 0 && idx < row.length ? row[idx]?.value : null;
        if (value is FormulaCellValue) {
          throw FormatException(
            'Fila ${n + 1}: pega el valor de $c; no se admiten fórmulas.',
          );
        }
        if (value is DoubleCellValue &&
            value.value == value.value.truncateToDouble()) {
          return value.value.toInt().toString();
        }
        return normalizar(value?.toString() ?? '');
      }

      final valores = columnas.map(valor).toList();
      if (valores.take(6).any((s) => s.isEmpty)) {
        throw FormatException('Fila ${n + 1}: completa todas las columnas.');
      }
      if (valores.any((s) => s.length > 500)) {
        throw FormatException('Fila ${n + 1}: un campo supera 500 caracteres.');
      }
      final cantidad = int.tryParse(valores[5]);
      if (cantidad == null || cantidad <= 0 || cantidad > 999999) {
        throw FormatException(
          'Fila ${n + 1}: CANTIDAD debe ser un entero entre 1 y 999999.',
        );
      }
      final clave = jsonEncode([
        valores[0],
        valores[1],
        valores[2],
        valores[4],
        valores[6],
      ]);
      final previa = grupos[clave];
      if (previa != null && previa['descripcion'] != valores[3]) {
        throw FormatException(
          'Fila ${n + 1}: la misma prenda tiene descripciones diferentes.',
        );
      }
      final total = (previa?['cantidad'] as int? ?? 0) + cantidad;
      if (total > 999999) {
        throw FormatException(
          'Fila ${n + 1}: la cantidad agrupada supera 999999.',
        );
      }
      grupos[clave] = {
        'ficha': valores[0],
        'cliente': valores[1],
        'codigo': valores[2],
        'descripcion': valores[3],
        'talla': valores[4],
        'cantidad': total,
        'estante': valores[6],
      };
    }
    if (grupos.isEmpty) {
      throw const FormatException('El archivo no contiene prendas.');
    }
    if (grupos.length > 1000) {
      throw const FormatException(
        'Máximo 1000 combinaciones de prenda y estante por carga. Divide el archivo.',
      );
    }
    final claves = grupos.keys.toList()..sort();
    return {
      'hoja': hoja.sheetName,
      'filas_leidas': leidas,
      'filas': [for (final k in claves) grupos[k]!],
    };
  }
}
