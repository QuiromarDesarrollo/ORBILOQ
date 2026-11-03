import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';
import 'masiva_importador_modelo.dart';

/// Lee los valores guardados en XLSX, incluidas fórmulas con resultado en caché.
/// No evalúa fórmulas ni consulta vínculos externos. Se ejecuta en worker/isolate.
MasivaImportacion parsearMasivaExcel(Uint8List bytes, {required String tipo}) {
  if (!{'recepcion', 'personal'}.contains(tipo)) {
    throw const FormatException('Selecciona recepción o base de personal.');
  }
  if (bytes.length > 40 * 1024 * 1024) {
    throw const FormatException('El Excel supera el máximo de 40 MB.');
  }
  late final _Libro libro;
  try {
    libro = _Libro(bytes);
  } catch (_) {
    throw const FormatException(
      'No se pudo leer el archivo. Selecciona un Excel .xlsx válido, sin contraseña.',
    );
  }
  final filas = <Map<String, dynamic>>[];
  final errores = <String>[];
  final avisos = <String>[];
  final hojas = <String>[];
  final omitidas = <String>[];
  final claves = <String, String>{};
  final personas = <String, String>{};
  final consecutivos = <String, String>{};
  final nombres = <String, String>{};
  final destinos = <String, Map<String, String>>{};
  final conflictosDestino = <String>{};
  final lideres = <String, Set<String>>{};
  final recepcion = tipo == 'recepcion';
  final obligatorias =
      recepcion
          ? ['sku', 'descripcion', 'cantidad', 'pedido', 'proveedor']
          : [
            'lista',
            'numero_persona',
            'cedula',
            'nombre',
            'sku',
            'descripcion',
            'cantidad',
          ];
  var totales = 0;
  for (final hoja in libro.hojas) {
    if (recepcion && _normalizar(hoja.nombre) != 'CONSOLIDADO') {
      omitidas.add(hoja.nombre);
      continue;
    }
    Map<int, String>? columnas;
    Map<int, String> columnasFuente = {};
    for (final fila in libro.filas(hoja.ruta)) {
      if (columnas == null) {
        if (fila.numero > 25) break;
        final candidatas = <int, String>{};
        for (final celda in fila.celdas.entries) {
          final clave =
              (recepcion ? _recepcion : _personal)[_normalizar(celda.value)];
          if (clave != null) candidatas[celda.key] = clave;
        }
        if (obligatorias.every(candidatas.values.contains)) {
          columnas = candidatas;
          if (!recepcion) columnasFuente = _columnasFuente(fila.celdas);
          hojas.add(hoja.nombre);
          if (candidatas.values.toSet().length != candidatas.length) {
            errores.add(
              '${hoja.nombre}, fila ${fila.numero}: hay encabezados repetidos para el mismo campo.',
            );
          }
        }
        continue;
      }
      final datos = <String, dynamic>{
        for (final columna in columnas.entries)
          columna.value: (fila.celdas[columna.key] ?? '').trim(),
      };
      if (datos.values.every((v) => v.toString().isEmpty)) continue;
      final origen = '${hoja.nombre}, fila ${fila.numero}';
      // Las hojas entregadas incluyen subtotales sin rótulo: no tienen
      // posición, material ni descripción, únicamente cantidad y unidad.
      if (recepcion &&
          '${datos['sku']}'.isEmpty &&
          '${datos['descripcion']}'.isEmpty &&
          (fila.celdas[1] ?? '').trim().isEmpty) {
        totales++;
        continue;
      }
      if ('${datos['sku']}'.isEmpty &&
          fila.celdas.values.any(
            (v) => RegExp(r'^(TOTAL|SUMA)(\s|$)').hasMatch(_normalizar(v)),
          )) {
        totales++;
        continue;
      }
      final faltantes =
          obligatorias.where((k) => '${datos[k] ?? ''}'.isEmpty).toList();
      if (faltantes.isNotEmpty) {
        errores.add('$origen: faltan ${faltantes.join(', ')}.');
        continue;
      }
      if (datos.values.any((v) => v.toString().startsWith('#ERROR_EXCEL:'))) {
        errores.add(
          '$origen: una celda contiene un error o una fórmula sin resultado guardado. Abre el archivo en Excel, recalcula y guarda.',
        );
        continue;
      }
      final cantidad = num.tryParse(
        '${datos['cantidad']}'.replaceAll(',', '.'),
      );
      if (cantidad == null ||
          !cantidad.isFinite ||
          cantidad <= 0 ||
          cantidad != cantidad.truncate() ||
          cantidad > 1000000) {
        errores.add(
          '$origen: la cantidad debe ser un entero positivo (máximo 1.000.000).',
        );
        continue;
      }
      datos['cantidad'] = cantidad.toInt();
      if (recepcion) {
        // El formato CONSOLIDADO expresa cantidades sin unidad de medida.
        // Se conserva el conteo original, sin convertir calzado ni otras prendas.
        datos['unidad'] = 'UN';
        final unidad = _normalizar('${datos['unidad']}');
        if (!{
          'UN',
          'UND',
          'UNIDAD',
          'UNIDADES',
          'PAR',
          'PARES',
        }.contains(unidad)) {
          errores.add('$origen: unidad no reconocida; debe ser UN o PAR.');
          continue;
        }
        datos['unidad'] = {'PAR', 'PARES'}.contains(unidad) ? 'PAR' : 'UN';
      } else {
        final numero = int.tryParse('${datos['numero_persona']}');
        if (numero == null || numero <= 0) {
          errores.add(
            '$origen: el número de persona debe ser un entero positivo.',
          );
          continue;
        }
        datos['numero_persona'] = numero;
        final persona = '${datos['lista']}\u0000${datos['cedula']}';
        final consecutivo = '${datos['lista']}\u0000$numero';
        if (personas.containsKey(persona) && personas[persona] != consecutivo) {
          errores.add(
            '$origen: una persona tiene dos consecutivos en la misma lista.',
          );
        }
        if (consecutivos.containsKey(consecutivo) &&
            consecutivos[consecutivo] != persona) {
          errores.add(
            '$origen: el consecutivo $numero se repite para personas diferentes.',
          );
        }
        personas[persona] = consecutivo;
        consecutivos[consecutivo] = persona;
        final nombre = '${datos['nombre']}';
        if (nombres.containsKey(persona) && nombres[persona] != nombre) {
          errores.add(
            '$origen: la misma persona aparece con nombres diferentes dentro de la lista.',
          );
        }
        nombres[persona] = nombre;
        final lista = '${datos['lista']}';
        final destino = destinos.putIfAbsent(lista, () => {});
        for (final campo in ['sede', 'ciudad', 'direccion', 'unidad']) {
          final valor = _normalizar('${datos[campo] ?? ''}');
          if (valor.isEmpty) continue;
          if (destino.containsKey(campo) &&
              destino[campo] != valor &&
              conflictosDestino.add('$lista\u0000$campo')) {
            errores.add(
              '$origen: la lista $lista tiene valores diferentes en $campo. Define un destino común antes de generar su lista de empaque.',
            );
          }
          destino.putIfAbsent(campo, () => valor);
        }
        final lider = '${datos['lider'] ?? ''}';
        if (lider.isNotEmpty) {
          lideres.putIfAbsent('${datos['lista']}', () => {}).add(lider);
        }
        for (final k in [
          'sede',
          'ciudad',
          'direccion',
          'unidad',
          'sector',
          'lider',
        ]) {
          datos.putIfAbsent(k, () => '');
        }
        // La fuente acompaña a cada renglón, sin reemplazar los campos operativos
        // ni agrupar datos de personas que comparten una lista de empaque.
        final fuente = <String, dynamic>{};
        for (final columna in columnasFuente.entries) {
          final clave = columna.value;
          final valor = (fila.celdas[columna.key] ?? '').trim();
          fuente[clave] = switch (clave) {
            'cantidad' || 'numero_persona' => datos[clave],
            'items_kit' || 'items_lista' || 'items_direccion' =>
              valor.isEmpty ? null : int.tryParse(valor) ?? valor,
            'fecha_empaque_programada' || 'fecha_entrega_programada' =>
              _fechaFuente(valor, usa1904: libro.usa1904),
            _ => valor,
          };
        }
        // También conservar columnas nuevas que lleguen sin encabezado.
        for (final celda in fila.celdas.entries) {
          if (!columnasFuente.containsKey(celda.key) &&
              celda.value.trim().isNotEmpty) {
            var clave = 'columna_${celda.key}';
            while (fuente.containsKey(clave)) {
              clave = '${clave}_columna_${celda.key}';
            }
            fuente[clave] = celda.value.trim();
          }
        }
        datos['fuente'] = fuente;
        datos['fila_origen'] = fila.numero;
        datos['hoja_origen'] = hoja.nombre;
      }
      final clave =
          recepcion
              ? '${datos['proveedor']}\u0000${datos['pedido']}\u0000${datos['sku']}'
              : '${datos['lista']}\u0000${datos['cedula']}\u0000${datos['sku']}';
      if (claves.containsKey(clave)) {
        errores.add(
          '$origen: registro duplicado con ${claves[clave]}; revisa antes de cargar.',
        );
      } else {
        claves[clave] = origen;
      }
      filas.add(datos);
      if (filas.length > 100000) {
        throw const FormatException(
          'La base supera las 100.000 filas. Divide la operación antes de cargar.',
        );
      }
    }
    if (!hojas.contains(hoja.nombre)) omitidas.add(hoja.nombre);
  }
  if (filas.isEmpty) {
    errores.add(
      recepcion
          ? 'No se encontraron filas válidas en CONSOLIDADO. El archivo debe incluir esa hoja con las columnas Código material, Descripción, Cantidad, ORDEN DE COMPRA y PROVEEDOR.'
          : 'No se encontraron filas con el formato de personal.',
    );
  }
  if (!recepcion && hojas.length > 1) {
    errores.add(
      'Se encontraron varias hojas de personal (${hojas.join(', ')}). Conserva una sola base para evitar duplicaciones.',
    );
  }
  if (omitidas.isNotEmpty) {
    avisos.add(
      'Hojas excluidas${recepcion ? ' (solo se lee CONSOLIDADO)' : ''}: ${omitidas.join(', ')}.',
    );
  }
  if (totales > 0) {
    avisos.add(
      'Se excluyeron $totales filas de totales; solo se cargarán referencias.',
    );
  }
  if (recepcion) {
    avisos.add(
      'Solo se lee CONSOLIDADO. Las cantidades se conservan sin conversión; este formato no incluye unidad de medida.',
    );
    avisos.add(
      'Solo se cargarán cantidades solicitadas. El inventario recibido iniciará en cero; no se importan recepciones ni soportes del ejemplo.',
    );
  }
  if (!recepcion) {
    avisos.add(
      'Las fechas programadas se conservan únicamente como datos de origen; no se muestran ni afectan la operación.',
    );
    final varias = lideres.values.where((v) => v.length > 1).length;
    if (varias > 0) {
      avisos.add(
        '$varias listas tienen varios líderes. Se propone el primero de cada lista como responsable principal; podrás revisarlo antes de emitir documentos.',
      );
    }
  }
  return MasivaImportacion(
    filas: filas,
    errores: errores,
    avisos: avisos,
    tipo: tipo,
    hojas: hojas,
  );
}

String _normalizar(String valor) {
  var s = valor.trim().toUpperCase();
  const original = 'ÁÉÍÓÚÜÑ';
  const normal = 'AEIOUUN';
  for (var i = 0; i < original.length; i++) {
    s = s.replaceAll(original[i], normal[i]);
  }
  return s.replaceAll(RegExp(r'\s+'), ' ');
}

const _recepcion = {
  'CODIGO MATERIAL': 'sku',
  'DESCRIPCION': 'descripcion',
  'CANTIDAD': 'cantidad',
  'ORDEN DE COMPRA': 'pedido',
  'PROVEEDOR': 'proveedor',
};
const _personal = {
  'LE': 'lista',
  '#': 'numero_persona',
  'NUMERO DE PERSONA': 'numero_persona',
  'CEDULA': 'cedula',
  'NOMBRE COMPLETO': 'nombre',
  'CODIGO': 'sku',
  'MATERIAL DESCRIPCION': 'descripcion',
  'CANTIDAD A ENVIAR': 'cantidad',
  'SEDE': 'sede',
  'CIUDAD': 'ciudad',
  'DIRECCION': 'direccion',
  'UNIDAD ORGANIZATIVA': 'unidad',
  'SECTOR': 'sector',
  'LIDER / ENCARGADO': 'lider',
  'LIDER/ENCARGADO': 'lider',
};

const _personalFuente = {
  ..._personal,
  'LOGISTICA': 'logistica',
  'ENTREGA': 'entrega',
  'UNIDAD DIRECTIVA': 'unidad_directiva',
  'GERENCIA': 'gerencia',
  'CARGO': 'cargo',
  'PRENDA': 'prenda',
  'REGIONAL': 'regional',
  'DEPARTAMENTO': 'departamento',
  'ITEMS KITS': 'items_kit',
  'ITEMS LE': 'items_lista',
  'ITEMS DIRECCION': 'items_direccion',
  'FECHA EMPAQUE': 'fecha_empaque_programada',
  'FECHA ENTREGA': 'fecha_entrega_programada',
};

Map<int, String> _columnasFuente(Map<int, String> encabezados) {
  final result = <int, String>{};
  final usadas = <String>{};
  for (final encabezado in encabezados.entries) {
    final normalizado = _normalizar(encabezado.value);
    if (normalizado.isEmpty) continue;
    final base =
        _personalFuente[normalizado] ??
        normalizado
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
            .replaceAll(RegExp(r'^_+|_+$'), '');
    var clave = base.isEmpty ? 'columna_${encabezado.key}' : base;
    if (usadas.contains(clave)) clave = '${clave}_columna_${encabezado.key}';
    while (!usadas.add(clave)) {
      clave = '${clave}_columna_${encabezado.key}';
    }
    result[encabezado.key] = clave;
  }
  return result;
}

String? _fechaFuente(String valor, {required bool usa1904}) {
  if (valor.isEmpty) return null;
  final serial = num.tryParse(valor.replaceAll(',', '.'));
  if (serial != null && serial.isFinite && serial >= 0 && serial <= 2958465) {
    // El calendario 1900 de Excel incluye un 29/02/1900 ficticio. No se inventa
    // una fecha gregoriana para ese valor; el resto se convierte sin zona local.
    if (!usa1904 && serial.floor() == 60) return valor;
    final base =
        usa1904
            ? DateTime.utc(1904, 1, 1)
            : serial < 60
            ? DateTime.utc(1899, 12, 31)
            : DateTime.utc(1899, 12, 30);
    return base
        .add(
          Duration(
            milliseconds: (serial * Duration.millisecondsPerDay).round(),
          ),
        )
        .toIso8601String();
  }
  return valor;
}

class _Libro {
  _Libro(Uint8List bytes) {
    final zip = ZipDecoder().decodeBytes(bytes);
    if (zip.files.fold<int>(0, (s, f) => s + f.size) > 250 * 1024 * 1024) {
      throw const FormatException(
        'El contenido del Excel es demasiado grande.',
      );
    }
    archivos = {for (final f in zip.files) f.name: f};
    final strings = archivos['xl/sharedStrings.xml'];
    if (strings != null) {
      var texto = StringBuffer();
      var leyendo = false;
      for (final e in parseEvents(utf8.decode(strings.content as List<int>))) {
        if (e is XmlStartElementEvent && e.localName == 'si') {
          texto = StringBuffer();
        }
        if (e is XmlStartElementEvent && e.localName == 't') {
          leyendo = !e.isSelfClosing;
        }
        if (e is XmlTextEvent && leyendo) texto.write(e.value);
        if (e is XmlEndElementEvent && e.localName == 't') leyendo = false;
        if (e is XmlEndElementEvent && e.localName == 'si') {
          textos.add(texto.toString());
        }
      }
    }
    final estilos = xml('xl/styles.xml', opcional: true);
    if (estilos != null) {
      final formatos = {
        for (final e in estilos.findAllElements('numFmt'))
          e.getAttribute('numFmtId'): e.getAttribute('formatCode') ?? '',
      };
      final xfs = estilos.findAllElements('cellXfs').firstOrNull;
      if (xfs != null) {
        ceros = [
          for (final e in xfs.childElements)
            formatos[e.getAttribute('numFmtId')] ?? '',
        ];
      }
    }
    final relaciones = {
      for (final e in xml(
        'xl/_rels/workbook.xml.rels',
      )!.findAllElements('Relationship'))
        e.getAttribute('Id'): e.getAttribute('Target')!,
    };
    final documento = xml('xl/workbook.xml')!;
    final calendario = documento
        .findAllElements('workbookPr')
        .firstOrNull
        ?.getAttribute('date1904');
    usa1904 = calendario == '1' || calendario == 'true';
    for (final e in documento.findAllElements('sheet')) {
      final id = e.attributes.firstWhere((a) => a.name.local == 'id').value;
      final destino = relaciones[id]!;
      final ruta =
          destino.startsWith('/')
              ? destino.substring(1)
              : Uri.parse('xl/').resolve(destino).path;
      hojas.add((nombre: e.getAttribute('name')!, ruta: ruta));
    }
  }
  late final Map<String, ArchiveFile> archivos;
  List<String> textos = [];
  List<String> ceros = [];
  bool usa1904 = false;
  final hojas = <({String nombre, String ruta})>[];
  XmlDocument? xml(String ruta, {bool opcional = false}) {
    final archivo = archivos[ruta];
    if (archivo == null && opcional) return null;
    if (archivo == null) throw FormatException('Falta $ruta');
    return XmlDocument.parse(utf8.decode(archivo.content as List<int>));
  }

  Iterable<({int numero, Map<int, String> celdas})> filas(String ruta) sync* {
    // Lectura incremental: no construye un árbol XML de cientos de miles de
    // celdas. También permite abandonar hojas de resumen tras sus encabezados.
    final archivo = archivos[ruta];
    if (archivo == null) throw FormatException('Falta $ruta');
    var celdas = <int, String>{};
    var numero = 0, columna = 0, anterior = 0;
    var tipo = '', estilo = '', captura = '';
    var formula = false;
    var valor = StringBuffer(), inline = StringBuffer();
    void terminarCelda() {
      var texto = valor.toString();
      if (tipo == 's') {
        texto = textos[int.parse(texto)];
      } else if (tipo == 'inlineStr') {
        texto = inline.toString();
      } else if (tipo == 'e' || (formula && texto.isEmpty)) {
        texto = '#ERROR_EXCEL:$texto';
      } else if (tipo.isEmpty || tipo == 'n') {
        final n = num.tryParse(texto);
        if (n != null && n.isFinite && n == n.truncate()) {
          texto = n.toInt().toString();
          final indice = int.tryParse(estilo);
          final formato =
              indice != null && indice < ceros.length ? ceros[indice] : '';
          if (RegExp(r'^0+$').hasMatch(formato)) {
            texto = texto.padLeft(formato.length, '0');
          }
        }
      }
      celdas[columna] = texto;
      captura = '';
    }

    for (final e in parseEvents(
      utf8.decode(archivo.content as List<int>),
      validateNesting: true,
    )) {
      if (e is XmlStartElementEvent) {
        switch (e.localName) {
          case 'row':
            celdas = <int, String>{};
            anterior = 0;
            numero =
                int.tryParse(
                  e.attributes
                          .where((a) => a.localName == 'r')
                          .firstOrNull
                          ?.value ??
                      '',
                ) ??
                0;
          case 'c':
            final a = {for (final a in e.attributes) a.localName: a.value};
            columna = 0;
            for (final c in (a['r'] ?? '').codeUnits.takeWhile(
              (c) => c >= 65 && c <= 90,
            )) {
              columna = columna * 26 + c - 64;
            }
            if (columna == 0) columna = anterior + 1;
            anterior = columna;
            tipo = a['t'] ?? '';
            estilo = a['s'] ?? '';
            valor = StringBuffer();
            inline = StringBuffer();
            formula = false;
            if (e.isSelfClosing) terminarCelda();
          case 'f':
            formula = true;
          case 'v':
            captura = e.isSelfClosing ? '' : 'v';
          case 't':
            captura = e.isSelfClosing ? '' : 't';
        }
      } else if (e is XmlTextEvent) {
        if (captura == 'v') valor.write(e.value);
        if (captura == 't') inline.write(e.value);
      } else if (e is XmlEndElementEvent) {
        switch (e.localName) {
          case 'v':
          case 't':
            captura = '';
          case 'c':
            terminarCelda();
          case 'row':
            yield (numero: numero, celdas: celdas);
        }
      }
    }
  }
}
