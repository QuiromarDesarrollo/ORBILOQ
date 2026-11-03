import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../application/auth_providers.dart';
import '../../core/masiva_entorno.dart';
import 'masiva_pendiente.dart';

typedef MasivaJson = Map<String, dynamic>;

MasivaJson mapaMasiva(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<MasivaJson> filasMasiva(dynamic value) =>
    value is List ? value.map(mapaMasiva).toList() : <MasivaJson>[];
int numeroMasiva(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

final masivaRepositoryProvider = Provider<MasivaRepository>((ref) {
  final conectado = ref.watch(usarSupabaseProvider);
  return MasivaRepository(
    conectado && masivaHabilitada() ? Supabase.instance.client : null,
  );
});

/// El servidor es la autoridad del inventario; nunca se descuenta en memoria.
/// Las escrituras no se reintentan automáticamente tras una pérdida de red.
class MasivaRepository {
  MasivaRepository(this.client);
  final SupabaseClient? client;
  bool get conectado => client != null;
  String get _usuario => client?.auth.currentUser?.id ?? 'local';
  MasivaJson? get movimientoPendiente {
    final raw = leerPendienteMasiva(_usuario);
    return raw == null ? null : mapaMasiva(jsonDecode(raw));
  }

  static String requestId() {
    final rng = Random.secure();
    final b = List<int>.generate(16, (_) => rng.nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final s = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  Future<MasivaJson> consultar({
    String? operacion,
    String vista = 'resumen',
    String buscar = '',
    String lista = '',
    int pagina = 1,
  }) async {
    if (client == null) {
      return {'operaciones': <dynamic>[], 'filas': <dynamic>[]};
    }
    return mapaMasiva(
      await client!
          .rpc(
            'masiva_consultar',
            params: {
              'p_operacion': operacion,
              'p_vista': vista,
              'p_buscar': buscar,
              'p_lista': lista,
              'p_pagina': pagina,
            },
          )
          .timeout(const Duration(seconds: 30)),
    );
  }

  Future<MasivaJson> ejecutar(String accion, MasivaJson datos) async {
    if (client == null) {
      throw const MasivaError(
        'Conecta ORBILOQ al entorno DEV para guardar una operación.',
      );
    }
    if (movimientoPendiente != null) {
      throw const MasivaError(
        'Recupera la confirmación del movimiento pendiente antes de registrar otro.',
      );
    }
    return _enviar(accion, datos);
  }

  Future<MasivaJson> consultarRecepcion({
    required String operacion,
    String buscar = '',
    Map<String, Set<String>> filtros = const {},
    int pagina = 1,
    String? proveedor,
    String? pedido,
  }) async {
    if (client == null) {
      return {'filas': <dynamic>[], 'total': 0, 'opciones': {}};
    }
    return mapaMasiva(
      await client!
          .rpc(
            'masiva_recepcion_consultar',
            params: {
              'p_operacion': operacion,
              'p_buscar': buscar,
              'p_filtros': {
                for (final e in filtros.entries)
                  if (e.value.isNotEmpty) e.key: e.value.toList(),
              },
              'p_pagina': pagina,
              'p_proveedor': proveedor,
              'p_pedido': pedido,
            },
          )
          .timeout(const Duration(seconds: 30)),
    );
  }

  Future<MasivaJson> consultarPuesto(String operacion) async {
    if (client == null) return {'pedidos': []};
    return mapaMasiva(
      await client!
          .rpc('masiva_recepcion_puesto', params: {'p_operacion': operacion})
          .timeout(const Duration(seconds: 30)),
    );
  }

  Future<MasivaJson> consultarHistorialRecepcion({
    required String operacion,
    String buscar = '',
    int pagina = 1,
  }) async {
    if (client == null) return {'filas': <dynamic>[], 'total': 0};
    return mapaMasiva(
      await client!
          .rpc(
            'masiva_recepcion_historial',
            params: {
              'p_operacion': operacion,
              'p_buscar': buscar,
              'p_pagina': pagina,
            },
          )
          .timeout(const Duration(seconds: 30)),
    );
  }

  Future<MasivaJson> consultarConciliacion({
    required String operacion,
    String buscar = '',
    String estado = '',
    int pagina = 1,
  }) async {
    if (client == null) return {'filas': [], 'total': 0, 'metricas': {}};
    return mapaMasiva(
      await client!
          .rpc(
            'masiva_conciliacion_consultar',
            params: {
              'p_operacion': operacion,
              'p_buscar': buscar,
              'p_estado': estado,
              'p_pagina': pagina,
            },
          )
          .timeout(const Duration(seconds: 30)),
    );
  }

  Future<MasivaJson> consultarMaestro({
    required String operacion,
    required String vista,
    String buscar = '',
    Map<String, Set<String>> filtros = const {},
    int pagina = 1,
    int tamano = 30,
    String fechaTipo = 'fecha_carga',
    String? desde,
    String? hasta,
    bool incluirOpciones = true,
  }) async {
    if (client == null) return {'filas': [], 'total': 0, 'opciones': {}};
    return mapaMasiva(
      await client!
          .rpc(
            'masiva_maestro_consultar',
            params: {
              'p_operacion': operacion,
              'p_vista': vista,
              'p_buscar': buscar,
              'p_filtros': {
                for (final e in filtros.entries)
                  if (e.value.isNotEmpty) e.key: e.value.toList(),
              },
              'p_pagina': pagina,
              'p_tamano': tamano,
              'p_fecha_tipo': fechaTipo,
              'p_desde': desde,
              'p_hasta': hasta,
              'p_incluir_opciones': incluirOpciones,
            },
          )
          .timeout(const Duration(seconds: 45)),
    );
  }

  Future<MasivaJson> recuperarConfirmacion() async {
    final pendiente = movimientoPendiente;
    if (pendiente == null) return {};
    return _enviar('${pendiente['accion']}', mapaMasiva(pendiente['datos']));
  }

  Future<MasivaJson> _enviar(String accion, MasivaJson datos) async {
    final usuario = _usuario;
    final protegido = datos['request_id'] != null;
    if (protegido) {
      guardarPendienteMasiva(
        usuario,
        jsonEncode({'accion': accion, 'datos': datos}),
      );
    }
    try {
      final result = mapaMasiva(
        await client!
            .rpc(
              'masiva_ejecutar',
              params: {'p_accion': accion, 'p_datos': datos},
            )
            .timeout(const Duration(seconds: 60)),
      );
      if (protegido) guardarPendienteMasiva(usuario, null);
      return result;
    } on PostgrestException catch (e) {
      // Una excepción de negocio PostgreSQL revierte la transacción completa.
      // Un error de red conserva el request_id para recuperar la respuesta.
      if (protegido &&
          RegExp(r'^(P0001|22|23|42501|PGRST301)').hasMatch(e.code ?? '')) {
        guardarPendienteMasiva(usuario, null);
      }
      rethrow;
    }
  }

  Future<void> importar({
    required String operacion,
    required String tipo,
    required String archivo,
    required List<MasivaJson> filas,
    required void Function(double) progreso,
  }) async {
    if (filas.isEmpty) {
      throw const MasivaError('El archivo no contiene filas válidas.');
    }
    const tamano = 500;
    final lotes = (filas.length / tamano).ceil();
    final inicio = await ejecutar('iniciar_importacion', {
      'operacion_id': operacion,
      'tipo': tipo,
      'archivo': archivo,
      'total_filas': filas.length,
      'total_lotes': lotes,
    });
    final id = inicio['importacion_id'];
    if (id == null) {
      throw const MasivaError('No se pudo iniciar la importación.');
    }
    for (var i = 0; i < lotes; i++) {
      await ejecutar('cargar_lote', {
        'importacion_id': id,
        'indice': i,
        'filas': filas.sublist(i * tamano, min((i + 1) * tamano, filas.length)),
      });
      progreso((i + 1) / (lotes + 1));
    }
    // Solo esta llamada publica los datos. Un envío incompleto no crea stock/kits.
    await ejecutar('confirmar_importacion', {'importacion_id': id});
    progreso(1);
  }
}

class MasivaError implements Exception {
  const MasivaError(this.message);
  final String message;
  @override
  String toString() => message;
}

String errorMasiva(Object e) => switch (e) {
  PostgrestException(:final code, :final message) =>
    code == 'PGRST202'
        ? message.contains('masiva_maestro_consultar')
            ? 'El Listado maestro necesita la migración 132 en DEV.'
            : message.contains('masiva_recepcion_historial')
            ? 'El historial de recepción necesita la migración 140 en DEV.'
            : message.contains('masiva_recepcion_consultar')
            ? 'La tabla de recepción necesita la migración 130 en DEV.'
            : 'Masiva necesita la migración 129 en DEV. Aún no está disponible en esta base.'
        : message,
  MasivaError(:final message) => message,
  FormatException(:final message) => message,
  TimeoutException() =>
    'No se recibió respuesta. Comprueba la conexión y actualiza antes de continuar.',
  _ =>
    'No se pudo completar la acción. Actualiza los datos antes de volver a intentarlo.',
};
