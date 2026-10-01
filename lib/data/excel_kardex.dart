import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../domain/models.dart';

class ArchivoKardex {
  const ArchivoKardex(this.vista, this.version, this.filas);
  final Rol vista;
  final String version;
  final List<Map<String, dynamic>> filas;
}

/// Formato de ida y vuelta: claves estables, números reales y fechas completas.
class ExcelKardex {
  static Map<String, String> columnas(Rol vista) => {
        'item_orden_id': 'ID FILA (no modificar)',
        'numero_op': 'OP',
        'descripcion': 'PRODUCTO',
        'codigo': 'CÓDIGO',
        'talla': 'TALLA',
        'cliente': 'CLIENTE',
        'oc': 'OC',
        'observacion_op': 'OBSERVACIÓN',
        'cantidad_pedida': 'CANTIDAD',
        'producido': 'ENTREGADO POR PRODUCCIÓN',
        'pendiente': 'PENDIENTE (calculado)',
        if (vista == Rol.logistica) ...{
          'recibido': 'RECIBIDO EN BODEGA',
          'despachado': 'DESPACHADO'
        },
        'pendiente_reproceso': 'PRODUCTO NO CONFORME',
        'estado': 'ESTADO (calculado)',
        'fecha_ultima_entrega': 'FECHA DE ENTREGA',
        if (vista == Rol.produccion)
          'fecha_esperada_produccion': 'FECHA ESPERADA',
        if (vista == Rol.logistica)
          'fecha_esperada_logistica': 'FECHA ESPERADA',
        'dias': 'DÍAS FALTANTES (calculado)',
        'ubicacion_ajuste': 'UBICACIÓN DEL AJUSTE',
      };
  static const calculadas = {'pendiente', 'estado', 'dias'};
  static const numericas = {
    'cantidad_pedida',
    'producido',
    'recibido',
    'despachado',
    'pendiente_reproceso'
  };

  static Uint8List generar(ArchivoKardex archivo) {
    final libro = Excel.createExcel();
    final hoja = libro['Kardex'];
    libro.delete('Sheet1');
    libro.setDefaultSheet('Kardex');
    final cols = columnas(archivo.vista);
    hoja.appendRow(cols.values.map(TextCellValue.new).toList());
    for (final fila in archivo.filas) {
      hoja.appendRow(cols.keys.map<CellValue>((key) {
        final v = fila[key];
        return v is int ? IntCellValue(v) : TextCellValue(v?.toString() ?? '');
      }).toList());
    }
    for (var c = 0; c < cols.length; c++) {
      hoja.setColumnWidth(c, c == 0 ? 40 : 24);
      hoja
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .cellStyle = CellStyle(bold: true);
    }
    final formato = libro['Formato'];
    formato.appendRow([
      TextCellValue('ORBILOQ_KARDEX_V1'),
      TextCellValue(archivo.vista.name),
      TextCellValue(archivo.version)
    ]);
    for (final texto in [
      'Exportación completa de filas activas, sin filtros ni paginación.',
      'Edita la hoja Kardex. Conserva ID FILA y la hoja Formato. Para una fila nueva deja ID vacío.',
      'Pendiente, estado y días faltantes son informativos: se recalculan al importar.',
      'Fechas: AAAA-MM-DD o una celda de fecha de Excel. Una fecha vacía se borra.',
      'Para corregir recibido, despachado o no conforme, indica el código del estante en UBICACIÓN DEL AJUSTE.',
      'La ubicación recibe la diferencia de stock, no todo el saldo. Los lotes históricos se conservan.',
      'La importación modifica ambas vistas. El servidor valida el archivo completo antes de confirmar.',
      'Si los datos del sistema cambiaron desde la exportación, exporta otra vez y revisa los cambios.',
    ]) {
      formato.appendRow([TextCellValue(texto)]);
    }
    formato.setColumnWidth(0, 110);
    return Uint8List.fromList(libro.save()!);
  }

  static ArchivoKardex leer(Uint8List bytes, Rol vista) {
    if (bytes.length > 20 * 1024 * 1024) {
      throw const FormatException('El archivo supera 20 MB.');
    }
    final libro = Excel.decodeBytes(bytes);
    final formato = libro.tables['Formato'];
    final hoja = libro.tables['Kardex'];
    String texto(Data? d) => d?.value?.toString().trim() ?? '';
    if (formato == null ||
        formato.rows.isEmpty ||
        hoja == null ||
        hoja.rows.isEmpty ||
        formato.rows.first.length < 3 ||
        texto(formato.rows.first[0]) != 'ORBILOQ_KARDEX_V1') {
      throw const FormatException(
          'Usa un Excel generado con Exportar tabla de esta versión.');
    }
    if (texto(formato.rows.first[1]) != vista.name) {
      throw const FormatException('El archivo pertenece a la otra vista.');
    }
    final version = texto(formato.rows.first[2]);
    if (version.isEmpty) {
      throw const FormatException('Falta la versión del archivo.');
    }
    final cols = columnas(vista);
    final headers = hoja.rows.first.map(texto).toList();
    if (headers.toSet().length != headers.length ||
        cols.values.any((h) => !headers.contains(h))) {
      throw const FormatException(
          'Faltan columnas o hay encabezados duplicados. Conserva los encabezados de la exportación.');
    }
    final filas = <Map<String, dynamic>>[];
    final ids = <String>{};
    final claves = <String>{};
    for (var r = 1; r < hoja.rows.length; r++) {
      final row = hoja.rows[r];
      if (row.every((d) => texto(d).isEmpty)) continue;
      if (filas.length >= 5000) {
        throw const FormatException(
            'Máximo 5000 filas por reemplazo. No dividas una tabla mayor: solicita ampliar el límite.');
      }
      final fila = <String, dynamic>{};
      for (final e in cols.entries) {
        if (calculadas.contains(e.key)) continue;
        final c = headers.indexOf(e.value);
        final data = c < row.length ? row[c] : null;
        final value = data?.value;
        final t = texto(data);
        if (value is FormulaCellValue) {
          throw FormatException(
              'Fila ${r + 1}, ${e.value}: usa valores, no fórmulas.');
        }
        if (numericas.contains(e.key)) {
          final n = num.tryParse(t);
          if (n == null ||
              !n.isFinite ||
              n < 0 ||
              n != n.roundToDouble() ||
              n > 2147483647) {
            throw FormatException(
                'Fila ${r + 1}, ${e.value}: escribe un entero no negativo.');
          }
          fila[e.key] = n.toInt();
        } else if (e.key.startsWith('fecha_')) {
          DateTime? fecha;
          if (value is DateCellValue) fecha = value.asDateTimeLocal();
          if (value is DateTimeCellValue) fecha = value.asDateTimeLocal();
          if (t.isNotEmpty && fecha == null) {
            if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(t)) {
              throw FormatException(
                  'Fila ${r + 1}: fecha inválida; usa AAAA-MM-DD.');
            }
            fecha = DateTime.tryParse(t);
            if (fecha == null || fecha.toIso8601String().substring(0, 10) != t) {
              throw FormatException('Fila ${r + 1}: fecha inexistente.');
            }
          }
          fila[e.key] = fecha?.toIso8601String().substring(0, 10);
        } else {
          fila[e.key] = t;
        }
      }
      for (final k in [
        'numero_op',
        'descripcion',
        'codigo',
        'talla',
        'cliente'
      ]) {
        if ((fila[k] as String).isEmpty) {
          throw FormatException('Fila ${r + 1}: ${cols[k]} es obligatorio.');
        }
      }
      final id = fila['item_orden_id'] as String;
      if (id.isNotEmpty && !ids.add(id)) {
        throw FormatException('Fila ${r + 1}: ID repetido.');
      }
      final clave =
          [fila['numero_op'], fila['codigo'], fila['talla']].join('\u0000');
      if (!claves.add(clave)) {
        throw FormatException('Fila ${r + 1}: OP/producto/talla duplicados.');
      }
      filas.add(fila);
    }
    if (filas.isEmpty) {
      throw const FormatException(
          'El archivo está vacío. No se reemplazará la tabla.');
    }
    return ArchivoKardex(vista, version, filas);
  }
}
