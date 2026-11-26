import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../shared/descargar_excel.dart';

const _azul = PdfColor.fromInt(0xff0b3b4d);
const _urlFirmaLista =
    'https://transacciones.colsubsidio.com/dotaciones/#/login';

/// Genera desde un snapshot inmutable. Nunca vuelve a consultar datos actuales,
/// por lo que una reimpresión conserva responsable y cantidades emitidas.
Future<Uint8List> generarListaMasiva(Map<String, dynamic> snapshot) async {
  final logos = await _logosDocumentos();
  return _generarListaReferencia(_Datos(snapshot, logos: logos));
}

/// Nombre visible de una lista individual, también al reimprimir su versión.
String nombreArchivoListaMasiva(Map<String, dynamic> snapshot) {
  final datoLista = snapshot['lista'];
  final numero =
      datoLista is Map ? '${datoLista['lista'] ?? ''}' : '${datoLista ?? ''}';
  final lista = numero.trim().replaceAll(RegExp(r'[^A-Za-z0-9-]'), '_');
  if (lista.isEmpty) {
    throw const FormatException('Falta identificar la lista de empaque.');
  }
  final datoOperacion = snapshot['operacion'];
  final nombreOperacion =
      datoOperacion is Map ? '${datoOperacion['nombre'] ?? ''}' : '';
  final periodo = RegExp(
    r'\b(?:MASIVA|MSV)\s+([IVXLCDM]+|\d+)\s+(20\d{2})\b',
    caseSensitive: false,
  ).firstMatch(nombreOperacion);
  if (periodo == null) return 'LE $lista.pdf';
  return 'LE $lista MSV ${periodo.group(1)!.toUpperCase()} ${periodo.group(2)}.pdf';
}

Future<({Uint8List colsubsidio, Uint8List quiromar})> _logosDocumentos() async {
  final colsubsidio = await rootBundle.load(
    'assets/images/logo_colsubsidio.svg',
  );
  final quiromar = await rootBundle.load(
    'assets/images/logo_quiromar_vector_bn.svg',
  );
  return (
    colsubsidio: colsubsidio.buffer.asUint8List(),
    quiromar: quiromar.buffer.asUint8List(),
  );
}

Future<Uint8List> _generarListaReferencia(_Datos d) async {
  final pdf = pw.Document(
    title: 'Lista de empaque ${d.lista}',
    author: 'ORBILOQ',
  );
  await _agregarListaReferencia(pdf, d, await _tema());
  return pdf.save();
}

/// Crea un único PDF con una sección paginada independiente por lista.
/// Cada lista empieza en página nueva y conserva su propio encabezado y versión.
Future<Uint8List> generarListasMasivasMasiva(
  List<Map<String, dynamic>> snapshots,
) async {
  if (snapshots.length < 2) {
    throw const FormatException('Selecciona al menos dos listas de empaque.');
  }
  final logos = await _logosDocumentos();
  final tema = await _tema();
  final pdf = pw.Document(title: 'Listas de empaque Masiva', author: 'ORBILOQ');
  for (final snapshot in snapshots) {
    await _agregarListaReferencia(pdf, _Datos(snapshot, logos: logos), tema);
  }
  return pdf.save();
}

Future<void> _agregarListaReferencia(
  pw.Document pdf,
  _Datos d,
  pw.ThemeData tema,
) async {
  final entregados =
      d.kits
          .where((k) => _articulos(k).any((a) => _n(a['validado']) > 0))
          .toList();
  if (entregados.isEmpty) {
    throw const FormatException(
      'La lista aún no tiene prendas validadas para emitir.',
    );
  }
  if (entregados.any((k) => _s(k['caja']).isEmpty)) {
    throw const FormatException(
      'Asigna un empaque a todos los kits validados antes de emitir la lista.',
    );
  }
  final pendientes =
      d.kits
          .where(
            (k) =>
                _articulos(k).any((a) => _n(a['cantidad']) > _n(a['validado'])),
          )
          .toList();
  final paginasAnteriores = pdf.document.pdfPageList.pages.length;
  var paginasLista = 1;
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter.landscape,
      margin: const pw.EdgeInsets.all(42.5),
      theme: tema,
      maxPages: 500,
      header: (context) => _cabeceraReferencia(d),
      footer:
          (context) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 6),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Lista ${d.lista} · Versión ${d.version}',
                  style: const pw.TextStyle(fontSize: 6.5),
                ),
                pw.Text(
                  'Página ${context.pageNumber - paginasAnteriores} de $paginasLista',
                  style: const pw.TextStyle(fontSize: 6.5),
                ),
              ],
            ),
          ),
      build:
          (context) => [
            _destinoReferencia(d, entregados.length),
            pw.SizedBox(height: 13),
            _entregaReferencia(d),
            pw.SizedBox(height: 8),
            _tablaReferencia(entregados, pendiente: false),
            pw.SizedBox(height: 17),
            pw.Inseparable(child: _firmaReferencia(d)),
            if (pendientes.isNotEmpty) ...[
              pw.NewPage(),
              pw.Text(
                'ANEXO · PRENDAS PENDIENTES',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Este anexo no acredita entrega. Estas cantidades no forman parte de las prendas validadas del documento.',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 8),
              _tablaReferencia(pendientes, pendiente: true),
            ],
          ],
    ),
  );
  // addPage realiza la composición; los pies definitivos se pintan en save.
  paginasLista = pdf.document.pdfPageList.pages.length - paginasAnteriores;
}

pw.Widget _marcaReferencia(
  Uint8List? bytes,
  String texto, {
  double width = 165,
  double height = 37,
}) => pw.SizedBox(
  width: width,
  height: height,
  child:
      bytes != null
          ? _imagenLogo(bytes)
          : pw.Center(
            child: pw.Text(
              texto,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
);

pw.Widget _cabeceraReferencia(_Datos d) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 9),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _marcaReferencia(
        d.logoColsubsidio,
        'COLSUBSIDIO',
        width: 50 * PdfPageFormat.mm,
        height: 8.5 * PdfPageFormat.mm,
      ),
      pw.Expanded(
        child: pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          child: pw.Column(
            children: [
              pw.Text(
                'DOTACIÓN Y EPP',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                d.nombre,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
        ),
      ),
      pw.Column(
        children: [
          _marcaReferencia(
            d.logoQuiromar,
            'QUIROMAR',
            width: 50 * PdfPageFormat.mm,
            height: 8.5 * PdfPageFormat.mm,
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'LISTA DE EMPAQUE',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            d.lista,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    ],
  ),
);

pw.Widget _destinoReferencia(_Datos d, int totalKits) {
  final k = d.kits.first;
  pw.Widget campo(String etiqueta, String valor) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 63,
          child: pw.Text(
            etiqueta,
            style: pw.TextStyle(fontSize: 7.3, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            valor.isEmpty ? '—' : valor,
            style: const pw.TextStyle(fontSize: 7.5),
          ),
        ),
      ],
    ),
  );
  pw.Widget cantidad(String etiqueta, int valor) => pw.Row(
    children: [
      pw.SizedBox(
        width: 64,
        child: pw.Text(
          etiqueta,
          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.Container(
        width: 32,
        height: 22,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(border: pw.Border.all(width: .7)),
        child: pw.Text(
          '$valor',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ],
  );
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              d.fecha,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 5),
            campo('SEDE:', _s(k['sede'])),
            campo('CIUDAD:', _s(k['ciudad'])),
            campo('DIRECCIÓN:', _s(k['direccion'])),
            campo('UNIDAD:', _s(k['unidad'])),
            campo('LÍDER:', d.responsable),
            campo(
              'CONTACTO:',
              _s(k['contacto']).isNotEmpty ? _s(k['contacto']) : d.responsable,
            ),
            campo('TOTAL KITS:', '$totalKits'),
          ],
        ),
      ),
      pw.SizedBox(width: 28),
      pw.SizedBox(
        width: 165,
        child: pw.Padding(
          padding: const pw.EdgeInsets.only(top: 20, left: 42),
          child: pw.Column(
            children: [
              for (final entry in d.conteoEmpaques.entries)
                cantidad('${entry.key}:', entry.value),
            ],
          ),
        ),
      ),
    ],
  );
}

pw.Widget _entregaReferencia(_Datos d) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Expanded(
        child: pw.Text(
          'A través del proveedor logístico de GRUPO QUIROMAR S.A.S., ${d.cliente} hace entrega de los Kits de dotaciones prestacionales y EPP correspondientes a la ${d.nombre} del personal a su cargo.',
          style: const pw.TextStyle(fontSize: 8, lineSpacing: 2),
        ),
      ),
      pw.SizedBox(width: 12),
      pw.BarcodeWidget(
        barcode: pw.Barcode.qrCode(),
        data: _urlFirmaLista,
        width: 48,
        height: 48,
      ),
      pw.SizedBox(width: 7),
      pw.SizedBox(
        width: 116,
        child: pw.Text(
          '¡ESCANEA Y FIRMA! Para gestionar cambios y devoluciones, usa el Módulo de Dotaciones. Registro Digital Obligatorio.',
          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ],
  );
}

pw.Widget _tablaReferencia(
  List<Map<String, dynamic>> kits, {
  required bool pendiente,
}) {
  pw.Widget celda(String texto, {bool titulo = false, bool centro = false}) =>
      pw.Padding(
        padding: pw.EdgeInsets.symmetric(
          horizontal: 3,
          vertical: titulo ? 5 : 2.5,
        ),
        child: pw.Text(
          texto,
          textAlign: centro ? pw.TextAlign.center : pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: titulo ? 6.7 : 7.2,
            fontWeight: titulo ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
  final porDocumento =
      <
        String,
        List<
          ({
            Map<String, dynamic> kit,
            Map<String, dynamic> articulo,
            int cantidad,
          })
        >
      >{};
  for (var i = 0; i < kits.length; i++) {
    final kit = kits[i];
    final documento = _s(kit['cedula']).trim();
    final key = documento.isEmpty ? '__sin_documento_$i' : documento;
    for (final articulo in _articulos(kit)) {
      final cantidad =
          pendiente
              ? _n(articulo['cantidad']) - _n(articulo['validado'])
              : _n(articulo['validado']);
      if (cantidad <= 0) continue;
      porDocumento.putIfAbsent(key, () => []).add((
        kit: kit,
        articulo: articulo,
        cantidad: cantidad,
      ));
    }
  }

  final declaracion =
      pendiente
          ? 'ESTADO'
          : 'Con mi firma dejo constancia de que la Corporación se encuentra a paz y salvo para conmigo por concepto de dotación hasta la fecha';
  return pw.Table(
    border: pw.TableBorder.all(width: .5, color: PdfColors.grey600),
    columnWidths: {
      0: const pw.FixedColumnWidth(64),
      1: const pw.FlexColumnWidth(1.25),
      2: const pw.FlexColumnWidth(3.65),
      3: const pw.FixedColumnWidth(111),
    },
    children: [
      pw.TableRow(
        repeat: true,
        verticalAlignment: pw.TableCellVerticalAlignment.middle,
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          celda('DOCUMENTO', titulo: true, centro: true),
          celda('NOMBRE DEL COLABORADOR', titulo: true, centro: true),
          pw.Table(
            border: const pw.TableBorder(
              verticalInside: pw.BorderSide(
                width: .5,
                color: PdfColors.grey600,
              ),
            ),
            columnWidths: {
              0: const pw.FixedColumnWidth(52),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FixedColumnWidth(28),
              3: const pw.FixedColumnWidth(41),
            },
            children: [
              pw.TableRow(
                children: [
                  celda('COD MM', titulo: true, centro: true),
                  celda('PRENDA / EPP', titulo: true, centro: true),
                  celda(
                    pendiente ? 'PEND.' : 'CANT',
                    titulo: true,
                    centro: true,
                  ),
                  celda('EMPAQUE', titulo: true, centro: true),
                ],
              ),
            ],
          ),
          celda(declaracion, titulo: true, centro: true),
        ],
      ),
      for (final articulos in porDocumento.values)
        pw.TableRow(
          verticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: [
            celda(_s(articulos.first.kit['cedula'])),
            celda(_s(articulos.first.kit['nombre'])),
            pw.Table(
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(
                  width: .5,
                  color: PdfColors.grey600,
                ),
                verticalInside: pw.BorderSide(
                  width: .5,
                  color: PdfColors.grey600,
                ),
              ),
              columnWidths: {
                0: const pw.FixedColumnWidth(52),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FixedColumnWidth(28),
                3: const pw.FixedColumnWidth(41),
              },
              children: [
                for (final linea in articulos)
                  pw.TableRow(
                    verticalAlignment: pw.TableCellVerticalAlignment.middle,
                    children: [
                      celda(_s(linea.articulo['sku'])),
                      celda(_s(linea.articulo['descripcion'])),
                      celda('${linea.cantidad}', centro: true),
                      celda(_s(linea.kit['caja']), centro: true),
                    ],
                  ),
              ],
            ),
            celda(pendiente ? 'Pendiente' : ''),
          ],
        ),
    ],
  );
}

pw.Widget _firmaReferencia(_Datos d) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    for (final etiqueta in [
      'FIRMA DE RECIBIDO (LÍDER/RECEPTOR):',
      'NOMBRE DE QUIEN RECIBE',
      'DOCUMENTO DE QUIEN RECIBE',
      'FECHA DE RECIBO',
    ])
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          children: [
            pw.SizedBox(
              width: 210,
              child: pw.Text(
                etiqueta,
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Container(
              width: 280,
              height: 10,
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: .7)),
              ),
            ),
          ],
        ),
      ),
    pw.SizedBox(height: 9),
    pw.RichText(
      text: pw.TextSpan(
        style: const pw.TextStyle(fontSize: 7.5),
        children: [
          pw.TextSpan(
            text: 'NOTA IMPORTANTE: ',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.TextSpan(
            text:
                'El presente documento constituye la constancia formal de la entrega de dotación por parte de ${d.cliente} al colaborador.',
          ),
        ],
      ),
    ),
  ],
);

Future<Uint8List> generarRotulosMasiva(Map<String, dynamic> snapshot) async {
  final datos = _Datos(snapshot, logos: await _logosDocumentos());
  final tema = await _tema();
  final pdf = pw.Document(
    title: 'Rótulos lista ${datos.lista}',
    author: 'ORBILOQ',
  );
  _agregarRotulos(pdf, tema, datos);
  return pdf.save();
}

/// Conserva el destino y la versión de cada lista en un único PDF de rótulos.
Future<Uint8List> generarRotulosMasivosMasiva(
  List<Map<String, dynamic>> snapshots,
) async {
  if (snapshots.isEmpty) {
    throw const FormatException('Selecciona al menos una lista para rotular.');
  }
  final tema = await _tema();
  final pdf = pw.Document(title: 'Rótulos Masiva', author: 'ORBILOQ');
  final logos = await _logosDocumentos();
  for (final snapshot in snapshots) {
    _agregarRotulos(pdf, tema, _Datos(snapshot, logos: logos));
  }
  return pdf.save();
}

void _agregarRotulos(pw.Document pdf, pw.ThemeData tema, _Datos datos) {
  final grupos = <String, List<Map<String, dynamic>>>{};
  for (final kit in datos.kits) {
    if (!_articulos(kit).any((a) => _n(a['validado']) > 0)) continue;
    final caja = _s(kit['caja']);
    if (caja.isEmpty) {
      throw const FormatException(
        'Falta asignar un empaque a un kit validado.',
      );
    }
    grupos.putIfAbsent(caja, () => []).add(kit);
  }
  if (grupos.isEmpty) {
    throw const FormatException(
      'No hay empaques con prendas validadas para rotular.',
    );
  }
  final numeros = grupos.keys.toList()..sort(_compararNumero);
  for (final numero in numeros) {
    final kits = grupos[numero]!;
    final empaque =
        datos.empaques
            .where((e) => _s(e['caja'] ?? e['numero']) == numero)
            .firstOrNull ??
        <String, dynamic>{};
    final primero = kits.first;
    final unidades = kits.fold<int>(
      0,
      (s, k) => s + _articulos(k).fold<int>(0, (s, a) => s + _n(a['validado'])),
    );
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(10 * PdfPageFormat.cm, 10 * PdfPageFormat.cm),
        margin: const pw.EdgeInsets.all(9),
        theme: tema,
        build:
            (context) => _rotuloReferencia(
              datos,
              primero,
              empaque,
              numero,
              numeros.indexOf(numero) + 1,
              numeros.length,
              kits.length,
              unidades,
            ),
      ),
    );
  }
}

/// Presentación de impresión; no altera el snapshot ni el contenido del empaque.
pw.Widget _rotuloReferencia(
  _Datos d,
  Map<String, dynamic> destino,
  Map<String, dynamic> empaque,
  String numero,
  int posicion,
  int total,
  int kits,
  int unidades,
) {
  final nombreEmpaque = _s(empaque['nombre']).trim();
  final tipo = _s(empaque['tipo']).toUpperCase() == 'BOLSA' ? 'BOLSA' : 'CAJA';
  final titulo =
      d.nombre.toUpperCase().contains(d.cliente.toUpperCase())
          ? d.nombre
          : '${d.cliente} / ${d.nombre}';
  return pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border.all(width: .7)),
    padding: const pw.EdgeInsets.all(6),
    child: pw.Stack(
      children: [
        pw.Positioned(
          left: 0,
          right: 0,
          bottom: 20,
          child: pw.Opacity(
            opacity: .07,
            child: pw.SizedBox(
              height: 75,
              child: pw.SvgImage(
                svg: utf8
                    .decode(d.logoColsubsidio)
                    .replaceAll(RegExp(r'#[0-9a-fA-F]{6}'), '#000000'),
                fit: pw.BoxFit.contain,
              ),
            ),
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              height: 37,
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: _marca(d.logoQuiromar, 'QUIROMAR', height: 31),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'REMITE\nGRUPO QUIROMAR S.A.S.\nNIT: 830055605-3\nTEL: 7136381',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 6.3,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 3),
            _textoRotulo(
              titulo.toUpperCase(),
              height: 26,
              size: 12,
              center: true,
            ),
            _filaRotulo('SEDE', _s(destino['sede']), height: 27),
            _filaRotulo('DIRECCIÓN', _s(destino['direccion']), height: 28),
            _filaRotulo('CIUDAD', _s(destino['ciudad']), height: 21),
            pw.SizedBox(height: 5),
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Column(
                      children: [
                        _textoRotulo(
                          '# LISTA DE\nEMPAQUE',
                          height: 32,
                          size: 15,
                        ),
                        pw.SizedBox(height: 3),
                        pw.Expanded(
                          child: pw.Container(
                            width: double.infinity,
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(width: .8),
                            ),
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.FittedBox(
                              child: pw.Text(
                                d.lista,
                                style: pw.TextStyle(
                                  fontSize: 48,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      children: [
                        _textoRotulo(
                          'EMPAQUE: ${nombreEmpaque.isEmpty ? tipo : nombreEmpaque.toUpperCase()}',
                          height: 24,
                          size: 9,
                        ),
                        pw.Expanded(
                          child: pw.FittedBox(
                            child: pw.Text(
                              '$posicion / $total',
                              style: pw.TextStyle(
                                fontSize: 39,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        pw.Text(
                          'BULTO $posicion DE $total · ID EMPAQUE: $numero',
                          style: const pw.TextStyle(fontSize: 6),
                        ),
                        pw.SizedBox(height: 5),
                        _textoRotulo(
                          'SECTOR: ${_s(destino['sector']).isEmpty ? 'Sin registrar' : _s(destino['sector'])}',
                          height: 13,
                          size: 8,
                        ),
                        _textoRotulo(
                          '$kits kits · $unidades prendas/pares · ${_decimal(empaque['peso_lleno'] ?? empaque['peso_promedio'])} kg promedio',
                          height: 9,
                          size: 5.8,
                        ),
                        _textoRotulo(
                          'Versión ${d.version} · ${d.fecha}',
                          height: 8,
                          size: 5.5,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _textoRotulo(
  String value, {
  required double height,
  double size = 10,
  bool center = false,
}) => pw.SizedBox(
  height: height,
  width: double.infinity,
  child: pw.FittedBox(
    fit: pw.BoxFit.scaleDown,
    alignment: center ? pw.Alignment.center : pw.Alignment.centerLeft,
    child: pw.Text(
      value,
      textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
      style: pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold),
    ),
  ),
);

pw.Widget _filaRotulo(String label, String value, {required double height}) =>
    pw.Container(
      height: height,
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: .5)),
      ),
      child:
          value.length > 55
              ? pw.FittedBox(
                fit: pw.BoxFit.scaleDown,
                alignment: pw.Alignment.centerLeft,
                child: pw.SizedBox(
                  width: 250,
                  child: pw.Text(
                    '$label: ${value.toUpperCase()}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              )
              : pw.Row(
                children: [
                  pw.Text(
                    '$label: ',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.FittedBox(
                      fit: pw.BoxFit.scaleDown,
                      alignment: pw.Alignment.centerLeft,
                      child: pw.SizedBox(
                        width: 173,
                        child: pw.Text(
                          value.isEmpty ? 'Sin registrar' : value.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
    );

/// Exporta valores como texto o números tipados; nunca interpreta fórmulas del
/// usuario. Las cédulas y SKU conservan sus ceros iniciales.
Future<void> exportarMasivaExcel(
  List<Map<String, dynamic>> filas, {
  required String nombre,
}) async {
  await descargarExcel(
    await generarExcelMasiva(filas),
    nombre.endsWith('.xlsx') ? nombre : '$nombre.xlsx',
  );
}

Future<Uint8List> generarExcelMasiva(List<Map<String, dynamic>> filas) async {
  filas = [
    for (final f in filas)
      if (f['articulos'] is List)
        for (final a in _maps(f['articulos']))
          {
            ...Map<String, dynamic>.from(f)..remove('articulos'),
            ...a,
            if (f['id'] != null) 'kit_id': f['id'],
          }
      else
        f,
  ];
  final libro = Excel.createExcel();
  final hoja = libro['Masiva'];
  libro.delete('Sheet1');
  final columnas = <String>{for (final f in filas) ...f.keys}.toList();
  if (columnas.isEmpty) {
    throw const FormatException('No hay registros para exportar.');
  }
  hoja.appendRow([
    for (final c in columnas)
      TextCellValue(_etiquetas[c] ?? c.replaceAll('_', ' ')),
  ]);
  for (var i = 0; i < filas.length; i++) {
    final fila = filas[i];
    hoja.appendRow([for (final c in columnas) _celda(fila[c], c)]);
    if (i % 400 == 0) await Future<void>.delayed(Duration.zero);
  }
  for (var i = 0; i < columnas.length; i++) {
    hoja.setColumnWidth(
      i,
      {'nombre', 'descripcion', 'direccion'}.contains(columnas[i]) ? 42 : 22,
    );
    hoja
        .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        .cellStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#0B3B4D'),
      textWrapping: TextWrapping.WrapText,
    );
  }
  return Uint8List.fromList(libro.encode()!);
}

CellValue _celda(dynamic v, String clave) {
  if (v == null) return TextCellValue('');
  if (v is int && !{'sku', 'cedula', 'lista', 'pedido'}.contains(clave)) {
    return IntCellValue(v);
  }
  if (v is double) return DoubleCellValue(v);
  return TextCellValue(v is Map || v is List ? jsonEncode(v) : '$v');
}

const _etiquetas = {
  'lista': 'Lista de empaque',
  'numero_persona': 'Número de persona',
  'cedula': 'Documento',
  'nombre': 'Nombre',
  'sku': 'SKU',
  'descripcion': 'Descripción',
  'cantidad': 'Cantidad solicitada',
  'validado': 'Cantidad validada',
  'proveedor': 'Proveedor',
  'pedido': 'Pedido',
  'unidad': 'Unidad',
  'sede': 'Sede',
  'ciudad': 'Ciudad',
  'direccion': 'Dirección',
  'lider': 'Responsable',
  'sector': 'Sector',
  'caja': 'Empaque',
};

Future<pw.ThemeData> _tema() async => pw.ThemeData.withFont(
  base: pw.Font.ttf(
    await rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'),
  ),
  bold: pw.Font.ttf(
    await rootBundle.load('assets/fonts/LiberationSans-Bold.ttf'),
  ),
);

class _Datos {
  _Datos(this.snapshot, {required this.logos}) {
    if (_n(snapshot['formato_version'] ?? 1) != 1) {
      throw const FormatException(
        'Esta versión del documento requiere actualizar ORBILOQ antes de reimprimir.',
      );
    }
    operacion = _map(snapshot['operacion']);
    final destino = _map(snapshot['lista']);
    kits = [
      for (final k in _maps(snapshot['kits'])) {...destino, ...k},
    ];
    final usados =
        kits
            .where((k) => _articulos(k).any((a) => _n(a['validado']) > 0))
            .map((k) => _s(k['caja']))
            .toSet();
    empaques = [
      for (final e in _maps(snapshot['empaques']))
        if (usados.contains(_s(e['numero'] ?? e['caja'])))
          {..._map(e['empaque_snapshot']), ...e},
    ];
    lista = destino.isEmpty ? _s(snapshot['lista']) : _s(destino['lista']);
    if (lista.isEmpty) {
      throw const FormatException('Falta identificar la lista de empaque.');
    }
    kits.sort(
      (a, b) => _n(a['numero_persona']).compareTo(_n(b['numero_persona'])),
    );
  }
  final Map<String, dynamic> snapshot;
  final ({Uint8List colsubsidio, Uint8List quiromar}) logos;
  late final Map<String, dynamic> operacion;
  late final List<Map<String, dynamic>> kits, empaques;
  late final String lista;
  Uint8List get logoColsubsidio => logos.colsubsidio;
  Uint8List get logoQuiromar => logos.quiromar;
  String get nombre => _s(operacion['nombre']);
  String get cliente => _s(operacion['cliente']);
  String get responsable =>
      _s(snapshot['responsable']).isNotEmpty
          ? _s(snapshot['responsable'])
          : (kits.isEmpty ? '' : _s(kits.first['lider']));
  String get version =>
      _s(snapshot['version']).isEmpty ? '1' : _s(snapshot['version']);
  String get fecha {
    final fecha = DateTime.tryParse(_s(snapshot['fecha']));
    if (fecha == null) return _s(snapshot['fecha']);
    final local =
        fecha.isUtc ? fecha.subtract(const Duration(hours: 5)) : fecha;
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  Map<String, int> get conteoEmpaques {
    final porNumero = {
      for (final e in empaques) _s(e['numero'] ?? e['caja']): e,
    };
    final usados = kits
        .where((k) => _articulos(k).any((a) => _n(a['validado']) > 0))
        .map((k) => _s(k['caja']))
        .where((n) => n.isNotEmpty)
        .toSet();
    final conteo = <String, int>{};
    for (final numero in usados) {
      final tipo = tipoEmpaqueListaMasiva(porNumero[numero] ?? const {});
      conteo.update(tipo, (n) => n + 1, ifAbsent: () => 1);
    }
    return conteo;
  }
}

/// Usa la categoría registrada; BOLSA es el código histórico de PAQUETE.
/// Un snapshot antiguo sin tipo no se presume caja.
String tipoEmpaqueListaMasiva(Map<String, dynamic> empaque) {
  final tipo = _s(empaque['tipo']).trim();
  final categoria = (tipo.isEmpty ? _s(empaque['categoria']) : tipo)
      .trim()
      .toUpperCase();
  return switch (categoria) {
    'CAJA' => 'CAJA',
    'BOLSA' || 'PAQUETE' => 'PAQUETE',
    _ => 'EMPAQUE',
  };
}

pw.Widget _marca(
  Uint8List? bytes,
  String texto, {
  double width = 145,
  double height = 36,
}) => pw.SizedBox(
  width: width,
  height: height,
  child:
      bytes != null
          ? _imagenLogo(bytes)
          : pw.Center(
            child: pw.Text(
              texto,
              maxLines: 2,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: _azul,
              ),
            ),
          ),
);

pw.Widget _imagenLogo(Uint8List bytes) {
  final source = utf8.decode(bytes, allowMalformed: true).trimLeft();
  final svgStart = source.indexOf('<svg');
  if (svgStart >= 0) {
    return pw.SvgImage(svg: source.substring(svgStart), fit: pw.BoxFit.contain);
  }
  return pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain);
}

List<Map<String, dynamic>> _articulos(Map<String, dynamic> kit) =>
    _maps(kit['articulos']);
List<Map<String, dynamic>> _maps(dynamic v) =>
    v is List
        ? [for (final e in v.whereType<Map>()) Map<String, dynamic>.from(e)]
        : [];
Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : {};
String _s(dynamic v) => v == null ? '' : '$v';
int _n(dynamic v) => v is num ? v.toInt() : int.tryParse(_s(v)) ?? 0;
String _decimal(dynamic v) =>
    v == null
        ? 'Sin registrar'
        : (num.tryParse('$v')?.toStringAsFixed(2) ?? 'Sin registrar');
int _compararNumero(String a, String b) =>
    (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0);
