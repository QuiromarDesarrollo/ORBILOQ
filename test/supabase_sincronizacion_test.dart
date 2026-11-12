import 'dart:io';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orbiloq_wms/data/supabase_wms_repository.dart';
import 'package:orbiloq_wms/core/result.dart';
import 'package:orbiloq_wms/core/inventario_entorno.dart';

void main() {
  final fuentes = inventarioEnPruebas ? 5 : 4;
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
      if (consultas == fuentes) cuatroConsultas.complete();
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
    expect(consultas, fuentes);
    liberar.complete();
    await Future.wait(pendientes);
    expect(consultas, fuentes * 2); // Dos snapshots, no 51 completos.
    await repo.refrescar();
    expect(
      consultas,
      fuentes * 3,
    ); // Sigue siendo posible actualizar manualmente.
  });

  for (final fallaInicial in [false, true]) {
    test('Cada solicitud espera su lectura posterior sin quedar ligada a '
        'avisos futuros (fallo inicial: $fallaInicial)', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final inicios = List.generate(3, (_) => Completer<void>());
      final liberar = List.generate(3, (_) => Completer<void>());
      var consultas = 0;
      var snapshots = 0;
      final errores = <Object>[];
      server.listen((request) async {
        if (!request.uri.path.startsWith('/rest/v1/')) {
          request.response.statusCode = 404;
          await request.response.close();
          return;
        }
        final ciclo = consultas ~/ fuentes;
        consultas++;
        if (consultas % fuentes == 0) inicios[ciclo].complete();
        await liberar[ciclo].future;
        request.response.headers.contentType = ContentType.json;
        // 400 evita reintentos HTTP automáticos: verificamos la cola, no backoff.
        final falla = fallaInicial && ciclo == 0;
        request.response.statusCode = falla ? 400 : 200;
        request.response.write(falla ? '{"message":"Error de lectura"}' : '[]');
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'test-key',
      );
      final repo = SupabaseWmsRepository(client);
      final sub = repo.watch().listen((_) => snapshots++, onError: errores.add);
      addTearDown(() async {
        for (final gate in liberar) {
          if (!gate.isCompleted) gate.complete();
        }
        await sub.cancel();
        repo.dispose();
        await client.dispose();
        await server.close(force: true);
      });
      await inicios[0].future.timeout(const Duration(seconds: 5));
      var manualTerminado = false;
      final manual = repo.refrescar().then((_) => manualTerminado = true);
      liberar[0].complete();
      await inicios[1].future.timeout(const Duration(seconds: 5));
      expect(manualTerminado, isFalse); // No acepta la lectura iniciada antes.
      var siguienteTerminado = false;
      final siguiente = repo.refrescar().then((_) => siguienteTerminado = true);
      liberar[1].complete();
      await manual.timeout(const Duration(seconds: 5));
      await inicios[2].future.timeout(const Duration(seconds: 5));
      expect(
        manualTerminado,
        isTrue,
      ); // La tercera lectura no retiene al usuario.
      expect(siguienteTerminado, isFalse);
      liberar[2].complete();
      await siguiente.timeout(const Duration(seconds: 5));
      await Future<void>.delayed(Duration.zero);
      expect(consultas, fuentes * 3);
      expect(snapshots, fallaInicial ? 2 : 3);
      expect(errores.length, fallaInicial ? 1 : 0);
    });
  }

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
