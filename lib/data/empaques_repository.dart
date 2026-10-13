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

// BOLSA se conserva como código histórico de base de datos.
String textoEmpaque(Object? valor) => (valor?.toString() ?? '')
    .replaceAllMapped(RegExp(r'\bbolsas?\b', caseSensitive: false), (m) {
      final original = m[0]!;
      final nuevo =
          original.toLowerCase().endsWith('s') ? 'paquetes' : 'paquete';
      return original == original.toUpperCase()
          ? nuevo.toUpperCase()
          : original[0] == original[0].toUpperCase()
          ? '${nuevo[0].toUpperCase()}${nuevo.substring(1)}'
          : nuevo;
    });

String descripcionEmpaque(Map<String, dynamic> e) =>
    '${textoEmpaque(e['categoria'])} · ${textoEmpaque(e['nombre'])} · ${e['largo_cm']} × ${e['ancho_cm']} × ${e['alto_cm']} cm';

double validarPesoBruto(String texto, num tara) {
  final peso = double.tryParse(texto.trim().replaceAll(',', '.'));
  if (peso == null || !peso.isFinite || peso <= 0 || peso > 100000) {
    throw const FormatException(
      'Indica un peso bruto mayor que 0 y hasta 100000 kg.',
    );
  }
  if (peso < tara) {
    throw FormatException(
      'El peso bruto debe ser igual o mayor que la tara ($tara kg).',
    );
  }
  return peso;
}

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
      'admin_empaque_guardar_v92',
      params: {
        'p_id': anterior?['id'],
        'p_version': anterior?['version'],
        'p_datos': datos,
      },
    );
  }
}
