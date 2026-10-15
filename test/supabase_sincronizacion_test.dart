import 'dart:io';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orbiloq_wms/data/supabase_wms_repository.dart';
import 'package:orbiloq_wms/core/result.dart';

void main() {
  test('50 avisos durante una carga comparten una recarga posterior', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final cuatroConsultas = Completer<void>();
    final liberar = Completer<void>();
    var consultas = 0;
    server.listen((request) async {
      if (!request.uri.path.startsWith('/rest/v1/')) {
        request.response.statusCode = 404;
        await request.response.close();
        return;
      }
      consultas++;
      if (consultas == 4) cuatroConsultas.complete();
      await liberar.future;
      request.response.headers.contentType = ContentType.json;
      request.response.write('[]');
      await request.response.close();
    });
    final client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-key',
    );
    final repo = SupabaseWmsRepository(client);
    addTearDown(() async {
      if (!liberar.isCompleted) liberar.complete();
      repo.dispose();
      await client.dispose();
      await server.close(force: true);
    });
    // Las cuatro fuentes deben comenzar sin esperar a que termine la primera.
    await cuatroConsultas.future.timeout(const Duration(seconds: 5));
    final pendientes = List.generate(50, (_) => repo.refrescar());
    expect(consultas, 4);
    liberar.complete();
    await Future.wait(pendientes);
    expect(consultas, 8); // Dos snapshots, no 51 snapshots completos.
    await repo.refrescar();
    expect(consultas, 12); // Sigue siendo posible actualizar manualmente.
  });

  test(
    'El refresco propaga el fallo y permite recuperarse sin perder el stream',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var falla = false;
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path.endsWith('/rpc/admin_eliminar_linea')) {
          request.response.write('null');
          await request.response.close();
          return;
        }
        request.response.statusCode = falla ? 503 : 200;
        request.response.write(falla ? '{"message":"Sin conexión"}' : '[]');
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'test-key',
      );
      final repo = SupabaseWmsRepository(client);
      final errores = <Object>[];
      var snapshots = 0;
      final subscription = repo.watch().listen(
        (_) => snapshots++,
        onError: errores.add,
      );
      addTearDown(() async {
        await subscription.cancel();
        repo.dispose();
        await client.dispose();
        await server.close(force: true);
      });
      await repo.refrescar();
      await Future<void>.delayed(Duration.zero);
      final antes = snapshots;
      falla = true;
      await expectLater(repo.refrescar(), throwsA(isA<PostgrestException>()));
      await Future<void>.delayed(Duration.zero);
      expect(errores, isNotEmpty);
      expect(snapshots, antes);
      // El servidor confirmó el guardado, aunque su recarga no tenga conexión.
      expect(
        await repo.eliminarLineaAdmin('item', 'version', 'motivo'),
        isA<Ok<void>>(),
      );
      falla = false;
      await repo.refrescar();
      await Future<void>.delayed(Duration.zero);
      expect(snapshots, greaterThan(antes));
    },
  );
}
