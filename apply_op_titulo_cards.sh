#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - OP en el titulo de las cards, No. OC en el subtitulo
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_op_titulo_cards.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi

echo "Aplicando OP en titulo + No. OC en subtitulo de las cards..."

echo "  - lib/features/produccion/presentation/entrega_produccion_dialog.dart"
mkdir -p "$(dirname 'lib/features/produccion/presentation/entrega_produccion_dialog.dart')"
cat > 'lib/features/produccion/presentation/entrega_produccion_dialog.dart' << 'ORBILOQ_EOF'
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
ORBILOQ_EOF

echo "  - lib/features/no_conforme/presentation/no_conforme_dialog.dart"
mkdir -p "$(dirname 'lib/features/no_conforme/presentation/no_conforme_dialog.dart')"
cat > 'lib/features/no_conforme/presentation/no_conforme_dialog.dart' << 'ORBILOQ_EOF'
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
import '../../../shared/widgets/addable_person_dropdown.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/labeled_dropdown.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showNoConformeDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const NoConformeDialog());

class NoConformeDialog extends StatelessWidget {
  const NoConformeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return WmsDialogShell(
      title: 'PRODUCTO NO CONFORME',
      icon: Icons.report_gmailerrorred,
      iconColor: AppColors.alertRed,
      expand: true,
      maxWidth: 1100,
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
                Tab(height: 38, icon: Icon(Icons.edit_note, size: 16), text: 'BÚSQUEDA MANUAL'),
                Tab(height: 38, icon: Icon(Icons.history, size: 16), text: 'HISTORIAL'),
              ],
            ),
            const SizedBox(height: 8),
            const Expanded(
              child: TabBarView(children: [_EscanearTab(), _ManualTab(), _HistorialTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una tarjeta = un producto que se va a reportar como no conforme, con su
/// propia cantidad, causal y nota. Independiente de cualquier lote.
class _TarjetaNoConforme {
  _TarjetaNoConforme({required this.itemId})
      : cantidadCtrl = TextEditingController(text: '1'),
        notaCtrl = TextEditingController();

  final String itemId;
  final TextEditingController cantidadCtrl;
  final TextEditingController notaCtrl;
  int conteo = 1;
  String? causalId;
  String? recibidoDeProduccion;
  bool enviando = false;
  bool enviada = false;

  void dispose() {
    cantidadCtrl.dispose();
    notaCtrl.dispose();
  }
}

Future<void> _reportarTodo({
  required WidgetRef ref,
  required List<_TarjetaNoConforme> pendientes,
  required String operario,
  required void Function(void Function()) setStateFn,
  required bool Function() estaMontado,
  required void Function(FeedbackMessage?) setMensaje,
}) async {
  for (final t in pendientes) {
    if (t.causalId == null) {
      setMensaje(const FeedbackMessage.error('Hay una tarjeta sin causal seleccionada.'));
      return;
    }
    if (t.recibidoDeProduccion == null || t.recibidoDeProduccion!.trim().isEmpty) {
      setMensaje(const FeedbackMessage.error('Hay una tarjeta sin indicar quién de Producción entregó la prenda.'));
      return;
    }
    final cantidad = int.tryParse(t.cantidadCtrl.text.trim()) ?? 0;
    if (cantidad <= 0) {
      setMensaje(const FeedbackMessage.error('Hay una tarjeta con cantidad inválida.'));
      return;
    }
  }

  setStateFn(() {
    setMensaje(null);
    for (final t in pendientes) {
      t.enviando = true;
    }
  });

  var okCount = 0;
  String? primerError;
  for (final t in pendientes) {
    final cantidad = int.tryParse(t.cantidadCtrl.text.trim()) ?? 0;
    final res = await ref.read(wmsRepositoryProvider).registrarNoConforme(
          itemId: t.itemId,
          cantidad: cantidad,
          causalId: t.causalId!,
          operario: operario,
          recibidoDeProduccion: t.recibidoDeProduccion!.trim(),
          nota: t.notaCtrl.text,
        );
    if (!estaMontado()) return;
    switch (res) {
      case Ok():
        okCount++;
        setStateFn(() {
          t.enviando = false;
          t.enviada = true;
        });
      case Err(:final message):
        primerError ??= message;
        setStateFn(() => t.enviando = false);
    }
  }

  setStateFn(() {
    if (primerError != null) {
      setMensaje(FeedbackMessage.error(
        okCount == 0 ? primerError : '$okCount reportado(s) — falló al menos uno: $primerError',
      ));
    } else {
      setMensaje(FeedbackMessage.ok('$okCount producto(s) reportado(s) como no conforme.'));
    }
  });
}

class _CausalDropdown extends ConsumerWidget {
  const _CausalDropdown({required this.valor, required this.onChanged});

  final String? valor;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final causales = ref.watch(causalesProvider);
    return causales.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('No se pudieron cargar las causales: $e', style: const TextStyle(color: AppColors.alertRed)),
      data: (lista) => DropdownButtonFormField<String>(
        initialValue: valor,
        decoration: wmsInput('Causal de la no conformidad', icon: Icons.report_problem_outlined),
        items: [for (final c in lista) DropdownMenuItem(value: c.id, child: Text(c.nombre))],
        onChanged: onChanged,
      ),
    );
  }
}

// ============================================================ pestaña 1: QR

class _EscanearTab extends ConsumerStatefulWidget {
  const _EscanearTab();

  @override
  ConsumerState<_EscanearTab> createState() => _EscanearTabState();
}

class _EscanearTabState extends ConsumerState<_EscanearTab> with AutomaticKeepAliveClientMixin {
  final _qrCtrl = TextEditingController();
  final _qrFocus = FocusNode();
  String _operario = WmsConstantes.operarios.first;
  final List<_TarjetaNoConforme> _tarjetas = [];
  FeedbackMessage? _msgGeneral;
  bool _enviandoTodo = false;

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

  _TarjetaNoConforme? _tarjetaActivaPara(String itemId) {
    for (final t in _tarjetas) {
      if (t.itemId == itemId && !t.enviada) return t;
    }
    return null;
  }

  void _procesarQR(String raw) {
    _qrCtrl.clear();
    if (raw.trim().isEmpty) return;
    final qr = QrPrenda.tryParse(raw);
    if (qr == null) {
      setState(() => _msgGeneral = FeedbackMessage.error('QR inválido. Formato esperado: ${QrPrenda.formato}'));
      return;
    }
    final kardex = ref.read(wmsSnapshotProvider).value?.kardexPorOpCodigo(qr.op, qr.codigo);
    if (kardex == null) {
      setState(() => _msgGeneral =
          FeedbackMessage.error('La prenda no existe en el kardex (OP ${qr.op} · Código ${qr.codigo}).'));
      return;
    }
    setState(() {
      _msgGeneral = null;
      final existente = _tarjetaActivaPara(kardex.id);
      if (existente != null) {
        _tarjetas.remove(existente);
        _tarjetas.insert(0, existente);
        existente.conteo++;
        existente.cantidadCtrl.text = '${existente.conteo}';
      } else {
        _tarjetas.insert(0, _TarjetaNoConforme(itemId: kardex.id));
      }
    });
    _qrFocus.requestFocus();
  }

  void _quitar(_TarjetaNoConforme t) {
    setState(() {
      t.dispose();
      _tarjetas.remove(t);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final snapshot = ref.watch(wmsSnapshotProvider).value;
    final pendientes = _tarjetas.where((t) => !t.enviada).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msgGeneral != null) ...[
            FeedbackBanner(message: _msgGeneral!),
            const SizedBox(height: 12),
          ],
          LabeledDropdown<String>(
            label: 'Reportado por',
            value: _operario,
            items: WmsConstantes.operarios,
            onChanged: (v) => setState(() => _operario = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qrCtrl,
            focusNode: _qrFocus,
            autofocus: true,
            decoration: wmsInput('PISTOLEE O ESCANEE QR DE LA PRENDA NO CONFORME', icon: Icons.qr_code_scanner),
            onSubmitted: _procesarQR,
          ),
          const SizedBox(height: 12),
          if (_tarjetas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Escanea una prenda para reportarla como no conforme.',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  pendientes.isNotEmpty ? '${pendientes.length} producto(s) por reportar' : 'Todo reportado',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                ActionButton(
                  icon: Icons.report_gmailerrorred,
                  label: 'REPORTAR TODO',
                  color: AppColors.alertRed,
                  busy: _enviandoTodo,
                  onPressed: pendientes.isEmpty
                      ? null
                      : () async {
                          setState(() => _enviandoTodo = true);
                          await _reportarTodo(
                            ref: ref,
                            pendientes: pendientes,
                            operario: _operario,
                            setStateFn: setState,
                            estaMontado: () => mounted,
                            setMensaje: (m) => _msgGeneral = m,
                          );
                          if (mounted) setState(() => _enviandoTodo = false);
                        },
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final t in _tarjetas) ...[
              _TarjetaWidget(tarjeta: t, kardex: snapshot?.kardexPorId(t.itemId), onQuitar: () => _quitar(t)),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

// ==================================================== pestaña 2: manual

class _ManualTab extends ConsumerStatefulWidget {
  const _ManualTab();

  @override
  ConsumerState<_ManualTab> createState() => _ManualTabState();
}

class _ManualTabState extends ConsumerState<_ManualTab> with AutomaticKeepAliveClientMixin {
  final _opCtrl = TextEditingController();
  String _operario = WmsConstantes.operarios.first;
  List<ItemKardex> _resultados = [];
  final Set<String> _seleccionados = {};
  final List<_TarjetaNoConforme> _tarjetas = [];
  String? _errorBusqueda;
  FeedbackMessage? _msgGeneral;
  bool _enviandoTodo = false;

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

  _TarjetaNoConforme? _tarjetaActivaPara(String itemId) {
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
      // Solo tiene sentido reportar productos que ya fueron entregados por Producción.
      _resultados = kardex.where((k) => k.item.op == op && k.producido > 0).toList();
      _errorBusqueda = _resultados.isEmpty
          ? 'No se encontraron tallas con unidades entregadas por Producción para la OP $op.'
          : null;
    });
  }

  void _agregarSeleccionadas() {
    setState(() {
      for (final id in _seleccionados) {
        if (_tarjetaActivaPara(id) != null) continue;
        _tarjetas.insert(0, _TarjetaNoConforme(itemId: id));
      }
      _seleccionados.clear();
      _resultados = [];
      _opCtrl.clear();
    });
  }

  void _quitar(_TarjetaNoConforme t) {
    setState(() {
      t.dispose();
      _tarjetas.remove(t);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final snapshot = ref.watch(wmsSnapshotProvider).value;
    final pendientes = _tarjetas.where((t) => !t.enviada).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msgGeneral != null) ...[
            FeedbackBanner(message: _msgGeneral!),
            const SizedBox(height: 12),
          ],
          LabeledDropdown<String>(
            label: 'Reportado por',
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
                      activeColor: AppColors.alertRed,
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
                      subtitle: Text('Entregadas por Producción: ${r.producido} Uds'),
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
                color: AppColors.primaryNavy,
                onPressed: _seleccionados.isEmpty ? null : _agregarSeleccionadas,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_tarjetas.isEmpty && _resultados.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Escribe una OP y busca para ver sus tallas entregadas.',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else if (_tarjetas.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  pendientes.isNotEmpty ? '${pendientes.length} producto(s) por reportar' : 'Todo reportado',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                ActionButton(
                  icon: Icons.report_gmailerrorred,
                  label: 'REPORTAR TODO',
                  color: AppColors.alertRed,
                  busy: _enviandoTodo,
                  onPressed: pendientes.isEmpty
                      ? null
                      : () async {
                          setState(() => _enviandoTodo = true);
                          await _reportarTodo(
                            ref: ref,
                            pendientes: pendientes,
                            operario: _operario,
                            setStateFn: setState,
                            estaMontado: () => mounted,
                            setMensaje: (m) => _msgGeneral = m,
                          );
                          if (mounted) setState(() => _enviandoTodo = false);
                        },
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final t in _tarjetas) ...[
              _TarjetaWidget(tarjeta: t, kardex: snapshot?.kardexPorId(t.itemId), onQuitar: () => _quitar(t)),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

// ==================================================== tarjeta (compartida)

class _TarjetaWidget extends StatefulWidget {
  const _TarjetaWidget({required this.tarjeta, required this.kardex, required this.onQuitar});

  final _TarjetaNoConforme tarjeta;
  final ItemKardex? kardex;
  final VoidCallback onQuitar;

  @override
  State<_TarjetaWidget> createState() => _TarjetaWidgetState();
}

class _TarjetaWidgetState extends State<_TarjetaWidget> {
  @override
  Widget build(BuildContext context) {
    final k = widget.kardex;
    final t = widget.tarjeta;
    if (k == null) return const SizedBox.shrink();
    final enviada = t.enviada;

    return Card(
      color: enviada ? Colors.grey.shade100 : Colors.red.shade50,
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
                      Text(
                        'OP: ${k.item.op} - ${k.item.descripcion} (${k.item.talla})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: enviada ? Colors.grey.shade600 : AppColors.primaryNavy,
                        ),
                      ),
                      Text('No. OC: ${k.item.oc} | Entregadas por Producción: ${k.producido} Uds',
                          style: TextStyle(color: enviada ? Colors.grey.shade600 : null)),
                    ],
                  ),
                ),
                if (enviada)
                  const Icon(Icons.check_circle, color: AppColors.actionGreen)
                else if (t.enviando)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  IconButton(
                    tooltip: 'Quitar esta tarjeta',
                    icon: const Icon(Icons.close, color: AppColors.alertRed),
                    onPressed: widget.onQuitar,
                  ),
              ],
            ),
            const Divider(),
            if (!enviada) ...[
              MetricWrap(children: [
                MetricCard(
                  title: 'ENTREGADAS',
                  value: '${k.producido} Uds',
                  color: AppColors.actionGreen,
                  icon: Icons.check_circle,
                ),
                MetricCard(
                  title: 'NO CONFORME ACTUAL',
                  value: '${k.pendienteReproceso} Uds',
                  color: k.pendienteReproceso > 0 ? AppColors.alertRed : Colors.grey,
                  icon: Icons.report_problem_outlined,
                ),
              ]),
              const SizedBox(height: 12),
              _CausalDropdown(
                valor: t.causalId,
                onChanged: (v) => setState(() => t.causalId = v),
              ),
              const SizedBox(height: 10),
              AddablePersonDropdown(
                label: 'Quién de Producción entregó la prenda',
                valor: t.recibidoDeProduccion,
                onChanged: (v) => setState(() => t.recibidoDeProduccion = v),
                itemsProvider: personalProduccionProvider,
                onAgregar: (ref, nombre) => ref.read(wmsRepositoryProvider).agregarPersonalProduccion(nombre),
                tituloDialogo: 'Agregar persona de Producción',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: t.cantidadCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: wmsInput('Cantidad no conforme (máx ${k.producido} Uds)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: t.notaCtrl,
                      decoration: wmsInput('Nota (opcional)', icon: Icons.note_outlined),
                    ),
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

// ==================================================== pestaña 3: historial

class _HistorialTab extends ConsumerStatefulWidget {
  const _HistorialTab();

  @override
  ConsumerState<_HistorialTab> createState() => _HistorialTabState();
}

class _HistorialTabState extends ConsumerState<_HistorialTab> {
  late Future<List<Devolucion>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = ref.read(wmsRepositoryProvider).cargarDevoluciones();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Devolucion>>(
      future: _futuro,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('No se pudo cargar el historial: ${snapshot.error}'));
        }
        final devoluciones = snapshot.data ?? const [];
        if (devoluciones.isEmpty) {
          return const Center(
            child: Text('Aún no hay productos no conformes reportados.', style: TextStyle(color: Colors.grey)),
          );
        }
        return ListView.builder(
          itemCount: devoluciones.length,
          itemBuilder: (_, i) {
            final d = devoluciones[i];
            return Card(
              child: ListTile(
                dense: true,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.alertRed,
                  child: Icon(Icons.report_problem_outlined, color: Colors.white, size: 18),
                ),
                title: Text(
                  '${d.item.codigo} (${d.item.talla}) — ${d.cantidad} Uds — ${d.causal}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'OP: ${d.item.op} | Reportado por: ${d.operario}'
                  '${d.recibidoDeProduccion.isNotEmpty ? ' | Recibido de Producción: ${d.recibidoDeProduccion}' : ''}'
                  ' | ${formatFechaHora(d.fecha)}'
                  '${d.nota.isNotEmpty ? ' | ${d.nota}' : ''}',
                ),
              ),
            );
          },
        );
      },
    );
  }
}
ORBILOQ_EOF

echo "  - lib/features/despacho/presentation/despacho_dialog.dart"
mkdir -p "$(dirname 'lib/features/despacho/presentation/despacho_dialog.dart')"
cat > 'lib/features/despacho/presentation/despacho_dialog.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import '../../../domain/qr_prenda.dart';
import '../../../shared/widgets/action_button.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/labeled_dropdown.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showDespachoDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const DespachoDialog());

class DespachoDialog extends ConsumerStatefulWidget {
  const DespachoDialog({super.key});

  @override
  ConsumerState<DespachoDialog> createState() => _DespachoDialogState();
}

class _DespachoDialogState extends ConsumerState<DespachoDialog> {
  final _qrCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController(text: '1');
  final _qrFocus = FocusNode();

  String? _itemId;
  String? _ubicacion;
  FeedbackMessage? _msg;

  @override
  void dispose() {
    _qrCtrl.dispose();
    _cantidadCtrl.dispose();
    _qrFocus.dispose();
    super.dispose();
  }

  void _error(String texto) {
    setState(() => _msg = FeedbackMessage.error(texto));
    _qrFocus.requestFocus();
  }

  void _procesarQR(String raw) {
    _qrCtrl.clear();
    if (raw.trim().isEmpty) return;

    final qr = QrPrenda.tryParse(raw);
    if (qr == null) {
      _error('QR inválido. Formato esperado: ${QrPrenda.formato}');
      return;
    }
    final k = ref.read(wmsSnapshotProvider).value?.kardexPorOpCodigo(qr.op, qr.codigo);
    if (k == null) {
      _error('La prenda no está registrada en el kardex.');
      return;
    }
    if (k.stockDisponible <= 0 || k.ubicaciones.isEmpty) {
      _error('La prenda no tiene stock disponible en bodega.');
      return;
    }
    setState(() {
      _itemId = k.id;
      _ubicacion = k.ubicaciones.keys.first;
      _cantidadCtrl.text = '1';
      _msg = null;
    });
  }

  /// Ubicación efectiva: la elegida si aún tiene stock; si no, la primera con stock.
  String? _ubicacionEfectiva(ItemKardex? k) {
    final opciones = k?.ubicaciones.keys.toList() ?? const <String>[];
    if (opciones.isEmpty) return null;
    return opciones.contains(_ubicacion) ? _ubicacion : opciones.first;
  }

  Future<void> _confirmar() async {
    final itemId = _itemId;
    if (itemId == null) return;
    final ubicacion = _ubicacionEfectiva(ref.read(wmsSnapshotProvider).value?.kardexPorId(itemId));
    if (ubicacion == null) return;
    final cantidad = int.tryParse(_cantidadCtrl.text.trim()) ?? 0;

    final res = await ref.read(wmsRepositoryProvider).despachar(
          itemId: itemId,
          cantidad: cantidad,
          ubicacion: ubicacion,
        );
    if (!mounted) return;

    switch (res) {
      case Ok():
        setState(() {
          _msg = FeedbackMessage.ok('Despacho de $cantidad Uds desde $ubicacion registrado.');
          _itemId = null;
          _ubicacion = null;
          _cantidadCtrl.text = '1';
        });
        _qrFocus.requestFocus();
      case Err(:final message):
        setState(() => _msg = FeedbackMessage.error(message));
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(wmsSnapshotProvider).value;
    final k = _itemId == null ? null : snapshot?.kardexPorId(_itemId!);
    final opciones = k?.ubicaciones.keys.toList() ?? const <String>[];
    final ubicacion = _ubicacionEfectiva(k);

    return WmsDialogShell(
      title: 'LOGÍSTICA: PICKING Y DESPACHO A CLIENTE',
      icon: Icons.local_shipping,
      iconColor: AppColors.actionOrange,
      maxWidth: 800,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msg != null) ...[
            FeedbackBanner(message: _msg!),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _qrCtrl,
            focusNode: _qrFocus,
            autofocus: true,
            decoration: wmsInput('ESCANEAR QR DE PRENDA A DESPACHAR', icon: Icons.qr_code_scanner),
            onSubmitted: _procesarQR,
          ),
          const SizedBox(height: 12),
          if (k != null)
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OP: ${k.item.op} - ${k.item.descripcion} (${k.item.talla})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text('No. OC: ${k.item.oc} | Cliente: ${k.item.cliente}'),
                    Text(
                      'Pendiente por despachar según la orden: ${k.pendienteDespacho} Uds',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.actionOrange),
                    ),
                    const Divider(),
                    if (ubicacion == null)
                      const Text('Sin stock disponible en ninguna ubicación.')
                    else
                      Row(
                        children: [
                          Expanded(
                            child: LabeledDropdown<String>(
                              label: 'Retirar del estante',
                              value: ubicacion,
                              items: opciones,
                              itemLabel: (u) => '$u (Disp: ${k.stockEn(u)})',
                              onChanged: (v) => setState(() => _ubicacion = v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: _cantidadCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: wmsInput('Cant.'),
                              onSubmitted: (_) => _confirmar(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ActionButton(
                            icon: Icons.upload,
                            label: 'DESPACHAR',
                            color: AppColors.actionOrange,
                            onPressed: _confirmar,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
ORBILOQ_EOF

echo "  - lib/features/reproceso/presentation/reproceso_dialog.dart"
mkdir -p "$(dirname 'lib/features/reproceso/presentation/reproceso_dialog.dart')"
cat > 'lib/features/reproceso/presentation/reproceso_dialog.dart' << 'ORBILOQ_EOF'
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
import '../../../shared/widgets/addable_person_dropdown.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/labeled_dropdown.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showReprocesoDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const ReprocesoDialog());

class ReprocesoDialog extends StatelessWidget {
  const ReprocesoDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return WmsDialogShell(
      title: 'PRODUCTOS NO CONFORME',
      icon: Icons.report_gmailerrorred,
      iconColor: AppColors.alertRed,
      expand: true,
      maxWidth: 1100,
      child: DefaultTabController(
        length: 2,
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
                Tab(height: 38, icon: Icon(Icons.report_problem_outlined, size: 16), text: 'NO CONFORME'),
                Tab(height: 38, icon: Icon(Icons.history, size: 16), text: 'HISTORIAL'),
              ],
            ),
            const SizedBox(height: 8),
            const Expanded(
              child: TabBarView(children: [_ListaTab(), _HistorialTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================ pestaña 1

class _ListaTab extends ConsumerStatefulWidget {
  const _ListaTab();

  @override
  ConsumerState<_ListaTab> createState() => _ListaTabState();
}

class _ListaTabState extends ConsumerState<_ListaTab> {
  final _opCtrl = TextEditingController();
  final _qrCtrl = TextEditingController();
  final Map<String, TextEditingController> _cantidadCtrls = {};
  final Map<String, bool> _liberando = {};
  final Map<String, String?> _recibidoPorLogistica = {};
  String _operario = WmsConstantes.operarios.first;
  String _filtroOp = '';
  FeedbackMessage? _msgGeneral;
  late Future<Map<String, List<String>>> _motivosFuturo;

  @override
  void initState() {
    super.initState();
    _motivosFuturo = _cargarMotivos();
  }

  /// Agrupa los motivos (causales) ya reportados por producto, para
  /// mostrarlos en cada tarjeta. Una misma prenda puede tener más de un
  /// motivo si se reportó no conforme más de una vez por razones distintas.
  Future<Map<String, List<String>>> _cargarMotivos() async {
    final devoluciones = await ref.read(wmsRepositoryProvider).cargarDevoluciones();
    final mapa = <String, List<String>>{};
    for (final d in devoluciones) {
      final lista = mapa.putIfAbsent(d.item.id, () => []);
      if (!lista.contains(d.causal)) lista.add(d.causal);
    }
    return mapa;
  }

  @override
  void dispose() {
    _opCtrl.dispose();
    _qrCtrl.dispose();
    for (final c in _cantidadCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrlPara(ItemKardex k) =>
      _cantidadCtrls.putIfAbsent(k.id, () => TextEditingController(text: '${k.pendienteReproceso}'));

  void _buscarOp() => setState(() => _filtroOp = _opCtrl.text.trim());

  void _limpiarFiltro() => setState(() {
        _filtroOp = '';
        _opCtrl.clear();
      });

  void _procesarQR(String raw) {
    _qrCtrl.clear();
    if (raw.trim().isEmpty) return;
    final qr = QrPrenda.tryParse(raw);
    if (qr == null) {
      setState(() => _msgGeneral = FeedbackMessage.error('QR inválido. Formato esperado: ${QrPrenda.formato}'));
      return;
    }
    final kardex = ref.read(wmsSnapshotProvider).value?.kardexPorOpCodigo(qr.op, qr.codigo);
    if (kardex == null) {
      setState(() => _msgGeneral = FeedbackMessage.error('La prenda no existe en el kardex.'));
      return;
    }
    if (kardex.pendienteReproceso <= 0) {
      setState(() => _msgGeneral =
          FeedbackMessage.error('${kardex.item.descripcion} (${kardex.item.talla}) no tiene unidades no conformes.'));
      return;
    }
    setState(() {
      _msgGeneral = null;
      _filtroOp = kardex.item.op;
      _opCtrl.text = kardex.item.op;
    });
  }

  Future<void> _liberar(ItemKardex k) async {
    final ctrl = _ctrlPara(k);
    final cantidad = int.tryParse(ctrl.text.trim()) ?? 0;
    if (cantidad <= 0) {
      setState(() => _msgGeneral = const FeedbackMessage.error('Ingresa una cantidad mayor a 0.'));
      return;
    }
    if (cantidad > k.pendienteReproceso) {
      setState(() => _msgGeneral =
          FeedbackMessage.error('LÍMITE EXCEDIDO: solo hay ${k.pendienteReproceso} Uds pendientes por reprocesar.'));
      return;
    }
    final recibidoPor = _recibidoPorLogistica[k.id]?.trim() ?? '';
    if (recibidoPor.isEmpty) {
      setState(() => _msgGeneral =
          const FeedbackMessage.error('Indica quién de Logística recibió esta prenda antes de liberar.'));
      return;
    }

    setState(() {
      _msgGeneral = null;
      _liberando[k.id] = true;
    });
    final res = await ref.read(wmsRepositoryProvider).liberarNoConforme(
          itemId: k.id,
          cantidad: cantidad,
          operario: _operario,
          recibidoPorLogistica: recibidoPor,
        );
    if (!mounted) return;
    setState(() {
      _liberando[k.id] = false;
      switch (res) {
        case Ok():
          _msgGeneral = FeedbackMessage.ok(
            '${cantidad}u de ${k.item.descripcion} (${k.item.talla}) liberadas — vuelven a Entregado a Logística.',
          );
          _cantidadCtrls.remove(k.id)?.dispose();
          _recibidoPorLogistica.remove(k.id);
        case Err(:final message):
          _msgGeneral = FeedbackMessage.error(message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final kardex = ref.watch(wmsSnapshotProvider).value?.kardex ?? const <ItemKardex>[];
    final noConformes = kardex.where((k) => k.pendienteReproceso > 0).toList()
      ..sort((a, b) => a.item.op.compareTo(b.item.op));
    final visibles =
        _filtroOp.isEmpty ? noConformes : noConformes.where((k) => k.item.op == _filtroOp).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_msgGeneral != null) ...[
          FeedbackBanner(message: _msgGeneral!),
          const SizedBox(height: 12),
        ],
        LabeledDropdown<String>(
          label: 'Liberado por',
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
                decoration: wmsInput('Buscar por número de OP', icon: Icons.tag),
                onSubmitted: (_) => _buscarOp(),
              ),
            ),
            const SizedBox(width: 8),
            ActionButton(icon: Icons.search, label: 'BUSCAR', color: AppColors.primaryNavy, onPressed: _buscarOp),
            if (_filtroOp.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton(tooltip: 'Quitar filtro', icon: const Icon(Icons.close), onPressed: _limpiarFiltro),
            ],
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _qrCtrl,
          decoration: wmsInput('O ESCANEAR QR PARA ENCONTRAR UNA PRENDA', icon: Icons.qr_code_scanner),
          onSubmitted: _procesarQR,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: visibles.isEmpty
              ? Center(
                  child: Text(
                    noConformes.isEmpty
                        ? 'No hay productos no conformes en este momento.'
                        : 'Ninguno coincide con la OP $_filtroOp.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              : FutureBuilder<Map<String, List<String>>>(
                  future: _motivosFuturo,
                  builder: (context, snapshotMotivos) {
                    final motivos = snapshotMotivos.data ?? const {};
                    return ListView.builder(
                      itemCount: visibles.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TarjetaNoConforme(
                          kardex: visibles[i],
                          cantidadCtrl: _ctrlPara(visibles[i]),
                          liberando: _liberando[visibles[i].id] ?? false,
                          motivos: motivos[visibles[i].id] ?? const [],
                          recibidoPorLogistica: _recibidoPorLogistica[visibles[i].id],
                          onRecibidoPorLogisticaChanged: (v) =>
                              setState(() => _recibidoPorLogistica[visibles[i].id] = v),
                          onLiberar: () => _liberar(visibles[i]),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TarjetaNoConforme extends StatelessWidget {
  const _TarjetaNoConforme({
    required this.kardex,
    required this.cantidadCtrl,
    required this.liberando,
    required this.motivos,
    required this.recibidoPorLogistica,
    required this.onRecibidoPorLogisticaChanged,
    required this.onLiberar,
  });

  final ItemKardex kardex;
  final TextEditingController cantidadCtrl;
  final bool liberando;
  final List<String> motivos;
  final String? recibidoPorLogistica;
  final ValueChanged<String?> onRecibidoPorLogisticaChanged;
  final VoidCallback onLiberar;

  @override
  Widget build(BuildContext context) {
    final k = kardex;
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OP: ${k.item.op} - ${k.item.descripcion} (${k.item.talla})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy),
            ),
            Text('No. OC: ${k.item.oc} | Cliente: ${k.item.cliente}'),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.report_problem_outlined, size: 16, color: AppColors.alertRed),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    motivos.isEmpty ? 'Motivo: sin registrar' : 'Motivo(s): ${motivos.join(', ')}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.alertRed,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            MetricWrap(children: [
              MetricCard(
                title: 'ENTREGADO A LOGÍSTICA',
                value: '${k.producido} Uds',
                color: AppColors.actionGreen,
                icon: Icons.check_circle,
              ),
              MetricCard(
                title: 'NO CONFORME',
                value: '${k.pendienteReproceso} Uds',
                color: AppColors.alertRed,
                icon: Icons.report_problem_outlined,
              ),
            ]),
            const SizedBox(height: 12),
            AddablePersonDropdown(
              label: 'Quién de Logística recibió la prenda',
              valor: recibidoPorLogistica,
              onChanged: onRecibidoPorLogisticaChanged,
              itemsProvider: personalLogisticaProvider,
              onAgregar: (ref, nombre) => ref.read(wmsRepositoryProvider).agregarPersonalLogistica(nombre),
              tituloDialogo: 'Agregar persona de Logística',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: cantidadCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: wmsInput('Cantidad a liberar (máx ${k.pendienteReproceso} Uds)'),
                  ),
                ),
                const SizedBox(width: 10),
                ActionButton(
                  icon: Icons.check_circle_outline,
                  label: 'LIBERAR',
                  color: AppColors.actionGreen,
                  busy: liberando,
                  onPressed: onLiberar,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================== pestaña 2: historial

class _HistorialTab extends ConsumerStatefulWidget {
  const _HistorialTab();

  @override
  ConsumerState<_HistorialTab> createState() => _HistorialTabState();
}

class _HistorialTabState extends ConsumerState<_HistorialTab> {
  late Future<List<Liberacion>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = ref.read(wmsRepositoryProvider).cargarLiberaciones();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Liberacion>>(
      future: _futuro,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('No se pudo cargar el historial: ${snapshot.error}'));
        }
        final liberaciones = snapshot.data ?? const [];
        if (liberaciones.isEmpty) {
          return const Center(child: Text('Aún no hay liberaciones registradas.', style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          itemCount: liberaciones.length,
          itemBuilder: (_, i) {
            final l = liberaciones[i];
            return Card(
              child: ListTile(
                dense: true,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.actionGreen,
                  child: Icon(Icons.check, color: Colors.white, size: 18),
                ),
                title: Text(
                  '${l.item.codigo} (${l.item.talla}) — ${l.cantidad} Uds liberadas',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'OP: ${l.item.op} | Por: ${l.operario}'
                  '${l.recibidoPorLogistica.isNotEmpty ? ' | Recibido por Logística: ${l.recibidoPorLogistica}' : ''}'
                  ' | ${formatFechaHora(l.fecha)}'
                  '${l.nota.isNotEmpty ? ' | ${l.nota}' : ''}',
                ),
              ),
            );
          },
        );
      },
    );
  }
}
ORBILOQ_EOF

echo "  - lib/features/ubicaciones/presentation/ubicaciones_dialog.dart"
mkdir -p "$(dirname 'lib/features/ubicaciones/presentation/ubicaciones_dialog.dart')"
cat > 'lib/features/ubicaciones/presentation/ubicaciones_dialog.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/action_button.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/labeled_dropdown.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showUbicacionesDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const UbicacionesDialog());

typedef _Existencia = ({ItemKardex item, int cantidad});

class UbicacionesDialog extends ConsumerStatefulWidget {
  const UbicacionesDialog({super.key});

  @override
  ConsumerState<UbicacionesDialog> createState() => _UbicacionesDialogState();
}

class _UbicacionesDialogState extends ConsumerState<UbicacionesDialog> {
  String _ubicacion = WmsConstantes.ubicaciones.first;
  FeedbackMessage? _msg;

  Future<void> _imprimir(List<_Existencia> items, int total) async {
    final imprimir = await showDialog<bool>(
      context: context,
      builder: (_) => dialogoClaro(_TicketDialog(ubicacion: _ubicacion, items: items, total: total)),
    );
    if (imprimir == true && mounted) {
      setState(() => _msg = FeedbackMessage.ok('Ticket de $_ubicacion enviado a impresora térmica.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final kardex = ref.watch(kardexProvider);
    final items = <_Existencia>[
      for (final k in kardex)
        if (k.stockEn(_ubicacion) > 0) (item: k, cantidad: k.stockEn(_ubicacion)),
    ];
    final total = items.fold<int>(0, (s, e) => s + e.cantidad);

    return WmsDialogShell(
      title: 'CONSULTA DE EXISTENCIAS POR ESTANTE',
      icon: Icons.domain,
      iconColor: AppColors.primaryNavy,
      maxWidth: 850,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msg != null) ...[
            FeedbackBanner(message: _msg!),
            const SizedBox(height: 12),
          ],
          LabeledDropdown<String>(
            label: 'Seleccionar estante / rack',
            value: _ubicacion,
            items: WmsConstantes.ubicaciones,
            onChanged: (v) => setState(() {
              _ubicacion = v;
              _msg = null;
            }),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total en $_ubicacion: $total unidades disponibles',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                  ),
                ),
                ActionButton(
                  icon: Icons.print,
                  label: 'TICKET',
                  color: AppColors.actionGreen,
                  onPressed: items.isEmpty ? null : () => _imprimir(items, total),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Este estante no tiene existencias.')),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final e = items[i];
                  return ListTile(
                    dense: true,
                    title: Text(
                      'OP: ${e.item.item.op} - ${e.item.item.descripcion} (${e.item.item.talla})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('No. OC: ${e.item.item.oc} | Cliente: ${e.item.item.cliente}'),
                    trailing: Text(
                      '${e.cantidad} Uds',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.actionGreen),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TicketDialog extends StatelessWidget {
  const _TicketDialog({required this.ubicacion, required this.items, required this.total});

  final String ubicacion;
  final List<_Existencia> items;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 380, maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 2)),
                    child: Column(
                      children: [
                        const Text('ORBILOQ WMS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Text('RÓTULO DE UBICACIÓN FÍSICA', style: TextStyle(fontSize: 11)),
                        const Divider(thickness: 1.5, color: Colors.black),
                        Text(ubicacion, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          height: 110,
                          width: 110,
                          decoration: BoxDecoration(color: Colors.grey.shade200, border: Border.all(color: Colors.black)),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_2, size: 70),
                              Text('SCAN UBICACIÓN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('QR ID: LOC-$ubicacion', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                        const Divider(color: Colors.black),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('CONTENIDO ALMACENADO:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 4),
                        for (final e in items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${e.item.item.codigo} (${e.item.item.talla}) OP:${e.item.item.op}',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                                Text('${e.cantidad} Uds', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        const Divider(color: Colors.black),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('TOTAL EN ESTANTE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('$total UDS', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cerrar')),
                  const SizedBox(width: 8),
                  ActionButton(
                    icon: Icons.print,
                    label: 'IMPRIMIR',
                    color: AppColors.actionGreen,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
ORBILOQ_EOF

echo "  - lib/features/recepcion/presentation/recepcion_dialog.dart"
mkdir -p "$(dirname 'lib/features/recepcion/presentation/recepcion_dialog.dart')"
cat > 'lib/features/recepcion/presentation/recepcion_dialog.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/constants.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import '../../../domain/qr_prenda.dart';
import '../../../shared/widgets/action_button.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/labeled_dropdown.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showRecepcionDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const RecepcionDialog());

/// Empareja una línea con su lote de origen — solo para mostrar la
/// referencia ("LOTE-101") en la lista plana; no cambia el modelo de datos.
class _LineaConLote {
  const _LineaConLote(this.lote, this.linea);
  final Lote lote;
  final LoteLinea linea;
}

class RecepcionDialog extends ConsumerStatefulWidget {
  const RecepcionDialog({super.key});

  @override
  ConsumerState<RecepcionDialog> createState() => _RecepcionDialogState();
}

class _RecepcionDialogState extends ConsumerState<RecepcionDialog> {
  final _scanCtrl = TextEditingController();
  final _scanFocus = FocusNode();
  final _scrollController = ScrollController();
  final _cantidadCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();

  /// Ids de línea que se han escaneado/buscado, más reciente primero — así
  /// se arma el orden "la última que pistoleaste sube al tope".
  final List<String> _ordenManual = [];

  String? _lineaAbiertaId;

  /// Cuántas unidades se han pistoleado por línea (sube de a 1 en cada
  /// escaneo, hasta el máximo declarado).
  final Map<String, int> _conteos = {};
  String _ubicacion = WmsConstantes.ubicaciones.first;
  bool _confirmando = false;
  FeedbackMessage? _msg;

  @override
  void dispose() {
    _scanCtrl.dispose();
    _scanFocus.dispose();
    _scrollController.dispose();
    _cantidadCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  List<_LineaConLote> get _todasPendientes {
    final lotes = ref.read(wmsSnapshotProvider).value?.lotes ?? const <Lote>[];
    final resultado = <_LineaConLote>[];
    for (final l in lotes) {
      for (final li in l.lineas) {
        if (li.enTransito) resultado.add(_LineaConLote(l, li));
      }
    }
    return resultado;
  }

  List<_LineaConLote> _ordenar(List<_LineaConLote> items) {
    final restantes = [...items]..sort((a, b) => a.linea.item.op.compareTo(b.linea.item.op));
    final resultado = <_LineaConLote>[];
    for (final id in _ordenManual) {
      final idx = restantes.indexWhere((e) => e.linea.id == id);
      if (idx != -1) resultado.add(restantes.removeAt(idx));
    }
    resultado.addAll(restantes);
    return resultado;
  }

  void _abrirValidacion(LoteLinea linea) {
    setState(() {
      _lineaAbiertaId = linea.id;
      _cantidadCtrl.text = '${_conteos[linea.id] ?? 0}';
      _notaCtrl.clear();
      _ubicacion = WmsConstantes.ubicaciones.first;
      _msg = null;
    });
  }

  void _subirAlTope(String lineaId) {
    _ordenManual.remove(lineaId);
    _ordenManual.insert(0, lineaId);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _procesarEntrada(String raw) {
    _scanCtrl.clear();
    if (raw.trim().isEmpty) return;
    final todas = _todasPendientes;

    final qr = QrPrenda.tryParse(raw);
    if (qr != null) {
      final encontrada = todas
          .where((e) => e.linea.item.op == qr.op && e.linea.item.codigo == qr.codigo)
          .map((e) => e.linea)
          .firstOrNull;
      if (encontrada == null) {
        setState(() => _msg = const FeedbackMessage.error('No hay ninguna línea pendiente por recibir para esta prenda.'));
        _scanFocus.requestFocus();
        return;
      }

      final actual = _conteos[encontrada.id] ?? 0;
      if (actual >= encontrada.cantidadEnviada) {
        setState(() => _msg = FeedbackMessage.error(
              'LÍMITE ALCANZADO: ya se contaron las ${encontrada.cantidadEnviada} Uds declaradas de esta prenda.',
            ));
        _scanFocus.requestFocus();
        return;
      }

      final mismaLineaYaAbierta = _lineaAbiertaId == encontrada.id;
      setState(() {
        _msg = null;
        _conteos[encontrada.id] = actual + 1;
        _subirAlTope(encontrada.id);
        _lineaAbiertaId = encontrada.id;
        _cantidadCtrl.text = '${_conteos[encontrada.id]}';
        if (!mismaLineaYaAbierta) {
          _notaCtrl.clear();
          _ubicacion = WmsConstantes.ubicaciones.first;
        }
      });
      _scanFocus.requestFocus();
      return;
    }

    // No es un QR: se interpreta como número de OP — sube todas sus líneas.
    final op = raw.trim();
    final coincidencias = todas.where((e) => e.linea.item.op == op).toList();
    if (coincidencias.isEmpty) {
      setState(() => _msg = FeedbackMessage.error('No hay líneas pendientes por recibir para la OP $op.'));
      _scanFocus.requestFocus();
      return;
    }
    setState(() {
      _msg = null;
      for (final c in coincidencias.reversed) {
        _subirAlTope(c.linea.id);
      }
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    _scanFocus.requestFocus();
  }

  Future<void> _confirmar(LoteLinea linea) async {
    final cantidad = int.tryParse(_cantidadCtrl.text.trim());
    if (cantidad == null) {
      setState(() => _msg = const FeedbackMessage.error('Ingresa una cantidad válida.'));
      return;
    }

    setState(() {
      _confirmando = true;
      _msg = null;
    });
    final res = await ref.read(wmsRepositoryProvider).recibirLoteLinea(
          loteLineaId: linea.id,
          cantidad: cantidad,
          ubicacion: _ubicacion,
          nota: _notaCtrl.text,
        );
    if (!mounted) return;

    switch (res) {
      case Ok(:final value):
        setState(() {
          _confirmando = false;
          _msg = FeedbackMessage.ok(
            '${linea.item.codigo} (${linea.item.talla}): ${value.estado.etiqueta}. Ingresada a $_ubicacion.',
          );
          _lineaAbiertaId = null;
          _ordenManual.remove(linea.id);
          _conteos.remove(linea.id);
        });
      case Err(:final message):
        setState(() {
          _confirmando = false;
          _msg = FeedbackMessage.error(message);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se observa el snapshot para reconstruir cuando cambian los lotes.
    ref.watch(wmsSnapshotProvider);
    final pendientes = _ordenar(_todasPendientes);

    return WmsDialogShell(
      title: 'RECEPCIÓN Y REPORTE DE NOVEDADES',
      icon: Icons.move_to_inbox,
      iconColor: AppColors.primaryNavy,
      expand: true,
      maxWidth: 1000,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_msg != null) ...[
                FeedbackBanner(message: _msg!),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _scanCtrl,
                focusNode: _scanFocus,
                autofocus: true,
                decoration: wmsInput('ESCANEAR PRENDA O BUSCAR POR OP', icon: Icons.qr_code_scanner),
                onSubmitted: _procesarEntrada,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: pendientes.isEmpty
                    ? const Center(
                        child: Text('No hay nada pendiente por recibir en este momento.',
                            style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: pendientes.length,
                        itemBuilder: (_, i) {
                          final e = pendientes[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TarjetaLinea(
                              lote: e.lote,
                              linea: e.linea,
                              abierta: e.linea.id == _lineaAbiertaId,
                              onValidar: () => _abrirValidacion(e.linea),
                              onCerrar: () => setState(() => _lineaAbiertaId = null),
                              cantidadCtrl: _cantidadCtrl,
                              notaCtrl: _notaCtrl,
                              ubicacion: _ubicacion,
                              onUbicacion: (v) => setState(() => _ubicacion = v),
                              onConfirmar: () => _confirmar(e.linea),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          if (_confirmando)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LogoLoader(size: 72),
                      SizedBox(height: 16),
                      Text(
                        'Procesando…',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _TarjetaLinea extends StatelessWidget {
  const _TarjetaLinea({
    required this.lote,
    required this.linea,
    required this.abierta,
    required this.onValidar,
    required this.onCerrar,
    required this.cantidadCtrl,
    required this.notaCtrl,
    required this.ubicacion,
    required this.onUbicacion,
    required this.onConfirmar,
  });

  final Lote lote;
  final LoteLinea linea;
  final bool abierta;
  final VoidCallback onValidar;
  final VoidCallback onCerrar;
  final TextEditingController cantidadCtrl;
  final TextEditingController notaCtrl;
  final String ubicacion;
  final ValueChanged<String> onUbicacion;
  final VoidCallback onConfirmar;

  @override
  Widget build(BuildContext context) {
    final colorBase = linea.esReproceso ? Colors.amber.shade50 : Colors.white;
    return Card(
      color: abierta ? Colors.green.shade50 : colorBase,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: abierta
              ? AppColors.actionGreen
              : linea.esReproceso
                  ? Colors.amber.shade700
                  : Colors.grey.shade300,
          width: abierta ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                            'OP: ${linea.item.op} (${linea.item.talla}) - ${linea.item.descripcion}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryNavy),
                          ),
                          if (linea.esReproceso)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade700,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('PRODUCTO REPROCESADO',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      Text(
                        'No. OC: ${linea.item.oc} | ${linea.cantidadEnviada} Uds | '
                        'Lote: ${lote.id} (${lote.operario})',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                if (!abierta)
                  ActionButton(icon: Icons.qr_code, label: 'VALIDAR', color: AppColors.primaryNavy, onPressed: onValidar)
                else
                  IconButton(tooltip: 'Cerrar', icon: const Icon(Icons.close), onPressed: onCerrar),
              ],
            ),
            if (abierta) ...[
              const Divider(),
              if (linea.esReproceso) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    children: [
                      Icon(Icons.autorenew, size: 16, color: Colors.amber.shade900),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Esta prenda era producto no conforme, ya fue reprocesada por Producción.',
                          style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.w600, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: LabeledDropdown<String>(
                      label: 'Estante físico',
                      value: ubicacion,
                      items: WmsConstantes.ubicaciones,
                      onChanged: onUbicacion,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: cantidadCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _MaxValorFormatter(linea.cantidadEnviada),
                      ],
                      decoration: wmsInput('Cant. validada (máx ${linea.cantidadEnviada})'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notaCtrl,
                decoration: wmsInput('Nota de novedad para Producción (opcional)', icon: Icons.warning_amber),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: onConfirmar,
                  icon: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  label: const Text('INGRESAR A ESTANTE & CONFIRMAR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.actionGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Impide que el campo acepte un número mayor al máximo permitido.
class _MaxValorFormatter extends TextInputFormatter {
  _MaxValorFormatter(this.maximo);
  final int maximo;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final valor = int.tryParse(newValue.text);
    if (valor == null || valor > maximo) return oldValue;
    return newValue;
  }
}

/// Logo de ORBILOQ girando, usado como loader de pantalla completa.
class _LogoLoader extends StatefulWidget {
  const _LogoLoader({this.size = 20});
  final double size;

  @override
  State<_LogoLoader> createState() => _LogoLoaderState();
}

class _LogoLoaderState extends State<_LogoLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: ClipOval(
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          padding: EdgeInsets.all(widget.size * 0.08),
          child: Image.asset(
            'assets/images/logo_orbiloq.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => SizedBox(
              width: widget.size,
              height: widget.size,
              child: const CircularProgressIndicator(strokeWidth: 3, color: AppColors.tealAccent),
            ),
          ),
        ),
      ),
    );
  }
}
ORBILOQ_EOF

echo "Listo. Revisa el diff con: git diff --stat"
