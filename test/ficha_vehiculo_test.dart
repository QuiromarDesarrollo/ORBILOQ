import 'package:orbiloq_wms/features/conductor/presentation/vista_evidencia_drive.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/conductor/conductor_model.dart';
import 'package:orbiloq_wms/features/conductor/conductor_repository.dart';
import 'package:orbiloq_wms/features/conductor/ficha_vehiculo.dart';
import 'package:orbiloq_wms/features/conductor/presentation/conductor_design.dart';
import 'package:orbiloq_wms/features/conductor/presentation/ficha_vehiculo_view.dart';
import 'package:orbiloq_wms/features/conductor/presentation/registro_conductor.dart';

class _Repo extends ConductorRepository {
  _Repo() : super(null);
  Map<String, dynamic>? datos;
  @override
  Future<void> guardar(
    String id,
    String tipo,
    int km,
    Map<String, dynamic> datos,
  ) async {
    this.datos = datos;
  }
}

const vehiculo = VehiculoConductor(
  id: 'demo',
  placa: 'TEST01',
  descripcion: 'Vehículo de prueba',
  km: 12000,
  datos: {
    'SOAT': '2027-03-15',
    'marca': 'Marca de prueba',
    'precio_compra': '0',
    'foto_frontal': 'https://drive.google.com/file/d/test/view',
  },
);
void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('Ficha completa, pestañas y diseño a $width', (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await (FontLoader('ConductorSans')
            ..addFont(
              rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'),
            )
            ..addFont(rootBundle.load('assets/fonts/LiberationSans-Bold.ttf')))
          .load();
      await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ConductorDesign.theme(),
            home: RepaintBoundary(
              key: boundary,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FichaVehiculoView(
                      vehiculo: vehiculo,
                      conductor: 'Conductor de prueba',
                      onEditar: () {},
                      onHistorial: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final campo in fichaVehiculoCampos.values.expand((e) => e)) {
        expect(find.text(campo.label), findsOneWidget);
      }
      expect(find.text('Marca de prueba'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Sin registrar'), findsWidgets);
      expect(find.text('Abrir original en Drive'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '.dart_tool/ficha-vehiculo-${width.toInt()}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Conductor'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Conductor'));
      await tester.pumpAndSettle();
      expect(find.text('Conductor actual'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Documentos'));
      await tester.pumpAndSettle();
      expect(find.text('SOAT'), findsOneWidget);
      expect(find.text('Vigencia desde'), findsNWidgets(4));
      expect(find.byType(VistaEvidenciaDrive), findsNWidgets(5));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Guardar ficha incluye nuevos datos y conserva vencimientos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Repo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [conductorRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: RegistroConductorPage(vehiculo: vehiculo, tipo: 'Documentos'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final marca = find.byKey(const ValueKey('campo-marca'));
    await tester.ensureVisible(marca);
    await tester.pumpAndSettle();
    await tester.enterText(marca, 'Nueva marca');
    final capacidad = find.byKey(const ValueKey('campo-capacidad_toneladas'));
    await tester.scrollUntilVisible(
      capacidad,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(capacidad, '1.5');
    await tester.tap(find.text('Guardar registro'));
    await tester.pumpAndSettle();
    expect(repo.datos?['marca'], 'Nueva marca');
    expect(repo.datos?['capacidad_toneladas'], '1.5');
    expect(repo.datos?['SOAT'], '2027-03-15');
    expect(repo.datos?['precio_compra'], '0');
    expect(
      repo.datos?.containsKey('foto_frontal'),
      isFalse,
      reason:
          'Sin foto nueva, el merge del servidor conserva el enlace anterior',
    );
    expect(tester.takeException(), isNull);
  });
}
