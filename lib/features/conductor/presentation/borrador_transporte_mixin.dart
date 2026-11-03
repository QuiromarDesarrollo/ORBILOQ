import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../borrador_local.dart';
import '../kit_semanal.dart';

/// Persistencia local del formulario, sin publicar registros ni subir evidencias.
mixin BorradorTransporteMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  String get draftKey;
  Map<String, dynamic> draftSnapshot();
  void restoreDraft(Map<String, dynamic> data);
  bool get draftBusy;
  bool get draftDaily => false;
  bool get draftWeekly => false;

  String? _key;
  BorradorLocalStore? _store;
  bool draftLoading = true, _restoring = false, _closed = false;
  bool _disposedDraft = false;
  String? draftError;
  String? _lastData;
  Map<String, dynamic>? _next;
  Future<void>? _writing;
  bool draftRecovered = false;
  bool get draftEnabled => _key != null;
  bool get draftCanLeave =>
      _closed || (!draftLoading && _writing == null && draftError == null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadDraft();
    });
  }

  void _paintDraft() {
    if (mounted && !_disposedDraft) super.setState(() {});
  }

  Future<void> _loadDraft() async {
    _restoring = true;
    draftError = null;
    draftLoading = true;
    _paintDraft();
    try {
      final user = ref.read(transporteBorradorUsuarioProvider);
      if (user != null) {
        _key = jsonEncode([user, draftKey]);
        _store = ref.read(transporteBorradorStoreProvider);
        final saved = await _store!.leer(_key!);
        if (!mounted) return;
        if (saved != null && saved['completed'] != true) {
          if (saved['schema'] != 1 || saved['data'] is! Map) {
            throw const FormatException('Formato de borrador no reconocido');
          }
          final previous = DateTime.tryParse('${saved['day']}');
          final today = hoyColombia();
          final old =
              previous != null &&
              ((draftDaily && fechaKit(previous) != fechaKit(today)) ||
                  (draftWeekly && lunesKit(previous) != lunesKit(today)));
          var resume = true;
          if (old) {
            resume =
                await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder:
                      (ctx) => AlertDialog(
                        title: const Text('Borrador de una revisión anterior'),
                        content: Text(
                          'Este avance es del ${saved['day']}. Si lo retomas, revisa nuevamente cada punto antes de confirmar la inspección.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Empezar de nuevo'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Retomar borrador'),
                          ),
                        ],
                      ),
                ) ==
                true;
          }
          if (!mounted) return;
          if (resume) {
            restoreDraft(Map<String, dynamic>.from(saved['data'] as Map));
            draftRecovered = true;
          } else {
            await _store!.eliminar(_key!);
          }
        }
      }
      _lastData = jsonEncode(draftSnapshot());
      draftLoading = false;
    } catch (_) {
      draftError =
          'No se pudo recuperar el avance de este dispositivo. Reintenta antes de continuar.';
    } finally {
      _restoring = false;
      _paintDraft();
    }
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    saveDraft();
  }

  void saveDraft() {
    if (_disposedDraft ||
        _restoring ||
        _closed ||
        draftLoading ||
        _key == null) {
      return;
    }
    final data = draftSnapshot();
    final encoded = jsonEncode(data);
    if (_lastData == encoded && _next == null && _writing == null) return;
    // Detach maps/controllers from subsequent edits before the async write.
    _next = {
      'schema': 1,
      'day': fechaKit(hoyColombia()),
      'data': jsonDecode(encoded),
      'updated': DateTime.now().toUtc().toIso8601String(),
    };
    if (_writing != null) return;
    _writing = _writeDraft();
  }

  Future<void> _writeDraft() async {
    // Yield so _writing is assigned before completion even with in-memory stores.
    await Future<void>.value();
    while (_next != null) {
      final data = _next!;
      _next = null;
      try {
        await _store!.guardar(_key!, data);
        _lastData = jsonEncode(data['data']);
        draftError = null;
      } catch (_) {
        draftError =
            'No se pudo guardar el avance en este dispositivo. No cierres la página; libera espacio y pulsa Reintentar.';
        break;
      }
    }
    _writing = null;
    _paintDraft();
  }

  Future<bool> flushDraft() async {
    saveDraft();
    while (_writing != null) {
      await _writing;
    }
    return draftError == null && !draftLoading;
  }

  Future<void> leaveDraft() async {
    if (draftBusy) return;
    if (!await flushDraft() || !mounted) return;
    _paintDraft();
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> completeDraft() async {
    _closed = true;
    _paintDraft();
    while (_writing != null) {
      await _writing;
    }
    if (_key == null) return;
    try {
      // A tombstone prevents restoration if removing the completed draft fails.
      await _store!.guardar(_key!, {'schema': 1, 'completed': true});
      await _store!.eliminar(_key!);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El registro se confirmó, pero no se pudo limpiar su borrador local. Revisa el historial antes de volver a registrarlo.',
            ),
          ),
        );
      }
    }
  }

  Widget draftStatus() {
    if (_key == null && !draftLoading) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Icon(
            draftError != null ? Icons.warning_amber : Icons.save_outlined,
            size: 18,
          ),
          Text(
            draftError ??
                (draftLoading
                    ? 'Recuperando avance…'
                    : _writing != null
                    ? 'Guardando avance en este dispositivo…'
                    : draftRecovered
                    ? 'Avance recuperado · Guardado automático en este dispositivo'
                    : 'Guardado automático en este dispositivo'),
          ),
          if (draftError != null)
            TextButton(
              onPressed: () {
                if (draftLoading) {
                  _loadDraft();
                } else {
                  saveDraft();
                }
              },
              child: const Text('Reintentar'),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Each edit has already queued its immutable snapshot; do not read disposed controllers.
    _disposedDraft = true;
    super.dispose();
  }
}
