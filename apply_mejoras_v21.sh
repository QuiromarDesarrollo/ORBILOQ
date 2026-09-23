#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Tarjetas al tope + entrega manual + login rediseñado (v21)
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_mejoras_v21.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi

echo "Aplicando mejoras..."

echo "  - pubspec.yaml"
mkdir -p "$(dirname 'pubspec.yaml')"
cat > 'pubspec.yaml' << 'ORBILOQ_EOF'
name: orbiloq_wms
description: ORBILOQ WMS - Kardex maestro y control de bodega.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.6.0
  flutter: ">=3.27.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  intl: ^0.20.2
  supabase_flutter: ^2.8.0
  excel: ^4.0.6
  file_picker: ^8.1.6

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/images/logo_orbiloq.png
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
/// conteo, sin perderse entre sí.
class _TarjetaEntrega {
  _TarjetaEntrega({required this.itemId}) : cantidadCtrl = TextEditingController(text: '1');

  final String itemId;
  final TextEditingController cantidadCtrl;
  int conteo = 1;
  bool enviando = false;
  bool enviada = false;
  String? remisionId;
  FeedbackMessage? mensaje;

  void dispose() => cantidadCtrl.dispose();
}

/// Ejecuta el despacho de una tarjeta contra el repositorio y actualiza su
/// estado. Compartido entre la pestaña de escaneo y la de entrega manual.
Future<void> _despacharTarjeta({
  required WidgetRef ref,
  required _TarjetaEntrega t,
  required String operario,
  required void Function(void Function()) setStateFn,
  required bool Function() estaMontado,
}) async {
  final kardex = ref.read(wmsSnapshotProvider).value?.kardexPorId(t.itemId);
  if (kardex == null) return;
  final cantidad = int.tryParse(t.cantidadCtrl.text.trim()) ?? 0;

  if (cantidad <= 0) {
    setStateFn(() => t.mensaje = const FeedbackMessage.error('Ingresa una cantidad mayor a 0.'));
    return;
  }
  if (cantidad > kardex.pendienteProduccion) {
    setStateFn(() => t.mensaje = FeedbackMessage.error(
          'LÍMITE EXCEDIDO: solo faltan ${kardex.pendienteProduccion} Uds por producir.',
        ));
    return;
  }

  setStateFn(() => t.enviando = true);
  final res = await ref.read(wmsRepositoryProvider).entregarLote(
        itemId: t.itemId,
        cantidad: cantidad,
        operario: operario,
      );
  if (!estaMontado()) return;
  setStateFn(() {
    t.enviando = false;
    switch (res) {
      case Ok(:final value):
        t.enviada = true;
        t.remisionId = value.id;
        t.mensaje = FeedbackMessage.ok('Remisión ${value.id} de ${value.cantidadEnviada} Uds despachada a bodega.');
      case Err(:final message):
        t.mensaje = FeedbackMessage.error(message);
    }
  });
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
          existente.mensaje = FeedbackMessage.error(
            'LÍMITE ALCANZADO: esta OP ya cumplió la cantidad pedida (${kardex.pendienteProduccion} Uds por entregar).',
          );
        } else {
          existente.conteo++;
          existente.cantidadCtrl.text = '${existente.conteo}';
          existente.mensaje = null;
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
      t.mensaje = null;
    });
    _qrFocus.requestFocus();
  }

  void _quitarTarjeta(_TarjetaEntrega t) {
    setState(() {
      t.dispose();
      _tarjetas.remove(t);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final snapshot = ref.watch(wmsSnapshotProvider).value;

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
                  'abiertas a la vez — cada una lleva su propio conteo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            for (final t in _tarjetas) ...[
              _TarjetaWidget(
                tarjeta: t,
                kardex: snapshot?.kardexPorId(t.itemId),
                onRecontear: () => _reiniciarConteo(t),
                onQuitar: () => _quitarTarjeta(t),
                onDespachar: () => _despacharTarjeta(
                  ref: ref,
                  t: t,
                  operario: _operario,
                  setStateFn: setState,
                  estaMontado: () => mounted,
                ),
              ),
              const SizedBox(height: 10),
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
        if (_tarjetaActivaPara(id) != null) continue; // ya está agregada y activa
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
      t.mensaje = null;
    });
  }

  void _quitarTarjeta(_TarjetaEntrega t) {
    setState(() {
      t.dispose();
      _tarjetas.remove(t);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final snapshot = ref.watch(wmsSnapshotProvider).value;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          else
            for (final t in _tarjetas) ...[
              _TarjetaWidget(
                tarjeta: t,
                kardex: snapshot?.kardexPorId(t.itemId),
                onRecontear: () => _reiniciarConteo(t),
                onQuitar: () => _quitarTarjeta(t),
                onDespachar: () => _despacharTarjeta(
                  ref: ref,
                  t: t,
                  operario: _operario,
                  setStateFn: setState,
                  estaMontado: () => mounted,
                ),
              ),
              const SizedBox(height: 10),
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
    required this.onDespachar,
  });

  final _TarjetaEntrega tarjeta;
  final ItemKardex? kardex;
  final VoidCallback onRecontear;
  final VoidCallback onQuitar;
  final VoidCallback onDespachar;

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
                            StatusChip(label: 'ENVIADA · ${tarjeta.remisionId}', color: AppColors.actionGreen),
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
                    onPressed: onRecontear,
                  ),
                  IconButton(
                    tooltip: 'Quitar esta tarjeta',
                    icon: const Icon(Icons.close, color: AppColors.alertRed),
                    onPressed: onQuitar,
                  ),
                ],
              ],
            ),
            const Divider(),
            if (tarjeta.mensaje != null) ...[
              FeedbackBanner(message: tarjeta.mensaje!),
              const SizedBox(height: 10),
            ],
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
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: tarjeta.cantidadCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: wmsInput('Cantidad a enviar (máx ${k.pendienteProduccion} Uds)'),
                      onSubmitted: (_) => onDespachar(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ActionButton(
                    icon: Icons.local_shipping,
                    label: 'DESPACHAR A BODEGA',
                    color: AppColors.actionGreen,
                    busy: tarjeta.enviando,
                    onPressed: onDespachar,
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

class _HistorialTab extends ConsumerWidget {
  const _HistorialTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remisiones = ref.watch(wmsSnapshotProvider).value?.remisiones ?? const [];
    if (remisiones.isEmpty) {
      return const Center(child: Text('Aún no hay remisiones.', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      itemCount: remisiones.length,
      itemBuilder: (_, i) {
        final r = remisiones[i];
        return Card(
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryNavy,
              child: Text('#${remisiones.length - i}', style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
            title: Text(
              '${r.id} — OP: ${r.item.op} | ${r.item.codigo} (${r.item.talla})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Enviadas: ${r.cantidadEnviada} Uds | Fecha: ${formatFechaHora(r.fechaEnvio)}'
                    '${r.cantidadRecibida != null ? ' | Recibidas: ${r.cantidadRecibida}' : ''}'),
                if (r.novedad.isNotEmpty)
                  Text('Novedad: ${r.novedad}', style: const TextStyle(color: AppColors.alertRed, fontWeight: FontWeight.bold)),
              ],
            ),
            trailing: StatusChip(label: r.estado.etiqueta, color: colorDeEstadoRemision(r.estado)),
          ),
        );
      },
    );
  }
}
ORBILOQ_EOF

echo "  - lib/features/auth/presentation/login_page.dart"
mkdir -p "$(dirname 'lib/features/auth/presentation/login_page.dart')"
cat > 'lib/features/auth/presentation/login_page.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/auth_providers.dart';
import '../../../core/result.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.errorInicial});

  final String? errorInicial;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _usuarioCtrl = TextEditingController();
  final _contrasenaCtrl = TextEditingController();
  bool _cargando = false;
  bool _verContrasena = false;
  String? _error;

  // Paleta propia de esta pantalla (coherente con el resto de la app, pero
  // con más matices de los que trae AppColors para lograr el degradado).
  static const _navyDeep = Color(0xFF0B1220);
  static const _navyMid = Color(0xFF13203A);
  static const _tealBright = Color(0xFF34D399);
  static const _tealPrimary = Color(0xFF0F766E);
  static const _slate900 = Color(0xFF0F172A);
  static const _slate500 = Color(0xFF64748B);
  static const _slate200 = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _error = widget.errorInicial;
  }

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _contrasenaCtrl.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    final repo = ref.read(authRepositoryProvider);
    if (repo == null) {
      setState(() => _error = 'No hay conexión a la base de datos configurada.');
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    final res = await repo.iniciarSesion(_usuarioCtrl.text, _contrasenaCtrl.text);

    if (!mounted) return;
    setState(() {
      _cargando = false;
      if (res is Err<void>) _error = res.message;
      // Si fue Ok, el cambio de sesión lo detecta authStateProvider solo y
      // la app pasa a la pantalla principal automáticamente.
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final ancho = constraints.maxWidth >= 900;
          final panelMarca = _PanelMarca(navyDeep: _navyDeep, navyMid: _navyMid, tealBright: _tealBright);
          final panelForm = _PanelFormulario(
            tealPrimary: _tealPrimary,
            slate900: _slate900,
            slate500: _slate500,
            slate200: _slate200,
            usuarioCtrl: _usuarioCtrl,
            contrasenaCtrl: _contrasenaCtrl,
            cargando: _cargando,
            verContrasena: _verContrasena,
            error: _error,
            onVerContrasena: () => setState(() => _verContrasena = !_verContrasena),
            onIngresar: _ingresar,
          );

          if (ancho) {
            return Row(
              children: [
                Expanded(flex: 5, child: panelMarca),
                Expanded(flex: 6, child: Center(child: panelForm)),
              ],
            );
          }
          // Pantallas angostas: la franja de marca queda arriba, compacta.
          return SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 260, child: panelMarca),
                Padding(padding: const EdgeInsets.all(24), child: panelForm),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Panel oscuro con el logo y el mensaje de marca.
class _PanelMarca extends StatelessWidget {
  const _PanelMarca({required this.navyDeep, required this.navyMid, required this.tealBright});

  final Color navyDeep;
  final Color navyMid;
  final Color tealBright;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navyDeep, navyMid],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
                ),
                child: Center(
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo_orbiloq.png',
                      width: 190,
                      height: 190,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Icon(
                        Icons.inventory_2_outlined,
                        size: 90,
                        color: tealBright,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.2),
                  children: [
                    const TextSpan(text: 'Eficiencia en\n', style: TextStyle(color: Colors.white)),
                    TextSpan(text: 'movimiento', style: TextStyle(color: tealBright)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Sistema de gestión de almacenes para una operación\nlogística precisa.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Panel claro con el formulario de acceso.
class _PanelFormulario extends StatelessWidget {
  const _PanelFormulario({
    required this.tealPrimary,
    required this.slate900,
    required this.slate500,
    required this.slate200,
    required this.usuarioCtrl,
    required this.contrasenaCtrl,
    required this.cargando,
    required this.verContrasena,
    required this.error,
    required this.onVerContrasena,
    required this.onIngresar,
  });

  final Color tealPrimary;
  final Color slate900;
  final Color slate500;
  final Color slate200;
  final TextEditingController usuarioCtrl;
  final TextEditingController contrasenaCtrl;
  final bool cargando;
  final bool verContrasena;
  final String? error;
  final VoidCallback onVerContrasena;
  final VoidCallback onIngresar;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ACCESO SEGURO',
              style: TextStyle(color: tealPrimary, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            Text(
              'Bienvenido de nuevo',
              style: TextStyle(color: slate900, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Ingresa tus credenciales para gestionar el inventario.',
              style: TextStyle(color: slate500, fontSize: 14),
            ),
            const SizedBox(height: 28),
            if (error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(error!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            _etiqueta('USUARIO', slate500),
            const SizedBox(height: 6),
            TextField(
              controller: usuarioCtrl,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.username],
              style: TextStyle(color: slate900),
              decoration: _decoracion('Ingresa tu usuario', Icons.person_outline, slate200, slate500),
              onSubmitted: (_) => onIngresar(),
            ),
            const SizedBox(height: 18),
            _etiqueta('CONTRASEÑA', slate500),
            const SizedBox(height: 6),
            TextField(
              controller: contrasenaCtrl,
              obscureText: !verContrasena,
              autofillHints: const [AutofillHints.password],
              style: TextStyle(color: slate900),
              decoration: _decoracion('Ingresa tu contraseña', Icons.lock_outline, slate200, slate500).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(verContrasena ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20, color: slate500),
                  onPressed: onVerContrasena,
                ),
              ),
              onSubmitted: (_) => onIngresar(),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: cargando ? null : onIngresar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: slate900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: cargando
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Iniciar sesión', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Divider(color: slate200),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text('ORBILOQ WMS', style: TextStyle(color: slate500, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                Text('¿Olvidaste tu clave?', style: TextStyle(color: tealPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _etiqueta(String texto, Color color) =>
      Text(texto, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6));

  InputDecoration _decoracion(String hint, IconData icono, Color borde, Color iconColor) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: iconColor.withValues(alpha: 0.7), fontSize: 14),
        prefixIcon: Icon(icono, color: iconColor, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borde)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borde)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
        ),
      );
}
ORBILOQ_EOF

echo "  - assets/images/logo_orbiloq.png (logo, via base64)"
mkdir -p assets/images
if command -v base64 >/dev/null 2>&1; then
  echo '/9j/4AAQSkZJRgABAQAAAQABAAD/4gHYSUNDX1BST0ZJTEUAAQEAAAHIAAAAAAQwAABtbnRyUkdCIFhZWiAH4AABAAEAAAAAAABhY3NwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAA9tYAAQAAAADTLQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAlkZXNjAAAA8AAAACRyWFlaAAABFAAAABRnWFlaAAABKAAAABRiWFlaAAABPAAAABR3dHB0AAABUAAAABRyVFJDAAABZAAAAChnVFJDAAABZAAAAChiVFJDAAABZAAAAChjcHJ0AAABjAAAADxtbHVjAAAAAAAAAAEAAAAMZW5VUwAAAAgAAAAcAHMAUgBHAEJYWVogAAAAAAAAb6IAADj1AAADkFhZWiAAAAAAAABimQAAt4UAABjaWFlaIAAAAAAAACSgAAAPhAAAts9YWVogAAAAAAAA9tYAAQAAAADTLXBhcmEAAAAAAAQAAAACZmYAAPKnAAANWQAAE9AAAApbAAAAAAAAAABtbHVjAAAAAAAAAAEAAAAMZW5VUwAAACAAAAAcAEcAbwBvAGcAbABlACAASQBuAGMALgAgADIAMAAxADb/2wBDAAMCAgICAgMCAgIDAwMDBAYEBAQEBAgGBgUGCQgKCgkICQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/2wBDAQMDAwQDBAgEBAgQCwkLEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBD/wAARCAHgAlgDASIAAhEBAxEB/8QAHQABAAEEAwEAAAAAAAAAAAAAAAgBAgYHAwUJBP/EAE0QAAEDAwIDBQUECAQEAwYHAAEAAgMEBQYHERIhMQgTQVFhCRQicYEyQpGhFSNSYnKSscFDgqLRFiRTsjNjwhc3c3Wz4SU0NTh0k5T/xAAcAQEAAgMBAQEAAAAAAAAAAAAABQYBAwQHAgj/xABAEQACAQMBBAcHAwMEAAUFAAAAAQIDBBEFBhIhMUFRYXGRodETIjKBscHwFDPhFSNSB0Ji8RYkU4LCJTSistL/2gAMAwEAAhEDEQA/APUtERbTUEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBERAEREAREQBEXwXa+2axQGovFyp6Rg/6jwCfkOpXzOpClHem8LtPmUlBb0nhH3p16LVV+1+sVJxQ2C3T1zxyEkn6uP5jxP4Ba/vWsuc3fiZHXx0ER+7TM4T/Mdyq1ebXaba+7GTm/8Aj68iJuNcs6HBPefZ68iSFTV0tHGZauqigYOrpHhoH4rHbhqZgts394yOleR4Qky/9u6jBXXSvrnGouVxnnIBJfNKXbD5lYFdtZtMbI98dZllI57CQWwB0x38vgBUPDazUNQk4abauT7nJ+EURFXaWo/2oJd7z6EvKvXjCafcQR19T6xwgD/UQurn7Q1ob/8Alseq3/xyNb/TdRXxfWTT3L7i202e+D3x/wD4cU0TozJ/CSNifTqs1UVqG0evWVT2VzH2UueHDDx8zilr97Lk0vl6m6Hdopo+xihPzq9v/SjO0Uw/bxQj5Ve//pWl1qPUvXh2DZbFidBYm1ku0Znlkm4A0v6AAA78uaaVqm0WtXH6aynvSw3jEFwXN5aRr/rl9/n5L0Jn0/aGtDj/AM1j1Wz+CRrv67LtKPXjCaggTx3Cl9ZIQR/pJUeGndod5gFFyU9sdUhzkn3pfbBshr97Hm0/l6EprfqbglzO1PkdMwnwm3i/7gFkVNWUlYwS0dXDOw9HRvDgfwUDMy1QwvBKqnoskuZhnqW8bI2ROkIbvtxHYchusttF6qGwwXOz3CohbMxskckb3MJaRuD5hT0Nrr+3pQr3lt7k+UllJ454zlPxO2ltLUX7sE+549SZnTqijRZtYs5tBa2S4troh9ypZxf6hz/NbBsGv1kqy2HILbNQuPIyxHvI/mR1H4FTVntdpt1iM5OD/wCXLxWV4ktb67Z1+Enuvt9eRtZF19ov9lv8PvFnucFUzx7t44h8x1C7BWSnUhVi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' | base64 -d > assets/images/logo_orbiloq.png
  echo '    logo guardado correctamente'
else
  echo '    AVISO: no se encontro el comando base64.'
  echo '    Copia manualmente el archivo Logo-quiromar.png a: assets/images/logo_orbiloq.png'
fi

echo ""
echo "Listo. Siguiente paso:"
echo "  flutter pub get   (para registrar el nuevo asset)"
echo "  flutter analyze"
echo "  flutter test"
