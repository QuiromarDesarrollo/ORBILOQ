import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../domain/ciclos.dart';

class ExcelCiclos {
  static const columnas = [
    'N° DE ORDEN',
    'CLIENTE',
    'CANTIDAD',
    'FECHA DE INICIO',
    'COMPRAS',
    'TRAZO',
    'CORTE',
    'SEPARADO',
    'ALIADOS',
    'TERMINADO',
    'LOGISTICA',
  ];
  static String normalizar(String s) => s
      .trim()
      .toUpperCase()
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll('É', 'E')
      .replaceAll('Á', 'A')
      .replaceAll('º', '°')
      .replaceAll(RegExp(r'\s+'), ' ');
  static List<Map<String, dynamic>> leer(Uint8List bytes) {
    if (bytes.length > 20 * 1024 * 1024) {
      throw const FormatException('El archivo supera 20 MB.');
    }
    final libro = Excel.decodeBytes(bytes);
    final hojas =
        libro.tables.values
            .where(
              (h) =>
                  h.rows.isNotEmpty &&
                  columnas.every(
                    (c) => h.rows.first.any(
                      (d) => normalizar('${d?.value ?? ''}') == c,
                    ),
                  ),
            )
            .toList();
    if (hojas.length != 1) {
      throw const FormatException(
        'Se requiere una sola hoja con los 11 encabezados: N° DE ORDEN, CLIENTE, CANTIDAD, FECHA DE INICIO y los siete procesos.',
      );
    }
    final hoja = hojas.single,
        headers =
            hoja.rows.first
                .map((d) => normalizar('${d?.value ?? ''}'))
                .toList();
    if (headers.where((h) => h.isNotEmpty).toSet().length !=
        headers.where((h) => h.isNotEmpty).length) {
      throw const FormatException('Hay encabezados duplicados.');
    }
    final merges = [
      for (final s in hoja.spannedItems)
        s.split(':').map(CellIndex.indexByString).toList(),
    ];
    final result = <Map<String, dynamic>>[], ops = <String>{};
    CellValue? celda(int r, int c) {
      final fila = hoja.rows[r];
      return c < fila.length ? fila[c]?.value : null;
    }

    for (var r = 1; r < hoja.rows.length; r++) {
      if (hoja.rows[r].every((v) => '${v?.value ?? ''}'.trim().isEmpty)) {
        continue;
      }
      CellValue? valor(String columna) {
        final c = headers.indexOf(columna);
        var v = celda(r, c);
        if (columna == 'CANTIDAD' && (v == null || '$v'.trim().isEmpty)) {
          for (final m in merges) {
            if (m.length == 2 &&
                m[0].columnIndex == c &&
                m[1].columnIndex == c &&
                r > m[0].rowIndex &&
                r <= m[1].rowIndex) {
              v = celda(m[0].rowIndex, c);
              break;
            }
          }
        }
        if (v is FormulaCellValue) {
          throw FormatException(
            'Fila ${r + 1}, $columna: usa valores, no fórmulas.',
          );
        }
        return v;
      }

      final opCelda = valor(columnas[0]);
      final op =
              opCelda is DoubleCellValue &&
                      opCelda.value.isFinite &&
                      opCelda.value == opCelda.value.roundToDouble()
                  ? opCelda.value.toInt().toString()
                  : '${opCelda ?? ''}'.trim(),
          cliente = '${valor('CLIENTE') ?? ''}'.trim();
      final cantidad = num.tryParse('${valor('CANTIDAD') ?? ''}');
      if (op.isEmpty ||
          op.length > 100 ||
          cliente.isEmpty ||
          cliente.length > 300 ||
          cantidad == null ||
          !cantidad.isFinite ||
          cantidad <= 0 ||
          cantidad != cantidad.roundToDouble() ||
          cantidad > 2147483647) {
        throw FormatException(
          'Fila ${r + 1}: revisa OP, cliente y cantidad entera positiva. Solo se rellenan cantidades de celdas combinadas.',
        );
      }
      if (!ops.add(op)) {
        throw FormatException(
          'Fila ${r + 1}: OP $op repetida. Debe haber una fila por OP.',
        );
      }
      String? fecha(String col) {
        final v = valor(col), t = '${v ?? ''}'.trim();
        if (t.isEmpty || t == '-') return null;
        DateTime? d;
        if (v is DateCellValue) d = v.asDateTimeLocal();
        if (v is DateTimeCellValue) d = v.asDateTimeLocal();
        final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(t);
        if (d == null && m != null) {
          d = DateTime.utc(
            int.parse(m[3]!),
            int.parse(m[2]!),
            int.parse(m[1]!),
          );
          if (d.day != int.parse(m[1]!) || d.month != int.parse(m[2]!)) {
            d = null;
          }
        } else if (d == null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(t)) {
          d = DateTime.tryParse(t);
          if (d != null && fechaCiclo(d) != t) d = null;
        }
        if (d == null || d.year < 1900 || d.year > 2200) {
          throw FormatException(
            'Fila ${r + 1}, $col: fecha inválida. Usa una fecha Excel o DD/MM/AAAA; vacío o - para borrar.',
          );
        }
        return fechaCiclo(d);
      }

      final inicio = fecha('FECHA DE INICIO'), fines = <String, String?>{};
      String? anterior = inicio;
      for (final p in ProcesoCiclo.values) {
        final f = fecha(normalizar(p.titulo));
        if (f != null && anterior != null && f.compareTo(anterior) < 0) {
          throw FormatException(
            'Fila ${r + 1}: ${p.titulo} termina antes del hito anterior.',
          );
        }
        fines[p.name] = f;
        anterior = f ?? anterior;
      }
      result.add({
        'op': op,
        'cliente': cliente,
        'cantidad': cantidad.toInt(),
        'inicio': inicio,
        'fines': fines,
      });
      if (result.length > 10000) {
        throw const FormatException('Máximo 10.000 OP por archivo.');
      }
    }
    if (result.isEmpty) {
      throw const FormatException('El archivo no contiene órdenes.');
    }
    return result;
  }
}
