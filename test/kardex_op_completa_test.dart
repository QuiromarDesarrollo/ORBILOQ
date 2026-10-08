import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/features/kardex/presentation/kardex_table.dart';
void main() {
 testWidgets('OP completa en tabla de escritorio con observaciones', (tester) async {
  tester.view.physicalSize = const Size(1880,1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repo = InMemoryWmsRepository.seeded(); addTearDown(repo.dispose);
  await tester.pumpWidget(ProviderScope(overrides: [usarSupabaseProvider.overrideWithValue(false), wmsRepositoryProvider.overrideWithValue(repo)],child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: KardexTable())))));
  await tester.pumpAndSettle();
  final ops = find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().startsWith('#'));
  expect(ops, findsWidgets);
  for (final e in ops.evaluate()) {
    expect((e.renderObject! as RenderParagraph).didExceedMaxLines, isFalse);
  }
  expect(tester.takeException(), isNull);
 });
}
