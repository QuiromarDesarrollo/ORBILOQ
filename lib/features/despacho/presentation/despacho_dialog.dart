import 'package:flutter/foundation.dart';
import '../../conductor/borrador_local.dart';
import '../../../shared/borrador_texto_native.dart'
    if (dart.library.js_interop) '../../../shared/borrador_texto_web.dart';
import '../../../data/inventario_repository.dart';
import '../../../shared/widgets/wms_expandable_alert_dialog.dart';
import 'historial_despachos_vista.dart';
import '../../../data/seguimiento_entregas.dart';
import 'seguimiento_entregas_tabla.dart';
import 'facturacion_panel.dart';
import 'dart:convert';
import 'dart:math' show max, min;
import '../../../data/destinatarios_empaque.dart';
import '../../../data/rotulo_empaque_pdf.dart';
import '../../../domain/rotulo_empaque.dart';
import '../../../shared/descargar_pdf.dart';
import 'package:orbiloq_wms/shared/widgets/wms_alert.dart';
import 'lista_empaque_dialog.dart';
import '../../../application/auth_providers.dart';
import '../../../shared/widgets/wms_scan_field.dart';
import '../../../shared/widgets/feedback_banner.dart';
import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../application/providers.dart';
import '../../../data/despachos_oc_repository.dart';
import '../../../data/despacho_borrador_repository.dart';
import '../../../data/empaques_repository.dart';
import '../../../domain/models.dart';
import '../../../domain/sesion.dart';
import '../../../domain/qr_prenda.dart';
import '../../../shared/widgets/wms_camera_scanner.dart';
import '../../../shared/widgets/wms_dialog.dart';
import '../../../core/theme/app_theme.dart';
import 'widgets/despacho_destino_selector.dart';

Future<void> showDespachoDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const DespachoDialog());

class DespachoDialog extends ConsumerStatefulWidget {
  const DespachoDialog({super.key, this.correccion, this.inventario})
    : assert(correccion == null || inventario == null);
  final InventarioFila? inventario;
  final Map<String, dynamic>? correccion;
  @override
  ConsumerState<DespachoDialog> createState() => _DespachoState();
}

class _EmpaqueAsignado {
  _EmpaqueAsignado(this.empaqueId);
  String empaqueId;
  String prendas = '0';
}

class _DespachoState extends ConsumerState<DespachoDialog> {
  InventarioFila? _inventarioRecuperado;
  InventarioFila? get _inventario => _inventarioRecuperado ?? widget.inventario;
  bool get _puedeSeguimiento =>
      !ref.read(usarSupabaseProvider) ||
      (ref.read(usuarioSesionProvider).valueOrNull?.puedeSeguimiento ?? false);
  bool get _admin =>
      ref.read(usuarioSesionProvider).valueOrNull?.tieneRol(RolCuenta.admin) ==
      true;
  bool _empaqueMasivo = false;
  int _paso = 0;
  bool _exito = false;
  bool _pantallaCompleta = false;
  String? _opEmpaque;
  String? _tallaEmpaque;
  final _gruposOpAbiertos = <String, bool>{};
  bool _coincideOp(ItemKardex i) =>
      _opEmpaque == null || i.item.op == _opEmpaque;
  int _confirmadas = 0, _bultosConfirmados = 0;
  List<Map<String, dynamic>>? _planRevisado;
  String? _cliente, _oc, _destinatarioId;
  final _ocDocumento = TextEditingController();
  String get _ocVisible =>
      _ocDocumento.text.trim().isEmpty ? (_oc ?? '') : _ocDocumento.text.trim();
  final _pesosBrutos = <String, String>{};
  final _rotulosGenerados = <String, String>{};
  bool _generandoRotulo = false;
  bool _sincronizandoDatos = false;
  String? _resultadoSincronizacion;
  bool _errorSincronizacion = false;
  Map<String, dynamic>? get _destino =>
      ref
          .read(destinatariosEmpaqueProvider)
          .valueOrNull
          ?.where((d) => d['id'] == _destinatarioId)
          .firstOrNull;
  bool get _faltaDestino => ref.read(usarSupabaseProvider) && _destino == null;

  RotuloEmpaque _rotulo(String pieza) {
    if (_destino == null) {
      throw const FormatException(
        'Selecciona el destinatario antes de empacar.',
      );
    }
    final productos = <String, ProductoRotulo>{};
    for (final i in _lineas.where((i) => _ops.contains(i.item.op))) {
      final a = _asignaciones[i.id]?[pieza];
      if (a == null) continue;
      final n = int.tryParse(a.prendas);
      if (n == null || n < 1 || n > 999999) {
        throw const FormatException(
          'Completa las cantidades de esta pieza antes de generar su rótulo.',
        );
      }
      final key = jsonEncode([i.item.op, i.item.descripcion, i.item.talla]);
      productos[key] = ProductoRotulo(
        i.item.descripcion,
        i.item.talla,
        (productos[key]?.cantidad ?? 0) + n,
        op: i.item.op,
      );
    }
    // También cuenta las prendas ya distribuidas en las otras piezas.
    final totales = <String, int>{};
    for (final i in _lineas.where((i) => _ops.contains(i.item.op))) {
      for (final a in (_asignaciones[i.id] ?? {}).values) {
        final n = int.tryParse(a.prendas) ?? 0;
        if (n > 0) totales[i.id] = (totales[i.id] ?? 0) + n;
      }
    }
    planificarDespacho(_lineas, totales);
    final empaque =
        (ref.read(empaquesProvider).value ?? [])
            .where((e) => e['id'] == _bultos[pieza])
            .firstOrNull;
    if (empaque == null) {
      throw const FormatException('Actualiza el catálogo de empaques.');
    }
    return RotuloEmpaque(
      tipoEmpaque: empaque['categoria'] == 'CAJA' ? 'Caja' : 'Paquete',
      pesoBrutoKg: _pesoBruto(pieza, empaque),
      numero: _numeros[pieza]!,
      destinatario: Map<String, dynamic>.from(_destino!['datos'] as Map),
      oc: _ocVisible,
      empacadoPor:
          ref.read(usarSupabaseProvider)
              ? (ref.read(usuarioSesionProvider).valueOrNull?.nombre ?? '')
              : 'Operario de prueba',
      productos: productos.values.toList(),
    );
  }

  bool _rotuloPendiente(String pieza) {
    if (!_rotulosGenerados.containsKey(pieza)) return false;
    try {
      return _rotulosGenerados[pieza] !=
          '${_bultos[pieza]}:${_rotulo(pieza).firma}';
    } catch (_) {
      return true;
    }
  }

  Future<void> _generarRotulo(String pieza) async {
    if (_generandoRotulo) return;
    setState(() => _generandoRotulo = true);
    try {
      final rotulo = _rotulo(pieza);
      final bytes = await crearRotuloEmpaquePdf(
        rotulo,
        logo:
            (await rootBundle.load(
              'assets/images/logo_quiromar_vector_bn.svg',
            )).buffer.asUint8List(),
        fuenteRegular: await rootBundle.load(
          'assets/fonts/LiberationSans-Regular.ttf',
        ),
        fuenteNegrita: await rootBundle.load(
          'assets/fonts/LiberationSans-Bold.ttf',
        ),
      );
      await descargarPdf(bytes, 'Rotulo_pieza_${rotulo.numero}.pdf');
      if (mounted) {
        setState(
          () => _rotulosGenerados[pieza] = '${_bultos[pieza]}:${rotulo.firma}',
        );
      }
    } catch (e) {
      if (mounted) {
        await mostrarAviso(
          context,
          e is FormatException
              ? e.message.toString()
              : 'No se pudo generar el rótulo: $e',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _generandoRotulo = false);
    }
  }

  Future<void> _generarTodosLosRotulos() async {
    if (_generandoRotulo) return;
    setState(() => _generandoRotulo = true);
    try {
      // Capturar y validar todos los empaques antes de iniciar la descarga.
      final piezas =
          _bultos.keys.toList()
            ..sort((a, b) => _numeros[a]!.compareTo(_numeros[b]!));
      final rotulos = [for (final pieza in piezas) _rotulo(pieza)];
      final firmas = {
        for (var i = 0; i < piezas.length; i++)
          piezas[i]: '${_bultos[piezas[i]]}:${rotulos[i].firma}',
      };
      final bytes = await crearRotulosEmpaquePdf(
        rotulos,
        logo:
            (await rootBundle.load(
              'assets/images/logo_quiromar_vector_bn.svg',
            )).buffer.asUint8List(),
        fuenteRegular: await rootBundle.load(
          'assets/fonts/LiberationSans-Regular.ttf',
        ),
        fuenteNegrita: await rootBundle.load(
          'assets/fonts/LiberationSans-Bold.ttf',
        ),
      );
      await descargarPdf(bytes, 'Rotulos_despacho.pdf');
      if (mounted) setState(() => _rotulosGenerados.addAll(firmas));
    } catch (e) {
      if (mounted) {
        await mostrarAviso(
          context,
          e is FormatException
              ? e.message.toString()
              : 'No se pudieron generar los rótulos: $e',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _generandoRotulo = false);
    }
  }

  Future<void> _sincronizarDatos() async {
    if (_sincronizandoDatos ||
        _ocupado ||
        _preparando ||
        _generandoRotulo ||
        _pendiente != null) {
      return;
    }
    setState(() {
      _sincronizandoDatos = true;
      _resultadoSincronizacion = null;
      _errorSincronizacion = false;
    });
    try {
      await ref.read(wmsRepositoryProvider).refrescar();
      ref.invalidate(destinatariosEmpaqueProvider);
      ref.invalidate(empaquesProvider);
      await Future.wait([
        ref.read(destinatariosEmpaqueProvider.future),
        ref.read(empaquesProvider.future),
      ]);
      if (mounted) {
        setState(() {
          _resultadoSincronizacion = 'Datos actualizados';
          _errorSincronizacion = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _resultadoSincronizacion =
              'La sincronización no se completó. Intenta de nuevo.';
          _errorSincronizacion = true;
        });
      }
    } finally {
      if (mounted) setState(() => _sincronizandoDatos = false);
    }
  }

  Widget _sincronizarEnDialogo() => Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color:
          _avisoBorrador == null
              ? null
              : _errorBorrador
              ? AppColors.redChipBg
              : AppColors.amberChipBg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final mensajes = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_avisoBorrador != null)
              Text(
                _avisoBorrador!,
                style: TextStyle(
                  fontSize: 12,
                  color:
                      _errorBorrador ? AppColors.alertRed : AppColors.amberChip,
                ),
              ),
            if (_errorBorrador)
              TextButton(
                onPressed: _cargarBorrador,
                child: const Text('Reintentar borrador'),
              ),
            if (_resultadoSincronizacion != null)
              Text(
                _resultadoSincronizacion!,
                style: TextStyle(
                  fontSize: 12,
                  color:
                      _errorSincronizacion
                          ? AppColors.alertRed
                          : AppColors.slate600,
                ),
              ),
          ],
        );
        final boton = FilledButton.icon(
          key: const ValueKey('despacho-sincronizar-datos'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.lima,
            foregroundColor: AppColors.petroleo,
            minimumSize: const Size(0, 44),
          ),
          onPressed:
              _sincronizandoDatos ||
                      _ocupado ||
                      _preparando ||
                      _generandoRotulo ||
                      _pendiente != null
                  ? null
                  : _sincronizarDatos,
          icon:
              _sincronizandoDatos
                  ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.sync, size: 18),
          label: Text(
            _sincronizandoDatos ? 'Sincronizando…' : 'Sincronizar datos',
          ),
        );
        final hayMensaje =
            _avisoBorrador != null || _resultadoSincronizacion != null;
        return constraints.maxWidth < 600 && hayMensaje
            ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                mensajes,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: boton),
              ],
            )
            : Row(
              children: [
                Expanded(child: mensajes),
                const SizedBox(width: 12),
                boton,
              ],
            );
      },
    ),
  );

  Widget _selectorDestinoBuscable(
    List<Map<String, dynamic>> datos,
    bool congelado,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Destinatario o sede *',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 6),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DespachoDestinoSelector(
              key: const ValueKey('despacho-destino-selector'),
              datos: datos,
              selectedId: _destinatarioId,
              enabled: !congelado,
              onSelected: (id) => setState(() => _destinatarioId = id),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            key: const ValueKey('despacho-destino-recargar'),
            tooltip: 'Actualizar destinatarios',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed:
                congelado
                    ? null
                    : () => ref.invalidate(destinatariosEmpaqueProvider),
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ],
      ),
      const SizedBox(height: 7),
      Text(
        _destino == null
            ? '¿No aparece? Actualiza para recargar la lista.'
            : '${_destino!['datos']['direccion'] ?? ''}',
        style: const TextStyle(fontSize: 12, color: AppColors.slate600),
      ),
      if (datos.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'Administración debe registrar un destinatario antes de empacar.',
          ),
        ),
    ],
  );

  Widget _selectorDestino(bool congelado) => ref
      .watch(destinatariosEmpaqueProvider)
      .when(
        loading: () => const WmsLoadingStrip(),
        error:
            (_, __) => TextButton(
              onPressed: () => ref.invalidate(destinatariosEmpaqueProvider),
              child: const Text(
                'No se pudieron cargar los destinatarios. Reintentar',
              ),
            ),
        data: (datos) => _selectorDestinoBuscable(datos, congelado),
      );
  final _ops = <String>{};
  final _asignaciones = <String, Map<String, _EmpaqueAsignado>>{};
  int _siguienteEmpaque = 0;
  final _qr = TextEditingController();
  bool _ocupado = false;
  bool _preparando = false;
  String? _solicitud;
  set _mensaje(String? texto) {
    if (texto == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) mostrarAviso(context, texto, error: true);
    });
  }

  List<Map<String, dynamic>>? _pendiente;
  List<Map<String, dynamic>> _empaquesPendientes = [];

  int _revisionEmpaques = 0;
  final _motivoCorreccion = TextEditingController();
  bool _correccionGuardada = false;
  bool _cargandoBorrador = false, _guardandoBorrador = false;
  bool _errorBorrador = false, _cerrando = false, _permitirSalida = false;
  int _versionBorrador = 0;
  String _estadoGuardado = '';
  String? _avisoBorrador;
  String get _claveBorrador =>
      widget.correccion != null
          ? 'correccion:${widget.correccion!['id']}'
          : _inventario != null
          ? 'inventario'
          : 'nuevo';

  Map<String, dynamic> _datosBorrador() => {
    'formato': 1,
    'inventario': _inventario,
    'paso': _paso,
    'cliente': _cliente,
    'oc': _oc,
    'destinatario': _destinatarioId,
    'oc_documento': _ocDocumento.text,
    'ops': _ops.toList(),
    'pesos': Map.of(_pesosBrutos),
    'asignaciones': {
      for (final i in _asignaciones.entries)
        i.key: {
          for (final e in i.value.entries)
            e.key: {'empaque': e.value.empaqueId, 'prendas': e.value.prendas},
        },
    },
    'siguiente_empaque': _siguienteEmpaque,
    'masivo': _empaqueMasivo,
    'motivo': _motivoCorreccion.text,
    'filtro_op': _opEmpaque,
    'filtro_talla': _tallaEmpaque,
    'grupos': Map.of(_gruposOpAbiertos),
    'tarjetas': Map.of(_opAbierta),
    'rotulos': Map.of(_rotulosGenerados),
    'solicitud': _solicitud,
    'pendiente': _pendiente,
    'empaques_pendientes': _empaquesPendientes,
  };

  bool _localPreparado = false;
  String? get _claveLocal {
    final user = ref.read(transporteBorradorUsuarioProvider);
    return user == null
        ? null
        : jsonEncode([user, 'despacho-refresh', _claveBorrador]);
  }

  void _aplicarBorrador(Map<String, dynamic> d) {
    if (widget.inventario != null && d['inventario'] is Map) {
      _inventarioRecuperado = Map<String, dynamic>.from(d['inventario'] as Map);
    }
    _cliente = d['cliente'] as String?;
    _oc = d['oc'] as String?;
    _destinatarioId = d['destinatario'] as String?;
    _ocDocumento.text = d['oc_documento'] as String? ?? '';
    _ops
      ..clear()
      ..addAll((d['ops'] as List).cast<String>());
    _pesosBrutos
      ..clear()
      ..addAll(Map<String, String>.from(d['pesos'] as Map));
    _asignaciones.clear();
    for (final i in (d['asignaciones'] as Map).entries) {
      _asignaciones[i.key as String] = {
        for (final e in (i.value as Map).entries)
          e.key as String: _EmpaqueAsignado(e.value['empaque'] as String)
            ..prendas = e.value['prendas'] as String,
      };
    }
    _siguienteEmpaque = (d['siguiente_empaque'] as num).toInt();
    _empaqueMasivo = d['masivo'] == true;
    _motivoCorreccion.text = d['motivo'] as String? ?? '';
    _opEmpaque = d['filtro_op'] as String?;
    _tallaEmpaque = d['filtro_talla'] as String?;
    _gruposOpAbiertos
      ..clear()
      ..addAll(Map<String, bool>.from(d['grupos'] as Map? ?? {}));
    _opAbierta
      ..clear()
      ..addAll(Map<String, bool>.from(d['tarjetas'] as Map? ?? {}));
    _rotulosGenerados
      ..clear()
      ..addAll(Map<String, String>.from(d['rotulos'] as Map? ?? {}));
    _solicitud = d['solicitud'] as String?;
    _pendiente =
        (d['pendiente'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
    _empaquesPendientes =
        (d['empaques_pendientes'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
    _paso = (d['paso'] as int).clamp(0, 3);
    _planRevisado = null;
    _confirmadas =
        _pendiente?.fold<int>(
          0,
          (n, l) => n + (l['cantidad'] as num).toInt(),
        ) ??
        0;
    _bultosConfirmados = _bultos.length;
  }

  void _guardarLocal() {
    if (!kIsWeb ||
        !_localPreparado ||
        _cargandoBorrador ||
        _errorBorrador ||
        _permitirSalida) {
      return;
    }
    final key = _claveLocal;
    if (key == null) return;
    try {
      escribirTextoBorrador(
        key,
        jsonEncode(
          _exito
              ? {'completo': true}
              : {'version': _versionBorrador, 'datos': _datosBorrador()},
        ),
      );
    } catch (_) {
      _avisoBorrador =
          'No se pudo guardar el avance local. Usa Guardar antes de cerrar o actualizar.';
    }
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _guardarLocal();
  }

  Future<void> _cargarBorrador() async {
    final repo = ref.read(despachoBorradorRepositoryProvider);
    if (repo == null) return;
    setState(() {
      _cargandoBorrador = true;
      _errorBorrador = false;
      _avisoBorrador = null;
    });
    try {
      final registro = await repo.cargar(_claveBorrador);
      if (!mounted) return;
      if (registro != null) {
        final d = Map<String, dynamic>.from(registro['datos'] as Map);
        if (d['formato'] != 1) {
          throw const FormatException('Formato de borrador no compatible.');
        }
        _aplicarBorrador(d);
        _versionBorrador = (registro['version'] as num).toInt();
        _revisionEmpaques++;
        _avisoBorrador =
            'Borrador recuperado. Revisa la disponibilidad actual antes de confirmar.';
      }
      _estadoGuardado = jsonEncode(_datosBorrador());
      if (kIsWeb && _claveLocal != null) {
        final raw = leerTextoBorrador(_claveLocal!);
        if (raw != null) {
          final local = Map<String, dynamic>.from(jsonDecode(raw));
          if (local['completo'] != true &&
              local['version'] == _versionBorrador) {
            final datos = Map<String, dynamic>.from(local['datos']);
            if (datos['formato'] != 1) {
              throw const FormatException('Borrador local incompatible');
            }
            _aplicarBorrador(datos);
            _revisionEmpaques++;
            _avisoBorrador =
                'Avance recuperado de este dispositivo. Revisa antes de confirmar.';
          }
        }
      }
      _localPreparado = true;
    } catch (_) {
      if (mounted) {
        _errorBorrador = true;
        _avisoBorrador =
            'No se pudo recuperar el borrador. Reintenta para continuar sin sobrescribirlo.';
      }
    } finally {
      if (mounted) setState(() => _cargandoBorrador = false);
    }
  }

  Future<void> _persistirBorrador() async {
    final repo = ref.read(despachoBorradorRepositoryProvider);
    if (repo == null) {
      throw const FormatException(
        'No está disponible el guardado de borradores.',
      );
    }
    final r = await repo.guardar(
      _claveBorrador,
      _datosBorrador(),
      version: _versionBorrador,
    );
    _versionBorrador = (r['version'] as num).toInt();
    _estadoGuardado = jsonEncode(_datosBorrador());
    _guardarLocal();
  }

  Future<void> _cerrar() async {
    if (_permitirSalida ||
        _cerrando ||
        _cargandoBorrador ||
        _guardandoBorrador ||
        _ocupado ||
        _preparando ||
        _generandoRotulo ||
        _sincronizandoDatos ||
        _pendiente != null) {
      return;
    }
    _cerrando = true;
    try {
      if (!_exito &&
          !_errorBorrador &&
          jsonEncode(_datosBorrador()) != _estadoGuardado) {
        final accion = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder:
              (ctx) => AlertDialog(
                title: const Text('¿Deseas guardar los cambios?'),
                content: const Text(
                  'Guarda el borrador para continuar este despacho desde cualquier equipo con tu usuario.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, 'cancelar'),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, 'descartar'),
                    child: const Text('No guardar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, 'guardar'),
                    child: const Text('Guardar'),
                  ),
                ],
              ),
        );
        if (!mounted || accion == null || accion == 'cancelar') return;
        if (accion == 'guardar') {
          setState(() => _guardandoBorrador = true);
          try {
            await _persistirBorrador();
          } catch (e) {
            if (mounted) {
              _mensaje =
                  e is PostgrestException
                      ? e.message
                      : 'No se pudo guardar el borrador. Tus cambios siguen abiertos; inténtalo de nuevo.';
            }
            return;
          } finally {
            if (mounted) setState(() => _guardandoBorrador = false);
          }
        }
        if (accion == 'descartar' && kIsWeb && _claveLocal != null) {
          escribirTextoBorrador(_claveLocal!, jsonEncode({'completo': true}));
          _localPreparado = false;
        }
        // No guardar descarta solo la edición actual y conserva el último guardado.
      }
      _salir();
    } finally {
      _cerrando = false;
    }
  }

  void _salir() {
    if (!mounted || _permitirSalida) return;
    setState(() => _permitirSalida = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void initState() {
    super.initState();
    _ocDocumento.addListener(_guardarLocal);
    _motivoCorreccion.addListener(_guardarLocal);
    _cargandoBorrador = ref.read(despachoBorradorRepositoryProvider) != null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _estadoGuardado = jsonEncode(_datosBorrador());
      _cargarBorrador();
    });
    if (_inventario case final origen?) {
      _cliente = origen['cliente'] as String;
      for (final r in _origenesInventario) {
        _ops.add('${r['numero_op']}');
      }
    }
    final d = widget.correccion;
    if (d == null) return;
    _paso = 2;
    _destinatarioId = d['destinatario_id'] as String?;
    _cliente = d['cliente'] as String;
    _oc = d['oc'] as String;
    _ocDocumento.text = d['oc_documento'] as String? ?? '';
    for (final e in d['empaques'] as List) {
      final numero = (e['numero'] as num).toInt();
      if (e['peso_tara_kg'] != null && e['peso_bruto_kg'] != null) {
        _pesosBrutos['$numero'] = '${e['peso_bruto_kg']}';
      }
      if (numero > _siguienteEmpaque) _siguienteEmpaque = numero;
      _asignaciones.putIfAbsent('${e['item_id']}', () => {})['$numero'] =
          _EmpaqueAsignado('${e['id']}')..prendas = '${e['cantidad']}';
    }
    for (final i in d['detalle'] as List) {
      _ops.add('${i['op']}');
    }
  }

  @override
  void dispose() {
    _ocDocumento.dispose();
    _motivoCorreccion.dispose();
    _qr.dispose();
    super.dispose();
  }

  void _limpiar() {
    _empaqueMasivo = false;
    _pesosBrutos.clear();
    _opAbierta.clear();
    _gruposOpAbiertos.clear();
    _tallaEmpaque = null;
    _opEmpaque = null;
    _ocDocumento.clear();
    _rotulosGenerados.clear();
    _asignaciones.clear();
    _siguienteEmpaque = 0;
    _revisionEmpaques++;
    _ops.clear();
  }

  int _total(ItemKardex i) => (_asignaciones[i.id] ?? {}).values.fold(
    0,
    (n, v) => n + (int.tryParse(v.prendas) ?? 0),
  );

  Map<String, String> get _bultos => {
    for (final a in _asignaciones.values)
      for (final e in a.entries) e.key: e.value.empaqueId,
  };
  Map<String, int> get _numeros {
    final keys =
        _bultos.keys.toList()
          ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    return {for (var i = 0; i < keys.length; i++) keys[i]: i + 1};
  }

  final _opAbierta = <String, bool>{};
  bool _abierta(ItemKardex i) =>
      _opAbierta[i.id] ?? i.disponibleParaDespacho > 0;

  int _prendasBulto(String key) => _asignaciones.values.fold(
    0,
    (n, a) => n + (int.tryParse(a[key]?.prendas ?? '0') ?? 0),
  );

  String? get _pendienteEmpaque {
    if (_bultos.isEmpty) return 'Agrega al menos un empaque para continuar.';
    for (final i in _lineas.where((i) => _ops.contains(i.item.op))) {
      if (_total(i) >
          min(i.disponibleParaDespacho, i.pendienteDisponibleDespacho)) {
        return 'OP ${i.item.op}: revisa la cantidad disponible.';
      }
    }
    final catalogo = ref.read(empaquesProvider).value ?? [];
    for (final b in _bultos.entries) {
      if (_prendasBulto(b.key) <= 0) {
        return 'Agrega prendas al empaque ${_numeros[b.key]} o quítalo.';
      }
      final e = catalogo.where((e) => e['id'] == b.value).firstOrNull;
      if (e == null) return 'Actualiza el tipo del empaque ${_numeros[b.key]}.';
      try {
        _pesoBruto(b.key, e);
      } catch (_) {
        return 'Indica un peso bruto válido para el empaque ${_numeros[b.key]}.';
      }
    }
    return null;
  }

  void _agregarRapido(ItemKardex i, Map<String, dynamic> e) {
    setState(() {
      final key = '${_siguienteEmpaque++}';
      _asignaciones.putIfAbsent(i.id, () => {})[key] = _EmpaqueAsignado(
        '${e['id']}',
      );
      _revisionEmpaques++;
    });
  }

  Widget _indicadoresEmpaque(ItemKardex i) {
    final total = _total(i);
    final disponible = i.disponibleParaDespacho;
    final progreso =
        disponible <= 0 ? 0.0 : (total / disponible).clamp(0.0, 1.0);
    Widget dato(
      String titulo,
      String valor,
      Color fondo, {
      bool barra = false,
    }) => Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontSize: 10, color: Color(0xff648090)),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (barra) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: progreso,
              color: total > disponible ? Colors.red : _green,
              backgroundColor: const Color(0xffe3ecef),
            ),
          ],
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, c) {
        final ancho =
            c.maxWidth >= 600 ? (c.maxWidth - 24) / 4 : (c.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: ancho,
              child: dato(
                '$total de $disponible prendas en empaques',
                '${(progreso * 100).round()} %',
                _soft,
                barra: true,
              ),
            ),
            SizedBox(
              width: ancho,
              child: dato(
                'Disponibles',
                'Quedan ${disponible - total} en bodega',
                const Color(0xffe6f4ee),
              ),
            ),
            SizedBox(
              width: ancho,
              child: dato(
                'Pendientes de recibir en Bodega: ${max(0, i.producido - i.recibido)}',
                '${max(0, i.producido - i.recibido)}',
                _soft,
              ),
            ),
            SizedBox(
              width: ancho,
              child: dato(
                'Pendientes de Producción: ${i.pendienteProduccion}',
                '${i.pendienteProduccion}',
                const Color(0xfffff3db),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _detalleSeleccion(bool congelado) => ref
      .watch(empaquesProvider)
      .when(
        loading: () => const WmsLoadingStrip(),
        error:
            (_, __) => TextButton(
              onPressed: () => ref.invalidate(empaquesProvider),
              child: const Text('Reintentar catálogo de empaques'),
            ),
        data:
            (catalogo) => LayoutBuilder(
              builder: (context, constraints) {
                final grupos = <String, List<ItemKardex>>{};
                for (final i in _lineas.where(
                  (i) => _ops.contains(i.item.op),
                )) {
                  grupos.putIfAbsent(i.item.op, () => []).add(i);
                }
                final visibles = grupos.entries.where(
                  (g) => g.value.any(
                    (i) =>
                        _coincideOp(i) &&
                        (_tallaEmpaque == null ||
                            i.item.talla == _tallaEmpaque),
                  ),
                );
                final tarjetas = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (visibles.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No hay prendas que coincidan con los filtros.',
                        ),
                      ),
                    for (final grupo in visibles)
                      _panel(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              key: ValueKey('grupo-op-${grupo.key}'),
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'OP ${grupo.key}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${grupo.value.length} referencias · ${grupo.value.fold<int>(0, (n, i) => n + _total(i))} prendas en empaques',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: Icon(
                                (_gruposOpAbiertos[grupo.key] ?? true)
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                              onTap:
                                  () => setState(
                                    () =>
                                        _gruposOpAbiertos[grupo.key] =
                                            !(_gruposOpAbiertos[grupo.key] ??
                                                true),
                                  ),
                            ),
                            Visibility(
                              visible: _gruposOpAbiertos[grupo.key] ?? true,
                              maintainState: true,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final i in grupo.value.where(
                                    (i) =>
                                        _tallaEmpaque == null ||
                                        i.item.talla == _tallaEmpaque,
                                  ))
                                    _panel(
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            onTap:
                                                () => setState(
                                                  () =>
                                                      _opAbierta[i.id] =
                                                          !_abierta(i),
                                                ),
                                            trailing: Icon(
                                              _abierta(i)
                                                  ? Icons.expand_less
                                                  : Icons.expand_more,
                                            ),
                                            title: Text(
                                              'OP ${i.item.op} · ${i.item.descripcion} · Talla ${i.item.talla}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            subtitle: Text(
                                              i.disponibleParaDespacho <= 0
                                                  ? 'Sin prendas en bodega · ${max(0, i.producido - i.recibido)} por recibir · ${i.pendienteProduccion} en producción'
                                                  : '${_total(i)} de ${i.disponibleParaDespacho} en empaques · ${i.ubicaciones.keys.join(', ')}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          if (_abierta(i))
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                _indicadoresEmpaque(i),
                                                const SizedBox(height: 14),
                                                if ((_asignaciones[i.id]
                                                        ?.isEmpty ??
                                                    true))
                                                  const Padding(
                                                    padding: EdgeInsets.only(
                                                      bottom: 12,
                                                    ),
                                                    child: Text(
                                                      'Aún no hay empaques para esta OP. Elige el tipo para empezar.',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                for (final entry
                                                    in (_asignaciones[i.id] ??
                                                            {})
                                                        .entries)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 12,
                                                        ),
                                                    child: LayoutBuilder(
                                                      builder: (context, c) {
                                                        final tipo = DropdownButtonFormField<
                                                          String
                                                        >(
                                                          key: ValueKey(
                                                            'tipo-${i.id}-${entry.key}-${entry.value.empaqueId}',
                                                          ),
                                                          initialValue:
                                                              catalogo.any(
                                                                    (e) =>
                                                                        e['id'] ==
                                                                        entry
                                                                            .value
                                                                            .empaqueId,
                                                                  )
                                                                  ? entry
                                                                      .value
                                                                      .empaqueId
                                                                  : null,
                                                          isExpanded: true,
                                                          decoration:
                                                              InputDecoration(
                                                                labelText:
                                                                    'Empaque ${_numeros[entry.key]}',
                                                                isDense: true,
                                                              ),
                                                          items: [
                                                            for (final e
                                                                in catalogo)
                                                              DropdownMenuItem(
                                                                value:
                                                                    '${e['id']}',
                                                                child: Text(
                                                                  descripcionEmpaque(
                                                                    e,
                                                                  ),
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ),
                                                          ],
                                                          onChanged:
                                                              congelado
                                                                  ? null
                                                                  : (tipo) {
                                                                    if (tipo !=
                                                                        null) {
                                                                      setState(() {
                                                                        for (final a
                                                                            in _asignaciones.values) {
                                                                          if (a[entry.key] !=
                                                                              null) {
                                                                            a[entry.key]!.empaqueId =
                                                                                tipo;
                                                                          }
                                                                        }
                                                                      });
                                                                    }
                                                                  },
                                                        );
                                                        final cantidad = Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            IconButton(
                                                              tooltip:
                                                                  'Restar prenda',
                                                              onPressed:
                                                                  congelado
                                                                      ? null
                                                                      : () => setState(() {
                                                                        final n =
                                                                            int.tryParse(
                                                                              entry.value.prendas,
                                                                            ) ??
                                                                            0;
                                                                        entry.value.prendas =
                                                                            '${n > 0 ? n - 1 : 0}';
                                                                        _revisionEmpaques++;
                                                                      }),
                                                              icon: const Icon(
                                                                Icons.remove,
                                                                size: 18,
                                                              ),
                                                            ),
                                                            SizedBox(
                                                              width: 62,
                                                              child: TextFormField(
                                                                key: ValueKey(
                                                                  'prendas-${i.id}-${entry.key}-$_revisionEmpaques',
                                                                ),
                                                                initialValue:
                                                                    entry
                                                                        .value
                                                                        .prendas,
                                                                enabled:
                                                                    !congelado,
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                keyboardType:
                                                                    TextInputType
                                                                        .number,
                                                                inputFormatters: [
                                                                  FilteringTextInputFormatter
                                                                      .digitsOnly,
                                                                ],
                                                                decoration:
                                                                    const InputDecoration(
                                                                      labelText:
                                                                          'Prendas',
                                                                      isDense:
                                                                          true,
                                                                    ),
                                                                onChanged:
                                                                    (
                                                                      v,
                                                                    ) => setState(
                                                                      () =>
                                                                          entry.value.prendas =
                                                                              v,
                                                                    ),
                                                              ),
                                                            ),
                                                            IconButton(
                                                              tooltip:
                                                                  'Sumar prenda',
                                                              onPressed:
                                                                  congelado
                                                                      ? null
                                                                      : () => setState(() {
                                                                        entry.value.prendas =
                                                                            '${(int.tryParse(entry.value.prendas) ?? 0) + 1}';
                                                                        _revisionEmpaques++;
                                                                      }),
                                                              icon: const Icon(
                                                                Icons.add,
                                                                size: 18,
                                                              ),
                                                            ),
                                                            IconButton(
                                                              tooltip:
                                                                  'Quitar empaque',
                                                              onPressed:
                                                                  congelado
                                                                      ? null
                                                                      : () => setState(() {
                                                                        _asignaciones[i.id]!.remove(
                                                                          entry
                                                                              .key,
                                                                        );
                                                                        _revisionEmpaques++;
                                                                      }),
                                                              icon: const Icon(
                                                                Icons.close,
                                                                color:
                                                                    Colors.red,
                                                                size: 18,
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                        return c.maxWidth < 500
                                                            ? Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .stretch,
                                                              children: [
                                                                tipo,
                                                                const SizedBox(
                                                                  height: 8,
                                                                ),
                                                                Align(
                                                                  alignment:
                                                                      Alignment
                                                                          .centerRight,
                                                                  child:
                                                                      cantidad,
                                                                ),
                                                              ],
                                                            )
                                                            : Row(
                                                              children: [
                                                                Expanded(
                                                                  child: tipo,
                                                                ),
                                                                const SizedBox(
                                                                  width: 8,
                                                                ),
                                                                cantidad,
                                                              ],
                                                            );
                                                      },
                                                    ),
                                                  ),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: [
                                                    for (final e in catalogo
                                                        .take(2))
                                                      OutlinedButton.icon(
                                                        onPressed:
                                                            congelado ||
                                                                    i.disponibleParaDespacho <=
                                                                        0
                                                                ? null
                                                                : () =>
                                                                    _agregarRapido(
                                                                      i,
                                                                      e,
                                                                    ),
                                                        icon: Icon(
                                                          e['categoria'] ==
                                                                  'CAJA'
                                                              ? Icons
                                                                  .inventory_2_outlined
                                                              : Icons
                                                                  .shopping_bag_outlined,
                                                          size: 15,
                                                        ),
                                                        label: Text(
                                                          '+ ${textoEmpaque(e['nombre'])}',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 11,
                                                              ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                DropdownButtonFormField<String>(
                                                  key: ValueKey(
                                                    'agregar-${i.id}-$_revisionEmpaques',
                                                  ),
                                                  isExpanded: true,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText:
                                                            'Agregar empaque',
                                                        isDense: true,
                                                      ),
                                                  items: [
                                                    for (final b in _bultos
                                                        .entries
                                                        .where(
                                                          (b) =>
                                                              !(_asignaciones[i
                                                                          .id] ??
                                                                      {})
                                                                  .containsKey(
                                                                    b.key,
                                                                  ),
                                                        ))
                                                      DropdownMenuItem(
                                                        value: 'usar:${b.key}',
                                                        child: Text(
                                                          'Usar empaque ${_numeros[b.key]}',
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                      ),
                                                    for (final e in catalogo)
                                                      DropdownMenuItem(
                                                        value:
                                                            'nuevo:${e['id']}',
                                                        child: Text(
                                                          'Nuevo · ${descripcionEmpaque(e)}',
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                      ),
                                                  ],
                                                  onChanged:
                                                      congelado
                                                          ? null
                                                          : (id) {
                                                            if (id == null) {
                                                              return;
                                                            }
                                                            setState(() {
                                                              final existe = id
                                                                  .startsWith(
                                                                    'usar:',
                                                                  );
                                                              final key =
                                                                  existe
                                                                      ? id.substring(
                                                                        5,
                                                                      )
                                                                      : (_siguienteEmpaque++)
                                                                          .toString();
                                                              final tipo =
                                                                  existe
                                                                      ? _bultos[key]!
                                                                      : id.substring(
                                                                        6,
                                                                      );
                                                              _asignaciones
                                                                      .putIfAbsent(
                                                                        i.id,
                                                                        () =>
                                                                            {},
                                                                      )[key] =
                                                                  _EmpaqueAsignado(
                                                                    tipo,
                                                                  );
                                                              _revisionEmpaques++;
                                                            });
                                                          },
                                                ),
                                                if (catalogo.isEmpty)
                                                  const Text(
                                                    'No hay empaques activos. Créalos en Administración → Empaques.',
                                                  ),
                                                const SizedBox(height: 10),
                                                Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: TextButton(
                                                    onPressed:
                                                        congelado ||
                                                                (_asignaciones[i
                                                                            .id]
                                                                        ?.isEmpty ??
                                                                    true)
                                                            ? null
                                                            : () => setState(() {
                                                              final maximo =
                                                                  i.disponibleParaDespacho <
                                                                          i.pendienteDisponibleDespacho
                                                                      ? i.disponibleParaDespacho
                                                                      : i.pendienteDisponibleDespacho;
                                                              final falta =
                                                                  maximo -
                                                                  _total(i);
                                                              if (falta > 0) {
                                                                final ultima =
                                                                    _asignaciones[i
                                                                            .id]!
                                                                        .values
                                                                        .last;
                                                                ultima.prendas =
                                                                    '${(int.tryParse(ultima.prendas) ?? 0) + falta}';
                                                                _revisionEmpaques++;
                                                              }
                                                            }),
                                                    child: const Text(
                                                      'Repartir lo que falta',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
                final resumen = _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _titulo(
                        'Empaques del despacho',
                        '${_bultos.length} empaques · $_cantidadTotal prendas',
                      ),
                      if (_bultos.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 28,
                            horizontal: 12,
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: _soft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                color: Color(0xff648090),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Todavía no hay empaques',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Agrega una caja o paquete. Aquí aparecerá su número, peso y rótulo.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      for (final b in _bultos.entries)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: _navy,
                            child: Text(
                              '${_numeros[b.key]}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(
                            descripcionEmpaque(
                              catalogo
                                      .where((e) => e['id'] == b.value)
                                      .firstOrNull ??
                                  {'nombre': 'No disponible'},
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${_asignaciones.values.fold<int>(0, (n, a) => n + (int.tryParse(a[b.key]?.prendas ?? '0') ?? 0))} prendas${_rotuloPendiente(b.key) ? ' · Rótulo cambió' : ''}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              if (_prendasBulto(b.key) <= 0)
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Vacío · agrega prendas o quita este empaque',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xff9a6700),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      key: ValueKey('peso-bruto-${b.key}'),
                                      initialValue: _pesosBrutos[b.key] ?? '',
                                      enabled: !congelado,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        labelText: 'Peso bruto (kg) *',
                                        isDense: true,
                                        helperText:
                                            'Pésalo cerrado, con las prendas dentro.',
                                        helperMaxLines: 2,
                                      ),
                                      onChanged:
                                          (valor) => setState(
                                            () => _pesosBrutos[b.key] = valor,
                                          ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip:
                                        'Generar rótulo ${_numeros[b.key]}',
                                    onPressed:
                                        congelado ||
                                                _destino == null ||
                                                _prendasBulto(b.key) <= 0
                                            ? null
                                            : () => _generarRotulo(b.key),
                                    icon: const Icon(
                                      Icons.print_outlined,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed:
                            congelado ||
                                    _destino == null ||
                                    _bultos.isEmpty ||
                                    _bultos.keys.any(
                                      (key) => _prendasBulto(key) <= 0,
                                    )
                                ? null
                                : _generarTodosLosRotulos,
                        icon: const Icon(Icons.print_outlined, size: 16),
                        label: const Text(
                          'Generar todos los rótulos en un PDF',
                        ),
                      ),
                      const Text(
                        'Rótulos de 10 × 10 cm. Imprime al 100 %. Generarlos no guarda ni confirma la salida.',
                        style: TextStyle(fontSize: 11),
                      ),
                      const Divider(height: 28),
                      const Text(
                        'Documentos del despacho',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _ocDocumento,
                        enabled: !congelado,
                        maxLength: 150,
                        decoration: InputDecoration(
                          labelText: 'OC para este despacho (opcional)',
                          hintText: _oc,
                          helperText:
                              'Vacío conserva la OC original. Solo cambia este despacho y sus documentos.',
                          helperMaxLines: 3,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                );
                return constraints.maxWidth < 800
                    ? Column(children: [tarjetas, resumen])
                    : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: tarjetas),
                        const SizedBox(width: 16),
                        Expanded(flex: 3, child: resumen),
                      ],
                    );
              },
            ),
      );

  // Proyección exclusiva para empacar el saldo elegido; no altera el kardex.
  List<InventarioFila> get _origenesInventario =>
      _inventario?['origenes'] is List
          ? (_inventario!['origenes'] as List).cast<InventarioFila>()
          : [_inventario!];

  List<ItemKardex> get _itemsInventario {
    final grupos = <String, List<InventarioFila>>{};
    for (final r in _origenesInventario) {
      grupos.putIfAbsent('${r['item_id']}', () => []).add(r);
    }
    return grupos.entries.map((e) {
      final r = e.value.first;
      final ubicaciones = <String, int>{};
      for (final f in e.value) {
        final u = '${f['ubicacion']}';
        ubicaciones[u] = (ubicaciones[u] ?? 0) + (f['libre'] as num).toInt();
      }
      final libre = ubicaciones.values.fold<int>(0, (a, b) => a + b);
      return ItemKardex(
        item: ItemOrden(
          id: e.key,
          op: '${r['numero_op']}',
          cliente: '${_inventario!['cliente']}',
          oc: _ocVisible,
          codigo: '${r['codigo'] ?? ''}',
          descripcion: '${r['producto']}',
          talla: '${r['talla']}',
          cantidadPedida: libre,
        ),
        producido: libre,
        recibido: libre,
        despachado: 0,
        ubicaciones: ubicaciones,
      );
    }).toList();
  }

  List<InventarioFila> _asignacionesInventario() {
    final usadas = <String, int>{};
    for (final linea in _pendiente!) {
      var falta = (linea['cantidad'] as num).toInt();
      for (final r in _origenesInventario.where(
        (r) =>
            r['item_id'] == linea['item_id'] &&
            r['ubicacion'] == linea['ubicacion'],
      )) {
        final id = '${r['id']}';
        final libre = (r['libre'] as num).toInt() - (usadas[id] ?? 0);
        final tomar = falta < libre ? falta : libre;
        if (tomar > 0) {
          usadas[id] = (usadas[id] ?? 0) + tomar;
          falta -= tomar;
        }
        if (falta == 0) break;
      }
      if (falta != 0) {
        throw StateError('Las cantidades superan la selección de inventario.');
      }
    }
    return [
      for (final e in usadas.entries)
        {'transferencia': e.key, 'cantidad': e.value},
    ];
  }

  List<ItemKardex> get _items =>
      _inventario != null
          ? _itemsInventario
          : (ref.read(wmsSnapshotProvider).value?.kardex ?? [])
              .where((i) => !i.eliminada)
              .map((i) {
                final d = widget.correccion;
                if (d == null || _correccionGuardada) return i;
                final retiros = (d['detalle'] as List).where(
                  (e) => e['item_id'] == i.id,
                );
                final ubicaciones = {...i.ubicaciones};
                final reservas = {...i.reservas};
                final empacado = d['fase'] == 'empacado';
                var cantidad = 0;
                for (final e in retiros) {
                  final n = (e['cantidad'] as num).toInt();
                  cantidad += n;
                  final u = '${e['ubicacion']}';
                  if (empacado) {
                    reservas[u] = (reservas[u] ?? 0) - n;
                  } else {
                    ubicaciones[u] = (ubicaciones[u] ?? 0) + n;
                  }
                }
                return ItemKardex(
                  item: i.item,
                  producido: i.producido,
                  recibido: i.recibido,
                  despachado: i.despachado - (empacado ? 0 : cantidad),
                  stockInventario: i.stockInventario,
                  ubicaciones: ubicaciones,
                  reservas: reservas,
                );
              })
              .toList();
  List<ItemKardex> get _lineas =>
      _items
          .where(
            (i) =>
                i.item.cliente == _cliente &&
                (_inventario != null || i.item.oc == _oc),
          )
          .toList();
  void _seleccionar(String op, bool seleccionar) {
    setState(() {
      if (seleccionar) {
        _ops.add(op);
      } else {
        _ops.remove(op);
        for (final i in _lineas.where((i) => i.item.op == op)) {
          _asignaciones.remove(i.id);
        }
      }
    });
  }

  void _escanear(String texto) {
    final q = QrPrenda.tryParse(texto);
    _qr.clear();
    final item =
        _items
            .where(
              (i) =>
                  q == null
                      ? i.item.codigo == texto.trim() ||
                          i.item.op == texto.trim()
                      : i.item.op == q.op && i.item.codigo == q.codigo,
            )
            .firstOrNull;
    if (item == null) {
      setState(() => _mensaje = 'QR no encontrado.');
      return;
    }
    if (item.disponibleParaDespacho <= 0 ||
        item.pendienteDisponibleDespacho <= 0) {
      _mensaje = 'La prenda no tiene unidades disponibles en bodega.';
      return;
    }
    if (_ops.isNotEmpty &&
        (_cliente != item.item.cliente || _oc != item.item.oc)) {
      _mensaje =
          'La etiqueta pertenece a otra OC. Termina la selección actual antes de cambiar.';
      return;
    }
    setState(() {
      if (_cliente != item.item.cliente || _oc != item.item.oc) _limpiar();
      _cliente = item.item.cliente;
      _oc = item.item.oc;
      _ops.add(item.item.op);
    });
  }

  FeedbackMessage _leerCamara(String raw) {
    final qr = QrPrenda.tryParse(raw);
    final item =
        qr == null
            ? null
            : _items
                .where((i) => i.item.op == qr.op && i.item.codigo == qr.codigo)
                .firstOrNull;
    if (item == null) return const FeedbackMessage.error('QR no encontrado.');
    if (item.disponibleParaDespacho <= 0 ||
        item.pendienteDisponibleDespacho <= 0) {
      return const FeedbackMessage.error('Sin prendas disponibles en bodega.');
    }
    // La cámara no debe borrar una selección previa al encontrar otra OC.
    if (_ops.isNotEmpty &&
        (_cliente != item.item.cliente || _oc != item.item.oc)) {
      return const FeedbackMessage.error(
        'La etiqueta pertenece a otra OC. Termina la selección actual antes de cambiar de orden.',
      );
    }
    _escanear(raw);
    return FeedbackMessage.ok(
      'OP ${item.item.op} · Agregada a la selección de despacho. Define las cantidades al volver.',
    );
  }

  double _pesoBruto(String pieza, Map<String, dynamic> empaque) {
    try {
      return validarPesoBruto(
        _pesosBrutos[pieza] ?? '',
        (empaque['peso_neto_kg'] as num?) ?? 0,
      );
    } on FormatException catch (e) {
      throw FormatException('Empaque ${_numeros[pieza]}: ${e.message}');
    }
  }

  String _resumenPeso(String pieza, String empaqueId) {
    final e =
        ref
            .read(empaquesProvider)
            .valueOrNull
            ?.where((e) => e['id'] == empaqueId)
            .firstOrNull;
    if (e == null) return 'Peso pendiente';
    try {
      final bruto = _pesoBruto(pieza, e);
      final tara = (e['peso_neto_kg'] as num?) ?? 0;
      return 'Bruto: $bruto kg · Tara: $tara kg · Neto: ${(bruto - tara).toStringAsFixed(3)} kg';
    } on FormatException {
      return 'Peso pendiente o inválido';
    }
  }

  Future<void> _preparar({bool completa = false}) async {
    if (_ocupado || _preparando) return;
    if (_pendiente != null) {
      await _guardar();
      return;
    }
    setState(() => _preparando = true);
    try {
      if (_asignaciones.keys.any(
        (id) => !_lineas.any((i) => i.id == id && _ops.contains(i.item.op)),
      )) {
        throw const FormatException(
          'Una prenda del borrador ya no está disponible. Revisa la selección antes de confirmar.',
        );
      }
      if (_faltaDestino) {
        throw const FormatException(
          'Selecciona el destinatario antes de empacar.',
        );
      }
      final catalogo = ref.read(empaquesProvider).value;
      if (catalogo == null) {
        throw const FormatException(
          'Espera a que cargue el catálogo de empaques.',
        );
      }
      final empaques = <Map<String, dynamic>>[];
      final cantidades = <String, int>{};
      for (final i in _lineas.where((i) => _ops.contains(i.item.op))) {
        for (final entry in (_asignaciones[i.id] ?? {}).entries) {
          final n = int.tryParse(entry.value.prendas);
          if (n == null || n <= 0 || n > 999999) {
            throw const FormatException(
              'Indica entre 1 y 999999 prendas por empaque, o quita la fila.',
            );
          }
          final e =
              catalogo
                  .where((e) => e['id'] == entry.value.empaqueId)
                  .firstOrNull;
          if (e == null) {
            throw const FormatException(
              'Un empaque ya no está disponible. Actualiza el catálogo.',
            );
          }
          empaques.add({
            'item_id': i.id,
            'numero': _numeros[entry.key],
            'empaque_id': entry.value.empaqueId,
            'cantidad': n,
            'version': e['version'],
            'peso_bruto_kg': _pesoBruto(entry.key, e),
            if (_empaqueMasivo) 'admin_masivo': true,
          });
          cantidades[i.id] = (cantidades[i.id] ?? 0) + n;
        }
      }
      if (_inventario?['origenes'] is List &&
          _lineas.any(
            (i) => cantidades[i.id] != i.pendienteDisponibleDespacho,
          )) {
        throw const FormatException(
          'Distribuye todas las cantidades seleccionadas en los empaques para conservar el reparto de inventario.',
        );
      }
      if (completa &&
          _lineas.any(
            (i) =>
                i.pendienteDisponibleDespacho > 0 &&
                cantidades[i.id] != i.pendienteDisponibleDespacho,
          )) {
        throw const FormatException(
          'Para completar la OC, distribuye todas las prendas pendientes de cada OP en sus empaques.',
        );
      }
      final plan = planificarDespacho(_lineas, cantidades);
      final total = plan.fold<int>(0, (n, l) => n + (l['cantidad'] as int));
      if (_paso != 3 || _planRevisado == null) {
        setState(() {
          _planRevisado = plan;
          _paso = 3;
        });
        return;
      }
      if (widget.correccion != null && _motivoCorreccion.text.trim().isEmpty) {
        throw const FormatException(
          'Indica el motivo de la corrección para guardar los cambios.',
        );
      }
      if (_bultos.keys.any(_rotuloPendiente)) {
        throw const FormatException(
          'Vuelve a generar los rótulos modificados antes de confirmar.',
        );
      }
      if (_planRevisado.toString() != plan.toString()) {
        setState(() => _planRevisado = plan);
        throw const FormatException(
          'Cambió la disponibilidad. Revisa nuevamente los estantes y confirma.',
        );
      }
      _confirmadas = total;
      _bultosConfirmados = _bultos.length;
      // Volver a comprobar los saldos si cambiaron mientras se revisaba.
      final actualizado = planificarDespacho(_lineas, cantidades);
      if (actualizado.toString() != plan.toString()) {
        throw const FormatException(
          'Cambió la disponibilidad en los estantes. Revisa el despacho nuevamente.',
        );
      }
      _pendiente = plan;
      _empaquesPendientes = empaques;
      _solicitud = nuevaSolicitudDespacho();
      await _guardar();
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _mensaje =
                  e is FormatException
                      ? e.message
                      : 'No se pudo preparar el despacho: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _preparando = false);
    }
  }

  Future<void> _guardar() async {
    final repo = ref.read(despachosOcProvider);
    if (repo == null) {
      setState(() {
        _mensaje = 'No se pudo conectar al servicio de despachos.';
        _pendiente = null;
        _solicitud = null;
      });
      return;
    }
    setState(() => _ocupado = true);

    try {
      // Conserva el identificador de reintento antes de una escritura real.
      // Si falla el borrado posterior, retomar no puede duplicar el despacho.
      await _persistirBorrador();
      if (_inventario != null) {
        final inventarioRepo = ref.read(inventarioRepositoryProvider);
        if (inventarioRepo == null) {
          throw StateError('Inventario no disponible');
        }
        await inventarioRepo.ejecutar(
          _inventario!['origenes'] is List
              ? 'inventario_empacar_multiple'
              : 'inventario_empacar_flujo',
          {
            'p_solicitud': _solicitud!,
            if (_inventario!['origenes'] is List)
              'p_asignaciones': _asignacionesInventario()
            else
              'p_transferencia': _inventario!['id'],
            'p_oc': _ocVisible,
            'p_destinatario': _destinatarioId,
            'p_destinatario_version': _destino?['version'],
            'p_empaques': _empaquesPendientes,
          },
        );
      } else if (widget.correccion != null) {
        await repo.corregir(
          '${widget.correccion!['id']}',
          '${widget.correccion!['version']}',
          _solicitud!,
          _motivoCorreccion.text.trim(),
          _cliente!,
          _oc!,
          _pendiente!,
          _empaquesPendientes,
          ocDocumento: _ocDocumento.text.trim(),
          destinatarioId: _destinatarioId,
          destinatarioVersion: _destino?['version'] as String?,
        );

        _correccionGuardada = true;
      } else {
        await repo.confirmar(
          _solicitud!,
          _cliente!,
          _oc!,
          _pendiente!,
          empaques: _empaquesPendientes,
          ocDocumento: _ocDocumento.text.trim(),
          destinatarioId: _destinatarioId,
          destinatarioVersion: _destino?['version'] as String?,
        );
      }
      _pendiente = null;
      _solicitud = null;
      ref.invalidate(historialDespachosProvider);
      ref.invalidate(entregasProvider);

      try {
        await ref.read(wmsRepositoryProvider).refrescar();
      } catch (_) {
        // El guardado ya fue confirmado; no repetirlo si falla el refresco.
      }
      if (mounted) {
        setState(() {
          _exito = true;
        });
      }
      if (_versionBorrador > 0) {
        try {
          await ref
              .read(despachoBorradorRepositoryProvider)!
              .eliminar(_claveBorrador, version: _versionBorrador);
          _versionBorrador = 0;
        } catch (_) {
          if (mounted) {
            _mensaje =
                'El despacho se confirmó, pero no se pudo limpiar su borrador. Si lo retomas, se verificará la misma solicitud.';
          }
        }
      }
    } on PostgrestException catch (e) {
      _pendiente = null;
      _solicitud = null;
      if (mounted) setState(() => _mensaje = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _mensaje =
                  'No se pudo confirmar la respuesta. Reintenta este mismo despacho; su identificador evita duplicarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
    if (mounted && _correccionGuardada) _salir();
  }

  static const _navy = Color(0xff123e4f);
  static const _soft = Color(0xfff4f8f9);
  static const _green = Color(0xff1c704b);
  int get _cantidadTotal => _lineas
      .where((i) => _ops.contains(i.item.op))
      .fold(0, (n, i) => n + _total(i));
  String get _nombreDestino =>
      _destino == null
          ? 'Destino de prueba'
          : '${_destino!['datos']['nombre']} · ${_destino!['datos']['ciudad'] ?? _destino!['datos']['sede'] ?? ''}';
  Widget _panel(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xffdce6eb)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Material(color: Colors.transparent, child: child),
  );
  Widget _titulo(String titulo, String detalle) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold, color: _navy),
        ),
        Text(
          detalle,
          style: const TextStyle(fontSize: 12, color: Color(0xff648090)),
        ),
      ],
    ),
  );
  Future<void> _empacarOcMasiva() async {
    if (!_admin || _ocupado || _preparando) return;
    final cajas =
        (ref.read(empaquesProvider).valueOrNull ?? [])
            .where((e) => e['categoria'] == 'CAJA')
            .toList();
    final elegibles =
        _lineas
            .where(
              (i) =>
                  min(i.disponibleParaDespacho, i.pendienteDisponibleDespacho) >
                  0,
            )
            .toList();
    if (cajas.isEmpty || elegibles.isEmpty) {
      setState(
        () =>
            _mensaje =
                'Se necesita una caja activa y prendas disponibles de esta OC.',
      );
      return;
    }
    String caja = '${cajas.first['id']}';
    final total = elegibles.fold<int>(
      0,
      (n, i) =>
          n + min(i.disponibleParaDespacho, i.pendienteDisponibleDespacho),
    );
    final elegido = await showDialog<String>(
      context: context,
      builder:
          (c) => StatefulBuilder(
            builder:
                (c, cambiar) => AlertDialog(
                  title: const Text('Empacar toda la OC en una caja'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'OC $_oc · $total unidades disponibles · ${elegibles.map((i) => i.item.op).toSet().length} OP. Reemplaza la distribución de empaques que estás editando. Las unidades sin stock quedan pendientes.',
                      ),
                      DropdownButton<String>(
                        isExpanded: true,
                        value: caja,
                        items: [
                          for (final e in cajas)
                            DropdownMenuItem(
                              value: '${e['id']}',
                              child: Text(
                                '${e['nombre']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => cambiar(() => caja = v!),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, caja),
                      child: const Text('Preparar empaque'),
                    ),
                  ],
                ),
          ),
    );
    if (elegido == null || !mounted || !_admin) return;
    setState(() {
      _ops
        ..clear()
        ..addAll(elegibles.map((i) => i.item.op));
      _asignaciones.clear();
      _pesosBrutos.clear();
      _rotulosGenerados.clear();
      final pieza = '${_siguienteEmpaque++}';
      for (final i in elegibles) {
        _asignaciones[i.id] = {
          pieza: _EmpaqueAsignado(elegido)
            ..prendas =
                '${min(i.disponibleParaDespacho, i.pendienteDisponibleDespacho)}',
        };
      }
      _empaqueMasivo = true;
      _planRevisado = null;
      _revisionEmpaques++;
      _opEmpaque = null;
      _tallaEmpaque = null;
      _mensaje =
          'OC agrupada en una caja. Indica su peso bruto y revisa antes de confirmar.';
    });
  }

  Widget _cabeceraEmpaque() => LayoutBuilder(
    builder: (context, c) {
      final titulo = _titulo(
        'Reparte las prendas en cajas o paquetes',
        'Cada empaque tiene su número, su peso y su rótulo.',
      );
      final ops =
          _lineas
              .where((i) => _ops.contains(i.item.op))
              .map((i) => i.item.op)
              .toSet()
              .toList()
            ..sort();
      final filtroOp = DropdownButtonFormField<String>(
        key: ValueKey('filtro-op-empaque-${_opEmpaque ?? "todas"}'),
        initialValue: ops.contains(_opEmpaque) ? _opEmpaque : null,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Filtrar por OP'),
        hint: const Text('Todas las OP'),
        items: [
          for (final op in ops)
            DropdownMenuItem(value: op, child: Text('OP $op')),
        ],
        onChanged:
            (op) => setState(() {
              _opEmpaque = op;
              _tallaEmpaque = null;
              if (op != null) _gruposOpAbiertos[op] = true;
            }),
      );
      final tallas =
          _lineas
              .where((i) => _ops.contains(i.item.op) && _coincideOp(i))
              .map((i) => i.item.talla)
              .toSet()
              .toList()
            ..sort();
      final filtroTalla = DropdownButtonFormField<String>(
        key: ValueKey('filtro-talla-empaque-${_tallaEmpaque ?? "todas"}'),
        initialValue: tallas.contains(_tallaEmpaque) ? _tallaEmpaque : null,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Filtrar por talla'),
        hint: const Text('Todas las tallas'),
        items: [
          for (final talla in tallas)
            DropdownMenuItem(value: talla, child: Text(talla)),
        ],
        onChanged:
            (talla) => setState(() {
              _tallaEmpaque = talla;
              for (final i in _lineas.where(
                (i) =>
                    _ops.contains(i.item.op) &&
                    i.item.talla == talla &&
                    _coincideOp(i),
              )) {
                _gruposOpAbiertos[i.item.op] = true;
              }
            }),
      );
      final acciones = Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (_admin)
            TextButton.icon(
              onPressed: _ocupado || _preparando ? null : _empacarOcMasiva,
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Empacar OC completa'),
            ),
          SizedBox(width: min(200, c.maxWidth), child: filtroTalla),
          SizedBox(width: min(200, c.maxWidth), child: filtroOp),
          TextButton.icon(
            key: const ValueKey('limpiar-filtros-empaque'),
            onPressed:
                () => setState(() {
                  _opEmpaque = null;
                  _tallaEmpaque = null;
                }),
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Limpiar filtros'),
          ),
        ],
      );
      return c.maxWidth < 1350
          ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [titulo, acciones],
          )
          : Row(
            children: [
              SizedBox(width: 360, child: titulo),
              const SizedBox(width: 20),
              acciones,
              const Spacer(),
            ],
          );
    },
  );
  Widget _pasos() => LayoutBuilder(
    builder: (context, c) {
      const nombres = ['Destino', 'Prendas', 'Empaques', 'Confirmar'];
      final escala = MediaQuery.textScalerOf(context).scale(12) / 12;
      final estrecho = c.maxWidth < 600 * escala;
      Widget paso(int n) => Semantics(
        selected: n == _paso,
        label: 'Paso ${n + 1} de 4',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor:
                  n < _paso
                      ? _green
                      : n == _paso
                      ? _navy
                      : AppColors.slate200,
              child:
                  n < _paso
                      ? const Icon(Icons.check, size: 15, color: Colors.white)
                      : Text(
                        '${n + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          color: n == _paso ? Colors.white : _navy,
                        ),
                      ),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                nombres[n],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: n == _paso ? FontWeight.w700 : FontWeight.w600,
                  color: n == _paso ? _navy : AppColors.slate600,
                ),
              ),
            ),
          ],
        ),
      );
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
        child:
            estrecho
                ? Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    for (var n = 0; n < nombres.length; n++)
                      SizedBox(width: (c.maxWidth - 12) / 2, child: paso(n)),
                  ],
                )
                : Row(
                  children: [
                    for (var n = 0; n < nombres.length; n++) ...[
                      if (n > 0)
                        Expanded(
                          child: Container(
                            height: 2,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            color: n <= _paso ? _green : AppColors.slate200,
                          ),
                        ),
                      paso(n),
                    ],
                  ],
                ),
      );
    },
  );
  Widget _destinoPaso(bool bloqueado) {
    if (_inventario != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder:
                (context, c) => Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    for (final dato in [
                      ('Cliente', '$_cliente'),
                      (
                        _inventario!['origenes'] is List
                            ? 'Fichas técnicas'
                            : 'Ficha técnica',
                        _inventario!['origenes'] is List
                            ? '${_origenesInventario.map((r) => r['ficha']).toSet().length}'
                            : '${_inventario!['ficha']}',
                      ),
                      (
                        _inventario!['origenes'] is List
                            ? 'Prendas seleccionadas'
                            : 'OP origen',
                        _inventario!['origenes'] is List
                            ? '${_itemsInventario.fold<int>(0, (a, i) => a + i.recibido)} unidades'
                            : '${_inventario!['numero_op']}',
                      ),
                    ])
                      Container(
                        width:
                            c.maxWidth < 550
                                ? c.maxWidth
                                : (c.maxWidth - 24) / 3,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dato.$1,
                              style: const TextStyle(
                                color: Colors.blueGrey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dato.$2,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE5F0FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: Color(0xFF285D94)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Las prendas conservan su cliente y se asignan a la OC que indiques.',
                    style: TextStyle(color: Color(0xFF285D94)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _selectorDestino(bloqueado),
          const SizedBox(height: 20),
          TextField(
            controller: _ocDocumento,
            enabled: !bloqueado,
            maxLength: 150,
            decoration: const InputDecoration(
              labelText: 'Orden de compra de destino',
              hintText: 'Ej.: OC-2026-0458',
            ),
            onChanged: (v) => setState(() => _oc = v.trim()),
          ),
        ],
      );
    }
    final clientes =
        _items
            .where(
              (i) =>
                  i.disponibleParaDespacho > 0 &&
                  i.pendienteDisponibleDespacho > 0,
            )
            .map((i) => i.item.cliente)
            .toSet()
            .toList()
          ..sort();
    if (widget.correccion != null &&
        _cliente != null &&
        !clientes.contains(_cliente)) {
      clientes.add(_cliente!);
    }
    Widget tarjeta(List<Widget> contenido) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: contenido,
      ),
    );
    Widget titulo(int numero, String texto, String detalle) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$numero. ',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: _navy,
              ),
            ),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: _navy,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          detalle,
          style: const TextStyle(color: AppColors.slate600, fontSize: 12),
        ),
      ],
    );
    final destino = tarjeta([
      LayoutBuilder(
        builder: (context, c) {
          final encabezado = titulo(
            1,
            '¿A quién va el empaque?',
            'El destinatario y su sede salen impresos en el rótulo.',
          );
          final catalogo = OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _navy,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed:
                bloqueado ? null : () => mostrarListaEmpaque(context, ''),
            icon: const Icon(Icons.contacts_outlined, size: 16),
            label: const Text(
              'Catálogo / consecutivo LE',
              style: TextStyle(fontSize: 12),
            ),
          );
          if (!ref.watch(usarSupabaseProvider)) return encabezado;
          final escala = MediaQuery.textScalerOf(context).scale(12) / 12;
          return c.maxWidth < 580 * escala
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [encabezado, const SizedBox(height: 10), catalogo],
              )
              : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: encabezado),
                  const SizedBox(width: 12),
                  catalogo,
                ],
              );
        },
      ),
      if (ref.watch(usarSupabaseProvider)) ...[
        const SizedBox(height: 14),
        _selectorDestino(bloqueado),
      ],
    ]);
    final cliente = tarjeta([
      titulo(
        2,
        '¿De qué cliente son las prendas?',
        'En el siguiente paso verás sus órdenes de compra.',
      ),
      const SizedBox(height: 14),
      KeyedSubtree(
        key: const ValueKey('despacho-cliente-selector'),
        child: DropdownButtonFormField<String>(
          key: ValueKey(_cliente),
          initialValue: _cliente,
          isExpanded: true,
          menuMaxHeight: 260,
          dropdownColor: Colors.white,
          decoration: const InputDecoration(
            labelText: 'Cliente',
            hintText: 'Selecciona un cliente',
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          items: [
            for (final c in clientes)
              DropdownMenuItem(
                value: c,
                child: Text(c, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged:
              bloqueado
                  ? null
                  : (v) => setState(() {
                    _limpiar();
                    _cliente = v;
                    _oc = null;
                  }),
        ),
      ),
      if (clientes.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('No hay prendas disponibles en bodega.'),
        ),
    ]);
    final faltantes = (_faltaDestino ? 1 : 0) + (_cliente == null ? 1 : 0);
    final resumen = tarjeta([
      const Text(
        'Resumen del despacho',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: _navy,
        ),
      ),
      const SizedBox(height: 6),
      for (final dato in [
        (
          'Destino',
          _faltaDestino ? 'Sin seleccionar' : _nombreDestino,
          'despacho-resumen-destino',
        ),
        ('Cliente', _cliente ?? 'Sin seleccionar', 'despacho-resumen-cliente'),
        (
          'Estado',
          faltantes == 0
              ? 'Listo para elegir prendas'
              : faltantes == 1
              ? 'Falta 1 dato'
              : 'Faltan $faltantes datos',
          'despacho-resumen-estado',
        ),
      ]) ...[
        const Divider(height: 1, color: AppColors.cardBorder),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dato.$1,
                style: const TextStyle(fontSize: 12, color: AppColors.slate600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  dato.$2,
                  key: ValueKey(dato.$3),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        dato.$1 == 'Estado'
                            ? faltantes > 0
                                ? AppColors.amberChip
                                : _green
                            : _navy,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ]);
    return LayoutBuilder(
      builder: (context, c) {
        final formulario = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [destino, const SizedBox(height: 14), cliente],
        );
        final escala = MediaQuery.textScalerOf(context).scale(12) / 12;
        return c.maxWidth >= 850 * escala
            ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: formulario),
                const SizedBox(width: 16),
                SizedBox(width: 270, child: resumen),
              ],
            )
            : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [formulario, const SizedBox(height: 14), resumen],
            );
      },
    );
  }

  Future<void> _entradaCodigo() async {
    await showDialog<void>(
      context: context,
      builder:
          (ctx) => WmsExpandableAlertDialog(
            title: const Text('Seleccionar prendas'),
            content: SizedBox(
              width: 400,
              child: WmsScanField(
                controller: _qr,
                decoration: const InputDecoration(
                  labelText: 'QR o código de etiqueta',
                ),
                onSubmitted: (v) {
                  _escanear(v);
                  Navigator.pop(ctx);
                },
                onCameraSubmitted: _leerCamara,
              ),
            ),
          ),
    );
  }

  Widget _avanceProduccion(
    Iterable<ItemKardex> lineas,
    String alcance, {
    bool mostrarBarra = true,
  }) {
    final total = lineas.fold<int>(0, (s, i) => s + i.cantidadPedida);
    final entregado = lineas.fold<int>(0, (s, i) => s + i.producido);
    final avance = total > 0 ? entregado / total : 0.0;
    final texto = Text(
      'Producción $alcance: $entregado de $total prendas · ${(avance * 100).toStringAsFixed(1)} %',
      style: const TextStyle(fontSize: 12, color: AppColors.slate600),
    );
    if (!mostrarBarra) return texto;
    final barra = LinearProgressIndicator(
      value: avance.clamp(0.0, 1.0),
      minHeight: 5,
      borderRadius: BorderRadius.circular(4),
      backgroundColor: AppColors.slate200,
      color: AppColors.petroleo,
      semanticsLabel:
          'Avance de producción $alcance: $entregado de $total prendas',
    );
    return LayoutBuilder(
      builder: (context, c) {
        final escala = MediaQuery.textScalerOf(context).scale(12) / 12;
        return c.maxWidth >= 550 * escala
            ? Row(
              children: [
                texto,
                const SizedBox(width: 12),
                Expanded(child: barra),
              ],
            )
            : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [texto, const SizedBox(height: 6), barra],
            );
      },
    );
  }

  Widget _prendasPaso(bool bloqueado) {
    // El avance incluye las tallas y OP que todavía no tienen stock en bodega.
    final todas = _items.where((i) => i.item.cliente == _cliente).toList();
    final items =
        todas
            .where(
              (i) =>
                  i.item.cliente == _cliente &&
                  i.disponibleParaDespacho > 0 &&
                  i.pendienteDisponibleDespacho > 0,
            )
            .toList();
    final ocs = items.map((i) => i.item.oc).toSet().toList()..sort();

    Widget tarjeta(Widget contenido, {Key? key}) => Container(
      key: key,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: contenido,
    );

    Widget chip(String texto, {bool disponible = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: disponible ? AppColors.tealSoft : AppColors.slate200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: disponible ? _green : AppColors.slate600,
        ),
      ),
    );

    Widget tallasYUbicaciones(List<ItemKardex> lineas) {
      final ubicaciones = lineas.first.ubicaciones.keys.toSet();
      final mismasUbicaciones = lineas.every(
        (i) => setEquals(ubicaciones, i.ubicaciones.keys.toSet()),
      );
      Widget talla(ItemKardex i) => chip(
        'T. ${i.item.talla} · ${i.disponibleParaDespacho} en bodega',
        disponible: true,
      );
      if (mismasUbicaciones) {
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final i in lineas) talla(i),
            for (final ubicacion in ubicaciones) chip(ubicacion),
          ],
        );
      }
      // Si las ubicaciones difieren, cada talla conserva su propia asociación.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var n = 0; n < lineas.length; n++) ...[
            if (n > 0) const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                talla(lineas[n]),
                for (final ubicacion in lineas[n].ubicaciones.keys)
                  chip(ubicacion),
              ],
            ),
          ],
        ],
      );
    }

    Widget opcionOp(String oc, String op) {
      final disponibles =
          items.where((i) => i.item.oc == oc && i.item.op == op).toList();
      final descripciones =
          disponibles.map((i) => i.item.descripcion).toSet().toList();
      final elegida = _oc == oc && _ops.contains(op);
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Material(
          color: elegida ? _soft : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: elegida ? AppColors.petroleo : AppColors.cardBorder,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: CheckboxListTile(
            key: ValueKey('despacho-op-$oc-$op'),
            titleAlignment: ListTileTitleAlignment.top,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.petroleo,
            checkColor: Colors.white,
            value: elegida,
            title: Wrap(
              spacing: 10,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'OP $op',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: _navy,
                  ),
                ),
                if (descripciones.length == 1)
                  Text(
                    descripciones.single,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.slate600,
                    ),
                  ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (descripciones.length == 1)
                    tallasYUbicaciones(disponibles)
                  else
                    for (var n = 0; n < descripciones.length; n++) ...[
                      if (n > 0) const SizedBox(height: 8),
                      Text(
                        descripciones[n],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      tallasYUbicaciones(
                        disponibles
                            .where(
                              (i) => i.item.descripcion == descripciones[n],
                            )
                            .toList(),
                      ),
                    ],
                  const SizedBox(height: 10),
                  _avanceProduccion(
                    todas.where((i) => i.item.oc == oc && i.item.op == op),
                    'OP $op',
                  ),
                ],
              ),
            ),
            onChanged:
                bloqueado
                    ? null
                    : (v) {
                      if (_oc != oc) {
                        setState(() {
                          _limpiar();
                          _oc = oc;
                        });
                      }
                      _seleccionar(op, v == true);
                    },
          ),
        ),
      );
    }

    Widget tarjetaOc(String oc) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: tarjeta(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, c) {
                final encabezado = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      oc.isEmpty
                          ? 'Sin OC'
                          : oc.toUpperCase().startsWith('OC')
                          ? oc
                          : 'OC $oc',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _avanceProduccion(
                      todas.where((i) => i.item.oc == oc),
                      'OC',
                      mostrarBarra: false,
                    ),
                  ],
                );
                final elegir = OutlinedButton(
                  key: ValueKey('elegir-oc-$oc'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.petroleo,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed:
                      bloqueado
                          ? null
                          : () => setState(() {
                            if (_oc != oc && _inventario == null) {
                              _limpiar();
                            }
                            _oc = oc;
                            _ops.addAll(
                              items
                                  .where((i) => i.item.oc == oc)
                                  .map((i) => i.item.op),
                            );
                          }),
                  child: const Text(
                    'Elegir toda la OC',
                    style: TextStyle(fontSize: 12),
                  ),
                );
                final escala = MediaQuery.textScalerOf(context).scale(12) / 12;
                return c.maxWidth >= 500 * escala
                    ? Row(
                      children: [
                        Expanded(child: encabezado),
                        const SizedBox(width: 12),
                        elegir,
                      ],
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [encabezado, const SizedBox(height: 8), elegir],
                    );
              },
            ),
            for (final op
                in items
                    .where((i) => i.item.oc == oc)
                    .map((i) => i.item.op)
                    .toSet())
              opcionOp(oc, op),
          ],
        ),
        key: ValueKey('despacho-oc-$oc'),
      ),
    );

    Widget panelEscaneo({required bool compacto}) => tarjeta(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '¿Tienes las prendas en la mano?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _navy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Escanéalas y se marcan solas.',
            style: TextStyle(fontSize: 12, color: AppColors.slate600),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final camara = FilledButton.icon(
                key: const ValueKey('despacho-prendas-camara'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.lima,
                  foregroundColor: AppColors.petroleo,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed:
                    bloqueado
                        ? null
                        : () => showDialog<void>(
                          context: context,
                          builder: (_) => WmsCameraScanner(onRead: _leerCamara),
                        ),
                icon: const Icon(Icons.camera_alt_outlined, size: 17),
                label: const Text('Cámara', style: TextStyle(fontSize: 12)),
              );
              Widget entrada(String texto, String key, IconData icono) =>
                  OutlinedButton.icon(
                    key: ValueKey(key),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.petroleo,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: bloqueado ? null : _entradaCodigo,
                    icon: Icon(icono, size: 17),
                    label: Text(texto, style: const TextStyle(fontSize: 12)),
                  );
              final lector = entrada(
                'Lector',
                'despacho-prendas-lector',
                Icons.qr_code_scanner,
              );
              final codigo = entrada(
                'Escribir código',
                'despacho-prendas-codigo',
                Icons.keyboard_outlined,
              );
              final escala = MediaQuery.textScalerOf(context).scale(12) / 12;
              return compacto && c.maxWidth / escala >= 200
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: camara),
                          const SizedBox(width: 8),
                          Expanded(child: lector),
                        ],
                      ),
                      const SizedBox(height: 8),
                      codigo,
                    ],
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      camara,
                      const SizedBox(height: 8),
                      lector,
                      const SizedBox(height: 8),
                      codigo,
                    ],
                  );
            },
          ),
        ],
      ),
      key: const ValueKey('despacho-prendas-escaneo'),
    );

    final seleccion = tarjeta(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Selección',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _navy,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'OP elegidas',
                  style: TextStyle(fontSize: 12, color: AppColors.slate600),
                ),
              ),
              Text(
                '${_ops.length}',
                key: const ValueKey('despacho-prendas-resumen-cantidad'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
            ],
          ),
          const Divider(height: 16, color: AppColors.cardBorder),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Siguiente',
                style: TextStyle(fontSize: 12, color: AppColors.slate600),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Armar empaques',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _navy,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      key: const ValueKey('despacho-prendas-seleccion'),
    );

    Widget titulo() => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Qué OP van en este despacho?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$_cliente · Solo aparecen prendas disponibles en bodega. Se empaca una OC a la vez.',
            style: const TextStyle(fontSize: 12, color: AppColors.slate600),
          ),
        ],
      ),
    );
    Widget listado() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final oc in ocs) tarjetaOc(oc),
        if (ocs.isEmpty)
          tarjeta(const Text('No hay prendas disponibles para este cliente.')),
      ],
    );
    return LayoutBuilder(
      builder: (context, c) {
        final escala = MediaQuery.textScalerOf(context).scale(12) / 12;
        return c.maxWidth >= 850 * escala
            ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [titulo(), listado()],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 300,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      panelEscaneo(compacto: false),
                      const SizedBox(height: 14),
                      seleccion,
                    ],
                  ),
                ),
              ],
            )
            : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titulo(),
                panelEscaneo(compacto: true),
                const SizedBox(height: 12),
                seleccion,
                const SizedBox(height: 12),
                listado(),
              ],
            );
      },
    );
  }

  Widget _revision() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _titulo(
        'Revisa antes de confirmar',
        'Si algo no cuadra, vuelve al paso que corresponda. Nada se ha guardado todavía.',
      ),
      Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final dato in [
            ('Destinatario', _nombreDestino),
            ('Cliente', _cliente ?? ''),
            ('Orden de compra', _ocVisible),
            ('Se reserva en bodega', '$_cantidadTotal prendas'),
          ])
            SizedBox(
              width: 220,
              child: _panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dato.$1, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      dato.$2,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      Row(
        children: [
          Expanded(
            child: Text(
              '${_bultos.length} empaques',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed:
                _ocupado || _pendiente != null
                    ? null
                    : () => setState(() {
                      _paso = 2;
                      _planRevisado = null;
                    }),
            child: const Text('Editar empaques'),
          ),
        ],
      ),
      for (final b in _bultos.entries)
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Empaque ${_numeros[b.key]} · ${descripcionEmpaque(ref.read(empaquesProvider).valueOrNull?.where((c) => c['id'] == b.value).firstOrNull ?? {'nombre': 'Empaque'})}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(_resumenPeso(b.key, b.value)),
              for (final i in _lineas.where(
                (i) =>
                    _ops.contains(i.item.op) &&
                    _asignaciones[i.id]?[b.key] != null,
              ))
                Text(
                  'OP ${i.item.op} · Talla ${i.item.talla} · ${_asignaciones[i.id]![b.key]!.prendas} prendas',
                ),
              Text(
                _rotuloPendiente(b.key)
                    ? 'Rótulo modificado: vuelve a generarlo'
                    : _rotulosGenerados.containsKey(b.key)
                    ? 'Rótulo generado'
                    : 'Rótulo sin generar',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      if (_planRevisado != null)
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estantes de origen',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              for (final l in _planRevisado!)
                Text(
                  'OP ${l['op']} · Talla ${l['talla']} · ${l['cantidad']} desde ${l['ubicacion']}',
                ),
            ],
          ),
        ),
      if (widget.correccion != null)
        TextField(
          controller: _motivoCorreccion,
          decoration: const InputDecoration(
            labelText: 'Motivo de la corrección (obligatorio)',
          ),
        ),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xfffff4dd),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Al confirmar, las prendas quedan reservadas y se crea la LE. La salida física se registra después en Seguimiento, cuando el transportador recoja.',
        ),
      ),
    ],
  );
  Widget _resultado(BuildContext tabContext) => Center(
    child: SingleChildScrollView(
      child: Column(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xffe5f3eb),
            child: Icon(Icons.check, color: _green, size: 34),
          ),
          const SizedBox(height: 16),
          const Text(
            'Empaque confirmado',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Las $_confirmadas prendas quedaron reservadas en $_bultosConfirmados empaques. La LE aparece en Seguimiento para registrar la salida.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _panel(Text('$_ocVisible · $_nombreDestino')),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (_inventario == null)
                OutlinedButton(
                  onPressed:
                      () => setState(() {
                        _limpiar();
                        _exito = false;
                        _paso = 0;
                        _planRevisado = null;
                        _oc = null;
                      }),
                  child: const Text('Empacar otra OC'),
                ),
              if (_puedeSeguimiento)
                FilledButton(
                  onPressed:
                      () => DefaultTabController.of(tabContext).animateTo(1),
                  child: const Text('Ir a Seguimiento'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
  Widget _contenidoTabs(BuildContext context, List<Widget> paginas) {
    final controller = DefaultTabController.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder:
          (_, __) => IndexedStack(index: controller.index, children: paginas),
    );
  }

  @override
  Widget build(BuildContext context) {
    // El catálogo autoDispose debe seguir observado al ocultar el paso Destino.
    // Los rótulos y la confirmación necesitan sus datos y su versión hasta cerrar.
    ref.watch(destinatariosEmpaqueProvider);
    ref.watch(usuarioSesionProvider);
    final puedeSeguimiento = _puedeSeguimiento;
    final estado = ref.watch(wmsSnapshotProvider);
    final congelado =
        _cargandoBorrador ||
        _guardandoBorrador ||
        _errorBorrador ||
        _ocupado ||
        _preparando ||
        _generandoRotulo ||
        _sincronizandoDatos ||
        _pendiente != null;
    return PopScope(
      canPop: _permitirSalida,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cerrar();
      },
      child: WmsDialogShell(
        canClose:
            !_cargandoBorrador &&
            !_guardandoBorrador &&
            !_ocupado &&
            !_preparando &&
            !_generandoRotulo &&
            !_sincronizandoDatos &&
            _pendiente == null,
        onClose: _cerrar,
        mobileCatalog: true,
        compactHeader: true,
        fullscreen: _pantallaCompleta,
        onToggleFullscreen:
            () => setState(() => _pantallaCompleta = !_pantallaCompleta),
        expand: true,
        maxWidth: 1100,
        title:
            _inventario != null
                ? 'Despacho desde inventario'
                : widget.correccion == null
                ? 'Despachos por orden de compra'
                : 'Corregir despacho · LE ${widget.correccion!['le_numero'] ?? ''}',
        subtitle: 'Empaca: ${ref.watch(nombreOperarioProvider)}',
        icon: Icons.local_shipping_outlined,
        iconColor: _navy,
        child: DefaultTabController(
          key: ValueKey(puedeSeguimiento),
          length: puedeSeguimiento ? 4 : 2,
          initialIndex:
              widget.correccion == null &&
                      ref.watch(usarSupabaseProvider) &&
                      ref.watch(usuarioSesionProvider).valueOrNull?.rolCuenta ==
                          RolCuenta.seguimiento
                  ? 1
                  : 0,
          child: Builder(
            builder:
                (tabContext) => Column(
                  children: [
                    TabBar(
                      indicator: const UnderlineTabIndicator(
                        borderSide: BorderSide(color: AppColors.lima, width: 3),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: _navy,
                      unselectedLabelColor: Colors.blueGrey,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                      tabs: [
                        const Tab(text: 'Despacho', height: 40),
                        if (puedeSeguimiento)
                          const Tab(text: 'Seguimiento', height: 40),
                        if (puedeSeguimiento)
                          const Tab(text: 'Facturación', height: 40),
                        const Tab(text: 'Historial', height: 40),
                      ],
                    ),
                    Expanded(
                      child: _contenidoTabs(tabContext, [
                        _exito
                            ? _resultado(tabContext)
                            : Column(
                              children: [
                                if (estado.isLoading ||
                                    _ocupado ||
                                    _preparando ||
                                    _cargandoBorrador ||
                                    _guardandoBorrador)
                                  const WmsLoadingStrip(),
                                Expanded(
                                  child: ColoredBox(
                                    color:
                                        _paso <= 1 && _inventario == null
                                            ? _soft
                                            : Colors.white,
                                    child: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          ColoredBox(
                                            color: Colors.white,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                _sincronizarEnDialogo(),
                                                _pasos(),
                                              ],
                                            ),
                                          ),
                                          ColoredBox(
                                            color:
                                                _paso <= 1 &&
                                                        _inventario == null
                                                    ? _soft
                                                    : Colors.white,
                                            child: AbsorbPointer(
                                              absorbing:
                                                  _cargandoBorrador ||
                                                  _guardandoBorrador ||
                                                  _errorBorrador,
                                              child: Padding(
                                                padding: EdgeInsets.symmetric(
                                                  vertical:
                                                      _paso <= 1 ? 12 : 18,
                                                  horizontal:
                                                      _paso <= 1 &&
                                                              _inventario ==
                                                                  null
                                                          ? 12
                                                          : 0,
                                                ),
                                                child:
                                                    _paso == 0
                                                        ? _destinoPaso(
                                                          congelado,
                                                        )
                                                        : _paso == 1
                                                        ? _prendasPaso(
                                                          congelado,
                                                        )
                                                        : _paso == 2
                                                        ? Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .stretch,
                                                          children: [
                                                            _cabeceraEmpaque(),
                                                            const SizedBox(
                                                              height: 12,
                                                            ),
                                                            _detalleSeleccion(
                                                              congelado,
                                                            ),
                                                          ],
                                                        )
                                                        : _revision(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 8,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    border: Border(
                                      top: BorderSide(color: Color(0xffdce6eb)),
                                    ),
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, c) {
                                      final siguiente = FilledButton.icon(
                                        iconAlignment:
                                            _paso <= 1
                                                ? IconAlignment.end
                                                : IconAlignment.start,
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              _paso == 3 ? _green : _navy,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed:
                                            _cargandoBorrador ||
                                                    _guardandoBorrador ||
                                                    _errorBorrador ||
                                                    _sincronizandoDatos ||
                                                    _ocupado ||
                                                    _preparando ||
                                                    _generandoRotulo ||
                                                    (_paso == 0 &&
                                                        (_cliente == null ||
                                                            _faltaDestino ||
                                                            (_inventario !=
                                                                    null &&
                                                                _ocVisible
                                                                    .isEmpty))) ||
                                                    (_paso == 1 &&
                                                        _ops.isEmpty) ||
                                                    (_paso == 2 &&
                                                        _pendienteEmpaque !=
                                                            null)
                                                ? null
                                                : () {
                                                  if (_paso >= 2) {
                                                    _preparar();
                                                  } else {
                                                    setState(() => _paso++);
                                                  }
                                                },
                                        icon: Icon(
                                          _paso == 3
                                              ? Icons.check_circle_outline
                                              : Icons.arrow_forward,
                                          size: 18,
                                        ),
                                        label: Text(
                                          _ocupado
                                              ? 'Guardando…'
                                              : _pendiente != null
                                              ? 'Reintentar mismo despacho'
                                              : [
                                                'Elegir prendas',
                                                'Armar empaques',
                                                'Revisar empaque',
                                                'Confirmar empaque',
                                              ][_paso],
                                        ),
                                      );
                                      final cancelar = OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                        ),
                                        onPressed: congelado ? null : _cerrar,
                                        child: const Text('Cancelar'),
                                      );
                                      final atras = OutlinedButton.icon(
                                        style:
                                            _paso == 1
                                                ? OutlinedButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  foregroundColor:
                                                      AppColors.petroleo,
                                                  minimumSize: const Size(
                                                    0,
                                                    44,
                                                  ),
                                                )
                                                : null,
                                        onPressed:
                                            congelado || _paso == 0
                                                ? null
                                                : () => setState(() {
                                                  _paso--;
                                                  _planRevisado = null;
                                                }),
                                        icon: const Icon(
                                          Icons.arrow_back,
                                          size: 16,
                                        ),
                                        label: const Text('Atrás'),
                                      );
                                      final resumen = Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            _paso == 0
                                                ? CrossAxisAlignment.start
                                                : CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            _paso == 0
                                                ? 'Paso 1 de 4 · Destino'
                                                : _paso == 1
                                                ? '${_ops.length} OP elegidas'
                                                : '$_cantidadTotal prendas · ${_bultos.length} empaques',
                                            textAlign:
                                                _paso == 0
                                                    ? TextAlign.left
                                                    : TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (_paso == 2 &&
                                              _pendienteEmpaque != null)
                                            Text(
                                              _pendienteEmpaque!,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xff9a6700),
                                              ),
                                            ),
                                        ],
                                      );
                                      return c.maxWidth < 550
                                          ? Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              resumen,
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  if (_paso > 0) ...[
                                                    atras,
                                                    const SizedBox(width: 8),
                                                  ],
                                                  if (_paso == 0) ...[
                                                    cancelar,
                                                    const SizedBox(width: 8),
                                                  ],
                                                  Expanded(child: siguiente),
                                                ],
                                              ),
                                            ],
                                          )
                                          : Row(
                                            children: [
                                              if (_paso > 0) atras,
                                              Expanded(child: resumen),
                                              if (_paso == 0) ...[
                                                cancelar,
                                                const SizedBox(width: 12),
                                              ],
                                              siguiente,
                                            ],
                                          );
                                    },
                                  ),
                                ),
                              ],
                            ),
                        if (puedeSeguimiento)
                          const SeguimientoPanel(
                            pendientes: _Historial(seguimiento: true),
                          ),
                        if (puedeSeguimiento) const FacturacionPanel(),
                        const _Historial(),
                      ]),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}

class _Historial extends ConsumerStatefulWidget {
  const _Historial({this.seguimiento = false});
  final bool seguimiento;
  @override
  ConsumerState<_Historial> createState() => _HistorialState();
}

class _HistorialState extends ConsumerState<_Historial> {
  bool _abriendoCorreccion = false;
  Future<void> _corregir(String id) async {
    if (_abriendoCorreccion) return;
    setState(() => _abriendoCorreccion = true);
    try {
      final d = await ref.read(despachosOcProvider)!.prepararCorreccion(id);
      await ref.read(wmsRepositoryProvider).refrescar();
      if (!mounted) return;
      await showWmsDialog<void>(context, (_) => DespachoDialog(correccion: d));
      ref.invalidate(historialDespachosProvider);
      ref.invalidate(entregasProvider);
    } catch (e) {
      if (mounted) {
        mostrarAvisoSnack(
          context,
          SnackBar(
            content: Text(
              e is PostgrestException
                  ? e.message
                  : 'No se pudo abrir la corrección. $e',
            ),
          ),
          tipo: TipoAviso.error,
        );
      }
    } finally {
      if (mounted) setState(() => _abriendoCorreccion = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conectado = ref.watch(usarSupabaseProvider);
    final puedeSeguimiento =
        ref.watch(usuarioSesionProvider).valueOrNull?.puedeSeguimiento ?? false;
    final puedeVerEntregas = !conectado || puedeSeguimiento;
    // Despacho conserva el historial sin consultar una RPC restringida.
    final entregas =
        puedeVerEntregas ? ref.watch(entregasProvider).valueOrNull : null;
    return ref
        .watch(historialDespachosProvider)
        .when(
          loading: () => const WmsLoadingPanel(),
          error:
              (_, __) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(historialDespachosProvider),
                  child: const Text('No se pudo cargar. Reintentar'),
                ),
              ),
          data:
              (todas) => HistorialDespachosVista(
                filas:
                    todas
                        .where(
                          (f) => !widget.seguimiento || f['fase'] == 'empacado',
                        )
                        .toList(),
                entregas: entregas,
                mostrarEntregadas: puedeVerEntregas,
                onActualizar: () => ref.invalidate(historialDespachosProvider),
                pendientes: widget.seguimiento,
                ocupado: _abriendoCorreccion,
                onCorregir: conectado ? _corregir : null,
                onDocumento:
                    conectado ? (id) => mostrarListaEmpaque(context, id) : null,
              ),
        );
  }
}
