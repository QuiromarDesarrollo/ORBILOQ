@TestOn('browser')
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/conductor/borrador_local.dart';
import 'package:orbiloq_wms/shared/borrador_texto_native.dart'
    if (dart.library.js_interop) 'package:orbiloq_wms/shared/borrador_texto_web.dart';
import 'borrador_operativo_test.dart' show Formulario, EstadoFormulario;

void main() {
  testWidgets('Almacenamiento web guarda antes del siguiente frame y restaura', (t) async {
    final user = 'prueba-web-${DateTime.now().microsecondsSinceEpoch}';
    final key = jsonEncode([user, 'operativo-v1', 'proceso']);
    Future<EstadoFormulario> abrir() async {
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(ProviderScope(overrides: [
        transporteBorradorUsuarioProvider.overrideWithValue(user),
      ], child: const MaterialApp(home: Formulario())));
      await t.pumpAndSettle();
      return t.state<EstadoFormulario>(find.byType(Formulario));
    }
    var state = await abrir();
    state.texto.text = '23';
    expect(jsonDecode(leerTextoBorrador(key)!)['datos']['texto'], '23');
    state = await abrir();
    expect(state.texto.text, '23');
    state.iniciar();
    expect(jsonDecode(leerTextoBorrador(key)!)['enCurso'], isTrue);
    state = await abrir();
    expect(state.borradorBloqueado, isTrue);
    await state.finalizarBorrador();
    expect(jsonDecode(leerTextoBorrador(key)!)['completo'], isTrue);
  });
}
