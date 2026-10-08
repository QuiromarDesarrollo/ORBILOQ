import 'dart:typed_data';
import 'package:printing/printing.dart';

Future<void> descargarPdf(Uint8List bytes, String nombre) async {
  await Printing.sharePdf(bytes: bytes, filename: nombre);
}
