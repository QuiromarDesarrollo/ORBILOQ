import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/result.dart';
import '../domain/models.dart';
import '../domain/wms_repository.dart';

/// Implementación real contra Supabase. Las reglas de negocio (límites de
/// producción, validación de stock) viven en funciones RPC de Postgres
/// (`entregar_lote`, `recibir_lote`, `despachar`), no aquí — así quedan
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
          table: 'remisiones',
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
  /// sin esto, tablas grandes (como el kardex con miles de líneas) se
  /// cortan en silencio y la app termina sin ver datos que sí existen.
  Future<List<Map<String, dynamic>>> _traerTodo(
    dynamic Function(int desde, int hasta) construirConsulta, {
    String etiqueta = '',
  }) async {
    const tamPagina = 1000;
    final todas = <Map<String, dynamic>>[];
    var desde = 0;
    var vuelta = 0;
    while (true) {
      vuelta++;
      final resultado = await construirConsulta(desde, desde + tamPagina - 1);
      final lote = (resultado as List).cast<Map<String, dynamic>>();
      debugPrint(
        '[ORBILOQ][$etiqueta] vuelta $vuelta: pedí rango $desde-${desde + tamPagina - 1}, '
        'llegaron ${lote.length} filas',
      );
      if (lote.isEmpty) break;
      todas.addAll(lote);
      // Avanza según lo que realmente llegó (no según lo pedido): si el
      // servidor entrega menos de tamPagina por su propio límite, esto
      // evita saltarse filas en la siguiente página.
      desde += lote.length;
    }
    debugPrint('[ORBILOQ][$etiqueta] TOTAL acumulado: ${todas.length} filas');
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
      etiqueta: 'vista_kardex',
    );
    debugPrint(
      '[ORBILOQ][vista_kardex] ¿contiene OP 25079? '
      '${kardexRows.any((r) => r['numero_op']?.toString() == '25079')}',
    );

    final stockRows = await _traerTodo(
      (desde, hasta) => _client.from('vista_stock_ubicacion_detalle').select().range(desde, hasta),
      etiqueta: 'vista_stock_ubicacion_detalle',
    );

    final remisionesRows = await _traerTodo(
      (desde, hasta) => _client
          .from('vista_remisiones')
          .select()
          .order('fecha_envio', ascending: false)
          .range(desde, hasta),
      etiqueta: 'vista_remisiones',
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

    final remisiones = [
      for (final row in remisionesRows) _remisionDesdeFila(row),
    ];

    return WmsSnapshot(
      kardex: kardex,
      remisiones: remisiones,
      // El número lo genera el servidor (secuencia de Postgres); no hace
      // falta calcularlo en el cliente.
      proximaRemision: 'Automático',
    );
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
      fechaEntregaLogistica: _fecha(row['fecha_entrega_logistica']),
    );
  }

  Remision _remisionDesdeFila(Map<String, dynamic> row) {
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
    return Remision(
      id: row['numero'] as String,
      item: item,
      operario: row['operario_nombre'] as String,
      fechaEnvio: DateTime.parse(row['fecha_envio'] as String).toLocal(),
      cantidadEnviada: (row['cantidad_enviada'] as num).toInt(),
      estado: _estadoDesde(row['estado'] as String),
      cantidadRecibida: (row['cantidad_recibida'] as num?)?.toInt(),
      ubicacionDestino: row['ubicacion_destino_codigo'] as String?,
      novedad: (row['novedad'] as String?) ?? '',
      fechaRecepcion: _fecha(row['fecha_recepcion']),
    );
  }

  EstadoRemision _estadoDesde(String v) => switch (v) {
        'recibido_conforme' => EstadoRemision.recibidoConforme,
        'recibido_con_novedad' => EstadoRemision.recibidoConNovedad,
        _ => EstadoRemision.enTransito,
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

  // -------------------------------------------------------------- comandos

  @override
  Future<Result<Remision>> entregarLote({
    required String itemId,
    required int cantidad,
    required String operario,
    String? numeroRemision,
  }) async {
    try {
      final res = await _client.rpc('entregar_lote', params: {
        'p_item_orden_id': itemId,
        'p_cantidad': cantidad,
        'p_operario_nombre': operario,
        'p_numero_remision': (numeroRemision == null || numeroRemision.trim().isEmpty)
            ? null
            : numeroRemision.trim(),
      });
      final numero = (res as Map)['numero'] as String;
      await refrescar();
      final remision = _ultimo?.remisiones.where((r) => r.id == numero).firstOrNull;
      if (remision == null) {
        return Err<Remision>('La remisión $numero se creó, pero no se pudo leer de vuelta.');
      }
      return Ok<Remision>(remision);
    } on PostgrestException catch (e) {
      return Err<Remision>(e.message);
    } catch (e) {
      return Err<Remision>('Error inesperado al entregar el lote: $e');
    }
  }

  @override
  Future<Result<Remision>> recibirLote({
    required String remisionId,
    required int cantidad,
    required String ubicacion,
    String nota = '',
  }) async {
    try {
      final ubicacionId = await _idDeUbicacion(ubicacion);
      if (ubicacionId == null) {
        return Err<Remision>('Ubicación no válida: $ubicacion.');
      }
      await _client.rpc('recibir_lote', params: {
        'p_remision_numero': remisionId,
        'p_cantidad': cantidad,
        'p_ubicacion_id': ubicacionId,
        'p_nota': nota,
      });
      await refrescar();
      final remision = _ultimo?.remisiones.where((r) => r.id == remisionId).firstOrNull;
      if (remision == null) {
        return Err<Remision>('La remisión se actualizó, pero no se pudo leer de vuelta.');
      }
      return Ok<Remision>(remision);
    } on PostgrestException catch (e) {
      return Err<Remision>(e.message);
    } catch (e) {
      return Err<Remision>('Error inesperado al recibir el lote: $e');
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
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
