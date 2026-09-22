#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Corrige el bug real de encabezados (v8) + prueba con .xlsx real
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_fix_encabezados_v8.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi

echo "Aplicando el arreglo del bug de encabezados..."

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
/// Nombres de columna esperados en cada hoja -> clave interna que usa el RPC.
/// Se busca por nombre de encabezado normalizado (sin tildes, sin distinguir
/// mayúsculas/minúsculas), no por posición, para tolerar que el Excel del ERP
/// cambie el orden o la escritura exacta de las columnas entre exportaciones
/// (ej. "OBSERVACION" en un archivo, "Observación" en otro).
String _normalizarEncabezado(String s) {
  var r = s.trim().toUpperCase();
  const conTilde = 'ÁÉÍÓÚÑ';
  const sinTilde = 'AEIOUN';
  for (var i = 0; i < conTilde.length; i++) {
    r = r.replaceAll(conTilde[i], sinTilde[i]);
  }
  return r;
}

final _columnasOrden = <String, String>{
  for (final e in {
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
  }.entries)
    _normalizarEncabezado(e.key): e.value,
};

final _columnasTallas = <String, String>{
  for (final e in {
    'Identificador orden': 'identificador_orden',
    'CLIENTE': 'cliente',
    'Código': 'codigo',
    'Descripción': 'descripcion',
    'Tallas nombre': 'talla',
    'Cantidad': 'cantidad',
    'NO. OC': 'oc',
    'OC ID': 'oc_id_erp',
    'OBSERVACION': 'observacion',
    'Observación': 'observacion',
  }.entries)
    _normalizarEncabezado(e.key): e.value,
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

    final ordenes = _leerHoja(
      libro.tables[nombreHojaOrden]!,
      _columnasOrden,
      requeridas: const ['identificador'],
      nombreHoja: 'Orden',
    );
    final tallas = _leerHoja(
      libro.tables[nombreHojaTallas]!,
      _columnasTallas,
      requeridas: const ['identificador_orden', 'codigo', 'talla', 'cantidad'],
      nombreHoja: 'Tallas',
    );

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

  static List<Map<String, String?>> _leerHoja(
    Sheet hoja,
    Map<String, String> columnas, {
    required List<String> requeridas,
    required String nombreHoja,
  }) {
    if (hoja.maxRows == 0) return const [];

    final encabezados = hoja.rows.first;
    final indicePorClave = <String, int>{};
    final encabezadosLeidos = <String>[];
    for (var i = 0; i < encabezados.length; i++) {
      final texto = _texto(encabezados[i]?.value)?.trim();
      if (texto == null || texto.isEmpty) continue;
      encabezadosLeidos.add(texto);
      final clave = columnas[_normalizarEncabezado(texto)];
      if (clave != null) indicePorClave[clave] = i;
    }

    final faltantes = requeridas.where((r) => !indicePorClave.containsKey(r)).toList();
    if (faltantes.isNotEmpty) {
      throw ExcelOrdenesParseException(
        'No se reconocieron algunas columnas requeridas en la hoja "$nombreHoja" '
        '(${faltantes.join(", ")}). Encabezados encontrados: ${encabezadosLeidos.join(", ")}',
      );
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
        // Un código como 202674809 puede venir como celda numérica (no texto).
        // Si es un número entero, se muestra sin decimales ("202674809", no
        // "202674809.0"), para que coincida con el mismo código tal como
        // viene en el QR.
        DoubleCellValue v => _formatearNumero(v.value),
        BoolCellValue v => v.value.toString(),
        _ => valor.toString(),
      };
    } catch (_) {
      return valor.toString();
    }
  }

  static String _formatearNumero(double d) {
    if (d.isFinite && d == d.roundToDouble() && d.abs() < 1e15) {
      return d.toStringAsFixed(0);
    }
    return d.toString();
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
            '${value.opsCreadas} OP nuevas creadas · ${value.opsOmitidas} ya existían (omitidas) · '
            '${value.lineasTallasCreadas} líneas de tallas cargadas'
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
            if (_resumen != null && _resumen!.tuvoProblemas) ...[
              const SizedBox(height: 12),
              Text(
                'Detalle'
                '${_resumen!.filasInvalidas > 0 ? ' · ${_resumen!.filasInvalidas} filas sin OP válida' : ''}'
                '${_resumen!.advertencias.isNotEmpty ? ' · ${_resumen!.advertencias.length} advertencias de cantidad' : ''}:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              if (_resumen!.advertencias.isEmpty)
                const Text(
                  'No hay advertencias de cantidad para mostrar, pero revisa el mensaje '
                  'de filas sin OP válida arriba — probablemente el archivo no tiene el '
                  'formato de columnas esperado.',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _resumen!.advertencias.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• ${_resumen!.advertencias[i]}', style: const TextStyle(fontSize: 12)),
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

echo "  - test/wms_rules_test.dart"
mkdir -p "$(dirname 'test/wms_rules_test.dart')"
cat > 'test/wms_rules_test.dart' << 'ORBILOQ_EOF'
import 'dart:typed_data';

import 'package:excel/excel.dart' as xlsx;
import 'package:flutter_test/flutter_test.dart';

import 'package:orbiloq_wms/core/result.dart';
import 'package:orbiloq_wms/data/excel_ordenes_parser.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/domain/qr_prenda.dart';

const _xs = '19249|ORD-001-ENE|2025289514|XS'; // pedida 9, producido 9 (límite alcanzado)
const _s = '19249|ORD-001-ENE|2025289515|S'; // pedida 264, producido 100, stock A1 = 30

void main() {
  group('QrPrenda', () {
    test('parsea un QR válido con el formato real de la marquilla', () {
      final qr = QrPrenda.tryParse(
        'https://orbiloq.app/qr?;19249;2025289514;TSHIRT MANGA CORTA T. XS;ENEL;ORD-001-ENE;ID0001',
      );
      expect(qr, isNotNull);
      expect(qr!.op, '19249');
      expect(qr.codigo, '2025289514');
      expect(qr.cliente, 'ENEL');
      expect(qr.noOc, 'ORD-001-ENE');
    });

    test('parsea un QR real donde la OP queda pegada a la URL, sin ; de por medio', () {
      // Caso real detectado: el '?' no va seguido de ';', la OP queda directo
      // pegada al final de la URL.
      final qr = QrPrenda.tryParse(
        'https://www.atom.bio/grupoquiromarsas?25079;202674809;'
        'BLUSA ADMINISTRATIVA DAMA  T. S/8;TV COLOMBIA DIGITAL;PEDIDO AGOSTO;ID0016',
      );
      expect(qr, isNotNull);
      expect(qr!.op, '25079');
      expect(qr.codigo, '202674809');
      expect(qr.cliente, 'TV COLOMBIA DIGITAL');
      expect(qr.noOc, 'PEDIDO AGOSTO');
    });

    test('rechaza QR incompleto o con OP/Código vacíos', () {
      expect(QrPrenda.tryParse('url;ENEL'), isNull);
      expect(QrPrenda.tryParse('url;;2025289514;TSHIRT;ENEL;ORD-001-ENE'), isNull);
    });
  });

  group('Reglas de negocio', () {
    late InMemoryWmsRepository repo;

    setUp(() => repo = InMemoryWmsRepository.seeded());
    tearDown(() => repo.dispose());

    Future<ItemKardex> kardex(String id) async =>
        (await repo.watch().first).kardexPorId(id)!;

    test('producción no puede superar la cantidad pedida', () async {
      expect(await repo.entregarLote(itemId: _xs, cantidad: 1, operario: 'X'), isA<Err>());
      expect(await repo.entregarLote(itemId: _s, cantidad: 165, operario: 'X'), isA<Err>());
      expect(await repo.entregarLote(itemId: _s, cantidad: 164, operario: 'X'), isA<Ok>());
    });

    test('no se entrega un producto inexistente ni cantidades <= 0', () async {
      expect(await repo.entregarLote(itemId: 'nope', cantidad: 1, operario: 'X'), isA<Err>());
      expect(await repo.entregarLote(itemId: _s, cantidad: 0, operario: 'X'), isA<Err>());
    });

    test('no permite remisiones duplicadas', () async {
      final r = await repo.entregarLote(itemId: _s, cantidad: 1, operario: 'X', numeroRemision: 'REM-097');
      expect(r, isA<Err>());
    });

    test('la numeración automática no colisiona', () async {
      final a = await repo.entregarLote(itemId: _s, cantidad: 1, operario: 'X');
      final b = await repo.entregarLote(itemId: _s, cantidad: 1, operario: 'X');
      expect((a as Ok<Remision>).value.id, isNot((b as Ok<Remision>).value.id));
    });

    test('la recepción con faltante genera novedad y actualiza el stock', () async {
      final res = await repo.recibirLote(remisionId: 'REM-101', cantidad: 3, ubicacion: 'RACK C3');
      final remision = (res as Ok<Remision>).value;
      expect(remision.estado, EstadoRemision.recibidoConNovedad);
      expect(remision.novedad, contains('FALTANTE'));

      final k = await kardex(_xs);
      expect(k.recibido, 8);
      expect(k.stockEn('RACK C3'), 3);
    });

    test('una remisión no se puede recibir dos veces', () async {
      await repo.recibirLote(remisionId: 'REM-101', cantidad: 4, ubicacion: 'RACK C3');
      final again = await repo.recibirLote(remisionId: 'REM-101', cantidad: 4, ubicacion: 'RACK C3');
      expect(again, isA<Err>());
    });

    test('el despacho valida el stock de la ubicación', () async {
      expect(await repo.despachar(itemId: _s, cantidad: 31, ubicacion: 'ESTANTE A1'), isA<Err>());
      expect(await repo.despachar(itemId: _s, cantidad: 1, ubicacion: 'RACK C3'), isA<Err>());
      expect(await repo.despachar(itemId: _s, cantidad: 30, ubicacion: 'ESTANTE A1'), isA<Ok>());

      final k = await kardex(_s);
      expect(k.despachado, 50);
      expect(k.stockDisponible, 0);
      expect(k.ubicaciones.containsKey('ESTANTE A1'), isFalse);
    });

    test('stockDisponible siempre coincide con la suma de ubicaciones', () async {
      final snap = await repo.watch().first;
      for (final k in snap.kardex) {
        expect(k.ubicaciones.values.fold<int>(0, (a, b) => a + b), k.stockDisponible);
      }
    });
  });

  group('ExcelOrdenesParser (bytes reales de .xlsx)', () {
    // Esta prueba existe porque un bug real (encabezados que no se
    // reconocían por diferencias de mayúsculas/tildes) pasó sin detectarse
    // porque nunca se probó el parser contra un archivo Excel de verdad,
    // solo contra texto. Aquí se construye un .xlsx real en memoria.
    List<int> construirXlsxDePrueba() {
      final libro = xlsx.Excel.createExcel();

      final orden = libro['Orden'];
      // Encabezados con mayúsculas/espacios distintos a los del diccionario
      // interno, a propósito, para probar la normalización.
      orden.appendRow([
        xlsx.TextCellValue('IDENTIFICADOR'),
        xlsx.TextCellValue(' Cliente '),
        xlsx.TextCellValue('CANTIDAD'),
      ]);
      orden.appendRow([
        xlsx.IntCellValue(25079),
        xlsx.TextCellValue('TV COLOMBIA DIGITAL'),
        xlsx.IntCellValue(15),
      ]);

      final tallas = libro['Tallas'];
      tallas.appendRow([
        xlsx.TextCellValue('identificador orden'), // minúsculas
        xlsx.TextCellValue('CODIGO'), // sin tilde, mayúsculas (la clave real es "Código")
        xlsx.TextCellValue('TALLAS NOMBRE'),
        xlsx.TextCellValue('cantidad'),
      ]);
      tallas.appendRow([
        xlsx.IntCellValue(25079),
        // Código como celda numérica con decimales, para probar que no
        // quede guardado como "202674809.0".
        xlsx.DoubleCellValue(202674809),
        xlsx.TextCellValue('S/8'),
        xlsx.IntCellValue(15),
      ]);

      libro.delete('Sheet1');
      final bytes = libro.encode();
      if (bytes == null) {
        fail('No se pudo generar el .xlsx de prueba');
      }
      return bytes;
    }

    test('reconoce encabezados aunque vengan con mayúsculas/tildes distintas', () {
      final bytes = Uint8List.fromList(construirXlsxDePrueba());
      final parseado = ExcelOrdenesParser.parsear(bytes);

      expect(parseado.ordenes.length, 1);
      expect(parseado.ordenes.first['identificador'], '25079');
      expect(parseado.ordenes.first['cliente'], 'TV COLOMBIA DIGITAL');

      expect(parseado.tallas.length, 1);
      expect(parseado.tallas.first['identificador_orden'], '25079');
      expect(parseado.tallas.first['talla'], 'S/8');
    });

    test('un código numérico no queda con ".0" pegado al final', () {
      final bytes = Uint8List.fromList(construirXlsxDePrueba());
      final parseado = ExcelOrdenesParser.parsear(bytes);

      expect(parseado.tallas.first['codigo'], '202674809');
    });

    test('avisa claramente si falta una columna requerida, en vez de fallar en silencio', () {
      final libro = xlsx.Excel.createExcel();
      final orden = libro['Orden'];
      // Sin columna "Identificador": debe fallar de forma explícita.
      orden.appendRow([xlsx.TextCellValue('Cliente'), xlsx.TextCellValue('Cantidad')]);
      orden.appendRow([xlsx.TextCellValue('ACME'), xlsx.IntCellValue(1)]);
      libro['Tallas'].appendRow([xlsx.TextCellValue('Identificador orden')]);
      libro.delete('Sheet1');
      final bytes = Uint8List.fromList(libro.encode()!);

      expect(
        () => ExcelOrdenesParser.parsear(bytes),
        throwsA(isA<ExcelOrdenesParseException>()),
      );
    });
  });
}
ORBILOQ_EOF

echo ""
echo "Listo. Siguiente paso:"
echo "  flutter analyze"
echo "  flutter test"
