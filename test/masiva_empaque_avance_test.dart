import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/features/masiva/masiva_repository.dart';
import 'package:orbiloq_wms/features/masiva/presentation/masiva_registrar_empaque_dialog.dart';

class EmpaqueFixture {
  final writes = <MasivaJson>[];
  Completer<void>? gate;
  bool fail = false;
  final kits = <MasivaJson>[
    {
      'id': 'k1',
      'numero_persona': 1,
      'nombre': 'Terminada',
      'armado': '2026-11-20T10:00:00Z',
      'empacador_id': 'a',
      'empacador': 'Operario A',
    },
    {
      'id': 'k2',
      'numero_persona': 2,
      'nombre': 'Persona Dos',
      'armado': null,
      'empacador_id': 'a',
      'empacador': 'Operario A',
    },
    {
      'id': 'k3',
      'numero_persona': 3,
      'nombre': 'Persona Tres',
      'armado': null,
      'empacador_id': null,
    },
    {
      'id': 'k4',
      'numero_persona': 4,
      'nombre': 'Persona Cuatro',
      'armado': null,
      'empacador_id': 'b',
      'empacador': 'Operario B',
    },
    {
      'id': 'k5',
      'numero_persona': 5,
      'nombre': 'Persona Cinco',
      'armado': null,
      'empacador_id': 'a',
      'empacador': 'Operario A',
    },
  ];
  Future<MasivaJson> consult(String list) async => {
    'lista': list,
    'total': kits.length,
    'terminados': kits.where((k) => k['armado'] != null).length,
    'pendientes': kits.where((k) => k['armado'] == null).length,
    'kits': kits.map((k) => {...k}).toList(),
    'asignaciones': [],
  };
  Future<void> save(MasivaJson data) async {
    writes.add({...data});
    await gate?.future;
    if (fail) throw const MasivaError('Conexión interrumpida de prueba');
    for (final k in kits) {
      if (k['armado'] != null ||
          (k['empacador_id'] != null &&
              k['empacador_id'] != data['empacador_id'])) {
        continue;
      }
      if (data['alcance'] == 'rango' &&
          ((k['numero_persona'] as int) < data['desde'] ||
              (k['numero_persona'] as int) > data['hasta'])) {
        continue;
      }
      k['armado'] = '2026-11-20T11:00:00Z';
      k['empacador_id'] = data['empacador_id'];
    }
  }
}

Future<void> mountEmpaque(
  WidgetTester tester,
  EmpaqueFixture repo,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.kardex(TemaModo.corporativo),
      home: Builder(
        builder:
            (context) => Scaffold(
              body: TextButton(
                onPressed:
                    () => showDialog<void>(
                      context: context,
                      builder:
                          (_) => MasivaRegistrarEmpaqueDialog(
                            people: const [
                              {'id': 'a', 'nombre': 'Operario A'},
                              {'id': 'b', 'nombre': 'Operario B'},
                            ],
                            initialLista: '88',
                            consultar: repo.consult,
                            registrar: repo.save,
                          ),
                    ),
                child: const Text('Abrir'),
              ),
            ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String key, String label) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester) async {
  final f = find.widgetWithText(FilledButton, 'Registrar terminados');
  final button = f.evaluate().isEmpty ? find.text('Registrar terminados') : f;
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets('pendientes conserva terminados y otros operarios a $width', (
      tester,
    ) async {
      final repo = EmpaqueFixture();
      await mountEmpaque(tester, repo, Size(width, 800));
      await choose(tester, 'empaque-persona', 'Operario A');
      expect(find.textContaining('ya terminados'), findsOneWidget);
      await choose(tester, 'empaque-alcance', 'Solo pendientes');
      expect(find.text('3 kits en el alcance seleccionado'), findsOneWidget);
      await submit(tester);
      await tester.pumpAndSettle();
      expect(repo.writes.single['alcance'], 'pendientes');
      expect(repo.writes.single['request_id'], isNotEmpty);
      expect(repo.kits.first['armado'], '2026-11-20T10:00:00Z');
      expect(repo.kits[3]['armado'], isNull);
      expect(find.text('Pendientes: 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('rango parcial valida extremos y no envía rango con otro dueño', (
    tester,
  ) async {
    final repo = EmpaqueFixture();
    await mountEmpaque(tester, repo, const Size(390, 800));
    await choose(tester, 'empaque-persona', 'Operario A');
    await choose(tester, 'empaque-alcance', 'Parcial · rango de personas');
    await tester.enterText(find.byKey(const ValueKey('empaque-desde')), '2');
    await tester.enterText(find.byKey(const ValueKey('empaque-hasta')), '4');
    await tester.pumpAndSettle();
    expect(find.textContaining('otro empacador'), findsWidgets);
    expect(repo.writes, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('empaque-hasta')), '3');
    await tester.pumpAndSettle();
    await submit(tester);
    await tester.pumpAndSettle();
    expect(repo.writes.single['desde'], 2);
    expect(repo.writes.single['hasta'], 3);
    expect(repo.kits[4]['armado'], isNull);
    expect(find.text('Pendientes: 2'), findsOneWidget);
  });
  testWidgets(
    'doble envío teclado bloqueado y error conserva borrador y UUID',
    (tester) async {
      final repo =
          EmpaqueFixture()
            ..fail = true
            ..gate = Completer<void>();
      await mountEmpaque(tester, repo, const Size(768, 800));
      await choose(tester, 'empaque-persona', 'Operario A');
      await choose(tester, 'empaque-alcance', 'Solo pendientes');
      await submit(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(repo.writes.length, 1);
      repo.gate!.complete();
      repo.gate = null;
      await tester.pumpAndSettle();
      expect(find.text('Conexión interrumpida de prueba'), findsOneWidget);
      expect(find.text('3 kits en el alcance seleccionado'), findsOneWidget);
      final request = repo.writes.single['request_id'];
      repo.fail = false;
      await submit(tester);
      await tester.pumpAndSettle();
      expect(repo.writes.length, 2);
      expect(repo.writes.last['request_id'], request);
      expect(tester.takeException(), isNull);
    },
  );
}
