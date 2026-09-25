#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - "Quien recibio" en Producto no conforme (v2)
# Reemplaza a v1: ahora "Quien de Produccion entrego la prenda" tambien es
# una lista ampliable (antes usaba la lista fija de estaciones, que no
# tenia nombres de personas). Requiere ejecutar antes el SQL adjunto
# sql_personal_produccion.sql (ademas del SQL de la v1, que no cambia).
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_recibido_no_conforme_v2.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi

echo "Aplicando cambios de quien-recibio en producto no conforme (v2)..."

echo "  - lib/domain/wms_repository.dart"
mkdir -p "$(dirname 'lib/domain/wms_repository.dart')"
cat > 'lib/domain/wms_repository.dart' << 'ORBILOQ_EOF'
import '../core/result.dart';
import 'models.dart';

/// Contrato de datos. Las reglas de negocio (límites, stock) deben aplicarse
/// dentro de cada implementación; en Supabase, mediante funciones RPC transaccionales.
abstract interface class WmsRepository {
  /// Emite el estado actual y cada cambio posterior.
  Stream<WmsSnapshot> watch();

  Future<void> refrescar();

  /// Producción entrega VARIOS productos de una sola vez, agrupados bajo un
  /// mismo lote (todo o nada: si uno de los productos no pasa validación,
  /// no se crea nada).
  Future<Result<Lote>> crearLote({
    required List<ItemCantidad> items,
    required String operario,
    String? numeroLote,
  });

  /// Logística recibe UNA línea (producto) dentro de un lote y la ubica en
  /// un estante.
  Future<Result<LoteLinea>> recibirLoteLinea({
    required String loteLineaId,
    required int cantidad,
    required String ubicacion,
    String nota = '',
  });

  /// Logística despacha unidades desde una ubicación.
  Future<Result<void>> despachar({
    required String itemId,
    required int cantidad,
    required String ubicacion,
  });

  /// Causales disponibles para marcar un producto como no conforme.
  Future<List<Causal>> cargarCausales();

  /// Lista ampliable de personas de Logística que pueden recibir una prenda
  /// liberada por Producción. Se puede agregar un nombre nuevo con
  /// [agregarPersonalLogistica].
  Future<List<String>> cargarPersonalLogistica();

  /// Agrega (o reutiliza si ya existe) un nombre en la lista de personal de
  /// Logística, devolviendo el nombre normalizado guardado.
  Future<Result<String>> agregarPersonalLogistica(String nombre);

  /// Lista ampliable de personas de Producción que pueden entregar una
  /// prenda no conforme a Logística. Se puede agregar un nombre nuevo con
  /// [agregarPersonalProduccion].
  Future<List<String>> cargarPersonalProduccion();

  /// Agrega (o reutiliza si ya existe) un nombre en la lista de personal de
  /// Producción, devolviendo el nombre normalizado guardado.
  Future<Result<String>> agregarPersonalProduccion(String nombre);

  /// Logística marca unidades como no conformes: se restan de lo entregado
  /// por Producción (independiente de cualquier lote) y quedan reflejadas
  /// en "Producto no conforme" hasta que se reprocesen.
  Future<Result<void>> registrarNoConforme({
    required String itemId,
    required int cantidad,
    required String causalId,
    required String operario,
    required String recibidoDeProduccion,
    String nota = '',
  });

  /// Producción libera (reprocesó) unidades no conformes: vuelven a sumar a
  /// lo entregado y bajan de "Producto no conforme". Puede ser parcial.
  Future<Result<void>> liberarNoConforme({
    required String itemId,
    required int cantidad,
    required String operario,
    required String recibidoPorLogistica,
    String nota = '',
  });

  /// Historial de liberaciones (más recientes primero), para control.
  Future<List<Liberacion>> cargarLiberaciones();

  /// Historial de reportes de producto no conforme (más recientes primero).
  Future<List<Devolucion>> cargarDevoluciones();

  void dispose();
}
ORBILOQ_EOF

echo "  - lib/data/supabase_wms_repository.dart"
mkdir -p "$(dirname 'lib/data/supabase_wms_repository.dart')"
cat > 'lib/data/supabase_wms_repository.dart' << 'ORBILOQ_EOF'
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/result.dart';
import '../domain/models.dart';
import '../domain/wms_repository.dart';

/// Implementación real contra Supabase. Las reglas de negocio (límites de
/// producción, validación de stock) viven en funciones RPC de Postgres
/// (`crear_lote`, `recibir_lote_item`, `despachar`), no aquí — así quedan
/// protegidas por transacciones del lado del servidor, sin condiciones de
/// carrera entre usuarios concurrentes.
class SupabaseWmsRepository implements WmsRepository {
  SupabaseWmsRepository(this._client) {
    _channel = _client
        .channel('wms_cambios')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'movimientos',
          callback: (_) => refrescar(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'lotes',
          callback: (_) => refrescar(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'lote_items',
          callback: (_) => refrescar(),
        )
        .subscribe();
    refrescar();
  }

  final SupabaseClient _client;
  late final RealtimeChannel _channel;
  final StreamController<WmsSnapshot> _controller = StreamController.broadcast();
  WmsSnapshot? _ultimo;

  @override
  Stream<WmsSnapshot> watch() async* {
    if (_ultimo != null) yield _ultimo!;
    yield* _controller.stream;
  }

  @override
  Future<void> refrescar() async {
    try {
      final snapshot = await _cargarSnapshot();
      _ultimo = snapshot;
      if (!_controller.isClosed) _controller.add(snapshot);
    } catch (e) {
      if (!_controller.isClosed) _controller.addError(e);
    }
  }

  @override
  void dispose() {
    _client.removeChannel(_channel);
    _controller.close();
  }

  // ---------------------------------------------------------------- lectura

  /// Supabase limita cada respuesta a un máximo de filas (por defecto 1000).
  /// Esta función pide "páginas" sucesivas hasta traer TODAS las filas —
  /// sin esto, tablas grandes se cortan en silencio.
  Future<List<Map<String, dynamic>>> _traerTodo(
    dynamic Function(int desde, int hasta) construirConsulta,
  ) async {
    const tamPagina = 1000;
    final todas = <Map<String, dynamic>>[];
    var desde = 0;
    while (true) {
      final resultado = await construirConsulta(desde, desde + tamPagina - 1);
      final lote = (resultado as List).cast<Map<String, dynamic>>();
      if (lote.isEmpty) break;
      todas.addAll(lote);
      // Avanza según lo que realmente llegó (no según lo pedido): si el
      // servidor entrega menos de tamPagina por su propio límite, esto
      // evita saltarse filas en la siguiente página.
      desde += lote.length;
    }
    return todas;
  }

  Future<WmsSnapshot> _cargarSnapshot() async {
    final kardexRows = await _traerTodo(
      (desde, hasta) => _client
          .from('vista_kardex')
          .select()
          .order('numero_op')
          .order('codigo')
          .range(desde, hasta),
    );

    final stockRows = await _traerTodo(
      (desde, hasta) => _client.from('vista_stock_ubicacion_detalle').select().range(desde, hasta),
    );

    final loteItemsRows = await _traerTodo(
      (desde, hasta) => _client
          .from('vista_lote_items_detalle')
          .select()
          .order('fecha_envio', ascending: false)
          .range(desde, hasta),
    );

    final stockPorItem = <String, Map<String, int>>{};
    for (final fila in stockRows) {
      final itemId = fila['item_orden_id'] as String;
      final ubicacion = fila['ubicacion_codigo'] as String;
      final cantidad = (fila['cantidad'] as num).toInt();
      stockPorItem.putIfAbsent(itemId, () => {})[ubicacion] = cantidad;
    }

    final kardex = [
      for (final row in kardexRows) _kardexDesdeFila(row, stockPorItem),
    ];

    return WmsSnapshot(kardex: kardex, lotes: _agruparLotes(loteItemsRows));
  }

  ItemKardex _kardexDesdeFila(
    Map<String, dynamic> row,
    Map<String, Map<String, int>> stockPorItem,
  ) {
    final id = row['item_orden_id'] as String;
    final item = ItemOrden(
      id: id,
      op: row['numero_op'] as String,
      cliente: row['cliente'] as String,
      oc: (row['oc'] as String?) ?? '',
      codigo: row['codigo'] as String,
      descripcion: row['descripcion'] as String,
      talla: row['talla'] as String,
      cantidadPedida: (row['cantidad_pedida'] as num).toInt(),
      observacionOp: (row['observacion_op'] as String?) ?? '',
    );
    return ItemKardex(
      item: item,
      producido: (row['producido'] as num).toInt(),
      recibido: (row['recibido'] as num).toInt(),
      despachado: (row['despachado'] as num).toInt(),
      ubicaciones: stockPorItem[id] ?? const {},
      fechaEntrega: _fecha(row['fecha_ultima_entrega']),
      fechaRecepcion: _fecha(row['fecha_ultima_recepcion']),
      fechaEsperadaProduccion: _fecha(row['fecha_esperada_produccion']),
      fechaEsperadaLogistica: _fecha(row['fecha_esperada_logistica']),
      pendienteReproceso: (row['pendiente_reproceso'] as num?)?.toInt() ?? 0,
    );
  }

  /// `vista_lote_items_detalle` trae una fila por CADA línea; aquí se
  /// agrupan por lote (ya vienen ordenadas por fecha_envio desc, así que el
  /// orden de agrupación preserva "más recientes primero").
  List<Lote> _agruparLotes(List<Map<String, dynamic>> filas) {
    final porNumero = <String, List<Map<String, dynamic>>>{};
    final orden = <String>[];
    for (final fila in filas) {
      final numero = fila['lote_numero'] as String;
      if (!porNumero.containsKey(numero)) orden.add(numero);
      porNumero.putIfAbsent(numero, () => []).add(fila);
    }

    return [
      for (final numero in orden) _loteDesdeFilas(numero, porNumero[numero]!),
    ];
  }

  Lote _loteDesdeFilas(String numero, List<Map<String, dynamic>> filas) {
    final primera = filas.first;
    final lineas = [for (final f in filas) _lineaDesdeFila(f)];
    final pendientes = lineas.where((l) => l.enTransito).length;
    final estado = pendientes == 0
        ? EstadoLote.recibidoCompleto
        : (pendientes == lineas.length ? EstadoLote.enTransito : EstadoLote.recibidoParcial);
    return Lote(
      id: numero,
      operario: primera['operario_nombre'] as String,
      fechaEnvio: DateTime.parse(primera['fecha_envio'] as String).toLocal(),
      estado: estado,
      lineas: lineas,
    );
  }

  LoteLinea _lineaDesdeFila(Map<String, dynamic> row) {
    final item = ItemOrden(
      id: row['item_orden_id'] as String,
      op: row['op_numero'] as String,
      cliente: row['item_cliente'] as String,
      oc: (row['item_oc'] as String?) ?? '',
      codigo: row['item_codigo'] as String,
      descripcion: row['item_descripcion'] as String,
      talla: row['item_talla'] as String,
      cantidadPedida: (row['cantidad_pedida'] as num).toInt(),
      observacionOp: (row['observacion_op'] as String?) ?? '',
    );
    return LoteLinea(
      id: row['lote_item_id'] as String,
      item: item,
      cantidadEnviada: (row['cantidad_enviada'] as num).toInt(),
      estado: _estadoLineaDesde(row['estado'] as String),
      cantidadRecibida: (row['cantidad_recibida'] as num?)?.toInt(),
      ubicacionDestino: row['ubicacion_destino_codigo'] as String?,
      novedad: (row['novedad'] as String?) ?? '',
      fechaRecepcion: _fecha(row['fecha_recepcion']),
      esReproceso: row['origen'] == 'reproceso',
    );
  }

  EstadoLineaLote _estadoLineaDesde(String v) => switch (v) {
        'recibido_conforme' => EstadoLineaLote.recibidoConforme,
        'recibido_con_novedad' => EstadoLineaLote.recibidoConNovedad,
        _ => EstadoLineaLote.enTransito,
      };

  DateTime? _fecha(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();

  Future<String?> _idDeUbicacion(String codigo) async {
    final fila = await _client
        .from('ubicaciones')
        .select('id')
        .eq('codigo', codigo)
        .maybeSingle();
    return fila?['id'] as String?;
  }

  Lote? _buscarLotePorNumero(String numero) {
    for (final l in _ultimo?.lotes ?? const <Lote>[]) {
      if (l.id == numero) return l;
    }
    return null;
  }

  // -------------------------------------------------------------- comandos

  @override
  Future<Result<Lote>> crearLote({
    required List<ItemCantidad> items,
    required String operario,
    String? numeroLote,
  }) async {
    if (items.isEmpty) return Err<Lote>('El lote no tiene productos.');
    try {
      final res = await _client.rpc('crear_lote', params: {
        'p_items': [
          for (final i in items) {'item_orden_id': i.itemId, 'cantidad': i.cantidad},
        ],
        'p_operario_nombre': operario,
        'p_numero_lote': (numeroLote == null || numeroLote.trim().isEmpty) ? null : numeroLote.trim(),
      });
      final numero = (res as Map)['numero'] as String;
      await refrescar();
      final lote = _buscarLotePorNumero(numero);
      if (lote == null) {
        return Err<Lote>('El lote $numero se creó, pero no se pudo leer de vuelta.');
      }
      return Ok<Lote>(lote);
    } on PostgrestException catch (e) {
      return Err<Lote>(e.message);
    } catch (e) {
      return Err<Lote>('Error inesperado al crear el lote: $e');
    }
  }

  @override
  Future<Result<LoteLinea>> recibirLoteLinea({
    required String loteLineaId,
    required int cantidad,
    required String ubicacion,
    String nota = '',
  }) async {
    try {
      final ubicacionId = await _idDeUbicacion(ubicacion);
      if (ubicacionId == null) {
        return Err<LoteLinea>('Ubicación no válida: $ubicacion.');
      }
      await _client.rpc('recibir_lote_item', params: {
        'p_lote_item_id': loteLineaId,
        'p_cantidad': cantidad,
        'p_ubicacion_id': ubicacionId,
        'p_nota': nota,
      });
      await refrescar();
      for (final lote in _ultimo?.lotes ?? const <Lote>[]) {
        for (final linea in lote.lineas) {
          if (linea.id == loteLineaId) return Ok<LoteLinea>(linea);
        }
      }
      return Err<LoteLinea>('La línea se actualizó, pero no se pudo leer de vuelta.');
    } on PostgrestException catch (e) {
      return Err<LoteLinea>(e.message);
    } catch (e) {
      return Err<LoteLinea>('Error inesperado al recibir: $e');
    }
  }

  @override
  Future<Result<void>> despachar({
    required String itemId,
    required int cantidad,
    required String ubicacion,
  }) async {
    try {
      final ubicacionId = await _idDeUbicacion(ubicacion);
      if (ubicacionId == null) {
        return Err<void>('Ubicación no válida: $ubicacion.');
      }
      await _client.rpc('despachar', params: {
        'p_item_orden_id': itemId,
        'p_cantidad': cantidad,
        'p_ubicacion_id': ubicacionId,
      });
      await refrescar();
      return const Ok<void>(null);
    } on PostgrestException catch (e) {
      return Err<void>(e.message);
    } catch (e) {
      return Err<void>('Error inesperado al despachar: $e');
    }
  }

  @override
  Future<List<Causal>> cargarCausales() async {
    final filas = await _client.from('causales_devolucion').select('id, nombre').eq('activa', true).order('nombre');
    return [
      for (final f in (filas as List).cast<Map<String, dynamic>>())
        Causal(id: f['id'] as String, nombre: f['nombre'] as String),
    ];
  }

  @override
  Future<List<String>> cargarPersonalLogistica() async {
    final filas = await _client
        .from('personal_logistica')
        .select('nombre')
        .eq('activo', true)
        .order('nombre');
    return [for (final f in (filas as List).cast<Map<String, dynamic>>()) f['nombre'] as String];
  }

  @override
  Future<Result<String>> agregarPersonalLogistica(String nombre) async {
    try {
      final res = await _client.rpc('agregar_personal_logistica', params: {'p_nombre': nombre});
      final fila = res as Map<String, dynamic>;
      return Ok<String>(fila['nombre'] as String);
    } on PostgrestException catch (e) {
      return Err<String>(e.message);
    } catch (e) {
      return Err<String>('Error inesperado al agregar el nombre: $e');
    }
  }

  @override
  Future<List<String>> cargarPersonalProduccion() async {
    final filas = await _client
        .from('personal_produccion')
        .select('nombre')
        .eq('activo', true)
        .order('nombre');
    return [for (final f in (filas as List).cast<Map<String, dynamic>>()) f['nombre'] as String];
  }

  @override
  Future<Result<String>> agregarPersonalProduccion(String nombre) async {
    try {
      final res = await _client.rpc('agregar_personal_produccion', params: {'p_nombre': nombre});
      final fila = res as Map<String, dynamic>;
      return Ok<String>(fila['nombre'] as String);
    } on PostgrestException catch (e) {
      return Err<String>(e.message);
    } catch (e) {
      return Err<String>('Error inesperado al agregar el nombre: $e');
    }
  }

  @override
  Future<Result<void>> registrarNoConforme({
    required String itemId,
    required int cantidad,
    required String causalId,
    required String operario,
    required String recibidoDeProduccion,
    String nota = '',
  }) async {
    try {
      await _client.rpc('registrar_no_conforme', params: {
        'p_item_orden_id': itemId,
        'p_cantidad': cantidad,
        'p_causal_id': causalId,
        'p_operario_nombre': operario,
        'p_nota': nota,
        'p_recibido_de_produccion': recibidoDeProduccion,
      });
      await refrescar();
      return const Ok<void>(null);
    } on PostgrestException catch (e) {
      return Err<void>(e.message);
    } catch (e) {
      return Err<void>('Error inesperado al registrar el no conforme: $e');
    }
  }

  @override
  Future<Result<void>> liberarNoConforme({
    required String itemId,
    required int cantidad,
    required String operario,
    required String recibidoPorLogistica,
    String nota = '',
  }) async {
    try {
      await _client.rpc('liberar_no_conforme', params: {
        'p_item_orden_id': itemId,
        'p_cantidad': cantidad,
        'p_operario_nombre': operario,
        'p_nota': nota,
        'p_recibido_por_logistica': recibidoPorLogistica,
      });
      await refrescar();
      return const Ok<void>(null);
    } on PostgrestException catch (e) {
      return Err<void>(e.message);
    } catch (e) {
      return Err<void>('Error inesperado al liberar: $e');
    }
  }

  @override
  Future<List<Liberacion>> cargarLiberaciones() async {
    final filas = await _traerTodo(
      (desde, hasta) => _client.from('vista_liberaciones').select().order('creado_en', ascending: false).range(desde, hasta),
    );
    return [
      for (final row in filas)
        Liberacion(
          id: row['id'] as String,
          item: ItemOrden(
            id: row['item_orden_id'] as String,
            op: row['op_numero'] as String,
            cliente: row['item_cliente'] as String,
            oc: '',
            codigo: row['item_codigo'] as String,
            descripcion: row['item_descripcion'] as String,
            talla: row['item_talla'] as String,
            cantidadPedida: 0,
          ),
          cantidad: (row['cantidad'] as num).toInt(),
          operario: row['operario_nombre'] as String,
          fecha: DateTime.parse(row['creado_en'] as String).toLocal(),
          nota: (row['nota'] as String?) ?? '',
          recibidoPorLogistica: (row['recibido_por_logistica'] as String?) ?? '',
        ),
    ];
  }

  @override
  Future<List<Devolucion>> cargarDevoluciones() async {
    final filas = await _traerTodo(
      (desde, hasta) => _client.from('vista_devoluciones').select().order('creado_en', ascending: false).range(desde, hasta),
    );
    return [
      for (final row in filas)
        Devolucion(
          id: row['id'] as String,
          item: ItemOrden(
            id: row['item_orden_id'] as String,
            op: row['op_numero'] as String,
            cliente: row['item_cliente'] as String,
            oc: '',
            codigo: row['item_codigo'] as String,
            descripcion: row['item_descripcion'] as String,
            talla: row['item_talla'] as String,
            cantidadPedida: 0,
          ),
          cantidad: (row['cantidad'] as num).toInt(),
          causal: row['causal_nombre'] as String,
          operario: row['operario_nombre'] as String,
          fecha: DateTime.parse(row['creado_en'] as String).toLocal(),
          nota: (row['nota'] as String?) ?? '',
          recibidoDeProduccion: (row['recibido_de_produccion'] as String?) ?? '',
        ),
    ];
  }
}
ORBILOQ_EOF

echo "  - lib/data/in_memory_wms_repository.dart"
mkdir -p "$(dirname 'lib/data/in_memory_wms_repository.dart')"
cat > 'lib/data/in_memory_wms_repository.dart' << 'ORBILOQ_EOF'
import 'dart:async';

import '../core/constants.dart';
import '../core/result.dart';
import '../domain/models.dart';
import '../domain/wms_repository.dart';

class _Acumulado {
  int producido = 0;
  int recibido = 0;
  int despachado = 0;
  int pendienteReproceso = 0;
  final Map<String, int> ubicaciones = {};
  DateTime? fechaEntrega;
  DateTime? fechaRecepcion;
}

/// Implementación en memoria basada en un libro de movimientos (ledger).
/// Todos los saldos se derivan de los movimientos: no hay contadores que puedan divergir.
class InMemoryWmsRepository implements WmsRepository {
  InMemoryWmsRepository._();

  factory InMemoryWmsRepository.seeded() => InMemoryWmsRepository._().._sembrar();

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
        case TipoMovimiento.devolucionProduccion:
          a.producido -= m.cantidad;
          a.pendienteReproceso += m.cantidad;
        case TipoMovimiento.liberacionNoConforme:
          a.producido += m.cantidad;
          a.pendienteReproceso -= m.cantidad;
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
      pendienteReproceso: a.pendienteReproceso,
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

  int _pendienteProduccion(String itemId) => _snapshot().kardexPorId(itemId)?.pendienteProduccion ?? 0;

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
      if (item == null) return Err<Lote>('Uno de los productos del lote no existe en el kardex.');
      if (linea.cantidad <= 0) return Err<Lote>('Cantidad inválida en uno de los productos del lote.');
      final pendiente = _pendienteProduccion(linea.itemId);
      if (linea.cantidad > pendiente) {
        return Err<Lote>('LÍMITE EXCEDIDO en uno de los productos: solo faltan $pendiente Uds por producir.');
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
      return Err<LoteLinea>('La línea del lote no existe.');
    }
    if (!lineaEncontrada.enTransito) {
      return Err<LoteLinea>('Esta línea ya fue recibida.');
    }
    if (cantidad < 0) return Err<LoteLinea>('La cantidad no puede ser negativa.');
    if (!WmsConstantes.ubicaciones.contains(ubicacion)) {
      return Err<LoteLinea>('Ubicación no válida: $ubicacion.');
    }

    final diff = cantidad - lineaEncontrada.cantidadEnviada;
    var novedad = '';
    if (diff < 0) {
      novedad = 'FALTANTE: Se recibieron $cantidad de ${lineaEncontrada.cantidadEnviada} Uds (faltaron ${-diff}).';
    } else if (diff > 0) {
      novedad = 'SOBRANTE: Se recibieron $cantidad de ${lineaEncontrada.cantidadEnviada} Uds (+$diff).';
    }
    final obs = nota.trim();
    if (obs.isNotEmpty) {
      novedad = novedad.isEmpty ? 'Obs: $obs' : '$novedad Obs: $obs';
    }

    final lineaActualizada = _aplicarRecepcionLinea(
      loteEncontrado, lineaEncontrada, cantidad, ubicacion, novedad, DateTime.now(),
    );
    _emitir();
    return Ok<LoteLinea>(lineaActualizada);
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

  @override
  Future<List<Causal>> cargarCausales() async => [
        for (final nombre in WmsConstantes.causales) Causal(id: nombre, nombre: nombre),
      ];

  @override
  Future<List<String>> cargarPersonalLogistica() async => List.unmodifiable(_personalLogistica);

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
  Future<List<String>> cargarPersonalProduccion() async => List.unmodifiable(_personalProduccion);

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
      return Err<void>('Debes indicar quién de Producción entregó esta prenda.');
    }
    final producido = _snapshot().kardexPorId(itemId)?.producido ?? 0;
    if (cantidad > producido) {
      return Err<void>('LÍMITE EXCEDIDO: solo hay $producido Uds entregadas por Producción para este producto.');
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
  Future<List<Devolucion>> cargarDevoluciones() async => List.unmodifiable(_devoluciones);

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
    final pendienteReproceso = _snapshot().kardexPorId(itemId)?.pendienteReproceso ?? 0;
    if (cantidad > pendienteReproceso) {
      return Err<void>('LÍMITE EXCEDIDO: solo hay $pendienteReproceso Uds pendientes por reprocesar.');
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
    final linea = LoteLinea(id: _nuevoIdLinea(), item: item, cantidadEnviada: cantidad, esReproceso: true);
    _lotes.insert(0, Lote(id: numero, operario: operario, fechaEnvio: fecha, lineas: [linea]));

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
  Future<List<Liberacion>> cargarLiberaciones() async => List.unmodifiable(_liberaciones);

  // ------------------------------------------------ mutaciones sin validar
  // (usadas por los comandos y por la siembra de datos)

  int _correlativoLinea = 0;
  String _nuevoIdLinea() => 'LI-${_correlativoLinea++}';

  Lote _aplicarEntregaLote(List<ItemCantidad> items, String operario, String numero, DateTime fecha) {
    final lineas = <LoteLinea>[];
    for (final linea in items) {
      final item = _items[linea.itemId]!;
      lineas.add(LoteLinea(id: _nuevoIdLinea(), item: item, cantidadEnviada: linea.cantidad));
      _movimientos.add(Movimiento(
        tipo: TipoMovimiento.entregaProduccion,
        itemId: item.id,
        cantidad: linea.cantidad,
        fecha: fecha,
        loteId: numero,
      ));
    }
    final lote = Lote(id: numero, operario: operario, fechaEnvio: fecha, lineas: lineas);
    _lotes.insert(0, lote);
    return lote;
  }

  LoteLinea _aplicarRecepcionLinea(
    Lote lote, LoteLinea linea, int cantidad, String ubicacion, String novedad, DateTime fecha,
  ) {
    final lineaActualizada = linea.copyWith(
      estado: novedad.isEmpty ? EstadoLineaLote.recibidoConforme : EstadoLineaLote.recibidoConNovedad,
      cantidadRecibida: cantidad,
      ubicacionDestino: ubicacion,
      novedad: novedad,
      fechaRecepcion: fecha,
    );

    final idxLote = _lotes.indexWhere((l) => l.id == lote.id);
    final nuevasLineas = [
      for (final l in _lotes[idxLote].lineas) l.id == linea.id ? lineaActualizada : l,
    ];
    final pendientes = nuevasLineas.where((l) => l.enTransito).length;
    _lotes[idxLote] = Lote(
      id: lote.id,
      operario: lote.operario,
      fechaEnvio: lote.fechaEnvio,
      lineas: nuevasLineas,
      estado: pendientes == 0 ? EstadoLote.recibidoCompleto : EstadoLote.recibidoParcial,
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
    final lote095 = _aplicarEntregaLote(
      [ItemCantidad(itemId: blusa.id, cantidad: 160)], op, 'LOTE-095', DateTime(2026, 8, 15, 10),
    );
    _aplicarRecepcionLinea(lote095, lote095.lineas.first, 160, 'ESTANTE A1', '', DateTime(2026, 8, 16, 11, 20));
    _aplicarDespacho(blusa, 160, 'ESTANTE A1', DateTime(2026, 8, 16, 15));

    // ENEL M + ENEL S (100 producidas de golpe): un lote con 2 productos,
    // para que el modo demo también muestre un lote agrupado.
    final lote096 = _aplicarEntregaLote(
      [ItemCantidad(itemId: m.id, cantidad: 841), ItemCantidad(itemId: s.id, cantidad: 50)],
      op, 'LOTE-096', DateTime(2026, 8, 17, 15),
    );
    _aplicarRecepcionLinea(
      lote096, lote096.lineas[0], 841, 'ESTANTE B2', '', DateTime(2026, 8, 17, 16),
    );
    _aplicarRecepcionLinea(
      lote096, lote096.lineas[1], 50, 'ESTANTE A1', '', DateTime(2026, 8, 17, 19, 15),
    );
    _aplicarDespacho(s, 20, 'ESTANTE A1', DateTime(2026, 8, 17, 20));
    _aplicarEntregaLote([ItemCantidad(itemId: s.id, cantidad: 50)], op, 'LOTE-102', DateTime(2026, 8, 18, 9));

    // ENEL XS: 9 producidas (5 recibidas + 4 en tránsito).
    final lote098 = _aplicarEntregaLote(
      [ItemCantidad(itemId: xs.id, cantidad: 5)], op, 'LOTE-098', DateTime(2026, 8, 17, 17, 30),
    );
    _aplicarRecepcionLinea(lote098, lote098.lineas.first, 5, 'ESTANTE A1', '', DateTime(2026, 8, 17, 18, 30));
    _aplicarEntregaLote([ItemCantidad(itemId: xs.id, cantidad: 4)], op, 'LOTE-101', DateTime(2026, 8, 17, 18, 30));

    // COLSUBSIDIO: 20 producidas, en tránsito.
    _aplicarEntregaLote([ItemCantidad(itemId: bata.id, cantidad: 20)], op, 'LOTE-103', DateTime(2026, 8, 20, 8));
  }
}
ORBILOQ_EOF

echo "  - lib/application/providers.dart"
mkdir -p "$(dirname 'lib/application/providers.dart')"
cat > 'lib/application/providers.dart' << 'ORBILOQ_EOF'
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_importador_fechas.dart';
import '../data/supabase_importador_ordenes.dart';
import '../domain/models.dart';
import '../domain/sesion.dart';
import '../domain/wms_repository.dart';
import 'auth_providers.dart';
import 'kardex_columnas.dart';
import 'kardex_filters.dart';

/// Debe sobrescribirse en `main.dart` (o en tests) con la implementación deseada.
final wmsRepositoryProvider = Provider<WmsRepository>(
  (ref) => throw UnimplementedError('Sobrescribe wmsRepositoryProvider en main.dart'),
);

/// Solo disponible cuando la app corre contra Supabase; `null` en modo memoria
/// (la importación de Excel no tiene sentido sin una base de datos real detrás).
final importadorOrdenesProvider = Provider<SupabaseImportadorOrdenes?>((ref) => null);

/// Igual, para el Excel de fechas esperadas.
final importadorFechasProvider = Provider<SupabaseImportadorFechas?>((ref) => null);

final wmsSnapshotProvider = StreamProvider<WmsSnapshot>(
  (ref) => ref.watch(wmsRepositoryProvider).watch(),
);

final kardexProvider = Provider<List<ItemKardex>>(
  (ref) => ref.watch(wmsSnapshotProvider).value?.kardex ?? const <ItemKardex>[],
);

/// Causales disponibles para reportar un producto como no conforme.
final causalesProvider = FutureProvider<List<Causal>>(
  (ref) => ref.watch(wmsRepositoryProvider).cargarCausales(),
);

/// Lista ampliable de personas de Logística que pueden recibir una prenda
/// liberada por Producción. Se invalida tras agregar un nombre nuevo.
final personalLogisticaProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(wmsRepositoryProvider).cargarPersonalLogistica(),
);

/// Lista ampliable de personas de Producción que pueden entregar una prenda
/// no conforme a Logística. Se invalida tras agregar un nombre nuevo.
final personalProduccionProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(wmsRepositoryProvider).cargarPersonalProduccion(),
);

// ------------------------------------------------------------------- rol

class RolNotifier extends Notifier<Rol> {
  @override
  Rol build() {
    final usarSupabase = ref.watch(usarSupabaseProvider);
    if (!usarSupabase) return Rol.produccion; // modo memoria: sin login, libre como antes

    final sesion = ref.watch(usuarioSesionProvider).value;
    if (sesion == null) return Rol.produccion; // aún cargando / sin sesión
    return switch (sesion.rolCuenta) {
      RolCuenta.produccion => Rol.produccion,
      RolCuenta.logistica => Rol.logistica,
      RolCuenta.admin => Rol.produccion, // el admin arranca en Producción y puede cambiar
    };
  }

  void cambiar(Rol rol) {
    if (rol == state) return;
    if (ref.read(usarSupabaseProvider)) {
      final esAdmin = ref.read(usuarioSesionProvider).value?.rolCuenta == RolCuenta.admin;
      if (!esAdmin) return; // Producción/Logística no pueden cambiarse su propio rol
    }
    state = rol;
  }
}

final rolProvider = NotifierProvider<RolNotifier, Rol>(RolNotifier.new);

/// El mapa de "columna -> valor" que le corresponde a la vista actual.
final extractoresColumnaProvider = Provider<Map<String, ExtractorColumna>>((ref) {
  final rol = ref.watch(rolProvider);
  return rol == Rol.produccion ? columnasProduccion : columnasBodega;
});

// --------------------------------------------------------------- filtros

class KardexFiltersNotifier extends Notifier<KardexFilters> {
  @override
  KardexFilters build() => const KardexFilters();

  void setBusqueda(String v) => state = state.conBusqueda(v);
  void setColumna(String columna, Set<String> valores) => state = state.conColumna(columna, valores);
  void limpiar() => state = const KardexFilters();
}

final kardexFiltersProvider =
    NotifierProvider<KardexFiltersNotifier, KardexFilters>(KardexFiltersNotifier.new);

final kardexFiltradoProvider = Provider<List<ItemKardex>>((ref) {
  final kardex = ref.watch(kardexProvider);
  final filtros = ref.watch(kardexFiltersProvider);
  final extractores = ref.watch(extractoresColumnaProvider);
  if (!filtros.hayFiltros) return kardex;
  return kardex.where((i) => filtros.aplica(i, extractores)).toList(growable: false);
});

final kardexResumenProvider = Provider<KardexResumen>((ref) {
  // Reacciona a lo que esté visible según los filtros activos.
  return KardexResumen.desde(ref.watch(kardexFiltradoProvider));
});

final opcionesFiltroProvider = Provider<OpcionesFiltro>((ref) {
  final kardex = ref.watch(kardexProvider);
  final extractores = ref.watch(extractoresColumnaProvider);
  final porColumna = <String, List<String>>{};
  for (final entry in extractores.entries) {
    porColumna[entry.key] = (kardex.map(entry.value).toSet().toList()..sort());
  }
  return OpcionesFiltro(porColumna);
});

// ----------------------------------------------------------- paginación

const kardexFilasPorPagina = 25;

class KardexPaginaNotifier extends Notifier<int> {
  @override
  int build() {
    // Cualquier cambio en los filtros vuelve a la página 1, para no quedar
    // "perdido" en una página que ya no existe tras filtrar.
    ref.listen(kardexFiltersProvider, (_, __) => state = 0);
    return 0;
  }

  void ir(int pagina) => state = pagina;
}

final kardexPaginaProvider = NotifierProvider<KardexPaginaNotifier, int>(KardexPaginaNotifier.new);

final kardexPaginaActualProvider = Provider<List<ItemKardex>>((ref) {
  final filtrado = ref.watch(kardexFiltradoProvider);
  final pagina = ref.watch(kardexPaginaProvider);
  final desde = pagina * kardexFilasPorPagina;
  if (desde >= filtrado.length) return const [];
  final hasta = (desde + kardexFilasPorPagina).clamp(0, filtrado.length);
  return filtrado.sublist(desde, hasta);
});
ORBILOQ_EOF

echo "  - lib/shared/widgets/addable_person_dropdown.dart"
mkdir -p "$(dirname 'lib/shared/widgets/addable_person_dropdown.dart')"
cat > 'lib/shared/widgets/addable_person_dropdown.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../../core/theme/app_theme.dart';

/// Desplegable respaldado por una lista ampliable de nombres: además de
/// elegir uno ya registrado, permite agregar uno nuevo directo desde el
/// formulario (persistido vía [onAgregar] y reflejado invalidando [itemsProvider]).
class AddablePersonDropdown extends ConsumerWidget {
  const AddablePersonDropdown({
    super.key,
    required this.label,
    required this.valor,
    required this.onChanged,
    required this.itemsProvider,
    required this.onAgregar,
    required this.tituloDialogo,
  });

  static const _valorAgregar = '__agregar_nuevo__';

  final String label;
  final String? valor;
  final ValueChanged<String?> onChanged;
  final FutureProvider<List<String>> itemsProvider;
  final Future<Result<String>> Function(WidgetRef ref, String nombre) onAgregar;
  final String tituloDialogo;

  Future<void> _agregarNuevo(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tituloDialogo),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: wmsInput('Nombre completo'),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(ctrl.text.trim()),
            child: const Text('AGREGAR'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (nombre == null || nombre.isEmpty) return;

    final res = await onAgregar(ref, nombre);
    switch (res) {
      case Ok(:final value):
        ref.invalidate(itemsProvider);
        onChanged(value);
      case Err(:final message):
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemsProvider);
    return items.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('No se pudo cargar la lista: $e', style: const TextStyle(color: AppColors.alertRed)),
      data: (lista) => DropdownButtonFormField<String>(
        initialValue: valor,
        decoration: wmsInput(label, icon: Icons.person_outline),
        items: [
          for (final n in lista) DropdownMenuItem(value: n, child: Text(n)),
          const DropdownMenuItem(
            value: _valorAgregar,
            child: Text('+ AGREGAR NUEVA PERSONA…', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
        onChanged: (v) {
          if (v == _valorAgregar) {
            _agregarNuevo(context, ref);
            return;
          }
          onChanged(v);
        },
      ),
    );
  }
}
ORBILOQ_EOF

echo "  - lib/features/no_conforme/presentation/no_conforme_dialog.dart"
mkdir -p "$(dirname 'lib/features/no_conforme/presentation/no_conforme_dialog.dart')"
cat > 'lib/features/no_conforme/presentation/no_conforme_dialog.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/constants.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/fecha.dart';
import '../../../domain/models.dart';
import '../../../domain/qr_prenda.dart';
import '../../../shared/widgets/action_button.dart';
import '../../../shared/widgets/addable_person_dropdown.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/labeled_dropdown.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showNoConformeDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const NoConformeDialog());

class NoConformeDialog extends StatelessWidget {
  const NoConformeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return WmsDialogShell(
      title: 'PRODUCTO NO CONFORME',
      icon: Icons.report_gmailerrorred,
      iconColor: AppColors.alertRed,
      expand: true,
      maxWidth: 1100,
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              labelColor: AppColors.primaryNavy,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primaryNavy,
              labelPadding: EdgeInsets.symmetric(vertical: 4),
              labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              unselectedLabelStyle: TextStyle(fontSize: 11),
              tabs: [
                Tab(height: 38, icon: Icon(Icons.qr_code_scanner, size: 16), text: 'ESCANEAR QR'),
                Tab(height: 38, icon: Icon(Icons.edit_note, size: 16), text: 'BÚSQUEDA MANUAL'),
                Tab(height: 38, icon: Icon(Icons.history, size: 16), text: 'HISTORIAL'),
              ],
            ),
            const SizedBox(height: 8),
            const Expanded(
              child: TabBarView(children: [_EscanearTab(), _ManualTab(), _HistorialTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una tarjeta = un producto que se va a reportar como no conforme, con su
/// propia cantidad, causal y nota. Independiente de cualquier lote.
class _TarjetaNoConforme {
  _TarjetaNoConforme({required this.itemId})
      : cantidadCtrl = TextEditingController(text: '1'),
        notaCtrl = TextEditingController();

  final String itemId;
  final TextEditingController cantidadCtrl;
  final TextEditingController notaCtrl;
  int conteo = 1;
  String? causalId;
  String? recibidoDeProduccion;
  bool enviando = false;
  bool enviada = false;

  void dispose() {
    cantidadCtrl.dispose();
    notaCtrl.dispose();
  }
}

Future<void> _reportarTodo({
  required WidgetRef ref,
  required List<_TarjetaNoConforme> pendientes,
  required String operario,
  required void Function(void Function()) setStateFn,
  required bool Function() estaMontado,
  required void Function(FeedbackMessage?) setMensaje,
}) async {
  for (final t in pendientes) {
    if (t.causalId == null) {
      setMensaje(const FeedbackMessage.error('Hay una tarjeta sin causal seleccionada.'));
      return;
    }
    if (t.recibidoDeProduccion == null || t.recibidoDeProduccion!.trim().isEmpty) {
      setMensaje(const FeedbackMessage.error('Hay una tarjeta sin indicar quién de Producción entregó la prenda.'));
      return;
    }
    final cantidad = int.tryParse(t.cantidadCtrl.text.trim()) ?? 0;
    if (cantidad <= 0) {
      setMensaje(const FeedbackMessage.error('Hay una tarjeta con cantidad inválida.'));
      return;
    }
  }

  setStateFn(() {
    setMensaje(null);
    for (final t in pendientes) {
      t.enviando = true;
    }
  });

  var okCount = 0;
  String? primerError;
  for (final t in pendientes) {
    final cantidad = int.tryParse(t.cantidadCtrl.text.trim()) ?? 0;
    final res = await ref.read(wmsRepositoryProvider).registrarNoConforme(
          itemId: t.itemId,
          cantidad: cantidad,
          causalId: t.causalId!,
          operario: operario,
          recibidoDeProduccion: t.recibidoDeProduccion!.trim(),
          nota: t.notaCtrl.text,
        );
    if (!estaMontado()) return;
    switch (res) {
      case Ok():
        okCount++;
        setStateFn(() {
          t.enviando = false;
          t.enviada = true;
        });
      case Err(:final message):
        primerError ??= message;
        setStateFn(() => t.enviando = false);
    }
  }

  setStateFn(() {
    if (primerError != null) {
      setMensaje(FeedbackMessage.error(
        okCount == 0 ? primerError : '$okCount reportado(s) — falló al menos uno: $primerError',
      ));
    } else {
      setMensaje(FeedbackMessage.ok('$okCount producto(s) reportado(s) como no conforme.'));
    }
  });
}

class _CausalDropdown extends ConsumerWidget {
  const _CausalDropdown({required this.valor, required this.onChanged});

  final String? valor;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final causales = ref.watch(causalesProvider);
    return causales.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('No se pudieron cargar las causales: $e', style: const TextStyle(color: AppColors.alertRed)),
      data: (lista) => DropdownButtonFormField<String>(
        initialValue: valor,
        decoration: wmsInput('Causal de la no conformidad', icon: Icons.report_problem_outlined),
        items: [for (final c in lista) DropdownMenuItem(value: c.id, child: Text(c.nombre))],
        onChanged: onChanged,
      ),
    );
  }
}

// ============================================================ pestaña 1: QR

class _EscanearTab extends ConsumerStatefulWidget {
  const _EscanearTab();

  @override
  ConsumerState<_EscanearTab> createState() => _EscanearTabState();
}

class _EscanearTabState extends ConsumerState<_EscanearTab> with AutomaticKeepAliveClientMixin {
  final _qrCtrl = TextEditingController();
  final _qrFocus = FocusNode();
  String _operario = WmsConstantes.operarios.first;
  final List<_TarjetaNoConforme> _tarjetas = [];
  FeedbackMessage? _msgGeneral;
  bool _enviandoTodo = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _qrCtrl.dispose();
    _qrFocus.dispose();
    for (final t in _tarjetas) {
      t.dispose();
    }
    super.dispose();
  }

  _TarjetaNoConforme? _tarjetaActivaPara(String itemId) {
    for (final t in _tarjetas) {
      if (t.itemId == itemId && !t.enviada) return t;
    }
    return null;
  }

  void _procesarQR(String raw) {
    _qrCtrl.clear();
    if (raw.trim().isEmpty) return;
    final qr = QrPrenda.tryParse(raw);
    if (qr == null) {
      setState(() => _msgGeneral = FeedbackMessage.error('QR inválido. Formato esperado: ${QrPrenda.formato}'));
      return;
    }
    final kardex = ref.read(wmsSnapshotProvider).value?.kardexPorOpCodigo(qr.op, qr.codigo);
    if (kardex == null) {
      setState(() => _msgGeneral =
          FeedbackMessage.error('La prenda no existe en el kardex (OP ${qr.op} · Código ${qr.codigo}).'));
      return;
    }
    setState(() {
      _msgGeneral = null;
      final existente = _tarjetaActivaPara(kardex.id);
      if (existente != null) {
        _tarjetas.remove(existente);
        _tarjetas.insert(0, existente);
        existente.conteo++;
        existente.cantidadCtrl.text = '${existente.conteo}';
      } else {
        _tarjetas.insert(0, _TarjetaNoConforme(itemId: kardex.id));
      }
    });
    _qrFocus.requestFocus();
  }

  void _quitar(_TarjetaNoConforme t) {
    setState(() {
      t.dispose();
      _tarjetas.remove(t);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final snapshot = ref.watch(wmsSnapshotProvider).value;
    final pendientes = _tarjetas.where((t) => !t.enviada).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msgGeneral != null) ...[
            FeedbackBanner(message: _msgGeneral!),
            const SizedBox(height: 12),
          ],
          LabeledDropdown<String>(
            label: 'Reportado por',
            value: _operario,
            items: WmsConstantes.operarios,
            onChanged: (v) => setState(() => _operario = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qrCtrl,
            focusNode: _qrFocus,
            autofocus: true,
            decoration: wmsInput('PISTOLEE O ESCANEE QR DE LA PRENDA NO CONFORME', icon: Icons.qr_code_scanner),
            onSubmitted: _procesarQR,
          ),
          const SizedBox(height: 12),
          if (_tarjetas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Escanea una prenda para reportarla como no conforme.',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  pendientes.isNotEmpty ? '${pendientes.length} producto(s) por reportar' : 'Todo reportado',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                ActionButton(
                  icon: Icons.report_gmailerrorred,
                  label: 'REPORTAR TODO',
                  color: AppColors.alertRed,
                  busy: _enviandoTodo,
                  onPressed: pendientes.isEmpty
                      ? null
                      : () async {
                          setState(() => _enviandoTodo = true);
                          await _reportarTodo(
                            ref: ref,
                            pendientes: pendientes,
                            operario: _operario,
                            setStateFn: setState,
                            estaMontado: () => mounted,
                            setMensaje: (m) => _msgGeneral = m,
                          );
                          if (mounted) setState(() => _enviandoTodo = false);
                        },
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final t in _tarjetas) ...[
              _TarjetaWidget(tarjeta: t, kardex: snapshot?.kardexPorId(t.itemId), onQuitar: () => _quitar(t)),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

// ==================================================== pestaña 2: manual

class _ManualTab extends ConsumerStatefulWidget {
  const _ManualTab();

  @override
  ConsumerState<_ManualTab> createState() => _ManualTabState();
}

class _ManualTabState extends ConsumerState<_ManualTab> with AutomaticKeepAliveClientMixin {
  final _opCtrl = TextEditingController();
  String _operario = WmsConstantes.operarios.first;
  List<ItemKardex> _resultados = [];
  final Set<String> _seleccionados = {};
  final List<_TarjetaNoConforme> _tarjetas = [];
  String? _errorBusqueda;
  FeedbackMessage? _msgGeneral;
  bool _enviandoTodo = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _opCtrl.dispose();
    for (final t in _tarjetas) {
      t.dispose();
    }
    super.dispose();
  }

  _TarjetaNoConforme? _tarjetaActivaPara(String itemId) {
    for (final t in _tarjetas) {
      if (t.itemId == itemId && !t.enviada) return t;
    }
    return null;
  }

  void _buscar() {
    final op = _opCtrl.text.trim();
    final kardex = ref.read(wmsSnapshotProvider).value?.kardex ?? const <ItemKardex>[];
    setState(() {
      _seleccionados.clear();
      if (op.isEmpty) {
        _resultados = [];
        _errorBusqueda = 'Escribe un número de OP.';
        return;
      }
      // Solo tiene sentido reportar productos que ya fueron entregados por Producción.
      _resultados = kardex.where((k) => k.item.op == op && k.producido > 0).toList();
      _errorBusqueda = _resultados.isEmpty
          ? 'No se encontraron tallas con unidades entregadas por Producción para la OP $op.'
          : null;
    });
  }

  void _agregarSeleccionadas() {
    setState(() {
      for (final id in _seleccionados) {
        if (_tarjetaActivaPara(id) != null) continue;
        _tarjetas.insert(0, _TarjetaNoConforme(itemId: id));
      }
      _seleccionados.clear();
      _resultados = [];
      _opCtrl.clear();
    });
  }

  void _quitar(_TarjetaNoConforme t) {
    setState(() {
      t.dispose();
      _tarjetas.remove(t);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final snapshot = ref.watch(wmsSnapshotProvider).value;
    final pendientes = _tarjetas.where((t) => !t.enviada).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msgGeneral != null) ...[
            FeedbackBanner(message: _msgGeneral!),
            const SizedBox(height: 12),
          ],
          LabeledDropdown<String>(
            label: 'Reportado por',
            value: _operario,
            items: WmsConstantes.operarios,
            onChanged: (v) => setState(() => _operario = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _opCtrl,
                  keyboardType: TextInputType.number,
                  decoration: wmsInput('Número de OP', icon: Icons.tag),
                  onSubmitted: (_) => _buscar(),
                ),
              ),
              const SizedBox(width: 10),
              ActionButton(icon: Icons.search, label: 'BUSCAR', color: AppColors.primaryNavy, onPressed: _buscar),
            ],
          ),
          if (_errorBusqueda != null) ...[
            const SizedBox(height: 10),
            FeedbackBanner(message: FeedbackMessage.error(_errorBusqueda!)),
          ],
          if (_resultados.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  for (final r in _resultados)
                    CheckboxListTile(
                      dense: true,
                      value: _seleccionados.contains(r.id),
                      activeColor: AppColors.alertRed,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _seleccionados.add(r.id);
                        } else {
                          _seleccionados.remove(r.id);
                        }
                      }),
                      title: Text(
                        '${r.item.codigo} — ${r.item.descripcion} (Talla ${r.item.talla})',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('Entregadas por Producción: ${r.producido} Uds'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ActionButton(
                icon: Icons.playlist_add,
                label: 'AGREGAR SELECCIONADAS (${_seleccionados.length})',
                color: AppColors.primaryNavy,
                onPressed: _seleccionados.isEmpty ? null : _agregarSeleccionadas,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_tarjetas.isEmpty && _resultados.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Escribe una OP y busca para ver sus tallas entregadas.',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else if (_tarjetas.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  pendientes.isNotEmpty ? '${pendientes.length} producto(s) por reportar' : 'Todo reportado',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                ActionButton(
                  icon: Icons.report_gmailerrorred,
                  label: 'REPORTAR TODO',
                  color: AppColors.alertRed,
                  busy: _enviandoTodo,
                  onPressed: pendientes.isEmpty
                      ? null
                      : () async {
                          setState(() => _enviandoTodo = true);
                          await _reportarTodo(
                            ref: ref,
                            pendientes: pendientes,
                            operario: _operario,
                            setStateFn: setState,
                            estaMontado: () => mounted,
                            setMensaje: (m) => _msgGeneral = m,
                          );
                          if (mounted) setState(() => _enviandoTodo = false);
                        },
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final t in _tarjetas) ...[
              _TarjetaWidget(tarjeta: t, kardex: snapshot?.kardexPorId(t.itemId), onQuitar: () => _quitar(t)),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

// ==================================================== tarjeta (compartida)

class _TarjetaWidget extends StatefulWidget {
  const _TarjetaWidget({required this.tarjeta, required this.kardex, required this.onQuitar});

  final _TarjetaNoConforme tarjeta;
  final ItemKardex? kardex;
  final VoidCallback onQuitar;

  @override
  State<_TarjetaWidget> createState() => _TarjetaWidgetState();
}

class _TarjetaWidgetState extends State<_TarjetaWidget> {
  @override
  Widget build(BuildContext context) {
    final k = widget.kardex;
    final t = widget.tarjeta;
    if (k == null) return const SizedBox.shrink();
    final enviada = t.enviada;

    return Card(
      color: enviada ? Colors.grey.shade100 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${k.item.codigo} - ${k.item.descripcion} (${k.item.talla})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: enviada ? Colors.grey.shade600 : AppColors.primaryNavy,
                        ),
                      ),
                      Text('OP: ${k.item.op} | Entregadas por Producción: ${k.producido} Uds',
                          style: TextStyle(color: enviada ? Colors.grey.shade600 : null)),
                    ],
                  ),
                ),
                if (enviada)
                  const Icon(Icons.check_circle, color: AppColors.actionGreen)
                else if (t.enviando)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  IconButton(
                    tooltip: 'Quitar esta tarjeta',
                    icon: const Icon(Icons.close, color: AppColors.alertRed),
                    onPressed: widget.onQuitar,
                  ),
              ],
            ),
            const Divider(),
            if (!enviada) ...[
              MetricWrap(children: [
                MetricCard(
                  title: 'ENTREGADAS',
                  value: '${k.producido} Uds',
                  color: AppColors.actionGreen,
                  icon: Icons.check_circle,
                ),
                MetricCard(
                  title: 'NO CONFORME ACTUAL',
                  value: '${k.pendienteReproceso} Uds',
                  color: k.pendienteReproceso > 0 ? AppColors.alertRed : Colors.grey,
                  icon: Icons.report_problem_outlined,
                ),
              ]),
              const SizedBox(height: 12),
              _CausalDropdown(
                valor: t.causalId,
                onChanged: (v) => setState(() => t.causalId = v),
              ),
              const SizedBox(height: 10),
              AddablePersonDropdown(
                label: 'Quién de Producción entregó la prenda',
                valor: t.recibidoDeProduccion,
                onChanged: (v) => setState(() => t.recibidoDeProduccion = v),
                itemsProvider: personalProduccionProvider,
                onAgregar: (ref, nombre) => ref.read(wmsRepositoryProvider).agregarPersonalProduccion(nombre),
                tituloDialogo: 'Agregar persona de Producción',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: t.cantidadCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: wmsInput('Cantidad no conforme (máx ${k.producido} Uds)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: t.notaCtrl,
                      decoration: wmsInput('Nota (opcional)', icon: Icons.note_outlined),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================================================== pestaña 3: historial

class _HistorialTab extends ConsumerStatefulWidget {
  const _HistorialTab();

  @override
  ConsumerState<_HistorialTab> createState() => _HistorialTabState();
}

class _HistorialTabState extends ConsumerState<_HistorialTab> {
  late Future<List<Devolucion>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = ref.read(wmsRepositoryProvider).cargarDevoluciones();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Devolucion>>(
      future: _futuro,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('No se pudo cargar el historial: ${snapshot.error}'));
        }
        final devoluciones = snapshot.data ?? const [];
        if (devoluciones.isEmpty) {
          return const Center(
            child: Text('Aún no hay productos no conformes reportados.', style: TextStyle(color: Colors.grey)),
          );
        }
        return ListView.builder(
          itemCount: devoluciones.length,
          itemBuilder: (_, i) {
            final d = devoluciones[i];
            return Card(
              child: ListTile(
                dense: true,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.alertRed,
                  child: Icon(Icons.report_problem_outlined, color: Colors.white, size: 18),
                ),
                title: Text(
                  '${d.item.codigo} (${d.item.talla}) — ${d.cantidad} Uds — ${d.causal}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'OP: ${d.item.op} | Reportado por: ${d.operario}'
                  '${d.recibidoDeProduccion.isNotEmpty ? ' | Recibido de Producción: ${d.recibidoDeProduccion}' : ''}'
                  ' | ${formatFechaHora(d.fecha)}'
                  '${d.nota.isNotEmpty ? ' | ${d.nota}' : ''}',
                ),
              ),
            );
          },
        );
      },
    );
  }
}
ORBILOQ_EOF

echo "  - lib/features/reproceso/presentation/reproceso_dialog.dart"
mkdir -p "$(dirname 'lib/features/reproceso/presentation/reproceso_dialog.dart')"
cat > 'lib/features/reproceso/presentation/reproceso_dialog.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/constants.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/fecha.dart';
import '../../../domain/models.dart';
import '../../../domain/qr_prenda.dart';
import '../../../shared/widgets/action_button.dart';
import '../../../shared/widgets/addable_person_dropdown.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/labeled_dropdown.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showReprocesoDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const ReprocesoDialog());

class ReprocesoDialog extends StatelessWidget {
  const ReprocesoDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return WmsDialogShell(
      title: 'PRODUCTOS NO CONFORME',
      icon: Icons.report_gmailerrorred,
      iconColor: AppColors.alertRed,
      expand: true,
      maxWidth: 1100,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              labelColor: AppColors.primaryNavy,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primaryNavy,
              labelPadding: EdgeInsets.symmetric(vertical: 4),
              labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              unselectedLabelStyle: TextStyle(fontSize: 11),
              tabs: [
                Tab(height: 38, icon: Icon(Icons.report_problem_outlined, size: 16), text: 'NO CONFORME'),
                Tab(height: 38, icon: Icon(Icons.history, size: 16), text: 'HISTORIAL'),
              ],
            ),
            const SizedBox(height: 8),
            const Expanded(
              child: TabBarView(children: [_ListaTab(), _HistorialTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================ pestaña 1

class _ListaTab extends ConsumerStatefulWidget {
  const _ListaTab();

  @override
  ConsumerState<_ListaTab> createState() => _ListaTabState();
}

class _ListaTabState extends ConsumerState<_ListaTab> {
  final _opCtrl = TextEditingController();
  final _qrCtrl = TextEditingController();
  final Map<String, TextEditingController> _cantidadCtrls = {};
  final Map<String, bool> _liberando = {};
  final Map<String, String?> _recibidoPorLogistica = {};
  String _operario = WmsConstantes.operarios.first;
  String _filtroOp = '';
  FeedbackMessage? _msgGeneral;
  late Future<Map<String, List<String>>> _motivosFuturo;

  @override
  void initState() {
    super.initState();
    _motivosFuturo = _cargarMotivos();
  }

  /// Agrupa los motivos (causales) ya reportados por producto, para
  /// mostrarlos en cada tarjeta. Una misma prenda puede tener más de un
  /// motivo si se reportó no conforme más de una vez por razones distintas.
  Future<Map<String, List<String>>> _cargarMotivos() async {
    final devoluciones = await ref.read(wmsRepositoryProvider).cargarDevoluciones();
    final mapa = <String, List<String>>{};
    for (final d in devoluciones) {
      final lista = mapa.putIfAbsent(d.item.id, () => []);
      if (!lista.contains(d.causal)) lista.add(d.causal);
    }
    return mapa;
  }

  @override
  void dispose() {
    _opCtrl.dispose();
    _qrCtrl.dispose();
    for (final c in _cantidadCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrlPara(ItemKardex k) =>
      _cantidadCtrls.putIfAbsent(k.id, () => TextEditingController(text: '${k.pendienteReproceso}'));

  void _buscarOp() => setState(() => _filtroOp = _opCtrl.text.trim());

  void _limpiarFiltro() => setState(() {
        _filtroOp = '';
        _opCtrl.clear();
      });

  void _procesarQR(String raw) {
    _qrCtrl.clear();
    if (raw.trim().isEmpty) return;
    final qr = QrPrenda.tryParse(raw);
    if (qr == null) {
      setState(() => _msgGeneral = FeedbackMessage.error('QR inválido. Formato esperado: ${QrPrenda.formato}'));
      return;
    }
    final kardex = ref.read(wmsSnapshotProvider).value?.kardexPorOpCodigo(qr.op, qr.codigo);
    if (kardex == null) {
      setState(() => _msgGeneral = FeedbackMessage.error('La prenda no existe en el kardex.'));
      return;
    }
    if (kardex.pendienteReproceso <= 0) {
      setState(() => _msgGeneral =
          FeedbackMessage.error('${kardex.item.descripcion} (${kardex.item.talla}) no tiene unidades no conformes.'));
      return;
    }
    setState(() {
      _msgGeneral = null;
      _filtroOp = kardex.item.op;
      _opCtrl.text = kardex.item.op;
    });
  }

  Future<void> _liberar(ItemKardex k) async {
    final ctrl = _ctrlPara(k);
    final cantidad = int.tryParse(ctrl.text.trim()) ?? 0;
    if (cantidad <= 0) {
      setState(() => _msgGeneral = const FeedbackMessage.error('Ingresa una cantidad mayor a 0.'));
      return;
    }
    if (cantidad > k.pendienteReproceso) {
      setState(() => _msgGeneral =
          FeedbackMessage.error('LÍMITE EXCEDIDO: solo hay ${k.pendienteReproceso} Uds pendientes por reprocesar.'));
      return;
    }
    final recibidoPor = _recibidoPorLogistica[k.id]?.trim() ?? '';
    if (recibidoPor.isEmpty) {
      setState(() => _msgGeneral =
          const FeedbackMessage.error('Indica quién de Logística recibió esta prenda antes de liberar.'));
      return;
    }

    setState(() {
      _msgGeneral = null;
      _liberando[k.id] = true;
    });
    final res = await ref.read(wmsRepositoryProvider).liberarNoConforme(
          itemId: k.id,
          cantidad: cantidad,
          operario: _operario,
          recibidoPorLogistica: recibidoPor,
        );
    if (!mounted) return;
    setState(() {
      _liberando[k.id] = false;
      switch (res) {
        case Ok():
          _msgGeneral = FeedbackMessage.ok(
            '${cantidad}u de ${k.item.descripcion} (${k.item.talla}) liberadas — vuelven a Entregado a Logística.',
          );
          _cantidadCtrls.remove(k.id)?.dispose();
          _recibidoPorLogistica.remove(k.id);
        case Err(:final message):
          _msgGeneral = FeedbackMessage.error(message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final kardex = ref.watch(wmsSnapshotProvider).value?.kardex ?? const <ItemKardex>[];
    final noConformes = kardex.where((k) => k.pendienteReproceso > 0).toList()
      ..sort((a, b) => a.item.op.compareTo(b.item.op));
    final visibles =
        _filtroOp.isEmpty ? noConformes : noConformes.where((k) => k.item.op == _filtroOp).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_msgGeneral != null) ...[
          FeedbackBanner(message: _msgGeneral!),
          const SizedBox(height: 12),
        ],
        LabeledDropdown<String>(
          label: 'Liberado por',
          value: _operario,
          items: WmsConstantes.operarios,
          onChanged: (v) => setState(() => _operario = v),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _opCtrl,
                keyboardType: TextInputType.number,
                decoration: wmsInput('Buscar por número de OP', icon: Icons.tag),
                onSubmitted: (_) => _buscarOp(),
              ),
            ),
            const SizedBox(width: 8),
            ActionButton(icon: Icons.search, label: 'BUSCAR', color: AppColors.primaryNavy, onPressed: _buscarOp),
            if (_filtroOp.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton(tooltip: 'Quitar filtro', icon: const Icon(Icons.close), onPressed: _limpiarFiltro),
            ],
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _qrCtrl,
          decoration: wmsInput('O ESCANEAR QR PARA ENCONTRAR UNA PRENDA', icon: Icons.qr_code_scanner),
          onSubmitted: _procesarQR,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: visibles.isEmpty
              ? Center(
                  child: Text(
                    noConformes.isEmpty
                        ? 'No hay productos no conformes en este momento.'
                        : 'Ninguno coincide con la OP $_filtroOp.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              : FutureBuilder<Map<String, List<String>>>(
                  future: _motivosFuturo,
                  builder: (context, snapshotMotivos) {
                    final motivos = snapshotMotivos.data ?? const {};
                    return ListView.builder(
                      itemCount: visibles.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TarjetaNoConforme(
                          kardex: visibles[i],
                          cantidadCtrl: _ctrlPara(visibles[i]),
                          liberando: _liberando[visibles[i].id] ?? false,
                          motivos: motivos[visibles[i].id] ?? const [],
                          recibidoPorLogistica: _recibidoPorLogistica[visibles[i].id],
                          onRecibidoPorLogisticaChanged: (v) =>
                              setState(() => _recibidoPorLogistica[visibles[i].id] = v),
                          onLiberar: () => _liberar(visibles[i]),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TarjetaNoConforme extends StatelessWidget {
  const _TarjetaNoConforme({
    required this.kardex,
    required this.cantidadCtrl,
    required this.liberando,
    required this.motivos,
    required this.recibidoPorLogistica,
    required this.onRecibidoPorLogisticaChanged,
    required this.onLiberar,
  });

  final ItemKardex kardex;
  final TextEditingController cantidadCtrl;
  final bool liberando;
  final List<String> motivos;
  final String? recibidoPorLogistica;
  final ValueChanged<String?> onRecibidoPorLogisticaChanged;
  final VoidCallback onLiberar;

  @override
  Widget build(BuildContext context) {
    final k = kardex;
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${k.item.codigo} - ${k.item.descripcion} (${k.item.talla})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy),
            ),
            Text('OP: ${k.item.op} | OC: ${k.item.oc} | Cliente: ${k.item.cliente}'),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.report_problem_outlined, size: 16, color: AppColors.alertRed),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    motivos.isEmpty ? 'Motivo: sin registrar' : 'Motivo(s): ${motivos.join(', ')}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.alertRed,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            MetricWrap(children: [
              MetricCard(
                title: 'ENTREGADO A LOGÍSTICA',
                value: '${k.producido} Uds',
                color: AppColors.actionGreen,
                icon: Icons.check_circle,
              ),
              MetricCard(
                title: 'NO CONFORME',
                value: '${k.pendienteReproceso} Uds',
                color: AppColors.alertRed,
                icon: Icons.report_problem_outlined,
              ),
            ]),
            const SizedBox(height: 12),
            AddablePersonDropdown(
              label: 'Quién de Logística recibió la prenda',
              valor: recibidoPorLogistica,
              onChanged: onRecibidoPorLogisticaChanged,
              itemsProvider: personalLogisticaProvider,
              onAgregar: (ref, nombre) => ref.read(wmsRepositoryProvider).agregarPersonalLogistica(nombre),
              tituloDialogo: 'Agregar persona de Logística',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: cantidadCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: wmsInput('Cantidad a liberar (máx ${k.pendienteReproceso} Uds)'),
                  ),
                ),
                const SizedBox(width: 10),
                ActionButton(
                  icon: Icons.check_circle_outline,
                  label: 'LIBERAR',
                  color: AppColors.actionGreen,
                  busy: liberando,
                  onPressed: onLiberar,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================== pestaña 2: historial

class _HistorialTab extends ConsumerStatefulWidget {
  const _HistorialTab();

  @override
  ConsumerState<_HistorialTab> createState() => _HistorialTabState();
}

class _HistorialTabState extends ConsumerState<_HistorialTab> {
  late Future<List<Liberacion>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = ref.read(wmsRepositoryProvider).cargarLiberaciones();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Liberacion>>(
      future: _futuro,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('No se pudo cargar el historial: ${snapshot.error}'));
        }
        final liberaciones = snapshot.data ?? const [];
        if (liberaciones.isEmpty) {
          return const Center(child: Text('Aún no hay liberaciones registradas.', style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          itemCount: liberaciones.length,
          itemBuilder: (_, i) {
            final l = liberaciones[i];
            return Card(
              child: ListTile(
                dense: true,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.actionGreen,
                  child: Icon(Icons.check, color: Colors.white, size: 18),
                ),
                title: Text(
                  '${l.item.codigo} (${l.item.talla}) — ${l.cantidad} Uds liberadas',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'OP: ${l.item.op} | Por: ${l.operario}'
                  '${l.recibidoPorLogistica.isNotEmpty ? ' | Recibido por Logística: ${l.recibidoPorLogistica}' : ''}'
                  ' | ${formatFechaHora(l.fecha)}'
                  '${l.nota.isNotEmpty ? ' | ${l.nota}' : ''}',
                ),
              ),
            );
          },
        );
      },
    );
  }
}
ORBILOQ_EOF

echo "Listo. Revisa el diff con: git diff --stat"
