@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:orbiloq_wms/shared/descargar_pdf.dart';

void main() {
  test(
    'Descarga el PDF con su nombre y bytes sin plugin de impresión',
    () async {
      String? url;
      String? nombre;
      final listener =
          ((web.Event event) {
            final target = event.target;
            if (target != null && target.isA<web.HTMLAnchorElement>()) {
              final enlace = target as web.HTMLAnchorElement;
              nombre = enlace.download;
              url = enlace.href;
              event.preventDefault();
            }
          }).toJS;
      web.document.addEventListener('click', listener);
      addTearDown(() => web.document.removeEventListener('click', listener));
      final bytes = Uint8List.fromList('%PDF-1.4\n%%EOF'.codeUnits);
      await descargarPdf(bytes, 'Lista_empaque_2973.pdf');
      expect(nombre, 'Lista_empaque_2973.pdf');
      expect(url, startsWith('blob:'));
      final response = await web.window.fetch(url!.toJS).toDart;
      expect(response.headers.get('Content-Type'), 'application/pdf');
      final buffer = await response.arrayBuffer().toDart;
      expect(buffer.toDart.asUint8List(), bytes);
      expect(
        web.document.querySelector('a[download="Lista_empaque_2973.pdf"]'),
        isNull,
      );
    },
  );
}
