import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Lee únicamente Clientes; no evalúa fórmulas ni ejecuta VBA.
List<Map<String, String>> leerClientesEmpaque(Uint8List bytes) {
  final zip = ZipDecoder().decodeBytes(bytes);
  XmlDocument xml(String name) {
    final f = zip.findFile(name);
    if (f == null) throw FormatException('Falta $name en el Excel');
    return XmlDocument.parse(utf8.decode(f.content as List<int>));
  }

  final wb = xml('xl/workbook.xml');
  final sheet =
      wb
          .findAllElements('sheet')
          .where(
            (s) =>
                (s.getAttribute('name') ?? '').trim().toLowerCase() ==
                'clientes',
          )
          .firstOrNull;
  if (sheet == null) throw const FormatException('No existe la hoja Clientes');
  final rid = sheet.attributes.where((a) => a.name.local == 'id').first.value;
  final rel = xml('xl/_rels/workbook.xml.rels')
      .findAllElements('Relationship')
      .firstWhere((r) => r.getAttribute('Id') == rid);
  var target = rel.getAttribute('Target')!;
  target = target.startsWith('/') ? target.substring(1) : 'xl/$target';
  final strings = <String>[];
  if (zip.findFile('xl/sharedStrings.xml') != null) {
    for (final si in xml('xl/sharedStrings.xml').findAllElements('si')) {
      strings.add(si.findAllElements('t').map((t) => t.innerText).join());
    }
  }
  final rows = <Map<String, String>>[];
  final campos = [
    'nombre',
    'nit',
    'contacto',
    'ciudad',
    'direccion',
    'telefono',
    'celular',
  ];
  for (final row in xml(target).findAllElements('row')) {
    final values = <String, String>{};
    for (final c in row.findElements('c')) {
      final col = (c.getAttribute('r') ?? '').replaceAll(RegExp(r'[0-9]'), '');
      final index = ['B', 'C', 'D', 'E', 'F', 'G', 'H'].indexOf(col);
      if (index < 0) continue;
      if (c.findElements('f').isNotEmpty) {
        throw FormatException(
          'Clientes: la celda ${c.getAttribute('r')} contiene una formula. Pega su valor antes de importar.',
        );
      }
      final raw = c.findElements('v').firstOrNull?.innerText ?? '';
      final type = c.getAttribute('t');
      if (type == 'e') {
        throw FormatException('Error de Excel en ${c.getAttribute('r')}');
      }
      final value =
          type == 's'
              ? strings[int.parse(raw)]
              : type == 'inlineStr'
              ? c.findAllElements('t').map((t) => t.innerText).join()
              : raw;
      values[campos[index]] = value.trim();
    }
    if (row.getAttribute('r') == '1') {
      const expected = {
        'nit': 'NIT',
        'contacto': 'QUIEN RECIBE',
        'ciudad': 'CIUDAD',
        'direccion': 'DIRECCION',
        'telefono': 'TELEFONO',
        'celular': 'CELULAR',
      };
      for (final e in expected.entries) {
        final header = (values[e.key] ?? '')
            .toUpperCase()
            .replaceAll('Ó', 'O')
            .replaceAll('É', 'E')
            .replaceAll('Í', 'I')
            .replaceAll(RegExp(r'\s+'), ' ');
        if (header != e.value) {
          throw FormatException(
            'La hoja Clientes debe conservar las columnas B:H de la plantilla. Encabezado esperado: ${e.value}',
          );
        }
      }
      continue;
    }
    if ((values['nombre'] ?? '').isEmpty) continue;
    rows.add({for (final k in campos) k: values[k] ?? ''});
  }
  if (rows.isEmpty) {
    throw const FormatException('Clientes no tiene destinatarios');
  }
  return rows;
}
