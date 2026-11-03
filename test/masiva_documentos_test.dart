import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/masiva/masiva_documentos.dart';

Map<String, dynamic> snapshotMasiva({int kits = 45, bool parcial = true}) => {
  'operacion': {
    'nombre': 'Dotación Masiva II 2026',
    'cliente': 'Cliente de prueba',
  },
  'lista': {
    'lista': '88',
    'sede': 'Centro médico de prueba',
    'ciudad': 'Bogotá D.C.',
    'direccion': 'Avenida Calle 145 # 92-30, Centro Comercial, local 209',
    'unidad': 'Servicios de salud',
    'responsable': 'Responsable de prueba',
    'sector': 'Norte',
  },
  'responsable': 'Responsable de prueba',
  'version': 3,
  'fecha': '2026-10-27T16:00:00Z',
  'kits': [
    for (var i = 1; i <= kits; i++)
      {
        'id': '$i',
        'numero_persona': i,
        'cedula': '001234${i.toString().padLeft(2, '0')}',
        'nombre': 'Colaborador de prueba $i',
        'caja': i <= 20 ? 1 : 2,
        'articulos': [
          {
            'sku': '00001',
            'descripcion': 'Camisa manga larga azul, talla M',
            'cantidad': 2,
            'validado': 2,
          },
          {
            'sku': '00002',
            'descripcion': 'Pantalón de trabajo azul, talla 32',
            'cantidad': 1,
            'validado': parcial && i == 1 ? 0 : 1,
          },
          {
            'sku': '00003',
            'descripcion': 'Calzado de seguridad, talla 39 (par)',
            'cantidad': 1,
            'validado': 1,
          },
        ],
      },
  ],
  'empaques': [
    {
      'numero': 1,
      'empaque_snapshot': {
        'nombre': 'Caja mediana',
        'tipo': 'caja',
        'peso_vacio': .5,
        'peso_lleno': 12,
      },
    },
    {
      'numero': 2,
      'empaque_snapshot': {
        'nombre': 'Bolsa resistente',
        'tipo': 'bolsa',
        'peso_vacio': .1,
        'peso_lleno': 8,
      },
    },
    {
      'numero': 3,
      'empaque_snapshot': {
        'nombre': 'Caja vacía',
        'tipo': 'caja',
        'peso_vacio': .5,
        'peso_lleno': 12,
      },
    },
  ],
};
int paginas(Uint8List bytes) =>
    RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'La lista individual usa número y periodo de la masiva en el nombre',
    () {
      final datos = snapshotMasiva();
      (datos['lista'] as Map<String, dynamic>)['lista'] = '523';
      (datos['operacion'] as Map<String, dynamic>)['nombre'] =
          'MASIVA III 2026 · Colsubsidio';
      expect(nombreArchivoListaMasiva(datos), 'LE 523 MSV III 2026.pdf');
      (datos['operacion'] as Map<String, dynamic>)['nombre'] =
          'Dotación Masiva II 2026';
      expect(nombreArchivoListaMasiva(datos), 'LE 523 MSV II 2026.pdf');
    },
  );
  test('Lista carta horizontal multipágina con anexo de faltantes', () async {
    final datos = snapshotMasiva();
    final original = jsonEncode(datos);
    final bytes = await generarListaMasiva(datos);
    expect(latin1.decode(bytes).startsWith('%PDF-'), isTrue);
    expect(paginas(bytes), greaterThan(2));
    expect(
      RegExp(r'/MediaBox\s*\[0 0 792 612\]').hasMatch(latin1.decode(bytes)),
      isTrue,
    );
    expect(
      jsonEncode(datos),
      original,
      reason: 'El generador no modifica el snapshot histórico.',
    );
  });
  test('Agrupa líneas y constancia cuando coinciden los documentos', () async {
    final datos = snapshotMasiva(kits: 1, parcial: false);
    final original = (datos['kits'] as List).single as Map<String, dynamic>;
    final repetido =
        Map<String, dynamic>.from(original)
          ..['id'] = 'repetido'
          ..['numero_persona'] = 2
          ..['caja'] = 1
          ..['articulos'] = [
            {
              'sku': '00004',
              'descripcion': 'Camisa adicional de prueba, talla M',
              'cantidad': 1,
              'validado': 1,
            },
          ];
    datos['kits'] = <Map<String, dynamic>>[
      for (final kit in datos['kits'] as List)
        Map<String, dynamic>.from(kit as Map),
      repetido,
    ];
    expect(paginas(await generarListaMasiva(datos)), 1);
  });
  test('Rótulos de 10x10 solo para los empaques con contenido', () async {
    final bytes = await generarRotulosMasiva(snapshotMasiva());
    expect(paginas(bytes), 2);
    expect(latin1.decode(bytes).contains('283.46457'), isTrue);
  });
  test(
    'Reimpresiones ignoran logos configurados en snapshots antiguos',
    () async {
      final datos = snapshotMasiva(kits: 1, parcial: false);
      (datos['operacion'] as Map)
        ..['logo_cliente'] = 'logo antiguo no válido'
        ..['logo_empresa'] = 'logo antiguo no válido';
      expect(paginas(await generarListaMasiva(datos)), 1);
      expect(paginas(await generarRotulosMasiva(datos)), 1);
    },
  );
  test(
    'Rótulos masivos conservan contenedores y snapshots de cada lista',
    () async {
      final listas = [snapshotMasiva(), snapshotMasiva(kits: 1)];
      (listas.last['lista'] as Map)['lista'] = '89';
      final original = jsonEncode(listas);
      final bytes = await generarRotulosMasivosMasiva(listas);
      expect(paginas(bytes), 3);
      expect(jsonEncode(listas), original);
      await expectLater(generarRotulosMasivosMasiva([]), throwsFormatException);
    },
  );
  test('Listas masivas separan cada lista en páginas independientes', () async {
    final primera = snapshotMasiva(kits: 1, parcial: false);
    final segunda = snapshotMasiva(kits: 1, parcial: false);
    (primera['lista'] as Map)['lista'] = '88';
    (segunda['lista'] as Map)['lista'] = '89';
    final bytes = await generarListasMasivasMasiva([primera, segunda]);
    expect(paginas(bytes), 2);
    await expectLater(
      generarListasMasivasMasiva([primera]),
      throwsFormatException,
    );
  });
  test('No acredita entregas sin validación o sin caja', () async {
    final datos = snapshotMasiva(kits: 1);
    final kit = (datos['kits'] as List).first as Map;
    kit['caja'] = '';
    await expectLater(generarListaMasiva(datos), throwsFormatException);
    await expectLater(generarRotulosMasiva(datos), throwsFormatException);
    kit['caja'] = 1;
    for (final a in kit['articulos'] as List) {
      a['validado'] = 0;
    }
    await expectLater(generarListaMasiva(datos), throwsFormatException);
  });
  test(
    'Exportación Excel conserva SKU/documento y no ejecuta fórmulas',
    () async {
      final bytes = await generarExcelMasiva([
        {
          'sku': '00001',
          'cedula': '00123',
          'nombre': '=HYPERLINK("https://ejemplo.invalid")',
          'cantidad': 3,
        },
      ]);
      final libro = Excel.decodeBytes(bytes);
      final fila = libro['Masiva'].rows[1];
      expect(fila[0]!.value, TextCellValue('00001'));
      expect(fila[1]!.value, TextCellValue('00123'));
      expect(fila[2]!.value, isA<TextCellValue>());
      expect(fila[3]!.value, IntCellValue(3));
    },
  );
}
