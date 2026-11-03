import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orbiloq_wms/core/masiva_entorno.dart';
import 'package:orbiloq_wms/domain/sesion.dart';
import 'package:orbiloq_wms/features/masiva/masiva_repository.dart';

class RecordingMasiva extends MasivaRepository {
  RecordingMasiva({this.failBatch = false}) : super(null);
  final bool failBatch;
  final calls = <(String, MasivaJson)>[];
  @override
  Future<MasivaJson> ejecutar(String action, MasivaJson data) async {
    calls.add((action, data));
    if (action == 'iniciar_importacion') return {'importacion_id': 'import-1'};
    if (failBatch && action == 'cargar_lote') {
      throw const MasivaError('Red interrumpida');
    }
    return {};
  }
}

void main() {
  test('Maestro envía filtros y paginación completos al servidor', () async {
    final requests = <MasivaJson>[];
    final client = SupabaseClient(
      'https://masiva.test',
      'test-key',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/rest/v1/rpc/masiva_maestro_consultar');
        requests.add(mapaMasiva(jsonDecode(request.body)));
        return http.Response(
          jsonEncode({'filas': [], 'total': 1001}),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final result = await MasivaRepository(client).consultarMaestro(
      operacion: 'op',
      vista: 'base',
      buscar: '000123',
      filtros: {
        'lista': {'001', '002'},
        'estado': {'PENDIENTE'},
      },
      pagina: 2,
      tamano: 1000,
      fechaTipo: 'fecha_carga',
      desde: '2026-10-01',
      hasta: '2026-10-27',
      incluirOpciones: false,
    );
    expect(result['total'], 1001);
    expect(requests.single, {
      'p_operacion': 'op',
      'p_vista': 'base',
      'p_buscar': '000123',
      'p_filtros': {
        'lista': ['001', '002'],
        'estado': ['PENDIENTE'],
      },
      'p_pagina': 2,
      'p_tamano': 1000,
      'p_fecha_tipo': 'fecha_carga',
      'p_desde': '2026-10-01',
      'p_hasta': '2026-10-27',
      'p_incluir_opciones': false,
    });
    await client.dispose();
  });
  test(
    'Recupera una respuesta perdida usando el mismo UUID sin repetir consumo',
    () async {
      final requests = <MasivaJson>[];
      final processed = <String>{};
      var received = 0;
      final client = SupabaseClient(
        'https://masiva.test',
        'test-key',
        httpClient: MockClient((request) async {
          final body = mapaMasiva(jsonDecode(request.body));
          requests.add(body);
          final id = '${mapaMasiva(body['p_datos'])['request_id']}';
          if (processed.add(id)) received++;
          if (requests.length == 1) {
            throw http.ClientException('Respuesta perdida');
          }
          return http.Response(
            jsonEncode({'recibido': received}),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final repo = MasivaRepository(client);
      await expectLater(
        repo.ejecutar('recibir', {
          'request_id': MasivaRepository.requestId(),
          'cantidad': 1,
        }),
        throwsA(anything),
      );
      expect(repo.movimientoPendiente, isNotNull);
      await expectLater(
        repo.ejecutar('recibir', {
          'request_id': MasivaRepository.requestId(),
          'cantidad': 1,
        }),
        throwsA(isA<MasivaError>()),
      );
      final recovered = MasivaRepository(client);
      expect((await recovered.recuperarConfirmacion())['recibido'], 1);
      expect(requests.length, 2);
      expect(requests[0]['p_datos'], requests[1]['p_datos']);
      expect(recovered.movimientoPendiente, isNull);
      await client.dispose();
    },
  );
  test('Masiva se habilita solo en los proyectos existentes de ORBILOQ', () {
    expect(
      masivaHabilitada('https://igfuafcekcpugpmsoqbe.supabase.co'),
      isTrue,
    );
    expect(
      masivaHabilitada('https://cxrflhgnxvomcvxzugda.supabase.co'),
      isTrue,
    );
    expect(masivaHabilitada('https://otro.supabase.co'), isFalse);
    expect(
      UsuarioSesion(
        numeroUsuario: '1',
        nombre: 'Masiva',
        rolCuenta: RolCuenta.masiva,
      ).areas,
      isEmpty,
    );
    expect(
      RolCuenta.deFila({
        'roles': ['masiva', 'admin'],
      }),
      [RolCuenta.admin, RolCuenta.masiva],
    );
  });
  test('Sube 30.000 filas por lotes completos antes de confirmar', () async {
    final repo = RecordingMasiva();
    final progress = <double>[];
    await repo.importar(
      operacion: 'op',
      tipo: 'personal',
      archivo: 'base.xlsx',
      filas: List.generate(30000, (i) => {'sku': '$i'}),
      progreso: progress.add,
    );
    expect(repo.calls.first.$2['total_lotes'], 60);
    expect(repo.calls.first.$2['total_filas'], 30000);
    expect(repo.calls.where((c) => c.$1 == 'cargar_lote').length, 60);
    expect(repo.calls[60].$2['indice'], 59);
    expect(repo.calls.last.$1, 'confirmar_importacion');
    expect(progress.last, 1);
  });
  test('Una carga interrumpida no confirma ni reintenta movimientos', () async {
    final repo = RecordingMasiva(failBatch: true);
    await expectLater(
      repo.importar(
        operacion: 'op',
        tipo: 'personal',
        archivo: 'base.xlsx',
        filas: [
          {'sku': 'a'},
        ],
        progreso: (_) {},
      ),
      throwsA(isA<MasivaError>()),
    );
    expect(repo.calls.map((c) => c.$1), ['iniciar_importacion', 'cargar_lote']);
  });
  test('No se simulan escrituras sin conexión DEV', () async {
    await expectLater(
      MasivaRepository(null).ejecutar('recibir', {}),
      throwsA(isA<MasivaError>()),
    );
  });
  test('Las claves de idempotencia son UUID v4 distintas', () {
    final ids = List.generate(1000, (_) => MasivaRepository.requestId());
    expect(ids.toSet().length, 1000);
    expect(
      ids.every(
        RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
        ).hasMatch,
      ),
      isTrue,
    );
  });
}
