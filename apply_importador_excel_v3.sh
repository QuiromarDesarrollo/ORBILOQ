#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Agrega el importador de Excel de Ordenes de Produccion (v3)
# Ejecutar DESDE LA RAIZ del repo (donde esta pubspec.yaml):
#   bash apply_importador_excel_v3.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi

echo "Aplicando cambios del importador de Excel..."

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
ORBILOQ_EOF

echo "  - lib/main.dart"
mkdir -p "$(dirname 'lib/main.dart')"
cat > 'lib/main.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'application/providers.dart';
import 'data/in_memory_wms_repository.dart';
import 'data/supabase_importador_ordenes.dart';
import 'data/supabase_wms_repository.dart';

/// Credenciales de Supabase, pasadas al compilar con:
///   flutter run -d chrome \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=sb_publishable_xxxx
///
/// Si no se pasan (quedan vacías), la app arranca con datos de prueba en
/// memoria — útil para desarrollar la interfaz sin depender de la base real.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final usarSupabase = _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

  if (usarSupabase) {
    await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
  }

  runApp(
    ProviderScope(
      overrides: [
        wmsRepositoryProvider.overrideWith((ref) {
          if (usarSupabase) {
            final repo = SupabaseWmsRepository(Supabase.instance.client);
            ref.onDispose(repo.dispose);
            return repo;
          }
          final repo = InMemoryWmsRepository.seeded();
          ref.onDispose(repo.dispose);
          return repo;
        }),
        importadorOrdenesProvider.overrideWith((ref) {
          if (!usarSupabase) return null;
          return SupabaseImportadorOrdenes(Supabase.instance.client);
        }),
      ],
      child: const OrbiloqWmsApp(),
    ),
  );
}
ORBILOQ_EOF

echo "  - lib/application/providers.dart"
mkdir -p "$(dirname 'lib/application/providers.dart')"
cat > 'lib/application/providers.dart' << 'ORBILOQ_EOF'
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/fecha.dart';
import '../data/supabase_importador_ordenes.dart';
import '../domain/models.dart';
import '../domain/wms_repository.dart';
import 'kardex_filters.dart';

/// Debe sobrescribirse en `main.dart` (o en tests) con la implementación deseada.
final wmsRepositoryProvider = Provider<WmsRepository>(
  (ref) => throw UnimplementedError('Sobrescribe wmsRepositoryProvider en main.dart'),
);

/// Solo disponible cuando la app corre contra Supabase; `null` en modo memoria
/// (la importación de Excel no tiene sentido sin una base de datos real detrás).
final importadorOrdenesProvider = Provider<SupabaseImportadorOrdenes?>((ref) => null);

final wmsSnapshotProvider = StreamProvider<WmsSnapshot>(
  (ref) => ref.watch(wmsRepositoryProvider).watch(),
);

final kardexProvider = Provider<List<ItemKardex>>(
  (ref) => ref.watch(wmsSnapshotProvider).value?.kardex ?? const <ItemKardex>[],
);

// ------------------------------------------------------------------- rol

class RolNotifier extends Notifier<Rol> {
  @override
  Rol build() => Rol.produccion;

  void cambiar(Rol rol) {
    if (rol == state) return;
    state = rol;
    // La fecha filtrada depende del perfil (entrega vs recepción).
    ref.read(kardexFiltersProvider.notifier).limpiarFechas();
  }
}

final rolProvider = NotifierProvider<RolNotifier, Rol>(RolNotifier.new);

// --------------------------------------------------------------- filtros

class KardexFiltersNotifier extends Notifier<KardexFilters> {
  @override
  KardexFilters build() => const KardexFilters();

  void setOps(Set<String> v) => state = state.copyWith(ops: v);
  void setOcs(Set<String> v) => state = state.copyWith(ocs: v);
  void setClientes(Set<String> v) => state = state.copyWith(clientes: v);
  void setFechas(Set<DateTime> v) => state = state.copyWith(fechas: v);
  void limpiarFechas() => state = state.copyWith(fechas: const {});
  void limpiar() => state = const KardexFilters();
}

final kardexFiltersProvider =
    NotifierProvider<KardexFiltersNotifier, KardexFilters>(KardexFiltersNotifier.new);

final kardexFiltradoProvider = Provider<List<ItemKardex>>((ref) {
  final kardex = ref.watch(kardexProvider);
  final filtros = ref.watch(kardexFiltersProvider);
  final rol = ref.watch(rolProvider);
  if (!filtros.hayFiltros) return kardex;
  return kardex.where((i) => filtros.aplica(i, rol)).toList(growable: false);
});

final opcionesFiltroProvider = Provider<OpcionesFiltro>((ref) {
  final kardex = ref.watch(kardexProvider);
  final rol = ref.watch(rolProvider);

  List<String> unicos(String Function(ItemKardex) f) => (kardex.map(f).toSet().toList()..sort());

  final fechas = kardex
      .map((i) => fechaSegunRol(i, rol))
      .whereType<DateTime>()
      .map(soloFecha)
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a));

  return OpcionesFiltro(
    ops: unicos((i) => i.item.op),
    ocs: unicos((i) => i.item.oc),
    clientes: unicos((i) => i.item.cliente),
    fechas: fechas,
  );
});
ORBILOQ_EOF

echo "  - lib/domain/importacion_result.dart"
mkdir -p "$(dirname 'lib/domain/importacion_result.dart')"
cat > 'lib/domain/importacion_result.dart' << 'ORBILOQ_EOF'
/// Resultado de una carga de Excel (Órdenes de Producción u otro tipo futuro).
class ResumenImportacion {
  const ResumenImportacion({
    required this.opsCreadas,
    required this.opsOmitidas,
    required this.filasConAdvertencia,
    required this.filasConError,
    required this.detalles,
  });

  final int opsCreadas;
  final int opsOmitidas;
  final int filasConAdvertencia;
  final int filasConError;

  /// Mensajes descriptivos de advertencias/errores, ya listos para mostrar.
  final List<String> detalles;

  bool get tuvoProblemas => filasConAdvertencia > 0 || filasConError > 0;

  factory ResumenImportacion.fromJson(Map<String, dynamic> json) {
    final detalleErrores = (json['detalle_errores'] as List?) ?? const [];
    return ResumenImportacion(
      opsCreadas: (json['ops_creadas'] as num?)?.toInt() ?? 0,
      opsOmitidas: (json['ops_omitidas'] as num?)?.toInt() ?? 0,
      filasConAdvertencia: (json['filas_con_advertencia'] as num?)?.toInt() ?? 0,
      filasConError: (json['filas_con_error'] as num?)?.toInt() ?? 0,
      detalles: [
        for (final d in detalleErrores)
          if (d is Map && d['motivo'] != null) '${d['hoja'] ?? ''}: ${d['motivo']}'.trim(),
      ],
    );
  }
}
ORBILOQ_EOF

echo "  - lib/data/excel_ordenes_parser.dart"
mkdir -p "$(dirname 'lib/data/excel_ordenes_parser.dart')"
cat > 'lib/data/excel_ordenes_parser.dart' << 'ORBILOQ_EOF'
import 'dart:typed_data';

import 'package:excel/excel.dart';

/// Fila ya interpretada de la hoja "Orden" (una por Orden de Producción).
typedef FilaOrden = Map<String, String?>;

/// Fila ya interpretada de la hoja "Tallas" (una por OP + código + talla).
typedef FilaTalla = Map<String, String?>;

class ExcelOrdenesParseException implements Exception {
  ExcelOrdenesParseException(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

class ExcelOrdenesParseado {
  const ExcelOrdenesParseado({required this.ordenes, required this.tallas});
  final List<FilaOrden> ordenes;
  final List<FilaTalla> tallas;
}

/// Nombres de columna esperados en cada hoja -> clave interna que usa el RPC.
/// Se busca por nombre de encabezado (no por posición), para tolerar que el
/// Excel del ERP cambie el orden de las columnas entre exportaciones.
const _columnasOrden = <String, String>{
  'Identificador': 'identificador',
  'Tipo de orden': 'tipo_orden',
  'Estado': 'estado',
  'Fecha solicitud': 'fecha_solicitud',
  'Fecha inicio': 'fecha_inicio',
  'Fecha comprometida': 'fecha_comprometida',
  'Fecha acordada': 'fecha_acordada',
  'Fecha entrega': 'fecha_entrega',
  'Fecha planeación': 'fecha_planeacion',
  'Nombre ficha técnica': 'nombre_ficha_tecnica',
  'Cliente': 'cliente',
  'No. OC': 'oc_cabecera',
  'Nombre prenda': 'nombre_prenda_resumen',
  'Cantidad': 'cantidad_total_erp',
  'Observaciones': 'observaciones',
  'Movimiento': 'etapa_movimiento',
  'Fecha inicio movimiento': 'fecha_inicio_movimiento',
  'Fecha planeada': 'fecha_planeada_movimiento',
  'Estado movimientos': 'estado_movimiento_erp',
  'Id. OC': 'oc_id_erp',
};

const _columnasTallas = <String, String>{
  'Identificador orden': 'identificador_orden',
  'CLIENTE': 'cliente',
  'Código': 'codigo',
  'Descripción': 'descripcion',
  'Tallas nombre': 'talla',
  'Cantidad': 'cantidad',
  'NO. OC': 'oc',
  'OC ID': 'oc_id_erp',
  'OBSERVACION': 'observacion',
};

/// Lee el archivo (bytes de un .xlsx) y devuelve las filas de ambas hojas ya
/// mapeadas a claves consistentes. Lanza [ExcelOrdenesParseException] con un
/// mensaje entendible si el archivo no tiene el formato esperado.
class ExcelOrdenesParser {
  static ExcelOrdenesParseado parsear(Uint8List bytes) {
    late final Excel libro;
    try {
      libro = Excel.decodeBytes(bytes);
    } catch (_) {
      throw ExcelOrdenesParseException(
        'No se pudo leer el archivo. Verifica que sea un .xlsx válido '
        '(si el original es .xls, ábrelo en Excel y usa "Guardar como" → .xlsx).',
      );
    }

    final nombreHojaOrden = _buscarHoja(libro, 'Orden');
    final nombreHojaTallas = _buscarHoja(libro, 'Tallas');
    if (nombreHojaOrden == null || nombreHojaTallas == null) {
      throw ExcelOrdenesParseException(
        'El archivo debe tener las hojas "Orden" y "Tallas". '
        'Hojas encontradas: ${libro.tables.keys.join(", ")}',
      );
    }

    final ordenes = _leerHoja(libro.tables[nombreHojaOrden]!, _columnasOrden);
    final tallas = _leerHoja(libro.tables[nombreHojaTallas]!, _columnasTallas);

    if (ordenes.isEmpty) {
      throw ExcelOrdenesParseException('La hoja "Orden" no tiene filas de datos.');
    }

    return ExcelOrdenesParseado(ordenes: ordenes, tallas: tallas);
  }

  static String? _buscarHoja(Excel libro, String nombreAproximado) {
    for (final nombre in libro.tables.keys) {
      if (nombre.trim().toLowerCase() == nombreAproximado.toLowerCase()) return nombre;
    }
    return null;
  }

  static List<Map<String, String?>> _leerHoja(Sheet hoja, Map<String, String> columnas) {
    if (hoja.maxRows == 0) return const [];

    final encabezados = hoja.rows.first;
    final indicePorClave = <String, int>{};
    for (var i = 0; i < encabezados.length; i++) {
      final texto = _texto(encabezados[i]?.value)?.trim();
      if (texto == null) continue;
      final clave = columnas[texto];
      if (clave != null) indicePorClave[clave] = i;
    }

    final filas = <Map<String, String?>>[];
    for (var f = 1; f < hoja.rows.length; f++) {
      final fila = hoja.rows[f];
      // Saltar filas completamente vacías.
      final vacia = fila.every((c) => _texto(c?.value)?.trim().isEmpty ?? true);
      if (vacia) continue;

      final mapa = <String, String?>{};
      for (final entrada in indicePorClave.entries) {
        final idx = entrada.value;
        final celda = idx < fila.length ? fila[idx]?.value : null;
        mapa[entrada.key] = _valorParaColumna(entrada.key, celda);
      }
      filas.add(mapa);
    }
    return filas;
  }

  /// Fechas se devuelven como texto ISO (yyyy-MM-dd) para que Postgres las
  /// pueda castear directo con `::date`. El resto de columnas, como texto.
  static String? _valorParaColumna(String clave, CellValue? valor) {
    if (clave.startsWith('fecha')) return _fechaIso(valor);
    return _texto(valor)?.trim();
  }

  static String? _texto(CellValue? valor) {
    if (valor == null) return null;
    try {
      return switch (valor) {
        TextCellValue v => v.value.toString(),
        IntCellValue v => v.value.toString(),
        DoubleCellValue v => v.value.toString(),
        BoolCellValue v => v.value.toString(),
        _ => valor.toString(),
      };
    } catch (_) {
      return valor.toString();
    }
  }

  static String? _fechaIso(CellValue? valor) {
    if (valor == null) return null;
    try {
      DateTime? dt;
      if (valor is DateCellValue) {
        dt = DateTime(valor.year, valor.month, valor.day);
      } else if (valor is DateTimeCellValue) {
        dt = DateTime(valor.year, valor.month, valor.day, valor.hour, valor.minute, valor.second);
      }
      if (dt != null) {
        final y = dt.year.toString().padLeft(4, '0');
        final m = dt.month.toString().padLeft(2, '0');
        final d = dt.day.toString().padLeft(2, '0');
        return '$y-$m-$d';
      }
    } catch (_) {
      // sigue abajo e intenta interpretar como texto
    }
    // Último recurso: si viene como texto tipo "2026-07-08 00:00:00".
    final texto = _texto(valor)?.trim();
    if (texto == null || texto.isEmpty) return null;
    final parseada = DateTime.tryParse(texto);
    if (parseada == null) return null;
    final y = parseada.year.toString().padLeft(4, '0');
    final m = parseada.month.toString().padLeft(2, '0');
    final d = parseada.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
ORBILOQ_EOF

echo "  - lib/data/supabase_importador_ordenes.dart"
mkdir -p "$(dirname 'lib/data/supabase_importador_ordenes.dart')"
cat > 'lib/data/supabase_importador_ordenes.dart' << 'ORBILOQ_EOF'
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/result.dart';
import '../domain/importacion_result.dart';
import 'excel_ordenes_parser.dart';

/// Orquesta la carga de un Excel de Órdenes de Producción:
/// 1) valida y parsea el archivo en el dispositivo,
/// 2) archiva el archivo original en Storage,
/// 3) delega toda la lógica de inserción (insert-only) al RPC de Postgres,
///    que corre en una sola transacción.
class SupabaseImportadorOrdenes {
  SupabaseImportadorOrdenes(this._client);

  final SupabaseClient _client;

  Future<Result<ResumenImportacion>> importar({
    required Uint8List bytes,
    required String nombreArchivo,
    required String usuarioNombre,
  }) async {
    final ExcelOrdenesParseado parseado;
    try {
      parseado = ExcelOrdenesParser.parsear(bytes);
    } on ExcelOrdenesParseException catch (e) {
      return Err<ResumenImportacion>(e.mensaje);
    } catch (e) {
      return Err<ResumenImportacion>('No se pudo interpretar el archivo: $e');
    }

    final storagePath = _rutaStorage(nombreArchivo);

    try {
      await _client.storage.from('documentos').uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ),
          );
    } on StorageException catch (e) {
      return Err<ResumenImportacion>('No se pudo archivar el Excel original: ${e.message}');
    }

    try {
      final res = await _client.rpc('importar_ordenes_produccion', params: {
        'p_ordenes': parseado.ordenes,
        'p_tallas': parseado.tallas,
        'p_nombre_archivo': nombreArchivo,
        'p_storage_path': storagePath,
        'p_usuario_nombre': usuarioNombre,
      });
      return Ok<ResumenImportacion>(ResumenImportacion.fromJson(res as Map<String, dynamic>));
    } on PostgrestException catch (e) {
      return Err<ResumenImportacion>('Error al importar: ${e.message}');
    } catch (e) {
      return Err<ResumenImportacion>('Error inesperado al importar: $e');
    }
  }

  String _rutaStorage(String nombreArchivo) {
    final sello = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final limpio = nombreArchivo.replaceAll(RegExp(r'[^\w\.\-]'), '_');
    return 'importaciones/$sello-$limpio';
  }
}
ORBILOQ_EOF

echo "  - lib/features/importacion/presentation/importar_ordenes_dialog.dart"
mkdir -p "$(dirname 'lib/features/importacion/presentation/importar_ordenes_dialog.dart')"
cat > 'lib/features/importacion/presentation/importar_ordenes_dialog.dart' << 'ORBILOQ_EOF'
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/importacion_result.dart';
import '../../../shared/widgets/action_button.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showImportarOrdenesDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const ImportarOrdenesDialog());

class ImportarOrdenesDialog extends ConsumerStatefulWidget {
  const ImportarOrdenesDialog({super.key});

  @override
  ConsumerState<ImportarOrdenesDialog> createState() => _ImportarOrdenesDialogState();
}

class _ImportarOrdenesDialogState extends ConsumerState<ImportarOrdenesDialog> {
  PlatformFile? _archivo;
  bool _cargando = false;
  FeedbackMessage? _msg;
  ResumenImportacion? _resumen;

  Future<void> _elegirArchivo() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (resultado == null || resultado.files.isEmpty) return;
    setState(() {
      _archivo = resultado.files.single;
      _msg = null;
      _resumen = null;
    });
  }

  Future<void> _importar() async {
    final archivo = _archivo;
    final bytes = archivo?.bytes;
    if (archivo == null || bytes == null) return;

    final importador = ref.read(importadorOrdenesProvider);
    if (importador == null) {
      setState(() => _msg = const FeedbackMessage.error(
            'Esta función necesita conexión a Supabase (la app está en modo de datos de prueba).',
          ));
      return;
    }

    setState(() {
      _cargando = true;
      _msg = null;
      _resumen = null;
    });

    final res = await importador.importar(
      bytes: bytes,
      nombreArchivo: archivo.name,
      usuarioNombre: 'Operario Confección 1', // TODO: usuario real cuando exista login
    );

    if (!mounted) return;
    setState(() {
      _cargando = false;
      switch (res) {
        case Ok(:final value):
          _resumen = value;
          _msg = FeedbackMessage.ok(
            '${value.opsCreadas} OP nuevas creadas · ${value.opsOmitidas} ya existían (omitidas)'
            '${value.tuvoProblemas ? ' · revisa los detalles abajo' : ''}.',
          );
        case Err(:final message):
          _msg = FeedbackMessage.error(message);
      }
    });

    if (res is Ok<ResumenImportacion>) {
      // Refresca el kardex para que las OP recién creadas aparezcan de una vez.
      await ref.read(wmsRepositoryProvider).refrescar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final disponible = ref.watch(importadorOrdenesProvider) != null;

    return WmsDialogShell(
      title: 'IMPORTAR ÓRDENES DE PRODUCCIÓN',
      icon: Icons.upload_file,
      iconColor: AppColors.primaryNavy,
      maxWidth: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!disponible)
            const FeedbackBanner(
              message: FeedbackMessage.error(
                'Esta función necesita conexión a Supabase. Ahora mismo la app está '
                'usando datos de prueba en memoria.',
              ),
            )
          else ...[
            const Text(
              'Sube el Excel exportado del ERP en formato .xlsx (hojas "Orden" y '
              '"Tallas"). Las Órdenes de Producción que ya existan en el sistema se '
              'omiten automáticamente — nunca se sobrescriben.',
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _cargando ? null : _elegirArchivo,
                    icon: const Icon(Icons.attach_file),
                    label: Text(_archivo?.name ?? 'Seleccionar archivo .xlsx'),
                  ),
                ),
                const SizedBox(width: 10),
                ActionButton(
                  icon: Icons.cloud_upload,
                  label: 'IMPORTAR',
                  color: AppColors.actionGreen,
                  busy: _cargando,
                  onPressed: _archivo == null ? null : _importar,
                ),
              ],
            ),
            if (_msg != null) ...[
              const SizedBox(height: 16),
              FeedbackBanner(message: _msg!),
            ],
            if (_resumen != null && _resumen!.detalles.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Detalle (${_resumen!.filasConAdvertencia} advertencias, '
                '${_resumen!.filasConError} errores):',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _resumen!.detalles.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• ${_resumen!.detalles[i]}', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ),
            ],
          ],
        ],
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

import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/action_button.dart';
import '../../despacho/presentation/despacho_dialog.dart';
import '../../importacion/presentation/importar_ordenes_dialog.dart';
import '../../produccion/presentation/entrega_produccion_dialog.dart';
import '../../recepcion/presentation/recepcion_dialog.dart';
import '../../ubicaciones/presentation/ubicaciones_dialog.dart';
import 'kardex_filters_bar.dart';
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
    final filas = ref.watch(kardexFiltradoProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
        elevation: 2,
        titleSpacing: 12,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.public, color: AppColors.primaryNavy, size: 22),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'ORBILOQ WMS - KARDEX MAESTRO Y CONTROL BODEGA',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: AppColors.secondaryNavy, borderRadius: BorderRadius.circular(20)),
            child: DropdownButton<Rol>(
              value: rol,
              dropdownColor: AppColors.secondaryNavy,
              underline: const SizedBox(),
              icon: const Icon(Icons.switch_account, color: AppColors.accentCyan),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              items: [
                for (final r in Rol.values)
                  DropdownMenuItem(value: r, child: Text('Perfil: ${r.etiqueta}')),
              ],
              onChanged: (r) {
                if (r != null) ref.read(rolProvider.notifier).cambiar(r);
              },
            ),
          ),
          const SizedBox(width: 12),
          ActionButton(
            icon: Icons.upload_file,
            label: 'IMPORTAR EXCEL',
            color: Colors.indigo.shade700,
            onPressed: () => showImportarOrdenesDialog(context),
          ),
          const SizedBox(width: 12),
          ActionButton(
            icon: Icons.sync,
            label: _sincronizando ? 'SINCRONIZANDO...' : 'SINCRONIZAR BD',
            color: AppColors.accentCyan,
            busy: _sincronizando,
            onPressed: _sincronizar,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error cargando datos: $e')),
        data: (s) => Column(
          children: [
            _BarraAcciones(rol: rol, enTransito: s.remisionesEnTransito),
            const KardexFiltersBar(),
            Expanded(child: KardexTable(rows: filas, rol: rol)),
          ],
        ),
      ),
    );
  }
}

class _BarraAcciones extends ConsumerWidget {
  const _BarraAcciones({required this.rol, required this.enTransito});

  final Rol rol;
  final int enTransito;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: AppColors.secondaryNavy,
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (rol == Rol.produccion) ...[
            ActionButton(
              icon: Icons.send_and_archive,
              label: 'ENTREGAR LOTE & VER HISTORIAL',
              color: AppColors.actionGreen,
              onPressed: () => showEntregaProduccionDialog(context),
            ),
            const Text(
              'Modo Producción: límite estricto por OP, control de faltantes e historial de remisiones.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ] else ...[
            ActionButton(
              icon: Icons.move_to_inbox,
              label: '1. RECIBIR Y REPORTAR NOVEDADES ($enTransito)',
              color: AppColors.actionGreen,
              onPressed: () => showRecepcionDialog(context),
            ),
            ActionButton(
              icon: Icons.local_shipping,
              label: '2. DESPACHO POR ORDEN',
              color: AppColors.actionOrange,
              onPressed: () => showDespachoDialog(context),
            ),
            ActionButton(
              icon: Icons.domain,
              label: '3. ESTANTES & TICKETS',
              color: Colors.indigo.shade700,
              onPressed: () => showUbicacionesDialog(context),
            ),
          ],
          ActionButton(
            icon: Icons.cleaning_services,
            label: 'LIMPIAR FILTROS',
            color: Colors.blueGrey.shade700,
            onPressed: () => ref.read(kardexFiltersProvider.notifier).limpiar(),
          ),
        ],
      ),
    );
  }
}
ORBILOQ_EOF

echo ""
echo "Listo. Archivos actualizados/creados:"
echo "  pubspec.yaml"
echo "  lib/main.dart"
echo "  lib/application/providers.dart"
echo "  lib/domain/importacion_result.dart"
echo "  lib/data/excel_ordenes_parser.dart"
echo "  lib/data/supabase_importador_ordenes.dart"
echo "  lib/features/importacion/presentation/importar_ordenes_dialog.dart"
echo "  lib/features/kardex/presentation/kardex_page.dart"
echo ""
echo "Siguiente paso:"
echo "  flutter pub get"
echo "  flutter analyze"
echo "  flutter test"
echo "  git status"
