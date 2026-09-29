#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Liberacion parcial de Aliados + fix ENTER + nota en card (v45)
# Requiere haber corrido antes dev_07_aliados_parcial.sql en el proyecto DEV.
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_aliados_parcial_v45.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi
echo "Aplicando liberacion parcial de Aliados..."

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

enum TipoMovimiento {
  entregaProduccion, recepcion, despacho, devolucionProduccion, liberacionNoConforme,
  envioAliado, liberacionAliado,
}

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
    this.recibidoPorLogistica = '',
  });

  final String id;
  final ItemOrden item;
  final int cantidad;
  final String operario;
  final DateTime fecha;
  final String nota;
  /// Quién de Logística recibió de vuelta la prenda liberada.
  final String recibidoPorLogistica;
}

/// Registro de haber reportado un producto como no conforme.
class Devolucion {
  const Devolucion({
    required this.id,
    required this.item,
    required this.cantidad,
    required this.causal,
    required this.operario,
    required this.fecha,
    this.nota = '',
    this.recibidoDeProduccion = '',
  });

  final String id;
  final ItemOrden item;
  final int cantidad;
  final String causal;
  final String operario;
  final DateTime fecha;
  final String nota;
  /// Quién de Producción entregó la prenda reportada como no conforme.
  final String recibidoDeProduccion;
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
    this.esReproceso = false,
    this.recibidoPor = '',
  });

  final String id;
  final ItemOrden item;
  final int cantidadEnviada;
  final EstadoLineaLote estado;
  final int? cantidadRecibida;
  final String? ubicacionDestino;
  final String novedad;
  final DateTime? fechaRecepcion;

  /// true si esta línea viene de liberar un producto no conforme (en vez de
  /// una entrega normal de Producción) — para distinguirla en Recepción.
  final bool esReproceso;

  /// Persona de Logística que hizo la recepción. Vacío para líneas recibidas
  /// antes de que este campo existiera — se muestra igual, sin error.
  final String recibidoPor;

  bool get enTransito => estado == EstadoLineaLote.enTransito;

  LoteLinea copyWith({
    EstadoLineaLote? estado,
    int? cantidadRecibida,
    String? ubicacionDestino,
    String? novedad,
    DateTime? fechaRecepcion,
    String? recibidoPor,
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
      esReproceso: esReproceso,
      recibidoPor: recibidoPor ?? this.recibidoPor,
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
    this.fechaEsperadaProduccion,
    this.fechaEsperadaLogistica,
    this.pendienteReproceso = 0,
    this.pendienteAliados = 0,
  });

  final ItemOrden item;
  final int producido;
  final int recibido;
  final int despachado;

  /// Stock por ubicación (solo cantidades > 0).
  final Map<String, int> ubicaciones;
  final DateTime? fechaEntrega;
  final DateTime? fechaRecepcion;

  /// Fecha esperada de entrega desde Producción hacia Logística (viene del
  /// Excel de fechas esperadas, columna "FECHA PROD"). Alimenta el estado
  /// "Estado parcial por retardo" y la columna "Fecha esperada" de Producción.
  final DateTime? fechaEsperadaProduccion;

  /// Fecha esperada de despacho hacia el cliente final (viene del mismo
  /// Excel, columna "FECHA LOG"). Alimenta "Fecha esperada" y "Días
  /// faltantes" en la vista de Logística.
  final DateTime? fechaEsperadaLogistica;

  /// Unidades devueltas a Producción por no conformidad, aún sin reprocesar.
  final int pendienteReproceso;

  /// Unidades enviadas a Aliados por no conformidad, aún sin liberar.
  final int pendienteAliados;

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
    final esperada = fechaEsperadaProduccion;
    if (esperada != null) {
      final hoy = DateTime.now();
      final soloHoy = DateTime(hoy.year, hoy.month, hoy.day);
      final soloEsperada = DateTime(esperada.year, esperada.month, esperada.day);
      if (soloEsperada.isBefore(soloHoy)) return EstadoProduccion.parcialPorRetardo;
    }
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

/// Solicitud de Producto No Conforme enviado a un Aliado externo. El total
/// solicitado se mantiene fijo; [cantidadLiberada] es un acumulado que crece
/// con cada liberación (parcial o completa) — nunca se sobrescribe, cada
/// liberación queda como su propio registro en [LiberacionAliado].
class NoConformeAliado {
  const NoConformeAliado({
    required this.id,
    required this.item,
    required this.cantidad,
    required this.causal,
    required this.estado,
    required this.usuarioSolicitud,
    required this.personaAliadoEntrega,
    required this.fechaSolicitud,
    this.notaSolicitud = '',
    this.cantidadLiberada = 0,
  });

  final String id;
  final ItemOrden item;

  /// Total original solicitado — nunca cambia.
  final int cantidad;
  final String causal;

  /// 'pendiente' o 'liberado' (liberado = ya se liberó el total).
  final String estado;

  final String usuarioSolicitud;
  final String personaAliadoEntrega;
  final DateTime fechaSolicitud;
  final String notaSolicitud;

  /// Acumulado de lo ya liberado (suma de todas las liberaciones, parciales
  /// o no) — siempre <= [cantidad]. El detalle de cada liberación individual
  /// vive aparte, en [LiberacionAliado] (ver cargarLiberacionesAliados).
  final int cantidadLiberada;

  int get cantidadPendiente => cantidad - cantidadLiberada;
  bool get pendiente => estado != 'liberado';
}

/// Un evento de liberación (parcial o completa) sobre una solicitud de
/// Aliados. Cada liberación es su propio registro — nunca se sobrescribe.
class LiberacionAliado {
  const LiberacionAliado({
    required this.id,
    required this.solicitudId,
    required this.item,
    required this.cantidad,
    required this.tipo,
    required this.operario,
    required this.personaAliado,
    required this.fecha,
    this.nota = '',
    this.cantidadTotalSolicitud = 0,
  });

  final String id;

  /// La solicitud (NoConformeAliado) a la que pertenece esta liberación.
  final String solicitudId;
  final ItemOrden item;

  /// Cuánto se liberó EN ESTE evento (no el total de la solicitud).
  final int cantidad;

  /// 'parcial' o 'completa'.
  final String tipo;

  final String operario;
  final String personaAliado;
  final DateTime fecha;
  final String nota;

  /// El total que tenía la solicitud original, para dar contexto en el historial.
  final int cantidadTotalSolicitud;
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
    required String recibidoPor,
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

  /// Lista ampliable de personas de Aliados. Se puede agregar un nombre
  /// nuevo con [agregarPersonalAliado].
  Future<List<String>> cargarPersonalAliados();

  /// Agrega (o reutiliza si ya existe) un nombre en la lista de personal de
  /// Aliados, devolviendo el nombre normalizado guardado.
  Future<Result<String>> agregarPersonalAliado(String nombre);

  /// Producción envía unidades no conformes a un Aliado externo. Flujo
  /// independiente del de Logística — no pasa por lotes ni Recepción.
  Future<Result<void>> enviarNoConformeAliado({
    required String itemId,
    required int cantidad,
    required String causalId,
    required String operario,
    required String personaAliadoEntrega,
    String nota = '',
  });

  /// Producción libera (total o parcialmente) un envío a Aliados. Cada
  /// llamada crea un registro de liberación propio — nunca sobrescribe uno
  /// anterior. Solo marca la solicitud como completada cuando lo liberado
  /// acumulado alcanza el total solicitado.
  Future<Result<void>> liberarNoConformeAliado({
    required String id,
    required int cantidad,
    required String operario,
    required String personaAliadoLibera,
    String nota = '',
  });

  /// Todas las solicitudes de Aliados (para "Pendientes"), más recientes primero.
  Future<List<NoConformeAliado>> cargarNoConformesAliados();

  /// Todas las liberaciones de Aliados (para "Historial"), una fila por cada
  /// liberación — más recientes primero.
  Future<List<LiberacionAliado>> cargarLiberacionesAliados();

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
  int pendienteAliados = 0;
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
  final List<String> _personalAliados = ['TALLER ALIADO 1'];
  final List<NoConformeAliado> _noConformesAliados = []; // más recientes primero
  int _correlativoAliado = 0;
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
        case TipoMovimiento.envioAliado:
          a.producido -= m.cantidad;
          a.pendienteAliados += m.cantidad;
        case TipoMovimiento.liberacionAliado:
          a.producido += m.cantidad;
          a.pendienteAliados -= m.cantidad;
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
    required String recibidoPor,
    String nota = '',
  }) async {
    if (recibidoPor.trim().isEmpty) {
      return Err<LoteLinea>('Debes indicar quién de Logística recibió esta prenda.');
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
      return Err<LoteLinea>('Esta línea ya fue recibida.');
    }
    if (cantidad <= 0) return Err<LoteLinea>('La cantidad debe ser mayor a 0.');
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
      recibidoPor: recibidoPor,
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
  Future<List<String>> cargarPersonalAliados() async => List.unmodifiable(_personalAliados);

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
      return Err<void>('Debes indicar a quién de Aliados se le entrega esta prenda.');
    }
    final item = _items[itemId];
    if (item == null) return Err<void>('El producto no existe en el kardex.');
    if (cantidad <= 0) return Err<void>('La cantidad debe ser mayor a 0.');
    final producido = _snapshot().kardexPorId(itemId)?.producido ?? 0;
    if (cantidad > producido) {
      return Err<void>('LÍMITE EXCEDIDO: solo hay $producido Uds entregadas por Producción para este producto.');
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
    if (!actual.pendiente) return Err<void>('Esta solicitud ya fue liberada por completo.');
    if (cantidad > actual.cantidadPendiente) {
      return Err<void>('LÍMITE EXCEDIDO: solo quedan ${actual.cantidadPendiente} Uds pendientes por liberar de esta solicitud.');
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
  Future<List<NoConformeAliado>> cargarNoConformesAliados() async => List.unmodifiable(_noConformesAliados);

  @override
  Future<List<LiberacionAliado>> cargarLiberacionesAliados() async => List.unmodifiable(_liberacionesAliados);

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
    {String recibidoPor = ''}
  ) {
    final lineaActualizada = linea.copyWith(
      estado: novedad.isEmpty ? EstadoLineaLote.recibidoConforme : EstadoLineaLote.recibidoConNovedad,
      cantidadRecibida: cantidad,
      ubicacionDestino: ubicacion,
      novedad: novedad,
      fechaRecepcion: fecha,
      recibidoPor: recibidoPor,
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
      fechaEsperadaProduccion: _fecha(row['fecha_esperada_produccion']),
      fechaEsperadaLogistica: _fecha(row['fecha_esperada_logistica']),
      pendienteReproceso: (row['pendiente_reproceso'] as num?)?.toInt() ?? 0,
      pendienteAliados: (row['pendiente_aliados'] as num?)?.toInt() ?? 0,
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
      recibidoPor: (row['recibido_por'] as String?) ?? '',
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
    required String recibidoPor,
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
        'p_recibido_por': recibidoPor,
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
  Future<List<String>> cargarPersonalAliados() async {
    final filas = await _client
        .from('personal_aliados')
        .select('nombre')
        .eq('activo', true)
        .order('nombre');
    return [for (final f in (filas as List).cast<Map<String, dynamic>>()) f['nombre'] as String];
  }

  @override
  Future<Result<String>> agregarPersonalAliado(String nombre) async {
    try {
      final res = await _client.rpc('agregar_personal_aliado', params: {'p_nombre': nombre});
      final fila = res as Map<String, dynamic>;
      return Ok<String>(fila['nombre'] as String);
    } on PostgrestException catch (e) {
      return Err<String>(e.message);
    } catch (e) {
      return Err<String>('Error inesperado al agregar el nombre: $e');
    }
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
    try {
      await _client.rpc('enviar_no_conforme_aliado', params: {
        'p_item_orden_id': itemId,
        'p_cantidad': cantidad,
        'p_causal_id': causalId,
        'p_operario_nombre': operario,
        'p_persona_aliado_entrega': personaAliadoEntrega,
        'p_nota': nota,
      });
      await refrescar();
      return const Ok<void>(null);
    } on PostgrestException catch (e) {
      return Err<void>(e.message);
    } catch (e) {
      return Err<void>('Error inesperado al enviar a Aliados: $e');
    }
  }

  @override
  Future<Result<void>> liberarNoConformeAliado({
    required String id,
    required int cantidad,
    required String operario,
    required String personaAliadoLibera,
    String nota = '',
  }) async {
    try {
      await _client.rpc('liberar_no_conforme_aliado', params: {
        'p_solicitud_id': id,
        'p_cantidad': cantidad,
        'p_operario_nombre': operario,
        'p_persona_aliado_libera': personaAliadoLibera,
        'p_nota': nota,
      });
      await refrescar();
      return const Ok<void>(null);
    } on PostgrestException catch (e) {
      return Err<void>(e.message);
    } catch (e) {
      return Err<void>('Error inesperado al liberar de Aliados: $e');
    }
  }

  @override
  Future<List<NoConformeAliado>> cargarNoConformesAliados() async {
    final filas = await _traerTodo(
      (desde, hasta) =>
          _client.from('vista_no_conformes_aliados').select().order('fecha_solicitud', ascending: false).range(desde, hasta),
    );
    return [
      for (final row in filas)
        NoConformeAliado(
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
          cantidad: (row['cantidad_solicitada'] as num).toInt(),
          causal: row['causal_nombre'] as String,
          estado: row['estado'] as String,
          usuarioSolicitud: row['usuario_produccion_solicitud_nombre'] as String,
          personaAliadoEntrega: row['persona_aliado_entrega'] as String,
          fechaSolicitud: DateTime.parse(row['fecha_solicitud'] as String).toLocal(),
          notaSolicitud: (row['nota_solicitud'] as String?) ?? '',
          cantidadLiberada: (row['cantidad_liberada'] as num?)?.toInt() ?? 0,
        ),
    ];
  }

  @override
  Future<List<LiberacionAliado>> cargarLiberacionesAliados() async {
    final filas = await _traerTodo(
      (desde, hasta) =>
          _client.from('vista_liberaciones_aliados').select().order('fecha', ascending: false).range(desde, hasta),
    );
    return [
      for (final row in filas)
        LiberacionAliado(
          id: row['id'] as String,
          solicitudId: row['solicitud_id'] as String,
          item: ItemOrden(
            id: row['item_orden_id'] as String,
            op: row['op_numero'] as String,
            cliente: row['item_cliente'] as String,
            oc: (row['item_oc'] as String?) ?? '',
            codigo: row['item_codigo'] as String,
            descripcion: row['item_descripcion'] as String,
            talla: row['item_talla'] as String,
            cantidadPedida: (row['cantidad_pedida'] as num?)?.toInt() ?? 0,
          ),
          cantidad: (row['cantidad'] as num).toInt(),
          tipo: (row['es_entrega_completa'] as bool) ? 'completa' : 'parcial',
          operario: row['usuario_produccion_nombre'] as String,
          personaAliado: row['persona_aliado_libera'] as String,
          fecha: DateTime.parse(row['fecha'] as String).toLocal(),
          nota: (row['nota'] as String?) ?? '',
          cantidadTotalSolicitud: (row['cantidad_solicitada'] as num?)?.toInt() ?? 0,
        ),
    ];
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

echo "  - lib/application/providers.dart"
mkdir -p "$(dirname 'lib/application/providers.dart')"
cat > 'lib/application/providers.dart' << 'ORBILOQ_EOF'
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
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

/// Lista ampliable de personas de Aliados (a quién se entrega / quién libera
/// un producto no conforme enviado a un taller externo).
final personalAliadosProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(wmsRepositoryProvider).cargarPersonalAliados(),
);

/// Todas las solicitudes de Producto No Conforme a Aliados (pendientes e
/// historial), más recientes primero.
final noConformesAliadosProvider = FutureProvider<List<NoConformeAliado>>(
  (ref) => ref.watch(wmsRepositoryProvider).cargarNoConformesAliados(),
);

/// Cada liberación (parcial o completa) de Aliados, una fila por evento —
/// para el Historial detallado.
final liberacionesAliadosProvider = FutureProvider<List<LiberacionAliado>>(
  (ref) => ref.watch(wmsRepositoryProvider).cargarLiberacionesAliados(),
);

// ------------------------------------------------------------------ tema

/// Modo de color de la pantalla del Kardex (oscuro/claro). Solo cambia el
/// estilo visual, no afecta ninguna funcionalidad. Arranca en oscuro, el
/// tema de siempre.
class TemaNotifier extends Notifier<TemaModo> {
  @override
  TemaModo build() => TemaModo.oscuro;

  void alternar() => state = state == TemaModo.oscuro ? TemaModo.claro : TemaModo.oscuro;
}

final temaProvider = NotifierProvider<TemaNotifier, TemaModo>(TemaNotifier.new);

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

echo "  - lib/features/aliados_no_conforme/presentation/aliados_no_conforme_dialog.dart"
mkdir -p "$(dirname 'lib/features/aliados_no_conforme/presentation/aliados_no_conforme_dialog.dart')"
cat > 'lib/features/aliados_no_conforme/presentation/aliados_no_conforme_dialog.dart' << 'ORBILOQ_EOF'
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
import '../../../shared/widgets/addable_person_dropdown.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showAliadosNoConformeDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const AliadosNoConformeDialog());

class AliadosNoConformeDialog extends StatelessWidget {
  const AliadosNoConformeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return WmsDialogShell(
      title: 'PRODUCTOS NO CONFORME DE ALIADOS',
      icon: Icons.handshake_outlined,
      iconColor: AppColors.primaryNavy,
      expand: true,
      maxWidth: 1000,
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
                Tab(height: 38, icon: Icon(Icons.outbox_outlined, size: 16), text: 'ENVIAR A ALIADO'),
                Tab(height: 38, icon: Icon(Icons.hourglass_top_outlined, size: 16), text: 'PENDIENTES'),
                Tab(height: 38, icon: Icon(Icons.history, size: 16), text: 'HISTORIAL'),
              ],
            ),
            const SizedBox(height: 8),
            const Expanded(
              child: TabBarView(children: [_EnviarTab(), _PendientesTab(), _HistorialTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

class _CausalDropdownAliados extends ConsumerWidget {
  const _CausalDropdownAliados({required this.valor, required this.onChanged});

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

// ================================================================ pestaña 1: enviar

class _EnviarTab extends ConsumerStatefulWidget {
  const _EnviarTab();

  @override
  ConsumerState<_EnviarTab> createState() => _EnviarTabState();
}

class _EnviarTabState extends ConsumerState<_EnviarTab> {
  final _opCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  List<ItemKardex> _resultados = [];
  String? _errorBusqueda;
  ItemKardex? _seleccionado;
  String? _causalId;
  String? _personaAliado;
  String _operario = WmsConstantes.operarios.first;
  bool _enviando = false;
  FeedbackMessage? _msg;

  @override
  void dispose() {
    _opCtrl.dispose();
    _cantidadCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  /// Reconoce si lo que se escribió/escaneó es un QR de prenda o un número
  /// de OP simple — misma lógica que ya usa Recepción.
  void _procesarEntrada(String raw) {
    final texto = raw.trim();
    final kardex = ref.read(wmsSnapshotProvider).value?.kardex ?? const <ItemKardex>[];
    setState(() {
      _seleccionado = null;
      if (texto.isEmpty) {
        _errorBusqueda = 'Escanea una prenda o escribe un número de OP.';
        _resultados = [];
        return;
      }

      final qr = QrPrenda.tryParse(texto);
      if (qr != null) {
        final encontrado = kardex.where((k) => k.item.op == qr.op && k.item.codigo == qr.codigo).toList();
        if (encontrado.isEmpty || encontrado.first.producido <= 0) {
          _errorBusqueda = 'No se encontró esa prenda con unidades entregadas por Producción.';
          _resultados = [];
          return;
        }
        _resultados = encontrado;
        _errorBusqueda = null;
        _seleccionado = encontrado.first;
        return;
      }

      // No es un QR: se interpreta como número de OP.
      _resultados = kardex.where((k) => k.item.op == texto && k.producido > 0).toList();
      _errorBusqueda = _resultados.isEmpty ? 'No se encontraron tallas entregadas por Producción para la OP $texto.' : null;
    });
  }

  Future<void> _enviar() async {
    final k = _seleccionado;
    if (k == null) return;
    final cantidad = int.tryParse(_cantidadCtrl.text.trim());
    if (_causalId == null) {
      setState(() => _msg = const FeedbackMessage.error('Selecciona una causal.'));
      return;
    }
    if (_personaAliado == null || _personaAliado!.trim().isEmpty) {
      setState(() => _msg = const FeedbackMessage.error('Selecciona a quién de Aliados se le entrega la prenda.'));
      return;
    }
    if (cantidad == null || cantidad <= 0) {
      setState(() => _msg = const FeedbackMessage.error('Ingresa una cantidad mayor a 0.'));
      return;
    }
    if (cantidad > k.producido) {
      setState(() => _msg = FeedbackMessage.error('LÍMITE EXCEDIDO: solo hay ${k.producido} Uds entregadas por Producción.'));
      return;
    }

    setState(() {
      _enviando = true;
      _msg = null;
    });
    final res = await ref.read(wmsRepositoryProvider).enviarNoConformeAliado(
          itemId: k.id,
          cantidad: cantidad,
          causalId: _causalId!,
          operario: _operario,
          personaAliadoEntrega: _personaAliado!,
          nota: _notaCtrl.text,
        );
    if (!mounted) return;
    setState(() {
      _enviando = false;
      switch (res) {
        case Ok():
          _msg = FeedbackMessage.ok('${cantidad}u de ${k.item.descripcion} (${k.item.talla}) enviadas a $_personaAliado.');
          _seleccionado = null;
          _causalId = null;
          _personaAliado = null;
          _cantidadCtrl.clear();
          _notaCtrl.clear();
          _resultados = [];
          _opCtrl.clear();
        case Err(:final message):
          _msg = FeedbackMessage.error(message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msg != null) ...[FeedbackBanner(message: _msg!), const SizedBox(height: 12)],
          DropdownButtonFormField<String>(
            initialValue: _operario,
            decoration: wmsInput('Enviado por (Producción)', icon: Icons.person_outline),
            items: [for (final o in WmsConstantes.operarios) DropdownMenuItem(value: o, child: Text(o))],
            onChanged: (v) => setState(() => _operario = v ?? _operario),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _opCtrl,
                  autofocus: true,
                  decoration: wmsInput('Escanear prenda o buscar por OP', icon: Icons.qr_code_scanner),
                  onSubmitted: (v) => _procesarEntrada(v),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _procesarEntrada(_opCtrl.text),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('BUSCAR'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy, foregroundColor: Colors.white),
              ),
            ],
          ),
          if (_errorBusqueda != null) ...[
            const SizedBox(height: 8),
            Text(_errorBusqueda!, style: const TextStyle(color: AppColors.alertRed)),
          ],
          if (_resultados.isNotEmpty && _seleccionado == null) ...[
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  for (final r in _resultados)
                    ListTile(
                      onTap: () => setState(() => _seleccionado = r),
                      leading: const Icon(Icons.checkroom, color: AppColors.primaryNavy),
                      title: Text('${r.item.codigo} — ${r.item.descripcion} (Talla ${r.item.talla})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text('Entregadas por Producción: ${r.producido} Uds'),
                    ),
                ],
              ),
            ),
          ],
          if (_seleccionado != null) ...[
            const SizedBox(height: 10),
            Card(
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(side: BorderSide(color: Colors.blue.shade200), borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'OP: ${_seleccionado!.item.op} - ${_seleccionado!.item.descripcion} (${_seleccionado!.item.talla})',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _seleccionado = null)),
                      ],
                    ),
                    MetricWrap(children: [
                      MetricCard(
                        title: 'ENTREGADAS',
                        value: '${_seleccionado!.producido} Uds',
                        color: AppColors.actionGreen,
                        icon: Icons.check_circle,
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _CausalDropdownAliados(valor: _causalId, onChanged: (v) => setState(() => _causalId = v)),
                    const SizedBox(height: 10),
                    AddablePersonDropdown(
                      label: 'A quién de Aliados se le entrega *',
                      valor: _personaAliado,
                      onChanged: (v) => setState(() => _personaAliado = v),
                      itemsProvider: personalAliadosProvider,
                      onAgregar: (ref, nombre) => ref.read(wmsRepositoryProvider).agregarPersonalAliado(nombre),
                      tituloDialogo: 'Agregar persona de Aliados',
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _cantidadCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: wmsInput('Cantidad a enviar (máx ${_seleccionado!.producido} Uds)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: _notaCtrl, decoration: wmsInput('Nota (opcional)', icon: Icons.notes)),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: _enviando ? null : _enviar,
                        icon: _enviando
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.outbox_outlined, color: Colors.white, size: 20),
                        label: const Text('ENVIAR A ALIADO'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================ pestaña 2: pendientes

class _PendientesTab extends ConsumerStatefulWidget {
  const _PendientesTab();

  @override
  ConsumerState<_PendientesTab> createState() => _PendientesTabState();
}

class _PendientesTabState extends ConsumerState<_PendientesTab> {
  final Map<String, String?> _personaMap = {};
  final Map<String, String> _operarioMap = {};
  final Map<String, TextEditingController> _cantidadCtrls = {};
  final Map<String, bool> _liberando = {};
  FeedbackMessage? _msg;

  @override
  void dispose() {
    for (final c in _cantidadCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrlPara(NoConformeAliado a) {
    return _cantidadCtrls.putIfAbsent(a.id, () => TextEditingController(text: '${a.cantidadPendiente}'));
  }

  Future<void> _liberar(NoConformeAliado a) async {
    final persona = _personaMap[a.id];
    if (persona == null || persona.trim().isEmpty) {
      setState(() => _msg = const FeedbackMessage.error('Selecciona quién de Aliados realizó la liberación.'));
      return;
    }
    final cantidad = int.tryParse(_ctrlPara(a).text.trim());
    if (cantidad == null || cantidad <= 0) {
      setState(() => _msg = const FeedbackMessage.error('Ingresa una cantidad mayor a 0 para liberar.'));
      return;
    }
    if (cantidad > a.cantidadPendiente) {
      setState(() => _msg =
          FeedbackMessage.error('LÍMITE EXCEDIDO: solo quedan ${a.cantidadPendiente} Uds pendientes por liberar.'));
      return;
    }

    setState(() {
      _msg = null;
      _liberando[a.id] = true;
    });
    final res = await ref.read(wmsRepositoryProvider).liberarNoConformeAliado(
          id: a.id,
          cantidad: cantidad,
          operario: _operarioMap[a.id] ?? WmsConstantes.operarios.first,
          personaAliadoLibera: persona,
        );
    if (!mounted) return;
    setState(() {
      _liberando[a.id] = false;
      switch (res) {
        case Ok():
          final quedan = a.cantidadPendiente - cantidad;
          _msg = FeedbackMessage.ok(
            quedan > 0
                ? '${cantidad}u de ${a.item.descripcion} (${a.item.talla}) liberadas — quedan $quedan Uds pendientes.'
                : '${cantidad}u de ${a.item.descripcion} (${a.item.talla}) liberadas — solicitud completada.',
          );
          _personaMap.remove(a.id);
          _cantidadCtrls.remove(a.id)?.dispose();
        case Err(:final message):
          _msg = FeedbackMessage.error(message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final todas = ref.watch(noConformesAliadosProvider);
    return todas.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.alertRed))),
      data: (lista) {
        final pendientes = lista.where((a) => a.pendiente).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_msg != null) ...[FeedbackBanner(message: _msg!), const SizedBox(height: 12)],
            Expanded(
              child: pendientes.isEmpty
                  ? const Center(child: Text('No hay envíos a Aliados pendientes por liberar.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: pendientes.length,
                      itemBuilder: (_, i) {
                        final a = pendientes[i];
                        final parcial = a.cantidadLiberada > 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Card(
                            color: Colors.amber.shade50,
                            shape: RoundedRectangleBorder(side: BorderSide(color: Colors.amber.shade700), borderRadius: BorderRadius.circular(8)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('OP: ${a.item.op} - ${a.item.descripcion} (${a.item.talla})',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                                  Text(
                                    parcial
                                        ? 'Solicitado: ${a.cantidad} Uds | Ya liberado: ${a.cantidadLiberada} Uds | '
                                            'Pendiente (máx a liberar): ${a.cantidadPendiente} Uds | Causal: ${a.causal}'
                                        : '${a.cantidad} Uds | Causal: ${a.causal}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    'Entregado a: ${a.personaAliadoEntrega} | Enviado por: ${a.usuarioSolicitud} | ${formatFechaHora(a.fechaSolicitud)}',
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                  if (a.notaSolicitud.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                                      child: Text('Nota: ${a.notaSolicitud}',
                                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                                    ),
                                  ],
                                  const Divider(),
                                  DropdownButtonFormField<String>(
                                    initialValue: _operarioMap[a.id] ?? WmsConstantes.operarios.first,
                                    decoration: wmsInput('Liberado por (Producción)', icon: Icons.person_outline),
                                    items: [for (final o in WmsConstantes.operarios) DropdownMenuItem(value: o, child: Text(o))],
                                    onChanged: (v) => setState(() => _operarioMap[a.id] = v ?? WmsConstantes.operarios.first),
                                  ),
                                  const SizedBox(height: 10),
                                  AddablePersonDropdown(
                                    label: 'Quién de Aliados liberó *',
                                    valor: _personaMap[a.id],
                                    onChanged: (v) => setState(() => _personaMap[a.id] = v),
                                    itemsProvider: personalAliadosProvider,
                                    onAgregar: (ref, nombre) => ref.read(wmsRepositoryProvider).agregarPersonalAliado(nombre),
                                    tituloDialogo: 'Agregar persona de Aliados',
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _ctrlPara(a),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    decoration: wmsInput('Cantidad a liberar (máx ${a.cantidadPendiente} Uds)'),
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: ElevatedButton.icon(
                                      onPressed: (_liberando[a.id] ?? false) ? null : () => _liberar(a),
                                      icon: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                                      label: const Text('LIBERAR'),
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.actionGreen, foregroundColor: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================ pestaña 3: historial

class _HistorialTab extends ConsumerWidget {
  const _HistorialTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitudes = ref.watch(noConformesAliadosProvider);
    final liberaciones = ref.watch(liberacionesAliadosProvider);

    if (solicitudes.isLoading || liberaciones.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (solicitudes.hasError) {
      return Center(child: Text('Error: ${solicitudes.error}', style: const TextStyle(color: AppColors.alertRed)));
    }
    if (liberaciones.hasError) {
      return Center(child: Text('Error: ${liberaciones.error}', style: const TextStyle(color: AppColors.alertRed)));
    }

    final lista = solicitudes.requireValue;
    final todasLiberaciones = liberaciones.requireValue;

    if (lista.isEmpty) {
      return const Center(child: Text('Aún no hay solicitudes de Aliados.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      itemCount: lista.length,
      itemBuilder: (_, i) {
        final a = lista[i];
        final eventos = todasLiberaciones.where((l) => l.solicitudId == a.id).toList()
          ..sort((x, y) => x.fecha.compareTo(y.fecha)); // más antigua primero, orden natural de entrega
        return Card(
          color: a.pendiente ? Colors.amber.shade50 : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('OP: ${a.item.op} - ${a.item.descripcion} (${a.item.talla})',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                    ),
                    StatusChip(
                      label: a.pendiente ? 'PENDIENTE' : 'LIBERADO',
                      color: a.pendiente ? Colors.amber.shade800 : AppColors.actionGreen,
                    ),
                  ],
                ),
                Text('Solicitado: ${a.cantidad} Uds | Causal: ${a.causal}', style: const TextStyle(fontSize: 12)),
                Text(
                  'Entregado a: ${a.personaAliadoEntrega} | Enviado por: ${a.usuarioSolicitud} | ${formatFechaHora(a.fechaSolicitud)}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (a.notaSolicitud.isNotEmpty)
                  Text('Nota: ${a.notaSolicitud}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                if (eventos.isNotEmpty) ...[
                  const Divider(),
                  for (final ev in eventos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusChip(
                            label: ev.tipo == 'completa' ? 'ENTREGA COMPLETA' : 'ENTREGA PARCIAL',
                            color: ev.tipo == 'completa' ? AppColors.actionGreen : Colors.orange.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${ev.cantidad} Uds | ${ev.operario} ← ${ev.personaAliado} | ${formatFechaHora(ev.fecha)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
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
          onSubmitted: (v) {
            // Misma causa que el fix de "+ AGREGAR NUEVA PERSONA": cerrar el
            // diálogo (Navigator.pop) en el mismo instante en que el campo
            // de texto todavía está procesando el ENTER del teclado/IME
            // puede romper el árbol de elementos. Se retrasa al siguiente
            // frame para que el campo termine de procesar el ENTER primero.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (dialogContext.mounted) Navigator.of(dialogContext).pop(v.trim());
            });
          },
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
            // Se retrasa al siguiente frame: si se abre el diálogo en el
            // mismo instante en que el desplegable todavía está cerrando su
            // propio menú, Flutter puede romper el árbol de elementos
            // ("_dependents.isEmpty is not true").
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) _agregarNuevo(context, ref);
            });
            return;
          }
          onChanged(v);
        },
      ),
    );
  }
}
ORBILOQ_EOF

echo ""
echo "Listo. Prueba contra DEV:"
echo "  flutter analyze"
echo "  flutter run -d chrome --dart-define=SUPABASE_URL=https://igfuafcekcpugpmsoqbe.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_xpjhE8UM6FgjotbGexUdlw_wTj6VUWi"
