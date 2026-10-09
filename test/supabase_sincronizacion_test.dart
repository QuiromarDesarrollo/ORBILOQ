import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orbiloq_wms/data/supabase_wms_repository.dart';
import 'package:orbiloq_wms/core/result.dart';

void main() {
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
