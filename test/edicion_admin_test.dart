import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/core/result.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/domain/edicion_admin.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/domain/sesion.dart';
import 'package:orbiloq_wms/features/kardex/presentation/kardex_table.dart';
import 'package:orbiloq_wms/features/kardex/presentation/edicion_admin_dialog.dart';

const itemId = '19249|ORD-001-ENE|2025289515|S';

void main() {
  test('anular envío no recibido elimina el pendiente y la revisión no escribe', () async {
    final r = InMemoryWmsRepository.seeded();
    addTearDown(r.dispose);
    final inicial = (await r.watch().first).kardex.firstWhere((k) => k.pendienteProduccion >= 37);
    expect(await r.crearLote(items: [ItemCantidad(itemId: inicial.id, cantidad: 37)], operario: 'TEST'), isA<Ok>());
    final c = CambioAdmin(itemId: inicial.id, campo: CampoAdmin.producido, valor: inicial.producido,
      motivo: 'Error de digitación', version: (await r.cargarEdicionAdmin(inicial.id)).version);
    expect(await r.editarAdmin(c, confirmar: false), isA<Ok>());
    expect((await r.watch().first).kardexPorId(inicial.id)!.producido, inicial.producido + 37);
    expect(await r.editarAdmin(c, confirmar: true), isA<Ok>());
    final snapshot = await r.watch().first;
    expect(snapshot.kardexPorId(inicial.id)!.pendienteProduccion, inicial.pendienteProduccion);
    final lineas = snapshot.lotes.firstWhere((l) => l.operario == 'TEST').lineas;
    expect(lineas.every((l) => !l.enTransito && l.cantidadPendiente == 0), isTrue);
  });
  late InMemoryWmsRepository repo;
  setUp(() => repo = InMemoryWmsRepository.seeded());
  tearDown(() => repo.dispose());
  Future<ItemKardex> fila() async =>
      (await repo.watch().first).kardexPorId(itemId)!;
  Future<CambioAdmin> cambio(CampoAdmin campo, Object? valor,
          {String? lote, String? ubicacion}) async =>
      CambioAdmin(
          itemId: itemId,
          campo: campo,
          valor: valor,
          motivo: 'Corrección comprobada',
          version: (await repo.cargarEdicionAdmin(itemId)).version,
          loteId: lote,
          ubicacionId: ubicacion);

  testWidgets('recepción edita saldo de bodega y muestra despachadas separadas', (tester) async {
    tester.view.physicalSize = const Size(1600, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final k = await fila();
    expect(k.despachado, greaterThan(0));
    await tester.pumpWidget(ProviderScope(overrides: [
      usarSupabaseProvider.overrideWithValue(false),
      wmsRepositoryProvider.overrideWithValue(repo),
    ], child: MaterialApp(home: Scaffold(body: EdicionAdminDialog(item: k, campo: CampoAdmin.recibido)))));
    await tester.pumpAndSettle();
    expect(find.text('Valor actual: ${k.stockDisponible}'), findsOneWidget);
    final campo = find.widgetWithText(TextField, 'Nuevo saldo en bodega');
    expect(tester.widget<TextField>(campo).controller!.text, '${k.stockDisponible}');
    await tester.enterText(campo, '-1');
    await tester.ensureVisible(find.text('Revisar cambios'));
    await tester.tap(find.text('Revisar cambios'));
    await tester.pumpAndSettle();
    expect(find.textContaining('El saldo en bodega no puede ser negativo'), findsOneWidget);
    expect((await fila()).despachado, k.despachado);
    expect(tester.takeException(), isNull);
  });

  test('reparte recepción entre lotes y valida toda la suma antes de escribir', () async {
    final antes = await fila();
    final ids = <String>[];
    for (final n in [4, 6, 2]) {
      expect(await repo.crearLote(items: [ItemCantidad(itemId: itemId, cantidad: n)], operario: 'TEST'), isA<Ok>());
      ids.add((await repo.watch().first).lotes.first.lineas.single.id);
    }
    final ctx = await repo.cargarEdicionAdmin(itemId);
    CambioAdmin plan(Map<String,int> cantidades) => CambioAdmin(itemId: itemId, campo: CampoAdmin.recibido,
      valor: antes.recibido + 12, motivo: 'Distribución', version: ctx.version,
      ubicacionId: 'ESTANTE A1', recepciones: cantidades);
    expect(await repo.editarAdmin(plan({ids[0]: 4, ids[1]: 7, ids[2]: 1}), confirmar: true), isA<Err>());
    expect((await fila()).recibido, antes.recibido);
    final c = plan({ids[0]: 4, ids[1]: 6, ids[2]: 2});
    expect(await repo.editarAdmin(c, confirmar: false), isA<Ok>());
    expect((await fila()).recibido, antes.recibido);
    expect(await repo.editarAdmin(c, confirmar: true), isA<Ok>());
    expect((await fila()).recibido, antes.recibido + 12);
    expect((await fila()).stockEn('ESTANTE A1'), antes.stockEn('ESTANTE A1') + 12);
    expect(await repo.editarAdmin(c, confirmar: true), isA<Err>());
  });

  test('aumentar cantidad recalcula pendientes sin inventar movimientos',
      () async {
    final antes = await fila();
    final c = await cambio(CampoAdmin.cantidad, antes.cantidadPedida + 20);
    expect(await repo.editarAdmin(c, confirmar: false), isA<Ok>());
    expect((await fila()).cantidadPedida, antes.cantidadPedida);
    expect(await repo.editarAdmin(c, confirmar: true), isA<Ok>());
    final despues = await fila();
    expect(despues.pendienteProduccion, antes.pendienteProduccion + 20);
    expect(despues.producido, antes.producido);
    expect(despues.recibido, antes.recibido);
    expect(despues.despachado, antes.despachado);
    expect((await repo.cargarEdicionAdmin(itemId)).historial.single['anterior'],
        antes.cantidadPedida);
  });

  test('rechaza una confirmación obsoleta y no duplica correcciones', () async {
    final c = await cambio(CampoAdmin.cantidad, 280);
    expect(await repo.editarAdmin(c, confirmar: true), isA<Ok>());
    expect(await repo.editarAdmin(c, confirmar: true), isA<Err>());
    expect((await repo.cargarEdicionAdmin(itemId)).historial.length, 1);
  });

  test('corrige el total y reduce pendientes sin cambiar recepciones ni stock', () async {
    final antes = await fila();
    final lotesAntes = (await repo.cargarEdicionAdmin(itemId)).lotes;
    for (final total in [antes.recibido + 1, antes.recibido, antes.recibido + 2]) {
      expect(
          await repo.editarAdmin(await cambio(CampoAdmin.producido, total),
              confirmar: true),
          isA<Ok>());
      final actual = await fila();
      expect(actual.producido, total);
      expect(actual.pendienteProduccion, antes.cantidadPedida - total);
      expect(actual.recibido, antes.recibido);
      expect(actual.despachado, antes.despachado);
      expect(actual.ubicaciones, antes.ubicaciones);
      final lotesDespues = (await repo.cargarEdicionAdmin(itemId)).lotes;
      expect(lotesDespues.map((l) => l['recibida']).toList(), lotesAntes.map((l) => l['recibida']).toList());
      expect(lotesDespues.fold<int>(0, (s, l) => s + (l['enviada'] as int) - (l['recibida'] as int)), lessThanOrEqualTo(total - antes.recibido));
    }
  });
  test('bloquea entrega inferior a recepcion en revisión y confirmación sin escribir', () async {
    final antes = await fila();
    expect(antes.recibido, greaterThan(0));
    final contexto = await repo.cargarEdicionAdmin(itemId);
    for (final confirmar in [false, true]) {
      final resultado = await repo.editarAdmin(
        await cambio(CampoAdmin.producido, antes.recibido - 1), confirmar: confirmar);
      expect(resultado, isA<Err>());
      expect((await fila()).producido, antes.producido);
      expect((await fila()).recibido, antes.recibido);
      expect((await fila()).despachado, antes.despachado);
      expect((await repo.cargarEdicionAdmin(itemId)).version, contexto.version);
      expect((await repo.cargarEdicionAdmin(itemId)).historial, contexto.historial);
    }
  });
  test('un cambio inválido no deja escritura parcial', () async {
    final antes = await fila();
    expect(
        await repo.editarAdmin(await cambio(CampoAdmin.cantidad, 1),
            confirmar: true),
        isA<Err>());
    expect((await fila()).cantidadPedida, antes.cantidadPedida);
    expect((await repo.cargarEdicionAdmin(itemId)).historial, isEmpty);
  });

  test('rechaza fechas inexistentes sin normalizarlas silenciosamente',
      () async {
    expect(
        await repo.editarAdmin(
            await cambio(CampoAdmin.fechaProduccion, '2026-02-30'),
            confirmar: true),
        isA<Err>());
    expect((await fila()).fechaEsperadaProduccion, isNull);
  });

  test('la corrección de recepción conserva su validación por lote', () async {
    final antes = await fila();
    expect(
        await repo.crearLote(
            items: [const ItemCantidad(itemId: itemId, cantidad: 5)],
            operario: 'TEST'),
        isA<Ok>());
    final lote = (await repo.watch().first).lotes.first;
    expect(lote.lineas.single.cantidadEnviada, 5);
    expect(
        await repo.editarAdmin(
            await cambio(CampoAdmin.recibido, antes.recibido + 5,
                lote: lote.lineas.single.id, ubicacion: 'ESTANTE A1'),
            confirmar: true),
        isA<Ok>());
    final despues = await fila();
    expect(despues.stockEn('ESTANTE A1'), antes.stockEn('ESTANTE A1') + 5);
    expect((await repo.watch().first).lotes.first.estado,
        EstadoLote.recibidoCompleto);
    expect(
        await repo.editarAdmin(
            await cambio(CampoAdmin.recibido, antes.recibido + 3,
                lote: lote.lineas.single.id, ubicacion: 'ESTANTE A1'),
            confirmar: true),
        isA<Ok>());
    expect((await repo.watch().first).lotes.first.lineas.single.enTransito,
        isTrue);
  });

  test('corregir PNC conserva el stock y las cantidades relacionadas',
      () async {
    final antes = await fila();
    expect(
        await repo.editarAdmin(
            await cambio(CampoAdmin.noConforme, antes.pendienteReproceso + 2,
                ubicacion: 'ESTANTE A1'),
            confirmar: true),
        isA<Ok>());
    final despues = await fila();
    expect(despues.producido, antes.producido - 2);
    expect(despues.recibido, antes.recibido - 2);
    expect(despues.stockEn('ESTANTE A1'), antes.stockEn('ESTANTE A1') - 2);
    expect(despues.stockDisponible,
        despues.ubicaciones.values.fold<int>(0, (a, b) => a + b));
  });

  test(
      'cliente cambia en todas las filas de la OP, manteniendo identificadores',
      () async {
    final antes = await fila();
    expect(
        await repo.editarAdmin(
            await cambio(CampoAdmin.cliente, 'Cliente corregido'),
            confirmar: true),
        isA<Ok>());
    final filas = (await repo.watch().first)
        .kardex
        .where((k) => k.item.op == antes.item.op);
    expect(filas.length, greaterThan(1));
    expect(filas.every((k) => k.item.cliente == 'Cliente corregido'), isTrue);
    expect((await fila()).id, itemId);
  });

  for (final cuenta in RolCuenta.values) {
    for (final vista in Rol.values) {
      testWidgets(
          'edición visible solo para admin: ${cuenta.name} / ${vista.name}',
          (tester) async {
        tester.view.physicalSize = const Size(2200, 1300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final snap = await repo.watch().first;
        await tester.pumpWidget(ProviderScope(
            overrides: [
              usarSupabaseProvider.overrideWithValue(true),
              usuarioSesionProvider.overrideWith((ref) async => UsuarioSesion(
                  numeroUsuario: '1', nombre: 'Test', rolCuenta: cuenta)),
              wmsRepositoryProvider.overrideWithValue(repo),
              wmsSnapshotProvider.overrideWith((ref) => Stream.value(snap)),
            ],
            child: const MaterialApp(
                home: Scaffold(
                    body: SingleChildScrollView(child: KardexTable())))));
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(KardexTable));
        final container = ProviderScope.containerOf(context);
        if (cuenta == RolCuenta.admin) {
          container.read(rolProvider.notifier).cambiar(vista);
        }
        await tester.pumpAndSettle();
        expect(
            find.byTooltip('Editar fila'),
            cuenta == RolCuenta.admin
                ? findsNWidgets(
                    container.read(kardexPaginaActualProvider).length)
                : findsNothing);
        expect(
            find.byIcon(Icons.delete_outline),
            cuenta == RolCuenta.admin
                ? findsNWidgets(
                    container.read(kardexPaginaActualProvider).length)
                : findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'edita el total entregado sin selector de lote y con confirmación',
      (tester) async {
    tester.view.physicalSize = const Size(2200, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          usarSupabaseProvider.overrideWithValue(true),
          usuarioSesionProvider.overrideWith((ref) async => const UsuarioSesion(
              numeroUsuario: '1', nombre: 'Admin', rolCuenta: RolCuenta.admin)),
          wmsRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
            home:
                Scaffold(body: SingleChildScrollView(child: KardexTable())))));
    await tester.pumpAndSettle();
    final filaEditada = ProviderScope.containerOf(tester.element(find.byType(KardexTable)))
        .read(kardexPaginaActualProvider).first;
    final objetivo = filaEditada.producido < filaEditada.cantidadPedida
        ? filaEditada.producido + 1 : filaEditada.recibido;
    await tester.tap(find.byTooltip('Editar fila').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<CampoAdmin>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entregado por Producción').last);
    await tester.pumpAndSettle();
    expect(find.text('Revisar cambios'), findsOneWidget);
    expect(find.text('Lote al que corresponde la diferencia'), findsNothing);
    final antes =
        (await repo.watch().first).kardex.map((k) => k.producido).toList();
    await tester.enterText(find.byType(TextField).first, '$objetivo');
    await tester.enterText(
        find.byType(TextField).last, 'Corrección verificada por administrador');
    await tester.tap(find.text('Revisar cambios'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar y guardar'), findsOneWidget);
    expect((await repo.watch().first).kardex.map((k) => k.producido).toList(),
        antes);
    await tester.tap(find.text('Confirmar y guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar y guardar'), findsNothing);
    expect(
        (await repo.watch().first).kardexPorId(filaEditada.id)!.producido, objetivo);
    expect(tester.takeException(), isNull);
  });
  test(
      'borrado conserva cantidades, lotes y otras filas; rechaza token obsoleto',
      () async {
    final antes = await repo.watch().first;
    final ctx = await repo.cargarEdicionAdmin(itemId);
    expect(await repo.eliminarLineaAdmin(itemId, 'obsoleto', 'Duplicado'),
        isA<Err>());
    expect(await repo.eliminarLineaAdmin(itemId, ctx.version, ''), isA<Err>());
    expect(await repo.eliminarLineaAdmin(itemId, ctx.version, 'Duplicado'),
        isA<Ok>());
    final despues = await repo.watch().first;
    expect(despues.kardex.length, antes.kardex.length);
    expect(despues.lotes, antes.lotes);
    expect(despues.kardexPorId(itemId)!.eliminada, isTrue);
    expect(despues.kardexPorId(itemId)!.stockDisponible,
        antes.kardexPorId(itemId)!.stockDisponible);
    expect(despues.kardex.where((k) => k.eliminada).length, 1);
    expect(await repo.eliminarLineaAdmin(itemId, ctx.version, 'Duplicado'),
        isA<Err>());
  });

  testWidgets(
      'cancelar no borra; confirmar oculta en ambas vistas y conserva datos',
      (tester) async {
    tester.view.physicalSize = const Size(2200, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          usarSupabaseProvider.overrideWithValue(false),
          wmsRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
            home:
                Scaffold(body: SingleChildScrollView(child: KardexTable())))));
    await tester.pumpAndSettle();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(KardexTable)));
    final total = container.read(kardexFiltradoProvider).length;
    final id = container.read(kardexPaginaActualProvider).first.id;
    await tester.tap(find.byTooltip('Borrar fila').first);
    await tester.pumpAndSettle();
    expect(find.text('Confirmar borrado'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(container.read(kardexFiltradoProvider).length, total);
    await tester.tap(find.byTooltip('Borrar fila').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Registro duplicado');
    await tester.tap(find.text('Confirmar borrado'));
    await tester.pumpAndSettle();
    expect(container.read(kardexFiltradoProvider).length, total - 1);
    container.read(rolProvider.notifier).cambiar(Rol.logistica);
    await tester.pumpAndSettle();
    expect(
        container.read(kardexFiltradoProvider).any((k) => k.id == id), isFalse);
    expect((await repo.watch().first).kardexPorId(id), isNotNull);
    expect(tester.takeException(), isNull);
  });
}


