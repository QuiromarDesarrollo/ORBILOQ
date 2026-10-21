import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orbiloq_wms/data/inventario_repository.dart';

void main() {
  testWidgets('Las lecturas lentas terminan con error recuperable', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    final client = SupabaseClient(
      'https://test.supabase.co',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((_) => response.future),
    );
    final repo = InventarioRepository(client);
    final listado = expectLater(
      repo.listar('', 0),
      throwsA(isA<TimeoutException>()),
    );
    final origenes = expectLater(
      repo.filas('inventario_origenes', {}),
      throwsA(isA<TimeoutException>()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 21));
    await listado;
    await origenes;
    response.complete(http.Response('[]', 200));
    await tester.pump();
  });
}
