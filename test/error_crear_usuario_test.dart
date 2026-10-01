import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orbiloq_wms/data/error_crear_usuario.dart';

void main() {
  test('Distingue despliegue, sesión y servidor aunque no llegue JSON', () {
    expect(mensajeErrorCrearUsuario(const FunctionException(status: 404, details: 'Not found')), contains('No se encontró'));
    expect(mensajeErrorCrearUsuario(const FunctionException(status: 401, details: 'Invalid JWT')), contains('autenticación'));
    expect(mensajeErrorCrearUsuario(const FunctionException(status: 503, details: '<html>error</html>')), contains('HTTP 503'));
    expect(mensajeErrorCrearUsuario(const FunctionException(status: 0)), contains('No se recibió respuesta'));
  });
  test('Conserva mensajes de validación enviados como objeto o texto JSON', () {
    for (final detalle in [{'error': 'El número ya existe.'}, '{"error":"El número ya existe."}']) {
      expect(mensajeErrorCrearUsuario(FunctionException(status: 409, details: detalle)), 'El número ya existe. (HTTP 409)');
    }
  });
}
