import '../../../shared/widgets/historial_agrupado.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/auth_providers.dart';
import '../../../application/providers.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/edicion_admin.dart';
import '../../../domain/models.dart';
import '../../../domain/sesion.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showEdicionAdminDialog(
        BuildContext context, ItemKardex item, CampoAdmin campo,
        {String? explicacion}) =>
    showWmsDialog<void>(
        context,
        (_) => EdicionAdminDialog(
            item: item, campo: campo, explicacion: explicacion));

class EdicionAdminDialog extends ConsumerStatefulWidget {
  const EdicionAdminDialog(
      {super.key, required this.item, required this.campo, this.explicacion});
  final ItemKardex item;
  final CampoAdmin campo;
  final String? explicacion;
  @override
  ConsumerState<EdicionAdminDialog> createState() => _EdicionAdminDialogState();
}

class _EdicionAdminDialogState extends ConsumerState<EdicionAdminDialog> {
  final _valor = TextEditingController();
  final _motivo = TextEditingController();
  late CampoAdmin _campo = widget.campo;
  ContextoEdicionAdmin? _contexto;
  Map<String, dynamic>? _preview;
  CambioAdmin? _propuesta;
  String? _lote, _ubicacion, _error;
  bool _ocupado = false;

  bool get _esAdmin =>
      !ref.read(usarSupabaseProvider) ||
      ref.read(usuarioSesionProvider).value?.rolCuenta == RolCuenta.admin;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _valor.dispose();
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (!_esAdmin) {
      setState(
          () => _error = 'Esta acción requiere una cuenta administradora.');
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final c = await ref
          .read(wmsRepositoryProvider)
          .cargarEdicionAdmin(widget.item.id);
      if (!mounted) return;
      setState(() {
        _contexto = c;
        _valor.text = '${c.valores[_campo.id] ?? ''}';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'No se pudo cargar la edición. Verifica la conexión y que el SQL de edición administrativa esté instalado en este entorno.');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _cambiarCampo(CampoAdmin c) => setState(() {
        _campo = c;
        _valor.text = '${_contexto!.valores[c.id] ?? ''}';
        _preview = null;
        _propuesta = null;
        _lote = null;
        _ubicacion = null;
        _error = null;
      });

  Future<void> _procesar(bool confirmar) async {
    if (!_esAdmin || _ocupado) return;
    Object? valor = _valor.text.trim();
    if (_campo.numero) {
      valor = int.tryParse(valor as String);
      if (valor == null) {
        setState(() => _error = 'Ingresa un número entero.');
        return;
      }
    }
    if (_campo.fecha) {
      if (valor == '') {
        valor = null;
      } else {
        final texto = valor as String;
        final fecha = DateTime.tryParse(texto);
        if (fecha == null || fechaAdmin(fecha) != texto) {
          setState(
              () => _error = 'Usa una fecha válida con formato AAAA-MM-DD.');
          return;
        }
      }
    }
    if (_motivo.text.trim().isEmpty) {
      setState(() => _error = 'Indica el motivo de la corrección.');
      return;
    }
    final cambio = confirmar
        ? _propuesta!
        : CambioAdmin(
            itemId: widget.item.id,
            campo: _campo,
            valor: valor,
            motivo: _motivo.text.trim(),
            version: _contexto!.version,
            loteId: _campo.lote ? _lote : null,
            ubicacionId: _ubicacion);
    if (!confirmar && _campo.lote && _lote == null) {
      setState(() => _error =
          'Selecciona el lote de la recepción que vas a corregir.');
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    final result = await ref
        .read(wmsRepositoryProvider)
        .editarAdmin(cambio, confirmar: confirmar);
    if (!mounted) return;
    setState(() => _ocupado = false);
    switch (result) {
      case Err<Map<String, dynamic>>(:final message):
        setState(() {
          _error = message;
          _preview = null;
          _propuesta = null;
        });
      case Ok<Map<String, dynamic>>(:final value):
        if (confirmar) {
          ref.invalidate(sobrantesProvider);
          ref.invalidate(noConformesAliadosProvider);
          ref.invalidate(liberacionesAliadosProvider);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Corrección guardada. El kardex se actualizó.')));
        } else {
          setState(() {
            _preview = value;
            _propuesta = cambio;
          });
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _contexto;
    final admin = !ref.watch(usarSupabaseProvider) ||
        ref.watch(usuarioSesionProvider).value?.rolCuenta == RolCuenta.admin;
    return PopScope(
        canPop: !_ocupado,
        child: WmsDialogShell(
            canClose: !_ocupado,
            title:
                'Editar · OP ${widget.item.item.op} · ${widget.item.item.codigo}',
            icon: Icons.edit_note,
            iconColor: AppColors.primaryNavy,
            maxWidth: 720,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_ocupado) const LinearProgressIndicator(),
                  if (!admin) const Text('Acceso exclusivo del administrador.'),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red))),
                  if (c == null && !_ocupado && admin)
                    TextButton(
                        onPressed: _cargar, child: const Text('Reintentar')),
                  if (c != null && admin) ...[
                    if (widget.explicacion != null)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(widget.explicacion!)),
                    if (_preview == null) ...[
                      DropdownButtonFormField<CampoAdmin>(
                          initialValue: _campo,
                          decoration: const InputDecoration(
                              labelText: 'Campo que se va a corregir'),
                          isExpanded: true,
                          items: [
                            for (final campo in CampoAdmin.values)
                              DropdownMenuItem(
                                  value: campo, child: Text(campo.etiqueta))
                          ],
                          onChanged: _ocupado
                              ? null
                              : (v) {
                                  if (v != null) _cambiarCampo(v);
                                }),
                      const SizedBox(height: 12),
                      Text(
                          'Valor actual: ${c.valores[_campo.id] ?? 'Sin fecha'}'),
                      if (_campo.compartido)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                                'Este dato pertenece a la OP: cambiará en sus ${c.filasOrden} filas.',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold))),
                      TextField(
                          controller: _valor,
                          enabled: !_ocupado,
                          keyboardType: _campo.numero
                              ? TextInputType.number
                              : TextInputType.text,
                          decoration: InputDecoration(
                              labelText: _campo.fecha
                                  ? 'Nueva fecha (AAAA-MM-DD; vacío para quitar)'
                                  : 'Nuevo valor',
                              helperText: _campo.numero &&
                                      _campo != CampoAdmin.cantidad
                                  ? _campo == CampoAdmin.producido
                                      ? 'Escribe el total entregado de esta fila. Se recalcula el pendiente y se conservan los lotes y las recepciones.'
                                      : 'Escribe el total deseado de la fila. La diferencia se aplicará a la selección inferior.'
                                  : null,
                              helperMaxLines: 3)),
                      if (_campo.lote)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: DropdownButtonFormField<String>(
                                key: ValueKey('lote-${_campo.id}'),
                                initialValue: _lote,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                    labelText:
                                        'Lote al que corresponde la diferencia'),
                                items: [
                                  for (final l in c.lotes)
                                    DropdownMenuItem(
                                        value: l['id'] as String,
                                        child: Text(
                                            '${l['numero']} · enviado ${l['enviada']} · recibido ${l['recibida']}',
                                            overflow: TextOverflow.ellipsis))
                                ],
                                onChanged: _ocupado
                                    ? null
                                    : (v) => setState(() => _lote = v))),
                      if (_campo.ubicacion)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: DropdownButtonFormField<String>(
                                key: ValueKey('ubicacion-${_campo.id}'),
                                initialValue: _ubicacion,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                    labelText: 'Ubicación afectada'),
                                items: [
                                  for (final u in c.ubicaciones)
                                    DropdownMenuItem(
                                        value: u['id'] as String,
                                        child: Text(u['codigo'] as String))
                                ],
                                onChanged: _ocupado
                                    ? null
                                    : (v) => setState(() => _ubicacion = v))),
                      const SizedBox(height: 12),
                      TextField(
                          controller: _motivo,
                          enabled: !_ocupado,
                          maxLines: 2,
                          decoration: const InputDecoration(
                              labelText:
                                  'Motivo obligatorio de la corrección')),
                    ] else ...[
                      const Text('Revisa el resultado antes de guardar',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _Resumen(preview: _preview!),
                      const SizedBox(height: 8),
                      Text('Motivo: ${_propuesta!.motivo}'),
                      if (_campo.compartido)
                        Text('Afecta las ${c.filasOrden} filas de esta OP.'),
                    ],
                    const SizedBox(height: 16),
                    Wrap(spacing: 12, runSpacing: 8, children: [
                      if (_preview != null)
                        OutlinedButton(
                            onPressed: _ocupado
                                ? null
                                : () => setState(() => _preview = null),
                            child: const Text('Volver a editar')),
                      FilledButton(
                          onPressed: _ocupado
                              ? null
                              : () => _procesar(_preview != null),
                          child: Text(_preview == null
                              ? 'Revisar cambios'
                              : 'Confirmar y guardar')),
                    ]),
                    if (c.historial.isNotEmpty)
                      ExpansionTile(
                          title:
                              const Text('Últimas correcciones de esta fila'),
                          children: [
                            HistorialAgrupado(embebido: true, grupos: [grupoDeItem(widget.item.item, [
                              for (final h in c.historial) EventoHistorial(
                                id: '${h['id'] ?? h['fecha']}', fecha: DateTime.tryParse('${h['fecha']}')?.toLocal(),
                                titulo: '${h['campo']}: ${h['anterior'] ?? 'Sin valor'} → ${h['nuevo'] ?? 'Sin valor'}',
                                detalle: '${h['actor']}\n${h['motivo']}'),
                            ])]),
                          ]),
                  ],
                ])));
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.preview});
  final Map<String, dynamic> preview;
  @override
  Widget build(BuildContext context) {
    final a = Map<String, dynamic>.from(preview['antes'] as Map);
    final d = Map<String, dynamic>.from(preview['despues'] as Map);
    ItemKardex fila(Map<String, dynamic> v) => ItemKardex(
        item: ItemOrden(
            id: '',
            op: '',
            cliente: '',
            oc: '',
            codigo: '',
            descripcion: '',
            talla: '',
            cantidadPedida: (v['cantidad_pedida'] as num).toInt()),
        producido: (v['producido'] as num).toInt(),
        recibido: (v['recibido'] as num).toInt(),
        despachado: (v['despachado'] as num).toInt(),
        ubicaciones: const {},
        fechaEsperadaProduccion:
            DateTime.tryParse('${v['fecha_esperada_produccion']}'));
    final antes = fila(a), despues = fila(d);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final campo in CampoAdmin.values)
        if (a[campo.id] != d[campo.id])
          Text(
              '${campo.etiqueta}: ${a[campo.id] ?? 'Sin fecha'} → ${d[campo.id] ?? 'Sin fecha'}'),
      Text(
          'Pendiente Producción: ${antes.pendienteProduccion} → ${despues.pendienteProduccion}'),
      Text(
          'Stock disponible: ${antes.stockDisponible} → ${despues.stockDisponible}'),
      if (despues.recibido > despues.producido)
        Text(
            'Las recepciones registradas se conservan: hay ${despues.recibido - despues.producido} unidades recibidas por encima del entregado corregido.',
            style: const TextStyle(color: Colors.deepOrange)),
      Text(
          'Estado Producción: ${antes.estadoProduccion.etiqueta} → ${despues.estadoProduccion.etiqueta}'),
      Text(
          'Estado Logística: ${antes.estadoLogistica.etiqueta} → ${despues.estadoLogistica.etiqueta}'),
    ]);
  }
}
