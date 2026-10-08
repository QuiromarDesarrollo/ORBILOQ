import 'package:orbiloq_wms/shared/widgets/wms_alert.dart';
import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';
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
  BuildContext context,
  ItemKardex item,
  CampoAdmin campo, {
  String? explicacion,
}) => showWmsDialog<void>(
  context,
  (_) => EdicionAdminDialog(item: item, campo: campo, explicacion: explicacion),
);

class EdicionAdminDialog extends ConsumerStatefulWidget {
  const EdicionAdminDialog({
    super.key,
    required this.item,
    required this.campo,
    this.explicacion,
  });
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
  String? _ubicacion, _error;
  final Map<String, TextEditingController> _recepciones = {};
  bool _ocupado = false;
  int get _despachadas => (_contexto!.valores['despachado'] as num).toInt();
  int get _stockActual =>
      (_contexto!.valores['recibido'] as num).toInt() - _despachadas;
  Object? _valorVisible(CampoAdmin campo) =>
      campo == CampoAdmin.recibido
          ? _stockActual
          : _contexto!.valores[campo.id];

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
    for (final c in _recepciones.values) {
      c.dispose();
    }
    _valor.dispose();
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (!_esAdmin) {
      setState(
        () => _error = 'Esta acción requiere una cuenta administradora.',
      );
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
        for (final l in c.lotes) {
          _recepciones[l['id']] = TextEditingController(
            text: "${l['recibida'] ?? 0}",
          );
        }
        _valor.text = '${_valorVisible(_campo) ?? ''}';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error =
                  'No se pudo cargar la edición. Verifica la conexión y que el SQL de edición administrativa esté instalado en este entorno.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _cambiarCampo(CampoAdmin c) => setState(() {
    _campo = c;
    _valor.text = '${_valorVisible(c) ?? ''}';
    _preview = null;
    _propuesta = null;
    for (final l in _contexto!.lotes) {
      _recepciones[l['id']]!.text = "${l['recibida'] ?? 0}";
    }
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
    if (_campo == CampoAdmin.recibido && valor is int) {
      if (valor < 0) {
        setState(
          () =>
              _error =
                  'El saldo en bodega no puede ser negativo. Las $_despachadas prendas despachadas no se pueden corregir aquí.',
        );
        return;
      }
      // El RPC conserva el acumulado recibido; el usuario edita el saldo físico.
      valor += _despachadas;
    }
    if (_campo == CampoAdmin.producido &&
        valor is int &&
        valor < (_contexto!.valores['recibido'] as num).toInt()) {
      setState(
        () =>
            _error =
                'No puedes dejar lo entregado por Producción en $valor prendas: '
                'Logística ya tiene ${_contexto!.valores['recibido']} recibidas. '
                'Revisa las recepciones relacionadas antes de corregir la entrega.',
      );
      return;
    }
    if (_campo.fecha) {
      if (valor == '') {
        valor = null;
      } else {
        final texto = valor as String;
        final fecha = DateTime.tryParse(texto);
        if (fecha == null || fechaAdmin(fecha) != texto) {
          setState(
            () => _error = 'Usa una fecha válida con formato AAAA-MM-DD.',
          );
          return;
        }
      }
    }
    if (_motivo.text.trim().isEmpty) {
      setState(() => _error = 'Indica el motivo de la corrección.');
      return;
    }
    final cambio =
        confirmar
            ? _propuesta!
            : CambioAdmin(
              itemId: widget.item.id,
              campo: _campo,
              valor: valor,
              motivo: _motivo.text.trim(),
              version: _contexto!.version,
              recepciones:
                  _campo.lote
                      ? {
                        for (final l in _contexto!.lotes)
                          if (int.tryParse(_recepciones[l['id']]!.text) !=
                              (l['recibida'] ?? 0))
                            l['id'] as String:
                                int.tryParse(_recepciones[l['id']]!.text) ?? -1,
                      }
                      : const {},
              ubicacionId: _ubicacion,
            );
    if (!confirmar && _campo.lote) {
      var diferencia = 0;
      var reducciones = 0;
      for (final l in _contexto!.lotes) {
        final n = int.tryParse(_recepciones[l['id']]!.text);
        if (n == null || n < 0 || n > (l['enviada'] as num)) {
          setState(
            () =>
                _error =
                    '${l['numero']}: ingresa un entero entre 0 y ${l['enviada']}.',
          );
          return;
        }
        final delta = n - (l['recibida'] as num).toInt();
        diferencia += delta;
        if (delta < 0) reducciones -= delta;
      }
      if (reducciones > _stockActual) {
        setState(
          () =>
              _error =
                  'Solo puedes descontar $_stockActual prendas que siguen en bodega. Las $_despachadas despachadas están protegidas.',
        );
        return;
      }
      if (diferencia == 0 ||
          (_contexto!.valores['recibido'] as num) + diferencia != valor) {
        setState(
          () =>
              _error =
                  'Distribuye la diferencia entre los lotes hasta alcanzar el nuevo total.',
        );
        return;
      }
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
          mostrarAvisoSnack(context, 
            const SnackBar(
              content: Text('Corrección guardada. El kardex se actualizó.'),
            ),
          );
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
    final admin =
        !ref.watch(usarSupabaseProvider) ||
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
            if (_ocupado) const WmsLoadingStrip(),
            if (!admin) const Text('Acceso exclusivo del administrador.'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: AvisoFormulario(_error!),
              ),
            if (c == null && !_ocupado && admin)
              TextButton(onPressed: _cargar, child: const Text('Reintentar')),
            if (c != null && admin) ...[
              if (widget.explicacion != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(widget.explicacion!),
                ),
              if (_preview == null) ...[
                DropdownButtonFormField<CampoAdmin>(
                  initialValue: _campo,
                  decoration: const InputDecoration(
                    labelText: 'Campo que se va a corregir',
                  ),
                  isExpanded: true,
                  items: [
                    for (final campo in CampoAdmin.values)
                      DropdownMenuItem(
                        value: campo,
                        child: Text(campo.etiqueta),
                      ),
                  ],
                  onChanged:
                      _ocupado
                          ? null
                          : (v) {
                            if (v != null) _cambiarCampo(v);
                          },
                ),
                const SizedBox(height: 12),
                Text('Valor actual: ${_valorVisible(_campo) ?? 'Sin fecha'}'),
                if (_campo.compartido)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Este dato pertenece a la OP: cambiará en sus ${c.filasOrden} filas.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                TextField(
                  controller: _valor,
                  onChanged: (_) => setState(() {}),
                  enabled: !_ocupado,
                  keyboardType:
                      _campo.numero ? TextInputType.number : TextInputType.text,
                  decoration: InputDecoration(
                    labelText:
                        _campo.fecha
                            ? 'Nueva fecha (AAAA-MM-DD; vacío para quitar)'
                            : _campo == CampoAdmin.recibido
                            ? 'Nuevo saldo en bodega'
                            : 'Nuevo valor',
                    helperText:
                        _campo.numero && _campo != CampoAdmin.cantidad
                            ? _campo == CampoAdmin.recibido
                                ? 'Recibidas históricas: ${c.valores['recibido']} · Despachadas: $_despachadas. Escribe solo las prendas que deben quedar en bodega.'
                                : _campo == CampoAdmin.producido
                                ? 'Escribe el total entregado de esta fila. Al reducirlo también se reducen los envíos pendientes de Bodega, empezando por los más recientes. Lo ya recibido se conserva.'
                                : 'Escribe el total deseado de la fila. La diferencia se aplicará a la selección inferior.'
                            : null,
                    helperMaxLines: 3,
                  ),
                ),
                if (_campo.lote) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Distribuir corrección entre recepciones',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Estos valores son recepciones históricas por lote. La reducción conjunta no puede superar las $_stockActual prendas en bodega.',
                  ),
                  for (final l in c.lotes)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${l['numero']} · enviado ${l['enviada']} · recibido ${l['recibida']}',
                            ),
                          ),
                          SizedBox(
                            width: 125,
                            child: TextField(
                              key: ValueKey('recepcion-${l['id']}'),
                              controller: _recepciones[l['id']],
                              enabled: !_ocupado,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Nuevo recibido',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (_) {
                      final delta = c.lotes.fold<int>(
                        0,
                        (s, l) =>
                            s +
                            (int.tryParse(_recepciones[l['id']]!.text) ??
                                (l['recibida'] as num).toInt()) -
                            (l['recibida'] as num).toInt(),
                      );
                      final total = _stockActual + delta;
                      final falta =
                          (int.tryParse(_valor.text) ?? total) - total;
                      return Text(
                        'Saldo en bodega: $total · Diferencia asignada: $delta · Por distribuir: $falta',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: falta == 0 ? Colors.teal : Colors.deepOrange,
                        ),
                      );
                    },
                  ),
                ],
                if (_campo.ubicacion)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('ubicacion-${_campo.id}'),
                      initialValue: _ubicacion,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Ubicación afectada',
                      ),
                      items: [
                        for (final u in c.ubicaciones)
                          DropdownMenuItem(
                            value: u['id'] as String,
                            child: Text(u['codigo'] as String),
                          ),
                      ],
                      onChanged:
                          _ocupado
                              ? null
                              : (v) => setState(() => _ubicacion = v),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _motivo,
                  enabled: !_ocupado,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Motivo obligatorio de la corrección',
                  ),
                ),
              ] else ...[
                const Text(
                  'Revisa el resultado antes de guardar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _Resumen(preview: _preview!),
                const SizedBox(height: 8),
                for (final l in c.lotes)
                  if (_propuesta!.recepciones.containsKey(l['id']))
                    Text(
                      '${l['numero']}: ${l['recibida']} → ${_propuesta!.recepciones[l['id']]}',
                    ),
                Text('Motivo: ${_propuesta!.motivo}'),
                if (_campo.compartido)
                  Text('Afecta las ${c.filasOrden} filas de esta OP.'),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (_preview != null)
                    OutlinedButton(
                      onPressed:
                          _ocupado
                              ? null
                              : () => setState(() => _preview = null),
                      child: const Text('Volver a editar'),
                    ),
                  FilledButton(
                    onPressed:
                        _ocupado ? null : () => _procesar(_preview != null),
                    child: Text(
                      _preview == null
                          ? 'Revisar cambios'
                          : 'Confirmar y guardar',
                    ),
                  ),
                ],
              ),
              if (c.historial.isNotEmpty)
                ExpansionTile(
                  title: const Text('Últimas correcciones de esta fila'),
                  children: [
                    HistorialAgrupado(
                      mostrarTotal: false,
                      embebido: true,
                      grupos: [
                        grupoDeItem(widget.item.item, [
                          for (final h in c.historial)
                            EventoHistorial(
                              id: '${h['id'] ?? h['fecha']}',
                              fecha:
                                  DateTime.tryParse('${h['fecha']}')?.toLocal(),
                              titulo:
                                  '${h['campo']}: ${h['anterior'] ?? 'Sin valor'} → ${h['nuevo'] ?? 'Sin valor'}',
                              detalle: '${h['actor']}\n${h['motivo']}',
                            ),
                        ]),
                      ],
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
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
        cantidadPedida: (v['cantidad_pedida'] as num).toInt(),
      ),
      producido: (v['producido'] as num).toInt(),
      recibido: (v['recibido'] as num).toInt(),
      despachado: (v['despachado'] as num).toInt(),
      ubicaciones: const {},
      fechaEsperadaProduccion: DateTime.tryParse(
        '${v['fecha_esperada_produccion']}',
      ),
    );
    final antes = fila(a), despues = fila(d);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final campo in CampoAdmin.values)
          if (a[campo.id] != d[campo.id])
            Text(
              '${campo.etiqueta}: ${a[campo.id] ?? 'Sin fecha'} → ${d[campo.id] ?? 'Sin fecha'}',
            ),
        Text(
          'Pendiente Producción: ${antes.pendienteProduccion} → ${despues.pendienteProduccion}',
        ),
        Text(
          'Stock disponible: ${antes.stockDisponible} → ${despues.stockDisponible}',
        ),
        if (despues.recibido > despues.producido)
          Text(
            'Las recepciones registradas se conservan: hay ${despues.recibido - despues.producido} unidades recibidas por encima del entregado corregido.',
            style: const TextStyle(color: Colors.deepOrange),
          ),
        Text(
          'Estado Producción: ${antes.estadoProduccion.etiqueta} → ${despues.estadoProduccion.etiqueta}',
        ),
        Text(
          'Estado Logística: ${antes.estadoLogistica.etiqueta} → ${despues.estadoLogistica.etiqueta}',
        ),
      ],
    );
  }
}
