import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/rotulo_empaque.dart';

/// Rótulo 100 × 100 mm. No genera QR, serial ni total de piezas.
Future<Uint8List> crearRotuloEmpaquePdf(
  RotuloEmpaque rotulo, {
  required Uint8List logo,
  required ByteData fuenteRegular,
  required ByteData fuenteNegrita,
}) async {
  if (rotulo.numero < 1 ||
      rotulo.productos.isEmpty ||
      rotulo.productos.any((p) => p.cantidad <= 0)) {
    throw const FormatException(
      'El empaque debe contener prendas con cantidades válidas.',
    );
  }
  if (!rotulo.pesoBrutoKg.isFinite || rotulo.pesoBrutoKg <= 0) {
    throw const FormatException(
      'Indica el peso bruto del empaque antes de generar su rótulo.',
    );
  }
  final logoVector = utf8.decode(logo);
  final doc = pw.Document();
  final font = PdfTtfFont(doc.document, fuenteRegular);
  const mm = PdfPageFormat.mm;
  const alto = 100 * mm;
  List<String> envolver(String texto, double ancho, double size) {
    final resultado = <String>[];
    for (final parrafo in texto.split('\n')) {
      var linea = '';
      for (final palabra in parrafo.split(RegExp(r'\s+'))) {
        final siguiente = linea.isEmpty ? palabra : '$linea $palabra';
        if (font.stringMetrics(siguiente).width * size <= ancho) {
          linea = siguiente;
          continue;
        }
        if (linea.isNotEmpty) {
          resultado.add(linea);
          linea = '';
        }
        for (final rune in palabra.runes) {
          final ch = String.fromCharCode(rune);
          if (linea.isNotEmpty &&
              font.stringMetrics(linea + ch).width * size > ancho) {
            resultado.add(linea);
            linea = '';
          }
          linea += ch;
        }
      }
      resultado.add(linea);
    }
    return resultado;
  }

  // Los campos del destinatario crecen si necesitan más de una línea.
  final cliente = envolver(
    '${rotulo.destinatario['nombre'] ?? ''}',
    67 * mm,
    8,
  );
  final oc = envolver(rotulo.oc, 57 * mm, 8);
  final ciudad = envolver('${rotulo.destinatario['ciudad'] ?? ''}', 67 * mm, 8);
  final direccion = envolver(
    '${rotulo.destinatario['direccion'] ?? ''}',
    67 * mm,
    8,
  );
  final sede = envolver('${rotulo.destinatario['sede'] ?? ''}', 67 * mm, 8);
  final hs = math.max(3.8 * mm, sede.length * 9.3 + 1);
  final hd = math.max(3.8 * mm, direccion.length * 9.3 + 1);
  final hc = math.max(3.8 * mm, cliente.length * 9.3 + 1);
  final ho = math.max(3.8 * mm, oc.length * 9.3 + 1);
  final hu = math.max(3.8 * mm, ciudad.length * 9.3 + 1);
  final inicioTabla = 70.5 * mm - hc - ho - hu - hs - hd - .5 * mm - 5 * mm;
  final capacidad = inicioTabla - 12 * mm;
  if (capacidad < 10 * mm) {
    throw const FormatException(
      'Los datos del destinatario son demasiado extensos para un rótulo de 10 × 10 cm.',
    );
  }
  final filas =
      <
        ({
          String op,
          String descripcion,
          String talla,
          String cantidad,
          double altura,
        })
      >[];
  final maxLineas = math.max(1, ((capacidad - 3) / 8).floor());
  for (final p in rotulo.productos) {
    final lineas = envolver(p.descripcion, 43 * mm, 6.8);
    final ops = envolver(p.op, 12 * mm, 6.5);
    final tallas = envolver(p.talla, 15 * mm, 7);
    for (var i = 0; i < lineas.length; i += maxLineas) {
      final parte = lineas.skip(i).take(maxLineas).toList();
      final altura = math.max(
        3.9 * mm,
        math.max(
              math.max(parte.length * 8, ops.length * 8),
              i == 0 ? tallas.length * 8 : 8,
            ) +
            3,
      );
      if (altura > capacidad) {
        throw const FormatException(
          'La OP o talla es demasiado extensa para el rótulo.',
        );
      }
      filas.add((
        op: ops.join('\n'),
        descripcion: parte.join('\n'),
        talla: i == 0 ? tallas.join('\n') : '',
        cantidad: i == 0 ? '${p.cantidad}' : '',
        altura: altura.toDouble(),
      ));
    }
  }
  final paginas =
      <
        List<
          ({
            String op,
            String descripcion,
            String talla,
            String cantidad,
            double altura,
          })
        >
      >[];
  var usadas = 0.0;
  for (final fila in filas) {
    if (paginas.isEmpty || usadas + fila.altura > capacidad) {
      paginas.add([]);
      usadas = 0;
    }
    paginas.last.add(fila);
    usadas += fila.altura;
  }
  for (var pagina = 0; pagina < paginas.length; pagina++) {
    final widgets = <pw.Widget>[];
    void caja(
      double x,
      double y,
      double w,
      double h, {
      bool encabezado = false,
    }) => widgets.add(
      pw.Positioned(
        left: x,
        bottom: y,
        right: alto - x - w,
        top: alto - y - h,
        child: pw.Container(
          decoration: pw.BoxDecoration(
            color: encabezado ? PdfColors.grey300 : null,
            border: pw.Border.all(width: .5),
          ),
        ),
      ),
    );
    void texto(
      double x,
      double y,
      double w,
      double h,
      String valor, {
      double size = 8,
      bool bold = false,
      bool blanco = false,
      pw.Alignment align = pw.Alignment.centerLeft,
    }) => widgets.add(
      pw.Positioned(
        left: x,
        bottom: y,
        right: alto - x - w,
        top: alto - y - h,
        child: pw.Container(
          alignment: align,
          child: pw.Text(
            valor,
            style: pw.TextStyle(
              fontSize: size,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: blanco ? PdfColors.white : PdfColors.black,
            ),
            textAlign:
                align == pw.Alignment.center
                    ? pw.TextAlign.center
                    : pw.TextAlign.left,
          ),
        ),
      ),
    );
    caja(4 * mm, 4 * mm, 92 * mm, 92 * mm);
    texto(8 * mm, 92 * mm, 55 * mm, 3 * mm, 'REMITE:', size: 6.3, bold: true);
    widgets.add(
      pw.Positioned(
        left: 12 * mm,
        bottom: 80 * mm,
        right: 38 * mm,
        top: 11.5 * mm,
        child: pw.SvgImage(svg: logoVector, fit: pw.BoxFit.contain),
      ),
    );
    texto(
      8 * mm,
      75 * mm,
      58 * mm,
      3 * mm,
      'AV CRA 50 # 29B - 19 SUR',
      size: 6.4,
      align: pw.Alignment.center,
    );
    texto(
      8 * mm,
      71.8 * mm,
      58 * mm,
      3 * mm,
      'NIT: 830055605-3 · TEL: 7136381',
      size: 6.4,
      align: pw.Alignment.center,
    );
    caja(72 * mm, 74 * mm, 21 * mm, 19 * mm);
    texto(
      72 * mm,
      85 * mm,
      21 * mm,
      6 * mm,
      'PIEZA',
      size: 11,
      bold: true,
      align: pw.Alignment.center,
    );
    texto(
      72 * mm,
      77 * mm,
      21 * mm,
      6 * mm,
      '${rotulo.numero} DE ____',
      size: 10,
      bold: true,
      align: pw.Alignment.center,
    );
    var y = 70.5 * mm;
    caja(4 * mm, y, 92 * mm, 0);
    for (final campo in [
      (hc, 'CLIENTE:', cliente.join('\n'), 26.0),
      (ho, 'ORDEN DE COMPRA:', oc.join('\n'), 37.0),
      (hu, 'CIUDAD:', ciudad.join('\n'), 26.0),
      (hs, 'SEDE:', sede.join('\n'), 26.0),
      (hd, 'DIRECCIÓN:', direccion.join('\n'), 26.0),
    ]) {
      y -= campo.$1;
      texto(
        7 * mm,
        y,
        29 * mm,
        campo.$1,
        campo.$2,
        size: campo.$2 == 'ORDEN DE COMPRA:' ? 6.6 : 7,
        bold: true,
      );
      texto(
        campo.$4 * mm,
        y,
        (93 - campo.$4) * mm,
        campo.$1,
        campo.$3,
        size: 8,
        bold: campo.$2 == 'CLIENTE:',
      );
    }
    caja(4 * mm, inicioTabla, 92 * mm, 5 * mm, encabezado: true);
    texto(
      5 * mm,
      inicioTabla,
      12 * mm,
      5 * mm,
      'OP',
      size: 6.6,
      bold: true,
      align: pw.Alignment.center,
    );
    texto(
      19 * mm,
      inicioTabla,
      43 * mm,
      5 * mm,
      'DESCRIPCIÓN DEL PRODUCTO',
      size: 5.8,
      bold: true,
    );
    texto(
      63 * mm,
      inicioTabla,
      17 * mm,
      5 * mm,
      'TALLA',
      size: 6.6,
      bold: true,
      align: pw.Alignment.center,
    );
    texto(
      80 * mm,
      inicioTabla,
      16 * mm,
      5 * mm,
      'CANT.',
      size: 6.6,
      bold: true,
      align: pw.Alignment.center,
    );
    y = inicioTabla;
    for (final f in paginas[pagina]) {
      y -= f.altura;
      caja(4 * mm, y, 14 * mm, f.altura);
      caja(18 * mm, y, 45 * mm, f.altura);
      caja(63 * mm, y, 17 * mm, f.altura);
      caja(80 * mm, y, 16 * mm, f.altura);
      texto(
        5 * mm,
        y,
        12 * mm,
        f.altura,
        f.op,
        size: 6.5,
        align: pw.Alignment.center,
      );
      texto(19 * mm, y, 43 * mm, f.altura, f.descripcion, size: 6.8);
      texto(
        64 * mm,
        y,
        15 * mm,
        f.altura,
        f.talla,
        size: 7,
        align: pw.Alignment.center,
      );
      texto(
        80 * mm,
        y,
        16 * mm,
        f.altura,
        f.cantidad,
        size: 7.5,
        bold: true,
        align: pw.Alignment.center,
      );
    }
    // Pie independiente de la tabla: nombre y peso en una fila; tipo debajo.
    void ajustado(double x, double y, double w, String valor, double size) {
      widgets.add(
        pw.Positioned(
          left: x * mm,
          bottom: y * mm,
          right: (100 - x - w) * mm,
          top: (100 - y - 3) * mm,
          child: pw.FittedBox(
            alignment: pw.Alignment.centerLeft,
            fit: pw.BoxFit.scaleDown,
            child: pw.Text(valor, style: pw.TextStyle(fontSize: size)),
          ),
        ),
      );
    }

    texto(
      7 * mm,
      7.8 * mm,
      25 * mm,
      3 * mm,
      'EMPACADO POR:',
      size: 6.5,
      bold: true,
    );
    ajustado(32, 7.8, 28, rotulo.empacadoPor, 7.5);
    final bruto = rotulo.pesoBrutoKg
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'\.?0+$'), '')
        .replaceAll('.', ',');
    ajustado(62, 7.8, 31, 'PESO BRUTO: $bruto kg', 6.7);
    texto(
      7 * mm,
      4.4 * mm,
      28 * mm,
      3 * mm,
      'TIPO DE EMPAQUE:',
      size: 6.5,
      bold: true,
    );
    ajustado(35, 4.4, 22, rotulo.tipoEmpaque, 7.5);
    texto(
      58 * mm,
      4.4 * mm,
      35 * mm,
      2.5 * mm,
      'RÓTULO ${pagina + 1} DE ${paginas.length} · MISMA PIEZA ${rotulo.numero}',
      size: 4.3,
      align: pw.Alignment.centerRight,
    );
    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(alto, alto),
        margin: pw.EdgeInsets.zero,
        theme: pw.ThemeData.withFont(
          base: pw.Font.ttf(fuenteRegular),
          bold: pw.Font.ttf(fuenteNegrita),
        ),
        build: (_) => pw.Stack(children: widgets),
      ),
    );
  }
  return doc.save();
}
