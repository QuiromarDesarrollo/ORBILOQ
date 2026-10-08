import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../application/auth_providers.dart';

final empaquesRepositoryProvider = Provider<EmpaquesRepository?>(
  (ref) =>
      ref.watch(usarSupabaseProvider)
          ? EmpaquesRepository(Supabase.instance.client)
          : null,
);
final empaquesProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async => await ref.watch(empaquesRepositoryProvider)?.listar() ?? [],
);

String descripcionEmpaque(Map<String, dynamic> e) =>
    '${e['categoria']} · ${e['nombre']} · ${e['largo_cm']} × ${e['ancho_cm']} × ${e['alto_cm']} cm';

class EmpaquesRepository {
  EmpaquesRepository(this.client);
  final SupabaseClient client;
  Future<List<Map<String, dynamic>>> listar({bool todos = false}) async =>
      (await client.rpc('empaques_listar', params: {'p_todos': todos}) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<void> guardar(
    Map<String, dynamic> datos,
    Map<String, dynamic>? anterior,
  ) async {
    await client.rpc(
      'admin_empaque_guardar',
      params: {
        'p_id': anterior?['id'],
        'p_version': anterior?['version'],
        'p_datos': datos,
      },
    );
  }
}
