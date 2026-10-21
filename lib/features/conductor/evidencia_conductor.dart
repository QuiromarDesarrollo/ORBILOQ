import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

const carpetaEvidenciasConductor =
    'https://drive.google.com/drive/folders/1KCgLHDHkiek82eyTwpdjfPACmRGC1l7W';
const maxEvidenciaBytes = 10 * 1024 * 1024;

/// La selección pertenece al formulario, incluso si el campo sale de pantalla.
class EvidenciaSeleccionada extends ChangeNotifier {
  EvidenciaSeleccionada({
    SubidaEvidencia Function(ArchivoEvidencia)? crearSubida,
  }) : _crearSubida = crearSubida ?? SubidaEvidencia.new;

  final SubidaEvidencia Function(ArchivoEvidencia) _crearSubida;
  SubidaEvidencia? _subida;
  String? _enlace;
  ArchivoEvidencia? get archivo => _subida?.archivo;
  String? get enlace => _enlace;
  bool get pendiente => _subida != null && _enlace == null;

  void seleccionar(ArchivoEvidencia archivo) {
    _subida?.dispose();
    _subida = _crearSubida(archivo);
    _enlace = null;
    notifyListeners();
  }

  void descartar() {
    _subida?.dispose();
    _subida = null;
    _enlace = null;
    notifyListeners();
  }

  Future<void> subir(
    SupabaseClient? client,
    String vehiculo,
    String campo,
    String tipo,
  ) async {
    if (!pendiente) return;
    _enlace = await _subida!.subir(client, vehiculo, campo, tipo);
    notifyListeners();
  }

  @override
  void dispose() {
    _subida?.dispose();
    super.dispose();
  }
}

/// Solo continúa al guardado cuando todas las evidencias tienen confirmación.
/// Los éxitos se conservan ante fallos de red o del posterior guardado del registro.
Future<void> subirEvidenciasConductor(
  Map<String, EvidenciaSeleccionada> evidencias, {
  required SupabaseClient? client,
  required String vehiculo,
  required String tipo,
  void Function(int actual, int total)? onProgress,
}) async {
  final pendientes =
      evidencias.entries.where((e) => e.value.pendiente).toList();
  for (var i = 0; i < pendientes.length; i++) {
    onProgress?.call(i + 1, pendientes.length);
    final e = pendientes[i];
    await e.value.subir(client, vehiculo, e.key, tipo);
  }
}

class ArchivoEvidencia {
  const ArchivoEvidencia(this.nombre, this.mime, this.bytes);
  final String nombre;
  final String mime;
  final Uint8List bytes;
  bool get esFoto => mime.startsWith('image/');
}

/// Reduce fotos y elimina metadatos EXIF antes de enviarlas a Drive.
Future<ArchivoEvidencia> prepararEvidencia(
  String nombre,
  Uint8List bytes,
) async {
  if (bytes.isEmpty || bytes.length > maxEvidenciaBytes) {
    throw const FormatException('El archivo debe pesar entre 1 byte y 10 MB.');
  }
  final ext = nombre.split('.').last.toLowerCase();
  const tipos = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'pdf': 'application/pdf',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  };
  final mime = tipos[ext];
  if (mime == null) {
    throw const FormatException('Selecciona JPG, PNG, WebP, PDF, DOCX o XLSX.');
  }
  if (!mime.startsWith('image/')) return ArchivoEvidencia(nombre, mime, bytes);
  Uint8List foto;
  try {
    foto = await compute(_optimizarFoto, bytes);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException(
      'No se pudo leer la foto. Selecciona otra imagen JPG, PNG o WebP.',
    );
  }
  return ArchivoEvidencia(
    '${nombre.substring(0, nombre.lastIndexOf('.'))}.jpg',
    'image/jpeg',
    foto,
  );
}

Uint8List _optimizarFoto(Uint8List bytes) {
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null || info.width * info.height > 40000000) {
    throw const FormatException(
      'Foto no compatible o demasiado grande (máximo 40 megapíxeles).',
    );
  }
  var foto = decoder!.decodeFrame(0)!;
  foto = img.bakeOrientation(foto);
  if (foto.width > 1600 || foto.height > 1600) {
    foto = img.copyResize(
      foto,
      width: foto.width >= foto.height ? 1600 : null,
      height: foto.height > foto.width ? 1600 : null,
    );
  }
  foto.exif.clear();
  return Uint8List.fromList(img.encodeJpg(foto, quality: 82));
}

/// Solo metadatos pasan por Supabase. Los bytes viajan directamente a Google.
/// Conserva la sesión al reintentar para evitar duplicar un archivo si se perdió
/// la respuesta después de que Drive terminara de recibirlo.
class SubidaEvidencia {
  SubidaEvidencia(this.archivo, {http.Client? transporte})
    : _http = transporte ?? http.Client();
  final ArchivoEvidencia archivo;
  final http.Client _http;
  Uri? _sesion;
  void dispose() => _http.close();

  Future<String> subir(
    SupabaseClient? client,
    String vehiculo,
    String campo,
    String tipo,
  ) async {
    if (client == null) {
      throw const FormatException(
        'La demostración permite tomar fotos, pero no subirlas. Entra al ambiente de pruebas con tu usuario.',
      );
    }
    if (_sesion == null) {
      try {
        final r = await client.functions.invoke(
          'conductor-evidencia',
          body: {
            'vehiculo': vehiculo,
            'campo': campo,
            'tipo': tipo,
            'nombre': archivo.nombre,
            'mime': archivo.mime,
            'bytes': archivo.bytes.length,
          },
        );
        final uri = Uri.tryParse(r.data['uploadUrl'] as String? ?? '');
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.host != 'www.googleapis.com' ||
            uri.path != '/upload/drive/v3/files' ||
            uri.userInfo.isNotEmpty) {
          throw const FormatException(
            'La conexión con Drive no devolvió una sesión válida.',
          );
        }
        _sesion = uri;
      } on FunctionException catch (e) {
        final code = e.details is Map ? e.details['code'] : null;
        throw FormatException(switch (code) {
          'DRIVE_NOT_CONFIGURED' =>
            'Falta activar la conexión con Google Drive. Contacta al administrador; tu foto sigue disponible aquí.',
          'FORBIDDEN' =>
            'No tienes acceso a este vehículo. Actualiza tu sesión.',
          'DRIVE_UNAVAILABLE' =>
            'Drive no está disponible o la cuenta no tiene permiso en TRANSPORTE. Puedes reintentar.',
          _ =>
            'No se pudo iniciar la subida. Verifica tu sesión y la configuración de Drive.',
        });
      }
    }
    final total = archivo.bytes.length;
    // Consultar antes de enviar también recupera una subida interrumpida.
    var r = await _http
        .put(_sesion!, headers: {'Content-Range': 'bytes */$total'})
        .timeout(const Duration(seconds: 30));
    if (r.statusCode == 200 || r.statusCode == 201) return _enlace(r);
    if (r.statusCode == 404 || r.statusCode == 410) {
      _sesion = null;
      throw const FormatException(
        'La sesión de subida venció. Pulsa Guardar registro para reintentar.',
      );
    }
    if (r.statusCode != 308) {
      throw const FormatException(
        'No se pudo consultar la subida. Puedes reintentar sin perder la foto.',
      );
    }
    final range = r.headers['range'];
    final match =
        range == null ? null : RegExp(r'^bytes=0-(\d+)$').firstMatch(range);
    if (range != null && match == null) {
      throw const FormatException(
        'Drive devolvió un estado de subida no válido.',
      );
    }
    final inicio = match == null ? 0 : int.parse(match[1]!) + 1;
    if (inicio >= total) {
      throw const FormatException(
        'Drive está finalizando el archivo. Reintenta en unos segundos.',
      );
    }
    r = await _http
        .put(
          _sesion!,
          headers: {
            'Content-Type': archivo.mime,
            'Content-Range': 'bytes $inicio-${total - 1}/$total',
          },
          body: archivo.bytes.sublist(inicio),
        )
        .timeout(const Duration(minutes: 2));
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw const FormatException(
        'La subida no terminó. Pulsa Guardar registro para reintentar para continuar.',
      );
    }
    return _enlace(r);
  }

  String _enlace(http.Response response) {
    final id = (jsonDecode(response.body) as Map)['id'];
    if (id is! String || !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      throw const FormatException(
        'No se recibió la confirmación del archivo en Drive.',
      );
    }
    return 'https://drive.google.com/file/d/$id/view';
  }
}
