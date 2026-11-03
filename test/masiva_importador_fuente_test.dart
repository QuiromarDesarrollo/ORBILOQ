import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/masiva/masiva_importador_parser.dart';
import 'masiva_importador_test.dart' show libro, personal;

const encabezadosFuente = [
  'LE',
  'Logistica',
  'Entrega',
  '#',
  'Cedula',
  'Nombre Completo',
  'Unidad Directiva',
  'Gerencia',
  'Unidad Organizativa',
  'Cargo',
  'Prenda',
  'Codigo',
  'Material Descripcion',
  'Cantidad a enviar',
  'Regional',
  'Departamento',
  'Ciudad',
  'Sede',
  'Direccion',
  'Lider / Encargado',
  'ITEMS KITS',
  'SECTOR',
  'ITEMS LE',
  'ITEMS DIRECCION',
  'FECHA EMPAQUE',
  'FECHA ENTREGA',
];

const camposFuente = {
  'lista',
  'logistica',
  'entrega',
  'numero_persona',
  'cedula',
  'nombre',
  'unidad_directiva',
  'gerencia',
  'unidad',
  'cargo',
  'prenda',
  'sku',
  'descripcion',
  'cantidad',
  'regional',
  'departamento',
  'ciudad',
  'sede',
  'direccion',
  'lider',
  'items_kit',
  'sector',
  'items_lista',
  'items_direccion',
  'fecha_empaque_programada',
  'fecha_entrega_programada',
};

void main() {
  test(
    'Conserva las 26 columnas sin cambiar cantidades ni identificadores',
    () {
      final result = parsearMasivaExcel(
        libro({
          'Base fuente': [
            encabezadosFuente,
            [
              '0001',
              'Ruta A',
              'Directa',
              1,
              '000123',
              'Persona de prueba',
              'Dirección',
              'Gerencia A',
              'Unidad A',
              '',
              'Camisa',
              '000045',
              'Camisa azul T. M',
              2,
              'Centro',
              'Departamento A',
              'Ciudad A',
              'Sede A',
              'Dirección A',
              'Responsable A',
              1,
              'Sector A',
              null,
              0,
              46023,
              46024,
            ],
          ],
        }),
        tipo: 'personal',
      );
      expect(result.errores, isEmpty);
      final row = result.filas.single;
      final fuente = Map<String, dynamic>.from(row['fuente'] as Map);
      expect(fuente.keys.toSet(), camposFuente);
      expect(row['hoja_origen'], 'Base fuente');
      expect(row['fila_origen'], 2);
      expect(row['cantidad'], 2);
      expect(row['lista'], '0001');
      expect(row['cedula'], '000123');
      expect(row['sku'], '000045');
      expect(fuente['sku'], '000045');
      expect(fuente['cedula'], '000123');
      expect(fuente['cargo'], '');
      expect(fuente['items_kit'], 1);
      expect(fuente['items_lista'], isNull);
      expect(fuente['items_direccion'], 0);
      expect(fuente['fecha_empaque_programada'], '2026-01-01T00:00:00.000Z');
      expect(fuente['fecha_entrega_programada'], '2026-01-02T00:00:00.000Z');
      expect(row.keys.where((key) => key.startsWith('fecha_')), isEmpty);
      expect(result.unidades, 2);
      expect(result.kits, 1);
    },
  );

  test(
    'Retiene encabezados desconocidos repetidos y calendario Excel 1904',
    () {
      final result = parsearMasivaExcel(
        libro({
          'Personal': [
            [...personal, 'Zona especial', 'Zona especial', null],
            [
              'L1',
              1,
              'DOC1',
              'Persona',
              'SKU-1',
              'Camisa',
              1,
              1,
              'Primera',
              'Segunda',
              'Sin encabezado',
            ],
          ],
        }, usa1904: true),
        tipo: 'personal',
      );
      expect(result.errores, isEmpty);
      final fuente = result.filas.single['fuente'] as Map;
      expect(fuente['zona_especial'], 'Primera');
      expect(fuente['zona_especial_columna_10'], 'Segunda');
      expect(fuente['columna_11'], 'Sin encabezado');
      expect(fuente['fecha_empaque_programada'], '1904-01-02T00:00:00.000Z');
    },
  );

  test('Una columna sin nombre no reemplaza un encabezado existente', () {
    final result = parsearMasivaExcel(
      libro({
        'Personal': [
          [...personal, 'Columna 10', null],
          [
            'L1',
            1,
            'DOC1',
            'Persona',
            'SKU-1',
            'Camisa',
            1,
            '',
            'Con nombre',
            'Sin nombre',
          ],
        ],
      }),
      tipo: 'personal',
    );
    expect(result.errores, isEmpty);
    final fuente = result.filas.single['fuente'] as Map;
    expect(fuente['columna_10'], 'Con nombre');
    expect(fuente['columna_10_columna_10'], 'Sin nombre');
  });

  final ejemplo = File('D:/DESCARGAS/Base Distribucion Masiva 2 2026.xlsx');
  test(
    'Base real conserva 29.361 filas y sus 26 campos de origen',
    () async {
      final result = parsearMasivaExcel(
        await ejemplo.readAsBytes(),
        tipo: 'personal',
      );
      expect(result.errores.length, 0);
      expect(result.filas.length, 29361);
      expect(result.unidades, 32812);
      expect(result.kits, 8749);
      expect(result.listas, 1015);
      expect(
        result.filas.every(
          (r) => (r['fuente'] as Map).keys.toSet().containsAll(camposFuente),
        ),
        isTrue,
      );
      expect(
        result.filas.every((r) => r['hoja_origen'] == 'Masiva 2 2026'),
        isTrue,
      );
      expect(result.filas.first['fila_origen'], 2);
      expect(result.filas.last['fila_origen'], 29362);
      final noVacios = <String, int>{};
      for (final field in [
        'cargo',
        'items_kit',
        'items_lista',
        'items_direccion',
      ]) {
        noVacios[field] =
            result.filas.where((r) {
              final value = (r['fuente'] as Map)[field];
              return value != null && value.toString().trim().isNotEmpty;
            }).length;
      }
      expect(noVacios, {
        'cargo': 28160,
        'items_kit': 8749,
        'items_lista': 1015,
        'items_direccion': 675,
      });
      expect(
        result.filas.every((r) => (r['fuente'] as Map)['sku'] is String),
        isTrue,
      );
      expect(
        result.filas.every((r) => (r['fuente'] as Map)['cedula'] is String),
        isTrue,
      );
    },
    skip: !ejemplo.existsSync(),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
