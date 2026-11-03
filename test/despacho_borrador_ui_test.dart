import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/data/despacho_borrador_repository.dart';
import 'package:orbiloq_wms/data/despachos_oc_repository.dart';
import 'package:orbiloq_wms/data/destinatarios_empaque.dart';
import 'package:orbiloq_wms/data/empaques_repository.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/domain/sesion.dart';
import 'package:orbiloq_wms/features/despacho/presentation/despacho_dialog.dart';

class _Borradores implements DespachoBorradorRepository {
  Map<String, dynamic>? registro;
  bool fallar = false;
  bool fallarCarga = false;
  int guardados = 0;
  int eliminados = 0;
  final cargas = <String>[];
  final datosGuardados = <Map<String, dynamic>>[];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<Map<String, dynamic>?> cargar(String clave) async {
    cargas.add(clave);
    if (fallarCarga) throw Exception('No se pudo leer');
    return registro;
  }

  @override
  Future<Map<String, dynamic>> guardar(
    String clave,
    Map<String, dynamic> datos, {
    int version = 0,
  }) async {
    if (fallar) throw Exception('Sin conexión');
    expect(clave, 'correccion:d1');
    expect(version, registro?['version'] ?? 0);
    guardados++;
    registro = {'version': version + 1, 'datos': jsonDecode(jsonEncode(datos))};
    datosGuardados.add(Map<String, dynamic>.from(registro!['datos']));
    return registro!;
  }

  @override
  Future<void> eliminar(String clave, {required int version}) async {
    expect(clave, 'correccion:d1');
    expect(version, registro!['version']);
    eliminados++;
    registro = null;
  }
}

class _Despachos implements DespachosOcRepository {
  final solicitudes = <String>[];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<List<Map<String, dynamic>>> historial() async => [];

  @override
  Future<void> corregir(
    String id,
    String version,
    String solicitud,
    String motivo,
    String cliente,
    String oc,
    List<Map<String, dynamic>> lineas,
    List<Map<String, dynamic>> empaques, {
    String? destinatarioId,
    String? destinatarioVersion,
    String? ocDocumento,
  }) async {
    solicitudes.add(solicitud);
  }
}

Future<void> _montar(
  WidgetTester tester,
  _Borradores borradores, {
  _Despachos? despachos,
}) async {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  await (FontLoader('Roboto')..addFont(
    rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'),
  )).load();
  await (FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repo = InMemoryWmsRepository.seeded();
  addTearDown(repo.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        usarSupabaseProvider.overrideWithValue(false),
        despachoBorradorRepositoryProvider.overrideWithValue(borradores),
        usuarioSesionProvider.overrideWith(
          (ref) async => const UsuarioSesion(
            numeroUsuario: '1',
            nombre: 'Administrador',
            rolCuenta: RolCuenta.admin,
          ),
        ),
        wmsRepositoryProvider.overrideWithValue(repo),
        despachosOcProvider.overrideWithValue(despachos ?? _Despachos()),
        destinatariosEmpaqueProvider.overrideWith((ref) async => []),
        empaquesProvider.overrideWith(
          (ref) async => [
            {
              'id': 'caja1',
              'nombre': 'Caja prueba',
              'categoria': 'CAJA',
              'version': 'v1',
              'alto_cm': 10,
              'ancho_cm': 20,
              'largo_cm': 30,
            },
          ],
        ),
        wmsSnapshotProvider.overrideWith(
          (ref) => Stream.value(
            WmsSnapshot(
              kardex: [
                ItemKardex(
                  item: ItemOrden(
                    id: 'i',
                    op: '1',
                    cliente: 'Cliente',
                    oc: 'OC1',
                    codigo: 'C',
                    descripcion: 'Camisa',
                    talla: 'M',
                    cantidadPedida: 10,
                  ),
                  producido: 10,
                  recibido: 10,
                  despachado: 0,
                  ubicaciones: {'A': 10},
                ),
              ],
              lotes: [],
            ),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder:
            (context, child) => RepaintBoundary(
              key: const ValueKey('captura-borrador'),
              child: child,
            ),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed:
                      () => showDialog<void>(
                        context: context,
                        builder:
                            (_) => const DespachoDialog(
                              correccion: {
                                'id': 'd1',
                                'version': 'v1',
                                'cliente': 'Cliente',
                                'oc': 'OC1',
                                'detalle': [
                                  {'op': '1'},
                                ],
                                'empaques': [
                                  {
                                    'id': 'caja1',
                                    'item_id': 'i',
                                    'numero': 1,
                                    'cantidad': 3,
                                  },
                                ],
                              },
                            ),
                      ),
                  child: const Text('Abrir despacho'),
                ),
              ),
        ),
      ),
    ),
  );
  await _abrir(tester);
}

Future<void> _abrir(WidgetTester tester) async {
  await tester.tap(find.text('Abrir despacho'));
  await tester.pumpAndSettle();
}

Finder get _cantidad => find.widgetWithText(TextFormField, 'Prendas');
Future<void> _editar(WidgetTester tester, String valor) async {
  await tester.ensureVisible(_cantidad);
  await tester.enterText(_cantidad, valor);
  await tester.pumpAndSettle();
}

Future<void> _cerrar(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Cerrar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Cerrar sin edición no pide guardar ni escribe', (tester) async {
    final repo = _Borradores();
    await _montar(tester, repo);
    await _cerrar(tester);
    expect(find.text('¿Deseas guardar los cambios?'), findsNothing);
    expect(find.byType(DespachoDialog), findsNothing);
    expect(repo.guardados, 0);
    expect(repo.eliminados, 0);
  });

  testWidgets(
    'Carga fallida bloquea edición; reintento o cierre son accesibles',
    (tester) async {
      final repo = _Borradores()..fallarCarga = true;
      await _montar(tester, repo);
      expect(
        find.textContaining('No se pudo recuperar el borrador'),
        findsOneWidget,
      );
      final bloqueo = find.ancestor(
        of: _cantidad,
        matching: find.byType(AbsorbPointer),
      );
      expect(
        tester.widgetList<AbsorbPointer>(bloqueo).any((w) => w.absorbing),
        isTrue,
      );
      await _cerrar(tester);
      expect(find.byType(DespachoDialog), findsNothing);
      expect(repo.guardados, 0);
      await _abrir(tester);
      repo.fallarCarga = false;
      await tester.tap(find.text('Reintentar borrador'));
      await tester.pumpAndSettle();
      expect(repo.cargas.length, 3);
      expect(
        find.textContaining('No se pudo recuperar el borrador'),
        findsNothing,
      );
      expect(
        tester.widgetList<AbsorbPointer>(bloqueo).any((w) => w.absorbing),
        isFalse,
      );
      await _editar(tester, '4');
      expect(find.text('4 prendas · 1 empaques'), findsOneWidget);
    },
  );

  testWidgets(
    'Confirmar corrección elimina borrador y persiste solicitud antes de enviar',
    (tester) async {
      final repo = _Borradores();
      final despachos = _Despachos();
      await _montar(tester, repo, despachos: despachos);
      await _editar(tester, '4');
      final peso = find.widgetWithText(TextFormField, 'Peso bruto (kg) *');
      await tester.ensureVisible(peso);
      await tester.enterText(peso, '12.5');
      await tester.pumpAndSettle();
      await _cerrar(tester);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      await _abrir(tester);
      await tester.ensureVisible(find.text('Revisar empaque'));
      await tester.tap(find.text('Revisar empaque'));
      await tester.pumpAndSettle();
      final motivo = find.widgetWithText(
        TextField,
        'Motivo de la corrección (obligatorio)',
      );
      await tester.ensureVisible(motivo);
      await tester.enterText(motivo, 'Cantidad actualizada');
      await tester.ensureVisible(find.text('Confirmar empaque'));
      await tester.tap(find.text('Confirmar empaque'));
      await tester.pumpAndSettle();
      expect(despachos.solicitudes, hasLength(1));
      expect(repo.guardados, 2);
      expect(
        repo.datosGuardados.last['solicitud'],
        despachos.solicitudes.single,
      );
      expect(repo.datosGuardados.last['pendiente'], isNotEmpty);
      expect(repo.eliminados, 1);
      expect(repo.registro, isNull);
      expect(find.byType(DespachoDialog), findsNothing);
    },
  );
  testWidgets(
    'Cancelar cierre conserva cantidades; No guardar descarta edición',
    (tester) async {
      final repo = _Borradores();
      await _montar(tester, repo);
      await _editar(tester, '4');
      await _cerrar(tester);
      expect(find.text('¿Deseas guardar los cambios?'), findsOneWidget);
      final captura = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('captura-borrador')),
      );
      captura.markNeedsPaint();
      await tester.pump();
      await tester.runAsync(() async {
        final imagen = await captura.toImage();
        final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
        await Directory('output/verificaciones').create(recursive: true);
        await File(
          'output/verificaciones/despacho-aviso-borrador.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        imagen.dispose();
      });
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(DespachoDialog), findsOneWidget);
      expect(find.text('4 prendas · 1 empaques'), findsOneWidget);
      await _cerrar(tester);
      await tester.tap(find.text('No guardar'));
      await tester.pumpAndSettle();
      expect(find.byType(DespachoDialog), findsNothing);
      expect(repo.guardados, 0);
      await _abrir(tester);
      expect(find.text('3 prendas · 1 empaques'), findsOneWidget);
    },
  );

  testWidgets('Guardar recupera cantidades y pesos en una instancia nueva', (
    tester,
  ) async {
    final repo = _Borradores();
    await _montar(tester, repo);
    await _editar(tester, '4');
    final peso = find.widgetWithText(TextFormField, 'Peso bruto (kg) *');
    await tester.ensureVisible(peso);
    await tester.enterText(peso, '12.5');
    await tester.pumpAndSettle();
    await _cerrar(tester);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.byType(DespachoDialog), findsNothing);
    expect(repo.guardados, 1);
    await _abrir(tester);
    expect(repo.cargas, ['correccion:d1', 'correccion:d1']);
    expect(find.text('4 prendas · 1 empaques'), findsOneWidget);
    expect(tester.widget<TextFormField>(peso).initialValue, '12.5');
    await _editar(tester, '5');
    await _cerrar(tester);
    await tester.tap(find.text('No guardar'));
    await tester.pumpAndSettle();
    await _abrir(tester);
    expect(find.text('4 prendas · 1 empaques'), findsOneWidget);
    expect(repo.guardados, 1);
  });

  testWidgets(
    'Error guardando mantiene el trabajo abierto y permite reintentar',
    (tester) async {
      final repo = _Borradores()..fallar = true;
      await _montar(tester, repo);
      await _editar(tester, '4');
      await _cerrar(tester);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.byType(DespachoDialog), findsOneWidget);
      expect(
        find.textContaining('Tus cambios siguen abiertos'),
        findsOneWidget,
      );
      expect(repo.guardados, 0);
      await tester.tap(find.text('Cerrar aviso'));
      await tester.pumpAndSettle();
      expect(find.text('4 prendas · 1 empaques'), findsOneWidget);
      repo.fallar = false;
      await _cerrar(tester);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.byType(DespachoDialog), findsNothing);
      expect(repo.guardados, 1);
    },
  );
}
