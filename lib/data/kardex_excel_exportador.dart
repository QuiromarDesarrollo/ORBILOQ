import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import '../application/kardex_columnas.dart';
import '../domain/models.dart';
import '../features/kardex/presentation/kardex_table.dart';

/// Exporta el kardex a un .xlsx con exactamente las mismas columnas, en el
/// mismo orden y con los mismos valores que se ven en la tabla — reutiliza
/// las listas de encabezados/columnas de `kardex_table.dart` y los mismos
/// extractores de valor de `kardex_columnas.dart` (los que ya usa el filtro
/// por columna), así nunca se puede desincronizar de lo que se ve en pantalla.
///
/// Siempre exporta TODO el histórico de esa vista, sin importar los filtros
/// que estén activos en ese momento en la tabla.
class KardexExcelExportador {
  const KardexExcelExportador._();

  static Future<void> exportarProduccion(List<ItemKardex> todosLosItems) => _exportar(
        items: todosLosItems,
        etiquetas: kEtiquetasProduccion,
        columnas: kColumnasProduccion,
        extractores: columnasProduccion,
        nombreBase: 'orbiloq_produccion',
      );

  static Future<void> exportarBodega(List<ItemKardex> todosLosItems) => _exportar(
        items: todosLosItems,
        etiquetas: kEtiquetasBodega,
        columnas: kColumnasBodega,
        extractores: columnasBodega,
        nombreBase: 'orbiloq_bodega',
      );

  static Future<void> _exportar({
    required List<ItemKardex> items,
    required List<String> etiquetas,
    required List<String?> columnas,
    required Map<String, ExtractorColumna> extractores,
    required String nombreBase,
  }) async {
    final libro = Excel.createExcel();
    final nombreHoja = libro.getDefaultSheet()!;
    final hoja = libro[nombreHoja];

    for (var c = 0; c < etiquetas.length; c++) {
      hoja.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).value = TextCellValue(etiquetas[c]);
    }

    for (var f = 0; f < items.length; f++) {
      final item = items[f];
      for (var c = 0; c < columnas.length; c++) {
        final columna = columnas[c];
        final valor = columna == null ? '' : (extractores[columna]?.call(item) ?? '');
        hoja.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: f + 1)).value = TextCellValue(valor);
      }
    }

    final bytes = libro.save();
    if (bytes == null) {
      throw Exception('No se pudo generar el archivo de Excel.');
    }

    final hoy = DateTime.now();
    final sufijo =
        '${hoy.year}${hoy.month.toString().padLeft(2, '0')}${hoy.day.toString().padLeft(2, '0')}';

    await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar histórico',
      fileName: '${nombreBase}_$sufijo.xlsx',
      bytes: Uint8List.fromList(bytes),
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
  }
}
