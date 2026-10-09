import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/core/result.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';

void main() {
  test('No conforme rechaza más que el stock y no altera el saldo', () async {
    final repo = InMemoryWmsRepository.seeded();
    addTearDown(repo.dispose);
    final antes = await repo.cargarSnapshot();
    final k = antes.kardex.firstWhere(
      (x) => x.stockDisponible > 0 && x.producido > x.stockDisponible,
    );
    final n = (await repo.cargarDevoluciones()).length;
    final rechazo = await repo.registrarNoConforme(
      itemId: k.id,
      cantidad: k.stockDisponible + 1,
      causalId: 'TEST',
      operario: 'TEST',
      recibidoDeProduccion: 'TEST',
    );
    expect(rechazo, isA<Err>());
    expect((await repo.cargarDevoluciones()).length, n);
    expect(
      (await repo.cargarSnapshot()).kardexPorId(k.id)!.stockDisponible,
      k.stockDisponible,
    );
    final ok = await repo.registrarNoConforme(
      itemId: k.id,
      cantidad: k.stockDisponible,
      causalId: 'TEST',
      operario: 'TEST',
      recibidoDeProduccion: 'TEST',
    );
    expect(ok, isA<Ok>());
    expect((await repo.cargarSnapshot()).kardexPorId(k.id)!.stockDisponible, 0);
  });
}
