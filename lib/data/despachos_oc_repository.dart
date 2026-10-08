import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models.dart';

/// Evalúa toda la OC, incluidas OP sin despachos y líneas ocultas.
/// Los filtros del historial no cambian el estado actual de la orden.
String estadoDespachoOc(List<ItemKardex> items, String cliente, String oc) {
  final lineas =
      items.where((i) => i.item.cliente == cliente && i.item.oc == oc).toList();
  if (lineas.isEmpty) return 'Sin datos actuales';
  return lineas.every((i) => i.pendienteDespacho == 0) ? 'Completo' : 'Parcial';
}

List<Map<String, dynamic>> planificarDespacho(
  List<ItemKardex> items,
  Map<String, int> cantidades,
) {
  final plan = <Map<String, dynamic>>[];
  for (final entrada in cantidades.entries) {
    if (entrada.value <= 0) {
      throw const FormatException('La cantidad debe ser mayor que cero.');
    }
    final item =
        items.where((i) => i.id == entrada.key && !i.eliminada).firstOrNull;
    if (item == null) {
      throw const FormatException('La prenda ya no está disponible.');
    }
    if (entrada.value > item.pendienteDisponibleDespacho) {
      throw FormatException(
        'OP ${item.item.op}: pide ${item.cantidadPedida} prendas '
        'y ya se despacharon ${item.despachado}. Hay ${item.reservado} reservadas '
        'y quedan ${item.pendienteDisponibleDespacho} sin reservar; '
        'asignaste ${entrada.value} en los empaques.',
      );
    }
    var restante = entrada.value;
    if (restante > item.disponibleParaDespacho) {
      throw FormatException(
        'OP ${item.item.op}, talla ${item.item.talla}: solicitas $restante unidades, '
        'pero solo hay ${max(0, item.disponibleParaDespacho)} disponibles sin reservar.',
      );
    }
    final ubicaciones = item.ubicaciones.keys.toList()..sort();
    for (final u in ubicaciones) {
      final cantidad = min(restante, max(0, item.disponibleEn(u)));
      if (cantidad > 0) {
        plan.add({
          'item_id': item.id,
          'ubicacion': u,
          'cantidad': cantidad,
          'op': item.item.op,
          'codigo': item.item.codigo,
          'talla': item.item.talla,
        });
      }
      restante -= cantidad;
      if (restante == 0) break;
    }
    if (restante > 0) {
      throw FormatException(
        'OP ${item.item.op}, ${item.item.codigo} (${item.item.talla}): stock insuficiente.',
      );
    }
  }
  if (plan.isEmpty) {
    throw const FormatException('Selecciona al menos una prenda.');
  }
  return plan;
}

String nuevaSolicitudDespacho() {
  final random = Random.secure();
  return List.generate(
    24,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

abstract class DespachosOcRepository {
  Future<Map<String, dynamic>> prepararCorreccion(String id) =>
      throw UnsupportedError('Corrección no disponible');
  Future<void> corregir(
    String id,
    String version,
    String solicitud,
    String motivo,
    String cliente,
    String oc,
    List<Map<String, dynamic>> lineas,
    List<Map<String, dynamic>> empaques,
  ) => throw UnsupportedError('Corrección no disponible');
  Future<void> confirmar(
    String solicitud,
    String cliente,
    String oc,
    List<Map<String, dynamic>> lineas, {
    List<Map<String, dynamic>> empaques = const [],
  });
  Future<List<Map<String, dynamic>>> historial();
}

class SupabaseDespachosOcRepository extends DespachosOcRepository {
  SupabaseDespachosOcRepository(this.client);
  final SupabaseClient client;
  @override
  Future<Map<String, dynamic>> prepararCorreccion(String id) async =>
      Map<String, dynamic>.from(
        await client.rpc('despacho_para_corregir', params: {'p_id': id}) as Map,
      );
  @override
  Future<void> corregir(
    String id,
    String version,
    String solicitud,
    String motivo,
    String cliente,
    String oc,
    List<Map<String, dynamic>> lineas,
    List<Map<String, dynamic>> empaques,
  ) async {
    await client.rpc(
      'corregir_despacho_le',
      params: {
        'p_id': id,
        'p_version': version,
        'p_solicitud': solicitud,
        'p_motivo': motivo,
        'p_cliente': cliente,
        'p_oc': oc,
        'p_lineas': [
          for (final l in lineas)
            {
              'item_id': l['item_id'],
              'ubicacion': l['ubicacion'],
              'cantidad': l['cantidad'],
            },
        ],
        'p_empaques': empaques,
      },
    );
  }

  @override
  Future<void> confirmar(
    String solicitud,
    String cliente,
    String oc,
    List<Map<String, dynamic>> lineas, {
    List<Map<String, dynamic>> empaques = const [],
  }) async {
    await client.rpc(
      'despachar_oc_bultos',
      params: {
        'p_empaques': empaques,
        'p_solicitud': solicitud,
        'p_cliente': cliente,
        'p_oc': oc,
        'p_lineas': [
          for (final l in lineas)
            {
              'item_id': l['item_id'],
              'ubicacion': l['ubicacion'],
              'cantidad': l['cantidad'],
            },
        ],
      },
    );
  }

  @override
  Future<List<Map<String, dynamic>>> historial() async {
    final filas = <Map<String, dynamic>>[];
    var cursor = '';
    while (true) {
      final pagina =
          (await client.rpc(
                    'historial_despachos_empaques',
                    params: {'p_despues': cursor},
                  )
                  as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
      filas.addAll(pagina);
      if (pagina.length < 1000) return filas;
      final siguiente = pagina.last['registro'] as String;
      if (siguiente == cursor) throw StateError('Historial incompleto.');
      cursor = siguiente;
    }
  }
}
