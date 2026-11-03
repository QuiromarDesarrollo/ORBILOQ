import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/masiva/masiva_importador.dart';
import 'package:orbiloq_wms/features/masiva/masiva_importador_parser.dart';

const personal = [
  'LE',
  '#',
  'Cédula',
  'Nombre Completo',
  'Código',
  'Material Descripcion',
  'Cantidad a enviar',
  'FECHA EMPAQUE',
];
const recepcion = [
  'Código material',
  'Descripción',
  'Cantidad',
  'ORDEN DE COMPRA',
  'PROVEEDOR',
];

String esc(String v) => v
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
String columna(int n) {
  var r = '';
  for (var c = n + 1; c > 0; c = (c - 1) ~/ 26) {
    r = String.fromCharCode(65 + (c - 1) % 26) + r;
  }
  return r;
}

Uint8List libro(
  Map<String, List<List<Object?>>> hojas, {
  String? formula,
  String? cache,
  String? formato,
  bool usa1904 = false,
}) {
  final zip = Archive();
  void agregar(String nombre, String texto) {
    final b = utf8.encode(texto);
    zip.addFile(ArchiveFile(nombre, b.length, b));
  }

  if (formato != null) {
    agregar(
      'xl/styles.xml',
      '<styleSheet><numFmts><numFmt numFmtId="164" formatCode="$formato"/></numFmts><cellXfs><xf numFmtId="164"/></cellXfs></styleSheet>',
    );
  }

  agregar(
    'xl/workbook.xml',
    '<workbook xmlns:r="rel"><workbookPr date1904="${usa1904 ? 1 : 0}"/><sheets>${hojas.keys.indexed.map((e) => '<sheet name="${esc(e.$2)}" r:id="r${e.$1}"/>').join()}</sheets></workbook>',
  );
  agregar(
    'xl/_rels/workbook.xml.rels',
    '<Relationships>${hojas.keys.indexed.map((e) => '<Relationship Id="r${e.$1}" Target="worksheets/s${e.$1}.xml"/>').join()}</Relationships>',
  );
  for (final h in hojas.values.indexed) {
    final xml = StringBuffer('<worksheet><sheetData>');
    for (final f in h.$2.indexed) {
      xml.write('<row r="${f.$1 + 1}">');
      for (final c in f.$2.indexed) {
        if (c.$2 == null) continue;
        final ref = '${columna(c.$1)}${f.$1 + 1}';
        if (ref == 'G2' && formula != null) {
          xml.write(
            '<c r="$ref"><f>${esc(formula)}</f>${cache == null ? '' : '<v>$cache</v>'}</c>',
          );
        } else if (c.$2 is num) {
          xml.write(
            '<c r="$ref"${formato == null ? '' : ' s="0"'}><v>${c.$2}</v></c>',
          );
        } else {
          xml.write(
            '<c r="$ref" t="inlineStr"><is><t>${esc('${c.$2}')}</t></is></c>',
          );
        }
      }
      xml.write('</row>');
    }
    xml.write('</sheetData></worksheet>');
    agregar('xl/worksheets/s${h.$1}.xml', xml.toString());
  }
  return Uint8List.fromList(ZipEncoder().encode(zip)!);
}

void main() {
  test(
    'Solo CONSOLIDADO aporta filas, proveedores y cantidades; TD se ignora',
    () {
      final result = parsearMasivaExcel(
        libro({
          'CONSOLIDADO': [
            recepcion,
            ['001', 'Camisa', 4, '0007', 'Proveedor'],
          ],
          'Proveedor': [
            recepcion,
            ['001', 'Camisa', 99, '0007', 'Proveedor'],
          ],
          'TD': [
            ['ORDEN DE COMPRA', 'HORARIO'],
            ['0007', '8:00 AM'],
          ],
        }),
        tipo: 'recepcion',
      );
      expect(result.errores, isEmpty);
      expect(result.hojas, ['CONSOLIDADO']);
      expect(result.filas, hasLength(1));
      expect(result.filas.single['proveedor'], 'Proveedor');
      expect(result.filas.single['cantidad'], 4);
      for (final campo in [
        'horario',
        'recibido',
        'fecha_recepcion',
        'novedad',
      ]) {
        expect(result.filas.single.containsKey(campo), isFalse);
      }
    },
  );
  test('Sin CONSOLIDADO no importa hojas de proveedores', () {
    final result = parsearMasivaExcel(
      libro({
        'Proveedor': [
          recepcion,
          ['001', 'Camisa', 4, '7', 'Proveedor'],
        ],
      }),
      tipo: 'recepcion',
    );
    expect(result.valida, isFalse);
    expect(result.filas, isEmpty);
    expect(result.errores.join(), contains('CONSOLIDADO'));
  });
  test('CONSOLIDADO exige los cinco encabezados del formato', () {
    final result = parsearMasivaExcel(
      libro({
        'CONSOLIDADO': [
          recepcion.take(4).toList(),
          ['001', 'Camisa', 4, '7'],
        ],
      }),
      tipo: 'recepcion',
    );
    expect(result.valida, isFalse);
    expect(result.errores.join(), contains('PROVEEDOR'));
  });
  test('CONSOLIDADO bloquea duplicados de proveedor, OC y SKU', () {
    final fila = ['001', 'Camisa', 4, '7', 'Proveedor'];
    final result = parsearMasivaExcel(
      libro({
        'CONSOLIDADO': [recepcion, fila, fila],
      }),
      tipo: 'recepcion',
    );
    expect(result.valida, isFalse);
    expect(result.errores.join(), contains('duplicado'));
  });
  test(
    'Los códigos numéricos con formato de ceros mantienen su presentación',
    () {
      final resultado = parsearMasivaExcel(
        libro({
          'Base': [
            personal,
            ['A', 1, 123, 'Persona', 12, 'Camisa', 2],
          ],
        }, formato: '00000'),
        tipo: 'personal',
      );
      expect(resultado.valida, isTrue);
      expect(resultado.filas.single['cedula'], '00123');
      expect(resultado.filas.single['sku'], '00012');
      expect(resultado.unidades, 2);
    },
  );
  test(
    'Detecta encabezados normalizados y conserva identificadores de texto',
    () {
      final resultado = parsearMasivaExcel(
        libro({
          'Base libre': [
            [
              ' le ',
              '#',
              'Cédula',
              ' NOMBRE  COMPLETO ',
              'Código',
              'Material Descripcion',
              'Cantidad a enviar',
              'FECHA EMPAQUE',
            ],
            [
              '001',
              1,
              '000123',
              'Persona de prueba',
              'SKU-001',
              'Camisa azul T. M',
              2,
              '2026-11-01',
            ],
          ],
        }),
        tipo: 'personal',
      );
      expect(resultado.errores, isEmpty);
      expect(resultado.kits, 1);
      expect(resultado.unidades, 2);
      expect(resultado.filas.single['cedula'], '000123');
      expect(resultado.filas.single['sku'], 'SKU-001');
      expect(resultado.filas.single['lista'], '001');
      expect(resultado.filas.single.keys, isNot(contains('FECHA EMPAQUE')));
    },
  );

  test('Recepción conserva cantidades y excluye subtotales y recibido', () {
    final resultado = parsearMasivaExcel(
      libro({
        'CONSOLIDADO': [
          [...recepcion, 'CANTIDAD RECIBIDA'],
          ['0001', 'Calzado', 8, 'OC01', 'Proveedor A', 7],
          [null, null, 8],
          ['0002', 'Camisa', 3, 'OC02', 'Proveedor B', 3],
        ],
      }),
      tipo: 'recepcion',
    );
    expect(resultado.valida, isTrue);
    expect(resultado.filas, hasLength(2));
    expect(resultado.unidades, 11);
    expect(resultado.filas.first['cantidad'], 8);
    expect(resultado.filas.first, isNot(contains('recibido')));
    expect(resultado.avisos.join(), contains('totales'));
  });

  test('Bloquea filas duplicadas y no las suma sin permiso', () {
    final fila = ['A', 1, '123', 'Persona', 'SKU1', 'Camisa', 1];
    final resultado = parsearMasivaExcel(
      libro({
        'Personal': [personal, fila, fila],
      }),
      tipo: 'personal',
    );
    expect(resultado.valida, isFalse);
    expect(resultado.errores.join(), contains('duplicado'));
  });

  test('Bloquea consecutivo compartido por dos personas', () {
    final resultado = parsearMasivaExcel(
      libro({
        'Personal': [
          personal,
          ['A', 1, '123', 'Persona A', 'SKU1', 'Camisa', 1],
          ['A', 1, '124', 'Persona B', 'SKU2', 'Pantalón', 1],
        ],
      }),
      tipo: 'personal',
    );
    expect(resultado.valida, isFalse);
    expect(resultado.errores.join(), contains('personas diferentes'));
  });

  test(
    'Bloquea nombres contradictorios en un kit y destinos distintos de una lista',
    () {
      final resultado = parsearMasivaExcel(
        libro({
          'Personal': [
            [
              ...personal,
              'Ciudad',
              'Sede',
              'Direccion',
              'Unidad Organizativa',
              'Lider / Encargado',
            ],
            [
              'A',
              1,
              '123',
              'Persona A',
              'SKU1',
              'Camisa',
              1,
              '',
              'Bogotá',
              'Principal',
              'Calle 1',
              'Salud',
              'Líder A',
            ],
            [
              'A',
              1,
              '123',
              'Persona B',
              'SKU2',
              'Pantalón',
              1,
              '',
              'Cali',
              'Alterna',
              'Calle 2',
              'Educación',
              'Líder B',
            ],
          ],
        }),
        tipo: 'personal',
      );
      expect(resultado.valida, isFalse);
      expect(resultado.errores.join(), contains('nombres diferentes'));
      for (final campo in ['ciudad', 'sede', 'direccion', 'unidad']) {
        expect(resultado.errores.join(), contains('en $campo'));
      }
      expect(resultado.errores.join(), isNot(contains('en lider')));
    },
  );

  test(
    'Admite varios responsables y diferencias de mayúsculas en el destino',
    () {
      final resultado = parsearMasivaExcel(
        libro({
          'Personal': [
            [...personal, 'Ciudad', 'Lider / Encargado'],
            [
              'A',
              1,
              '123',
              'Persona A',
              'SKU1',
              'Camisa',
              1,
              '',
              'Bogotá',
              'Líder A',
            ],
            [
              'A',
              2,
              '456',
              'Persona B',
              'SKU2',
              'Pantalón',
              1,
              '',
              ' BOGOTA ',
              'Líder B',
            ],
          ],
        }),
        tipo: 'personal',
      );
      expect(resultado.valida, isTrue);
      expect(resultado.avisos.join(), contains('varios líderes'));
    },
  );

  test('Lee caché de fórmulas y exige guardar resultados cuando faltan', () {
    final hojas = {
      'Personal': [
        personal,
        ['A', 1, '123', 'Persona', 'SKU1', 'Camisa', 1],
      ],
    };
    expect(
      parsearMasivaExcel(
        libro(hojas, formula: '1+2', cache: '3'),
        tipo: 'personal',
      ).unidades,
      3,
    );
    final sinCache = parsearMasivaExcel(
      libro(hojas, formula: '1+2'),
      tipo: 'personal',
    );
    expect(sinCache.valida, isFalse);
    expect(sinCache.errores.join(), contains('fórmula sin resultado'));
  });

  test('Bloquea cantidades cero, fraccionadas y proveedor ausente', () {
    final resultado = parsearMasivaExcel(
      libro({
        'CONSOLIDADO': [
          recepcion,
          ['SKU1', 'Camisa', 0, 'OC1', 'Proveedor'],
          ['SKU2', 'Pantalón', 1.5, 'OC1', 'Proveedor'],
          ['SKU3', 'Calzado', 1, 'OC1', null],
        ],
      }),
      tipo: 'recepcion',
    );
    expect(resultado.valida, isFalse);
    expect(resultado.filas, isEmpty);
    expect(resultado.errores.length, greaterThanOrEqualTo(3));
  });

  test(
    '30.000 filas se leen fuera del hilo principal sin alterar totales',
    () async {
      final bytes = libro({
        'Personal': [
          personal,
          for (var i = 1; i <= 30000; i++)
            ['1', i, 'DOC$i', 'Persona de prueba $i', 'SKU1', 'Camisa', 1],
        ],
      });
      final resultado = await leerMasivaExcel(bytes, tipo: 'personal');
      expect(resultado.valida, isTrue);
      expect(resultado.filas, hasLength(30000));
      expect(resultado.kits, 30000);
      expect(resultado.unidades, 30000);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
