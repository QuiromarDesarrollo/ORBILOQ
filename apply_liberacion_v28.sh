#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Quitar Avance + Liberar producto no conforme (v28)
# Requiere haber corrido antes orbiloq_wms_liberacion.sql en Supabase.
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_liberacion_v28.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi

echo "Aplicando quitar Avance + liberar no conforme..."

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

/// Estado del LOTE completo (el encabezado). Depende de cuántas de sus
/// líneas siguen en tránsito.
enum EstadoLote {
  enTransito('EN TRÁNSITO'),
  recibidoParcial('RECIBIDO PARCIAL'),
  recibidoCompleto('RECIBIDO COMPLETO');

  const EstadoLote(this.etiqueta);
  final String etiqueta;
}

/// Estado de UNA línea (producto) dentro de un lote.
enum EstadoLineaLote {
  enTransito('EN TRÁNSITO'),
  recibidoConforme('RECIBIDO CONFORME'),
  recibidoConNovedad('RECIBIDO CON NOVEDAD');

  const EstadoLineaLote(this.etiqueta);
  final String etiqueta;
}

enum TipoMovimiento { entregaProduccion, recepcion, despacho, devolucionProduccion, liberacionNoConforme }

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

/// Estado propio de la vista de Producción (distinto de [EstadoItem], que es
/// el que usa Bodega). "Retardo" requiere una fecha esperada de entrega con
/// la que compararse — mientras esa fecha no tenga una fuente de datos real,
/// este estado nunca se activa y todo lo pendiente cae en "parcial por entregar".
enum EstadoProduccion {
  completado('Completado'),
  parcialPorEntregar('Estado parcial por entregar'),
  parcialPorRetardo('Estado parcial por retardo');

  const EstadoProduccion(this.etiqueta);
  final String etiqueta;
}

/// Estado para la vista de Bodega (Logística).
enum EstadoLogistica {
  completado('Completado'),
  pendienteRecibir('Por recibir'),
  pendientePorDespachar('Por despachar');

  const EstadoLogistica(this.etiqueta);
  final String etiqueta;
}

/// Motivo de una devolución a Producción por no conformidad.
class Causal {
  const Causal({required this.id, required this.nombre});
  final String id;
  final String nombre;
}

/// Registro de haber liberado (reprocesado) unidades no conformes.
class Liberacion {
  const Liberacion({
    required this.id,
    required this.item,
    required this.cantidad,
    required this.operario,
    required this.fecha,
    this.nota = '',
  });

  final String id;
  final ItemOrden item;
  final int cantidad;
  final String operario;
  final DateTime fecha;
  final String nota;
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

/// Un producto + cantidad, usado al armar un lote nuevo (antes de enviarlo).
class ItemCantidad {
  const ItemCantidad({required this.itemId, required this.cantidad});
  final String itemId;
  final int cantidad;
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
    this.loteId,
    this.loteLineaId,
    this.nota = '',
  });

  final TipoMovimiento tipo;
  final String itemId;
  final int cantidad;
  final DateTime fecha;
  final String? ubicacion;
  final String? loteId;
  final String? loteLineaId;
  final String nota;
}

/// Una línea (producto) dentro de un lote — cada una se recibe por separado,
/// con su propia ubicación, cantidad y novedad.
class LoteLinea {
  const LoteLinea({
    required this.id,
    required this.item,
    required this.cantidadEnviada,
    this.estado = EstadoLineaLote.enTransito,
    this.cantidadRecibida,
    this.ubicacionDestino,
    this.novedad = '',
    this.fechaRecepcion,
  });

  final String id;
  final ItemOrden item;
  final int cantidadEnviada;
  final EstadoLineaLote estado;
  final int? cantidadRecibida;
  final String? ubicacionDestino;
  final String novedad;
  final DateTime? fechaRecepcion;

  bool get enTransito => estado == EstadoLineaLote.enTransito;

  LoteLinea copyWith({
    EstadoLineaLote? estado,
    int? cantidadRecibida,
    String? ubicacionDestino,
    String? novedad,
    DateTime? fechaRecepcion,
  }) {
    return LoteLinea(
      id: id,
      item: item,
      cantidadEnviada: cantidadEnviada,
      estado: estado ?? this.estado,
      cantidadRecibida: cantidadRecibida ?? this.cantidadRecibida,
      ubicacionDestino: ubicacionDestino ?? this.ubicacionDestino,
      novedad: novedad ?? this.novedad,
      fechaRecepcion: fechaRecepcion ?? this.fechaRecepcion,
    );
  }
}

/// Lote enviado por Producción hacia Bodega — puede traer varios productos
/// (líneas) de una sola vez, bajo un mismo número.
class Lote {
  const Lote({
    required this.id,
    required this.operario,
    required this.fechaEnvio,
    required this.lineas,
    this.estado = EstadoLote.enTransito,
  });

  /// Número del lote (ej. "LOTE-101"). Es la clave que usa la app para
  /// referenciarlo — no hay un UUID de lote expuesto en el dominio.
  final String id;
  final String operario;
  final DateTime fechaEnvio;
  final EstadoLote estado;
  final List<LoteLinea> lineas;

  int get totalLineas => lineas.length;
  int get lineasPendientes => lineas.where((l) => l.enTransito).length;
  bool get tienePendientes => lineasPendientes > 0;
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

  /// Estado para la vista de Producción. "Retardo" queda reservado para
  /// cuando exista una fecha esperada real de entrega (aún no conectada);
  /// mientras tanto, nunca se activa.
  EstadoProduccion get estadoProduccion {
    if (pendienteProduccion <= 0 && cantidadPedida > 0) return EstadoProduccion.completado;
    // TODO: activar "parcialPorRetardo" cuando exista una fecha esperada de
    // entrega real contra la cual comparar la fecha de hoy.
    return EstadoProduccion.parcialPorEntregar;
  }

  /// Estado para la vista de Bodega. Prioridad: si ya se despachó todo,
  /// completado; si todavía falta recibir (venga de producción o esté en
  /// tránsito), pendiente por recibir; si ya está todo recibido pero falta
  /// despachar, pendiente por despachar.
  EstadoLogistica get estadoLogistica {
    if (cantidadPedida > 0 && despachado >= cantidadPedida) return EstadoLogistica.completado;
    if (recibido < cantidadPedida) return EstadoLogistica.pendienteRecibir;
    return EstadoLogistica.pendientePorDespachar;
  }

  String get ubicacionesFormateadas {
    if (ubicaciones.isEmpty) return 'SIN UBICACIÓN';
    return ubicaciones.entries.map((e) => '${e.key} (${e.value})').join(' | ');
  }
}

/// Foto inmutable del estado completo que consume la UI.
class WmsSnapshot {
  WmsSnapshot({
    required this.kardex,
    required this.lotes,
  });

  final List<ItemKardex> kardex;

  /// Más recientes primero.
  final List<Lote> lotes;

  late final Map<String, ItemKardex> _porId = {for (final k in kardex) k.id: k};
  late final Map<String, ItemKardex> _porOpCodigo = {
    for (final k in kardex) '${k.item.op}|${k.item.codigo}': k,
  };
  late final int lotesConPendientes = lotes.where((l) => l.tienePendientes).length;

  ItemKardex? kardexPorId(String id) => _porId[id];

  /// El QR real de la marquilla trae OP + Código, sin talla (el código ya es
  /// único por talla dentro de cada OP). Esta es la búsqueda que usa el escaneo.
  ItemKardex? kardexPorOpCodigo(String op, String codigo) => _porOpCodigo['$op|$codigo'];
}
ORBILOQ_EOF

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

  /// Logística marca unidades como no conformes: se restan de lo entregado
  /// por Producción (independiente de cualquier lote) y quedan reflejadas
  /// en "Producto no conforme" hasta que se reprocesen.
  Future<Result<void>> registrarNoConforme({
    required String itemId,
    required int cantidad,
    required String causalId,
    required String operario,
    String nota = '',
  });

  /// Producción libera (reprocesó) unidades no conformes: vuelven a sumar a
  /// lo entregado y bajan de "Producto no conforme". Puede ser parcial.
  Future<Result<void>> liberarNoConforme({
    required String itemId,
    required int cantidad,
    required String operario,
    String nota = '',
  });

  /// Historial de liberaciones (más recientes primero), para control.
  Future<List<Liberacion>> cargarLiberaciones();

  void dispose();
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
  Future<Result<void>> registrarNoConforme({
    required String itemId,
    required int cantidad,
    required String causalId,
    required String operario,
    String nota = '',
  }) async {
    final item = _items[itemId];
    if (item == null) return Err<void>('El producto no existe en el kardex.');
    if (cantidad <= 0) return Err<void>('La cantidad debe ser mayor a 0.');
    final producido = _snapshot().kardexPorId(itemId)?.producido ?? 0;
    if (cantidad > producido) {
      return Err<void>('LÍMITE EXCEDIDO: solo hay $producido Uds entregadas por Producción para este producto.');
    }

    _movimientos.add(Movimiento(
      tipo: TipoMovimiento.devolucionProduccion,
      itemId: item.id,
      cantidad: cantidad,
      fecha: DateTime.now(),
      nota: '$causalId${nota.trim().isEmpty ? '' : ' - ${nota.trim()}'}',
    ));
    _emitir();
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> liberarNoConforme({
    required String itemId,
    required int cantidad,
    required String operario,
    String nota = '',
  }) async {
    final item = _items[itemId];
    if (item == null) return Err<void>('El producto no existe en el kardex.');
    if (cantidad <= 0) return Err<void>('La cantidad debe ser mayor a 0.');
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
      ),
    );
    _movimientos.add(Movimiento(
      tipo: TipoMovimiento.liberacionNoConforme,
      itemId: item.id,
      cantidad: cantidad,
      fecha: fecha,
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
      fechaEntregaLogistica: _fecha(row['fecha_entrega_logistica']),
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
  Future<Result<void>> registrarNoConforme({
    required String itemId,
    required int cantidad,
    required String causalId,
    required String operario,
    String nota = '',
  }) async {
    try {
      await _client.rpc('registrar_no_conforme', params: {
        'p_item_orden_id': itemId,
        'p_cantidad': cantidad,
        'p_causal_id': causalId,
        'p_operario_nombre': operario,
        'p_nota': nota,
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
    String nota = '',
  }) async {
    try {
      await _client.rpc('liberar_no_conforme', params: {
        'p_item_orden_id': itemId,
        'p_cantidad': cantidad,
        'p_operario_nombre': operario,
        'p_nota': nota,
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
        ),
    ];
  }
}
ORBILOQ_EOF

echo "  - lib/features/kardex/presentation/kardex_table.dart"
mkdir -p "$(dirname 'lib/features/kardex/presentation/kardex_table.dart')"
cat > 'lib/features/kardex/presentation/kardex_table.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/kardex_filters.dart';
import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/multi_select_filter.dart';
import 'observacion_dialog.dart';

// Columnas para el rol Producción (Taller). Todas tienen filtro por columna.
const List<double> _kAnchosProduccion = [110, 220, 170, 85, 160, 100, 150, 190, 120, 120];
const List<String> _kEtiquetasProduccion = [
  'OP / OBS.', 'PRODUCTO', 'CLIENTE / OC', 'CANTIDAD',
  'ENTREGADO A LOGÍSTICA', 'PENDIENTE', 'PRODUCTO NO CONFORME',
  'ESTADOS', 'FECHA DE ENTREGA', 'FECHA ESPERADA',
];
// A qué columna de filtro corresponde cada encabezado de Producción (por
// índice). `null` = sin filtro en esa columna.
const List<String?> _kColumnasProduccion = [
  ColKardex.op, ColKardex.producto, ColKardex.cliente, ColKardex.cantidad,
  ColKardex.entregado, ColKardex.pendiente, ColKardex.noConforme,
  ColKardex.estadoProduccion, ColKardex.fechaEntrega, ColKardex.fechaEsperada,
];

// Columnas para el rol Logística (Bodega). Solo OP tiene filtro (igual que antes).
const List<double> _kAnchosBodega = [100, 190, 150, 75, 110, 110, 75, 95, 110, 120, 100, 100, 95, 130];
const List<String> _kEtiquetasBodega = [
  'OP / OBS.', 'PRODUCTO', 'CLIENTE / OC', 'PEDIDAS',
  'ENTREGADO POR PRODUCCIÓN', 'PENDIENTE POR PRODUCCIÓN', 'BODEGA', 'DESPACHADAS',
  'PRODUCTO NO CONFORME', 'ESTADOS', 'FECHA DE ENTREGA', 'FECHA ESPERADA', 'DÍAS FALTANTES',
  'ENTREGA',
];
const List<String?> _kColumnasBodega = [
  ColKardex.op, null, null, null, null, null, null, null, null, null, null, null, null, null,
];

const _kPaletaProducto = [
  Color(0xFF2DD4BF), Color(0xFF60A5FA), Color(0xFFA78BFA), Color(0xFFFBBF24),
  Color(0xFFF472B6), Color(0xFFFB923C), Color(0xFF34D399), Color(0xFF94A3B8),
];

Color _colorProducto(String codigo) => _kPaletaProducto[codigo.hashCode.abs() % _kPaletaProducto.length];

const _mesesEs = [
  '', 'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
];
String _fechaCorta(DateTime d) => '${d.day} ${_mesesEs[d.month]}';

/// Tabla del kardex, paginada, con columnas distintas según el rol.
class KardexTable extends ConsumerWidget {
  const KardexTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filas = ref.watch(kardexPaginaActualProvider);
    final total = ref.watch(kardexFiltradoProvider).length;
    final pagina = ref.watch(kardexPaginaProvider);
    final rol = ref.watch(rolProvider);
    final esProduccion = rol == Rol.produccion;
    final anchos = esProduccion ? _kAnchosProduccion : _kAnchosBodega;
    final etiquetas = esProduccion ? _kEtiquetasProduccion : _kEtiquetasBodega;
    final columnas = esProduccion ? _kColumnasProduccion : _kColumnasBodega;
    final totalPaginas = total == 0 ? 1 : ((total - 1) ~/ kardexFilasPorPagina) + 1;
    final anchoTabla = anchos.fold<double>(0, (a, b) => a + b);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkCardBorder),
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
                    color: AppColors.darkHeader,
                    child: Row(
                      children: [
                        for (var i = 0; i < etiquetas.length; i++)
                          _Celda(
                            i,
                            anchos,
                            columnas[i] == null
                                ? Text(
                                    etiquetas[i],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.darkTextSecondary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                      letterSpacing: 0.3,
                                      height: 1.2,
                                    ),
                                  )
                                : _EncabezadoConFiltro(
                                    columna: columnas[i]!,
                                    etiqueta: etiquetas[i],
                                    esOp: columnas[i] == ColKardex.op,
                                  ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.darkCardBorder),
                  if (filas.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text('Sin resultados para los filtros aplicados.',
                            style: TextStyle(color: AppColors.darkTextMuted)),
                      ),
                    )
                  else
                    for (final item in filas) _KardexRow(item: item, anchos: anchos, esProduccion: esProduccion),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.darkCardBorder),
          _BarraPaginacion(pagina: pagina, totalPaginas: totalPaginas, total: total, filas: filas.length),
        ],
      ),
    );
  }
}

/// Encabezado de columna con el ícono de embudo que abre el filtro de
/// selección múltiple (búsqueda + casillas), para cualquier columna.
class _EncabezadoConFiltro extends ConsumerWidget {
  const _EncabezadoConFiltro({required this.columna, required this.etiqueta, this.esOp = false});

  final String columna;
  final String etiqueta;
  final bool esOp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtros = ref.watch(kardexFiltersProvider);
    final opciones = ref.watch(opcionesFiltroProvider);
    final activo = filtros.valoresDe(columna).isNotEmpty;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            etiqueta,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.darkTextSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.3,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () async {
            final r = await showMultiSelectFilter<String>(
              context,
              title: 'Filtrar por $etiqueta',
              options: opciones.de(columna),
              selected: filtros.valoresDe(columna),
              labelOf: esOp ? (v) => '#$v' : (v) => v,
            );
            if (r != null) ref.read(kardexFiltersProvider.notifier).setColumna(columna, r);
          },
          child: Icon(
            Icons.filter_alt,
            size: 14,
            color: activo ? AppColors.tealAccent : AppColors.darkTextMuted,
          ),
        ),
      ],
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
            style: const TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: pagina > 0 ? () => notifier.ir(pagina - 1) : null,
                icon: const Icon(Icons.chevron_left, size: 18),
                label: const Text('Anterior'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.darkTextSecondary,
                  side: const BorderSide(color: AppColors.darkCardBorder),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: pagina + 1 < totalPaginas ? () => notifier.ir(pagina + 1) : null,
                icon: const Icon(Icons.chevron_right, size: 18),
                label: const Text('Siguiente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tealPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.darkCardBorder,
                  disabledForegroundColor: AppColors.darkTextMuted,
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
  const _Celda(this.col, this.anchos, this.child, {this.alignment = Alignment.centerLeft});

  final int col;
  final List<double> anchos;
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: anchos[col],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Align(alignment: alignment, child: child),
      ),
    );
  }
}

class _KardexRow extends StatelessWidget {
  const _KardexRow({required this.item, required this.anchos, required this.esProduccion});

  final ItemKardex item;
  final List<double> anchos;
  final bool esProduccion;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.darkCardBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _celdaOp(),
          _celdaProducto(),
          _celdaClienteOc(),
          if (esProduccion) ..._celdasProduccion() else ..._celdasBodega(),
        ],
      ),
    );
  }

  Widget _celdaOp() {
    final o = item.item;
    return _Celda(
      0,
      anchos,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder: (context) => InkWell(
              onTap: () => showObservacionDialog(context, item),
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.darkTextMuted),
              ),
            ),
          ),
          Text('#${o.op}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.tealAccent)),
        ],
      ),
    );
  }

  Widget _celdaProducto() {
    final o = item.item;
    return _Celda(
      1,
      anchos,
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
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.darkTextPrimary)),
                Text('Talla ${o.talla}', style: const TextStyle(fontSize: 11, color: AppColors.darkTextMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _celdaClienteOc() {
    final o = item.item;
    return _Celda(
      2,
      anchos,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(o.cliente, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.darkTextPrimary)),
          if (o.oc.isNotEmpty)
            Text('OC ${o.oc}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.darkTextMuted)),
        ],
      ),
    );
  }

  // ------------------------------------------------------- vista Producción

  List<Widget> _celdasProduccion() {
    final noConforme = item.pendienteReproceso;
    return [
      _Celda(3, anchos, Text('${item.cantidadPedida}', style: const TextStyle(fontSize: 13, color: AppColors.darkTextPrimary)),
          alignment: Alignment.center),
      _Celda(4, anchos, Text('${item.producido}', style: const TextStyle(fontSize: 13, color: AppColors.tealAccent)),
          alignment: Alignment.center),
      _Celda(
        5,
        anchos,
        Text('${item.pendienteProduccion}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: item.pendienteProduccion > 0 ? AppColors.chipRedDark : AppColors.darkTextMuted,
            )),
        alignment: Alignment.center,
      ),
      _Celda(
        6,
        anchos,
        Text(
          '$noConforme',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: noConforme > 0 ? const Color(0xFFFBBF24) : AppColors.darkTextMuted,
          ),
        ),
        alignment: Alignment.center,
      ),
      _Celda(7, anchos, _celdaEstado()),
      _Celda(8, anchos, _chipFecha(item.fechaEntrega)),
      // "Fecha esperada": aún sin fuente de datos definida — placeholder
      // visual hasta que se conecte (el usuario indicará el origen luego).
      _Celda(9, anchos, _chipFecha(null)),
    ];
  }

  Widget _celdaEstado() {
    final e = item.estadoProduccion;
    final Color color;
    final Color fondo;
    final IconData icono;
    switch (e) {
      case EstadoProduccion.completado:
        color = AppColors.chipGreenDark;
        fondo = AppColors.chipGreenBgDark;
        icono = Icons.check_circle_outline;
      case EstadoProduccion.parcialPorRetardo:
        color = AppColors.chipRedDark;
        fondo = AppColors.chipRedBgDark;
        icono = Icons.warning_amber_outlined;
      case EstadoProduccion.parcialPorEntregar:
        color = AppColors.darkTextSecondary;
        fondo = AppColors.chipNeutralBgDark;
        icono = Icons.hourglass_bottom;
    }
    return _chip(e.etiqueta, color, fondo, icono);
  }

  Widget _chipFecha(DateTime? fecha) {
    if (fecha == null) {
      return _chip('Sin fecha', AppColors.darkTextMuted, AppColors.chipNeutralBgDark, Icons.event_outlined);
    }
    return _chip(_fechaCorta(fecha), AppColors.darkTextSecondary, AppColors.chipNeutralBgDark, Icons.event_outlined);
  }

  // ------------------------------------------------------- vista Bodega

  List<Widget> _celdasBodega() {
    final completado = item.cantidadPedida > 0 && item.despachado >= item.cantidadPedida;
    final noConforme = item.pendienteReproceso;
    return [
      _Celda(3, anchos, Text('${item.cantidadPedida}', style: const TextStyle(fontSize: 13, color: AppColors.darkTextPrimary)),
          alignment: Alignment.center),
      _Celda(4, anchos, Text('${item.producido}', style: const TextStyle(fontSize: 13, color: AppColors.tealAccent)),
          alignment: Alignment.center),
      _Celda(
        5,
        anchos,
        Text('${item.pendienteProduccion}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: item.pendienteProduccion > 0 ? AppColors.chipRedDark : AppColors.darkTextMuted,
            )),
        alignment: Alignment.center,
      ),
      _Celda(6, anchos, Text('${item.recibido}', style: const TextStyle(fontSize: 13, color: Color(0xFF60A5FA))),
          alignment: Alignment.center),
      _Celda(7, anchos, Text('${item.despachado}', style: const TextStyle(fontSize: 13, color: Color(0xFFFBBF24))),
          alignment: Alignment.center),
      _Celda(
        8,
        anchos,
        Text(
          '$noConforme',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: noConforme > 0 ? const Color(0xFFFBBF24) : AppColors.darkTextMuted,
          ),
        ),
        alignment: Alignment.center,
      ),
      _Celda(9, anchos, _celdaEstadoLogistica()),
      _Celda(10, anchos, _chipFecha(item.fechaEntrega)),
      // "Fecha esperada" y "Días faltantes": aún sin fuente de datos real —
      // quedan como marcador visual hasta conectarlas.
      _Celda(11, anchos, _chipFecha(null)),
      _Celda(12, anchos, _chip('Sin fecha', AppColors.darkTextMuted, AppColors.chipNeutralBgDark, Icons.hourglass_empty)),
      _Celda(13, anchos, _ChipEntrega(item: item, completado: completado)),
    ];
  }

  Widget _celdaEstadoLogistica() {
    final e = item.estadoLogistica;
    final Color color;
    final Color fondo;
    final IconData icono;
    switch (e) {
      case EstadoLogistica.completado:
        color = AppColors.chipGreenDark;
        fondo = AppColors.chipGreenBgDark;
        icono = Icons.check_circle_outline;
      case EstadoLogistica.pendienteRecibir:
        color = AppColors.darkTextSecondary;
        fondo = AppColors.chipNeutralBgDark;
        icono = Icons.hourglass_bottom;
      case EstadoLogistica.pendientePorDespachar:
        color = const Color(0xFFFBBF24);
        fondo = AppColors.chipNeutralBgDark;
        icono = Icons.local_shipping_outlined;
    }
    return _chip(e.etiqueta, color, fondo, icono);
  }

  Widget _chip(String texto, Color color, Color fondo, IconData icono) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 11, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
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
      return _chipEstatico('ENTREGADO', AppColors.chipGreenDark, AppColors.chipGreenBgDark, Icons.check_circle_outline);
    }
    final fecha = item.fechaEntregaLogistica;
    if (fecha == null) {
      return _chipEstatico('Sin fecha', AppColors.darkTextMuted, AppColors.chipNeutralBgDark, Icons.event_outlined);
    }
    final vencida = fecha.isBefore(DateTime.now());
    return _chipEstatico(
      _fechaCorta(fecha),
      vencida ? AppColors.chipRedDark : AppColors.darkTextSecondary,
      vencida ? AppColors.chipRedBgDark : AppColors.chipNeutralBgDark,
      Icons.event_outlined,
    );
  }

  Widget _chipEstatico(String texto, Color color, Color fondo, IconData icono) {
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

import '../../../application/auth_providers.dart';
import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import '../../../domain/sesion.dart';
import '../../despacho/presentation/despacho_dialog.dart';
import '../../importacion/presentation/importar_ordenes_dialog.dart';
import '../../no_conforme/presentation/no_conforme_dialog.dart';
import '../../produccion/presentation/entrega_produccion_dialog.dart';
import '../../recepcion/presentation/recepcion_dialog.dart';
import '../../reproceso/presentation/reproceso_dialog.dart';
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
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkHeader,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        toolbarHeight: 72,
        surfaceTintColor: AppColors.darkHeader,
        shape: const Border(bottom: BorderSide(color: AppColors.darkCardBorder)),
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkTextPrimary),
                    children: [
                      TextSpan(text: 'ORBILOQ '),
                      TextSpan(
                        text: '| KARDEX MAESTRO',
                        style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.tealAccent),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'CONTROL OPERATIVO DE BODEGA Y PRODUCCIÓN',
                  style: TextStyle(fontSize: 10, color: AppColors.darkTextMuted, letterSpacing: 0.4),
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
              foregroundColor: AppColors.darkTextSecondary,
              side: const BorderSide(color: AppColors.darkCardBorder),
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
          const SizedBox(width: 10),
          _SelectorPerfil(rol: rol),
          const SizedBox(width: 20),
        ],
      ),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.tealAccent)),
        error: (e, _) => Center(
          child: Text('Error cargando datos: $e', style: const TextStyle(color: AppColors.darkTextPrimary)),
        ),
        data: (s) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cabecera(rol: rol, enTransito: s.lotesConPendientes),
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

/// Botón-píldora "PERFIL DE TRABAJO" que abre un menú con los roles
/// disponibles. Solo muestra los 2 que funcionan hoy (Producción y Bodega).
class _SelectorPerfil extends ConsumerWidget {
  const _SelectorPerfil({required this.rol});

  final Rol rol;

  IconData _icono(Rol r) => r == Rol.produccion ? Icons.content_cut : Icons.warehouse_outlined;
  String _etiqueta(Rol r) => r == Rol.produccion ? 'Producción' : 'Bodega';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usarSupabase = ref.watch(usarSupabaseProvider);
    final sesion = usarSupabase ? ref.watch(usuarioSesionProvider).value : null;
    final esAdmin = !usarSupabase || sesion?.rolCuenta == RolCuenta.admin;

    final pastilla = esAdmin
        ? _pastillaDesplegable(context, ref)
        : _pastillaFija(sesion?.nombre ?? _etiqueta(rol));

    if (!usarSupabase) return pastilla; // modo memoria: sin sesión que cerrar

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pastilla,
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Cerrar sesión',
          icon: const Icon(Icons.logout, size: 18, color: AppColors.darkTextMuted),
          onPressed: () => ref.read(authRepositoryProvider)?.cerrarSesion(),
        ),
      ],
    );
  }

  /// Producción o Logística: no pueden cambiar de rol, solo ven quiénes son.
  Widget _pastillaFija(String nombre) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.tealPrimary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.tealPrimary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icono(rol), size: 16, color: AppColors.tealAccent),
          const SizedBox(width: 8),
          Text(nombre, style: const TextStyle(color: AppColors.tealAccent, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  /// Administrador (o modo memoria sin login): puede alternar entre vistas.
  Widget _pastillaDesplegable(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<Rol>(
      color: AppColors.darkCard,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.darkCardBorder),
      ),
      onSelected: (r) => ref.read(rolProvider.notifier).cambiar(r),
      itemBuilder: (context) => [
        const PopupMenuItem<Rol>(
          enabled: false,
          height: 32,
          child: Text(
            'PERFIL DE TRABAJO',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.darkTextMuted, letterSpacing: 0.5),
          ),
        ),
        for (final r in Rol.values)
          PopupMenuItem<Rol>(
            value: r,
            child: Row(
              children: [
                Icon(_icono(r), size: 18, color: r == rol ? AppColors.tealAccent : AppColors.darkTextSecondary),
                const SizedBox(width: 10),
                Text(_etiqueta(r),
                    style: TextStyle(
                      color: r == rol ? AppColors.tealAccent : AppColors.darkTextPrimary,
                      fontWeight: r == rol ? FontWeight.bold : FontWeight.normal,
                    )),
                if (r == rol) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 16, color: AppColors.tealAccent),
                ],
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.tealPrimary.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.tealPrimary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icono(rol), size: 16, color: AppColors.tealAccent),
            const SizedBox(width: 8),
            Text(_etiqueta(rol),
                style: const TextStyle(color: AppColors.tealAccent, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 16, color: AppColors.tealAccent),
          ],
        ),
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.rol, required this.enTransito});

  final Rol rol;
  final int enTransito;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Órdenes activas',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.darkTextPrimary),
            ),
            SizedBox(height: 2),
            Text(
              'Producción, bodega y despachos en un solo tablero',
              style: TextStyle(fontSize: 13, color: AppColors.darkTextSecondary),
            ),
          ],
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (rol == Rol.produccion) ...[
              _BotonAccion(
                icono: Icons.history,
                texto: 'Entregar lote y ver historial',
                onPressed: () => showEntregaProduccionDialog(context),
              ),
              _BotonAccion(
                icono: Icons.report_gmailerrorred_outlined,
                texto: 'Productos no conforme',
                onPressed: () => showReprocesoDialog(context),
              ),
            ] else ...[
              _BotonAccion(
                icono: Icons.move_to_inbox_outlined,
                texto: 'Recibir lote ($enTransito)',
                onPressed: () => showRecepcionDialog(context),
              ),
              _BotonAccion(
                icono: Icons.report_gmailerrorred_outlined,
                texto: 'Producto no conforme',
                onPressed: () => showNoConformeDialog(context),
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
        foregroundColor: AppColors.tealAccent,
        side: const BorderSide(color: AppColors.tealPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
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
  String _operario = WmsConstantes.operarios.first;
  String _filtroOp = '';
  FeedbackMessage? _msgGeneral;

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

    setState(() {
      _msgGeneral = null;
      _liberando[k.id] = true;
    });
    final res = await ref.read(wmsRepositoryProvider).liberarNoConforme(
          itemId: k.id,
          cantidad: cantidad,
          operario: _operario,
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
              : ListView.builder(
                  itemCount: visibles.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TarjetaNoConforme(
                      kardex: visibles[i],
                      cantidadCtrl: _ctrlPara(visibles[i]),
                      liberando: _liberando[visibles[i].id] ?? false,
                      onLiberar: () => _liberar(visibles[i]),
                    ),
                  ),
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
    required this.onLiberar,
  });

  final ItemKardex kardex;
  final TextEditingController cantidadCtrl;
  final bool liberando;
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
                  'OP: ${l.item.op} | Por: ${l.operario} | ${formatFechaHora(l.fecha)}'
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

echo ""
echo "Listo. flutter analyze / flutter test"
