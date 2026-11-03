import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../shared/descargar_excel.dart';

const _azul = PdfColor.fromInt(0xff0b3b4d);
const _verde = PdfColor.fromInt(0xffc5d900);
const _suave = PdfColor.fromInt(0xfff1f5f6);
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
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter.landscape,
      margin: const pw.EdgeInsets.fromLTRB(28, 20, 28, 23),
      theme: tema,
      maxPages: 500,
      header: (context) => _cabeceraReferencia(d, context.pageNumber > 1),
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
                  'Página ${context.pageNumber} de ${context.pagesCount}',
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

pw.Widget _cabeceraReferencia(_Datos d, bool continuacion) => pw.Padding(
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
              if (continuacion)
                pw.Text('CONTINUACIÓN', style: const pw.TextStyle(fontSize: 7)),
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
        width: 40,
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
              cantidad('CAJA:', d.cajas),
              cantidad('BOLSA:', d.bolsas),
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
              3: const pw.FixedColumnWidth(29),
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
                  celda('CAJA', titulo: true, centro: true),
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
                3: const pw.FixedColumnWidth(29),
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
        margin: pw.EdgeInsets.zero,
        theme: tema,
        build:
            (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _marca(
                      datos.logoColsubsidio,
                      'COLSUBSIDIO',
                      width: 50 * PdfPageFormat.mm,
                      height: 8.5 * PdfPageFormat.mm,
                    ),
                    _marca(
                      datos.logoQuiromar,
                      'QUIROMAR',
                      width: 50 * PdfPageFormat.mm,
                      height: 8.5 * PdfPageFormat.mm,
                    ),
                  ],
                ),
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(12, 7, 12, 12),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          color: _azul,
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'LISTA ${datos.lista}',
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 11,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                '${_s(empaque['tipo']).toUpperCase() == 'BOLSA' ? 'BOLSA' : 'CAJA'} $numero',
                                style: pw.TextStyle(
                                  color: _verde,
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          datos.nombre,
                          maxLines: 2,
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: _azul,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        _campoRotulo(
                          'SEDE / CIUDAD',
                          '${_s(primero['sede'])} · ${_s(primero['ciudad'])}',
                          2,
                        ),
                        _campoRotulo('DIRECCIÓN', _s(primero['direccion']), 3),
                        _campoRotulo('RESPONSABLE', datos.responsable, 2),
                        pw.Spacer(),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(7),
                          color: _suave,
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                '${kits.length} kits · $unidades prendas/pares',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                '${_decimal(empaque['peso_lleno'] ?? empaque['peso_promedio'])} kg*',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '* Peso promedio lleno. Vacío: ${_decimal(empaque['peso_vacio'])} kg.',
                          style: const pw.TextStyle(fontSize: 6),
                        ),
                        pw.Text(
                          'Versión ${datos.version} · ${datos.fecha}',
                          style: const pw.TextStyle(
                            fontSize: 6,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

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

  int get bolsas =>
      empaques.where((e) => _s(e['tipo']).toUpperCase() == 'BOLSA').length;
  int get cajas =>
      empaques.isEmpty
          ? kits
              .map((k) => _s(k['caja']))
              .where((v) => v.isNotEmpty)
              .toSet()
              .length
          : empaques.length - bolsas;
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

pw.Widget _campoRotulo(String nombre, String valor, int lineas) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 5),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        nombre,
        style: pw.TextStyle(
          fontSize: 6,
          color: PdfColors.grey700,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.Text(
        valor.isEmpty ? 'Sin registrar' : valor,
        style: pw.TextStyle(fontSize: valor.length > 100 ? 8 : 9),
      ),
    ],
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
