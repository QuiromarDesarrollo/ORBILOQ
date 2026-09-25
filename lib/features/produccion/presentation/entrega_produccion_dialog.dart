import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/constants.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/fecha.dart';
import '../../../domain/models.dart';
import '../../../domain/qr_prenda.dart';
import '../../../shared/widgets/action_button.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/labeled_dropdown.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showEntregaProduccionDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const EntregaProduccionDialog());

class EntregaProduccionDialog extends StatelessWidget {
  const EntregaProduccionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return WmsDialogShell(
      title: 'PRODUCCIÓN: ENTREGA CON LÍMITES E HISTORIAL',
      icon: Icons.precision_manufacturing,
      iconColor: AppColors.actionGreen,
      expand: true,
      maxWidth: 1200,
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              labelColor: AppColors.primaryNavy,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primaryNavy,
              labelPadding: EdgeInsets.symmetric(vertical: 4),
              labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              unselectedLabelStyle: TextStyle(fontSize: 11),
              tabs: [
                Tab(height: 38, icon: Icon(Icons.qr_code_scanner, size: 16), text: 'ESCANEAR QR'),
                Tab(height: 38, icon: Icon(Icons.edit_note, size: 16), text: 'ENTREGA MANUAL'),
                Tab(height: 38, icon: Icon(Icons.history, size: 16), text: 'HISTORIAL'),
              ],
            ),
            const SizedBox(height: 8),
            const Expanded(
              child: TabBarView(children: [_NuevaEntregaTab(), _EntregaManualTab(), _HistorialTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado de UNA tarjeta de producto/talla dentro de la sesión de entrega
/// (por escaneo o manual). Varias pueden coexistir, cada una con su propio
/// conteo — pero se despachan TODAS JUNTAS bajo un mismo lote.
class _TarjetaEntrega {
  _TarjetaEntrega({required this.itemId}) : cantidadCtrl = TextEditingController(text: '1');

  final String itemId;
  final TextEditingController cantidadCtrl;
  int conteo = 1;
  bool enviando = false;
  bool enviada = false;
  String? loteId;

  void dispose() => cantidadCtrl.dispose();
}

/// Valida todas las tarjetas pendientes y, si todas pasan, crea UN solo lote
/// con todas ellas (todo o nada — así también funciona la base de datos).
Future<Result<Lote>> _validarYCrearLote({
  required WidgetRef ref,
  required List<_TarjetaEntrega> pendientes,
  required String operario,
}) async {
  for (final t in pendientes) {
    final kardex = ref.read(wmsSnapshotProvider).value?.kardexPorId(t.itemId);
    if (kardex == null) continue;
    final cantidad = int.tryParse(t.cantidadCtrl.text.trim()) ?? 0;
    if (cantidad <= 0) {
      return Err<Lote>(
        'La cantidad de "${kardex.item.descripcion} (${kardex.item.talla})" debe ser mayor a 0.',
      );
    }
    if (cantidad > kardex.pendienteProduccion) {
      return Err<Lote>(
        'LÍMITE EXCEDIDO en "${kardex.item.descripcion} (${kardex.item.talla})": '
        'solo faltan ${kardex.pendienteProduccion} Uds por producir.',
      );
    }
  }

  final items = [
    for (final t in pendientes)
      ItemCantidad(itemId: t.itemId, cantidad: int.tryParse(t.cantidadCtrl.text.trim()) ?? 0),
  ];
  return ref.read(wmsRepositoryProvider).crearLote(items: items, operario: operario);
}

// ============================================================ pestaña 1: QR

class _NuevaEntregaTab extends ConsumerStatefulWidget {
  const _NuevaEntregaTab();

  @override
  ConsumerState<_NuevaEntregaTab> createState() => _NuevaEntregaTabState();
}

class _NuevaEntregaTabState extends ConsumerState<_NuevaEntregaTab> with AutomaticKeepAliveClientMixin {
  final _qrCtrl = TextEditingController();
  final _qrFocus = FocusNode();

  String _operario = WmsConstantes.operarios.first;
  final List<_TarjetaEntrega> _tarjetas = [];
  FeedbackMessage? _msgGeneral;
  bool _despachandoTodo = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _qrCtrl.dispose();
    _qrFocus.dispose();
    for (final t in _tarjetas) {
      t.dispose();
    }
    super.dispose();
  }

  _TarjetaEntrega? _tarjetaActivaPara(String itemId) {
    for (final t in _tarjetas) {
      if (t.itemId == itemId && !t.enviada) return t;
    }
    return null;
  }

  void _errorGeneral(String texto) {
    setState(() => _msgGeneral = FeedbackMessage.error(texto));
    _qrFocus.requestFocus();
  }

  void _procesarQR(String raw) {
    _qrCtrl.clear();
    if (raw.trim().isEmpty) return;

    final qr = QrPrenda.tryParse(raw);
    if (qr == null) {
      _errorGeneral('QR inválido. Formato esperado: ${QrPrenda.formato}');
      return;
    }
    final kardex = ref.read(wmsSnapshotProvider).value?.kardexPorOpCodigo(qr.op, qr.codigo);
    if (kardex == null) {
      _errorGeneral('La prenda no existe en el kardex (OP ${qr.op} · Código ${qr.codigo}).');
      return;
    }

    setState(() {
      _msgGeneral = null;
      final existente = _tarjetaActivaPara(kardex.id);
      if (existente != null) {
        // Siempre sube al tope, para que se vea cuál fue la última escaneada.
        _tarjetas.remove(existente);
        _tarjetas.insert(0, existente);
        if (existente.conteo >= kardex.pendienteProduccion) {
          _msgGeneral = FeedbackMessage.error(
            'LÍMITE ALCANZADO: esta OP ya cumplió la cantidad pedida (${kardex.pendienteProduccion} Uds por entregar).',
          );
        } else {
          existente.conteo++;
          existente.cantidadCtrl.text = '${existente.conteo}';
        }
      } else if (kardex.pendienteProduccion <= 0) {
        _msgGeneral = FeedbackMessage.error(
          'LÍMITE ALCANZADO: esta OP ya cumplió la cantidad pedida (${kardex.pendienteProduccion} Uds por entregar).',
        );
      } else {
        _tarjetas.insert(0, _TarjetaEntrega(itemId: kardex.id));
      }
    });
    _qrFocus.requestFocus();
  }

  void _reiniciarConteo(_TarjetaEntrega t) {
    setState(() {
      t.conteo = 0;
      t.cantidadCtrl.text = '1';
    });
    _qrFocus.requestFocus();
  }

  void _quitarTarjeta(_TarjetaEntrega t) {
    setState(() {
      t.dispose();
      _tarjetas.remove(t);
    });
  }

  /// Despacha TODAS las tarjetas activas (no enviadas) como UN solo lote.
  Future<void> _despacharTodo() async {
    final pendientes = _tarjetas.where((t) => !t.enviada).toList();
    if (pendientes.isEmpty) return;
    setState(() {
      _despachandoTodo = true;
      _msgGeneral = null;
      for (final t in pendientes) {
        t.enviando = true;
      }
    });
    final res = await _validarYCrearLote(ref: ref, pendientes: pendientes, operario: _operario);
    if (!mounted) return;
    setState(() {
      _despachandoTodo = false;
      for (final t in pendientes) {
        t.enviando = false;
      }
      switch (res) {
        case Ok(:final value):
          for (final t in pendientes) {
            t.enviada = true;
            t.loteId = value.id;
          }
          _msgGeneral = FeedbackMessage.ok(
            'Lote ${value.id} despachado a bodega (${pendientes.length} producto(s)).',
          );
        case Err(:final message):
          _msgGeneral = FeedbackMessage.error(message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final snapshot = ref.watch(wmsSnapshotProvider).value;
    final pendientes = _tarjetas.where((t) => !t.enviada).length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msgGeneral != null) ...[
            FeedbackBanner(message: _msgGeneral!),
            const SizedBox(height: 12),
          ],
          LabeledDropdown<String>(
            label: 'Operario de Producción',
            value: _operario,
            items: WmsConstantes.operarios,
            onChanged: (v) => setState(() => _operario = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qrCtrl,
            focusNode: _qrFocus,
            autofocus: true,
            decoration: wmsInput('PISTOLEE O ESCANEE QR DE PRENDA A ENTREGAR', icon: Icons.qr_code_scanner),
            onSubmitted: _procesarQR,
          ),
          const SizedBox(height: 12),
          if (_tarjetas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Escanea una prenda para empezar. Puedes tener varias tallas u OP\n'
                  'abiertas a la vez — todas se despachan juntas, en un mismo lote.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  pendientes > 0
                      ? '$pendientes producto(s) listo(s) para el lote'
                      : 'Todas las tarjetas ya se enviaron',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                ActionButton(
                  icon: Icons.local_shipping,
                  label: 'DESPACHAR LOTE A LOGÍSTICA',
                  color: AppColors.actionGreen,
                  busy: _despachandoTodo,
                  onPressed: pendientes == 0 ? null : _despacharTodo,
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final t in _tarjetas) ...[
              _TarjetaWidget(
                tarjeta: t,
                kardex: snapshot?.kardexPorId(t.itemId),
                onRecontear: () => _reiniciarConteo(t),
                onQuitar: () => _quitarTarjeta(t),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

// ==================================================== pestaña 2: manual

class _EntregaManualTab extends ConsumerStatefulWidget {
  const _EntregaManualTab();

  @override
  ConsumerState<_EntregaManualTab> createState() => _EntregaManualTabState();
}

class _EntregaManualTabState extends ConsumerState<_EntregaManualTab> with AutomaticKeepAliveClientMixin {
  final _opCtrl = TextEditingController();
  String _operario = WmsConstantes.operarios.first;
  List<ItemKardex> _resultados = [];
  final Set<String> _seleccionados = {};
  final List<_TarjetaEntrega> _tarjetas = [];
  String? _errorBusqueda;
  FeedbackMessage? _msgGeneral;
  bool _despachandoTodo = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _opCtrl.dispose();
    for (final t in _tarjetas) {
      t.dispose();
    }
    super.dispose();
  }

  _TarjetaEntrega? _tarjetaActivaPara(String itemId) {
    for (final t in _tarjetas) {
      if (t.itemId == itemId && !t.enviada) return t;
    }
    return null;
  }

  void _buscar() {
    final op = _opCtrl.text.trim();
    final kardex = ref.read(wmsSnapshotProvider).value?.kardex ?? const <ItemKardex>[];
    setState(() {
      _seleccionados.clear();
      if (op.isEmpty) {
        _resultados = [];
        _errorBusqueda = 'Escribe un número de OP.';
        return;
      }
      _resultados = kardex.where((k) => k.item.op == op && k.pendienteProduccion > 0).toList();
      _errorBusqueda = _resultados.isEmpty
          ? 'No se encontraron tallas con producción pendiente para la OP $op.'
          : null;
    });
  }

  void _agregarSeleccionadas() {
    setState(() {
      for (final id in _seleccionados) {
        if (_tarjetaActivaPara(id) != null) continue;
        _tarjetas.insert(0, _TarjetaEntrega(itemId: id));
      }
      _seleccionados.clear();
      _resultados = [];
      _opCtrl.clear();
    });
  }

  void _reiniciarConteo(_TarjetaEntrega t) {
    setState(() {
      t.conteo = 0;
      t.cantidadCtrl.text = '1';
    });
  }

  void _quitarTarjeta(_TarjetaEntrega t) {
    setState(() {
      t.dispose();
      _tarjetas.remove(t);
    });
  }

  Future<void> _despacharTodo() async {
    final pendientes = _tarjetas.where((t) => !t.enviada).toList();
    if (pendientes.isEmpty) return;
    setState(() {
      _despachandoTodo = true;
      _msgGeneral = null;
      for (final t in pendientes) {
        t.enviando = true;
      }
    });
    final res = await _validarYCrearLote(ref: ref, pendientes: pendientes, operario: _operario);
    if (!mounted) return;
    setState(() {
      _despachandoTodo = false;
      for (final t in pendientes) {
        t.enviando = false;
      }
      switch (res) {
        case Ok(:final value):
          for (final t in pendientes) {
            t.enviada = true;
            t.loteId = value.id;
          }
          _msgGeneral = FeedbackMessage.ok(
            'Lote ${value.id} despachado a bodega (${pendientes.length} producto(s)).',
          );
        case Err(:final message):
          _msgGeneral = FeedbackMessage.error(message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final snapshot = ref.watch(wmsSnapshotProvider).value;
    final pendientes = _tarjetas.where((t) => !t.enviada).length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msgGeneral != null) ...[
            FeedbackBanner(message: _msgGeneral!),
            const SizedBox(height: 12),
          ],
          LabeledDropdown<String>(
            label: 'Operario de Producción',
            value: _operario,
            items: WmsConstantes.operarios,
            onChanged: (v) => setState(() => _operario = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _opCtrl,
                  keyboardType: TextInputType.number,
                  decoration: wmsInput('Número de OP', icon: Icons.tag),
                  onSubmitted: (_) => _buscar(),
                ),
              ),
              const SizedBox(width: 10),
              ActionButton(icon: Icons.search, label: 'BUSCAR', color: AppColors.primaryNavy, onPressed: _buscar),
            ],
          ),
          if (_errorBusqueda != null) ...[
            const SizedBox(height: 10),
            FeedbackBanner(message: FeedbackMessage.error(_errorBusqueda!)),
          ],
          if (_resultados.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  for (final r in _resultados)
                    CheckboxListTile(
                      dense: true,
                      value: _seleccionados.contains(r.id),
                      activeColor: AppColors.actionGreen,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _seleccionados.add(r.id);
                        } else {
                          _seleccionados.remove(r.id);
                        }
                      }),
                      title: Text(
                        '${r.item.codigo} — ${r.item.descripcion} (Talla ${r.item.talla})',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('Pendiente por producir: ${r.pendienteProduccion} Uds'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ActionButton(
                icon: Icons.playlist_add,
                label: 'AGREGAR SELECCIONADAS (${_seleccionados.length})',
                color: AppColors.actionGreen,
                onPressed: _seleccionados.isEmpty ? null : _agregarSeleccionadas,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_tarjetas.isEmpty && _resultados.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Escribe una OP y busca para ver sus tallas pendientes.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else if (_tarjetas.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  pendientes > 0
                      ? '$pendientes producto(s) listo(s) para el lote'
                      : 'Todas las tarjetas ya se enviaron',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                ActionButton(
                  icon: Icons.local_shipping,
                  label: 'DESPACHAR LOTE A LOGÍSTICA',
                  color: AppColors.actionGreen,
                  busy: _despachandoTodo,
                  onPressed: pendientes == 0 ? null : _despacharTodo,
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final t in _tarjetas) ...[
              _TarjetaWidget(
                tarjeta: t,
                kardex: snapshot?.kardexPorId(t.itemId),
                onRecontear: () => _reiniciarConteo(t),
                onQuitar: () => _quitarTarjeta(t),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

// ==================================================== tarjeta (compartida)

class _TarjetaWidget extends StatelessWidget {
  const _TarjetaWidget({
    required this.tarjeta,
    required this.kardex,
    required this.onRecontear,
    required this.onQuitar,
  });

  final _TarjetaEntrega tarjeta;
  final ItemKardex? kardex;
  final VoidCallback onRecontear;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final k = kardex;
    if (k == null) return const SizedBox.shrink();
    final enviada = tarjeta.enviada;

    return Card(
      color: enviada ? Colors.grey.shade100 : Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(
                            'OP: ${k.item.op} - ${k.item.descripcion} (${k.item.talla})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: enviada ? Colors.grey.shade600 : AppColors.primaryNavy,
                            ),
                          ),
                          if (enviada)
                            StatusChip(label: 'ENVIADA · ${tarjeta.loteId}', color: AppColors.actionGreen)
                          else if (tarjeta.enviando)
                            const StatusChip(label: 'ENVIANDO…', color: AppColors.accentCyan),
                        ],
                      ),
                      Text(
                        'No. OC: ${k.item.oc} | Cliente: ${k.item.cliente}',
                        style: TextStyle(color: enviada ? Colors.grey.shade600 : null),
                      ),
                    ],
                  ),
                ),
                if (!enviada) ...[
                  ActionButton(
                    icon: Icons.refresh,
                    label: 'RECONTEAR',
                    color: Colors.amber.shade900,
                    onPressed: tarjeta.enviando ? null : onRecontear,
                  ),
                  IconButton(
                    tooltip: 'Quitar esta tarjeta',
                    icon: const Icon(Icons.close, color: AppColors.alertRed),
                    onPressed: tarjeta.enviando ? null : onQuitar,
                  ),
                ],
              ],
            ),
            const Divider(),
            MetricWrap(children: [
              MetricCard(title: 'META OP', value: '${k.cantidadPedida} Uds', color: Colors.blueGrey, icon: Icons.flag),
              MetricCard(title: 'ENTREGADAS', value: '${k.producido} Uds', color: AppColors.actionGreen, icon: Icons.check_circle),
              MetricCard(
                title: 'LÍMITE MÁXIMO',
                value: '${k.pendienteProduccion} Uds',
                color: k.pendienteProduccion > 0 ? AppColors.alertRed : Colors.grey,
                icon: Icons.lock_clock,
              ),
              MetricCard(
                title: 'AVANCE',
                value: '${((k.producido / k.cantidadPedida).clamp(0.0, 1.0) * 100).toStringAsFixed(1)}%',
                color: AppColors.accentCyan,
                icon: Icons.donut_large,
              ),
            ]),
            if (!enviada) ...[
              const SizedBox(height: 12),
              TextField(
                controller: tarjeta.cantidadCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: wmsInput('Cantidad a enviar (máx ${k.pendienteProduccion} Uds)'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================================================== pestaña 3: historial

class _HistorialTab extends ConsumerWidget {
  const _HistorialTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lotes = ref.watch(wmsSnapshotProvider).value?.lotes ?? const [];
    if (lotes.isEmpty) {
      return const Center(child: Text('Aún no hay lotes.', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      itemCount: lotes.length,
      itemBuilder: (_, i) => _LoteExpandible(lote: lotes[i], indice: lotes.length - i),
    );
  }
}

Color _colorEstadoLote(EstadoLote e) => switch (e) {
      EstadoLote.enTransito => Colors.amber.shade800,
      EstadoLote.recibidoParcial => AppColors.accentCyan,
      EstadoLote.recibidoCompleto => AppColors.actionGreen,
    };

class _LoteExpandible extends StatelessWidget {
  const _LoteExpandible({required this.lote, required this.indice});

  final Lote lote;
  final int indice;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryNavy,
          child: Text('#$indice', style: const TextStyle(color: Colors.white, fontSize: 11)),
        ),
        title: Text(
          '${lote.id} — ${lote.totalLineas} producto(s)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Operario: ${lote.operario} | Fecha: ${formatFechaHora(lote.fechaEnvio)}'),
        trailing: StatusChip(label: lote.estado.etiqueta, color: _colorEstadoLote(lote.estado)),
        children: [
          for (final linea in lote.lineas)
            ListTile(
              dense: true,
              title: Text(
                'OP: ${linea.item.op} — ${linea.item.descripcion} (${linea.item.talla})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No. OC: ${linea.item.oc} | Enviadas: ${linea.cantidadEnviada} Uds'
                      '${linea.cantidadRecibida != null ? ' | Recibidas: ${linea.cantidadRecibida}' : ''}'),
                  if (linea.novedad.isNotEmpty)
                    Text('Novedad: ${linea.novedad}',
                        style: const TextStyle(color: AppColors.alertRed, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              trailing: StatusChip(label: linea.estado.etiqueta, color: colorDeEstadoLinea(linea.estado)),
            ),
        ],
      ),
    );
  }
}
