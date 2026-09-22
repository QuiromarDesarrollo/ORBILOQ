#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Corrige codigos numericos con '.0' al leer el Excel (v6)
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_fix_codigo_numerico_v6.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi

echo "Aplicando correccion..."

echo "  - lib/data/excel_ordenes_parser.dart"
mkdir -p "$(dirname 'lib/data/excel_ordenes_parser.dart')"
cat > 'lib/data/excel_ordenes_parser.dart' << 'ORBILOQ_EOF'
import 'dart:typed_data';

import 'package:excel/excel.dart';

/// Fila ya interpretada de la hoja "Orden" (una por Orden de Producción).
typedef FilaOrden = Map<String, String?>;

/// Fila ya interpretada de la hoja "Tallas" (una por OP + código + talla).
typedef FilaTalla = Map<String, String?>;

class ExcelOrdenesParseException implements Exception {
  ExcelOrdenesParseException(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

class ExcelOrdenesParseado {
  const ExcelOrdenesParseado({required this.ordenes, required this.tallas});
  final List<FilaOrden> ordenes;
  final List<FilaTalla> tallas;
}

/// Nombres de columna esperados en cada hoja -> clave interna que usa el RPC.
/// Se busca por nombre de encabezado (no por posición), para tolerar que el
/// Excel del ERP cambie el orden de las columnas entre exportaciones.
/// Nombres de columna esperados en cada hoja -> clave interna que usa el RPC.
/// Se busca por nombre de encabezado normalizado (sin tildes, sin distinguir
/// mayúsculas/minúsculas), no por posición, para tolerar que el Excel del ERP
/// cambie el orden o la escritura exacta de las columnas entre exportaciones
/// (ej. "OBSERVACION" en un archivo, "Observación" en otro).
String _normalizarEncabezado(String s) {
  var r = s.trim().toUpperCase();
  const conTilde = 'ÁÉÍÓÚÑ';
  const sinTilde = 'AEIOUN';
  for (var i = 0; i < conTilde.length; i++) {
    r = r.replaceAll(conTilde[i], sinTilde[i]);
  }
  return r;
}

final _columnasOrden = <String, String>{
  for (final e in {
    'Identificador': 'identificador',
    'Tipo de orden': 'tipo_orden',
    'Estado': 'estado',
    'Fecha solicitud': 'fecha_solicitud',
    'Fecha inicio': 'fecha_inicio',
    'Fecha comprometida': 'fecha_comprometida',
    'Fecha acordada': 'fecha_acordada',
    'Fecha entrega': 'fecha_entrega',
    'Fecha planeación': 'fecha_planeacion',
    'Nombre ficha técnica': 'nombre_ficha_tecnica',
    'Cliente': 'cliente',
    'No. OC': 'oc_cabecera',
    'Nombre prenda': 'nombre_prenda_resumen',
    'Cantidad': 'cantidad_total_erp',
    'Observaciones': 'observaciones',
    'Movimiento': 'etapa_movimiento',
    'Fecha inicio movimiento': 'fecha_inicio_movimiento',
    'Fecha planeada': 'fecha_planeada_movimiento',
    'Estado movimientos': 'estado_movimiento_erp',
    'Id. OC': 'oc_id_erp',
  }.entries)
    _normalizarEncabezado(e.key): e.value,
};

final _columnasTallas = <String, String>{
  for (final e in {
    'Identificador orden': 'identificador_orden',
    'CLIENTE': 'cliente',
    'Código': 'codigo',
    'Descripción': 'descripcion',
    'Tallas nombre': 'talla',
    'Cantidad': 'cantidad',
    'NO. OC': 'oc',
    'OC ID': 'oc_id_erp',
    'OBSERVACION': 'observacion',
    'Observación': 'observacion',
  }.entries)
    _normalizarEncabezado(e.key): e.value,
};

/// Lee el archivo (bytes de un .xlsx) y devuelve las filas de ambas hojas ya
/// mapeadas a claves consistentes. Lanza [ExcelOrdenesParseException] con un
/// mensaje entendible si el archivo no tiene el formato esperado.
class ExcelOrdenesParser {
  static ExcelOrdenesParseado parsear(Uint8List bytes) {
    late final Excel libro;
    try {
      libro = Excel.decodeBytes(bytes);
    } catch (_) {
      throw ExcelOrdenesParseException(
        'No se pudo leer el archivo. Verifica que sea un .xlsx válido '
        '(si el original es .xls, ábrelo en Excel y usa "Guardar como" → .xlsx).',
      );
    }

    final nombreHojaOrden = _buscarHoja(libro, 'Orden');
    final nombreHojaTallas = _buscarHoja(libro, 'Tallas');
    if (nombreHojaOrden == null || nombreHojaTallas == null) {
      throw ExcelOrdenesParseException(
        'El archivo debe tener las hojas "Orden" y "Tallas". '
        'Hojas encontradas: ${libro.tables.keys.join(", ")}',
      );
    }

    final ordenes = _leerHoja(libro.tables[nombreHojaOrden]!, _columnasOrden);
    final tallas = _leerHoja(libro.tables[nombreHojaTallas]!, _columnasTallas);

    if (ordenes.isEmpty) {
      throw ExcelOrdenesParseException('La hoja "Orden" no tiene filas de datos.');
    }

    return ExcelOrdenesParseado(ordenes: ordenes, tallas: tallas);
  }

  static String? _buscarHoja(Excel libro, String nombreAproximado) {
    for (final nombre in libro.tables.keys) {
      if (nombre.trim().toLowerCase() == nombreAproximado.toLowerCase()) return nombre;
    }
    return null;
  }

  static List<Map<String, String?>> _leerHoja(Sheet hoja, Map<String, String> columnas) {
    if (hoja.maxRows == 0) return const [];

    final encabezados = hoja.rows.first;
    final indicePorClave = <String, int>{};
    for (var i = 0; i < encabezados.length; i++) {
      final texto = _texto(encabezados[i]?.value)?.trim();
      if (texto == null) continue;
      final clave = columnas[texto];
      if (clave != null) indicePorClave[clave] = i;
    }

    final filas = <Map<String, String?>>[];
    for (var f = 1; f < hoja.rows.length; f++) {
      final fila = hoja.rows[f];
      // Saltar filas completamente vacías.
      final vacia = fila.every((c) => _texto(c?.value)?.trim().isEmpty ?? true);
      if (vacia) continue;

      final mapa = <String, String?>{};
      for (final entrada in indicePorClave.entries) {
        final idx = entrada.value;
        final celda = idx < fila.length ? fila[idx]?.value : null;
        mapa[entrada.key] = _valorParaColumna(entrada.key, celda);
      }
      filas.add(mapa);
    }
    return filas;
  }

  /// Fechas se devuelven como texto ISO (yyyy-MM-dd) para que Postgres las
  /// pueda castear directo con `::date`. El resto de columnas, como texto.
  static String? _valorParaColumna(String clave, CellValue? valor) {
    if (clave.startsWith('fecha')) return _fechaIso(valor);
    return _texto(valor)?.trim();
  }

  static String? _texto(CellValue? valor) {
    if (valor == null) return null;
    try {
      return switch (valor) {
        TextCellValue v => v.value.toString(),
        IntCellValue v => v.value.toString(),
        // Un código como 202674809 puede venir como celda numérica (no texto).
        // Si es un número entero, se muestra sin decimales ("202674809", no
        // "202674809.0"), para que coincida con el mismo código tal como
        // viene en el QR.
        DoubleCellValue v => _formatearNumero(v.value),
        BoolCellValue v => v.value.toString(),
        _ => valor.toString(),
      };
    } catch (_) {
      return valor.toString();
    }
  }

  static String _formatearNumero(double d) {
    if (d.isFinite && d == d.roundToDouble() && d.abs() < 1e15) {
      return d.toStringAsFixed(0);
    }
    return d.toString();
  }

  static String? _fechaIso(CellValue? valor) {
    if (valor == null) return null;
    try {
      DateTime? dt;
      if (valor is DateCellValue) {
        dt = DateTime(valor.year, valor.month, valor.day);
      } else if (valor is DateTimeCellValue) {
        dt = DateTime(valor.year, valor.month, valor.day, valor.hour, valor.minute, valor.second);
      }
      if (dt != null) {
        final y = dt.year.toString().padLeft(4, '0');
        final m = dt.month.toString().padLeft(2, '0');
        final d = dt.day.toString().padLeft(2, '0');
        return '$y-$m-$d';
      }
    } catch (_) {
      // sigue abajo e intenta interpretar como texto
    }
    // Último recurso: si viene como texto tipo "2026-07-08 00:00:00".
    final texto = _texto(valor)?.trim();
    if (texto == null || texto.isEmpty) return null;
    final parseada = DateTime.tryParse(texto);
    if (parseada == null) return null;
    final y = parseada.year.toString().padLeft(4, '0');
    final m = parseada.month.toString().padLeft(2, '0');
    final d = parseada.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
ORBILOQ_EOF

echo "  - test/wms_rules_test.dart"
mkdir -p "$(dirname 'test/wms_rules_test.dart')"
cat > 'test/wms_rules_test.dart' << 'ORBILOQ_EOF'
import 'package:flutter_test/flutter_test.dart';

import 'package:orbiloq_wms/core/result.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/domain/qr_prenda.dart';

const _xs = '19249|ORD-001-ENE|2025289514|XS'; // pedida 9, producido 9 (límite alcanzado)
const _s = '19249|ORD-001-ENE|2025289515|S'; // pedida 264, producido 100, stock A1 = 30

void main() {
  group('QrPrenda', () {
    test('parsea un QR válido con el formato real de la marquilla', () {
      final qr = QrPrenda.tryParse(
        'https://orbiloq.app/qr?;19249;2025289514;TSHIRT MANGA CORTA T. XS;ENEL;ORD-001-ENE;ID0001',
      );
      expect(qr, isNotNull);
      expect(qr!.op, '19249');
      expect(qr.codigo, '2025289514');
      expect(qr.cliente, 'ENEL');
      expect(qr.noOc, 'ORD-001-ENE');
    });

    test('parsea un QR real donde la OP queda pegada a la URL, sin ; de por medio', () {
      // Caso real detectado: el '?' no va seguido de ';', la OP queda directo
      // pegada al final de la URL.
      final qr = QrPrenda.tryParse(
        'https://www.atom.bio/grupoquiromarsas?25079;202674809;'
        'BLUSA ADMINISTRATIVA DAMA  T. S/8;TV COLOMBIA DIGITAL;PEDIDO AGOSTO;ID0016',
      );
      expect(qr, isNotNull);
      expect(qr!.op, '25079');
      expect(qr.codigo, '202674809');
      expect(qr.cliente, 'TV COLOMBIA DIGITAL');
      expect(qr.noOc, 'PEDIDO AGOSTO');
    });

    test('rechaza QR incompleto o con OP/Código vacíos', () {
      expect(QrPrenda.tryParse('url;ENEL'), isNull);
      expect(QrPrenda.tryParse('url;;2025289514;TSHIRT;ENEL;ORD-001-ENE'), isNull);
    });
  });

  group('Reglas de negocio', () {
    late InMemoryWmsRepository repo;

    setUp(() => repo = InMemoryWmsRepository.seeded());
    tearDown(() => repo.dispose());

    Future<ItemKardex> kardex(String id) async =>
        (await repo.watch().first).kardexPorId(id)!;

    test('producción no puede superar la cantidad pedida', () async {
      expect(await repo.entregarLote(itemId: _xs, cantidad: 1, operario: 'X'), isA<Err>());
      expect(await repo.entregarLote(itemId: _s, cantidad: 165, operario: 'X'), isA<Err>());
      expect(await repo.entregarLote(itemId: _s, cantidad: 164, operario: 'X'), isA<Ok>());
    });

    test('no se entrega un producto inexistente ni cantidades <= 0', () async {
      expect(await repo.entregarLote(itemId: 'nope', cantidad: 1, operario: 'X'), isA<Err>());
      expect(await repo.entregarLote(itemId: _s, cantidad: 0, operario: 'X'), isA<Err>());
    });

    test('no permite remisiones duplicadas', () async {
      final r = await repo.entregarLote(itemId: _s, cantidad: 1, operario: 'X', numeroRemision: 'REM-097');
      expect(r, isA<Err>());
    });

    test('la numeración automática no colisiona', () async {
      final a = await repo.entregarLote(itemId: _s, cantidad: 1, operario: 'X');
      final b = await repo.entregarLote(itemId: _s, cantidad: 1, operario: 'X');
      expect((a as Ok<Remision>).value.id, isNot((b as Ok<Remision>).value.id));
    });

    test('la recepción con faltante genera novedad y actualiza el stock', () async {
      final res = await repo.recibirLote(remisionId: 'REM-101', cantidad: 3, ubicacion: 'RACK C3');
      final remision = (res as Ok<Remision>).value;
      expect(remision.estado, EstadoRemision.recibidoConNovedad);
      expect(remision.novedad, contains('FALTANTE'));

      final k = await kardex(_xs);
      expect(k.recibido, 8);
      expect(k.stockEn('RACK C3'), 3);
    });

    test('una remisión no se puede recibir dos veces', () async {
      await repo.recibirLote(remisionId: 'REM-101', cantidad: 4, ubicacion: 'RACK C3');
      final again = await repo.recibirLote(remisionId: 'REM-101', cantidad: 4, ubicacion: 'RACK C3');
      expect(again, isA<Err>());
    });

    test('el despacho valida el stock de la ubicación', () async {
      expect(await repo.despachar(itemId: _s, cantidad: 31, ubicacion: 'ESTANTE A1'), isA<Err>());
      expect(await repo.despachar(itemId: _s, cantidad: 1, ubicacion: 'RACK C3'), isA<Err>());
      expect(await repo.despachar(itemId: _s, cantidad: 30, ubicacion: 'ESTANTE A1'), isA<Ok>());

      final k = await kardex(_s);
      expect(k.despachado, 50);
      expect(k.stockDisponible, 0);
      expect(k.ubicaciones.containsKey('ESTANTE A1'), isFalse);
    });

    test('stockDisponible siempre coincide con la suma de ubicaciones', () async {
      final snap = await repo.watch().first;
      for (final k in snap.kardex) {
        expect(k.ubicaciones.values.fold<int>(0, (a, b) => a + b), k.stockDisponible);
      }
    });
  });
}
ORBILOQ_EOF

echo ""
echo "Listo. Siguiente paso:"
echo "  flutter analyze"
echo "  flutter test   (ahora deberian ser 11 pruebas)"
