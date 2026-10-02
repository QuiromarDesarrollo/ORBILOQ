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
    List<ItemKardex> items, Map<String, int> cantidades) {
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
    if (entrada.value > item.pendienteDespacho) {
      throw FormatException('OP ${item.item.op}: supera el pendiente.');
    }
    var restante = entrada.value;
    if (restante > item.stockDisponible) {
      throw FormatException('OP ${item.item.op}: stock total insuficiente.');
    }
    final ubicaciones = item.ubicaciones.keys.toList()..sort();
    for (final u in ubicaciones) {
      final cantidad = min(restante, max(0, item.stockEn(u)));
      if (cantidad > 0) {
        plan.add({
          'item_id': item.id,
          'ubicacion': u,
          'cantidad': cantidad,
          'op': item.item.op,
          'codigo': item.item.codigo,
          'talla': item.item.talla
        });
      }
      restante -= cantidad;
      if (restante == 0) break;
    }
    if (restante > 0) {
      throw FormatException(
          'OP ${item.item.op}, ${item.item.codigo} (${item.item.talla}): stock insuficiente.');
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
      24, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

abstract class DespachosOcRepository {
  Future<void> confirmar(String solicitud, String cliente, String oc,
      List<Map<String, dynamic>> lineas);
  Future<List<Map<String, dynamic>>> historial();
}

class SupabaseDespachosOcRepository implements DespachosOcRepository {
  SupabaseDespachosOcRepository(this.client);
  final SupabaseClient client;
  @override
  Future<void> confirmar(String solicitud, String cliente, String oc,
      List<Map<String, dynamic>> lineas) async {
    await client.rpc('despachar_oc', params: {
      'p_solicitud': solicitud,
      'p_cliente': cliente,
      'p_oc': oc,
      'p_lineas': [
        for (final l in lineas)
          {
            'item_id': l['item_id'],
            'ubicacion': l['ubicacion'],
            'cantidad': l['cantidad']
          }
      ]
    });
  }

  @override
  Future<List<Map<String, dynamic>>> historial() async {
    final filas = <Map<String, dynamic>>[];
    var cursor = '';
    while (true) {
      final pagina = (await client.rpc('historial_despachos_oc',
              params: {'p_despues': cursor}) as List)
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
