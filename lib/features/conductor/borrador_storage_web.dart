import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<web.IDBDatabase> _open() {
  final done = Completer<web.IDBDatabase>();
  final request = web.window.indexedDB.open('orbiloq-transporte-borradores', 1);
  request.onupgradeneeded =
      ((web.Event _) {
        (request.result as web.IDBDatabase).createObjectStore('borradores');
      }).toJS;
  request.onsuccess =
      ((web.Event _) {
        final db = request.result as web.IDBDatabase;
        if (done.isCompleted) {
          db.close();
          return;
        }
        done.complete(db);
      }).toJS;
  void error(web.Event _) {
    if (!done.isCompleted) {
      done.completeError(
        StateError('No se pudo abrir el almacenamiento local.'),
      );
    }
  }

  request.onerror = error.toJS;
  request.onblocked = error.toJS;
  return done.future;
}

Future<String?> operar(String key, String? value, {bool delete = false}) async {
  final db = await _open();
  try {
    final done = Completer<String?>();
    final tx = db.transaction(
      'borradores'.toJS,
      value != null || delete ? 'readwrite' : 'readonly',
    );
    final store = tx.objectStore('borradores');
    final request =
        delete
            ? store.delete(key.toJS)
            : value == null
            ? store.get(key.toJS)
            : store.put(value.toJS, key.toJS);
    String? result;
    request.onsuccess =
        ((web.Event _) {
          if (value == null && !delete && request.result != null) {
            result = (request.result as JSString).toDart;
          }
        }).toJS;
    tx.oncomplete =
        ((web.Event _) {
          if (!done.isCompleted) done.complete(result);
        }).toJS;
    void error(web.Event _) {
      if (!done.isCompleted) {
        done.completeError(
          StateError('No se pudo guardar en este dispositivo.'),
        );
      }
    }

    tx.onerror = error.toJS;
    tx.onabort = error.toJS;
    return await done.future;
  } finally {
    db.close();
  }
}
