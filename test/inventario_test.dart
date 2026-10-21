import 'package:orbiloq_wms/data/destinatarios_empaque.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/data/despachos_oc_repository.dart';
import 'package:orbiloq_wms/data/inventario_repository.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/domain/sesion.dart';
import 'package:orbiloq_wms/features/inventario/presentation/inventario_page.dart';

class InventarioPrueba implements InventarioRepository {
  final consultas = <(String, int)>[];
  final detalles = <InventarioFila>[];
  @override
  Future<List<InventarioFila>> filas(
    String funcion,
    InventarioFila parametros,
  ) async {
    expect(funcion, 'inventario_detalle_talla');
    detalles.add(parametros);
    return [
      {
        'id': 'transferencia-1',
        'item_id': 'item-1',
        'ficha': 'FICHA V0',
        'talla': 'M',
        'numero_op': '123',
        'producto': 'CAMISA',
        'cliente': 'CLIENTE A',
        'ubicacion': 'A1',
        'cantidad': 35,
        'libre': 35,
        'reservado': 0,
        'despachado': 0,
        'revertido': 0,
        'fecha': '2026-10-19',
        'motivo': 'Recepción',
      },
    ];
  }

  @override
  Future<InventarioFila> listar(String buscar, int pagina) async {
    consultas.add((buscar, pagina));
    return {
      'total': 26,
      'filas': [
        {
          'ficha': 'FICHA V0',
          'talla': 'M',
          'producto': 'CAMISA',
          'cliente': 'CLIENTE A',
          'pendiente_producir': 12,
          'bodega': 40,
          'libre': 35,
          'reservado': 5,
          'despachado': 20,
        },
      ],
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class ExcelPrueba extends InventarioPrueba {
  final operaciones = <InventarioFila>[];
  bool eliminado = false;
  @override
  Future<List<InventarioFila>> filas(String f, InventarioFila p) async {
    if (eliminado) return [];
    return [
      for (final r in await super.filas(f, p)) {...r, 'entrada_excel': true},
    ];
  }

  @override
  Future<dynamic> ejecutar(String f, InventarioFila p) async {
    expect(f, 'inventario_eliminar_excel');
    operaciones.add(p);
    eliminado = true;
    return 'transferencia-1';
  }
}

class InventarioFiltroPrueba extends InventarioPrueba {
  @override
  Future<InventarioFila> listar(String buscar, int pagina) async {
    final base = await super.listar(buscar, pagina);
    final r = (base['filas'] as List).first as InventarioFila;
    return {
      'total': 26,
      'filas':
          pagina == 0
              ? [
                for (var i = 0; i < 25; i++) {...r, 'talla': 'M'},
              ]
              : [
                {...r, 'talla': 'ESPECIAL', 'libre': 7},
              ],
    };
  }
}

class InventarioMultiplePrueba extends InventarioPrueba {
  List<InventarioFila>? seleccion;
  @override
  Future<InventarioFila> listar(String buscar, int pagina) async {
    final r =
        ((await super.listar(buscar, pagina))['filas'] as List).first
            as InventarioFila;
    return {
      'total': 26,
      'filas':
          pagina == 0
              ? [
                r,
                {...r, 'cliente': 'CLIENTE B', 'ficha': 'OTRO'},
              ]
              : [
                {...r, 'ficha': 'FICHA V1', 'talla': 'L'},
              ],
    };
  }

  @override
  Future<List<InventarioFila>> filas(String f, InventarioFila p) async {
    if (f != 'inventario_preparar_despacho') return super.filas(f, p);
    seleccion = (p['p_seleccion'] as List).cast<InventarioFila>();
    return [
      for (var i = 0; i < seleccion!.length; i++)
        {
          ...seleccion![i],
          'id': 't$i',
          'item_id': 'i$i',
          'numero_op': '$i',
          'producto': 'CAMISA',
          'ubicacion': 'A',
          'libre': seleccion![i]['cantidad'],
        },
    ];
  }
}

void main() {
  testWidgets('Selección múltiple conserva páginas y limita el cliente', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = InventarioMultiplePrueba();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventarioRepositoryProvider.overrideWithValue(repo),
          usuarioSesionProvider.overrideWith(
            (ref) async => const UsuarioSesion(
              numeroUsuario: '1',
              nombre: 'Admin',
              rolCuenta: RolCuenta.admin,
            ),
          ),
        ],
        child: const MaterialApp(home: InventarioPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Checkbox>(find.byType(Checkbox).at(2)).onChanged,
      isNull,
    );
    await tester.ensureVisible(find.byTooltip('Siguiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Siguiente'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    expect(find.text('2 prendas seleccionadas · CLIENTE A'), findsOneWidget);
    await tester.ensureVisible(find.text('Despachar seleccionadas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Despachar seleccionadas'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('cantidad-seleccion-0')),
      '4',
    );
    await tester.enterText(
      find.byKey(const ValueKey('cantidad-seleccion-1')),
      '3',
    );
    await tester.tap(find.text('Continuar al despacho'));
    await tester.pumpAndSettle();
    expect(repo.seleccion!.map((r) => r['cantidad']), [4, 3]);
    expect(find.text('Despacho desde inventario'), findsWidgets);
    expect(find.text('7 unidades'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Filtros alcanzan otras páginas, combinan cantidades y se limpian',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = InventarioFiltroPrueba();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventarioRepositoryProvider.overrideWithValue(repo),
            usuarioSesionProvider.overrideWith(
              (ref) async => const UsuarioSesion(
                numeroUsuario: '1',
                nombre: 'Bodega',
                rolCuenta: RolCuenta.logistica,
              ),
            ),
          ],
          child: const MaterialApp(home: InventarioPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Filtrar por Talla'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filtrar por Talla'));
      await tester.pumpAndSettle();
      expect(repo.consultas, contains(('', 1)));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'ESPECIAL'));
      await tester.tap(find.text('APLICAR FILTRO'));
      await tester.pumpAndSettle();
      expect(find.text('ESPECIAL'), findsOneWidget);
      expect(find.text('Página 1 · 1 resultados'), findsOneWidget);
      await tester.ensureVisible(
        find.byTooltip('Filtrar por Stock disponible'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filtrar por Stock disponible'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, '35'));
      await tester.tap(find.text('APLICAR FILTRO'));
      await tester.pumpAndSettle();
      expect(find.text('No hay prendas para esta búsqueda.'), findsOneWidget);
      await tester.ensureVisible(find.text('Limpiar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpiar'));
      await tester.pumpAndSettle();
      expect(find.text('Página 1 · 25 resultados'), findsOneWidget);
      expect(find.textContaining('filtros de columna activos'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final rol in [RolCuenta.admin, RolCuenta.logistica]) {
    testWidgets('Eliminar Excel solo administrador: $rol', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = ExcelPrueba();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventarioRepositoryProvider.overrideWithValue(repo),
            usuarioSesionProvider.overrideWith(
              (ref) async => UsuarioSesion(
                numeroUsuario: '1',
                nombre: 'Prueba',
                rolCuenta: rol,
              ),
            ),
          ],
          child: const MaterialApp(home: InventarioPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('FICHA V0'));
      await tester.pumpAndSettle();
      if (rol != RolCuenta.admin) {
        expect(find.text('Eliminar entrada Excel'), findsNothing);
        return;
      }
      await tester.tap(find.text('Eliminar entrada Excel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar eliminación'));
      await tester.pumpAndSettle();
      expect(repo.operaciones, isEmpty);
      final motivo = find.descendant(
        of: find.byType(AlertDialog).last,
        matching: find.byType(TextField),
      );
      await tester.enterText(motivo, 'Cantidad importada por error');
      await tester.tap(find.text('Confirmar eliminación'));
      await tester.pumpAndSettle();
      expect(repo.operaciones.single['p_transferencia'], 'transferencia-1');
      expect(
        repo.operaciones.single['p_motivo'],
        'Cantidad importada por error',
      );
      expect(find.text('Eliminar entrada Excel'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  test(
    'Stock libre de OP excluye inventario y sus reservas no se duplican',
    () {
      const item = ItemOrden(
        id: 'i',
        op: '1',
        cliente: 'A',
        oc: 'OC',
        codigo: 'X',
        descripcion: 'Camisa',
        talla: 'M',
        cantidadPedida: 100,
      );
      const kardex = ItemKardex(
        item: item,
        producido: 100,
        recibido: 100,
        despachado: 20,
        stockInventario: 40,
        ubicaciones: {'A': 40},
        reservas: {'A': 5},
      );
      expect(kardex.stockDisponible, 40);
      expect(kardex.disponibleParaDespacho, 35);
      expect(kardex.disponibleEn('A'), 35);
      expect(
        () => planificarDespacho([kardex], {'i': 36}),
        throwsFormatException,
      );
      expect(planificarDespacho([kardex], {'i': 35}).single['cantidad'], 35);
    },
  );
  for (final ancho in [390.0, 1440.0]) {
    testWidgets('Inventario responsive y permisos en $ancho', (tester) async {
      tester.view.physicalSize = Size(ancho, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = InventarioPrueba();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventarioRepositoryProvider.overrideWithValue(repo),
            destinatariosEmpaqueProvider.overrideWith(
              (ref) async => [
                {
                  'id': 'destino-prueba',
                  'version': '1',
                  'datos': {
                    'nombre': 'CLIENTE A',
                    'sede': 'Sede Norte',
                    'ciudad': 'Bogotá',
                    'direccion': 'Calle 10',
                  },
                },
              ],
            ),
            usuarioSesionProvider.overrideWith(
              (ref) async => const UsuarioSesion(
                numeroUsuario: '1',
                nombre: 'Bodega',
                rolCuenta: RolCuenta.logistica,
              ),
            ),
          ],
          child: const MaterialApp(home: InventarioPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('FICHA V0'), findsOneWidget);
      expect(find.text('Control de inventario'), findsOneWidget);
      expect(find.text('UNIDADES EN LA PÁGINA ACTUAL'), findsOneWidget);
      if (ancho >= 800) {
        expect(find.text('Ficha técnica'), findsOneWidget);
        expect(find.text('Producto'), findsOneWidget);
      }
      expect(find.text('Transferir desde OP'), findsOneWidget);
      expect(find.text('Importar inventario Excel'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              (w is Text && w.data == 'Despachar') ||
              (w is Tooltip && w.message == 'Despachar'),
        ),
        findsNothing,
      );
      final error = tester.takeException();
      if (error is FlutterError) debugPrint(error.toStringDeep());
      expect(error, isNull);
      await tester.enterText(find.byType(TextField), 'CAMISA');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(repo.consultas.last, ('CAMISA', 0));
      await tester.ensureVisible(find.byTooltip('Siguiente'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Siguiente'));
      await tester.pumpAndSettle();
      expect(repo.consultas.last, ('CAMISA', 1));
    });
  }
  testWidgets('Producción consulta sin permiso de transferir', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventarioRepositoryProvider.overrideWithValue(InventarioPrueba()),
          usuarioSesionProvider.overrideWith(
            (ref) async => const UsuarioSesion(
              numeroUsuario: '2',
              nombre: 'Producción',
              rolCuenta: RolCuenta.produccion,
            ),
          ),
        ],
        child: const MaterialApp(home: InventarioPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Transferir desde OP'), findsNothing);
    expect(find.text('Importar inventario Excel'), findsNothing);
    expect(find.text('FICHA V0'), findsOneWidget);
  });
  for (final ancho in [390.0, 1440.0]) {
    testWidgets('Despacho selecciona prenda y abre sus tallas en $ancho', (
      tester,
    ) async {
      tester.view.physicalSize = Size(ancho, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = InventarioPrueba();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventarioRepositoryProvider.overrideWithValue(repo),
            destinatariosEmpaqueProvider.overrideWith(
              (ref) async => [
                {
                  'id': 'destino-prueba',
                  'version': '1',
                  'datos': {
                    'nombre': 'CLIENTE A',
                    'sede': 'Sede Norte',
                    'ciudad': 'Bogotá',
                    'direccion': 'Calle 10',
                  },
                },
              ],
            ),
            usuarioSesionProvider.overrideWith(
              (ref) async => const UsuarioSesion(
                numeroUsuario: '3',
                nombre: 'Despacho',
                rolCuenta: RolCuenta.despacho,
              ),
            ),
          ],
          child: const MaterialApp(home: InventarioPage()),
        ),
      );
      await tester.pumpAndSettle();
      final boton = find.byWidgetPredicate(
        (w) =>
            (w is Text && w.data == 'Despachar') ||
            (w is Tooltip && w.message == 'Despachar'),
      );
      await tester.ensureVisible(boton);
      await tester.pumpAndSettle();
      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(repo.detalles.single['p_ficha'], 'FICHA V0');
      expect(repo.detalles.single['p_talla'], 'M');
      expect(repo.detalles.single['p_cliente'], 'CLIENTE A');
      expect(find.text('Transferencia desde OP 123'), findsOneWidget);
      expect(find.text('Seleccionar para despacho'), findsOneWidget);
      expect(find.text('Devolver a OP original'), findsNothing);
      await tester.ensureVisible(find.text('Seleccionar para despacho'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seleccionar para despacho'));
      await tester.pumpAndSettle();
      expect(find.text('Despachos por orden de compra'), findsNothing);
      expect(find.text('Despacho desde inventario'), findsWidgets);
      expect(find.text('Orden de compra de destino'), findsOneWidget);
      expect(find.text('Destino'), findsOneWidget);
      expect(find.text('Prendas'), findsOneWidget);
      expect(find.text('Empaques'), findsOneWidget);
      expect(find.text('Confirmar'), findsOneWidget);
      expect(find.text('Seleccionar para despacho'), findsNothing);
      await tester.ensureVisible(
        find.text('Buscar y seleccionar destinatario o sede'),
      );
      await tester.tap(find.text('Buscar y seleccionar destinatario o sede'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText == 'Buscar destinatario o sede',
        ),
        'Sede Norte',
      );
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsOneWidget);
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(find.text('Calle 10'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Orden de compra de destino'),
        'OC NUEVA',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Elegir prendas'));
      await tester.tap(find.text('Elegir prendas'));
      await tester.pumpAndSettle();
      expect(find.textContaining('35 en bodega'), findsWidgets);
      await tester.ensureVisible(find.text('Armar empaques'));
      await tester.tap(find.text('Armar empaques'));
      await tester.pumpAndSettle();
      expect(find.text('Revisar empaque'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
