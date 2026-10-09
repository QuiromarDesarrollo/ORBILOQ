import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/features/kardex/presentation/kardex_page.dart';

void main() {
  testWidgets('Kardex cambia entre escritorio y móvil sin fallar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1920, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = InMemoryWmsRepository.seeded();
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [wmsRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.kardex(TemaModo.corporativo),
          home: const KardexPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final width in [300.0, 390.0, 1920.0, 280.0, 768.0, 320.0]) {
      tester.view.physicalSize = Size(width, 800);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
