import 'package:supabase_flutter/supabase_flutter.dart';

const catalogosAdministrables = {
  'usuarios': 'Usuarios',
  'ubicaciones': 'Ubicaciones / estantes',
  'causales_devolucion': 'Causales de devolución',
  'personal_logistica': 'Personal de Logística',
  'personal_produccion': 'Personal de Producción',
  'personal_aliados': 'Personal de Aliados',
};

abstract class CatalogosRepository {
  Future<List<Map<String, dynamic>>> listar(String tipo);
  Future<void> guardar(String tipo, Map<String, dynamic>? anterior,
      String nombre, bool activo, String rol);
  Future<bool> crearUsuario(
      String numero, String nombre, String rol, String contrasena);
}

class SupabaseCatalogosRepository implements CatalogosRepository {
  SupabaseCatalogosRepository(this.client);
  final SupabaseClient client;
  @override
  Future<List<Map<String, dynamic>>> listar(String tipo) async =>
      (await client.rpc('admin_catalogos_listar', params: {'p_tipo': tipo})
              as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
  @override
  Future<void> guardar(String tipo, Map<String, dynamic>? anterior,
      String nombre, bool activo, String rol) async {
    await client.rpc(
        tipo == 'usuarios'
            ? 'admin_usuario_guardar'
            : 'admin_catalogos_guardar',
        params: {
          if (tipo != 'usuarios') 'p_tipo': tipo,
          'p_id': anterior?['id'],
          'p_nombre': nombre,
          'p_activo': activo,
          'p_version': anterior?['version'],
          if (tipo == 'usuarios') 'p_rol': rol,
        });
  }

  @override
  Future<bool> crearUsuario(
      String numero, String nombre, String rol, String contrasena) async {
    final res = await client.functions.invoke('admin-crear-usuario', body: {
      'numero': numero,
      'nombre': nombre,
      'rol': rol,
      'contrasena': contrasena
    });
    if (res.status != 200 || res.data is! Map || res.data['usuario'] == null) {
      throw FormatException(res.data is Map
          ? res.data['error']?.toString() ?? 'No se pudo crear la cuenta.'
          : 'No se pudo crear la cuenta.');
    }
    return res.data['recuperada'] == true;
  }
}
