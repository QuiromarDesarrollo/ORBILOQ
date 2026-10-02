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

const qrS = 'https://etiqueta?19249;2025289515;TSHIRT;ENEL;ORD-001-ENE;1';
const qrBata = 'https://etiqueta?18353;CLSBAOCD20;BATA;COLSUBSIDIO;OC-9920;2';

void main() {
  for (final dialog in [
    const EntregaProduccionDialog(),
    const RecepcionDialog(),
    const NoConformeDialog()
  ]) {
    testWidgets(
        '${dialog.runtimeType}: acumula tarjetas y rechaza QR sin guardar movimientos',
        (tester) async {
      final repo = InMemoryWmsRepository.seeded();
      addTearDown(repo.dispose);
      await tester.pumpWidget(ProviderScope(overrides: [
        usarSupabaseProvider.overrideWithValue(false),
        wmsRepositoryProvider.overrideWithValue(repo),
      ], child: MaterialApp(home: Scaffold(body: dialog))));
      await tester.pumpAndSettle();
      final campo =
          tester.widget<WmsScanField>(find.byType(WmsScanField).first);
      final container = ProviderScope.containerOf(
          tester.element(find.byType(WmsScanField).first));
      final antes = container.read(wmsSnapshotProvider).value!;
      final uno = await campo.onCameraSubmitted!(qrS);
      await tester.pumpAndSettle();
      final dos = await campo.onCameraSubmitted!(qrBata);
      await tester.pumpAndSettle();
      final tres = await campo.onCameraSubmitted!(qrS);
      await tester.pumpAndSettle();
      expect(uno.isError, false);
      expect(dos.isError, false);
      expect(tres.text, contains('2 Uds'));
      final invalido = await campo.onCameraSubmitted!('invalido');
      await tester.pumpAndSettle();
      expect(invalido.isError, true);
      expect(container.read(wmsSnapshotProvider).value, same(antes));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Despacho no reemplaza la selección por una lectura de otra OC',
      (tester) async {
    final repo = InMemoryWmsRepository.seeded();
    addTearDown(repo.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      usarSupabaseProvider.overrideWithValue(false),
      wmsRepositoryProvider.overrideWithValue(repo),
    ], child: const MaterialApp(home: Scaffold(body: DespachoDialog()))));
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
