@TestOn('browser')
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/conductor/borrador_local.dart';

void main() {
  test('IndexedDB conserva fotos y respuestas al recrear el almacén', () async {
    final key = 'test-${DateTime.now().microsecondsSinceEpoch}';
    final store = BorradorLocalStore();
    final data = <String, dynamic>{
      'schema': 1,
      'data': {
        'respuestas': {'Frenos': 'Bueno'},
        'foto': base64Encode(List<int>.generate(1024 * 1024, (i) => i % 256)),
      },
    };
    try {
      await store.guardar(key, data);
      expect(await BorradorLocalStore().leer(key), data);
      expect(await BorradorLocalStore().leer('$key-otro-usuario'), isNull);
      await store.eliminar(key);
      expect(await BorradorLocalStore().leer(key), isNull);
    } finally {
      await store.eliminar(key);
    }
  });
}
