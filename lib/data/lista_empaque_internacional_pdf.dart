import 'dart:math' as math;
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'lista_empaque_internacional_plantilla.dart';

/// Reproduce B2:P42 de FMT-GL-005. Solo crece el cuerpo para las prendas;
/// los bloques combinados del encabezado y del pie conservan su geometría.
Future<Uint8List> crearListaEmpaqueInternacionalPdf(
  Map<String, dynamic> d, {
  required Uint8List logo,
  required ByteData fuenteRegular,
  required ByteData fuenteNegrita,
}) async {
  final pdf = pw.Document();
  final font = PdfTtfFont(pdf.document, fuenteRegular);
  final destino = Map<String, dynamic>.from(d['destinatario'] as Map);
  String s(dynamic v) => v?.toString() ?? '';
  double n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  String f(dynamic v) => n(
    v,
  ).toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '').replaceAll('.', ',');
  final detalle = {
    for (final x in d['detalle'] as List) s(x['item_id']): x as Map,
  };
  final grupos = <int, List<Map>>{};
  for (final x in d['empaques'] as List) {
    final e = x as Map;
    grupos.putIfAbsent((e['numero'] as num).toInt(), () => []).add(e);
  }
  if (grupos.isEmpty) throw const FormatException('La lista no tiene prendas');
  final numeros = grupos.keys.toList()..sort();
  final piezas = numeros.map((k) => grupos[k]!.first).toList();
  double volumen(Map e) =>
      n(e['alto_cm']) * n(e['largo_cm']) * n(e['ancho_cm']) / 1000000;
  // Mismo orden de columnas que la LE nacional, dentro de los 560 puntos del formato.
  const widths = [
    31.0,
    55.0,
    165.0,
    54.0,
    39.0,
    33.0,
    45.0,
    19.0,
    19.0,
    19.0,
    23.0,
    21.0,
    37.0,
  ];
  final xs = <double>[0];
  for (final w in widths) {
    xs.add(xs.last + w);
  }
  String tipoEmpaque(Map e) {
    final categoria = s(e['categoria']).trim().toUpperCase();
    return ['BOLSA', 'EMPAQUE', 'PAQUETE'].contains(categoria)
        ? 'Paquete'
        : categoria == 'CAJA'
        ? 'Caja'
        : s(e['categoria']);
  }

  final bodyY = n(plantillaInternacional['bodyY']);
  final footerY = n(plantillaInternacional['footerY']);
  final rowHeight = n(plantillaInternacional['rowHeight']);
  const bodySize = 6.5;
  String envolver(String value, double ancho) {
    final out = <String>[];
    for (final parrafo in value.split('\n')) {
      var line = '';
      for (final word in parrafo.split(' ')) {
        final next = line.isEmpty ? word : '$line $word';
        if (font.stringMetrics(next).width * bodySize <= ancho) {
          line = next;
          continue;
        }
        if (line.isNotEmpty) {
          out.add(line);
          line = '';
        }
        for (final rune in word.runes) {
          final ch = String.fromCharCode(rune);
          if (line.isNotEmpty &&
              font.stringMetrics(line + ch).width * bodySize > ancho) {
            out.add(line);
            line = '';
          }
          line += ch;
        }
      }
      out.add(line);
    }
    return out.join('\n');
  }

  final filas =
      <({int numero, List<String> values, double h, double cantidad})>[];
  for (final numero in numeros) {
    for (final e in grupos[numero]!) {
      final item = detalle[s(e['item_id'])];
      if (item == null) {
        throw const FormatException('Falta el detalle histórico de una prenda');
      }
      final values = [
        '$numero',
        s(item['op']),
        s(item['producto']),
        tipoEmpaque(e),
        s(item['talla']),
        f(e['cantidad']),
      ];
      var h = rowHeight;
      for (var i = 0; i < 6; i++) {
        values[i] = envolver(values[i], widths[i] - 4);
        h = math.max(h, values[i].split('\n').length * 7.4 + 3);
      }
      filas.add((
        numero: numero,
        values: values,
        h: h,
        cantidad: n(e['cantidad']),
      ));
    }
  }
  final paginas =
      <List<({int numero, List<String> values, double h, double cantidad})>>[];
  var pagina =
      <({int numero, List<String> values, double h, double cantidad})>[];
  var usado = 0.0;
  const maxCuerpo = 245.0;
  for (final numero in numeros) {
    final bloque = filas.where((r) => r.numero == numero).toList();
    final h = bloque.fold<double>(0, (a, r) => a + r.h);
    if (pagina.isNotEmpty && usado + h > maxCuerpo) {
      paginas.add(pagina);
      pagina = [];
      usado = 0;
    }
    for (final r in bloque) {
      if (pagina.isNotEmpty && usado + r.h > maxCuerpo) {
        paginas.add(pagina);
        pagina = [];
        usado = 0;
      }
      pagina.add(r);
      usado += r.h;
    }
  }
  if (pagina.isNotEmpty) {
    paginas.add(pagina);
  }
  final fecha = DateTime.parse(
    s(d['fecha']),
  ).toUtc().subtract(const Duration(hours: 5));
  final fechaTexto =
      '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  for (var index = 0; index < paginas.length; index++) {
    final rows = paginas[index];
    final ultima = index == paginas.length - 1;
    final cuerpo = math.max(
      footerY - bodyY,
      rows.fold<double>(0, (a, r) => a + r.h),
    );
    final desplazamiento = cuerpo - (footerY - bodyY);
    final values = <String, String>{
      'L4': 'Página ${index + 1} de ${paginas.length}',
      'C6': fechaTexto,
      'O6': s(d['numero']),
      'F8': s(destino['nombre']),
      'F10': s(destino['nit']),
      'F11': s(destino['contacto']),
      'F12': s(destino['direccion']),
      'F13': s(destino['ciudad']),
      'F14': s(destino['telefono']),
      'F15': s(destino['celular']),
      'F16': s(destino['email']),
      'O8': s(destino['termino_negociacion']),
      'O9': s(destino['via']),
      'O10': s(destino['tipo_carga']),
      'O11': s(destino['embalaje']),
      'O13': s(destino['puerto_embarque']),
      'O14': s(destino['pais_origen']),
      'O16': s(destino['puerto_destino']),
      'O17': s(destino['pais_destino']),
      'B20': s(d['factura']),
      'D20': s(d['remision']),
      'E20': s(d['oc']),
      'J20': s(d['numero']),
      'M20': detalle.values.map((e) => s(e['op'])).toSet().join(', '),
      'H31': f(rows.fold<double>(0, (a, r) => a + r.cantidad)),
      'H32': ultima ? f(filas.fold<double>(0, (a, r) => a + r.cantidad)) : '',
      'B32': ultima ? 'TOTAL / TOTAL:' : 'CONTINÚA EN LA SIGUIENTE PÁGINA',
      'G34':
          ultima
              ? '${f(piezas.fold<double>(0, (a, e) => a + n(e['peso_neto_kg'])))} Kg'
              : '',
      'G35':
          ultima
              ? '${f(piezas.fold<double>(0, (a, e) => a + n(e['peso_bruto_kg'])))} Kg'
              : '',
      'O34': ultima ? f(piezas.fold<double>(0, (a, e) => a + volumen(e))) : '',
      'O35':
          ultima
              ? '${piezas.where((e) => e['categoria'] == 'CAJA').length}'
              : '',
      'D37': s(d['codigo_postal']),
      'D38': s(d['sello_precinto']),
      'G41': ultima ? s(d['actor']) : '',
    };
    final widgets = <pw.Widget>[];
    void cell(
      double x,
      double y,
      double w,
      double h,
      String text, {
      double size = bodySize,
      bool bold = false,
      PdfColor? fill,
      PdfColor color = PdfColors.black,
      List<bool> borders = const [true, true, true, true],
      String align = 'center',
    }) {
      pw.BorderSide side(bool on) =>
          on ? const pw.BorderSide(width: .4) : pw.BorderSide.none;
      widgets.add(
        pw.Positioned(
          left: x,
          top: y,
          child: pw.Container(
            width: w,
            height: h,
            decoration: pw.BoxDecoration(
              color: fill,
              border: pw.Border(
                left: side(borders[0]),
                top: side(borders[1]),
                right: side(borders[2]),
                bottom: side(borders[3]),
              ),
            ),
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 1.5,
              vertical: 1,
            ),
            alignment:
                align == 'left'
                    ? pw.Alignment.centerLeft
                    : align == 'right'
                    ? pw.Alignment.centerRight
                    : pw.Alignment.center,
            child:
                text.trim().isEmpty
                    ? null
                    : pw.FittedBox(
                      fit: pw.BoxFit.scaleDown,
                      child: pw.SizedBox(
                        width: math.max(1, w - 3),
                        child: pw.Text(
                          text,
                          textAlign:
                              align == 'left'
                                  ? pw.TextAlign.left
                                  : align == 'right'
                                  ? pw.TextAlign.right
                                  : pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: size,
                            color: color,
                            fontWeight:
                                bold
                                    ? pw.FontWeight.bold
                                    : pw.FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
          ),
        ),
      );
    }

    for (final raw in plantillaInternacional['cells'] as List) {
      final c = raw as Map;
      final y = n(c['y']);
      final fila = int.parse(s(c['id']).replaceAll(RegExp(r'[A-Z]'), ''));
      if ([22, 23, 31, 32, 34, 35].contains(fila)) continue;
      cell(
        n(c['x']),
        y + (y >= footerY - .01 ? desplazamiento : 0),
        n(c['w']),
        n(c['h']),
        values[c['id']] ?? s(c['text']),
        size: n(c['size']),
        bold: c['bold'] == true,
        color: PdfColor.fromHex(s(c['color'])),
        fill: c['fill'] == null ? null : PdfColor.fromHex(s(c['fill'])),
        borders: List<bool>.from(c['borders'] as List),
        align: s(c['align']),
      );
      if (c['id'] == 'B2') {
        widgets.add(
          pw.Positioned(
            left: n(c['x']) + 4,
            top: y + 3,
            child: pw.SizedBox(
              width: n(c['w']) - 8,
              height: n(c['h']) - 6,
              child: pw.Center(
                child: pw.Image(pw.MemoryImage(logo), fit: pw.BoxFit.contain),
              ),
            ),
          ),
        );
      }
    }
    // Cabecera de dos niveles, conservando medidas y pesos agrupados.
    const azul = PdfColor(0, .243, .314);
    final plantillaCeldas =
        (plantillaInternacional['cells'] as List).cast<Map>();
    final encabezadoY = n(
      plantillaCeldas.firstWhere((c) => c['id'] == 'B22')['y'],
    );
    final altoEncabezado = bodyY - encabezadoY;
    void titulo(double x, double yy, double w, double h, String t) => cell(
      x,
      yy,
      w,
      h,
      t,
      size: 4.2,
      bold: true,
      fill: azul,
      color: PdfColors.white,
    );
    final encabezados = [
      'N. CAJA',
      'OP',
      'DESCRIPCIÓN DEL PRODUCTO',
      'TIPO DE EMPAQUE',
      'TALLA',
      'CANTIDAD',
      'TOTAL UNDS. POR CAJA',
    ];
    for (var i = 0; i < encabezados.length; i++) {
      titulo(xs[i], encabezadoY, widths[i], altoEncabezado, encabezados[i]);
    }
    titulo(
      xs[7],
      encabezadoY,
      xs[10] - xs[7],
      altoEncabezado / 2,
      'MEDIDA CAJA (MT)',
    );
    titulo(
      xs[10],
      encabezadoY,
      xs[12] - xs[10],
      altoEncabezado / 2,
      'PESOS CAJA (Kg)',
    );
    for (var i = 7; i < 12; i++) {
      titulo(
        xs[i],
        encabezadoY + altoEncabezado / 2,
        widths[i],
        altoEncabezado / 2,
        ['ALTO', 'LARGO', 'ANCHO', 'NETO', 'BRUTO'][i - 7],
      );
    }
    titulo(xs[12], encabezadoY, widths[12], altoEncabezado, 'VOLUMEN');
    final totalFila = plantillaCeldas.firstWhere((c) => c['id'] == 'E31');
    final totalGeneral = plantillaCeldas.firstWhere((c) => c['id'] == 'B32');
    final totalY = n(totalFila['y']) + desplazamiento;
    final totalH = n(totalFila['h']);
    cell(0, totalY, xs[3], totalH, '');
    cell(
      xs[3],
      totalY,
      xs[5] - xs[3],
      totalH,
      'TOTAL UNIDADES',
      size: 5,
      bold: true,
      fill: const PdfColor(.765, .835, 0),
    );
    cell(xs[5], totalY, widths[5], totalH, values['H31']!, size: 5.5);
    cell(xs[6], totalY, 560 - xs[6], totalH, '');
    final generalY = n(totalGeneral['y']) + desplazamiento;
    final generalH = n(totalGeneral['h']);
    cell(
      0,
      generalY,
      xs[5],
      generalH,
      values['B32']!,
      size: 5.5,
      bold: true,
      fill: azul,
      color: PdfColors.white,
      align: 'right',
    );
    cell(
      xs[5],
      generalY,
      widths[5],
      generalH,
      values['H32']!,
      size: 5.5,
      bold: true,
    );
    cell(xs[6], generalY, 560 - xs[6], generalH, '', fill: azul);
    // Resumen de tres filas: pesos/volumen y conteo de piezas físicas.
    final celdas = (plantillaInternacional['cells'] as List).cast<Map>();
    final primera = celdas.firstWhere((c) => c['id'] == 'B34');
    final segunda = celdas.firstWhere((c) => c['id'] == 'B35');
    final resumenY = n(primera['y']) + desplazamiento;
    final altoFila = (n(segunda['y']) + n(segunda['h']) - n(primera['y'])) / 3;
    final cajas = piezas.where((e) => e['categoria'] == 'CAJA').length;
    final resumen = [
      [
        'Peso Neto Total (Kg)',
        values['G34']!,
        'Total de piezas',
        ultima ? '${piezas.length}' : '',
      ],
      [
        'Peso Bruto Total (Kg)',
        values['G35']!,
        'N° de cajas',
        ultima ? '$cajas' : '',
      ],
      [
        'Volumen Total (m³)',
        values['O34']!,
        'N° de empaques',
        ultima ? '${piezas.length - cajas}' : '',
      ],
    ];
    const resumenX = [0.0, 299.0, 339.0, 520.0, 560.0];
    for (var r = 0; r < resumen.length; r++) {
      for (var c = 0; c < 4; c++) {
        final titulo = c.isEven;
        cell(
          resumenX[c],
          resumenY + r * altoFila,
          resumenX[c + 1] - resumenX[c],
          altoFila,
          resumen[r][c],
          size: 5.5,
          bold: titulo,
          fill: titulo ? const PdfColor(0, .243, .314) : null,
          color: titulo ? PdfColors.white : PdfColors.black,
        );
      }
    }
    var y = bodyY;
    for (final numero in rows.map((r) => r.numero).toSet()) {
      final block = rows.where((r) => r.numero == numero).toList();
      final start = y;
      for (final r in block) {
        for (var i = 0; i < 6; i++) {
          cell(xs[i], y, widths[i], r.h, r.values[i]);
        }
        y += r.h;
      }
      final e = grupos[numero]!.first;
      final summary = [
        f(grupos[numero]!.fold<double>(0, (a, e) => a + n(e['cantidad']))),
        f(n(e['alto_cm']) / 100),
        f(n(e['largo_cm']) / 100),
        f(n(e['ancho_cm']) / 100),
        f(e['peso_neto_kg']),
        f(e['peso_bruto_kg']),
        f(volumen(e)),
      ];
      for (var i = 6; i < 13; i++) {
        cell(xs[i], start, widths[i], y - start, summary[i - 6]);
      }
    }
    final falta = bodyY + cuerpo - y;
    if (falta > .01) {
      for (var i = 0; i < widths.length; i++) {
        cell(xs[i], y, widths[i], falta, '');
      }
    }
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.fromLTRB(24, 37, 28, 31),
        theme: pw.ThemeData.withFont(
          base: pw.Font.ttf(fuenteRegular),
          bold: pw.Font.ttf(fuenteNegrita),
        ),
        build:
            (_) => pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              alignment: pw.Alignment.topLeft,
              child: pw.SizedBox(
                width: 560,
                height: n(plantillaInternacional['height']) + desplazamiento,
                child: pw.Stack(children: widgets),
              ),
            ),
      ),
    );
  }
  return pdf.save();
}
