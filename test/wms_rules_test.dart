import 'package:flutter_test/flutter_test.dart';

import '../lib/core/result.dart';
import '../lib/data/in_memory_wms_repository.dart';
import '../lib/domain/models.dart';
import '../lib/domain/qr_prenda.dart';

const _xs = '19249|ORD-001-ENE|2025289514|XS'; // pedida 9, producido 9 (límite alcanzado)
const _s = '19249|ORD-001-ENE|2025289515|S'; // pedida 264, producido 100, stock A1 = 30

void main() {
  group('QrPrenda', () {
    test('parsea un QR válido', () {
      final qr = QrPrenda.tryParse('19249;ENEL;2025289514;TSHIRT;XS;ORD-001-ENE');
      expect(qr, isNotNull);
      expect(qr!.itemId, _xs);
    });

    test('rechaza QR incompleto o con campos vacíos', () {
      expect(QrPrenda.tryParse('19249;ENEL'), isNull);
      expect(QrPrenda.tryParse('19249;ENEL;2025289514;;XS;ORD-001-ENE'), isNull);
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
