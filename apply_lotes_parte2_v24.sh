#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Modelo de LOTES, parte 2/2: pantallas (v24)
# Requiere haber corrido antes apply_lotes_parte1_v23.sh
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_lotes_parte2_v24.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi

echo "Aplicando el modelo de lotes (parte 2/2: pantallas)..."

echo "  - lib/shared/widgets/status_chip.dart"
mkdir -p "$(dirname 'lib/shared/widgets/status_chip.dart')"
cat > 'lib/shared/widgets/status_chip.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}

Color colorDeEstadoLinea(EstadoLineaLote e) => switch (e) {
      EstadoLineaLote.enTransito => Colors.amber.shade800,
      EstadoLineaLote.recibidoConforme => AppColors.actionGreen,
      EstadoLineaLote.recibidoConNovedad => AppColors.alertRed,
    };
ORBILOQ_EOF

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
                            '${k.item.codigo} - ${k.item.descripcion} (${k.item.talla})',
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
                        'OP: ${k.item.op} | OC: ${k.item.oc} | Cliente: ${k.item.cliente}',
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
                '${linea.item.codigo} — ${linea.item.descripcion} (${linea.item.talla})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('OP: ${linea.item.op} | Enviadas: ${linea.cantidadEnviada} Uds'
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

class RecepcionDialog extends ConsumerStatefulWidget {
  const RecepcionDialog({super.key});

  @override
  ConsumerState<RecepcionDialog> createState() => _RecepcionDialogState();
}

class _RecepcionDialogState extends ConsumerState<RecepcionDialog> {
  final _scanLoteCtrl = TextEditingController();
  final _scanPrendaCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  final _scanPrendaFocus = FocusNode();

  String? _loteId;
  String? _lineaId;
  String _ubicacion = WmsConstantes.ubicaciones.first;
  int _conteo = 0;
  FeedbackMessage? _msg;

  @override
  void dispose() {
    _scanLoteCtrl.dispose();
    _scanPrendaCtrl.dispose();
    _cantidadCtrl.dispose();
    _notaCtrl.dispose();
    _scanPrendaFocus.dispose();
    super.dispose();
  }

  List<Lote> get _lotesEnTransito =>
      (ref.read(wmsSnapshotProvider).value?.lotes ?? const <Lote>[]).where((l) => l.tienePendientes).toList();

  void _seleccionarLote(Lote l) {
    setState(() {
      _loteId = l.id;
      _lineaId = null;
      _msg = null;
    });
  }

  void _volverALotes() {
    setState(() {
      _loteId = null;
      _lineaId = null;
      _msg = null;
    });
  }

  void _seleccionarLinea(LoteLinea l) {
    setState(() {
      _lineaId = l.id;
      _cantidadCtrl.text = '${l.cantidadEnviada}';
      _conteo = 0;
      _notaCtrl.clear();
      _msg = null;
    });
  }

  void _procesarScanLote(String raw) {
    final query = raw.trim().toUpperCase();
    _scanLoteCtrl.clear();
    if (query.isEmpty) return;
    final coincidencias = _lotesEnTransito.where(
      (l) => l.id.toUpperCase() == query || l.lineas.any((linea) => linea.item.op == query),
    );
    if (coincidencias.isEmpty) {
      setState(() => _msg = const FeedbackMessage.error('Lote no encontrado en tránsito.'));
      return;
    }
    _seleccionarLote(coincidencias.first);
  }

  void _procesarScanPrenda(String raw, LoteLinea linea) {
    _scanPrendaCtrl.clear();
    if (raw.trim().isEmpty) return;
    final qr = QrPrenda.tryParse(raw);
    if (qr == null) {
      setState(() => _msg = FeedbackMessage.error('QR inválido. Formato esperado: ${QrPrenda.formato}'));
    } else if (qr.op != linea.item.op || qr.codigo != linea.item.codigo) {
      setState(() => _msg = const FeedbackMessage.error('La prenda NO corresponde a esta línea.'));
    } else {
      setState(() {
        _conteo++;
        _cantidadCtrl.text = '$_conteo';
        _msg = null;
      });
    }
    _scanPrendaFocus.requestFocus();
  }

  Future<void> _confirmar(LoteLinea linea) async {
    final cantidad = int.tryParse(_cantidadCtrl.text.trim());
    if (cantidad == null) {
      setState(() => _msg = const FeedbackMessage.error('Ingresa una cantidad válida.'));
      return;
    }

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
          _msg = FeedbackMessage.ok(
            '${linea.item.codigo} (${linea.item.talla}): ${value.estado.etiqueta}. Ingresada a $_ubicacion.',
          );
          _lineaId = null;
          _conteo = 0;
        });
      case Err(:final message):
        setState(() => _msg = FeedbackMessage.error(message));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se observa el snapshot para reconstruir cuando cambian los lotes.
    ref.watch(wmsSnapshotProvider);
    final lotesEnTransito = _lotesEnTransito;
    final loteSeleccionado = lotesEnTransito.where((l) => l.id == _loteId).firstOrNull;
    final lineasPendientes = loteSeleccionado?.lineas.where((l) => l.enTransito).toList() ?? const [];
    final lineaSeleccionada = lineasPendientes.where((l) => l.id == _lineaId).firstOrNull;

    return WmsDialogShell(
      title: 'RECEPCIÓN DE LOTES Y REPORTE DE NOVEDADES',
      icon: Icons.move_to_inbox,
      iconColor: AppColors.primaryNavy,
      maxWidth: 1000,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msg != null) ...[
            FeedbackBanner(message: _msg!),
            const SizedBox(height: 12),
          ],
          if (loteSeleccionado == null) ...[
            TextField(
              controller: _scanLoteCtrl,
              autofocus: true,
              decoration: wmsInput('ESCANEAR LOTE O BUSCAR OP (Ej. LOTE-101)', icon: Icons.qr_code_scanner),
              onSubmitted: _procesarScanLote,
            ),
            const SizedBox(height: 12),
            if (lotesEnTransito.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('No hay lotes pendientes.', style: TextStyle(color: Colors.grey))),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: lotesEnTransito.length,
                  itemBuilder: (_, i) {
                    final l = lotesEnTransito[i];
                    return Card(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ListTile(
                        dense: true,
                        title: Text('${l.id} — ${l.totalLineas} producto(s)',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Envía: ${l.operario} | ${l.lineasPendientes} pendiente(s) por recibir'),
                        trailing: ActionButton(
                          icon: Icons.qr_code,
                          label: 'ABRIR',
                          color: AppColors.primaryNavy,
                          onPressed: () => _seleccionarLote(l),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ] else ...[
            Row(
              children: [
                IconButton(
                  tooltip: 'Volver a la lista de lotes',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _volverALotes,
                ),
                Expanded(
                  child: Text(
                    '${loteSeleccionado.id} — ${loteSeleccionado.operario}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy),
                  ),
                ),
              ],
            ),
            const Divider(),
            if (lineasPendientes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('Ya se recibieron todas las líneas de este lote.',
                    style: TextStyle(color: Colors.grey))),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: lineasPendientes.length,
                  itemBuilder: (_, i) {
                    final linea = lineasPendientes[i];
                    final sel = linea.id == _lineaId;
                    return Card(
                      color: sel ? Colors.blue.shade50 : Colors.white,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: sel ? AppColors.primaryNavy : Colors.grey.shade300, width: sel ? 2 : 1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          '${linea.item.codigo} (${linea.item.talla}) - ${linea.item.descripcion}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('OP: ${linea.item.op} | OC: ${linea.item.oc} | ${linea.cantidadEnviada} Uds'),
                        trailing: ActionButton(
                          icon: Icons.qr_code,
                          label: 'VALIDAR',
                          color: AppColors.primaryNavy,
                          onPressed: () => _seleccionarLinea(linea),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (lineaSeleccionada != null) ...[
              const SizedBox(height: 12),
              _Validacion(
                linea: lineaSeleccionada,
                scanCtrl: _scanPrendaCtrl,
                scanFocus: _scanPrendaFocus,
                cantidadCtrl: _cantidadCtrl,
                notaCtrl: _notaCtrl,
                ubicacion: _ubicacion,
                onUbicacion: (v) => setState(() => _ubicacion = v),
                onScan: (raw) => _procesarScanPrenda(raw, lineaSeleccionada),
                onConfirmar: () => _confirmar(lineaSeleccionada),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _Validacion extends StatelessWidget {
  const _Validacion({
    required this.linea,
    required this.scanCtrl,
    required this.scanFocus,
    required this.cantidadCtrl,
    required this.notaCtrl,
    required this.ubicacion,
    required this.onUbicacion,
    required this.onScan,
    required this.onConfirmar,
  });

  final LoteLinea linea;
  final TextEditingController scanCtrl;
  final FocusNode scanFocus;
  final TextEditingController cantidadCtrl;
  final TextEditingController notaCtrl;
  final String ubicacion;
  final ValueChanged<String> onUbicacion;
  final ValueChanged<String> onScan;
  final VoidCallback onConfirmar;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'VALIDACIÓN: ${linea.item.codigo} (Declarado: ${linea.cantidadEnviada} Uds)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy),
            ),
            const Divider(),
            TextField(
              controller: scanCtrl,
              focusNode: scanFocus,
              decoration: wmsInput('PISTOLEADO 1 A 1 PARA RECONTEO (SUBE CONTADOR)', icon: Icons.flash_on),
              onSubmitted: onScan,
            ),
            const SizedBox(height: 10),
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: wmsInput('Cant. validada'),
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
              child: ActionButton(
                icon: Icons.check_circle,
                label: 'INGRESAR A ESTANTE & CONFIRMAR',
                color: AppColors.actionGreen,
                onPressed: onConfirmar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
ORBILOQ_EOF

echo "  - lib/features/kardex/presentation/kardex_page.dart"
mkdir -p "$(dirname 'lib/features/kardex/presentation/kardex_page.dart')"
cat > 'lib/features/kardex/presentation/kardex_page.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/auth_providers.dart';
import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import '../../../domain/sesion.dart';
import '../../despacho/presentation/despacho_dialog.dart';
import '../../importacion/presentation/importar_ordenes_dialog.dart';
import '../../produccion/presentation/entrega_produccion_dialog.dart';
import '../../recepcion/presentation/recepcion_dialog.dart';
import '../../ubicaciones/presentation/ubicaciones_dialog.dart';
import 'kardex_filters_bar.dart';
import 'kardex_summary_cards.dart';
import 'kardex_table.dart';

class KardexPage extends ConsumerStatefulWidget {
  const KardexPage({super.key});

  @override
  ConsumerState<KardexPage> createState() => _KardexPageState();
}

class _KardexPageState extends ConsumerState<KardexPage> {
  bool _sincronizando = false;

  Future<void> _sincronizar() async {
    setState(() => _sincronizando = true);
    await ref.read(wmsRepositoryProvider).refrescar();
    if (!mounted) return;
    setState(() => _sincronizando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Datos sincronizados'),
        backgroundColor: AppColors.actionGreen,
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rol = ref.watch(rolProvider);
    final snapshot = ref.watch(wmsSnapshotProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkHeader,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        toolbarHeight: 72,
        surfaceTintColor: AppColors.darkHeader,
        shape: const Border(bottom: BorderSide(color: AppColors.darkCardBorder)),
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.tealPrimary, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkTextPrimary),
                    children: [
                      TextSpan(text: 'ORBILOQ '),
                      TextSpan(
                        text: '| KARDEX MAESTRO',
                        style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.tealAccent),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'CONTROL OPERATIVO DE BODEGA Y PRODUCCIÓN',
                  style: TextStyle(fontSize: 10, color: AppColors.darkTextMuted, letterSpacing: 0.4),
                ),
              ],
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => showImportarOrdenesDialog(context),
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: const Text('Importar Excel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.darkTextSecondary,
              side: const BorderSide(color: AppColors.darkCardBorder),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _sincronizando ? null : _sincronizar,
            icon: _sincronizando
                ? const SizedBox(
                    width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.sync, size: 18),
            label: Text(_sincronizando ? 'Sincronizando...' : 'Sincronizar BD'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tealPrimary,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          _SelectorPerfil(rol: rol),
          const SizedBox(width: 20),
        ],
      ),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.tealAccent)),
        error: (e, _) => Center(
          child: Text('Error cargando datos: $e', style: const TextStyle(color: AppColors.darkTextPrimary)),
        ),
        data: (s) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cabecera(rol: rol, enTransito: s.lotesConPendientes),
              const SizedBox(height: 20),
              const KardexSummaryCards(),
              const SizedBox(height: 20),
              const KardexFiltersBar(),
              const SizedBox(height: 16),
              const KardexTable(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón-píldora "PERFIL DE TRABAJO" que abre un menú con los roles
/// disponibles. Solo muestra los 2 que funcionan hoy (Producción y Bodega).
class _SelectorPerfil extends ConsumerWidget {
  const _SelectorPerfil({required this.rol});

  final Rol rol;

  IconData _icono(Rol r) => r == Rol.produccion ? Icons.content_cut : Icons.warehouse_outlined;
  String _etiqueta(Rol r) => r == Rol.produccion ? 'Producción' : 'Bodega';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usarSupabase = ref.watch(usarSupabaseProvider);
    final sesion = usarSupabase ? ref.watch(usuarioSesionProvider).value : null;
    final esAdmin = !usarSupabase || sesion?.rolCuenta == RolCuenta.admin;

    final pastilla = esAdmin
        ? _pastillaDesplegable(context, ref)
        : _pastillaFija(sesion?.nombre ?? _etiqueta(rol));

    if (!usarSupabase) return pastilla; // modo memoria: sin sesión que cerrar

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pastilla,
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Cerrar sesión',
          icon: const Icon(Icons.logout, size: 18, color: AppColors.darkTextMuted),
          onPressed: () => ref.read(authRepositoryProvider)?.cerrarSesion(),
        ),
      ],
    );
  }

  /// Producción o Logística: no pueden cambiar de rol, solo ven quiénes son.
  Widget _pastillaFija(String nombre) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.tealPrimary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.tealPrimary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icono(rol), size: 16, color: AppColors.tealAccent),
          const SizedBox(width: 8),
          Text(nombre, style: const TextStyle(color: AppColors.tealAccent, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  /// Administrador (o modo memoria sin login): puede alternar entre vistas.
  Widget _pastillaDesplegable(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<Rol>(
      color: AppColors.darkCard,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.darkCardBorder),
      ),
      onSelected: (r) => ref.read(rolProvider.notifier).cambiar(r),
      itemBuilder: (context) => [
        const PopupMenuItem<Rol>(
          enabled: false,
          height: 32,
          child: Text(
            'PERFIL DE TRABAJO',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.darkTextMuted, letterSpacing: 0.5),
          ),
        ),
        for (final r in Rol.values)
          PopupMenuItem<Rol>(
            value: r,
            child: Row(
              children: [
                Icon(_icono(r), size: 18, color: r == rol ? AppColors.tealAccent : AppColors.darkTextSecondary),
                const SizedBox(width: 10),
                Text(_etiqueta(r),
                    style: TextStyle(
                      color: r == rol ? AppColors.tealAccent : AppColors.darkTextPrimary,
                      fontWeight: r == rol ? FontWeight.bold : FontWeight.normal,
                    )),
                if (r == rol) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 16, color: AppColors.tealAccent),
                ],
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.tealPrimary.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.tealPrimary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icono(rol), size: 16, color: AppColors.tealAccent),
            const SizedBox(width: 8),
            Text(_etiqueta(rol),
                style: const TextStyle(color: AppColors.tealAccent, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 16, color: AppColors.tealAccent),
          ],
        ),
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.rol, required this.enTransito});

  final Rol rol;
  final int enTransito;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Órdenes activas',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.darkTextPrimary),
            ),
            SizedBox(height: 2),
            Text(
              'Producción, bodega y despachos en un solo tablero',
              style: TextStyle(fontSize: 13, color: AppColors.darkTextSecondary),
            ),
          ],
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (rol == Rol.produccion)
              _BotonAccion(
                icono: Icons.history,
                texto: 'Entregar lote y ver historial',
                onPressed: () => showEntregaProduccionDialog(context),
              )
            else ...[
              _BotonAccion(
                icono: Icons.move_to_inbox_outlined,
                texto: 'Recibir lote ($enTransito)',
                onPressed: () => showRecepcionDialog(context),
              ),
              _BotonAccion(
                icono: Icons.local_shipping_outlined,
                texto: 'Despacho por orden',
                onPressed: () => showDespachoDialog(context),
              ),
              _BotonAccion(
                icono: Icons.domain_outlined,
                texto: 'Estantes y tickets',
                onPressed: () => showUbicacionesDialog(context),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _BotonAccion extends StatelessWidget {
  const _BotonAccion({required this.icono, required this.texto, required this.onPressed});

  final IconData icono;
  final String texto;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icono, size: 16),
      label: Text(texto),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.tealAccent,
        side: const BorderSide(color: AppColors.tealPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
ORBILOQ_EOF

echo ""
echo "Listo. Esta es la parte final. Siguiente paso:"
echo "  flutter analyze"
echo "  flutter test"
