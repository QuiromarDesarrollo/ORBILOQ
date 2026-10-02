import 'dart:async';
import 'dart:convert';

import '../core/constants.dart';
import '../core/result.dart';
import '../domain/models.dart';
import '../domain/edicion_admin.dart';
import '../domain/wms_repository.dart';

class _Acumulado {
  int producido = 0;
  int recibido = 0;
  int despachado = 0;
  int pendienteReproceso = 0;
  int pendienteAliados = 0;
  final Map<String, int> ubicaciones = {};
  DateTime? fechaEntrega;
  DateTime? fechaDespacho;
  DateTime? fechaRecepcion;
}

/// Implementación en memoria basada en un libro de movimientos (ledger).
/// Todos los saldos se derivan de los movimientos: no hay contadores que puedan divergir.
class InMemoryWmsRepository implements WmsRepository {
  @override
  Future<WmsSnapshot> cargarSnapshot() async => _snapshot();
  @override
  Future<List<String>> cargarUbicaciones() async => WmsConstantes.ubicaciones;
  final Set<String> _eliminadas = {};
  @override
  Future<Result<void>> eliminarLineaAdmin(
      String itemId, String version, String motivo) async {
    final ctx = await cargarEdicionAdmin(itemId);
    if (ctx.version != version) {
      return const Err(
          'La fila cambio. Cierra y vuelve a abrir la confirmacion.');
    }
    if (motivo.trim().isEmpty) {
      return const Err('Indica el motivo del borrado.');
    }
    if (_eliminadas.contains(itemId)) {
      return const Err('La fila ya esta borrada.');
    }
    _eliminadas.add(itemId);
    _auditoriaAdmin.add({
      'item_id': itemId,
      'campo': 'admin_eliminado_en',
      'anterior': null,
      'nuevo': DateTime.now().toIso8601String(),
      'motivo': motivo.trim(),
      'actor': 'Administrador demo',
      'fecha': DateTime.now().toIso8601String()
    });
    _emitir();
    return const Ok(null);
  }

  final Map<String, DateTime?> _fechasEntregaAdmin = {};
  final Map<String, DateTime?> _fechasProduccionAdmin = {};
  final Map<String, DateTime?> _fechasLogisticaAdmin = {};
  final List<Map<String, dynamic>> _auditoriaAdmin = [];

  @override
  Future<ContextoEdicionAdmin> cargarEdicionAdmin(String itemId) async {
    final k = _snapshot().kardexPorId(itemId)!;
    final lotes = [
      for (final lote in _lotes)
        for (final l in lote.lineas)
          if (l.item.id == itemId)
            {
              'id': l.id,
              'numero': lote.id,
              'enviada': l.cantidadEnviada,
              'recibida': l.cantidadRecibida ?? 0,
              'origen': l.esReproceso ? 'reproceso' : 'entrega'
            }
    ];
    final valores = valoresAdmin(k);
    return ContextoEdicionAdmin.fromJson({
      'version': jsonEncode(
          [valores, lotes, _movimientos.length, _auditoriaAdmin.length]),
      'valores': valores,
      'lotes': lotes,
      'ubicaciones': [
        for (final u in WmsConstantes.ubicaciones) {'id': u, 'codigo': u}
      ],
      'historial': _auditoriaAdmin
          .where((a) => a['item_id'] == itemId)
          .toList()
          .reversed
          .take(20)
          .toList(),
      'filas_orden': _items.values.where((i) => i.op == k.item.op).length,
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> editarAdmin(CambioAdmin cambio,
      {required bool confirmar}) async {
    final ctx = await cargarEdicionAdmin(cambio.itemId);
    if (ctx.version != cambio.version) {
      return const Err('La fila cambió. Cierra y vuelve a abrir la edición.');
    }
    if (cambio.motivo.trim().isEmpty) {
      return const Err('Indica el motivo de la corrección.');
    }
    final antes = ctx.valores;
    final despues = Map<String, dynamic>.from(antes);
    final c = cambio.campo;
    final k = _snapshot().kardexPorId(cambio.itemId)!;
    final valor = cambio.valor;
    int delta = 0;
    LoteLinea? linea;
    final lineaId = c.lote ? cambio.loteId : null;
    if (c.lote) {
      for (final lote in _lotes) {
        for (final l in lote.lineas) {
          if (l.id == cambio.loteId && l.item.id == cambio.itemId) linea = l;
        }
      }
      if (linea == null) return const Err('Selecciona el lote afectado.');
      if (linea.novedad.contains('FALTANTE DEFINITIVO')) {
        return const Err(
            'El lote está cerrado con faltante. Revisa esa corrección primero.');
      }
    }
    if (c.ubicacion &&
        !WmsConstantes.ubicaciones.contains(cambio.ubicacionId)) {
      return const Err('Selecciona una ubicación válida.');
    }
    if (c.numero) {
      if (valor is! int ||
          valor < 0 ||
          (c == CampoAdmin.cantidad && valor == 0)) {
        return const Err('Ingresa una cantidad entera válida.');
      }
      delta = valor - (antes[c.id] as int);
      if (delta == 0) return const Err('El valor no cambió.');
      despues[c.id] = valor;
      if (c == CampoAdmin.noConforme) {
        despues['producido'] = k.producido - delta;
        despues['recibido'] = k.recibido - delta;
      }
      final q = despues['cantidad_pedida'] as int;
      final p = despues['producido'] as int;
      final r = despues['recibido'] as int;
      final d = despues['despachado'] as int;
      final diferenciaPrevia =
          k.recibido > k.producido ? k.recibido - k.producido : 0;
      if (p < 0 ||
          r < 0 ||
          d < 0 ||
          p > q ||
          d > q ||
          d > r ||
          (c != CampoAdmin.producido && r > p && r - p > diferenciaPrevia)) {
        return const Err(
            'La corrección dejaría cantidades incompatibles. Revisa las operaciones relacionadas.');
      }
      if (c == CampoAdmin.recibido &&
          ((linea!.cantidadRecibida ?? 0) + delta < 0 ||
              (linea.cantidadRecibida ?? 0) + delta > linea.cantidadEnviada)) {
        return const Err(
            'La recepción corregida debe estar entre cero y lo enviado en el lote.');
      }
      if (c.ubicacion) {
        final stockDelta = c == CampoAdmin.recibido ? delta : -delta;
        if (k.stockEn(cambio.ubicacionId!) + stockDelta < 0) {
          return const Err('Stock insuficiente en la ubicación.');
        }
        if (c == CampoAdmin.recibido && delta < 0) {
          final recibidoAlli = _movimientos
              .where((m) =>
                  m.itemId == cambio.itemId &&
                  m.loteLineaId == cambio.loteId &&
                  m.ubicacion == cambio.ubicacionId &&
                  m.tipo == TipoMovimiento.recepcion)
              .fold(0, (a, m) => a + m.cantidad);
          if (recibidoAlli + delta < 0) {
            return const Err(
                'La ubicación no tiene esa cantidad recibida en el lote.');
          }
        }
        if (c == CampoAdmin.despachado && delta < 0) {
          final enviado = _movimientos
              .where((m) =>
                  m.itemId == cambio.itemId &&
                  m.ubicacion == cambio.ubicacionId &&
                  m.tipo == TipoMovimiento.despacho)
              .fold(0, (a, m) => a + m.cantidad);
          if (enviado + delta < 0) {
            return const Err('La ubicación no tiene esa cantidad despachada.');
          }
        }
        if (c == CampoAdmin.noConforme && delta < 0) {
          final registrado = _movimientos
              .where((m) =>
                  m.itemId == cambio.itemId &&
                  m.ubicacion == cambio.ubicacionId &&
                  m.tipo == TipoMovimiento.devolucionProduccion)
              .fold(0, (a, m) => a + m.cantidad);
          if (registrado + delta < 0) {
            return const Err(
                'No hay suficiente PNC registrado en esa ubicación. Los registros históricos requieren conciliación.');
          }
        }
      }
    } else {
      if (c.fecha) {
        if (valor != null &&
            (valor is! String ||
                DateTime.tryParse(valor) == null ||
                fechaAdmin(DateTime.tryParse(valor)) != valor)) {
          return const Err('Fecha inválida.');
        }
      } else if (valor is! String ||
          (valor.trim().isEmpty &&
              [
                CampoAdmin.numeroOp,
                CampoAdmin.descripcion,
                CampoAdmin.codigo,
                CampoAdmin.cliente
              ].contains(c))) {
        return const Err('Completa el valor del campo.');
      }
      despues[c.id] = valor;
      if (antes[c.id] == valor) return const Err('El valor no cambió.');
      if (c == CampoAdmin.numeroOp &&
          _items.values.any((i) => i.op != k.item.op && i.op == valor)) {
        return const Err('Ya existe otra orden con ese número.');
      }
      if ([CampoAdmin.codigo, CampoAdmin.talla].contains(c) &&
          _items.values.any((i) =>
              i.id != k.id &&
              i.op == k.item.op &&
              i.codigo == despues['codigo'] &&
              i.talla == despues['talla'])) {
        return const Err('Ya existe el código y talla en esta OP.');
      }
    }
    final resultado = <String, dynamic>{
      'antes': antes,
      'despues': despues,
      'guardado': confirmar
    };
    if (!confirmar) return Ok(resultado);
    if (c.numero && c != CampoAdmin.cantidad) {
      final tipo = switch (c) {
        CampoAdmin.producido => TipoMovimiento.entregaProduccion,
        CampoAdmin.recibido => TipoMovimiento.recepcion,
        CampoAdmin.despachado => TipoMovimiento.despacho,
        _ => TipoMovimiento.devolucionProduccion,
      };
      _movimientos.add(Movimiento(
          tipo: tipo,
          itemId: k.id,
          cantidad: delta,
          fecha: k.fechaEntrega ?? DateTime.now(),
          ubicacion: cambio.ubicacionId,
          loteLineaId: lineaId,
          nota: 'Corrección administrativa: ${cambio.motivo}'));
    } else {
      final ids = c.compartido
          ? _items.values
              .where((i) => i.op == k.item.op)
              .map((i) => i.id)
              .toList()
          : [k.id];
      for (final id in ids) {
        final i = _items[id]!;
        _items[id] = ItemOrden(
            id: i.id,
            op: c == CampoAdmin.numeroOp ? valor as String : i.op,
            cliente: c == CampoAdmin.cliente ? valor as String : i.cliente,
            oc: c == CampoAdmin.oc ? valor as String : i.oc,
            codigo: c == CampoAdmin.codigo ? valor as String : i.codigo,
            descripcion:
                c == CampoAdmin.descripcion ? valor as String : i.descripcion,
            talla: c == CampoAdmin.talla ? valor as String : i.talla,
            cantidadPedida:
                c == CampoAdmin.cantidad ? valor as int : i.cantidadPedida,
            observacionOp: c == CampoAdmin.observacion
                ? valor as String
                : i.observacionOp);
        if (c.fecha) {
          final fecha = valor == null ? null : DateTime.parse(valor as String);
          switch (c) {
            case CampoAdmin.fechaEntrega:
              _fechasEntregaAdmin[id] = fecha;
            case CampoAdmin.fechaProduccion:
              _fechasProduccionAdmin[id] = fecha;
            case CampoAdmin.fechaLogistica:
              _fechasLogisticaAdmin[id] = fecha;
            default:
              break;
          }
        }
      }
    }
    for (var n = 0; n < _lotes.length; n++) {
      if (c == CampoAdmin.producido) {
        break; // Corrección del total: lotes intactos.
      }
      final lote = _lotes[n];
      final lineas = [
        for (final l in lote.lineas)
          LoteLinea(
              id: l.id,
              item: _items[l.item.id]!,
              cantidadEnviada: l.cantidadEnviada +
                  (l.id == lineaId && c == CampoAdmin.producido ? delta : 0),
              cantidadRecibida: l.id == lineaId && c == CampoAdmin.recibido
                  ? (l.cantidadRecibida ?? 0) + delta
                  : l.cantidadRecibida,
              estado: l.id == lineaId && c.lote
                  ? ((l.cantidadRecibida ?? 0) +
                              (c == CampoAdmin.recibido ? delta : 0) >
                          l.cantidadEnviada +
                              (c == CampoAdmin.producido ? delta : 0)
                      ? EstadoLineaLote.recibidoConNovedad
                      : (l.cantidadRecibida ?? 0) +
                                  (c == CampoAdmin.recibido ? delta : 0) ==
                              l.cantidadEnviada +
                                  (c == CampoAdmin.producido ? delta : 0)
                          ? EstadoLineaLote.recibidoConforme
                          : EstadoLineaLote.enTransito)
                  : l.estado,
              ubicacionDestino: l.ubicacionDestino,
              novedad: l.novedad,
              fechaRecepcion: l.fechaRecepcion,
              esReproceso: l.esReproceso,
              recibidoPor: l.recibidoPor)
      ];
      _lotes[n] = Lote(
          id: lote.id,
          operario: lote.operario,
          fechaEnvio: lote.fechaEnvio,
          lineas: lineas,
          estado: lineas.every((l) => !l.enTransito)
              ? EstadoLote.recibidoCompleto
              : lineas.any((l) => (l.cantidadRecibida ?? 0) > 0)
                  ? EstadoLote.recibidoParcial
                  : EstadoLote.enTransito);
    }
    _auditoriaAdmin.add({
      'item_id': k.id,
      'campo': c.id,
      'motivo': cambio.motivo,
      'anterior': antes[c.id],
      'nuevo': valor,
      'actor': 'Administrador (memoria)',
      'fecha': DateTime.now().toIso8601String()
    });
    _emitir();
    return Ok(resultado);
  }

  InMemoryWmsRepository._();

  factory InMemoryWmsRepository.seeded() =>
      InMemoryWmsRepository._().._sembrar();

  /// Base de numeración automática de lotes (en Supabase: secuencia de Postgres).
  static const _baseSecuencia = 101;

  final Map<String, ItemOrden> _items = {};
  final List<Movimiento> _movimientos = [];
  final List<Lote> _lotes = []; // más recientes primero
  final List<Liberacion> _liberaciones = []; // más recientes primero
  int _correlativoLiberacion = 0;
  final List<Devolucion> _devoluciones = []; // más recientes primero
  int _correlativoDevolucion = 0;
  final List<String> _personalLogistica = ['RECEPCIÓN BODEGA'];
  final List<String> _personalProduccion = ['SUPERVISOR PLANTA'];
  final List<String> _personalAliados = ['TALLER ALIADO 1'];
  final List<NoConformeAliado> _noConformesAliados =
      []; // más recientes primero
  int _correlativoAliado = 0;
  final List<LiberacionAliado> _liberacionesAliados =
      []; // más recientes primero
  int _correlativoLiberacionAliado = 0;
  final List<SobranteBodega> _sobrantes = []; // más recientes primero
  int _correlativoSobrante = 0;
  final StreamController<WmsSnapshot> _controller =
      StreamController.broadcast();

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
          a.ubicaciones.update(m.ubicacion!, (v) => v + m.cantidad,
              ifAbsent: () => m.cantidad);
        case TipoMovimiento.despacho:
          if (m.cantidad > 0) a.fechaDespacho = _masReciente(a.fechaDespacho, m.fecha);
          a.despachado += m.cantidad;
          a.ubicaciones.update(m.ubicacion!, (v) => v - m.cantidad,
              ifAbsent: () => -m.cantidad);
        case TipoMovimiento.devolucionProduccion:
          a.producido -= m.cantidad;
          a.pendienteReproceso += m.cantidad;
          // Las correcciones nuevas tienen ubicación explícita; los eventos
          // históricos del modo memoria conservan su comportamiento original.
          if (m.ubicacion != null) {
            a.recibido -= m.cantidad;
            a.ubicaciones.update(m.ubicacion!, (v) => v - m.cantidad,
                ifAbsent: () => -m.cantidad);
          }
        case TipoMovimiento.liberacionNoConforme:
          a.producido += m.cantidad;
          a.pendienteReproceso -= m.cantidad;
        case TipoMovimiento.envioAliado:
          a.producido -= m.cantidad;
          a.pendienteAliados += m.cantidad;
        case TipoMovimiento.liberacionAliado:
          a.producido += m.cantidad;
          a.pendienteAliados -= m.cantidad;
        case TipoMovimiento.ajusteFaltanteEntrega:
          a.producido -= m.cantidad;
      }
    }

    final kardex = [
      for (final e in _items.entries) _aKardex(e.value, acc[e.key]!),
    ];

    return WmsSnapshot(
      kardex: List.unmodifiable(kardex),
      lotes: List.unmodifiable(_lotes),
    );
  }

  ItemKardex _aKardex(ItemOrden item, _Acumulado a) {
    return ItemKardex(
      eliminada: _eliminadas.contains(item.id),
      item: item,
      producido: a.producido,
      recibido: a.recibido,
      despachado: a.despachado,
      ubicaciones: Map.unmodifiable({
        for (final e in a.ubicaciones.entries)
          if (e.value > 0) e.key: e.value,
      }),
      fechaEntrega: _fechasEntregaAdmin.containsKey(item.id)
          ? _fechasEntregaAdmin[item.id]
          : a.fechaEntrega,
      fechaEsperadaProduccion: _fechasProduccionAdmin[item.id],
      fechaEsperadaLogistica: _fechasLogisticaAdmin[item.id],
      fechaRecepcion: a.fechaRecepcion,
      fechaDespacho: a.fechaDespacho,
      pendienteReproceso: a.pendienteReproceso,
      pendienteAliados: a.pendienteAliados,
    );
  }

  DateTime _masReciente(DateTime? actual, DateTime nueva) =>
      actual == null || nueva.isAfter(actual) ? nueva : actual;

  String _proximoNumero() {
    var n = _baseSecuencia;
    while (_lotes.any((l) => l.id == 'LOTE-$n')) {
      n++;
    }
    return 'LOTE-$n';
  }

  int _pendienteProduccion(String itemId) =>
      _snapshot().kardexPorId(itemId)?.pendienteProduccion ?? 0;

  // -------------------------------------------------------------- comandos

  @override
  Future<Result<Lote>> crearLote({
    required List<ItemCantidad> items,
    required String operario,
    String? numeroLote,
  }) async {
    if (items.isEmpty) return Err<Lote>('El lote no tiene productos.');

    // Validar TODO antes de crear nada (todo o nada).
    for (final linea in items) {
      final item = _items[linea.itemId];
      if (item == null) {
        return Err<Lote>(
            'Uno de los productos del lote no existe en el kardex.');
      }
      if (linea.cantidad <= 0) {
        return Err<Lote>('Cantidad inválida en uno de los productos del lote.');
      }
      final pendiente = _pendienteProduccion(linea.itemId);
      if (linea.cantidad > pendiente) {
        return Err<Lote>(
            'LÍMITE EXCEDIDO en uno de los productos: solo faltan $pendiente Uds por producir.');
      }
    }

    var numero = (numeroLote ?? '').trim().toUpperCase();
    if (numero.isEmpty) {
      numero = _proximoNumero();
    } else if (_lotes.any((l) => l.id == numero)) {
      return Err<Lote>('El lote $numero ya existe.');
    }

    final lote = _aplicarEntregaLote(items, operario, numero, DateTime.now());
    _emitir();
    return Ok<Lote>(lote);
  }

  @override
  Future<Result<LoteLinea>> recibirLoteLinea({
    required String loteLineaId,
    required int cantidad,
    required String ubicacion,
    required String recibidoPor,
    String nota = '',
  }) async {
    if (recibidoPor.trim().isEmpty) {
      return Err<LoteLinea>(
          'Debes indicar quién de Logística recibió esta prenda.');
    }
    Lote? loteEncontrado;
    LoteLinea? lineaEncontrada;
    for (final lote in _lotes) {
      for (final linea in lote.lineas) {
        if (linea.id == loteLineaId) {
          loteEncontrado = lote;
          lineaEncontrada = linea;
          break;
        }
      }
      if (lineaEncontrada != null) break;
    }
    if (loteEncontrado == null || lineaEncontrada == null) {
      return Err<LoteLinea>('La línea del lote no existe.');
    }
    if (!lineaEncontrada.enTransito) {
      return Err<LoteLinea>('Esta línea ya fue cerrada.');
    }
    if (cantidad <= 0) return Err<LoteLinea>('La cantidad debe ser mayor a 0.');
    if (!WmsConstantes.ubicaciones.contains(ubicacion)) {
      return Err<LoteLinea>('Ubicación no válida: $ubicacion.');
    }

    final recibidoPrevio = lineaEncontrada.cantidadRecibida ?? 0;
    final pendiente = lineaEncontrada.cantidadEnviada - recibidoPrevio;
    if (cantidad > pendiente) {
      return Err<LoteLinea>(
        'LÍMITE EXCEDIDO: solo faltan $pendiente Uds por recibir en esta línea. '
        'Si llegó más de lo declarado, usa la Bandeja de Sobrantes para el exceso.',
      );
    }

    final nuevoRecibido = recibidoPrevio + cantidad;
    final completa = nuevoRecibido >= lineaEncontrada.cantidadEnviada;
    final fecha = DateTime.now();

    final lineaActualizada = lineaEncontrada.copyWith(
      estado: completa
          ? EstadoLineaLote.recibidoConforme
          : EstadoLineaLote.enTransito,
      cantidadRecibida: nuevoRecibido,
      ubicacionDestino: ubicacion,
      fechaRecepcion: fecha,
      recibidoPor: recibidoPor,
    );

    final idxLote = _lotes.indexWhere((l) => l.id == loteEncontrado!.id);
    final nuevasLineas = [
      for (final l in _lotes[idxLote].lineas)
        l.id == loteLineaId ? lineaActualizada : l,
    ];
    final pendientesEnLote = nuevasLineas.where((l) => l.enTransito).length;
    _lotes[idxLote] = Lote(
      id: loteEncontrado.id,
      operario: loteEncontrado.operario,
      fechaEnvio: loteEncontrado.fechaEnvio,
      lineas: nuevasLineas,
      estado: pendientesEnLote == 0
          ? EstadoLote.recibidoCompleto
          : EstadoLote.recibidoParcial,
    );

    _movimientos.add(Movimiento(
      tipo: TipoMovimiento.recepcion,
      itemId: lineaEncontrada.item.id,
      cantidad: cantidad,
      fecha: fecha,
      ubicacion: ubicacion,
      loteId: loteEncontrado.id,
      loteLineaId: loteLineaId,
      nota: nota,
    ));

    _emitir();
    return Ok<LoteLinea>(lineaActualizada);
  }

  @override
  Future<Result<void>> cerrarLoteItemConFaltante({
    required String loteLineaId,
    String nota = '',
  }) async {
    Lote? loteEncontrado;
    LoteLinea? lineaEncontrada;
    for (final lote in _lotes) {
      for (final linea in lote.lineas) {
        if (linea.id == loteLineaId) {
          loteEncontrado = lote;
          lineaEncontrada = linea;
          break;
        }
      }
      if (lineaEncontrada != null) break;
    }
    if (loteEncontrado == null || lineaEncontrada == null) {
      return Err<void>('La línea del lote no existe.');
    }
    if (!lineaEncontrada.enTransito) {
      return Err<void>('Esta línea ya fue cerrada.');
    }
    final recibido = lineaEncontrada.cantidadRecibida ?? 0;
    final faltante = lineaEncontrada.cantidadEnviada - recibido;
    if (faltante <= 0) {
      return Err<void>(
          'Esta línea ya está completa, no hay faltante que cerrar.');
    }

    var novedad =
        'FALTANTE DEFINITIVO: se recibieron $recibido de ${lineaEncontrada.cantidadEnviada} Uds (nunca llegaron $faltante).';
    if (nota.trim().isNotEmpty) novedad = '$novedad Obs: ${nota.trim()}';

    final lineaActualizada = lineaEncontrada.copyWith(
        estado: EstadoLineaLote.recibidoConNovedad, novedad: novedad);

    final idxLote = _lotes.indexWhere((l) => l.id == loteEncontrado!.id);
    final nuevasLineas = [
      for (final l in _lotes[idxLote].lineas)
        l.id == loteLineaId ? lineaActualizada : l,
    ];
    final pendientesEnLote = nuevasLineas.where((l) => l.enTransito).length;
    _lotes[idxLote] = Lote(
      id: loteEncontrado.id,
      operario: loteEncontrado.operario,
      fechaEnvio: loteEncontrado.fechaEnvio,
      lineas: nuevasLineas,
      estado: pendientesEnLote == 0
          ? EstadoLote.recibidoCompleto
          : EstadoLote.recibidoParcial,
    );

    _movimientos.add(Movimiento(
      tipo: TipoMovimiento.ajusteFaltanteEntrega,
      itemId: lineaEncontrada.item.id,
      cantidad: faltante,
      fecha: DateTime.now(),
      loteId: loteEncontrado.id,
      loteLineaId: loteLineaId,
      nota: novedad,
    ));

    _emitir();
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> registrarSobrante({
    required String itemId,
    String? loteLineaId,
    required int cantidad,
    required String operario,
    String nota = '',
  }) async {
    if (cantidad <= 0) return Err<void>('La cantidad debe ser mayor a 0.');
    final item = _items[itemId];
    if (item == null) return Err<void>('El producto no existe en el kardex.');

    _sobrantes.insert(
      0,
      SobranteBodega(
        id: 'SOB-${_correlativoSobrante++}',
        item: item,
        cantidad: cantidad,
        estado: 'pendiente',
        operario: operario,
        fecha: DateTime.now(),
        nota: nota,
      ),
    );
    _emitir();
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> resolverSobrante(
      {required String id, required String resolucion}) async {
    if (resolucion.trim().isEmpty) {
      return Err<void>('Debes indicar qué se decidió hacer con este sobrante.');
    }
    final idx = _sobrantes.indexWhere((s) => s.id == id);
    if (idx == -1) return Err<void>('El sobrante no existe.');
    if (!_sobrantes[idx].pendiente) {
      return Err<void>('El sobrante ya fue resuelto.');
    }

    final actual = _sobrantes[idx];
    _sobrantes[idx] = SobranteBodega(
      id: actual.id,
      item: actual.item,
      cantidad: actual.cantidad,
      estado: 'resuelto',
      operario: actual.operario,
      fecha: actual.fecha,
      nota: actual.nota,
      resolucion: resolucion,
      fechaResolucion: DateTime.now(),
    );
    _emitir();
    return const Ok<void>(null);
  }

  @override
  Future<List<SobranteBodega>> cargarSobrantes() async =>
      List.unmodifiable(_sobrantes);

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
      return Err<void>(
          'Stock insuficiente en $ubicacion (disponible: $stock).');
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

  @override
  Future<List<Causal>> cargarCausales() async => [
        for (final nombre in WmsConstantes.causales)
          Causal(id: nombre, nombre: nombre),
      ];

  @override
  Future<List<String>> cargarPersonalLogistica() async =>
      List.unmodifiable(_personalLogistica);

  @override
  Future<Result<String>> agregarPersonalLogistica(String nombre) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) return Err<String>('El nombre no puede estar vacío.');
    final existente = _personalLogistica.firstWhere(
      (n) => n.toLowerCase() == limpio.toLowerCase(),
      orElse: () => '',
    );
    if (existente.isNotEmpty) return Ok<String>(existente);
    _personalLogistica.add(limpio);
    return Ok<String>(limpio);
  }

  @override
  Future<List<String>> cargarPersonalProduccion() async =>
      List.unmodifiable(_personalProduccion);

  @override
  Future<Result<String>> agregarPersonalProduccion(String nombre) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) return Err<String>('El nombre no puede estar vacío.');
    final existente = _personalProduccion.firstWhere(
      (n) => n.toLowerCase() == limpio.toLowerCase(),
      orElse: () => '',
    );
    if (existente.isNotEmpty) return Ok<String>(existente);
    _personalProduccion.add(limpio);
    return Ok<String>(limpio);
  }

  @override
  Future<List<String>> cargarPersonalAliados() async =>
      List.unmodifiable(_personalAliados);

  @override
  Future<Result<String>> agregarPersonalAliado(String nombre) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) return Err<String>('El nombre no puede estar vacío.');
    final existente = _personalAliados.firstWhere(
      (n) => n.toLowerCase() == limpio.toLowerCase(),
      orElse: () => '',
    );
    if (existente.isNotEmpty) return Ok<String>(existente);
    _personalAliados.add(limpio);
    return Ok<String>(limpio);
  }

  @override
  Future<Result<void>> enviarNoConformeAliado({
    required String itemId,
    required int cantidad,
    required String causalId,
    required String operario,
    required String personaAliadoEntrega,
    String nota = '',
  }) async {
    if (personaAliadoEntrega.trim().isEmpty) {
      return Err<void>(
          'Debes indicar a quién de Aliados se le entrega esta prenda.');
    }
    final item = _items[itemId];
    if (item == null) return Err<void>('El producto no existe en el kardex.');
    if (cantidad <= 0) return Err<void>('La cantidad debe ser mayor a 0.');
    final producido = _snapshot().kardexPorId(itemId)?.producido ?? 0;
    if (cantidad > producido) {
      return Err<void>(
          'LÍMITE EXCEDIDO: solo hay $producido Uds entregadas por Producción para este producto.');
    }

    _noConformesAliados.insert(
      0,
      NoConformeAliado(
        id: 'ALI-${_correlativoAliado++}',
        item: item,
        cantidad: cantidad,
        causal: causalId,
        estado: 'pendiente',
        usuarioSolicitud: operario,
        personaAliadoEntrega: personaAliadoEntrega,
        fechaSolicitud: DateTime.now(),
        notaSolicitud: nota,
      ),
    );
    _movimientos.add(Movimiento(
      tipo: TipoMovimiento.envioAliado,
      itemId: item.id,
      cantidad: cantidad,
      fecha: DateTime.now(),
      nota: nota,
    ));
    _emitir();
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> liberarNoConformeAliado({
    required String id,
    required int cantidad,
    required String operario,
    required String personaAliadoLibera,
    String nota = '',
  }) async {
    if (personaAliadoLibera.trim().isEmpty) {
      return Err<void>('Debes indicar quién de Aliados realizó la liberación.');
    }
    if (cantidad <= 0) return Err<void>('La cantidad debe ser mayor a 0.');
    final idx = _noConformesAliados.indexWhere((a) => a.id == id);
    if (idx == -1) return Err<void>('La solicitud no existe.');
    final actual = _noConformesAliados[idx];
    if (!actual.pendiente) {
      return Err<void>('Esta solicitud ya fue liberada por completo.');
    }
    if (cantidad > actual.cantidadPendiente) {
      return Err<void>(
          'LÍMITE EXCEDIDO: solo quedan ${actual.cantidadPendiente} Uds pendientes por liberar de esta solicitud.');
    }

    final nuevaLiberada = actual.cantidadLiberada + cantidad;
    final tipo = nuevaLiberada >= actual.cantidad ? 'completa' : 'parcial';
    final fecha = DateTime.now();

    _noConformesAliados[idx] = NoConformeAliado(
      id: actual.id,
      item: actual.item,
      cantidad: actual.cantidad,
      causal: actual.causal,
      estado: nuevaLiberada >= actual.cantidad ? 'liberado' : 'pendiente',
      usuarioSolicitud: actual.usuarioSolicitud,
      personaAliadoEntrega: actual.personaAliadoEntrega,
      fechaSolicitud: actual.fechaSolicitud,
      notaSolicitud: actual.notaSolicitud,
      cantidadLiberada: nuevaLiberada,
    );
    _liberacionesAliados.insert(
      0,
      LiberacionAliado(
        id: 'LIBALI-${_correlativoLiberacionAliado++}',
        solicitudId: actual.id,
        item: actual.item,
        cantidad: cantidad,
        tipo: tipo,
        operario: operario,
        personaAliado: personaAliadoLibera,
        fecha: fecha,
        nota: nota,
        cantidadTotalSolicitud: actual.cantidad,
      ),
    );
    _movimientos.add(Movimiento(
      tipo: TipoMovimiento.liberacionAliado,
      itemId: actual.item.id,
      cantidad: cantidad,
      fecha: fecha,
      nota: nota,
    ));
    _emitir();
    return const Ok<void>(null);
  }

  @override
  Future<List<NoConformeAliado>> cargarNoConformesAliados() async =>
      List.unmodifiable(_noConformesAliados);

  @override
  Future<List<LiberacionAliado>> cargarLiberacionesAliados() async =>
      List.unmodifiable(_liberacionesAliados);

  @override
  Future<Result<void>> registrarNoConforme({
    required String itemId,
    required int cantidad,
    required String causalId,
    required String operario,
    required String recibidoDeProduccion,
    String nota = '',
  }) async {
    final item = _items[itemId];
    if (item == null) return Err<void>('El producto no existe en el kardex.');
    if (cantidad <= 0) return Err<void>('La cantidad debe ser mayor a 0.');
    if (recibidoDeProduccion.trim().isEmpty) {
      return Err<void>(
          'Debes indicar quién de Producción entregó esta prenda.');
    }
    final producido = _snapshot().kardexPorId(itemId)?.producido ?? 0;
    if (cantidad > producido) {
      return Err<void>(
          'LÍMITE EXCEDIDO: solo hay $producido Uds entregadas por Producción para este producto.');
    }

    final fecha = DateTime.now();
    _devoluciones.insert(
      0,
      Devolucion(
        id: 'DEV-${_correlativoDevolucion++}',
        item: item,
        cantidad: cantidad,
        causal: causalId, // en modo memoria, el id de la causal ES su nombre
        operario: operario,
        fecha: fecha,
        nota: nota,
        recibidoDeProduccion: recibidoDeProduccion.trim(),
      ),
    );
    _movimientos.add(Movimiento(
      tipo: TipoMovimiento.devolucionProduccion,
      itemId: item.id,
      cantidad: cantidad,
      fecha: fecha,
      nota: '$causalId${nota.trim().isEmpty ? '' : ' - ${nota.trim()}'}',
    ));
    _emitir();
    return const Ok<void>(null);
  }

  @override
  Future<List<Devolucion>> cargarDevoluciones() async =>
      List.unmodifiable(_devoluciones);

  @override
  Future<Result<void>> liberarNoConforme({
    required String itemId,
    required int cantidad,
    required String operario,
    required String recibidoPorLogistica,
    String nota = '',
  }) async {
    final item = _items[itemId];
    if (item == null) return Err<void>('El producto no existe en el kardex.');
    if (cantidad <= 0) return Err<void>('La cantidad debe ser mayor a 0.');
    if (recibidoPorLogistica.trim().isEmpty) {
      return Err<void>('Debes indicar quién de Logística recibió esta prenda.');
    }
    final pendienteReproceso =
        _snapshot().kardexPorId(itemId)?.pendienteReproceso ?? 0;
    if (cantidad > pendienteReproceso) {
      return Err<void>(
          'LÍMITE EXCEDIDO: solo hay $pendienteReproceso Uds pendientes por reprocesar.');
    }

    final fecha = DateTime.now();
    _liberaciones.insert(
      0,
      Liberacion(
        id: 'LIB-${_correlativoLiberacion++}',
        item: item,
        cantidad: cantidad,
        operario: operario,
        fecha: fecha,
        nota: nota,
        recibidoPorLogistica: recibidoPorLogistica.trim(),
      ),
    );

    // Crea un lote real (igual que una entrega normal) para que Bodega lo
    // reciba explícitamente por "Recibir lote", marcado como reproceso.
    final numero = _proximoNumero();
    final linea = LoteLinea(
        id: _nuevoIdLinea(),
        item: item,
        cantidadEnviada: cantidad,
        esReproceso: true);
    _lotes.insert(
        0,
        Lote(
            id: numero,
            operario: operario,
            fechaEnvio: fecha,
            lineas: [linea]));

    _movimientos.add(Movimiento(
      tipo: TipoMovimiento.liberacionNoConforme,
      itemId: item.id,
      cantidad: cantidad,
      fecha: fecha,
      loteId: numero,
      nota: nota,
    ));
    _emitir();
    return const Ok<void>(null);
  }

  @override
  Future<List<Liberacion>> cargarLiberaciones() async =>
      List.unmodifiable(_liberaciones);

  // ------------------------------------------------ mutaciones sin validar
  // (usadas por los comandos y por la siembra de datos)

  int _correlativoLinea = 0;
  String _nuevoIdLinea() => 'LI-${_correlativoLinea++}';

  Lote _aplicarEntregaLote(List<ItemCantidad> items, String operario,
      String numero, DateTime fecha) {
    final lineas = <LoteLinea>[];
    for (final linea in items) {
      final item = _items[linea.itemId]!;
      lineas.add(LoteLinea(
          id: _nuevoIdLinea(), item: item, cantidadEnviada: linea.cantidad));
      _movimientos.add(Movimiento(
        tipo: TipoMovimiento.entregaProduccion,
        itemId: item.id,
        cantidad: linea.cantidad,
        fecha: fecha,
        loteId: numero,
      ));
    }
    final lote =
        Lote(id: numero, operario: operario, fechaEnvio: fecha, lineas: lineas);
    _lotes.insert(0, lote);
    return lote;
  }

  LoteLinea _aplicarRecepcionLinea(Lote lote, LoteLinea linea, int cantidad,
      String ubicacion, String novedad, DateTime fecha,
      {String recibidoPor = ''}) {
    final lineaActualizada = linea.copyWith(
      estado: novedad.isEmpty
          ? EstadoLineaLote.recibidoConforme
          : EstadoLineaLote.recibidoConNovedad,
      cantidadRecibida: cantidad,
      ubicacionDestino: ubicacion,
      novedad: novedad,
      fechaRecepcion: fecha,
      recibidoPor: recibidoPor,
    );

    final idxLote = _lotes.indexWhere((l) => l.id == lote.id);
    final nuevasLineas = [
      for (final l in _lotes[idxLote].lineas)
        l.id == linea.id ? lineaActualizada : l,
    ];
    final pendientes = nuevasLineas.where((l) => l.enTransito).length;
    _lotes[idxLote] = Lote(
      id: lote.id,
      operario: lote.operario,
      fechaEnvio: lote.fechaEnvio,
      lineas: nuevasLineas,
      estado: pendientes == 0
          ? EstadoLote.recibidoCompleto
          : EstadoLote.recibidoParcial,
    );

    if (cantidad > 0) {
      _movimientos.add(Movimiento(
        tipo: TipoMovimiento.recepcion,
        itemId: linea.item.id,
        cantidad: cantidad,
        fecha: fecha,
        ubicacion: ubicacion,
        loteId: lote.id,
        loteLineaId: linea.id,
        nota: novedad,
      ));
    }
    return lineaActualizada;
  }

  void _aplicarDespacho(
      ItemOrden item, int cantidad, String ubicacion, DateTime fecha) {
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
      op: '19249',
      cliente: 'ENEL',
      oc: 'ORD-001-ENE',
      codigo: '2025289514',
      descripcion: 'TSHIRT MANGA CORTA',
      talla: 'XS',
      cantidadPedida: 9,
      observacionOp: 'MARQUILLA DOT TEJIDA 2025 - PECHO IZQ',
    );
    final s = ItemOrden(
      id: buildItemId('19249', 'ORD-001-ENE', '2025289515', 'S'),
      op: '19249',
      cliente: 'ENEL',
      oc: 'ORD-001-ENE',
      codigo: '2025289515',
      descripcion: 'TSHIRT MANGA CORTA',
      talla: 'S',
      cantidadPedida: 264,
      observacionOp: 'TELA AZUL CONFECCIÓN NORMAL - CUELLO REDONDO',
    );
    final m = ItemOrden(
      id: buildItemId('19249', 'ORD-001-ENE', '2025289516', 'M'),
      op: '19249',
      cliente: 'ENEL',
      oc: 'ORD-001-ENE',
      codigo: '2025289516',
      descripcion: 'TSHIRT MANGA CORTA',
      talla: 'M',
      cantidadPedida: 841,
      observacionOp: 'DESPACHO PRIORITARIO BOGOTÁ',
    );
    final blusa = ItemOrden(
      id: buildItemId('18348', 'OC-40012', 'MTHBMMCCV', 'M'),
      op: '18348',
      cliente: 'MEDICALL',
      oc: 'OC-40012',
      codigo: 'MTHBMMCCV',
      descripcion: 'BLUSA MUJER',
      talla: 'M',
      cantidadPedida: 160,
      observacionOp: 'BORDADO EN BOLSILLO DELANTERO',
    );
    final bata = ItemOrden(
      id: buildItemId('18353', 'OC-9920', 'CLSBAOCD20', 'L'),
      op: '18353',
      cliente: 'COLSUBSIDIO',
      oc: 'OC-9920',
      codigo: 'CLSBAOCD20',
      descripcion: 'BATA MÉDICA',
      talla: 'L',
      cantidadPedida: 45,
      observacionOp: 'BOTONES ANTIFLUIDO BLANCO',
    );
    for (final i in [xs, s, m, blusa, bata]) {
      _items[i.id] = i;
    }

    const op = 'OPERARIO CONFECCIÓN 1';

    // MEDICALL: 160 producidas, recibidas y despachadas por completo.
    final lote095 = _aplicarEntregaLote(
      [ItemCantidad(itemId: blusa.id, cantidad: 160)],
      op,
      'LOTE-095',
      DateTime(2026, 8, 15, 10),
    );
    _aplicarRecepcionLinea(lote095, lote095.lineas.first, 160, 'ESTANTE A1', '',
        DateTime(2026, 8, 16, 11, 20));
    _aplicarDespacho(blusa, 160, 'ESTANTE A1', DateTime(2026, 8, 16, 15));

    // ENEL M + ENEL S (100 producidas de golpe): un lote con 2 productos,
    // para que el modo demo también muestre un lote agrupado.
    final lote096 = _aplicarEntregaLote(
      [
        ItemCantidad(itemId: m.id, cantidad: 841),
        ItemCantidad(itemId: s.id, cantidad: 50)
      ],
      op,
      'LOTE-096',
      DateTime(2026, 8, 17, 15),
    );
    _aplicarRecepcionLinea(
      lote096,
      lote096.lineas[0],
      841,
      'ESTANTE B2',
      '',
      DateTime(2026, 8, 17, 16),
    );
    _aplicarRecepcionLinea(
      lote096,
      lote096.lineas[1],
      50,
      'ESTANTE A1',
      '',
      DateTime(2026, 8, 17, 19, 15),
    );
    _aplicarDespacho(s, 20, 'ESTANTE A1', DateTime(2026, 8, 17, 20));
    _aplicarEntregaLote([ItemCantidad(itemId: s.id, cantidad: 50)], op,
        'LOTE-102', DateTime(2026, 8, 18, 9));

    // ENEL XS: 9 producidas (5 recibidas + 4 en tránsito).
    final lote098 = _aplicarEntregaLote(
      [ItemCantidad(itemId: xs.id, cantidad: 5)],
      op,
      'LOTE-098',
      DateTime(2026, 8, 17, 17, 30),
    );
    _aplicarRecepcionLinea(lote098, lote098.lineas.first, 5, 'ESTANTE A1', '',
        DateTime(2026, 8, 17, 18, 30));
    _aplicarEntregaLote([ItemCantidad(itemId: xs.id, cantidad: 4)], op,
        'LOTE-101', DateTime(2026, 8, 17, 18, 30));

    // COLSUBSIDIO: 20 producidas, en tránsito.
    _aplicarEntregaLote([ItemCantidad(itemId: bata.id, cantidad: 20)], op,
        'LOTE-103', DateTime(2026, 8, 20, 8));
  }
}
