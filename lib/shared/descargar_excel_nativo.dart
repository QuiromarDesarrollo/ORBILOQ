import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<void> descargarExcel(Uint8List bytes, String nombre, {String titulo = 'Guardar Excel'}) async {
  await FilePicker.platform.saveFile(
    dialogTitle: titulo,
    fileName: nombre,
    bytes: bytes,
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
  );
}
