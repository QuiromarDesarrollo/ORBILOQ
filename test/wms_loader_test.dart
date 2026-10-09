import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';

void main() {
  testWidgets('Modos, porcentaje real, animación y liberación del ticker', (tester) async {
    for (final mode in OrbiloqLoaderMode.values) {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: WmsLoader(mode: mode, value: mode == OrbiloqLoaderMode.progress ? .45 : null))));
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('Movimiento reducido, progreso accesible y móvil', (tester) async {
    final semantics = tester.ensureSemantics();

    tester.view.physicalSize = const Size(320,640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: MediaQuery(data: MediaQueryData(size: Size(320,640),disableAnimations:true), child: Scaffold(body: WmsLoadingPanel(value:.45)))));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
    final node = tester.getSemantics(find.byType(WmsLoader));
    expect(node.value, '45%');
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Vista de las variantes Orbiloq', (tester) async {
    tester.view.physicalSize = const Size(800,650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('Roboto')..addFont(rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'));
    await font.load();
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RepaintBoundary(key:key,child: const ColoredBox(color:Colors.white,child: Center(child: Column(mainAxisSize:MainAxisSize.min,children:[
      Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[WmsLoader(width:260,mode:OrbiloqLoaderMode.orbit),WmsLoader(width:260,mode:OrbiloqLoaderMode.progress,value:.45)]),
      SizedBox(height:40), WmsLoadingStrip(label:'Guardando cambios…'), SizedBox(height:24), WmsLoader(),
    ])))))));
    await tester.pump(const Duration(milliseconds:500));
    await tester.runAsync(() async {
    final boundary=key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image=await boundary.toImage();
    final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
    await File('.dart_tool/orbiloq_loaders.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
  });
}
