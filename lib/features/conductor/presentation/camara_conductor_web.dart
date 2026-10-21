import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Future<Uint8List?> tomarFotoConductor(BuildContext context) =>
    showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _Camara(),
    );

class _Camara extends StatefulWidget {
  const _Camara();
  @override
  State<_Camara> createState() => _CamaraState();
}

class _CamaraState extends State<_Camara> {
  web.MediaStream? _stream;
  web.HTMLVideoElement? _video;
  String? _error;
  bool _lista = false;

  Future<void> _abrir(web.HTMLVideoElement video) async {
    _video = video;
    video
      ..muted = true
      ..autoplay = true
      ..setAttribute('playsinline', '')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain';
    try {
      if (!web.window.isSecureContext) {
        throw const FormatException('La cámara necesita una conexión HTTPS.');
      }
      final stream =
          await web.window.navigator.mediaDevices
              .getUserMedia(
                web.MediaStreamConstraints(
                  audio: false.toJS,
                  video:
                      {
                        'facingMode': {'ideal': 'environment'},
                        'width': {'ideal': 1600},
                        'height': {'ideal': 1200},
                      }.jsify()!,
                ),
              )
              .toDart;
      if (!mounted) {
        for (final track in stream.getTracks().toDart) {
          track.stop();
        }
        return;
      }
      _stream = stream;
      video.srcObject = stream;
      await video.play().toDart;
      if (mounted) setState(() => _lista = true);
    } catch (e) {
      for (final track
          in _stream?.getTracks().toDart ?? <web.MediaStreamTrack>[]) {
        track.stop();
      }
      if (mounted) {
        setState(
          () =>
              _error =
                  e is FormatException
                      ? e.message
                      : 'No se pudo abrir la cámara. Permite su acceso en el navegador y verifica que otra aplicación no la esté usando. También puedes seleccionar una foto guardada.',
        );
      }
    }
  }

  void _capturar() {
    final video = _video!;
    if (video.videoWidth == 0 || video.videoHeight == 0) return;
    final scale =
        1600 /
        (video.videoWidth > video.videoHeight
            ? video.videoWidth
            : video.videoHeight);
    final canvas =
        web.HTMLCanvasElement()
          ..width = (video.videoWidth * (scale < 1 ? scale : 1)).round()
          ..height = (video.videoHeight * (scale < 1 ? scale : 1)).round();
    canvas.context2D.drawImage(video, 0, 0, canvas.width, canvas.height);
    final data = canvas.toDataURL('image/jpeg', 0.82.toJS);
    Navigator.pop(context, base64Decode(data.split(',').last));
  }

  @override
  void dispose() {
    for (final track
        in _stream?.getTracks().toDart ?? <web.MediaStreamTrack>[]) {
      track.stop();
    }
    _video?.srcObject = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tomar foto'),
    content: SizedBox(
      width: 640,
      child:
          _error != null
              ? Text(_error!)
              : AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: HtmlElementView.fromTagName(
                        tagName: 'video',
                        onElementCreated:
                            (element) =>
                                _abrir(element as web.HTMLVideoElement),
                      ),
                    ),
                    if (!_lista)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton.icon(
        onPressed: _lista && _error == null ? _capturar : null,
        icon: const Icon(Icons.camera_alt_outlined),
        label: const Text('Capturar'),
      ),
    ],
  );
}
