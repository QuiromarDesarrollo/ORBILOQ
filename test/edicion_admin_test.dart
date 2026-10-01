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

const itemId = '19249|ORD-001-ENE|2025289515|S';

void main() {
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

  test('corrige el total incluso a cero sin cambiar lotes ni stock', () async {
    final antes = await fila();
    final lotesAntes = (await repo.cargarEdicionAdmin(itemId)).lotes;
    for (final total in [10, 2, 0, 20]) {
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
      expect((await repo.cargarEdicionAdmin(itemId)).lotes, lotesAntes);
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
            find.byIcon(Icons.edit_outlined),
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
    await tester.enterText(find.byType(TextField).first, '2');
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
        (await repo.watch().first).kardex.any((k) => k.producido == 2), isTrue);
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
