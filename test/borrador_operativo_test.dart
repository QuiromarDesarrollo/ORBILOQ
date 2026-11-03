import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/conductor/borrador_local.dart';
import 'package:orbiloq_wms/shared/borrador_operativo.dart';

class MemoriaOperativa extends BorradorLocalStore {
  final datos = <String, Map<String, dynamic>>{};
  bool fallo = false;
  @override
  Future<Map<String, dynamic>?> leer(String key) async => datos[key];
  @override
  Future<void> guardar(String key, Map<String, dynamic> value) async {
    if (fallo) throw StateError('Sin espacio');
    datos[key] = Map<String, dynamic>.from(jsonDecode(jsonEncode(value)));
  }
}

class Formulario extends ConsumerStatefulWidget {
  const Formulario({super.key});
  @override
  ConsumerState<Formulario> createState() => EstadoFormulario();
}

class EstadoFormulario extends ConsumerState<Formulario>
    with BorradorOperativo<Formulario> {
  final texto = TextEditingController();
  bool enviando = false;
  @override
  String get borradorProceso => 'proceso';
  @override
  bool get operacionEnCurso => enviando;
  @override
  Iterable<TextEditingController> get controlesBorrador => [texto];
  @override
  Map<String, dynamic> capturarBorrador() => {'texto': texto.text};
  @override
  void recuperarBorrador(Map<String, dynamic> d) {
    texto.text = d['texto'] as String;
  }

  void iniciar() => setState(() => enviando = true);
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: envolverBorrador(TextField(controller: texto)));
  @override
  void dispose() {
    texto.dispose();
    super.dispose();
  }
}

void main() {
  testWidgets(
    'Recupera sin envío, aísla usuario/entorno y bloquea operación incierta',
    (t) async {
      final store = MemoriaOperativa();
      Future<EstadoFormulario> abrir(String user) async {
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(
          ProviderScope(
            overrides: [
              transporteBorradorUsuarioProvider.overrideWithValue(user),
              transporteBorradorStoreProvider.overrideWithValue(store),
            ],
            child: const MaterialApp(home: Formulario()),
          ),
        );
        await t.pumpAndSettle();
        return t.state<EstadoFormulario>(find.byType(Formulario));
      }

      var estado = await abrir('dev:u1');
      await t.enterText(find.byType(TextField), '12 prendas');
      await t.pumpAndSettle();
      estado = await abrir('dev:u1');
      expect(estado.texto.text, '12 prendas');
      expect(estado.enviando, isFalse);
      expect((await abrir('dev:u2')).texto.text, '');
      expect((await abrir('prod:u1')).texto.text, '');
      estado = await abrir('dev:u1');
      estado.iniciar();
      await estado.asegurarBorrador();
      estado = await abrir('dev:u1');
      expect(estado.texto.text, '12 prendas');
      expect(estado.borradorIncierto, isTrue);
      expect(estado.borradorBloqueado, isTrue);
      expect(estado.enviando, isFalse);
      await estado.finalizarBorrador();
      expect((await abrir('dev:u1')).texto.text, '');
    },
  );

  testWidgets('Fallo de guardado bloquea confirmación y permite reintentar', (
    t,
  ) async {
    final store = MemoriaOperativa()..fallo = true;
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          transporteBorradorUsuarioProvider.overrideWithValue('dev:u1'),
          transporteBorradorStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(home: Formulario()),
      ),
    );
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '7');
    await t.pumpAndSettle();
    final estado = t.state<EstadoFormulario>(find.byType(Formulario));
    expect(await estado.asegurarBorrador(), isFalse);
    expect(estado.borradorBloqueado, isTrue);
    store.fallo = false;
    await t.tap(find.text('Reintentar'));
    await t.pumpAndSettle();
    expect(estado.borradorBloqueado, isFalse);
    expect(store.datos.values.single['datos']['texto'], '7');
  });
}
