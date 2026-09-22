#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Aplica los cambios de conexion a Supabase (v2, incluye fix de tests)
# Ejecutar DESDE LA RAIZ del repo (donde esta pubspec.yaml), en Git Bash / VS Code:
#   bash apply_supabase_changes_v2.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi

echo "Aplicando cambios..."
mkdir -p lib/data lib/domain test

echo "  - pubspec.yaml"
mkdir -p "$(dirname 'pubspec.yaml')"
cat > 'pubspec.yaml' << 'ORBILOQ_EOF'
name: orbiloq_wms
description: ORBILOQ WMS - Kardex maestro y control de bodega.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.6.0
  flutter: ">=3.27.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  intl: ^0.20.2
  supabase_flutter: ^2.8.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
ORBILOQ_EOF

echo "  - lib/main.dart"
mkdir -p "$(dirname 'lib/main.dart')"
cat > 'lib/main.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'application/providers.dart';
import 'data/in_memory_wms_repository.dart';
import 'data/supabase_wms_repository.dart';

/// Credenciales de Supabase, pasadas al compilar con:
///   flutter run -d chrome \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=sb_publishable_xxxx
///
/// Si no se pasan (quedan vacías), la app arranca con datos de prueba en
/// memoria — útil para desarrollar la interfaz sin depender de la base real.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final usarSupabase = _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

  if (usarSupabase) {
    await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
  }

  runApp(
    ProviderScope(
      overrides: [
        wmsRepositoryProvider.overrideWith((ref) {
          if (usarSupabase) {
            final repo = SupabaseWmsRepository(Supabase.instance.client);
            ref.onDispose(repo.dispose);
            return repo;
          }
          final repo = InMemoryWmsRepository.seeded();
          ref.onDispose(repo.dispose);
          return repo;
        }),
      ],
      child: const OrbiloqWmsApp(),
    ),
  );
}
ORBILOQ_EOF

echo "  - lib/domain/qr_prenda.dart"
mkdir -p "$(dirname 'lib/domain/qr_prenda.dart')"
cat > 'lib/domain/qr_prenda.dart' << 'ORBILOQ_EOF'
/// Contenido real del QR impreso en la marquilla de cada prenda:
/// `url;OP;Código;Descripción;Cliente;NO.OC;ID`
///
/// - El primer segmento (URL) y el último (ID de etiqueta) se ignoran.
/// - La talla NO viene como campo separado: ya está incluida como texto
///   dentro de "Descripción" (ej. "...N/A T. ESPECIAL"), y no se necesita
///   parsearla porque el Código ya identifica la línea exacta (OP + Código
///   es única dentro del Excel de origen).
/// - Descripción, Cliente y NO. OC se guardan como validación cruzada:
///   si no coinciden con lo que hay en la base de datos para esa OP+Código,
///   la pantalla puede advertir una inconsistencia sin bloquear el escaneo.
class QrPrenda {
  const QrPrenda({
    required this.op,
    required this.codigo,
    required this.descripcion,
    required this.cliente,
    required this.noOc,
  });

  final String op;
  final String codigo;
  final String descripcion;
  final String cliente;
  final String noOc;

  static const formato = 'url;OP;Código;Descripción;Cliente;NO.OC;ID';

  /// Devuelve `null` si el QR no cumple el formato mínimo esperado.
  static QrPrenda? tryParse(String raw) {
    final p = raw.split(';').map((e) => e.trim()).toList();
    // Se requieren al menos: url, OP, Código, Descripción, Cliente, NO.OC (6).
    // El ID final de la etiqueta (posición 6) es opcional / se ignora si viene.
    if (p.length < 6) return null;
    final op = p[1];
    final codigo = p[2];
    if (op.isEmpty || codigo.isEmpty) return null;
    return QrPrenda(
      op: op,
      codigo: codigo,
      descripcion: p.length > 3 ? p[3] : '',
      cliente: p.length > 4 ? p[4] : '',
      noOc: p.length > 5 ? p[5] : '',
    );
  }
}
ORBILOQ_EOF

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
  });

  final ItemOrden item;
  final int producido;
  final int recibido;
  final int despachado;

  /// Stock por ubicación (solo cantidades > 0).
  final Map<String, int> ubicaciones;
  final DateTime? fechaEntrega;
  final DateTime? fechaRecepcion;

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

  Future<WmsSnapshot> _cargarSnapshot() async {
    final kardexRows = await _client
        .from('vista_kardex')
        .select()
        .order('numero_op')
        .order('codigo');

    final stockRows = await _client.from('vista_stock_ubicacion_detalle').select();

    final remisionesRows = await _client
        .from('vista_remisiones')
        .select()
        .order('fecha_envio', ascending: false);

    final stockPorItem = <String, Map<String, int>>{};
    for (final row in stockRows as List) {
      final fila = row as Map<String, dynamic>;
      final itemId = fila['item_orden_id'] as String;
      final ubicacion = fila['ubicacion_codigo'] as String;
      final cantidad = (fila['cantidad'] as num).toInt();
      stockPorItem.putIfAbsent(itemId, () => {})[ubicacion] = cantidad;
    }

    final kardex = [
      for (final row in kardexRows as List)
        _kardexDesdeFila(row as Map<String, dynamic>, stockPorItem),
    ];

    final remisiones = [
      for (final row in remisionesRows as List) _remisionDesdeFila(row as Map<String, dynamic>),
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

echo "  - lib/features/produccion/presentation/entrega_produccion_dialog.dart"
mkdir -p "$(dirname 'lib/features/produccion/presentation/entrega_produccion_dialog.dart')"
cat > 'lib/features/produccion/presentation/entrega_produccion_dialog.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/constants.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/fecha.dart';
import '../../../domain/qr_prenda.dart';
import '../../../shared/widgets/action_button.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/labeled_dropdown.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showEntregaProduccionDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const EntregaProduccionDialog());

class EntregaProduccionDialog extends StatelessWidget {
  const EntregaProduccionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return WmsDialogShell(
      title: 'PRODUCCIÓN: ENTREGA CON LÍMITES E HISTORIAL',
      icon: Icons.precision_manufacturing,
      iconColor: AppColors.actionGreen,
      expand: true,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              labelColor: AppColors.primaryNavy,
              indicatorColor: AppColors.primaryNavy,
              tabs: [
                Tab(icon: Icon(Icons.add_box), text: 'NUEVA ENTREGA CON LÍMITES'),
                Tab(icon: Icon(Icons.history), text: 'HISTORIAL DE REMISIONES'),
              ],
            ),
            const SizedBox(height: 10),
            const Expanded(
              child: TabBarView(children: [_NuevaEntregaTab(), _HistorialTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

class _NuevaEntregaTab extends ConsumerStatefulWidget {
  const _NuevaEntregaTab();

  @override
  ConsumerState<_NuevaEntregaTab> createState() => _NuevaEntregaTabState();
}

class _NuevaEntregaTabState extends ConsumerState<_NuevaEntregaTab>
    with AutomaticKeepAliveClientMixin {
  final _remisionCtrl = TextEditingController();
  final _qrCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController(text: '1');
  final _qrFocus = FocusNode();

  String _operario = WmsConstantes.operarios.first;
  String? _itemId;
  int _conteo = 0;
  FeedbackMessage? _msg;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _remisionCtrl.dispose();
    _qrCtrl.dispose();
    _cantidadCtrl.dispose();
    _qrFocus.dispose();
    super.dispose();
  }

  void _error(String texto) {
    setState(() => _msg = FeedbackMessage.error(texto));
    _qrFocus.requestFocus();
  }

  void _procesarQR(String raw) {
    _qrCtrl.clear();
    if (raw.trim().isEmpty) return;

    final qr = QrPrenda.tryParse(raw);
    if (qr == null) {
      _error('QR inválido. Formato esperado: ${QrPrenda.formato}');
      return;
    }
    final kardex = ref.read(wmsSnapshotProvider).value?.kardexPorOpCodigo(qr.op, qr.codigo);
    if (kardex == null) {
      _error('La prenda no existe en el kardex (OP ${qr.op} · Código ${qr.codigo}).');
      return;
    }

    // Al cambiar de producto el conteo se reinicia.
    final base = _itemId == kardex.id ? _conteo : 0;
    if (base >= kardex.pendienteProduccion) {
      _error('LÍMITE ALCANZADO: esta OP ya cumplió la cantidad pedida (${kardex.pendienteProduccion} Uds por entregar).');
      return;
    }

    setState(() {
      _itemId = kardex.id;
      _conteo = base + 1;
      _cantidadCtrl.text = '$_conteo';
      _msg = null;
    });
    _qrFocus.requestFocus();
  }

  void _reiniciarConteo() {
    setState(() {
      _conteo = 0;
      _cantidadCtrl.text = '1';
    });
    _qrFocus.requestFocus();
  }

  Future<void> _confirmar() async {
    final itemId = _itemId;
    if (itemId == null) return;
    final cantidad = int.tryParse(_cantidadCtrl.text.trim()) ?? 0;

    final res = await ref.read(wmsRepositoryProvider).entregarLote(
          itemId: itemId,
          cantidad: cantidad,
          operario: _operario,
          numeroRemision: _remisionCtrl.text,
        );
    if (!mounted) return;

    switch (res) {
      case Ok(:final value):
        setState(() {
          _msg = FeedbackMessage.ok('Remisión ${value.id} de ${value.cantidadEnviada} Uds despachada a bodega.');
          _itemId = null;
          _conteo = 0;
          _remisionCtrl.clear();
          _cantidadCtrl.text = '1';
        });
      case Err(:final message):
        setState(() => _msg = FeedbackMessage.error(message));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final snapshot = ref.watch(wmsSnapshotProvider).value;
    final k = _itemId == null ? null : snapshot?.kardexPorId(_itemId!);
    final proxima = snapshot?.proximaRemision;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msg != null) ...[
            FeedbackBanner(message: _msg!),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _remisionCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: wmsInput(
                    'N° Remisión / Lote',
                    hint: (proxima == null || proxima == 'Automático')
                        ? 'Automático'
                        : 'Automático ($proxima)',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LabeledDropdown<String>(
                  label: 'Operario de Producción',
                  value: _operario,
                  items: WmsConstantes.operarios,
                  onChanged: (v) => setState(() => _operario = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qrCtrl,
            focusNode: _qrFocus,
            autofocus: true,
            decoration: wmsInput('PISTOLEE O ESCANEE QR DE PRENDA A ENTREGAR', icon: Icons.qr_code_scanner),
            onSubmitted: _procesarQR,
          ),
          const SizedBox(height: 12),
          if (k != null)
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${k.item.codigo} - ${k.item.descripcion} (${k.item.talla})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy),
                              ),
                              Text('OP: ${k.item.op} | OC: ${k.item.oc} | Cliente: ${k.item.cliente}'),
                            ],
                          ),
                        ),
                        ActionButton(
                          icon: Icons.refresh,
                          label: 'RECONTEAR',
                          color: Colors.amber.shade900,
                          onPressed: _reiniciarConteo,
                        ),
                      ],
                    ),
                    const Divider(),
                    MetricWrap(children: [
                      MetricCard(title: 'META OP', value: '${k.cantidadPedida} Uds', color: Colors.blueGrey, icon: Icons.flag),
                      MetricCard(title: 'ENTREGADAS', value: '${k.producido} Uds', color: AppColors.actionGreen, icon: Icons.check_circle),
                      MetricCard(
                        title: 'LÍMITE MÁXIMO',
                        value: '${k.pendienteProduccion} Uds',
                        color: k.pendienteProduccion > 0 ? AppColors.alertRed : Colors.grey,
                        icon: Icons.lock_clock,
                      ),
                      MetricCard(
                        title: 'AVANCE',
                        value: '${((k.producido / k.cantidadPedida).clamp(0.0, 1.0) * 100).toStringAsFixed(1)}%',
                        color: AppColors.accentCyan,
                        icon: Icons.donut_large,
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cantidadCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: wmsInput('Cantidad a enviar (máx ${k.pendienteProduccion} Uds)'),
                            onSubmitted: (_) => _confirmar(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ActionButton(
                          icon: Icons.local_shipping,
                          label: 'DESPACHAR A BODEGA',
                          color: AppColors.actionGreen,
                          onPressed: _confirmar,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistorialTab extends ConsumerWidget {
  const _HistorialTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remisiones = ref.watch(wmsSnapshotProvider).value?.remisiones ?? const [];
    if (remisiones.isEmpty) {
      return const Center(child: Text('Aún no hay remisiones.', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      itemCount: remisiones.length,
      itemBuilder: (_, i) {
        final r = remisiones[i];
        return Card(
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryNavy,
              child: Text('#${remisiones.length - i}', style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
            title: Text(
              '${r.id} — OP: ${r.item.op} | ${r.item.codigo} (${r.item.talla})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Enviadas: ${r.cantidadEnviada} Uds | Fecha: ${formatFechaHora(r.fechaEnvio)}'
                    '${r.cantidadRecibida != null ? ' | Recibidas: ${r.cantidadRecibida}' : ''}'),
                if (r.novedad.isNotEmpty)
                  Text('Novedad: ${r.novedad}', style: const TextStyle(color: AppColors.alertRed, fontWeight: FontWeight.bold)),
              ],
            ),
            trailing: StatusChip(label: r.estado.etiqueta, color: colorDeEstadoRemision(r.estado)),
          ),
        );
      },
    );
  }
}
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
import '../../../domain/models.dart';
import '../../../domain/qr_prenda.dart';
import '../../../shared/widgets/action_button.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/labeled_dropdown.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showRecepcionDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const RecepcionDialog());

class RecepcionDialog extends ConsumerStatefulWidget {
  const RecepcionDialog({super.key});

  @override
  ConsumerState<RecepcionDialog> createState() => _RecepcionDialogState();
}

class _RecepcionDialogState extends ConsumerState<RecepcionDialog> {
  final _scanRemisionCtrl = TextEditingController();
  final _scanPrendaCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  final _scanPrendaFocus = FocusNode();

  String? _remisionId;
  String _ubicacion = WmsConstantes.ubicaciones.first;
  int _conteo = 0;
  FeedbackMessage? _msg;

  @override
  void dispose() {
    _scanRemisionCtrl.dispose();
    _scanPrendaCtrl.dispose();
    _cantidadCtrl.dispose();
    _notaCtrl.dispose();
    _scanPrendaFocus.dispose();
    super.dispose();
  }

  List<Remision> get _enTransito =>
      (ref.read(wmsSnapshotProvider).value?.remisiones ?? const <Remision>[]).where((r) => r.enTransito).toList();

  void _seleccionar(Remision r) {
    setState(() {
      _remisionId = r.id;
      _cantidadCtrl.text = '${r.cantidadEnviada}';
      _conteo = 0;
      _notaCtrl.clear();
      _msg = null;
    });
  }

  void _procesarScanRemision(String raw) {
    final query = raw.trim().toUpperCase();
    _scanRemisionCtrl.clear();
    if (query.isEmpty) return;
    final coincidencias = _enTransito.where((r) => r.id.toUpperCase() == query || r.item.op == query);
    if (coincidencias.isEmpty) {
      setState(() => _msg = const FeedbackMessage.error('Lote no encontrado en tránsito.'));
      return;
    }
    _seleccionar(coincidencias.first);
  }

  void _procesarScanPrenda(String raw, Remision remision) {
    _scanPrendaCtrl.clear();
    if (raw.trim().isEmpty) return;
    final qr = QrPrenda.tryParse(raw);
    if (qr == null) {
      setState(() => _msg = FeedbackMessage.error('QR inválido. Formato esperado: ${QrPrenda.formato}'));
    } else if (qr.op != remision.item.op || qr.codigo != remision.item.codigo) {
      setState(() => _msg = const FeedbackMessage.error('La prenda NO corresponde a esta remisión.'));
    } else {
      setState(() {
        _conteo++;
        _cantidadCtrl.text = '$_conteo';
        _msg = null;
      });
    }
    _scanPrendaFocus.requestFocus();
  }

  Future<void> _confirmar(Remision remision) async {
    final cantidad = int.tryParse(_cantidadCtrl.text.trim());
    if (cantidad == null) {
      setState(() => _msg = const FeedbackMessage.error('Ingresa una cantidad válida.'));
      return;
    }

    final res = await ref.read(wmsRepositoryProvider).recibirLote(
          remisionId: remision.id,
          cantidad: cantidad,
          ubicacion: _ubicacion,
          nota: _notaCtrl.text,
        );
    if (!mounted) return;

    switch (res) {
      case Ok(:final value):
        setState(() {
          _msg = FeedbackMessage.ok('${value.id}: ${value.estado.etiqueta}. Ingresada a $_ubicacion.');
          _remisionId = null;
          _conteo = 0;
        });
      case Err(:final message):
        setState(() => _msg = FeedbackMessage.error(message));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se observa el snapshot para reconstruir cuando cambian las remisiones.
    ref.watch(wmsSnapshotProvider);
    final enTransito = _enTransito;
    final seleccionada = enTransito.where((r) => r.id == _remisionId).firstOrNull;

    return WmsDialogShell(
      title: 'RECEPCIÓN DE LOTES Y REPORTE DE NOVEDADES',
      icon: Icons.move_to_inbox,
      iconColor: AppColors.primaryNavy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msg != null) ...[
            FeedbackBanner(message: _msg!),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _scanRemisionCtrl,
            autofocus: true,
            decoration: wmsInput('ESCANEAR REMISIÓN O BUSCAR OP (Ej. REM-101)', icon: Icons.qr_code_scanner),
            onSubmitted: _procesarScanRemision,
          ),
          const SizedBox(height: 12),
          if (enTransito.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('No hay transferencias pendientes.', style: TextStyle(color: Colors.grey))),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: enTransito.length,
                itemBuilder: (_, i) {
                  final r = enTransito[i];
                  final sel = r.id == _remisionId;
                  return Card(
                    color: sel ? Colors.blue.shade50 : Colors.white,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: sel ? AppColors.primaryNavy : Colors.grey.shade300, width: sel ? 2 : 1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        '${r.id} — ${r.item.codigo} (${r.item.talla}) - ${r.item.descripcion}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('OP: ${r.item.op} | OC: ${r.item.oc} | Envía: ${r.operario} | ${r.cantidadEnviada} Uds'),
                      trailing: ActionButton(
                        icon: Icons.qr_code,
                        label: 'VALIDAR',
                        color: AppColors.primaryNavy,
                        onPressed: () => _seleccionar(r),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (seleccionada != null) ...[
            const SizedBox(height: 12),
            _Validacion(
              remision: seleccionada,
              scanCtrl: _scanPrendaCtrl,
              scanFocus: _scanPrendaFocus,
              cantidadCtrl: _cantidadCtrl,
              notaCtrl: _notaCtrl,
              ubicacion: _ubicacion,
              onUbicacion: (v) => setState(() => _ubicacion = v),
              onScan: (raw) => _procesarScanPrenda(raw, seleccionada),
              onConfirmar: () => _confirmar(seleccionada),
            ),
          ],
        ],
      ),
    );
  }
}

class _Validacion extends StatelessWidget {
  const _Validacion({
    required this.remision,
    required this.scanCtrl,
    required this.scanFocus,
    required this.cantidadCtrl,
    required this.notaCtrl,
    required this.ubicacion,
    required this.onUbicacion,
    required this.onScan,
    required this.onConfirmar,
  });

  final Remision remision;
  final TextEditingController scanCtrl;
  final FocusNode scanFocus;
  final TextEditingController cantidadCtrl;
  final TextEditingController notaCtrl;
  final String ubicacion;
  final ValueChanged<String> onUbicacion;
  final ValueChanged<String> onScan;
  final VoidCallback onConfirmar;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'VALIDACIÓN: ${remision.id} (Declarado: ${remision.cantidadEnviada} Uds)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy),
            ),
            const Divider(),
            TextField(
              controller: scanCtrl,
              focusNode: scanFocus,
              decoration: wmsInput('PISTOLEADO 1 A 1 PARA RECONTEO (SUBE CONTADOR)', icon: Icons.flash_on),
              onSubmitted: onScan,
            ),
            const SizedBox(height: 10),
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: wmsInput('Cant. validada'),
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
            Align(
              alignment: Alignment.centerLeft,
              child: ActionButton(
                icon: Icons.check_circle,
                label: 'INGRESAR A ESTANTE & CONFIRMAR',
                color: AppColors.actionGreen,
                onPressed: onConfirmar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
ORBILOQ_EOF

echo "  - lib/features/despacho/presentation/despacho_dialog.dart"
mkdir -p "$(dirname 'lib/features/despacho/presentation/despacho_dialog.dart')"
cat > 'lib/features/despacho/presentation/despacho_dialog.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import '../../../domain/qr_prenda.dart';
import '../../../shared/widgets/action_button.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/labeled_dropdown.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showDespachoDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const DespachoDialog());

class DespachoDialog extends ConsumerStatefulWidget {
  const DespachoDialog({super.key});

  @override
  ConsumerState<DespachoDialog> createState() => _DespachoDialogState();
}

class _DespachoDialogState extends ConsumerState<DespachoDialog> {
  final _qrCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController(text: '1');
  final _qrFocus = FocusNode();

  String? _itemId;
  String? _ubicacion;
  FeedbackMessage? _msg;

  @override
  void dispose() {
    _qrCtrl.dispose();
    _cantidadCtrl.dispose();
    _qrFocus.dispose();
    super.dispose();
  }

  void _error(String texto) {
    setState(() => _msg = FeedbackMessage.error(texto));
    _qrFocus.requestFocus();
  }

  void _procesarQR(String raw) {
    _qrCtrl.clear();
    if (raw.trim().isEmpty) return;

    final qr = QrPrenda.tryParse(raw);
    if (qr == null) {
      _error('QR inválido. Formato esperado: ${QrPrenda.formato}');
      return;
    }
    final k = ref.read(wmsSnapshotProvider).value?.kardexPorOpCodigo(qr.op, qr.codigo);
    if (k == null) {
      _error('La prenda no está registrada en el kardex.');
      return;
    }
    if (k.stockDisponible <= 0 || k.ubicaciones.isEmpty) {
      _error('La prenda no tiene stock disponible en bodega.');
      return;
    }
    setState(() {
      _itemId = k.id;
      _ubicacion = k.ubicaciones.keys.first;
      _cantidadCtrl.text = '1';
      _msg = null;
    });
  }

  /// Ubicación efectiva: la elegida si aún tiene stock; si no, la primera con stock.
  String? _ubicacionEfectiva(ItemKardex? k) {
    final opciones = k?.ubicaciones.keys.toList() ?? const <String>[];
    if (opciones.isEmpty) return null;
    return opciones.contains(_ubicacion) ? _ubicacion : opciones.first;
  }

  Future<void> _confirmar() async {
    final itemId = _itemId;
    if (itemId == null) return;
    final ubicacion = _ubicacionEfectiva(ref.read(wmsSnapshotProvider).value?.kardexPorId(itemId));
    if (ubicacion == null) return;
    final cantidad = int.tryParse(_cantidadCtrl.text.trim()) ?? 0;

    final res = await ref.read(wmsRepositoryProvider).despachar(
          itemId: itemId,
          cantidad: cantidad,
          ubicacion: ubicacion,
        );
    if (!mounted) return;

    switch (res) {
      case Ok():
        setState(() {
          _msg = FeedbackMessage.ok('Despacho de $cantidad Uds desde $ubicacion registrado.');
          _itemId = null;
          _ubicacion = null;
          _cantidadCtrl.text = '1';
        });
        _qrFocus.requestFocus();
      case Err(:final message):
        setState(() => _msg = FeedbackMessage.error(message));
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(wmsSnapshotProvider).value;
    final k = _itemId == null ? null : snapshot?.kardexPorId(_itemId!);
    final opciones = k?.ubicaciones.keys.toList() ?? const <String>[];
    final ubicacion = _ubicacionEfectiva(k);

    return WmsDialogShell(
      title: 'LOGÍSTICA: PICKING Y DESPACHO A CLIENTE',
      icon: Icons.local_shipping,
      iconColor: AppColors.actionOrange,
      maxWidth: 800,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msg != null) ...[
            FeedbackBanner(message: _msg!),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _qrCtrl,
            focusNode: _qrFocus,
            autofocus: true,
            decoration: wmsInput('ESCANEAR QR DE PRENDA A DESPACHAR', icon: Icons.qr_code_scanner),
            onSubmitted: _procesarQR,
          ),
          const SizedBox(height: 12),
          if (k != null)
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${k.item.codigo} - ${k.item.descripcion} (${k.item.talla})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text('OP: ${k.item.op} | OC: ${k.item.oc} | Cliente: ${k.item.cliente}'),
                    Text(
                      'Pendiente por despachar según la orden: ${k.pendienteDespacho} Uds',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.actionOrange),
                    ),
                    const Divider(),
                    if (ubicacion == null)
                      const Text('Sin stock disponible en ninguna ubicación.')
                    else
                      Row(
                        children: [
                          Expanded(
                            child: LabeledDropdown<String>(
                              label: 'Retirar del estante',
                              value: ubicacion,
                              items: opciones,
                              itemLabel: (u) => '$u (Disp: ${k.stockEn(u)})',
                              onChanged: (v) => setState(() => _ubicacion = v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: _cantidadCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: wmsInput('Cant.'),
                              onSubmitted: (_) => _confirmar(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ActionButton(
                            icon: Icons.upload,
                            label: 'DESPACHAR',
                            color: AppColors.actionOrange,
                            onPressed: _confirmar,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
ORBILOQ_EOF

echo "  - test/wms_rules_test.dart"
mkdir -p "$(dirname 'test/wms_rules_test.dart')"
cat > 'test/wms_rules_test.dart' << 'ORBILOQ_EOF'
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/result.dart';
import '../lib/data/in_memory_wms_repository.dart';
import '../lib/domain/models.dart';
import '../lib/domain/qr_prenda.dart';

const _xs = '19249|ORD-001-ENE|2025289514|XS'; // pedida 9, producido 9 (límite alcanzado)
const _s = '19249|ORD-001-ENE|2025289515|S'; // pedida 264, producido 100, stock A1 = 30

void main() {
  group('QrPrenda', () {
    test('parsea un QR válido con el formato real de la marquilla', () {
      final qr = QrPrenda.tryParse(
        'https://orbiloq.app/qr?;19249;2025289514;TSHIRT MANGA CORTA T. XS;ENEL;ORD-001-ENE;ID0001',
      );
      expect(qr, isNotNull);
      expect(qr!.op, '19249');
      expect(qr.codigo, '2025289514');
      expect(qr.cliente, 'ENEL');
      expect(qr.noOc, 'ORD-001-ENE');
    });

    test('rechaza QR incompleto o con OP/Código vacíos', () {
      expect(QrPrenda.tryParse('url;ENEL'), isNull);
      expect(QrPrenda.tryParse('url;;2025289514;TSHIRT;ENEL;ORD-001-ENE'), isNull);
    });
  });

  group('Reglas de negocio', () {
    late InMemoryWmsRepository repo;

    setUp(() => repo = InMemoryWmsRepository.seeded());
    tearDown(() => repo.dispose());

    Future<ItemKardex> kardex(String id) async =>
        (await repo.watch().first).kardexPorId(id)!;

    test('producción no puede superar la cantidad pedida', () async {
      expect(await repo.entregarLote(itemId: _xs, cantidad: 1, operario: 'X'), isA<Err>());
      expect(await repo.entregarLote(itemId: _s, cantidad: 165, operario: 'X'), isA<Err>());
      expect(await repo.entregarLote(itemId: _s, cantidad: 164, operario: 'X'), isA<Ok>());
    });

    test('no se entrega un producto inexistente ni cantidades <= 0', () async {
      expect(await repo.entregarLote(itemId: 'nope', cantidad: 1, operario: 'X'), isA<Err>());
      expect(await repo.entregarLote(itemId: _s, cantidad: 0, operario: 'X'), isA<Err>());
    });

    test('no permite remisiones duplicadas', () async {
      final r = await repo.entregarLote(itemId: _s, cantidad: 1, operario: 'X', numeroRemision: 'REM-097');
      expect(r, isA<Err>());
    });

    test('la numeración automática no colisiona', () async {
      final a = await repo.entregarLote(itemId: _s, cantidad: 1, operario: 'X');
      final b = await repo.entregarLote(itemId: _s, cantidad: 1, operario: 'X');
      expect((a as Ok<Remision>).value.id, isNot((b as Ok<Remision>).value.id));
    });

    test('la recepción con faltante genera novedad y actualiza el stock', () async {
      final res = await repo.recibirLote(remisionId: 'REM-101', cantidad: 3, ubicacion: 'RACK C3');
      final remision = (res as Ok<Remision>).value;
      expect(remision.estado, EstadoRemision.recibidoConNovedad);
      expect(remision.novedad, contains('FALTANTE'));

      final k = await kardex(_xs);
      expect(k.recibido, 8);
      expect(k.stockEn('RACK C3'), 3);
    });

    test('una remisión no se puede recibir dos veces', () async {
      await repo.recibirLote(remisionId: 'REM-101', cantidad: 4, ubicacion: 'RACK C3');
      final again = await repo.recibirLote(remisionId: 'REM-101', cantidad: 4, ubicacion: 'RACK C3');
      expect(again, isA<Err>());
    });

    test('el despacho valida el stock de la ubicación', () async {
      expect(await repo.despachar(itemId: _s, cantidad: 31, ubicacion: 'ESTANTE A1'), isA<Err>());
      expect(await repo.despachar(itemId: _s, cantidad: 1, ubicacion: 'RACK C3'), isA<Err>());
      expect(await repo.despachar(itemId: _s, cantidad: 30, ubicacion: 'ESTANTE A1'), isA<Ok>());

      final k = await kardex(_s);
      expect(k.despachado, 50);
      expect(k.stockDisponible, 0);
      expect(k.ubicaciones.containsKey('ESTANTE A1'), isFalse);
    });

    test('stockDisponible siempre coincide con la suma de ubicaciones', () async {
      final snap = await repo.watch().first;
      for (final k in snap.kardex) {
        expect(k.ubicaciones.values.fold<int>(0, (a, b) => a + b), k.stockDisponible);
      }
    });
  });
}
ORBILOQ_EOF

if [ -f "test/widget_test.dart" ]; then
  echo "  - eliminando test/widget_test.dart (plantilla de Flutter, no se usa en este proyecto)"
  rm -f test/widget_test.dart
fi

echo ""
echo "Listo. Archivos actualizados:"
echo "  pubspec.yaml"
echo "  lib/main.dart"
echo "  lib/domain/qr_prenda.dart"
echo "  lib/domain/models.dart"
echo "  lib/data/in_memory_wms_repository.dart"
echo "  lib/data/supabase_wms_repository.dart"
echo "  lib/features/produccion/presentation/entrega_produccion_dialog.dart"
echo "  lib/features/recepcion/presentation/recepcion_dialog.dart"
echo "  lib/features/despacho/presentation/despacho_dialog.dart"
echo "  test/wms_rules_test.dart"
echo "  (test/widget_test.dart eliminado si existia)"
echo ""
echo "Siguiente paso:"
echo "  flutter pub get"
echo "  flutter test"
echo "  git status"
