import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/shared/widgets/selector_tema.dart';

double contraste(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (math.max(x, y) + .05) / (math.min(x, y) + .05);
}

void main() {
  test(
    'Corporativo conserva contraste en superficies, navegación y acciones',
    () {
      final t = AppTheme.kardex(TemaModo.corporativo);
      final p = t.extension<AppPalette>()!;
      for (final par in [
        (p.textPrimary, p.card),
        (p.textSecondary, p.card),
        (p.textMuted, p.input),
        (Colors.white, AppColors.petroleo),
        (AppColors.petroleo, AppColors.lima),
        (t.colorScheme.onPrimary, t.colorScheme.primary),
        (p.info, p.card),
      ]) {
        expect(contraste(par.$1, par.$2), greaterThanOrEqualTo(4.5));
      }
      expect(t.brightness, Brightness.light);
      expect(t.appBarTheme.backgroundColor, AppColors.petroleo);
    },
  );
  testWidgets('Selector ofrece tres modos y los aplica también a diálogos', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder:
              (context, ref, _) => MaterialApp(
                theme: AppTheme.kardex(ref.watch(temaProvider)),
                home: Scaffold(
                  appBar: AppBar(actions: const [SelectorTema()]),
                  body: Builder(
                    builder:
                        (ctx) => TextButton(
                          onPressed:
                              () => showDialog<void>(
                                context: ctx,
                                builder:
                                    (_) => dialogoClaro(
                                      const AlertDialog(
                                        content: Text('Formulario corporativo'),
                                      ),
                                    ),
                              ),
                          child: const Text('Abrir'),
                        ),
                  ),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Elegir apariencia'));
    await tester.pumpAndSettle();
    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Oscuro'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tema-corporativo')));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Abrir'))).colorScheme.primary,
      AppColors.petroleo,
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(
        tester.element(find.text('Formulario corporativo')),
      ).colorScheme.secondary,
      AppColors.lima,
    );
    expect(tester.takeException(), isNull);
  });
}
