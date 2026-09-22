#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Rediseno visual del kardex (v13)
# Nuevo header, tarjetas de resumen, filtros por busqueda+cliente+estado,
# tabla rediseñada con paginacion real. Aplica a ambos roles.
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_rediseno_kardex_v13.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi

echo "Aplicando el rediseno del kardex..."

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

echo "  - lib/core/theme/app_theme.dart"
mkdir -p "$(dirname 'lib/core/theme/app_theme.dart')"
cat > 'lib/core/theme/app_theme.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primaryNavy = Color(0xFF173559);
  static const secondaryNavy = Color(0xFF1F436E);
  static const actionGreen = Color(0xFF2E8B57);
  static const actionOrange = Color(0xFFF37021);
  static const alertRed = Color(0xFFD32F2F);
  static const accentCyan = Color(0xFF00A8CC);
  static const background = Color(0xFFF4F6F9);

  // ---- Paleta del rediseño del Kardex (pantalla principal) ----
  static const tealPrimary = Color(0xFF0F766E);
  static const tealDark = Color(0xFF0B5750);
  static const tealSoft = Color(0xFFE6F4F2);
  static const slate900 = Color(0xFF0F172A);
  static const slate600 = Color(0xFF475569);
  static const slate400 = Color(0xFF94A3B8);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate50 = Color(0xFFF8FAFC);
  static const cardBorder = Color(0xFFE5E9F0);
  static const amberChip = Color(0xFFB45309);
  static const amberChipBg = Color(0xFFFFF7ED);
  static const redChipBg = Color(0xFFFEF2F2);
  static const greenChipBg = Color(0xFFECFDF5);
  static const blueChipBg = Color(0xFFEFF6FF);
  static const blueChip = Color(0xFF1D4ED8);
}

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryNavy),
        scaffoldBackgroundColor: AppColors.background,
      );
}

/// Decoración estándar de campos de texto.
InputDecoration wmsInput(String label, {IconData? icon, String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon),
    border: const OutlineInputBorder(),
    isDense: true,
  );
}
ORBILOQ_EOF

echo "  - lib/application/kardex_filters.dart"
mkdir -p "$(dirname 'lib/application/kardex_filters.dart')"
cat > 'lib/application/kardex_filters.dart' << 'ORBILOQ_EOF'
import '../domain/models.dart';

/// Filtros del kardex: búsqueda libre + cliente + estado, todos opcionales.
/// `null`/vacío en cualquiera de ellos significa "sin restricción en ese campo".
class KardexFilters {
  const KardexFilters({
    this.busqueda = '',
    this.cliente,
    this.estado,
  });

  final String busqueda;
  final String? cliente;
  final String? estado; // etiqueta de EstadoItem, o null = todos

  bool get hayFiltros => busqueda.trim().isNotEmpty || cliente != null || estado != null;

  KardexFilters copyWith({
    String? busqueda,
    Object? cliente = _sinCambio,
    Object? estado = _sinCambio,
  }) {
    return KardexFilters(
      busqueda: busqueda ?? this.busqueda,
      cliente: identical(cliente, _sinCambio) ? this.cliente : cliente as String?,
      estado: identical(estado, _sinCambio) ? this.estado : estado as String?,
    );
  }

  bool aplica(ItemKardex i) {
    if (cliente != null && i.item.cliente != cliente) return false;
    if (estado != null && i.estadoEtiqueta != estado) return false;
    final q = busqueda.trim().toLowerCase();
    if (q.isNotEmpty) {
      final texto = '${i.item.op} ${i.item.cliente} ${i.item.oc} ${i.item.codigo} '
              '${i.item.descripcion} ${i.item.talla}'
          .toLowerCase();
      if (!texto.contains(q)) return false;
    }
    return true;
  }
}

const _sinCambio = Object();

/// Valores disponibles en los desplegables de filtro.
class OpcionesFiltro {
  const OpcionesFiltro({required this.clientes, required this.estados});
  final List<String> clientes;
  final List<String> estados;
}

/// Totales agregados para las tarjetas de resumen, calculados sobre la lista
/// que se le pase (normalmente la ya filtrada, para que reaccionen a los
/// filtros activos).
class KardexResumen {
  const KardexResumen({
    required this.unidadesPedidas,
    required this.cantidadOrdenes,
    required this.enProduccion,
    required this.recibidoEnBodega,
    required this.pendientePorDespachar,
  });

  final int unidadesPedidas;
  final int cantidadOrdenes;
  final int enProduccion;
  final int recibidoEnBodega;
  final int pendientePorDespachar;

  double get porcentajeProduccion => unidadesPedidas == 0 ? 0 : enProduccion / unidadesPedidas * 100;
  double get porcentajeBodega => unidadesPedidas == 0 ? 0 : recibidoEnBodega / unidadesPedidas * 100;

  factory KardexResumen.desde(List<ItemKardex> items) {
    var pedidas = 0, prod = 0, bodega = 0, pendiente = 0;
    final ops = <String>{};
    for (final i in items) {
      pedidas += i.cantidadPedida;
      prod += i.producido;
      bodega += i.recibido;
      pendiente += i.pendienteDespacho;
      ops.add(i.item.op);
    }
    return KardexResumen(
      unidadesPedidas: pedidas,
      cantidadOrdenes: ops.length,
      enProduccion: prod,
      recibidoEnBodega: bodega,
      pendientePorDespachar: pendiente,
    );
  }
}
ORBILOQ_EOF

echo "  - lib/application/providers.dart"
mkdir -p "$(dirname 'lib/application/providers.dart')"
cat > 'lib/application/providers.dart' << 'ORBILOQ_EOF'
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_importador_ordenes.dart';
import '../domain/models.dart';
import '../domain/wms_repository.dart';
import 'kardex_filters.dart';

/// Debe sobrescribirse en `main.dart` (o en tests) con la implementación deseada.
final wmsRepositoryProvider = Provider<WmsRepository>(
  (ref) => throw UnimplementedError('Sobrescribe wmsRepositoryProvider en main.dart'),
);

/// Solo disponible cuando la app corre contra Supabase; `null` en modo memoria
/// (la importación de Excel no tiene sentido sin una base de datos real detrás).
final importadorOrdenesProvider = Provider<SupabaseImportadorOrdenes?>((ref) => null);

final wmsSnapshotProvider = StreamProvider<WmsSnapshot>(
  (ref) => ref.watch(wmsRepositoryProvider).watch(),
);

final kardexProvider = Provider<List<ItemKardex>>(
  (ref) => ref.watch(wmsSnapshotProvider).value?.kardex ?? const <ItemKardex>[],
);

// ------------------------------------------------------------------- rol

class RolNotifier extends Notifier<Rol> {
  @override
  Rol build() => Rol.produccion;

  void cambiar(Rol rol) {
    if (rol == state) return;
    state = rol;
  }
}

final rolProvider = NotifierProvider<RolNotifier, Rol>(RolNotifier.new);

// --------------------------------------------------------------- filtros

class KardexFiltersNotifier extends Notifier<KardexFilters> {
  @override
  KardexFilters build() => const KardexFilters();

  void setBusqueda(String v) => state = state.copyWith(busqueda: v);
  void setCliente(String? v) => state = state.copyWith(cliente: v);
  void setEstado(String? v) => state = state.copyWith(estado: v);
  void limpiar() => state = const KardexFilters();
}

final kardexFiltersProvider =
    NotifierProvider<KardexFiltersNotifier, KardexFilters>(KardexFiltersNotifier.new);

final kardexFiltradoProvider = Provider<List<ItemKardex>>((ref) {
  final kardex = ref.watch(kardexProvider);
  final filtros = ref.watch(kardexFiltersProvider);
  if (!filtros.hayFiltros) return kardex;
  return kardex.where(filtros.aplica).toList(growable: false);
});

final kardexResumenProvider = Provider<KardexResumen>((ref) {
  // Reacciona a lo que esté visible según los filtros activos.
  return KardexResumen.desde(ref.watch(kardexFiltradoProvider));
});

final opcionesFiltroProvider = Provider<OpcionesFiltro>((ref) {
  final kardex = ref.watch(kardexProvider);
  List<String> unicos(String Function(ItemKardex) f) => (kardex.map(f).toSet().toList()..sort());
  return OpcionesFiltro(
    clientes: unicos((i) => i.item.cliente),
    estados: unicos((i) => i.estadoEtiqueta),
  );
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

echo "  - lib/features/kardex/presentation/kardex_filters_bar.dart"
mkdir -p "$(dirname 'lib/features/kardex/presentation/kardex_filters_bar.dart')"
cat > 'lib/features/kardex/presentation/kardex_filters_bar.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';

/// Barra de filtros: búsqueda libre + cliente + estado.
class KardexFiltersBar extends ConsumerStatefulWidget {
  const KardexFiltersBar({super.key});

  @override
  ConsumerState<KardexFiltersBar> createState() => _KardexFiltersBarState();
}

class _KardexFiltersBarState extends ConsumerState<KardexFiltersBar> {
  late final TextEditingController _busquedaCtrl;

  @override
  void initState() {
    super.initState();
    _busquedaCtrl = TextEditingController(text: ref.read(kardexFiltersProvider).busqueda);
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtros = ref.watch(kardexFiltersProvider);
    final opciones = ref.watch(opcionesFiltroProvider);
    final notifier = ref.read(kardexFiltersProvider.notifier);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final estrecho = constraints.maxWidth < 760;
          final campos = <Widget>[
            SizedBox(
              width: estrecho ? double.infinity : 320,
              child: TextField(
                controller: _busquedaCtrl,
                onChanged: notifier.setBusqueda,
                decoration: InputDecoration(
                  hintText: 'Buscar por OP, cliente, OC o producto',
                  hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.slate400),
                  filled: true,
                  fillColor: AppColors.slate50,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                ),
              ),
            ),
            _Desplegable(
              ancho: estrecho ? double.infinity : 200,
              etiquetaTodos: 'Todos los clientes',
              valor: filtros.cliente,
              opciones: opciones.clientes,
              onChanged: notifier.setCliente,
            ),
            _Desplegable(
              ancho: estrecho ? double.infinity : 190,
              etiquetaTodos: 'Todos los estados',
              valor: filtros.estado,
              opciones: opciones.estados,
              onChanged: notifier.setEstado,
            ),
            OutlinedButton.icon(
              onPressed: () {
                _busquedaCtrl.clear();
                notifier.limpiar();
              },
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Limpiar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.slate600,
                side: const BorderSide(color: AppColors.cardBorder),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ];

          return Wrap(spacing: 12, runSpacing: 12, children: campos);
        },
      ),
    );
  }
}

class _Desplegable extends StatelessWidget {
  const _Desplegable({
    required this.ancho,
    required this.etiquetaTodos,
    required this.valor,
    required this.opciones,
    required this.onChanged,
  });

  final double ancho;
  final String etiquetaTodos;
  final String? valor;
  final List<String> opciones;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            isExpanded: true,
            isDense: true,
            value: valor,
            hint: Text(etiquetaTodos, style: const TextStyle(fontSize: 13, color: AppColors.slate600)),
            icon: const Icon(Icons.expand_more, size: 18, color: AppColors.slate400),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(etiquetaTodos, style: const TextStyle(fontSize: 13)),
              ),
              for (final o in opciones)
                DropdownMenuItem<String?>(
                  value: o,
                  child: Text(o, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
ORBILOQ_EOF

echo "  - lib/features/kardex/presentation/kardex_summary_cards.dart"
mkdir -p "$(dirname 'lib/features/kardex/presentation/kardex_summary_cards.dart')"
cat > 'lib/features/kardex/presentation/kardex_summary_cards.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';

class KardexSummaryCards extends ConsumerWidget {
  const KardexSummaryCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(kardexResumenProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        // 4 en una fila si hay espacio; si no, se acomodan solas (Wrap).
        final anchoTarjeta = constraints.maxWidth >= 900
            ? (constraints.maxWidth - 3 * 16) / 4
            : constraints.maxWidth >= 500
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: anchoTarjeta,
              child: _SummaryCard(
                titulo: 'UNIDADES PEDIDAS',
                valor: '${r.unidadesPedidas}',
                subtitulo: '+${r.cantidadOrdenes} órdenes',
                subtituloColor: AppColors.slate600,
                icono: Icons.bar_chart_rounded,
              ),
            ),
            SizedBox(
              width: anchoTarjeta,
              child: _SummaryCard(
                titulo: 'EN PRODUCCIÓN',
                valor: '${r.enProduccion}',
                subtitulo: '${r.porcentajeProduccion.toStringAsFixed(1)}% del total',
                subtituloColor: AppColors.slate600,
                icono: Icons.autorenew_rounded,
              ),
            ),
            SizedBox(
              width: anchoTarjeta,
              child: _SummaryCard(
                titulo: 'RECIBIDO EN BODEGA',
                valor: '${r.recibidoEnBodega}',
                subtitulo: '${r.porcentajeBodega.toStringAsFixed(1)}% del total',
                subtituloColor: AppColors.slate600,
                icono: Icons.warehouse_rounded,
              ),
            ),
            SizedBox(
              width: anchoTarjeta,
              child: _SummaryCard(
                titulo: 'PENDIENTE POR DESPACHAR',
                valor: '${r.pendientePorDespachar}',
                subtitulo: r.pendientePorDespachar > 0 ? 'Requiere seguimiento' : 'Al día',
                subtituloColor: r.pendientePorDespachar > 0 ? AppColors.amberChip : AppColors.actionGreen,
                icono: Icons.inventory_2_rounded,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.titulo,
    required this.valor,
    required this.subtitulo,
    required this.subtituloColor,
    required this.icono,
  });

  final String titulo;
  final String valor;
  final String subtitulo;
  final Color subtituloColor;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Icon(icono, size: 18, color: AppColors.slate400),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            valor,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.slate900),
          ),
          const SizedBox(height: 4),
          Text(subtitulo, style: TextStyle(fontSize: 12, color: subtituloColor, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
ORBILOQ_EOF

echo "  - lib/features/kardex/presentation/kardex_table.dart"
mkdir -p "$(dirname 'lib/features/kardex/presentation/kardex_table.dart')"
cat > 'lib/features/kardex/presentation/kardex_table.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import 'observacion_dialog.dart';

const List<double> _kAnchos = [110, 250, 190, 90, 100, 90, 110, 170, 130];
const List<String> _kEtiquetas = [
  'OP / OBSERVACIÓN', 'PRODUCTO', 'CLIENTE / OC', 'PEDIDAS',
  'PRODUCCIÓN', 'BODEGA', 'DESPACHADAS', 'AVANCE', 'ENTREGA',
];

const _kPaletaProducto = [
  Color(0xFF0F172A), Color(0xFF0F766E), Color(0xFF7C3AED), Color(0xFFB45309),
  Color(0xFF1D4ED8), Color(0xFF991B1B), Color(0xFF15803D), Color(0xFF334155),
];

Color _colorProducto(String codigo) => _kPaletaProducto[codigo.hashCode.abs() % _kPaletaProducto.length];

const _mesesEs = [
  '', 'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
];
String _fechaCorta(DateTime d) => '${d.day} ${_mesesEs[d.month]}';

/// Tabla del kardex, paginada. Cada página construye solo sus propias filas,
/// así que sigue escalando bien con miles de registros en total.
class KardexTable extends ConsumerWidget {
  const KardexTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filas = ref.watch(kardexPaginaActualProvider);
    final total = ref.watch(kardexFiltradoProvider).length;
    final pagina = ref.watch(kardexPaginaProvider);
    final totalPaginas = total == 0 ? 1 : ((total - 1) ~/ kardexFilasPorPagina) + 1;
    final anchoTabla = _kAnchos.fold<double>(0, (a, b) => a + b);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: anchoTabla,
              child: Column(
                children: [
                  Container(
                    color: AppColors.slate50,
                    child: Row(
                      children: [
                        for (var i = 0; i < _kEtiquetas.length; i++)
                          _Celda(
                            i,
                            Text(
                              _kEtiquetas[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.slate600,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.cardBorder),
                  if (filas.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text('Sin resultados para los filtros aplicados.',
                            style: TextStyle(color: AppColors.slate400)),
                      ),
                    )
                  else
                    for (final item in filas) _KardexRow(item: item),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.cardBorder),
          _BarraPaginacion(pagina: pagina, totalPaginas: totalPaginas, total: total, filas: filas.length),
        ],
      ),
    );
  }
}

class _BarraPaginacion extends ConsumerWidget {
  const _BarraPaginacion({
    required this.pagina,
    required this.totalPaginas,
    required this.total,
    required this.filas,
  });

  final int pagina;
  final int totalPaginas;
  final int total;
  final int filas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(kardexPaginaProvider.notifier);
    final desde = total == 0 ? 0 : pagina * kardexFilasPorPagina + 1;
    final hasta = pagina * kardexFilasPorPagina + filas;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Mostrando $desde-$hasta de $total registros',
            style: const TextStyle(fontSize: 12, color: AppColors.slate600),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: pagina > 0 ? () => notifier.ir(pagina - 1) : null,
                icon: const Icon(Icons.chevron_left, size: 18),
                label: const Text('Anterior'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.slate600),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: pagina + 1 < totalPaginas ? () => notifier.ir(pagina + 1) : null,
                icon: const Icon(Icons.chevron_right, size: 18),
                label: const Text('Siguiente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tealPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.slate200,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Celda extends StatelessWidget {
  const _Celda(this.col, this.child, {this.alignment = Alignment.centerLeft});

  final int col;
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kAnchos[col],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Align(alignment: alignment, child: child),
      ),
    );
  }
}

class _KardexRow extends StatelessWidget {
  const _KardexRow({required this.item});

  final ItemKardex item;

  @override
  Widget build(BuildContext context) {
    final o = item.item;
    final completado = item.cantidadPedida > 0 && item.despachado >= item.cantidadPedida;
    final avance = item.cantidadPedida == 0
        ? 0.0
        : (item.recibido / item.cantidadPedida).clamp(0.0, 1.0);

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Celda(
            0,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => showObservacionDialog(context, item),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.slate400),
                  ),
                ),
                Text('#${o.op}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
          _Celda(
            1,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 8, top: 2),
                  decoration: BoxDecoration(color: _colorProducto(o.codigo), borderRadius: BorderRadius.circular(3)),
                ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(o.descripcion,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      Text('Talla ${o.talla}', style: const TextStyle(fontSize: 11, color: AppColors.slate400)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _Celda(
            2,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(o.cliente, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                if (o.oc.isNotEmpty)
                  Text('OC ${o.oc}', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.slate400)),
              ],
            ),
          ),
          _Celda(3, Text('${item.cantidadPedida}', style: const TextStyle(fontSize: 13)),
              alignment: Alignment.center),
          _Celda(4, Text('${item.producido}', style: const TextStyle(fontSize: 13, color: AppColors.tealPrimary)),
              alignment: Alignment.center),
          _Celda(5, Text('${item.recibido}', style: const TextStyle(fontSize: 13, color: AppColors.blueChip)),
              alignment: Alignment.center),
          _Celda(6, Text('${item.despachado}', style: const TextStyle(fontSize: 13, color: AppColors.amberChip)),
              alignment: Alignment.center),
          _Celda(7, _Avance(porcentaje: avance, completado: completado)),
          _Celda(8, _ChipEntrega(item: item, completado: completado)),
        ],
      ),
    );
  }
}

class _Avance extends StatelessWidget {
  const _Avance({required this.porcentaje, required this.completado});

  final double porcentaje;
  final bool completado;

  @override
  Widget build(BuildContext context) {
    final color = completado ? AppColors.actionGreen : AppColors.tealPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: completado ? 1 : porcentaje,
            minHeight: 6,
            backgroundColor: AppColors.slate200,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          completado ? 'Completado' : '${(porcentaje * 100).toStringAsFixed(0)}% recibido',
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ChipEntrega extends StatelessWidget {
  const _ChipEntrega({required this.item, required this.completado});

  final ItemKardex item;
  final bool completado;

  @override
  Widget build(BuildContext context) {
    if (completado) {
      return _chip('ENTREGADO', AppColors.actionGreen, AppColors.greenChipBg, Icons.check_circle_outline);
    }
    final fecha = item.fechaEntregaLogistica;
    if (fecha == null) {
      return _chip('Sin fecha', AppColors.slate400, AppColors.slate50, Icons.event_outlined);
    }
    final vencida = fecha.isBefore(DateTime.now());
    return _chip(
      _fechaCorta(fecha),
      vencida ? AppColors.alertRed : AppColors.slate600,
      vencida ? AppColors.redChipBg : AppColors.slate50,
      Icons.event_outlined,
    );
  }

  Widget _chip(String texto, Color color, Color fondo, IconData icono) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 12, color: color),
          const SizedBox(width: 4),
          Text(texto, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
ORBILOQ_EOF

echo "  - lib/features/kardex/presentation/kardex_page.dart"
mkdir -p "$(dirname 'lib/features/kardex/presentation/kardex_page.dart')"
cat > 'lib/features/kardex/presentation/kardex_page.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import '../../despacho/presentation/despacho_dialog.dart';
import '../../importacion/presentation/importar_ordenes_dialog.dart';
import '../../produccion/presentation/entrega_produccion_dialog.dart';
import '../../recepcion/presentation/recepcion_dialog.dart';
import '../../ubicaciones/presentation/ubicaciones_dialog.dart';
import 'kardex_filters_bar.dart';
import 'kardex_summary_cards.dart';
import 'kardex_table.dart';

class KardexPage extends ConsumerStatefulWidget {
  const KardexPage({super.key});

  @override
  ConsumerState<KardexPage> createState() => _KardexPageState();
}

class _KardexPageState extends ConsumerState<KardexPage> {
  bool _sincronizando = false;

  Future<void> _sincronizar() async {
    setState(() => _sincronizando = true);
    await ref.read(wmsRepositoryProvider).refrescar();
    if (!mounted) return;
    setState(() => _sincronizando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Datos sincronizados'),
        backgroundColor: AppColors.actionGreen,
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rol = ref.watch(rolProvider);
    final snapshot = ref.watch(wmsSnapshotProvider);

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
        toolbarHeight: 72,
        surfaceTintColor: Colors.white,
        shape: const Border(bottom: BorderSide(color: AppColors.cardBorder)),
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.tealPrimary, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
                    children: [
                      TextSpan(text: 'ORBILOQ '),
                      TextSpan(
                        text: '| KARDEX MAESTRO',
                        style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.slate600),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'CONTROL OPERATIVO DE BODEGA Y PRODUCCIÓN',
                  style: TextStyle(fontSize: 10, color: AppColors.slate400, letterSpacing: 0.4),
                ),
              ],
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => showImportarOrdenesDialog(context),
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: const Text('Importar Excel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.slate600,
              side: const BorderSide(color: AppColors.cardBorder),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _sincronizando ? null : _sincronizar,
            icon: _sincronizando
                ? const SizedBox(
                    width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.sync, size: 18),
            label: Text(_sincronizando ? 'Sincronizando...' : 'Sincronizar BD'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tealPrimary,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error cargando datos: $e')),
        data: (s) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cabecera(rol: rol, enTransito: s.remisionesEnTransito),
              const SizedBox(height: 20),
              const KardexSummaryCards(),
              const SizedBox(height: 20),
              const KardexFiltersBar(),
              const SizedBox(height: 16),
              const KardexTable(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cabecera extends ConsumerWidget {
  const _Cabecera({required this.rol, required this.enTransito});

  final Rol rol;
  final int enTransito;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _SelectorPerfil(rol: rol),
            const SizedBox(height: 2),
            const Text(
              'Órdenes activas',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate900),
            ),
          ],
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (rol == Rol.produccion)
              _BotonAccion(
                icono: Icons.history,
                texto: 'Entregar lote y ver historial',
                onPressed: () => showEntregaProduccionDialog(context),
              )
            else ...[
              _BotonAccion(
                icono: Icons.move_to_inbox_outlined,
                texto: 'Recibir remisión ($enTransito)',
                onPressed: () => showRecepcionDialog(context),
              ),
              _BotonAccion(
                icono: Icons.local_shipping_outlined,
                texto: 'Despacho por orden',
                onPressed: () => showDespachoDialog(context),
              ),
              _BotonAccion(
                icono: Icons.domain_outlined,
                texto: 'Estantes y tickets',
                onPressed: () => showUbicacionesDialog(context),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Se ve como una etiqueta de texto ("Perfil: X"), pero sigue siendo un
/// desplegable funcional para cambiar de rol — necesario mientras no exista
/// login real con el rol del usuario autenticado.
class _SelectorPerfil extends ConsumerWidget {
  const _SelectorPerfil({required this.rol});

  final Rol rol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<Rol>(
        value: rol,
        isDense: true,
        icon: const Icon(Icons.expand_more, size: 16, color: AppColors.slate400),
        style: const TextStyle(fontSize: 12, color: AppColors.slate600, fontWeight: FontWeight.w500),
        items: [
          for (final r in Rol.values)
            DropdownMenuItem(value: r, child: Text('Perfil: ${_etiquetaCorta(r)}')),
        ],
        onChanged: (r) {
          if (r != null) ref.read(rolProvider.notifier).cambiar(r);
        },
      ),
    );
  }

  String _etiquetaCorta(Rol r) => r == Rol.produccion ? 'Producción (Taller)' : 'Logística (Bodega)';
}

class _BotonAccion extends StatelessWidget {
  const _BotonAccion({required this.icono, required this.texto, required this.onPressed});

  final IconData icono;
  final String texto;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icono, size: 16),
      label: Text(texto),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.tealPrimary,
        side: const BorderSide(color: AppColors.tealPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
ORBILOQ_EOF

echo ""
echo "Listo. Siguiente paso:"
echo "  flutter analyze"
echo "  flutter test"
echo "  flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=..."
