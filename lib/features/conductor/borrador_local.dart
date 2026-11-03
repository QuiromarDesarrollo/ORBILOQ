import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/auth_providers.dart';
import 'conductor_repository.dart';
import 'borrador_storage_native.dart'
    if (dart.library.js_interop) 'borrador_storage_web.dart'
    as storage;

final transporteBorradorStoreProvider = Provider<BorradorLocalStore>(
  (ref) => BorradorLocalStore(),
);
final transporteBorradorUsuarioProvider = Provider<String?>((ref) {
  if (ref.watch(usarSupabaseProvider)) ref.watch(authStateProvider);
  final client = ref.watch(conductorRepositoryProvider).client;
  final user = client?.auth.currentUser?.id;
  if (user == null) {
    return null; // La demostración no conserva datos de usuarios.
  }
  return '${const String.fromEnvironment('SUPABASE_URL')}:$user';
});

class BorradorLocalStore {
  Future<Map<String, dynamic>?> leer(String key) async {
    final raw = await storage.operar(key, null);
    return raw == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> guardar(String key, Map<String, dynamic> datos) async {
    await storage.operar(key, jsonEncode(datos));
  }

  Future<void> eliminar(String key) async {
    await storage.operar(key, null, delete: true);
  }
}
