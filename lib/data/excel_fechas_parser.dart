import 'dart:typed_data';

import 'package:excel/excel.dart';

/// Fila ya interpretada del Excel de fechas esperadas (una por OP).
typedef FilaFechaEsperada = Map<String, String?>;

class ExcelFechasParseException implements Exception {
  ExcelFechasParseException(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

String _normalizarEncabezado(String s) {
  var r = s.trim().toUpperCase();
  const conTilde = 'ÁÉÍÓÚÑ';
  const sinTilde = 'AEIOUN';
  for (var i = 0; i < conTilde.length; i++) {
    r = r.replaceAll(conTilde[i], sinTilde[i]);
  }
  return r;
}

/// Nombres de columna esperados -> clave interna. Se acepta más de una
/// variante de escritura para cada una (el Excel del ERP puede cambiar
/// ligeramente el texto exacto entre exportaciones).
final _columnas = <String, String>{
  for (final e in {
    'N° DE ORDEN': 'numero_op',
    'NO. DE ORDEN': 'numero_op',
    'NUMERO DE ORDEN': 'numero_op',
    'ORDEN': 'numero_op',
    'IDENTIFICADOR': 'numero_op',
    'FECHA PROD': 'fecha_esperada_produccion',
    'FECHA PRODUCCION': 'fecha_esperada_produccion',
    'FECHA LOG': 'fecha_esperada_logistica',
    'FECHA LOGISTICA': 'fecha_esperada_logistica',
  }.entries)
    _normalizarEncabezado(e.key): e.value,
};

/// Lee el Excel de fechas esperadas (columnas: N° DE ORDEN, FECHA PROD,
/// FECHA LOG) y devuelve una fila por OP con sus fechas ya en texto ISO.
class ExcelFechasParser {
  static List<FilaFechaEsperada> parsear(Uint8List bytes) {
    late final Excel libro;
    try {
      libro = Excel.decodeBytes(bytes);
    } catch (_) {
      throw ExcelFechasParseException(
        'No se pudo leer el archivo. Verifica que sea un .xlsx válido '
        '(si el original es .xls, ábrelo en Excel y usa "Guardar como" → .xlsx).',
      );
    }

    if (libro.tables.isEmpty) {
      throw ExcelFechasParseException('El archivo no tiene hojas.');
    }
    final hoja = libro.tables.values.first;
    if (hoja.maxRows == 0) {
      throw ExcelFechasParseException('La hoja está vacía.');
    }

    final encabezados = hoja.rows.first;
    final indicePorClave = <String, int>{};
    final encabezadosLeidos = <String>[];
    for (var i = 0; i < encabezados.length; i++) {
      final texto = _texto(encabezados[i]?.value)?.trim();
      if (texto == null || texto.isEmpty) continue;
      encabezadosLeidos.add(texto);
      final clave = _columnas[_normalizarEncabezado(texto)];
      if (clave != null) indicePorClave[clave] = i;
    }

    if (!indicePorClave.containsKey('numero_op')) {
      throw ExcelFechasParseException(
        'No se encontró la columna "N° DE ORDEN". Encabezados encontrados: ${encabezadosLeidos.join(", ")}',
      );
    }
    if (!indicePorClave.containsKey('fecha_esperada_produccion') &&
        !indicePorClave.containsKey('fecha_esperada_logistica')) {
      throw ExcelFechasParseException(
        'No se encontró ninguna columna de fecha ("FECHA PROD" o "FECHA LOG"). '
        'Encabezados encontrados: ${encabezadosLeidos.join(", ")}',
      );
    }

    final filas = <FilaFechaEsperada>[];
    for (var f = 1; f < hoja.rows.length; f++) {
      final fila = hoja.rows[f];
      final vacia = fila.every((c) => _texto(c?.value)?.trim().isEmpty ?? true);
      if (vacia) continue;

      final mapa = <String, String?>{};
      for (final entrada in indicePorClave.entries) {
        final idx = entrada.value;
        final celda = idx < fila.length ? fila[idx]?.value : null;
        mapa[entrada.key] = entrada.key == 'numero_op' ? _texto(celda)?.trim() : _fechaIso(celda);
      }

      if ((mapa['numero_op'] ?? '').isEmpty) continue; // fila sin OP: se ignora
      filas.add(mapa);
    }

    if (filas.isEmpty) {
      throw ExcelFechasParseException('No se encontraron filas con datos válidos.');
    }
    return filas;
  }

  static String? _texto(CellValue? valor) {
    if (valor == null) return null;
    try {
      return switch (valor) {
        TextCellValue v => v.value.toString(),
        IntCellValue v => v.value.toString(),
        DoubleCellValue v => _formatearNumero(v.value),
        BoolCellValue v => v.value.toString(),
        _ => valor.toString(),
      };
    } catch (_) {
      return valor.toString();
    }
  }

  static String _formatearNumero(double d) {
    if (d.isFinite && d == d.roundToDouble() && d.abs() < 1e15) {
      return d.toStringAsFixed(0);
    }
    return d.toString();
  }

  /// Fechas se devuelven como texto ISO (yyyy-MM-dd) para que Postgres las
  /// pueda castear directo con `::date`.
  static String? _fechaIso(CellValue? valor) {
    if (valor == null) return null;
    try {
      DateTime? dt;
      if (valor is DateCellValue) {
        dt = DateTime(valor.year, valor.month, valor.day);
      } else if (valor is DateTimeCellValue) {
        dt = DateTime(valor.year, valor.month, valor.day, valor.hour, valor.minute, valor.second);
      }
      if (dt != null) return _formatoIso(dt);
    } catch (_) {
      // sigue abajo e intenta interpretar como texto
    }

    final texto = _texto(valor)?.trim();
    if (texto == null || texto.isEmpty) return null;

    // Por si la columna vino como texto plano en formato M/D/AAAA (como se
    // ve en el Excel de origen) en vez de una celda de fecha real.
    final partesSlash = texto.split('/');
    if (partesSlash.length == 3) {
      final mes = int.tryParse(partesSlash[0]);
      final dia = int.tryParse(partesSlash[1]);
      final anio = int.tryParse(partesSlash[2]);
      if (mes != null && dia != null && anio != null) {
        try {
          return _formatoIso(DateTime(anio, mes, dia));
        } catch (_) {
          // formato raro, sigue con el intento genérico de abajo
        }
      }
    }

    final parseada = DateTime.tryParse(texto);
    if (parseada == null) return null;
    return _formatoIso(parseada);
  }

  static String _formatoIso(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
