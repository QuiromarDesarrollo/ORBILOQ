import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/auth_providers.dart';

final despachoBorradorRepositoryProvider =
    Provider<DespachoBorradorRepository?>(
      (ref) =>
          ref.watch(usarSupabaseProvider)
              ? DespachoBorradorRepository(Supabase.instance.client)
              : null,
    );

/// Borradores privados del usuario autenticado. No reservan inventario.
class DespachoBorradorRepository {
  DespachoBorradorRepository(this.client);

  final SupabaseClient client;

  Future<Map<String, dynamic>?> cargar(String clave) async {
    final resultado = await client.rpc(
      'despacho_borrador_cargar',
      params: {'p_clave': clave},
    );
    return resultado == null
        ? null
        : Map<String, dynamic>.from(resultado as Map);
  }

  /// Version cero crea un borrador. Las siguientes escrituras requieren la
  /// versión devuelta al cargar/guardar para no sobrescribir otro equipo.
  Future<Map<String, dynamic>> guardar(
    String clave,
    Map<String, dynamic> datos, {
    int version = 0,
  }) async => Map<String, dynamic>.from(
    await client.rpc(
          'despacho_borrador_guardar',
          params: {'p_clave': clave, 'p_datos': datos, 'p_version': version},
        )
        as Map,
  );

  Future<void> eliminar(String clave, {required int version}) async {
    await client.rpc(
      'despacho_borrador_eliminar',
      params: {'p_clave': clave, 'p_version': version},
    );
  }
}
