import '../domain/destinatario_internacional.dart';
import 'lista_empaque_internacional_pdf.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// FMT-GL-002: geometría, colores y agrupación del FORMATO.pdf de la empresa.
Future<Uint8List> crearListaEmpaquePdf(
  Map<String, dynamic> d, {
  required Uint8List logo,
  required ByteData fuenteRegular,
  required ByteData fuenteNegrita,
}) async {
  if (esDestinatarioInternacional(d['destinatario'] as Map)) {
    return crearListaEmpaqueInternacionalPdf(
      d,
      logo: logo,
      fuenteRegular: fuenteRegular,
      fuenteNegrita: fuenteNegrita,
    );
  }
  final pdf = pw.Document();
  final font = PdfTtfFont(pdf.document, fuenteRegular);
  const azul = PdfColor(0, .243, .314);
  const celeste = PdfColor(.157, .553, .753);
  const azulDest = PdfColor(.122, .306, .471);
  const amarillo = PdfColor(.765, .835, 0);
  const gris = PdfColor(.851, .851, .851);
  const ancho = 554.0;
  final destino = Map<String, dynamic>.from(d['destinatario'] as Map);
  final detalle = {
    for (final x in d['detalle'] as List)
      '${x['item_id']}': Map<String, dynamic>.from(x as Map),
  };
  final grupos = <int, List<Map<String, dynamic>>>{};
  for (final x in d['empaques'] as List) {
    final e = Map<String, dynamic>.from(x as Map);
    grupos.putIfAbsent((e['numero'] as num).toInt(), () => []).add(e);
  }
  final numeros = grupos.keys.toList()..sort();
  double n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  String f(dynamic v, {int dec = 3}) => n(v)
      .toStringAsFixed(dec)
      .replaceFirst(RegExp(r'\.?0+$'), '')
      .replaceAll('.', ',');
  String s(dynamic v) => v?.toString() ?? '';
  double volumen(Map<String, dynamic> e) =>
      n(e['alto_cm']) * n(e['largo_cm']) * n(e['ancho_cm']) / 1000000;
  final unicos = numeros.map((i) => grupos[i]!.first).toList();
  String tipoEmpaque(Map<String, dynamic> e) {
    final categoria = s(e['categoria']).trim().toUpperCase();
    return categoria == 'BOLSA' ||
            categoria == 'EMPAQUE' ||
            categoria == 'PAQUETE'
        ? 'Paquete'
        : categoria == 'CAJA'
        ? 'Caja'
        : s(e['categoria']);
  }

  final cajas = unicos.where((e) => tipoEmpaque(e) == 'Caja').length;
  final empaques = unicos.where((e) => tipoEmpaque(e) == 'Paquete').length;
  final total = grupos.values
      .expand((e) => e)
      .fold<double>(0, (a, e) => a + n(e['cantidad']));
  final fecha = DateTime.parse(
    s(d['fecha']),
  ).toUtc().subtract(const Duration(hours: 5));
  const dias = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
  const meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  final fechaTexto =
      '${dias[fecha.weekday - 1]}, ${fecha.day} de ${meses[fecha.month - 1]} de ${fecha.year}';
  // Columnas en puntos: conservan las proporciones del formato de referencia.
  const widths = [
    31.0,
    55.0,
    159.0,
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
  String envolver(String text, double width, double size) {
    final lines = <String>[];
    for (final paragraph in text.split('\n')) {
      var line = '';
      for (final word in paragraph.split(' ')) {
        final next = line.isEmpty ? word : '$line $word';
        if (font.stringMetrics(next).width * size <= width) {
          line = next;
          continue;
        }
        if (line.isNotEmpty) {
          lines.add(line);
          line = '';
        }
        for (final rune in word.runes) {
          final ch = String.fromCharCode(rune);
          if (line.isNotEmpty &&
              font.stringMetrics(line + ch).width * size > width) {
            lines.add(line);
            line = '';
          }
          line += ch;
        }
      }
      lines.add(line);
    }
    return lines.join('\n');
  }

  final filas = <({int numero, List<String> c, double alto})>[];
  for (final numero in numeros) {
    for (final e in grupos[numero]!) {
      final item = detalle[s(e['item_id'])];
      if (item == null) {
        throw const FormatException('Falta el detalle histórico de una prenda');
      }
      final c = [
        s(numero),
        s(item['op']),
        s(item['producto']),
        tipoEmpaque(e),
        s(item['talla']),
        s(e['cantidad']),
      ];
      var alto = 10.2;
      for (var i = 0; i < c.length; i++) {
        c[i] = envolver(c[i], widths[i] - 3, 5.4);
        alto = math.max(alto, c[i].split('\n').length * 6.2 + 3);
      }
      filas.add((numero: numero, c: c, alto: alto));
    }
  }
  if (filas.isEmpty) throw const FormatException('La lista no tiene prendas');
  // Mantener cada caja junta siempre que quepa; dividir solo cajas muy extensas.
  final paginas = <List<({int numero, List<String> c, double alto})>>[];
  var pagina = <({int numero, List<String> c, double alto})>[];
  var usado = 0.0;
  const maxCuerpo = 430.0;
  for (final numero in numeros) {
    final bloque = filas.where((r) => r.numero == numero).toList();
    final h = bloque.fold<double>(0, (v, r) => v + r.alto);
    if (pagina.isNotEmpty && usado + h > maxCuerpo) {
      paginas.add(pagina);
      pagina = [];
      usado = 0;
    }
    for (final r in bloque) {
      if (usado + r.alto > maxCuerpo && pagina.isNotEmpty) {
        paginas.add(pagina);
        pagina = [];
        usado = 0;
      }
      pagina.add(r);
      usado += r.alto;
    }
  }
  if (pagina.isNotEmpty) paginas.add(pagina);
  for (var paginaIndex = 0; paginaIndex < paginas.length; paginaIndex++) {
    final widgets = <pw.Widget>[];
    void cell(
      double x,
      double y,
      double w,
      double h,
      String text, {
      double size = 5.4,
      bool bold = false,
      PdfColor? bg,
      bool left = false,
      bool border = true,
    }) {
      widgets.add(
        pw.Positioned(
          left: x,
          top: y,
          child: pw.Container(
            width: w,
            height: h,
            decoration: pw.BoxDecoration(
              color: bg,
              border: border ? pw.Border.all(width: .35) : null,
            ),
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 1.3,
              vertical: .5,
            ),
            alignment: left ? pw.Alignment.centerLeft : pw.Alignment.center,
            child: pw.Text(
              text,
              textAlign: left ? pw.TextAlign.left : pw.TextAlign.center,
              softWrap: false,
              style: pw.TextStyle(
                fontSize: size,
                lineSpacing: 0,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color:
                    bg == azul || bg == celeste || bg == azulDest
                        ? PdfColors.white
                        : PdfColors.black,
              ),
            ),
          ),
        ),
      );
    }

    void image(Uint8List bytes, double x, double y, double w, double h) {
      widgets.add(
        pw.Positioned(
          left: x,
          top: y,
          child: pw.SizedBox(
            width: w,
            height: h,
            child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
          ),
        ),
      );
    }

    cell(0, 0, 156, 19, '');
    image(logo, (156 - 89) / 2, 1, 89, 17);
    cell(156, 0, 278, 19, 'LISTA DE EMPAQUE NACIONAL', size: 7.4, bold: true);
    cell(434, 0, 60, 6, 'FMT-GL-002', size: 4.4, bold: true);
    cell(494, 0, 60, 6, 'V.1', size: 4.4, bold: true);
    cell(
      434,
      6,
      120,
      6,
      'FECHA DE VIGENCIA: 01-02-2018',
      size: 4.2,
      bold: true,
    );
    cell(
      434,
      12,
      120,
      7,
      'Página ${paginaIndex + 1} de ${paginas.length}',
      size: 4.4,
    );
    cell(0, 19, 31, 11, 'FECHA', bold: true);
    cell(31, 19, 440, 11, fechaTexto, size: 6.5, bold: true, left: true);
    cell(471, 19, 23, 11, 'LE N°', bold: true, size: 6.2);
    cell(494, 19, 60, 11, s(d['numero']), bold: true, size: 6.2);
    cell(0, 30, 299, 6, 'REMITENTE', size: 4.4, bold: true, bg: celeste);
    cell(299, 30, 255, 6, 'DESTINATARIO', size: 4.4, bold: true, bg: azulDest);
    // Altura adaptable para nombres y direcciones largos sin cortar información.
    final nombre = envolver(s(destino['nombre']), 214, 5.2);
    final sede = envolver(s(destino['sede']).trim(), 214, 5.2);
    final direccion = envolver(s(destino['direccion']), 214, 5.2);
    final contacto = envolver(s(destino['contacto']), 214, 5.2);
    final hn = math.max(12.0, nombre.split('\n').length * 6.2 + 2);
    final hc = math.max(8.0, contacto.split('\n').length * 6.2 + 2);
    final hs = math.max(8.0, sede.split('\n').length * 6.2 + 2);
    final hd = math.max(13.0, direccion.split('\n').length * 6.2 + 2);
    var y = 36.0;
    void pareja(
      double x,
      double labelW,
      double valueW,
      double yy,
      double h,
      String label,
      String value,
    ) {
      cell(x, yy, labelW, h, label, size: 4.4, bold: true, bg: gris);
      cell(x + labelW, yy, valueW, h, value, size: 5.2);
    }

    pareja(0, 31, 268, y, hn + 8, 'Nombre:', 'GRUPO QUIROMAR S.A.S.');
    pareja(299, 39, 216, y, hn, 'Nombre:', nombre);
    pareja(299, 39, 216, y + hn, 8, 'NIT:', s(destino['nit']));
    y += hn + 8;
    pareja(0, 31, 268, y, hc, 'NIT:', '830.055.605-3');
    pareja(299, 39, 216, y, hc, 'Sr/Sra:', contacto);
    y += hc;
    pareja(0, 31, 268, y, hs + hd, 'Dirección:', 'AV CRA 50 N° 29B - 19 SUR');
    pareja(299, 39, 216, y, hs, 'Sede:', sede);
    y += hs;
    pareja(299, 39, 216, y, hd, 'Dirección:', direccion);
    y += hd;
    for (final row in [
      ('Ciudad:', 'BOGOTA', 'Ciudad:', s(destino['ciudad'])),
      ('Teléfono:', '7136381 EXT.110', 'Teléfono:', s(destino['telefono'])),
      (
        'E-mail:',
        'logistica@grupoquiromar.com',
        'Móvil:',
        s(destino['celular']),
      ),
    ]) {
      pareja(0, 31, 268, y, 8, row.$1, row.$2);
      pareja(299, 39, 216, y, 8, row.$3, row.$4);
      y += 8;
    }
    cell(0, y, ancho, 8, '');
    y += 8;
    final metaWidths = [86.0, 70.0, 89.0, 92.0, 77.0, 140.0];
    final metaLabels = [
      'REMISIÓN No.',
      'ID OC',
      'ORDEN DE COMPRA',
      'LISTA DE EMPAQUE',
      'FACTURA No',
      'ORDEN DE PRODUCCIÓN',
    ];
    final metaValues = [
      s(d['remision']),
      s(d['id_oc']),
      s(d['oc']),
      s(d['numero']),
      s(d['factura']),
      detalle.values.map((e) => s(e['op'])).toSet().join(', '),
    ];
    var mx = 0.0;
    var metaH = 23.0;
    for (var i = 0; i < 6; i++) {
      metaValues[i] = envolver(metaValues[i], metaWidths[i] - 3, 5.6);
      metaH = math.max(metaH, metaValues[i].split('\n').length * 6.5 + 2);
    }
    for (var i = 0; i < 6; i++) {
      cell(
        mx,
        y,
        metaWidths[i],
        8,
        metaLabels[i],
        size: 4.4,
        bold: true,
        bg: azul,
      );
      cell(mx, y + 8, metaWidths[i], metaH, metaValues[i], size: 5.6);
      mx += metaWidths[i];
    }
    y += 8 + metaH;
    cell(0, y, ancho, 3, '');
    y += 3;
    final labels = [
      'N. CAJA',
      'OP',
      'DESCRIPCION DEL PRODUCTO',
      'TIPO DE EMPAQUE',
      'TALLA',
      'CANTIDAD',
    ];
    cell(0, y, xs[6], 6, '', bg: azul);
    for (var i = 0; i < 6; i++) {
      cell(
        xs[i],
        y + 6,
        widths[i],
        10,
        labels[i],
        size: 4.2,
        bold: true,
        bg: azul,
      );
    }
    cell(
      xs[6],
      y,
      widths[6],
      16,
      'CANTIDAD TOTAL\nPOR CAJA',
      size: 4.1,
      bold: true,
      bg: azul,
    );
    cell(
      xs[7],
      y,
      widths[7] + widths[8] + widths[9],
      6,
      'MEDIDA CAJA (m)',
      size: 4,
      bold: true,
      bg: azul,
    );
    cell(
      xs[10],
      y,
      widths[10] + widths[11],
      6,
      'PESOS CAJA (Kg)',
      size: 4,
      bold: true,
      bg: azul,
    );
    for (var i = 7; i < 12; i++) {
      cell(
        xs[i],
        y + 6,
        widths[i],
        10,
        ['ALTO', 'LARGO', 'ANCHO', 'NETO', 'BRUTO'][i - 7],
        size: 4,
        bold: true,
        bg: azul,
      );
    }
    cell(
      xs[12],
      y,
      widths[12],
      16,
      'PESO\nVOLUMETRICO',
      size: 3.5,
      bold: true,
      bg: azul,
    );
    y += 16;
    final inicio = y;
    final pageRows = paginas[paginaIndex];
    for (final numero in pageRows.map((e) => e.numero).toSet()) {
      final rows = pageRows.where((e) => e.numero == numero).toList();
      final groupH = rows.fold<double>(0, (v, r) => v + r.alto);
      final inicioGrupo = y;
      for (final r in rows) {
        for (var i = 0; i < 6; i++) {
          cell(xs[i], y, widths[i], r.alto, r.c[i], left: i == 2, size: 5.4);
        }
        y += r.alto;
      }
      final e = grupos[numero]!.first;
      final datos = [
        f(grupos[numero]!.fold<double>(0, (v, e) => v + n(e['cantidad']))),
        f(n(e['alto_cm']) / 100),
        f(n(e['largo_cm']) / 100),
        f(n(e['ancho_cm']) / 100),
        f(e['peso_neto_kg']),
        f(e['peso_bruto_kg']),
        f(volumen(e)),
      ];
      for (var i = 6; i < 13; i++) {
        cell(xs[i], inicioGrupo, widths[i], groupH, datos[i - 6]);
      }
    }
    final blanco = math.max(10.0, 151 - (y - inicio));
    for (var i = 0; i < 13; i++) {
      cell(xs[i], y, widths[i], blanco, '');
    }
    y += blanco;
    final ultima = paginaIndex == paginas.length - 1;
    cell(0, y, xs[3], 10, '');
    cell(
      xs[3],
      y,
      widths[3] + widths[4],
      10,
      ultima ? 'TOTAL / TOTAL:' : 'CONTINÚA:',
      size: 5,
      bold: true,
      bg: amarillo,
    );
    cell(xs[5], y, widths[5], 10, ultima ? f(total) : '');
    cell(
      xs[6],
      y,
      ancho - xs[6],
      10,
      ultima ? '' : 'Página ${paginaIndex + 2} de ${paginas.length}',
      size: 5,
    );
    y += 10;
    cell(0, y, ancho, 6, '', bg: celeste);
    y += 9;
    final totales = [
      [
        'Peso Neto Total (Kg)',
        ultima
            ? '${f(unicos.fold<double>(0, (v, e) => v + n(e['peso_neto_kg'])))} Kg'
            : '',
        'Total de piezas',
        ultima ? '${cajas + empaques}' : '',
      ],
      [
        'Peso Bruto Total (Kg)',
        ultima
            ? '${f(unicos.fold<double>(0, (v, e) => v + n(e['peso_bruto_kg'])))} Kg'
            : '',
        'N° de cajas',
        ultima ? '$cajas' : '',
      ],
      [
        'Volumen Total (m³)',
        ultima ? f(unicos.fold<double>(0, (v, e) => v + volumen(e))) : '',
        'N° de paquetes',
        ultima ? '$empaques' : '',
      ],
    ];
    for (final row in totales) {
      cell(0, y, 299, 7, row[0], size: 5, bold: true, bg: azul);
      cell(299, y, 39, 7, row[1], size: 5);
      cell(338, y, 177, 7, row[2], size: 5, bold: true, bg: azul);
      cell(515, y, 39, 7, row[3], size: 5);
      y += 7;
    }
    cell(0, y, ancho, 39, '');
    cell(
      50,
      y + 5,
      230,
      12,
      'RECIBIDO A SATISFACCION:',
      border: false,
      size: 5,
    );
    cell(338, y + 5, 116, 12, 'DESPACHADO POR:', border: false, size: 5);
    cell(86, y + 22, 159, 10, '', border: false);
    cell(
      338,
      y + 22,
      116,
      10,
      envolver(s(d['actor']), 112, 5),
      border: false,
      size: 5,
    );
    widgets.add(
      pw.Positioned(
        left: 86,
        top: y + 32,
        child: pw.SizedBox(
          width: 159,
          child: pw.Divider(height: 0, thickness: .4),
        ),
      ),
    );
    widgets.add(
      pw.Positioned(
        left: 338,
        top: y + 32,
        child: pw.SizedBox(
          width: 116,
          child: pw.Divider(height: 0, thickness: .4),
        ),
      ),
    );
    y += 39;
    // El cuerpo se escala solo en casos excepcionales de encabezados muy largos.
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.fromLTRB(22, 60, 36, 25),
        theme: pw.ThemeData.withFont(
          base: pw.Font.ttf(fuenteRegular),
          bold: pw.Font.ttf(fuenteNegrita),
        ),
        build:
            (_) => pw.FittedBox(
              alignment: pw.Alignment.topLeft,
              fit: pw.BoxFit.scaleDown,
              child: pw.SizedBox(
                width: ancho,
                height: y,
                child: pw.Stack(children: widgets),
              ),
            ),
      ),
    );
  }
  return pdf.save();
}
