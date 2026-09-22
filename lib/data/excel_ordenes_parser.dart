import 'dart:typed_data';

import 'package:excel/excel.dart';

/// Fila ya interpretada de la hoja "Orden" (una por Orden de Producción).
typedef FilaOrden = Map<String, String?>;

/// Fila ya interpretada de la hoja "Tallas" (una por OP + código + talla).
typedef FilaTalla = Map<String, String?>;

class ExcelOrdenesParseException implements Exception {
  ExcelOrdenesParseException(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

class ExcelOrdenesParseado {
  const ExcelOrdenesParseado({required this.ordenes, required this.tallas});
  final List<FilaOrden> ordenes;
  final List<FilaTalla> tallas;
}

/// Nombres de columna esperados en cada hoja -> clave interna que usa el RPC.
/// Se busca por nombre de encabezado (no por posición), para tolerar que el
/// Excel del ERP cambie el orden de las columnas entre exportaciones.
/// Nombres de columna esperados en cada hoja -> clave interna que usa el RPC.
/// Se busca por nombre de encabezado normalizado (sin tildes, sin distinguir
/// mayúsculas/minúsculas), no por posición, para tolerar que el Excel del ERP
/// cambie el orden o la escritura exacta de las columnas entre exportaciones
/// (ej. "OBSERVACION" en un archivo, "Observación" en otro).
String _normalizarEncabezado(String s) {
  var r = s.trim().toUpperCase();
  const conTilde = 'ÁÉÍÓÚÑ';
  const sinTilde = 'AEIOUN';
  for (var i = 0; i < conTilde.length; i++) {
    r = r.replaceAll(conTilde[i], sinTilde[i]);
  }
  return r;
}

final _columnasOrden = <String, String>{
  for (final e in {
    'Identificador': 'identificador',
    'Tipo de orden': 'tipo_orden',
    'Estado': 'estado',
    'Fecha solicitud': 'fecha_solicitud',
    'Fecha inicio': 'fecha_inicio',
    'Fecha comprometida': 'fecha_comprometida',
    'Fecha acordada': 'fecha_acordada',
    'Fecha entrega': 'fecha_entrega',
    'Fecha planeación': 'fecha_planeacion',
    'Nombre ficha técnica': 'nombre_ficha_tecnica',
    'Cliente': 'cliente',
    'No. OC': 'oc_cabecera',
    'Nombre prenda': 'nombre_prenda_resumen',
    'Cantidad': 'cantidad_total_erp',
    'Observaciones': 'observaciones',
    'Movimiento': 'etapa_movimiento',
    'Fecha inicio movimiento': 'fecha_inicio_movimiento',
    'Fecha planeada': 'fecha_planeada_movimiento',
    'Estado movimientos': 'estado_movimiento_erp',
    'Id. OC': 'oc_id_erp',
  }.entries)
    _normalizarEncabezado(e.key): e.value,
};

final _columnasTallas = <String, String>{
  for (final e in {
    'Identificador orden': 'identificador_orden',
    'CLIENTE': 'cliente',
    'Código': 'codigo',
    'Descripción': 'descripcion',
    'Tallas nombre': 'talla',
    'Cantidad': 'cantidad',
    'NO. OC': 'oc',
    'OC ID': 'oc_id_erp',
    'OBSERVACION': 'observacion',
    'Observación': 'observacion',
  }.entries)
    _normalizarEncabezado(e.key): e.value,
};

/// Lee el archivo (bytes de un .xlsx) y devuelve las filas de ambas hojas ya
/// mapeadas a claves consistentes. Lanza [ExcelOrdenesParseException] con un
/// mensaje entendible si el archivo no tiene el formato esperado.
class ExcelOrdenesParser {
  static ExcelOrdenesParseado parsear(Uint8List bytes) {
    late final Excel libro;
    try {
      libro = Excel.decodeBytes(bytes);
    } catch (_) {
      throw ExcelOrdenesParseException(
        'No se pudo leer el archivo. Verifica que sea un .xlsx válido '
        '(si el original es .xls, ábrelo en Excel y usa "Guardar como" → .xlsx).',
      );
    }

    final nombreHojaOrden = _buscarHoja(libro, 'Orden');
    final nombreHojaTallas = _buscarHoja(libro, 'Tallas');
    if (nombreHojaOrden == null || nombreHojaTallas == null) {
      throw ExcelOrdenesParseException(
        'El archivo debe tener las hojas "Orden" y "Tallas". '
        'Hojas encontradas: ${libro.tables.keys.join(", ")}',
      );
    }

    final ordenes = _leerHoja(
      libro.tables[nombreHojaOrden]!,
      _columnasOrden,
      requeridas: const ['identificador'],
      nombreHoja: 'Orden',
    );
    final tallas = _leerHoja(
      libro.tables[nombreHojaTallas]!,
      _columnasTallas,
      requeridas: const ['identificador_orden', 'codigo', 'talla', 'cantidad'],
      nombreHoja: 'Tallas',
    );

    if (ordenes.isEmpty) {
      throw ExcelOrdenesParseException('La hoja "Orden" no tiene filas de datos.');
    }

    return ExcelOrdenesParseado(ordenes: ordenes, tallas: tallas);
  }

  static String? _buscarHoja(Excel libro, String nombreAproximado) {
    for (final nombre in libro.tables.keys) {
      if (nombre.trim().toLowerCase() == nombreAproximado.toLowerCase()) return nombre;
    }
    return null;
  }

  static List<Map<String, String?>> _leerHoja(
    Sheet hoja,
    Map<String, String> columnas, {
    required List<String> requeridas,
    required String nombreHoja,
  }) {
    if (hoja.maxRows == 0) return const [];

    final encabezados = hoja.rows.first;
    final indicePorClave = <String, int>{};
    final encabezadosLeidos = <String>[];
    for (var i = 0; i < encabezados.length; i++) {
      final texto = _texto(encabezados[i]?.value)?.trim();
      if (texto == null || texto.isEmpty) continue;
      encabezadosLeidos.add(texto);
      final clave = columnas[_normalizarEncabezado(texto)];
      if (clave != null) indicePorClave[clave] = i;
    }

    final faltantes = requeridas.where((r) => !indicePorClave.containsKey(r)).toList();
    if (faltantes.isNotEmpty) {
      throw ExcelOrdenesParseException(
        'No se reconocieron algunas columnas requeridas en la hoja "$nombreHoja" '
        '(${faltantes.join(", ")}). Encabezados encontrados: ${encabezadosLeidos.join(", ")}',
      );
    }

    final filas = <Map<String, String?>>[];
    for (var f = 1; f < hoja.rows.length; f++) {
      final fila = hoja.rows[f];
      // Saltar filas completamente vacías.
      final vacia = fila.every((c) => _texto(c?.value)?.trim().isEmpty ?? true);
      if (vacia) continue;

      final mapa = <String, String?>{};
      for (final entrada in indicePorClave.entries) {
        final idx = entrada.value;
        final celda = idx < fila.length ? fila[idx]?.value : null;
        mapa[entrada.key] = _valorParaColumna(entrada.key, celda);
      }
      filas.add(mapa);
    }
    return filas;
  }

  /// Fechas se devuelven como texto ISO (yyyy-MM-dd) para que Postgres las
  /// pueda castear directo con `::date`. El resto de columnas, como texto.
  static String? _valorParaColumna(String clave, CellValue? valor) {
    if (clave.startsWith('fecha')) return _fechaIso(valor);
    return _texto(valor)?.trim();
  }

  static String? _texto(CellValue? valor) {
    if (valor == null) return null;
    try {
      return switch (valor) {
        TextCellValue v => v.value.toString(),
        IntCellValue v => v.value.toString(),
        // Un código como 202674809 puede venir como celda numérica (no texto).
        // Si es un número entero, se muestra sin decimales ("202674809", no
        // "202674809.0"), para que coincida con el mismo código tal como
        // viene en el QR.
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

  static String? _fechaIso(CellValue? valor) {
    if (valor == null) return null;
    try {
      DateTime? dt;
      if (valor is DateCellValue) {
        dt = DateTime(valor.year, valor.month, valor.day);
      } else if (valor is DateTimeCellValue) {
        dt = DateTime(valor.year, valor.month, valor.day, valor.hour, valor.minute, valor.second);
      }
      if (dt != null) {
        final y = dt.year.toString().padLeft(4, '0');
        final m = dt.month.toString().padLeft(2, '0');
        final d = dt.day.toString().padLeft(2, '0');
        return '$y-$m-$d';
      }
    } catch (_) {
      // sigue abajo e intenta interpretar como texto
    }
    // Último recurso: si viene como texto tipo "2026-07-08 00:00:00".
    final texto = _texto(valor)?.trim();
    if (texto == null || texto.isEmpty) return null;
    final parseada = DateTime.tryParse(texto);
    if (parseada == null) return null;
    final y = parseada.year.toString().padLeft(4, '0');
    final m = parseada.month.toString().padLeft(2, '0');
    final d = parseada.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
