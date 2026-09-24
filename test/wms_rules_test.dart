import 'dart:typed_data';

import 'package:excel/excel.dart' as xlsx;
import 'package:flutter_test/flutter_test.dart';

import 'package:orbiloq_wms/core/result.dart';
import 'package:orbiloq_wms/data/excel_ordenes_parser.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/domain/qr_prenda.dart';

const _xs = '19249|ORD-001-ENE|2025289514|XS'; // pedida 9, producido 9 (límite alcanzado)
const _s = '19249|ORD-001-ENE|2025289515|S'; // pedida 264, producido 100, stock A1 = 30
const _bata = '18353|OC-9920|CLSBAOCD20|L'; // pedida 45, producido 20, pendiente 25

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
      expect(await repo.crearLote(items: [ItemCantidad(itemId: _xs, cantidad: 1)], operario: 'X'), isA<Err>());
      expect(await repo.crearLote(items: [ItemCantidad(itemId: _s, cantidad: 165)], operario: 'X'), isA<Err>());
      expect(await repo.crearLote(items: [ItemCantidad(itemId: _s, cantidad: 164)], operario: 'X'), isA<Ok>());
    });

    test('no se entrega un producto inexistente ni cantidades <= 0', () async {
      expect(await repo.crearLote(items: [ItemCantidad(itemId: 'nope', cantidad: 1)], operario: 'X'), isA<Err>());
      expect(await repo.crearLote(items: [ItemCantidad(itemId: _s, cantidad: 0)], operario: 'X'), isA<Err>());
    });

    test('no permite lotes duplicados', () async {
      final r = await repo.crearLote(
        items: [ItemCantidad(itemId: _s, cantidad: 1)], operario: 'X', numeroLote: 'LOTE-096',
      );
      expect(r, isA<Err>());
    });

    test('crear_lote es todo o nada: si un producto falla, no se crea ninguna línea', () async {
      final antes = await kardex(_xs);
      final res = await repo.crearLote(
        items: [
          ItemCantidad(itemId: _s, cantidad: 1), // válido por sí solo
          ItemCantidad(itemId: _xs, cantidad: 999), // excede el límite
        ],
        operario: 'X',
      );
      expect(res, isA<Err>());
      final despues = await kardex(_xs);
      expect(despues.producido, antes.producido); // nada cambió, ni siquiera lo válido
    });

    test('la numeración automática no colisiona', () async {
      final a = await repo.crearLote(items: [ItemCantidad(itemId: _s, cantidad: 1)], operario: 'X');
      final b = await repo.crearLote(items: [ItemCantidad(itemId: _s, cantidad: 1)], operario: 'X');
      expect((a as Ok<Lote>).value.id, isNot((b as Ok<Lote>).value.id));
    });

    test('un lote con varias líneas queda parcial hasta que se reciben todas sus líneas', () async {
      final creado = await repo.crearLote(
        items: [ItemCantidad(itemId: _s, cantidad: 5), ItemCantidad(itemId: _bata, cantidad: 5)],
        operario: 'X',
      );
      final lote = (creado as Ok<Lote>).value;
      expect(lote.lineas.length, 2);
      expect(lote.lineasPendientes, 2);

      await repo.recibirLoteLinea(loteLineaId: lote.lineas[0].id, cantidad: 5, ubicacion: 'ESTANTE A1');
      final snap1 = await repo.watch().first;
      expect(snap1.lotes.firstWhere((l) => l.id == lote.id).estado, EstadoLote.recibidoParcial);

      await repo.recibirLoteLinea(loteLineaId: lote.lineas[1].id, cantidad: 5, ubicacion: 'ESTANTE A1');
      final snap2 = await repo.watch().first;
      expect(snap2.lotes.firstWhere((l) => l.id == lote.id).estado, EstadoLote.recibidoCompleto);
    });

    test('la recepción con faltante genera novedad y actualiza el stock', () async {
      final snap = await repo.watch().first;
      final linea = snap.lotes.firstWhere((l) => l.id == 'LOTE-101').lineas.first;

      final res = await repo.recibirLoteLinea(loteLineaId: linea.id, cantidad: 3, ubicacion: 'RACK C3');
      final actualizada = (res as Ok<LoteLinea>).value;
      expect(actualizada.estado, EstadoLineaLote.recibidoConNovedad);
      expect(actualizada.novedad, contains('FALTANTE'));

      final k = await kardex(_xs);
      expect(k.recibido, 8);
      expect(k.stockEn('RACK C3'), 3);
    });

    test('una línea de lote no se puede recibir dos veces', () async {
      final snap = await repo.watch().first;
      final linea = snap.lotes.firstWhere((l) => l.id == 'LOTE-101').lineas.first;

      await repo.recibirLoteLinea(loteLineaId: linea.id, cantidad: 4, ubicacion: 'RACK C3');
      final again = await repo.recibirLoteLinea(loteLineaId: linea.id, cantidad: 4, ubicacion: 'RACK C3');
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

  group('ExcelOrdenesParser (bytes reales de .xlsx)', () {
    // Esta prueba existe porque un bug real (encabezados que no se
    // reconocían por diferencias de mayúsculas/tildes) pasó sin detectarse
    // porque nunca se probó el parser contra un archivo Excel de verdad,
    // solo contra texto. Aquí se construye un .xlsx real en memoria.
    List<int> construirXlsxDePrueba() {
      final libro = xlsx.Excel.createExcel();

      final orden = libro['Orden'];
      // Encabezados con mayúsculas/espacios distintos a los del diccionario
      // interno, a propósito, para probar la normalización.
      orden.appendRow([
        xlsx.TextCellValue('IDENTIFICADOR'),
        xlsx.TextCellValue(' Cliente '),
        xlsx.TextCellValue('CANTIDAD'),
      ]);
      orden.appendRow([
        xlsx.IntCellValue(25079),
        xlsx.TextCellValue('TV COLOMBIA DIGITAL'),
        xlsx.IntCellValue(15),
      ]);

      final tallas = libro['Tallas'];
      tallas.appendRow([
        xlsx.TextCellValue('identificador orden'), // minúsculas
        xlsx.TextCellValue('CODIGO'), // sin tilde, mayúsculas (la clave real es "Código")
        xlsx.TextCellValue('TALLAS NOMBRE'),
        xlsx.TextCellValue('cantidad'),
      ]);
      tallas.appendRow([
        xlsx.IntCellValue(25079),
        // Código como celda numérica con decimales, para probar que no
        // quede guardado como "202674809.0".
        xlsx.DoubleCellValue(202674809),
        xlsx.TextCellValue('S/8'),
        xlsx.IntCellValue(15),
      ]);

      libro.delete('Sheet1');
      final bytes = libro.encode();
      if (bytes == null) {
        fail('No se pudo generar el .xlsx de prueba');
      }
      return bytes;
    }

    test('reconoce encabezados aunque vengan con mayúsculas/tildes distintas', () {
      final bytes = Uint8List.fromList(construirXlsxDePrueba());
      final parseado = ExcelOrdenesParser.parsear(bytes);

      expect(parseado.ordenes.length, 1);
      expect(parseado.ordenes.first['identificador'], '25079');
      expect(parseado.ordenes.first['cliente'], 'TV COLOMBIA DIGITAL');

      expect(parseado.tallas.length, 1);
      expect(parseado.tallas.first['identificador_orden'], '25079');
      expect(parseado.tallas.first['talla'], 'S/8');
    });

    test('un código numérico no queda con ".0" pegado al final', () {
      final bytes = Uint8List.fromList(construirXlsxDePrueba());
      final parseado = ExcelOrdenesParser.parsear(bytes);

      expect(parseado.tallas.first['codigo'], '202674809');
    });

    test('avisa claramente si falta una columna requerida, en vez de fallar en silencio', () {
      final libro = xlsx.Excel.createExcel();
      final orden = libro['Orden'];
      // Sin columna "Identificador": debe fallar de forma explícita.
      orden.appendRow([xlsx.TextCellValue('Cliente'), xlsx.TextCellValue('Cantidad')]);
      orden.appendRow([xlsx.TextCellValue('ACME'), xlsx.IntCellValue(1)]);
      libro['Tallas'].appendRow([xlsx.TextCellValue('Identificador orden')]);
      libro.delete('Sheet1');
      final bytes = Uint8List.fromList(libro.encode()!);

      expect(
        () => ExcelOrdenesParser.parsear(bytes),
        throwsA(isA<ExcelOrdenesParseException>()),
      );
    });
  });
}
