import 'dart:async';

import '../core/constants.dart';
import '../core/result.dart';
import '../domain/models.dart';
import '../domain/wms_repository.dart';

class _Acumulado {
  int producido = 0;
  int recibido = 0;
  int despachado = 0;
  final Map<String, int> ubicaciones = {};
  DateTime? fechaEntrega;
  DateTime? fechaRecepcion;
}

/// Implementación en memoria basada en un libro de movimientos (ledger).
/// Todos los saldos se derivan de los movimientos: no hay contadores que puedan divergir.
class InMemoryWmsRepository implements WmsRepository {
  InMemoryWmsRepository._();

  factory InMemoryWmsRepository.seeded() => InMemoryWmsRepository._().._sembrar();

  /// Base de numeración automática de remisiones (en Supabase: secuencia de Postgres).
  static const _baseSecuencia = 104;

  final Map<String, ItemOrden> _items = {};
  final List<Movimiento> _movimientos = [];
  final List<Remision> _remisiones = []; // más recientes primero
  final StreamController<WmsSnapshot> _controller = StreamController.broadcast();

  // ---------------------------------------------------------------- lectura

  @override
  Stream<WmsSnapshot> watch() async* {
    yield _snapshot();
    yield* _controller.stream;
  }

  @override
  Future<void> refrescar() async => _emitir();

  @override
  void dispose() {
    _controller.close();
  }

  void _emitir() {
    if (!_controller.isClosed) _controller.add(_snapshot());
  }

  WmsSnapshot _snapshot() {
    final acc = {for (final id in _items.keys) id: _Acumulado()};

    for (final m in _movimientos) {
      final a = acc[m.itemId];
      if (a == null) continue;
      switch (m.tipo) {
        case TipoMovimiento.entregaProduccion:
          a.producido += m.cantidad;
          a.fechaEntrega = _masReciente(a.fechaEntrega, m.fecha);
        case TipoMovimiento.recepcion:
          a.recibido += m.cantidad;
          a.fechaRecepcion = _masReciente(a.fechaRecepcion, m.fecha);
          a.ubicaciones.update(m.ubicacion!, (v) => v + m.cantidad, ifAbsent: () => m.cantidad);
        case TipoMovimiento.despacho:
          a.despachado += m.cantidad;
          a.ubicaciones.update(m.ubicacion!, (v) => v - m.cantidad, ifAbsent: () => -m.cantidad);
      }
    }

    final kardex = [
      for (final e in _items.entries) _aKardex(e.value, acc[e.key]!),
    ];

    return WmsSnapshot(
      kardex: List.unmodifiable(kardex),
      remisiones: List.unmodifiable(_remisiones),
      proximaRemision: _proximoNumero(),
    );
  }

  ItemKardex _aKardex(ItemOrden item, _Acumulado a) {
    return ItemKardex(
      item: item,
      producido: a.producido,
      recibido: a.recibido,
      despachado: a.despachado,
      ubicaciones: Map.unmodifiable({
        for (final e in a.ubicaciones.entries)
          if (e.value > 0) e.key: e.value,
      }),
      fechaEntrega: a.fechaEntrega,
      fechaRecepcion: a.fechaRecepcion,
    );
  }

  DateTime _masReciente(DateTime? actual, DateTime nueva) =>
      actual == null || nueva.isAfter(actual) ? nueva : actual;

  String _proximoNumero() {
    var n = _baseSecuencia;
    while (_remisiones.any((r) => r.id == 'REM-$n')) {
      n++;
    }
    return 'REM-$n';
  }

  // -------------------------------------------------------------- comandos

  @override
  Future<Result<Remision>> entregarLote({
    required String itemId,
    required int cantidad,
    required String operario,
    String? numeroRemision,
  }) async {
    final item = _items[itemId];
    if (item == null) {
      return Err<Remision>('El producto no existe en el kardex.');
    }
    if (cantidad <= 0) {
      return Err<Remision>('La cantidad debe ser mayor a 0.');
    }
    final kardex = _snapshot().kardexPorId(itemId)!;
    if (cantidad > kardex.pendienteProduccion) {
      return Err<Remision>(
        'LÍMITE EXCEDIDO: solo faltan ${kardex.pendienteProduccion} Uds por producir.',
      );
    }

    var numero = (numeroRemision ?? '').trim().toUpperCase();
    if (numero.isEmpty) {
      numero = _proximoNumero();
    } else if (_remisiones.any((r) => r.id == numero)) {
      return Err<Remision>('La remisión $numero ya existe.');
    }

    final remision = _aplicarEntrega(item, cantidad, operario, numero, DateTime.now());
    _emitir();
    return Ok<Remision>(remision);
  }

  @override
  Future<Result<Remision>> recibirLote({
    required String remisionId,
    required int cantidad,
    required String ubicacion,
    String nota = '',
  }) async {
    final idx = _remisiones.indexWhere((r) => r.id == remisionId);
    if (idx == -1) return Err<Remision>('La remisión $remisionId no existe.');
    final remision = _remisiones[idx];
    if (!remision.enTransito) {
      return Err<Remision>('La remisión ${remision.id} ya fue procesada.');
    }
    if (cantidad < 0) return Err<Remision>('La cantidad no puede ser negativa.');
    if (!WmsConstantes.ubicaciones.contains(ubicacion)) {
      return Err<Remision>('Ubicación no válida: $ubicacion.');
    }

    final diff = cantidad - remision.cantidadEnviada;
    var novedad = '';
    if (diff < 0) {
      novedad = 'FALTANTE: Se recibieron $cantidad de ${remision.cantidadEnviada} Uds (faltaron ${-diff}).';
    } else if (diff > 0) {
      novedad = 'SOBRANTE: Se recibieron $cantidad de ${remision.cantidadEnviada} Uds (+$diff).';
    }
    final obs = nota.trim();
    if (obs.isNotEmpty) {
      novedad = novedad.isEmpty ? 'Obs: $obs' : '$novedad Obs: $obs';
    }

    _aplicarRecepcion(remision, cantidad, ubicacion, novedad, DateTime.now());
    _emitir();
    return Ok<Remision>(_remisiones[idx]);
  }

  @override
  Future<Result<void>> despachar({
    required String itemId,
    required int cantidad,
    required String ubicacion,
  }) async {
    final item = _items[itemId];
    if (item == null) return Err<void>('El producto no existe en el kardex.');
    if (cantidad <= 0) return Err<void>('La cantidad debe ser mayor a 0.');

    final kardex = _snapshot().kardexPorId(itemId)!;
    final stock = kardex.stockEn(ubicacion);
    if (cantidad > stock) {
      return Err<void>('Stock insuficiente en $ubicacion (disponible: $stock).');
    }
    if (cantidad > kardex.pendienteDespacho) {
      return Err<void>(
        'LÍMITE EXCEDIDO: solo faltan ${kardex.pendienteDespacho} Uds por despachar según la orden.',
      );
    }

    _aplicarDespacho(item, cantidad, ubicacion, DateTime.now());
    _emitir();
    return const Ok<void>(null);
  }

  // ------------------------------------------------ mutaciones sin validar
  // (usadas por los comandos y por la siembra de datos)

  Remision _aplicarEntrega(ItemOrden item, int cantidad, String operario, String numero, DateTime fecha) {
    final remision = Remision(
      id: numero,
      item: item,
      operario: operario,
      fechaEnvio: fecha,
      cantidadEnviada: cantidad,
    );
    _remisiones.insert(0, remision);
    _movimientos.add(Movimiento(
      tipo: TipoMovimiento.entregaProduccion,
      itemId: item.id,
      cantidad: cantidad,
      fecha: fecha,
      remisionId: numero,
    ));
    return remision;
  }

  void _aplicarRecepcion(Remision remision, int cantidad, String ubicacion, String novedad, DateTime fecha) {
    final idx = _remisiones.indexWhere((r) => r.id == remision.id);
    _remisiones[idx] = remision.copyWith(
      estado: novedad.isEmpty ? EstadoRemision.recibidoConforme : EstadoRemision.recibidoConNovedad,
      cantidadRecibida: cantidad,
      ubicacionDestino: ubicacion,
      novedad: novedad,
      fechaRecepcion: fecha,
    );
    if (cantidad > 0) {
      _movimientos.add(Movimiento(
        tipo: TipoMovimiento.recepcion,
        itemId: remision.item.id,
        cantidad: cantidad,
        fecha: fecha,
        ubicacion: ubicacion,
        remisionId: remision.id,
        nota: novedad,
      ));
    }
  }

  void _aplicarDespacho(ItemOrden item, int cantidad, String ubicacion, DateTime fecha) {
    _movimientos.add(Movimiento(
      tipo: TipoMovimiento.despacho,
      itemId: item.id,
      cantidad: cantidad,
      fecha: fecha,
      ubicacion: ubicacion,
    ));
  }

  // ---------------------------------------------------------------- datos demo

  void _sembrar() {
    final xs = ItemOrden(
      id: buildItemId('19249', 'ORD-001-ENE', '2025289514', 'XS'),
      op: '19249', cliente: 'ENEL', oc: 'ORD-001-ENE', codigo: '2025289514',
      descripcion: 'TSHIRT MANGA CORTA', talla: 'XS', cantidadPedida: 9,
      observacionOp: 'MARQUILLA DOT TEJIDA 2025 - PECHO IZQ',
    );
    final s = ItemOrden(
      id: buildItemId('19249', 'ORD-001-ENE', '2025289515', 'S'),
      op: '19249', cliente: 'ENEL', oc: 'ORD-001-ENE', codigo: '2025289515',
      descripcion: 'TSHIRT MANGA CORTA', talla: 'S', cantidadPedida: 264,
      observacionOp: 'TELA AZUL CONFECCIÓN NORMAL - CUELLO REDONDO',
    );
    final m = ItemOrden(
      id: buildItemId('19249', 'ORD-001-ENE', '2025289516', 'M'),
      op: '19249', cliente: 'ENEL', oc: 'ORD-001-ENE', codigo: '2025289516',
      descripcion: 'TSHIRT MANGA CORTA', talla: 'M', cantidadPedida: 841,
      observacionOp: 'DESPACHO PRIORITARIO BOGOTÁ',
    );
    final blusa = ItemOrden(
      id: buildItemId('18348', 'OC-40012', 'MTHBMMCCV', 'M'),
      op: '18348', cliente: 'MEDICALL', oc: 'OC-40012', codigo: 'MTHBMMCCV',
      descripcion: 'BLUSA MUJER', talla: 'M', cantidadPedida: 160,
      observacionOp: 'BORDADO EN BOLSILLO DELANTERO',
    );
    final bata = ItemOrden(
      id: buildItemId('18353', 'OC-9920', 'CLSBAOCD20', 'L'),
      op: '18353', cliente: 'COLSUBSIDIO', oc: 'OC-9920', codigo: 'CLSBAOCD20',
      descripcion: 'BATA MÉDICA', talla: 'L', cantidadPedida: 45,
      observacionOp: 'BOTONES ANTIFLUIDO BLANCO',
    );
    for (final i in [xs, s, m, blusa, bata]) {
      _items[i.id] = i;
    }

    const op = 'OPERARIO CONFECCIÓN 1';

    // MEDICALL: 160 producidas, recibidas y despachadas por completo.
    final r095 = _aplicarEntrega(blusa, 160, op, 'REM-095', DateTime(2026, 8, 15, 10));
    _aplicarRecepcion(r095, 160, 'ESTANTE A1', '', DateTime(2026, 8, 16, 11, 20));
    _aplicarDespacho(blusa, 160, 'ESTANTE A1', DateTime(2026, 8, 16, 15));

    // ENEL M: 841 recibidas en B2.
    final r096 = _aplicarEntrega(m, 841, op, 'REM-096', DateTime(2026, 8, 17, 15));
    _aplicarRecepcion(r096, 841, 'ESTANTE B2', '', DateTime(2026, 8, 17, 16));

    // ENEL S: 100 producidas (50 recibidas + 50 en tránsito), 20 despachadas.
    final r097 = _aplicarEntrega(s, 50, op, 'REM-097', DateTime(2026, 8, 17, 17));
    _aplicarRecepcion(r097, 50, 'ESTANTE A1', '', DateTime(2026, 8, 17, 19, 15));
    _aplicarDespacho(s, 20, 'ESTANTE A1', DateTime(2026, 8, 17, 20));
    _aplicarEntrega(s, 50, op, 'REM-102', DateTime(2026, 8, 18, 9));

    // ENEL XS: 9 producidas (5 recibidas + 4 en tránsito).
    final r098 = _aplicarEntrega(xs, 5, op, 'REM-098', DateTime(2026, 8, 17, 17, 30));
    _aplicarRecepcion(r098, 5, 'ESTANTE A1', '', DateTime(2026, 8, 17, 18, 30));
    _aplicarEntrega(xs, 4, op, 'REM-101', DateTime(2026, 8, 17, 18, 30));

    // COLSUBSIDIO: 20 producidas, en tránsito.
    _aplicarEntrega(bata, 20, op, 'REM-103', DateTime(2026, 8, 20, 8));
  }
}
