#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Recepcion parcial + Cerrar con faltante (v51, parte 1/2)
# Requiere haber corrido antes dev_09_recepcion_parcial_y_sobrantes.sql en DEV.
# Falta la Bandeja de Sobrantes (pantalla + boton), viene en la parte 2/2.
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_recepcion_parcial_v51.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi
echo "Aplicando recepcion parcial..."

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
  envioAliado, liberacionAliado, ajusteFaltanteEntrega,
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

  /// Cuánto falta por recibir de esta línea (0 si ya se completó o se cerró).
  int get cantidadPendiente => cantidadEnviada - (cantidadRecibida ?? 0);

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

/// Una unidad (o varias) que llegó de más al recibir un lote — no cuenta
/// para Bodega hasta que alguien decida qué hacer con ella.
class SobranteBodega {
  const SobranteBodega({
    required this.id,
    required this.item,
    required this.cantidad,
    required this.estado,
    required this.operario,
    required this.fecha,
    this.nota = '',
    this.resolucion,
    this.fechaResolucion,
  });

  final String id;
  final ItemOrden item;
  final int cantidad;

  /// 'pendiente' o 'resuelto'.
  final String estado;

  final String operario;
  final DateTime fecha;
  final String nota;

  /// Qué se decidió hacer con este sobrante (solo cuando ya está resuelto).
  final String? resolucion;
  final DateTime? fechaResolucion;

  bool get pendiente => estado == 'pendiente';
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

  /// Cierra una línea aceptando que el resto nunca llegó. Las unidades que
  /// faltaron vuelven a estar "pendientes por entregar" en Producción.
  Future<Result<void>> cerrarLoteItemConFaltante({
    required String loteLineaId,
    String nota = '',
  });

  /// Registra el excedente cuando llega MÁS de lo declarado en una línea —
  /// queda aparte, sin sumar a Bodega, hasta que se resuelva.
  Future<Result<void>> registrarSobrante({
    required String itemId,
    String? loteLineaId,
    required int cantidad,
    required String operario,
    String nota = '',
  });

  /// Marca un sobrante pendiente como resuelto, con la decisión tomada.
  Future<Result<void>> resolverSobrante({
    required String id,
    required String resolucion,
  });

  /// Todos los sobrantes (pendientes e historial), más recientes primero.
  Future<List<SobranteBodega>> cargarSobrantes();

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
  final List<LiberacionAliado> _liberacionesAliados = []; // más recientes primero
  int _correlativoLiberacionAliado = 0;
  final List<SobranteBodega> _sobrantes = []; // más recientes primero
  int _correlativoSobrante = 0;
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
      estado: completa ? EstadoLineaLote.recibidoConforme : EstadoLineaLote.enTransito,
      cantidadRecibida: nuevoRecibido,
      ubicacionDestino: ubicacion,
      fechaRecepcion: fecha,
      recibidoPor: recibidoPor,
    );

    final idxLote = _lotes.indexWhere((l) => l.id == loteEncontrado!.id);
    final nuevasLineas = [
      for (final l in _lotes[idxLote].lineas) l.id == loteLineaId ? lineaActualizada : l,
    ];
    final pendientesEnLote = nuevasLineas.where((l) => l.enTransito).length;
    _lotes[idxLote] = Lote(
      id: loteEncontrado.id,
      operario: loteEncontrado.operario,
      fechaEnvio: loteEncontrado.fechaEnvio,
      lineas: nuevasLineas,
      estado: pendientesEnLote == 0 ? EstadoLote.recibidoCompleto : EstadoLote.recibidoParcial,
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
      return Err<void>('Esta línea ya está completa, no hay faltante que cerrar.');
    }

    var novedad =
        'FALTANTE DEFINITIVO: se recibieron $recibido de ${lineaEncontrada.cantidadEnviada} Uds (nunca llegaron $faltante).';
    if (nota.trim().isNotEmpty) novedad = '$novedad Obs: ${nota.trim()}';

    final lineaActualizada = lineaEncontrada.copyWith(estado: EstadoLineaLote.recibidoConNovedad, novedad: novedad);

    final idxLote = _lotes.indexWhere((l) => l.id == loteEncontrado!.id);
    final nuevasLineas = [
      for (final l in _lotes[idxLote].lineas) l.id == loteLineaId ? lineaActualizada : l,
    ];
    final pendientesEnLote = nuevasLineas.where((l) => l.enTransito).length;
    _lotes[idxLote] = Lote(
      id: loteEncontrado.id,
      operario: loteEncontrado.operario,
      fechaEnvio: loteEncontrado.fechaEnvio,
      lineas: nuevasLineas,
      estado: pendientesEnLote == 0 ? EstadoLote.recibidoCompleto : EstadoLote.recibidoParcial,
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
  Future<Result<void>> resolverSobrante({required String id, required String resolucion}) async {
    if (resolucion.trim().isEmpty) return Err<void>('Debes indicar qué se decidió hacer con este sobrante.');
    final idx = _sobrantes.indexWhere((s) => s.id == id);
    if (idx == -1) return Err<void>('El sobrante no existe.');
    if (!_sobrantes[idx].pendiente) return Err<void>('El sobrante ya fue resuelto.');

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
  Future<List<SobranteBodega>> cargarSobrantes() async => List.unmodifiable(_sobrantes);


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
  Future<Result<void>> cerrarLoteItemConFaltante({
    required String loteLineaId,
    String nota = '',
  }) async {
    try {
      await _client.rpc('cerrar_lote_item_con_faltante', params: {
        'p_lote_item_id': loteLineaId,
        'p_nota': nota,
      });
      await refrescar();
      return const Ok<void>(null);
    } on PostgrestException catch (e) {
      return Err<void>(e.message);
    } catch (e) {
      return Err<void>('Error inesperado al cerrar la línea: $e');
    }
  }

  @override
  Future<Result<void>> registrarSobrante({
    required String itemId,
    String? loteLineaId,
    required int cantidad,
    required String operario,
    String nota = '',
  }) async {
    try {
      await _client.rpc('registrar_sobrante', params: {
        'p_item_orden_id': itemId,
        'p_lote_item_id': loteLineaId,
        'p_cantidad': cantidad,
        'p_operario_nombre': operario,
        'p_nota': nota,
      });
      return const Ok<void>(null);
    } on PostgrestException catch (e) {
      return Err<void>(e.message);
    } catch (e) {
      return Err<void>('Error inesperado al registrar el sobrante: $e');
    }
  }

  @override
  Future<Result<void>> resolverSobrante({required String id, required String resolucion}) async {
    try {
      await _client.rpc('resolver_sobrante', params: {'p_id': id, 'p_resolucion': resolucion});
      return const Ok<void>(null);
    } on PostgrestException catch (e) {
      return Err<void>(e.message);
    } catch (e) {
      return Err<void>('Error inesperado al resolver el sobrante: $e');
    }
  }

  @override
  Future<List<SobranteBodega>> cargarSobrantes() async {
    final filas = await _traerTodo(
      (desde, hasta) => _client.from('vista_sobrantes_bodega').select().order('fecha', ascending: false).range(desde, hasta),
    );
    return [
      for (final row in filas)
        SobranteBodega(
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
          estado: row['estado'] as String,
          operario: row['operario_nombre'] as String,
          fecha: DateTime.parse(row['fecha'] as String).toLocal(),
          nota: (row['nota'] as String?) ?? '',
          resolucion: row['resolucion'] as String?,
          fechaResolucion: _fecha(row['fecha_resolucion']),
        ),
    ];
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

/// Todo lo que llegó de más al recibir (pendiente e historial de sobrantes).
final sobrantesProvider = FutureProvider<List<SobranteBodega>>(
  (ref) => ref.watch(wmsRepositoryProvider).cargarSobrantes(),
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

echo "  - lib/features/recepcion/presentation/recepcion_dialog.dart"
mkdir -p "$(dirname 'lib/features/recepcion/presentation/recepcion_dialog.dart')"
cat > 'lib/features/recepcion/presentation/recepcion_dialog.dart' << 'ORBILOQ_EOF'
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
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showRecepcionDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const RecepcionDialog());

/// Empareja una línea con su lote de origen — solo para mostrar la
/// referencia ("LOTE-101") en la lista plana; no cambia el modelo de datos.
class _LineaConLote {
  const _LineaConLote(this.lote, this.linea);
  final Lote lote;
  final LoteLinea linea;
}

class RecepcionDialog extends StatelessWidget {
  const RecepcionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return WmsDialogShell(
      title: 'RECEPCIÓN Y REPORTE DE NOVEDADES',
      icon: Icons.move_to_inbox,
      iconColor: AppColors.primaryNavy,
      expand: true,
      maxWidth: 1000,
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
                Tab(height: 38, icon: Icon(Icons.move_to_inbox_outlined, size: 16), text: 'PENDIENTES'),
                Tab(height: 38, icon: Icon(Icons.history, size: 16), text: 'HISTORIAL'),
              ],
            ),
            const SizedBox(height: 8),
            const Expanded(
              child: TabBarView(children: [_PendientesTab(), _HistorialTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ============================================================ pestaña 1: pendientes
// (flujo actual, sin cambios de comportamiento — solo se agrega "Recibido por")

class _PendientesTab extends ConsumerStatefulWidget {
  const _PendientesTab();

  @override
  ConsumerState<_PendientesTab> createState() => _PendientesTabState();
}

class _PendientesTabState extends ConsumerState<_PendientesTab> {
  final _scanCtrl = TextEditingController();
  final _scanFocus = FocusNode();
  final _scrollController = ScrollController();
  final _cantidadCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();

  /// Ids de línea que se han escaneado/buscado, más reciente primero — así
  /// se arma el orden "la última que pistoleaste sube al tope".
  final List<String> _ordenManual = [];

  String? _lineaAbiertaId;

  /// Cuántas unidades se han pistoleado por línea (sube de a 1 en cada
  /// escaneo, hasta el máximo declarado).
  final Map<String, int> _conteos = {};
  String _ubicacion = WmsConstantes.ubicaciones.first;

  /// Quién de Logística está recibiendo — se mantiene entre tarjetas (lo
  /// normal es que sea la misma persona recibiendo varias seguidas), pero
  /// es obligatorio tener uno seleccionado para poder confirmar cualquiera.
  String? _recibidoPor;

  bool _confirmando = false;
  FeedbackMessage? _msg;

  @override
  void dispose() {
    _scanCtrl.dispose();
    _scanFocus.dispose();
    _scrollController.dispose();
    _cantidadCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  List<_LineaConLote> get _todasPendientes {
    final lotes = ref.read(wmsSnapshotProvider).value?.lotes ?? const <Lote>[];
    final resultado = <_LineaConLote>[];
    for (final l in lotes) {
      for (final li in l.lineas) {
        if (li.enTransito) resultado.add(_LineaConLote(l, li));
      }
    }
    return resultado;
  }

  List<_LineaConLote> _ordenar(List<_LineaConLote> items) {
    final restantes = [...items]..sort((a, b) => a.linea.item.op.compareTo(b.linea.item.op));
    final resultado = <_LineaConLote>[];
    for (final id in _ordenManual) {
      final idx = restantes.indexWhere((e) => e.linea.id == id);
      if (idx != -1) resultado.add(restantes.removeAt(idx));
    }
    resultado.addAll(restantes);
    return resultado;
  }

  void _abrirValidacion(LoteLinea linea) {
    setState(() {
      _lineaAbiertaId = linea.id;
      _cantidadCtrl.text = '${_conteos[linea.id] ?? 0}';
      _notaCtrl.clear();
      _ubicacion = WmsConstantes.ubicaciones.first;
      _msg = null;
    });
  }

  void _subirAlTope(String lineaId) {
    _ordenManual.remove(lineaId);
    _ordenManual.insert(0, lineaId);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _procesarEntrada(String raw) {
    _scanCtrl.clear();
    if (raw.trim().isEmpty) return;
    final todas = _todasPendientes;

    final qr = QrPrenda.tryParse(raw);
    if (qr != null) {
      final encontrada = todas
          .where((e) => e.linea.item.op == qr.op && e.linea.item.codigo == qr.codigo)
          .map((e) => e.linea)
          .firstOrNull;
      if (encontrada == null) {
        setState(() => _msg = const FeedbackMessage.error('No hay ninguna línea pendiente por recibir para esta prenda.'));
        _scanFocus.requestFocus();
        return;
      }

      final actual = _conteos[encontrada.id] ?? 0;
      if (actual >= encontrada.cantidadEnviada) {
        setState(() => _msg = FeedbackMessage.error(
              'LÍMITE ALCANZADO: ya se contaron las ${encontrada.cantidadEnviada} Uds declaradas de esta prenda.',
            ));
        _scanFocus.requestFocus();
        return;
      }

      final mismaLineaYaAbierta = _lineaAbiertaId == encontrada.id;
      setState(() {
        _msg = null;
        _conteos[encontrada.id] = actual + 1;
        _subirAlTope(encontrada.id);
        _lineaAbiertaId = encontrada.id;
        _cantidadCtrl.text = '${_conteos[encontrada.id]}';
        if (!mismaLineaYaAbierta) {
          _notaCtrl.clear();
          _ubicacion = WmsConstantes.ubicaciones.first;
        }
      });
      _scanFocus.requestFocus();
      return;
    }

    // No es un QR: se interpreta como número de OP — sube todas sus líneas.
    final op = raw.trim();
    final coincidencias = todas.where((e) => e.linea.item.op == op).toList();
    if (coincidencias.isEmpty) {
      setState(() => _msg = FeedbackMessage.error('No hay líneas pendientes por recibir para la OP $op.'));
      _scanFocus.requestFocus();
      return;
    }
    setState(() {
      _msg = null;
      for (final c in coincidencias.reversed) {
        _subirAlTope(c.linea.id);
      }
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    _scanFocus.requestFocus();
  }

  Future<void> _confirmar(LoteLinea linea) async {
    final cantidad = int.tryParse(_cantidadCtrl.text.trim());
    if (cantidad == null || cantidad <= 0) {
      setState(() => _msg = const FeedbackMessage.error('Ingresa una cantidad mayor a 0 para confirmar la recepción.'));
      return;
    }
    if (_recibidoPor == null || _recibidoPor!.trim().isEmpty) {
      setState(() => _msg = const FeedbackMessage.error('Selecciona quién de Logística está recibiendo.'));
      return;
    }

    setState(() {
      _confirmando = true;
      _msg = null;
    });
    final res = await ref.read(wmsRepositoryProvider).recibirLoteLinea(
          loteLineaId: linea.id,
          cantidad: cantidad,
          ubicacion: _ubicacion,
          recibidoPor: _recibidoPor!,
          nota: _notaCtrl.text,
        );
    if (!mounted) return;

    switch (res) {
      case Ok(:final value):
        setState(() {
          _confirmando = false;
          if (value.enTransito) {
            // Recepción parcial: la tarjeta se queda en Pendientes.
            _msg = FeedbackMessage.ok(
              '${linea.item.codigo} (${linea.item.talla}): recibidas $cantidad Uds — faltan ${value.cantidadPendiente} Uds.',
            );
            _cantidadCtrl.text = '0';
            _conteos[linea.id] = 0;
          } else {
            _msg = FeedbackMessage.ok(
              '${linea.item.codigo} (${linea.item.talla}): ${value.estado.etiqueta}. Ingresada a $_ubicacion.',
            );
            _lineaAbiertaId = null;
            _ordenManual.remove(linea.id);
            _conteos.remove(linea.id);
          }
        });
      case Err(:final message):
        setState(() {
          _confirmando = false;
          _msg = FeedbackMessage.error(message);
        });
    }
  }

  Future<void> _cerrarConFaltante(LoteLinea linea) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cerrar con faltante?'),
        content: Text(
          'Faltan ${linea.cantidadPendiente} Uds de ${linea.item.descripcion} (${linea.item.talla}) que nunca llegaron. '
          'Al cerrar, esas unidades van a volver a aparecer como pendientes por entregar en Producción. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('CERRAR CON FALTANTE', style: TextStyle(color: AppColors.alertRed)),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    if (!mounted) return;

    setState(() => _confirmando = true);
    final res = await ref.read(wmsRepositoryProvider).cerrarLoteItemConFaltante(
          loteLineaId: linea.id,
          nota: _notaCtrl.text,
        );
    if (!mounted) return;
    setState(() {
      _confirmando = false;
      switch (res) {
        case Ok():
          _msg = FeedbackMessage.ok(
            '${linea.item.codigo} (${linea.item.talla}): cerrada con faltante — vuelve a estar pendiente por entregar en Producción.',
          );
          _lineaAbiertaId = null;
          _ordenManual.remove(linea.id);
          _conteos.remove(linea.id);
        case Err(:final message):
          _msg = FeedbackMessage.error(message);
      }
    });
  }

  Future<void> _reportarSobrante(LoteLinea linea) async {
    final ctrlCantidad = TextEditingController();
    final ctrlNota = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reportar sobrante'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¿Cuántas unidades de más llegaron de ${linea.item.descripcion} (${linea.item.talla})?'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrlCantidad,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: wmsInput('Cantidad de sobra'),
            ),
            const SizedBox(height: 10),
            TextField(controller: ctrlNota, decoration: wmsInput('Nota (opcional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('CANCELAR')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('REGISTRAR')),
        ],
      ),
    );
    if (confirmado != true) return;
    final cantidad = int.tryParse(ctrlCantidad.text.trim());
    if (cantidad == null || cantidad <= 0) {
      if (!mounted) return;
      setState(() => _msg = const FeedbackMessage.error('Ingresa una cantidad de sobrante mayor a 0.'));
      return;
    }
    if (!mounted) return;

    final res = await ref.read(wmsRepositoryProvider).registrarSobrante(
          itemId: linea.item.id,
          loteLineaId: linea.id,
          cantidad: cantidad,
          operario: _recibidoPor ?? '',
          nota: ctrlNota.text,
        );
    if (!mounted) return;
    setState(() {
      switch (res) {
        case Ok():
          _msg = FeedbackMessage.ok(
            '$cantidad Uds de sobrante registradas — revísalas en la Bandeja de Sobrantes.',
          );
        case Err(:final message):
          _msg = FeedbackMessage.error(message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Se observa el snapshot para reconstruir cuando cambian los lotes.
    ref.watch(wmsSnapshotProvider);
    final pendientes = _ordenar(_todasPendientes);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_msg != null) ...[
              FeedbackBanner(message: _msg!),
              const SizedBox(height: 12),
            ],
            AddablePersonDropdown(
              label: 'Recibido por (Logística) *',
              valor: _recibidoPor,
              onChanged: (v) => setState(() => _recibidoPor = v),
              itemsProvider: personalLogisticaProvider,
              onAgregar: (ref, nombre) => ref.read(wmsRepositoryProvider).agregarPersonalLogistica(nombre),
              tituloDialogo: 'Agregar persona de Logística',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _scanCtrl,
              focusNode: _scanFocus,
              autofocus: true,
              decoration: wmsInput('ESCANEAR PRENDA O BUSCAR POR OP', icon: Icons.qr_code_scanner),
              onSubmitted: _procesarEntrada,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: pendientes.isEmpty
                  ? const Center(
                      child: Text('No hay nada pendiente por recibir en este momento.',
                          style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: pendientes.length,
                      itemBuilder: (_, i) {
                        final e = pendientes[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TarjetaLinea(
                            lote: e.lote,
                            linea: e.linea,
                            abierta: e.linea.id == _lineaAbiertaId,
                            onValidar: () => _abrirValidacion(e.linea),
                            onCerrar: () => setState(() => _lineaAbiertaId = null),
                            cantidadCtrl: _cantidadCtrl,
                            notaCtrl: _notaCtrl,
                            ubicacion: _ubicacion,
                            onUbicacion: (v) => setState(() => _ubicacion = v),
                            onConfirmar: () => _confirmar(e.linea),
                            onCerrarConFaltante: () => _cerrarConFaltante(e.linea),
                            onReportarSobrante: () => _reportarSobrante(e.linea),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        if (_confirmando)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LogoLoader(size: 72),
                    SizedBox(height: 16),
                    Text(
                      'Procesando…',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TarjetaLinea extends StatelessWidget {
  const _TarjetaLinea({
    required this.lote,
    required this.linea,
    required this.abierta,
    required this.onValidar,
    required this.onCerrar,
    required this.cantidadCtrl,
    required this.notaCtrl,
    required this.ubicacion,
    required this.onUbicacion,
    required this.onConfirmar,
    required this.onCerrarConFaltante,
    required this.onReportarSobrante,
  });

  final Lote lote;
  final LoteLinea linea;
  final bool abierta;
  final VoidCallback onValidar;
  final VoidCallback onCerrar;
  final TextEditingController cantidadCtrl;
  final TextEditingController notaCtrl;
  final String ubicacion;
  final ValueChanged<String> onUbicacion;
  final VoidCallback onConfirmar;
  final VoidCallback onCerrarConFaltante;
  final VoidCallback onReportarSobrante;

  @override
  Widget build(BuildContext context) {
    final colorBase = linea.esReproceso ? Colors.amber.shade50 : Colors.white;
    return Card(
      color: abierta ? Colors.green.shade50 : colorBase,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: abierta
              ? AppColors.actionGreen
              : linea.esReproceso
                  ? Colors.amber.shade700
                  : Colors.grey.shade300,
          width: abierta ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(
                            'OP: ${linea.item.op} (${linea.item.talla}) - ${linea.item.descripcion}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryNavy),
                          ),
                          if (linea.esReproceso)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade700,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('PRODUCTO REPROCESADO',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      Text(
                        'No. OC: ${linea.item.oc} | ${linea.cantidadEnviada} Uds | '
                        'Lote: ${lote.id} (${lote.operario})',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      if ((linea.cantidadRecibida ?? 0) > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              'Ya recibidas: ${linea.cantidadRecibida} · Faltan: ${linea.cantidadPendiente} Uds',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!abierta)
                  ActionButton(icon: Icons.qr_code, label: 'VALIDAR', color: AppColors.primaryNavy, onPressed: onValidar)
                else
                  IconButton(tooltip: 'Cerrar', icon: const Icon(Icons.close), onPressed: onCerrar),
              ],
            ),
            if (abierta) ...[
              const Divider(),
              if (linea.esReproceso) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    children: [
                      Icon(Icons.autorenew, size: 16, color: Colors.amber.shade900),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Esta prenda era producto no conforme, ya fue reprocesada por Producción.',
                          style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.w600, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: LabeledDropdown<String>(
                      label: 'Estante físico',
                      value: ubicacion,
                      items: WmsConstantes.ubicaciones,
                      onChanged: onUbicacion,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: cantidadCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _MaxValorFormatter(linea.cantidadPendiente),
                      ],
                      decoration: wmsInput('Cant. a recibir ahora (máx ${linea.cantidadPendiente})'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notaCtrl,
                decoration: wmsInput('Nota de novedad para Producción (opcional)', icon: Icons.warning_amber),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: onConfirmar,
                    icon: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                    label: const Text('INGRESAR A ESTANTE & CONFIRMAR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.actionGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onReportarSobrante,
                    icon: const Icon(Icons.add_box_outlined, size: 18),
                    label: const Text('¿Llegó de más? Reportar sobrante'),
                  ),
                  if ((linea.cantidadRecibida ?? 0) > 0)
                    TextButton.icon(
                      onPressed: onCerrarConFaltante,
                      icon: const Icon(Icons.block, size: 18, color: AppColors.alertRed),
                      label: const Text('Cerrar con faltante', style: TextStyle(color: AppColors.alertRed)),
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

/// Impide que el campo acepte un número mayor al máximo permitido.
class _MaxValorFormatter extends TextInputFormatter {
  _MaxValorFormatter(this.maximo);
  final int maximo;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final valor = int.tryParse(newValue.text);
    if (valor == null || valor > maximo) return oldValue;
    return newValue;
  }
}

/// Logo de ORBILOQ girando, usado como loader de pantalla completa.
class _LogoLoader extends StatefulWidget {
  const _LogoLoader({this.size = 20});
  final double size;

  @override
  State<_LogoLoader> createState() => _LogoLoaderState();
}

class _LogoLoaderState extends State<_LogoLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: ClipOval(
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          padding: EdgeInsets.all(widget.size * 0.08),
          child: Image.asset(
            'assets/images/logo_orbiloq.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => SizedBox(
              width: widget.size,
              height: widget.size,
              child: const CircularProgressIndicator(strokeWidth: 3, color: AppColors.tealAccent),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================================================== pestaña 2: historial
// Reutiliza datos que YA están cargados en memoria (WmsSnapshot.lotes trae
// todo, no solo lo pendiente) — no hace ninguna consulta nueva.

class _HistorialTab extends ConsumerWidget {
  const _HistorialTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lotes = ref.watch(wmsSnapshotProvider).value?.lotes ?? const <Lote>[];
    final procesadas = <_LineaConLote>[];
    for (final l in lotes) {
      for (final li in l.lineas) {
        if (!li.enTransito) procesadas.add(_LineaConLote(l, li));
      }
    }
    procesadas.sort((a, b) {
      final fa = a.linea.fechaRecepcion;
      final fb = b.linea.fechaRecepcion;
      if (fa == null || fb == null) return 0;
      return fb.compareTo(fa); // más recientes primero
    });

    if (procesadas.isEmpty) {
      return const Center(
        child: Text('Aún no hay recepciones registradas.', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: procesadas.length,
      itemBuilder: (_, i) {
        final e = procesadas[i];
        final linea = e.linea;
        final conNovedad = linea.estado == EstadoLineaLote.recibidoConNovedad;
        return Card(
          color: conNovedad ? Colors.red.shade50 : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'OP: ${linea.item.op} (${linea.item.talla}) - ${linea.item.descripcion}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryNavy),
                      ),
                    ),
                    StatusChip(label: linea.estado.etiqueta, color: colorDeEstadoLinea(linea.estado)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Lote: ${e.lote.id} | Enviadas: ${linea.cantidadEnviada} Uds | '
                  'Recibidas: ${linea.cantidadRecibida ?? 0} Uds | Estante: ${linea.ubicacionDestino ?? "—"}',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
                Text(
                  'Recibido por: ${linea.recibidoPor.isNotEmpty ? linea.recibidoPor : "Sin registrar (recepción anterior a esta función)"} | '
                  '${linea.fechaRecepcion != null ? formatFechaHora(linea.fechaRecepcion) : "Sin fecha"}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (linea.novedad.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      linea.novedad,
                      style: const TextStyle(fontSize: 12, color: AppColors.alertRed, fontWeight: FontWeight.w600),
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

echo ""
echo "Listo (parte 1/2). Falta la parte 2/2 con la Bandeja de Sobrantes."
echo "flutter analyze va a marcar errores hasta que apliques esa parte 2."
