import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/features/produccion/presentation/entrega_produccion_dialog.dart';
import 'package:orbiloq_wms/features/recepcion/presentation/recepcion_dialog.dart';
import 'package:orbiloq_wms/features/no_conforme/presentation/no_conforme_dialog.dart';
import 'package:orbiloq_wms/features/despacho/presentation/despacho_dialog.dart';
import 'package:orbiloq_wms/shared/widgets/wms_scan_field.dart';
import 'package:orbiloq_wms/shared/widgets/wms_camera_scanner.dart';

const qrS = 'https://etiqueta?19249;2025289515;TSHIRT;ENEL;ORD-001-ENE;1';
const qrBata = 'https://etiqueta?18353;CLSBAOCD20;BATA;COLSUBSIDIO;OC-9920;2';

void main() {
  for (final dialog in [
    const EntregaProduccionDialog(),
    const RecepcionDialog(),
    const NoConformeDialog(),
  ]) {
    testWidgets(
      '${dialog.runtimeType}: acumula tarjetas y rechaza QR sin guardar movimientos',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = InMemoryWmsRepository.seeded();
        addTearDown(repo.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              usarSupabaseProvider.overrideWithValue(false),
              wmsRepositoryProvider.overrideWithValue(repo),
            ],
            child: MaterialApp(home: Scaffold(body: dialog)),
          ),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(dialog.runtimeType)),
        );
        final antes = container.read(wmsSnapshotProvider).value!;
        final botonCamara = find.text('Escanear con cámara');
        await tester.ensureVisible(botonCamara);
        await tester.pumpAndSettle();
        await tester.tap(botonCamara);
        await tester.pump(const Duration(milliseconds: 500));
        final campo = tester.widget<WmsCameraScanner>(
          find.byType(WmsCameraScanner),
        );
        final uno = await campo.onRead(qrS);
        await tester.pump(const Duration(milliseconds: 500));
        final dos = await campo.onRead(qrBata);
        await tester.pump(const Duration(milliseconds: 500));
        final tres = await campo.onRead(qrS);
        await tester.pump(const Duration(milliseconds: 500));
        expect(uno.isError, false);
        expect(dos.isError, false);
        expect(tres.text, contains('2 Uds'));
        final invalido = await campo.onRead('invalido');
        await tester.pump(const Duration(milliseconds: 500));
        expect(invalido.isError, true);
        expect(container.read(wmsSnapshotProvider).value, same(antes));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('Despacho no reemplaza la selección por una lectura de otra OC', (
    tester,
  ) async {
    final repo = InMemoryWmsRepository.seeded();
    addTearDown(repo.dispose);
    final snapshot = await repo.cargarSnapshot();
    final linea = snapshot.lotes
        .expand((l) => l.lineas)
        .firstWhere((l) => l.item.op == '18353');
    await repo.recibirLoteLinea(
      loteLineaId: linea.id,
      cantidad: 5,
      ubicacion: 'ESTANTE A1',
      recibidoPor: 'Prueba',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          usarSupabaseProvider.overrideWithValue(false),
          wmsRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: Scaffold(body: DespachoDialog())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ENEL').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir prendas'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Escribir código'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escribir código'));
    await tester.pumpAndSettle();
    final campo = tester.widget<WmsScanField>(find.byType(WmsScanField).first);
    expect((await campo.onCameraSubmitted!(qrS)).isError, false);
    await tester.pumpAndSettle();
    final otra = await campo.onCameraSubmitted!(qrBata);
    expect(otra.isError, true);
    expect(otra.text, contains('otra OC'));
    await tester.pumpAndSettle();
    expect((await campo.onCameraSubmitted!(qrS)).isError, false);
    await tester.pumpWidget(const SizedBox());
  });
}
