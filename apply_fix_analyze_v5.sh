#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Corrige los avisos de 'flutter analyze' (v5)
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_fix_analyze_v5.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi

echo "Corrigiendo avisos de flutter analyze..."

echo "  - lib/main.dart"
mkdir -p "$(dirname 'lib/main.dart')"
cat > 'lib/main.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'application/providers.dart';
import 'data/in_memory_wms_repository.dart';
import 'data/supabase_importador_ordenes.dart';
import 'data/supabase_wms_repository.dart';

/// Credenciales de Supabase, pasadas al compilar con:
///   flutter run -d chrome \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=sb_publishable_xxxx
///
/// Si no se pasan (quedan vacías), la app arranca con datos de prueba en
/// memoria — útil para desarrollar la interfaz sin depender de la base real.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final usarSupabase = _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

  if (usarSupabase) {
    await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseAnonKey);
  }

  runApp(
    ProviderScope(
      overrides: [
        wmsRepositoryProvider.overrideWith((ref) {
          if (usarSupabase) {
            final repo = SupabaseWmsRepository(Supabase.instance.client);
            ref.onDispose(repo.dispose);
            return repo;
          }
          final repo = InMemoryWmsRepository.seeded();
          ref.onDispose(repo.dispose);
          return repo;
        }),
        importadorOrdenesProvider.overrideWith((ref) {
          if (!usarSupabase) return null;
          return SupabaseImportadorOrdenes(Supabase.instance.client);
        }),
      ],
      child: const OrbiloqWmsApp(),
    ),
  );
}
ORBILOQ_EOF

echo "  - test/wms_rules_test.dart"
mkdir -p "$(dirname 'test/wms_rules_test.dart')"
cat > 'test/wms_rules_test.dart' << 'ORBILOQ_EOF'
import 'package:flutter_test/flutter_test.dart';

import 'package:orbiloq_wms/core/result.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/domain/qr_prenda.dart';

const _xs = '19249|ORD-001-ENE|2025289514|XS'; // pedida 9, producido 9 (límite alcanzado)
const _s = '19249|ORD-001-ENE|2025289515|S'; // pedida 264, producido 100, stock A1 = 30

void main() {
  group('QrPrenda', () {
    test('parsea un QR válido con el formato real de la marquilla', () {
      final qr = QrPrenda.tryParse(
        'https://orbiloq.app/qr?;19249;2025289514;TSHIRT MANGA CORTA T. XS;ENEL;ORD-001-ENE;ID0001',
      );
      expect(qr, isNotNull);
      expect(qr!.op, '19249');
      expect(qr.codigo, '2025289514');
      expect(qr.cliente, 'ENEL');
      expect(qr.noOc, 'ORD-001-ENE');
    });

    test('rechaza QR incompleto o con OP/Código vacíos', () {
      expect(QrPrenda.tryParse('url;ENEL'), isNull);
      expect(QrPrenda.tryParse('url;;2025289514;TSHIRT;ENEL;ORD-001-ENE'), isNull);
    });
  });

  group('Reglas de negocio', () {
    late InMemoryWmsRepository repo;

    setUp(() => repo = InMemoryWmsRepository.seeded());
    tearDown(() => repo.dispose());

    Future<ItemKardex> kardex(String id) async =>
        (await repo.watch().first).kardexPorId(id)!;

    test('producción no puede superar la cantidad pedida', () async {
      expect(await repo.entregarLote(itemId: _xs, cantidad: 1, operario: 'X'), isA<Err>());
      expect(await repo.entregarLote(itemId: _s, cantidad: 165, operario: 'X'), isA<Err>());
      expect(await repo.entregarLote(itemId: _s, cantidad: 164, operario: 'X'), isA<Ok>());
    });

    test('no se entrega un producto inexistente ni cantidades <= 0', () async {
      expect(await repo.entregarLote(itemId: 'nope', cantidad: 1, operario: 'X'), isA<Err>());
      expect(await repo.entregarLote(itemId: _s, cantidad: 0, operario: 'X'), isA<Err>());
    });

    test('no permite remisiones duplicadas', () async {
      final r = await repo.entregarLote(itemId: _s, cantidad: 1, operario: 'X', numeroRemision: 'REM-097');
      expect(r, isA<Err>());
    });

    test('la numeración automática no colisiona', () async {
      final a = await repo.entregarLote(itemId: _s, cantidad: 1, operario: 'X');
      final b = await repo.entregarLote(itemId: _s, cantidad: 1, operario: 'X');
      expect((a as Ok<Remision>).value.id, isNot((b as Ok<Remision>).value.id));
    });

    test('la recepción con faltante genera novedad y actualiza el stock', () async {
      final res = await repo.recibirLote(remisionId: 'REM-101', cantidad: 3, ubicacion: 'RACK C3');
      final remision = (res as Ok<Remision>).value;
      expect(remision.estado, EstadoRemision.recibidoConNovedad);
      expect(remision.novedad, contains('FALTANTE'));

      final k = await kardex(_xs);
      expect(k.recibido, 8);
      expect(k.stockEn('RACK C3'), 3);
    });

    test('una remisión no se puede recibir dos veces', () async {
      await repo.recibirLote(remisionId: 'REM-101', cantidad: 4, ubicacion: 'RACK C3');
      final again = await repo.recibirLote(remisionId: 'REM-101', cantidad: 4, ubicacion: 'RACK C3');
      expect(again, isA<Err>());
    });

    test('el despacho valida el stock de la ubicación', () async {
      expect(await repo.despachar(itemId: _s, cantidad: 31, ubicacion: 'ESTANTE A1'), isA<Err>());
      expect(await repo.despachar(itemId: _s, cantidad: 1, ubicacion: 'RACK C3'), isA<Err>());
      expect(await repo.despachar(itemId: _s, cantidad: 30, ubicacion: 'ESTANTE A1'), isA<Ok>());

      final k = await kardex(_s);
      expect(k.despachado, 50);
      expect(k.stockDisponible, 0);
      expect(k.ubicaciones.containsKey('ESTANTE A1'), isFalse);
    });

    test('stockDisponible siempre coincide con la suma de ubicaciones', () async {
      final snap = await repo.watch().first;
      for (final k in snap.kardex) {
        expect(k.ubicaciones.values.fold<int>(0, (a, b) => a + b), k.stockDisponible);
      }
    });
  });
}
ORBILOQ_EOF

echo ""
echo "Listo. Siguiente paso:"
echo "  flutter analyze   (deberia salir: No issues found!)"
echo "  flutter test"
