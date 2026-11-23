import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/masiva/masiva_repository.dart';
import 'package:orbiloq_wms/features/masiva/presentation/masiva_maestro_tabla.dart';
import 'masiva_ui_test.dart' show MasivaFixture, mount;

class PagingFixture extends MasivaFixture {
  PagingFixture()
    : super(
        listadoMaestro: List.generate(
          61,
          (i) => {
            'lista': '$i',
            'cliente': i == 60 ? 'Cliente global' : 'Cliente A',
            'estado': 'POR EMPACAR',
          },
        ),
      );
  Completer<void>? pending;
  bool fail = false;
  @override
  Future<MasivaJson> consultarMaestro({
    required String operacion,
    required String vista,
    String buscar = '',
    Map<String, Set<String>> filtros = const {},
    int pagina = 1,
    int tamano = 30,
    String fechaTipo = 'fecha_carga',
    String? desde,
    String? hasta,
    bool incluirOpciones = true,
  }) async {
    final result = await super.consultarMaestro(
      operacion: operacion,
      vista: vista,
      buscar: buscar,
      filtros: filtros,
      pagina: pagina,
      tamano: tamano,
      fechaTipo: fechaTipo,
      desde: desde,
      hasta: hasta,
      incluirOpciones: incluirOpciones,
    );
    await pending?.future;
    if (fail) throw Exception('Fallo simulado');
    return result;
  }
}

void main() {
  testWidgets('temporizador no solapa recargas silenciosas lentas', (
    tester,
  ) async {
    final repo = PagingFixture();
    await mount(tester, const Size(1440, 1000), repo);
    await tester.tap(find.text('Listado maestro').first);
    await tester.pumpAndSettle();
    repo.pending = Completer<void>();
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    final requests = repo.maestroConsultas.length;
    expect(requests, 2);
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    expect(repo.maestroConsultas.length, requests);
    repo.pending!.complete();
    repo.pending = null;
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });
  testWidgets(
    'paginar conserva tabla y facetas globales sin recargar catalogos; actualizar invalida',
    (tester) async {
      final repo = PagingFixture();
      await mount(tester, const Size(1440, 1000), repo);
      await tester.tap(find.text('Listado maestro').first);
      await tester.pumpAndSettle();
      final table = find.byType(MasivaMaestroTabla);
      final state = tester.state(table);
      final queries = repo.consultas.length;
      repo.pending = Completer<void>();
      final next = find.byTooltip('Página siguiente');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pump();
      expect(repo.maestroConsultas.last['incluir_opciones'], false);
      expect(repo.consultas.length, queries);
      expect(tester.state(table), same(state));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(repo.maestroConsultas.length, 2);
      expect(
        tester.widget<MasivaMaestroTabla>(table).opciones['cliente'],
        contains('Cliente global'),
      );
      await tester.pump(const Duration(seconds: 61));
      expect(repo.maestroConsultas.length, 1 + 1);
      repo.pending!.complete();
      repo.pending = null;
      await tester.pumpAndSettle();
      expect(find.text('Página 2 de 3'), findsOneWidget);
      expect(
        tester.widget<MasivaMaestroTabla>(table).filas.first['lista'],
        '30',
      );
      await tester.tap(find.byTooltip('Actualizar datos'));
      await tester.pumpAndSettle();
      expect(repo.maestroConsultas.last['incluir_opciones'], true);
      expect(repo.consultas.length, greaterThan(queries));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'error de paginacion mantiene filas y numero de pagina anteriores',
    (tester) async {
      final repo = PagingFixture();
      await mount(tester, const Size(1440, 1000), repo);
      await tester.tap(find.text('Listado maestro').first);
      await tester.pumpAndSettle();
      repo.fail = true;
      final next = find.byTooltip('Página siguiente');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('Página 1 de 3'), findsOneWidget);
      expect(
        tester
            .widget<MasivaMaestroTabla>(find.byType(MasivaMaestroTabla))
            .filas
            .first['lista'],
        '0',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
