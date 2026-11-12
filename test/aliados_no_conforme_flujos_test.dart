import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/core/result.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/domain/wms_repository.dart';
import 'package:orbiloq_wms/features/aliados_no_conforme/presentation/aliados_no_conforme_dialog.dart';
import 'package:orbiloq_wms/shared/widgets/addable_person_dropdown.dart';

NoConformeAliado solicitud(
  String id,
  String op,
  String talla, {
  int liberada = 0,
}) => NoConformeAliado(
  id: id,
  item: ItemOrden(
    id: 'item-$id',
    op: op,
    cliente: 'Cliente',
    oc: 'OC',
    codigo: 'codigo-$id',
    descripcion: 'OVEROL DOS PIEZAS DIELECTRICO',
    talla: talla,
    cantidadPedida: 20,
  ),
  cantidad: 3,
  cantidadLiberada: liberada,
  causal: 'Costura suelta o mal terminada',
  estado: liberada == 3 ? 'liberado' : 'pendiente',
  usuarioSolicitud: 'Helen Calderon',
  personaAliadoEntrega: 'ARGELIS',
  fechaSolicitud: DateTime(2026, 11, 11, 16, 51),
  notaSolicitud: 'Revisar costuras y botones antes de liberar',
);

// Repositorio aislado: estas pruebas nunca se conectan ni escriben en Supabase.
class AliadosFake implements WmsRepository {
  final filas = [
    solicitud('a', '25615', 'M/38/14'),
    solicitud('b', '25615', 'L/40/16'),
    solicitud('c', '26094', 'S'),
  ];
  final eventos = <LiberacionAliado>[];
  final llamadas =
      <({String id, int cantidad, String persona, String operario})>[];
  Completer<Result<void>>? respuesta;
  bool fallaLectura = false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Stream<WmsSnapshot> watch() =>
      Stream.value(WmsSnapshot(kardex: [], lotes: []));
  @override
  Future<List<Causal>> cargarCausales() async => [];
  @override
  Future<List<String>> cargarPersonalAliados() async => ['ARGELIS', 'JULIANA'];
  @override
  Future<List<NoConformeAliado>> cargarNoConformesAliados() async {
    if (fallaLectura) throw StateError('Sin conexión de prueba');
    return List.of(filas);
  }

  @override
  Future<List<LiberacionAliado>> cargarLiberacionesAliados() async =>
      List.of(eventos);
  @override
  Future<Result<void>> liberarNoConformeAliado({
    required String id,
    required int cantidad,
    required String operario,
    required String personaAliadoLibera,
    String nota = '',
  }) async {
    llamadas.add((
      id: id,
      cantidad: cantidad,
      persona: personaAliadoLibera,
      operario: operario,
    ));
    final result =
        respuesta == null ? const Ok<void>(null) : await respuesta!.future;
    if (result is Ok<void>) {
      final i = filas.indexWhere((a) => a.id == id);
      final a = filas[i];
      filas[i] = solicitud(
        id,
        a.item.op,
        a.item.talla,
        liberada: a.cantidadLiberada + cantidad,
      );
      eventos.add(
        LiberacionAliado(
          id: 'evento-${eventos.length}',
          solicitudId: id,
          item: a.item,
          cantidad: cantidad,
          tipo: filas[i].pendiente ? 'parcial' : 'completa',
          operario: operario,
          personaAliado: personaAliadoLibera,
          fecha: DateTime(2026, 11, 12),
        ),
      );
    }
    return result;
  }
}

Future<void> abrir(
  WidgetTester tester,
  AliadosFake repo,
  double width, {
  double height = 850,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        wmsRepositoryProvider.overrideWithValue(repo),
        nombreOperarioProvider.overrideWithValue('Administrador'),
      ],
      child: MaterialApp(
        theme: AppTheme.kardex(TemaModo.corporativo),
        home: const Scaffold(body: AliadosNoConformeDialog()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Pendientes'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Pendientes'));
  await tester.pumpAndSettle();
}

Finder campo(String key) => find.byKey(ValueKey(key));
Future<void> pulsar(WidgetTester tester, Finder finder) async {
  if (finder.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(finder);
  }
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> persona(WidgetTester tester, String nombre) async {
  final drop = find.descendant(
    of: find.byType(AddablePersonDropdown),
    matching: find.byType(DropdownButtonFormField<String>),
  );
  await pulsar(tester, drop);
  await pulsar(tester, find.text(nombre).last);
}

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'Aliados: seleccionar no desplaza horizontalmente la pestaña a $width',
      (tester) async {
        await abrir(tester, AliadosFake(), width);
        final horizontal =
            tester
                .stateList<ScrollableState>(
                  find.descendant(
                    of: find.byType(TabBarView),
                    matching: find.byType(Scrollable),
                  ),
                )
                .where(
                  (s) =>
                      s.axisDirection == AxisDirection.right ||
                      s.axisDirection == AxisDirection.left,
                )
                .first;
        final offsetInicial = horizontal.position.pixels;
        final vertical =
            Scrollable.of(
              tester.element(campo('aliados-solicitud-a')),
            ).position;
        final verticalInicial = vertical.pixels;
        final buscadorX = tester.getTopLeft(campo('aliados-buscar-op')).dx;
        expect(campo('aliados-solicitud-a').hitTestable(), findsOneWidget);
        await tester.tap(campo('aliados-solicitud-a'));
        // Inspeccionar también los frames intermedios: el PageView puede volver
        // a su página al terminar y esconder el salto horizontal transitorio.
        for (var frame = 0; frame < 16; frame++) {
          await tester.pump(const Duration(milliseconds: 20));
          expect(
            horizontal.position.pixels,
            closeTo(offsetInicial, 0.1),
            reason:
                'La selección solo puede desplazar el panel vertical, frame $frame',
          );
          expect(
            tester.getTopLeft(campo('aliados-buscar-op')).dx,
            closeTo(buscadorX, 0.1),
          );
        }
        await tester.pumpAndSettle();
        if (width < 800) {
          expect(
            vertical.pixels,
            greaterThan(verticalInicial),
            reason:
                'En móvil se conserva el avance vertical al detalle seleccionado',
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Aliados: respuesta incierta no reintenta una escritura automáticamente',
    (tester) async {
      final repo = AliadosFake()..respuesta = Completer<Result<void>>();
      await abrir(tester, repo, 1440);
      await pulsar(tester, campo('aliados-solicitud-a'));
      await persona(tester, 'ARGELIS');
      await tester.ensureVisible(find.text('LIBERAR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LIBERAR'));
      await tester.pump();
      repo.respuesta!.completeError(
        StateError('Respuesta de red interrumpida'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Revisa el historial'), findsOneWidget);
      expect(repo.llamadas.length, 1);
      await pulsar(tester, find.text('Cerrar aviso'));
      expect(find.text('LIBERAR').hitTestable(), findsOneWidget);
      expect(repo.eventos, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Aliados: móvil con teclado mantiene cantidad y acción accesibles',
    (tester) async {
      final repo = AliadosFake();
      await abrir(tester, repo, 390, height: 700);
      await pulsar(tester, campo('aliados-solicitud-a'));
      await tester.ensureVisible(campo('aliados-cantidad-a'));
      await tester.enterText(campo('aliados-cantidad-a'), '2');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('LIBERAR'));
      await tester.pumpAndSettle();
      expect(find.text('LIBERAR').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(repo.llamadas, isEmpty);
    },
  );
  testWidgets('Aliados: estados sin pendientes y error de consulta', (
    tester,
  ) async {
    final repo = AliadosFake()..filas.clear();
    await abrir(tester, repo, 390);
    expect(find.textContaining('No hay envíos'), findsOneWidget);
    expect(find.text('LIBERAR'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    repo.fallaLectura = true;
    await abrir(tester, repo, 390);
    expect(find.textContaining('Sin conexión de prueba'), findsOneWidget);
    expect(repo.llamadas, isEmpty);
  });
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets('Aliados: buscar, filtrar y conservar borrador a $width', (
      tester,
    ) async {
      final repo = AliadosFake();
      await abrir(tester, repo, width);
      await tester.enterText(campo('aliados-buscar-op'), '25615');
      await tester.pumpAndSettle();
      expect(campo('aliados-solicitud-c'), findsNothing);
      await pulsar(tester, campo('aliados-solicitud-a'));
      await tester.ensureVisible(campo('aliados-cantidad-a'));
      await tester.enterText(campo('aliados-cantidad-a'), '2');
      await persona(tester, 'JULIANA');
      await pulsar(tester, campo('aliados-solicitud-b'));
      await pulsar(tester, campo('aliados-solicitud-a'));
      expect(
        tester.widget<TextField>(campo('aliados-cantidad-a')).controller!.text,
        '2',
      );
      expect(
        tester
            .widget<AddablePersonDropdown>(find.byType(AddablePersonDropdown))
            .valor,
        'JULIANA',
      );
      await pulsar(tester, find.text('Limpiar'));
      await pulsar(
        tester,
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'aliados-filtro-op-',
              ),
        ),
      );
      await pulsar(tester, find.text('OP 26094').last);
      expect(campo('aliados-solicitud-a'), findsNothing);
      expect(campo('aliados-solicitud-c'), findsOneWidget);
      expect(repo.llamadas, isEmpty);
      if (find.text('Cerrar aviso').evaluate().isNotEmpty) {
        await pulsar(tester, find.text('Cerrar aviso'));
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Aliados: valida, evita doble envío y recupera error sin perder borrador',
    (tester) async {
      final repo = AliadosFake();
      await abrir(tester, repo, 1440);
      await pulsar(tester, campo('aliados-solicitud-a'));
      await pulsar(tester, find.text('LIBERAR'));
      expect(repo.llamadas, isEmpty);
      if (find.text('Cerrar aviso').evaluate().isNotEmpty) {
        await pulsar(tester, find.text('Cerrar aviso'));
      }
      await persona(tester, 'ARGELIS');
      await tester.enterText(campo('aliados-cantidad-a'), '0');
      await pulsar(tester, find.text('LIBERAR'));
      expect(repo.llamadas, isEmpty);
      if (find.text('Cerrar aviso').evaluate().isNotEmpty) {
        await pulsar(tester, find.text('Cerrar aviso'));
      }
      await tester.enterText(campo('aliados-cantidad-a'), '4');
      await pulsar(tester, find.text('LIBERAR'));
      expect(repo.llamadas, isEmpty);
      if (find.text('Cerrar aviso').evaluate().isNotEmpty) {
        await pulsar(tester, find.text('Cerrar aviso'));
      }
      await tester.enterText(campo('aliados-cantidad-a'), '2');
      repo.respuesta = Completer<Result<void>>();
      final liberar =
          tester
              .widget<ElevatedButton>(
                find.ancestor(
                  of: find.text('LIBERAR'),
                  matching: find.byType(ElevatedButton),
                ),
              )
              .onPressed!;
      await tester.ensureVisible(find.text('LIBERAR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LIBERAR'));
      // Un segundo evento que llegó antes de reconstruir el botón deshabilitado.
      liberar();
      await tester.pump();
      expect(
        tester
            .widget<ElevatedButton>(
              find.ancestor(
                of: find.text('Liberando…'),
                matching: find.byType(ElevatedButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.pump();
      expect(repo.llamadas.length, 1);
      repo.respuesta!.complete(
        const Err<void>('Fallo simulado: inténtalo de nuevo'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Fallo simulado'), findsOneWidget);
      expect(
        tester.widget<TextField>(campo('aliados-cantidad-a')).controller!.text,
        '2',
      );
      expect(
        tester
            .widget<AddablePersonDropdown>(find.byType(AddablePersonDropdown))
            .valor,
        'ARGELIS',
      );
      await pulsar(tester, find.text('Cerrar aviso'));
      repo.respuesta = null;
      await pulsar(tester, find.text('LIBERAR'));
      expect(repo.filas.first.cantidadPendiente, 1);
      expect(repo.eventos.single.tipo, 'parcial');
      expect(
        tester.widget<TextField>(campo('aliados-cantidad-a')).controller!.text,
        '1',
      );
      await pulsar(tester, find.text('Cerrar aviso'));
      await persona(tester, 'JULIANA');
      await pulsar(tester, find.text('LIBERAR'));
      expect(repo.filas.first.pendiente, false);
      expect(repo.eventos.last.tipo, 'completa');
      expect(repo.eventos.map((e) => e.cantidad).toList(), [2, 1]);
      expect(
        repo.llamadas.every(
          (e) => e.operario == 'Administrador' && e.id == 'a',
        ),
        true,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
