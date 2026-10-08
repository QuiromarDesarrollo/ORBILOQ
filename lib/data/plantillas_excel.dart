import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'excel_ciclos.dart';
import 'excel_ordenes_parser.dart';

enum PlantillaExcel { ordenes, fechas, ciclos, clientes }

/// Las hojas de captura están vacías para evitar importar ejemplos por error.
class PlantillasExcel {
  static Uint8List generar(PlantillaExcel tipo) {
    final hojas = switch (tipo) {
      PlantillaExcel.ordenes => {'Orden': ExcelOrdenesParser.encabezadosOrden, 'Tallas': ExcelOrdenesParser.encabezadosTallas},
      PlantillaExcel.fechas => {'Fechas': ['N° DE ORDEN', 'FECHA PROD', 'FECHA LOG']},
      PlantillaExcel.ciclos => {'Historicos': ExcelCiclos.columnas},
      PlantillaExcel.clientes => {'Clientes': ['CONSECUTIVO (opcional)', 'NOMBRE', 'NIT', 'QUIEN RECIBE', 'CIUDAD', 'DIRECCION', 'TELEFONO', 'CELULAR']},
    };
    final notas = switch (tipo) {
      PlantillaExcel.ordenes => [
        'Orden: una fila por OP. Identificador es el número de OP; completa Cliente y No. OC.',
        'Tallas: una fila por OP, código y talla. Identificador orden debe coincidir con Identificador de Orden.',
        'Completa Código, Descripción, Tallas nombre y Cantidad (entero positivo). Las OP existentes se omiten.',
      ],
      PlantillaExcel.fechas => [
        'Una fila por OP existente. N° DE ORDEN identifica la OP.',
        'FECHA PROD: fecha esperada de Producción. FECHA LOG: fecha esperada de Logística.',
        'Las fechas vacías se conservan sin actualización; consulta la revisión de importación.',
      ],
      PlantillaExcel.ciclos => [
        'Una fila por OP: N° DE ORDEN, CLIENTE y CANTIDAD entera positiva.',
        'FECHA DE INICIO corresponde al requerimiento. Cada proceso lleva su fecha de finalización completa.',
        'Deja vacíos los procesos sin finalizar. No ingreses duraciones ni fórmulas.',
      ],
      PlantillaExcel.clientes => [
        'Conserva la hoja Clientes y las posiciones B:H. La columna A es opcional y no se importa.',
        'Una fila por destinatario o sede. NOMBRE es obligatorio; completa los datos disponibles.',
        'Escribe NIT y teléfonos como texto para conservar ceros iniciales. No uses fórmulas.',
      ],
    };
    final libro = Excel.createExcel();
    for (final entrada in hojas.entries) {
      final hoja = libro[entrada.key];
      hoja.appendRow(entrada.value.map(TextCellValue.new).toList());
      for (var c = 0; c < entrada.value.length; c++) {
        hoja.setColumnWidth(c, 28);
        hoja.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).cellStyle = CellStyle(bold: true);
      }
    }
    libro.delete('Sheet1');
    libro.setDefaultSheet(hojas.keys.first);
    final guia = libro['Instrucciones'];
    for (final nota in ['Completa los datos desde la fila 2. No cambies nombres de hojas ni encabezados.',
      'Fechas: AAAA-MM-DD (por ejemplo 2026-10-07) o fecha de Excel. Guarda como .xlsx.', ...notas]) {
      guia.appendRow([TextCellValue(nota)]);
    }
    guia.setColumnWidth(0, 110);
    return Uint8List.fromList(libro.save()!);
  }
}
