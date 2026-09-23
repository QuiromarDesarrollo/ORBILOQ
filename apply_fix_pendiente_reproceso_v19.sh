#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Agrega pendienteReproceso que faltaba enviar (v19)
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_fix_pendiente_reproceso_v19.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi
echo "Aplicando el campo que faltaba..."

echo "  - lib/domain/models.dart"
mkdir -p "$(dirname 'lib/domain/models.dart')"
cat > 'lib/domain/models.dart' << 'ORBILOQ_EOF'
import 'dart:math' as math;

/// Perfil operativo. Hoy solo cambia la UI; en producción debe provenir del
/// usuario autenticado y reforzarse con RLS en la base de datos.
enum Rol {
  produccion('PRODUCCIÓN (TALLER)'),
  logistica('LOGÍSTICA (BODEGA)');

  const Rol(this.etiqueta);
  final String etiqueta;
}

enum EstadoRemision {
  enTransito('EN TRÁNSITO'),
  recibidoConforme('RECIBIDO CONFORME'),
  recibidoConNovedad('RECIBIDO CON NOVEDAD');

  const EstadoRemision(this.etiqueta);
  final String etiqueta;
}

enum TipoMovimiento { entregaProduccion, recepcion, despacho }

enum EstadoItem {
  enProduccion('EN PRODUCCIÓN'),
  recepcionParcial('RECEPCIÓN PARCIAL'),
  recibidoTotal('RECIBIDO TOTAL'),
  excedente('EXCEDENTE'),
  despachoParcial('DESPACHO PARCIAL'),
  despachadoTotal('DESPACHADO TOTAL');

  const EstadoItem(this.etiqueta);
  final String etiqueta;
}

/// Clave única de una línea de orden (OP + OC + código + talla).
String buildItemId(String op, String oc, String codigo, String talla) =>
    '$op|$oc|$codigo|$talla';

/// Línea de una orden de producción (dato maestro, inmutable).
///
/// [id] es la clave real que usan los repositorios para referenciar esta
/// línea (en Supabase, el UUID de `items_orden.id`; en el repositorio en
/// memoria, la clave compuesta [buildItemId]).
class ItemOrden {
  const ItemOrden({
    required this.id,
    required this.op,
    required this.cliente,
    required this.oc,
    required this.codigo,
    required this.descripcion,
    required this.talla,
    required this.cantidadPedida,
    this.observacionOp = '',
  });

  final String id;
  final String op;
  final String cliente;
  final String oc;
  final String codigo;
  final String descripcion;
  final String talla;
  final int cantidadPedida;
  final String observacionOp;
}

/// Movimiento inmutable del libro de movimientos (ledger). Es la única fuente
/// de verdad: producido, recibido, despachado y stock por ubicación se derivan de aquí.
class Movimiento {
  const Movimiento({
    required this.tipo,
    required this.itemId,
    required this.cantidad,
    required this.fecha,
    this.ubicacion,
    this.remisionId,
    this.nota = '',
  });

  final TipoMovimiento tipo;
  final String itemId;
  final int cantidad;
  final DateTime fecha;
  final String? ubicacion;
  final String? remisionId;
  final String nota;
}

/// Lote enviado por producción hacia bodega.
class Remision {
  const Remision({
    required this.id,
    required this.item,
    required this.operario,
    required this.fechaEnvio,
    required this.cantidadEnviada,
    this.estado = EstadoRemision.enTransito,
    this.cantidadRecibida,
    this.ubicacionDestino,
    this.novedad = '',
    this.fechaRecepcion,
  });

  final String id;
  final ItemOrden item;
  final String operario;
  final DateTime fechaEnvio;
  final int cantidadEnviada;
  final EstadoRemision estado;
  final int? cantidadRecibida;
  final String? ubicacionDestino;
  final String novedad;
  final DateTime? fechaRecepcion;

  bool get enTransito => estado == EstadoRemision.enTransito;

  Remision copyWith({
    EstadoRemision? estado,
    int? cantidadRecibida,
    String? ubicacionDestino,
    String? novedad,
    DateTime? fechaRecepcion,
  }) {
    return Remision(
      id: id,
      item: item,
      operario: operario,
      fechaEnvio: fechaEnvio,
      cantidadEnviada: cantidadEnviada,
      estado: estado ?? this.estado,
      cantidadRecibida: cantidadRecibida ?? this.cantidadRecibida,
      ubicacionDestino: ubicacionDestino ?? this.ubicacionDestino,
      novedad: novedad ?? this.novedad,
      fechaRecepcion: fechaRecepcion ?? this.fechaRecepcion,
    );
  }
}

/// Fila del kardex: línea de orden + saldos derivados de los movimientos.
class ItemKardex {
  const ItemKardex({
    required this.item,
    required this.producido,
    required this.recibido,
    required this.despachado,
    required this.ubicaciones,
    this.fechaEntrega,
    this.fechaRecepcion,
    this.fechaEntregaLogistica,
    this.pendienteReproceso = 0,
  });

  final ItemOrden item;
  final int producido;
  final int recibido;
  final int despachado;

  /// Stock por ubicación (solo cantidades > 0).
  final Map<String, int> ubicaciones;
  final DateTime? fechaEntrega;
  final DateTime? fechaRecepcion;

  /// Fecha comprometida de entrega al cliente final (viene del Excel de
  /// fechas de entrega logística; puede no existir todavía).
  final DateTime? fechaEntregaLogistica;

  /// Unidades devueltas a Producción por no conformidad, aún sin reprocesar.
  final int pendienteReproceso;

  String get id => item.id;
  int get cantidadPedida => item.cantidadPedida;

  int get stockDisponible => recibido - despachado;
  int get pendienteProduccion => math.max(0, cantidadPedida - producido);
  int get pendienteRecibir => math.max(0, cantidadPedida - recibido);
  int get excedente => math.max(0, recibido - cantidadPedida);
  int get pendienteDespacho => math.max(0, cantidadPedida - despachado);

  int stockEn(String ubicacion) => ubicaciones[ubicacion] ?? 0;

  EstadoItem get estado {
    if (cantidadPedida > 0 && despachado >= cantidadPedida) {
      return EstadoItem.despachadoTotal;
    }
    if (despachado > 0) return EstadoItem.despachoParcial;
    if (recibido > cantidadPedida) return EstadoItem.excedente;
    if (recibido > 0 && recibido == cantidadPedida) return EstadoItem.recibidoTotal;
    if (recibido > 0) return EstadoItem.recepcionParcial;
    return EstadoItem.enProduccion;
  }

  String get estadoEtiqueta =>
      estado == EstadoItem.excedente ? 'EXCEDENTE (+$excedente)' : estado.etiqueta;

  String get ubicacionesFormateadas {
    if (ubicaciones.isEmpty) return 'SIN UBICACIÓN';
    return ubicaciones.entries.map((e) => '${e.key} (${e.value})').join(' | ');
  }
}

/// Foto inmutable del estado completo que consume la UI.
class WmsSnapshot {
  WmsSnapshot({
    required this.kardex,
    required this.remisiones,
    required this.proximaRemision,
  });

  final List<ItemKardex> kardex;

  /// Más recientes primero.
  final List<Remision> remisiones;
  final String proximaRemision;

  late final Map<String, ItemKardex> _porId = {for (final k in kardex) k.id: k};
  late final Map<String, ItemKardex> _porOpCodigo = {
    for (final k in kardex) '${k.item.op}|${k.item.codigo}': k,
  };
  late final int remisionesEnTransito = remisiones.where((r) => r.enTransito).length;

  ItemKardex? kardexPorId(String id) => _porId[id];

  /// El QR real de la marquilla trae OP + Código, sin talla (el código ya es
  /// único por talla dentro de cada OP). Esta es la búsqueda que usa el escaneo.
  ItemKardex? kardexPorOpCodigo(String op, String codigo) => _porOpCodigo['$op|$codigo'];
}
ORBILOQ_EOF

echo "  - lib/data/supabase_wms_repository.dart"
mkdir -p "$(dirname 'lib/data/supabase_wms_repository.dart')"
cat > 'lib/data/supabase_wms_repository.dart' << 'ORBILOQ_EOF'
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
      pendienteReproceso: (row['pendiente_reproceso'] as num?)?.toInt() ?? 0,
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
ORBILOQ_EOF

echo ""
echo "Listo. flutter analyze / flutter test"
