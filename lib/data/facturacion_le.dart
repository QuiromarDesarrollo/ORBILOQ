import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../application/auth_providers.dart';

abstract class FacturacionRepository {
  Future<List<Map<String, dynamic>>> listar(bool completas);
  Future<void> guardar(Map<String, dynamic> fila, String remision, String idOc);
}

class SupabaseFacturacionRepository implements FacturacionRepository {
  SupabaseFacturacionRepository(this.client);
  final SupabaseClient client;
  @override
  Future<List<Map<String, dynamic>>> listar(bool completas) async {
    final filas = <Map<String, dynamic>>[];
    int? antes;
    while (true) {
      final pagina =
          (await client.rpc(
                    'facturacion_le_listar',
                    params: {'p_completa': completas, 'p_antes': antes},
                  )
                  as List)
              .map((x) => Map<String, dynamic>.from(x as Map))
              .toList();
      filas.addAll(pagina);
      if (pagina.length < 200) return filas;
      final siguiente = (pagina.last['le'] as num).toInt();
      if (antes != null && siguiente >= antes) {
        throw StateError('No se pudo completar la consulta de facturación');
      }
      antes = siguiente;
    }
  }

  @override
  Future<void> guardar(
    Map<String, dynamic> fila,
    String remision,
    String idOc,
  ) async {
    await client.rpc(
      'facturacion_le_guardar',
      params: {
        'p_id': fila['id'],
        'p_revision': fila['revision'],
        'p_version': fila['version'],
        'p_version_seguimiento': fila['version_seguimiento'],
        'p_remision': remision,
        'p_id_oc': idOc,
      },
    );
  }
}

final facturacionRepositoryProvider = Provider<FacturacionRepository?>(
  (ref) =>
      ref.watch(usarSupabaseProvider)
          ? SupabaseFacturacionRepository(Supabase.instance.client)
          : null,
);
final facturacionProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, bool>((ref, completas) async {
      final repo = ref.watch(facturacionRepositoryProvider);
      return repo == null ? [] : repo.listar(completas);
    });
