import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orbiloq_wms/data/catalogos_repository.dart';

void main() {
  test(
    'Editar, desactivar y crear envían todos los perfiles al servidor',
    () async {
      final peticiones = <http.Request>[];
      final client = SupabaseClient(
        'https://prueba.supabase.co',
        'clave-publica-de-prueba',
        httpClient: MockClient((req) async {
          peticiones.add(req);
          return http.Response(
            jsonEncode(
              req.url.path.contains('/functions/')
                  ? {
                    'usuario': {
                      'id': '1',
                      'roles': ['seguimiento', 'despacho'],
                    },
                    'recuperada': false,
                  }
                  : {},
            ),
            200,
            request: req,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = SupabaseCatalogosRepository(client);
      final fila = {
        'id': '1',
        'version': 'v1',
        'rol': 'seguimiento',
        'roles': ['seguimiento', 'despacho'],
      };
      await repo.guardar('usuarios', fila, 'Alejandro', false, 'seguimiento');
      expect(
        peticiones.last.url.path,
        endsWith('/rpc/admin_usuario_guardar_roles'),
      );
      expect(jsonDecode(peticiones.last.body)['p_roles'], [
        'seguimiento',
        'despacho',
      ]);
      await repo.guardar(
        'usuarios',
        fila,
        'Alejandro',
        true,
        'despacho',
        roles: ['despacho'],
      );
      expect(jsonDecode(peticiones.last.body)['p_roles'], ['despacho']);
      await repo.crearUsuario(
        '123',
        'Nuevo',
        'seguimiento',
        'clave-ficticia-prueba',
        roles: ['seguimiento', 'despacho'],
      );
      expect(
        peticiones.last.url.path,
        endsWith('/functions/v1/admin-crear-usuario'),
      );
      expect(jsonDecode(peticiones.last.body)['roles'], [
        'seguimiento',
        'despacho',
      ]);
    },
  );
}
