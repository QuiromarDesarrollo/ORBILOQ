import 'dart:convert';
import 'conductor_model.dart';

const tipoKitSemanal = 'Checklist semanal de carretera';
final catalogoKit = (jsonDecode(r'''[
  {
    "nombre": "Gato para elevar el vehículo",
    "categoria": "Gato",
    "vencimiento": false,
    "opcional": false
  },
  {
    "nombre": "Manivela o mecanismo de accionamiento",
    "categoria": "Gato",
    "vencimiento": false,
    "opcional": false
  },
  {
    "nombre": "Cruceta para las tuercas de las ruedas",
    "categoria": "Cruceta",
    "vencimiento": false,
    "opcional": false
  },
  {
    "nombre": "Triángulo reflectivo N.º 1",
    "categoria": "Señalización",
    "vencimiento": false,
    "opcional": true
  },
  {
    "nombre": "Triángulo reflectivo N.º 2",
    "categoria": "Señalización",
    "vencimiento": false,
    "opcional": true
  },
  {
    "nombre": "Soportes de los triángulos",
    "categoria": "Señalización",
    "vencimiento": false,
    "opcional": true
  },
  {
    "nombre": "Lámparas amarillas intermitentes",
    "categoria": "Señalización",
    "vencimiento": false,
    "opcional": true
  },
  {
    "nombre": "Guantes desechables de nitrilo",
    "categoria": "Botiquín",
    "vencimiento": true,
    "opcional": false
  },
  {
    "nombre": "Mascarilla de barrera para RCP",
    "categoria": "Botiquín",
    "vencimiento": true,
    "opcional": false
  },
  {
    "nombre": "Gasas estériles",
    "categoria": "Botiquín",
    "vencimiento": true,
    "opcional": false
  },
  {
    "nombre": "Apósitos estériles",
    "categoria": "Botiquín",
    "vencimiento": true,
    "opcional": false
  },
  {
    "nombre": "Vendas de gasa",
    "categoria": "Botiquín",
    "vencimiento": true,
    "opcional": false
  },
  {
    "nombre": "Venda elástica",
    "categoria": "Botiquín",
    "vencimiento": true,
    "opcional": false
  },
  {
    "nombre": "Esparadrapo o cinta médica",
    "categoria": "Botiquín",
    "vencimiento": true,
    "opcional": false
  },
  {
    "nombre": "Apósitos adhesivos",
    "categoria": "Botiquín",
    "vencimiento": true,
    "opcional": false
  },
  {
    "nombre": "Solución salina estéril",
    "categoria": "Botiquín",
    "vencimiento": true,
    "opcional": false
  },
  {
    "nombre": "Toallitas antisépticas",
    "categoria": "Botiquín",
    "vencimiento": true,
    "opcional": false
  },
  {
    "nombre": "Compresa estéril para quemaduras",
    "categoria": "Botiquín",
    "vencimiento": true,
    "opcional": false
  },
  {
    "nombre": "Tijeras de punta roma",
    "categoria": "Botiquín",
    "vencimiento": false,
    "opcional": false
  },
  {
    "nombre": "Pinzas de punta roma",
    "categoria": "Botiquín",
    "vencimiento": false,
    "opcional": false
  },
  {
    "nombre": "Manta térmica de emergencia",
    "categoria": "Botiquín",
    "vencimiento": false,
    "opcional": false
  },
  {
    "nombre": "Bolsas para material contaminado",
    "categoria": "Botiquín",
    "vencimiento": false,
    "opcional": false
  },
  {
    "nombre": "Estuche del botiquín",
    "categoria": "Botiquín",
    "vencimiento": false,
    "opcional": false
  },
  {
    "nombre": "Extintor adecuado para el vehículo",
    "categoria": "Extintor",
    "vencimiento": true,
    "opcional": false
  },
  {
    "nombre": "Carga y mantenimiento del extintor",
    "categoria": "Extintor",
    "vencimiento": true,
    "opcional": false
  },
  {
    "nombre": "Manómetro, seguro y sello",
    "categoria": "Extintor",
    "vencimiento": false,
    "opcional": true
  },
  {
    "nombre": "Soporte de fijación del extintor",
    "categoria": "Extintor",
    "vencimiento": false,
    "opcional": false
  },
  {
    "nombre": "Taco de bloqueo N.º 1",
    "categoria": "Tacos",
    "vencimiento": false,
    "opcional": false
  },
  {
    "nombre": "Taco de bloqueo N.º 2",
    "categoria": "Tacos",
    "vencimiento": false,
    "opcional": false
  },
  {
    "nombre": "Alicate",
    "categoria": "Caja de herramientas",
    "vencimiento": false,
    "opcional": false
  },
  {
    "nombre": "Destornillador de pala",
    "categoria": "Caja de herramientas",
    "vencimiento": false,
    "opcional": false
  },
  {
    "nombre": "Destornillador de estrella",
    "categoria": "Caja de herramientas",
    "vencimiento": false,
    "opcional": false
  },
  {
    "nombre": "Llave de expansión",
    "categoria": "Caja de herramientas",
    "vencimiento": false,
    "opcional": false
  },
  {
    "nombre": "Juego de llaves fijas",
    "categoria": "Caja de herramientas",
    "vencimiento": false,
    "opcional": false
  },
  {
    "nombre": "Caja o bolso de herramientas",
    "categoria": "Caja de herramientas",
    "vencimiento": false,
    "opcional": false
  },
  {
    "nombre": "Llanta de repuesto compatible",
    "categoria": "Llanta de repuesto",
    "vencimiento": false,
    "opcional": false
  },
  {
    "nombre": "Presión y estado de la llanta",
    "categoria": "Llanta de repuesto",
    "vencimiento": false,
    "opcional": false
  },
  {
    "nombre": "Fijación de la llanta",
    "categoria": "Llanta de repuesto",
    "vencimiento": false,
    "opcional": false
  },
  {
    "nombre": "Linterna funcional",
    "categoria": "Linterna",
    "vencimiento": false,
    "opcional": false
  },
  {
    "nombre": "Pilas o batería con carga",
    "categoria": "Linterna",
    "vencimiento": false,
    "opcional": false
  },
  {
    "nombre": "Chaleco reflectivo",
    "categoria": "Elementos adicionales recomendados",
    "vencimiento": false,
    "opcional": true
  },
  {
    "nombre": "Cables de arranque o arrancador portátil",
    "categoria": "Elementos adicionales recomendados",
    "vencimiento": false,
    "opcional": true
  },
  {
    "nombre": "Compresor o medidor de presión",
    "categoria": "Elementos adicionales recomendados",
    "vencimiento": false,
    "opcional": true
  },
  {
    "nombre": "Sellador de pinchazos",
    "categoria": "Elementos adicionales recomendados",
    "vencimiento": true,
    "opcional": true
  },
  {
    "nombre": "Guantes de trabajo",
    "categoria": "Elementos adicionales recomendados",
    "vencimiento": false,
    "opcional": true
  },
  {
    "nombre": "Agua potable",
    "categoria": "Elementos adicionales recomendados",
    "vencimiento": true,
    "opcional": true
  },
  {
    "nombre": "Impermeable",
    "categoria": "Elementos adicionales recomendados",
    "vencimiento": false,
    "opcional": true
  },
  {
    "nombre": "Cargador portátil para celular",
    "categoria": "Elementos adicionales recomendados",
    "vencimiento": false,
    "opcional": true
  },
  {
    "nombre": "Cuerda de remolque compatible",
    "categoria": "Elementos adicionales recomendados",
    "vencimiento": false,
    "opcional": true
  },
  {
    "nombre": "Contactos de emergencia",
    "categoria": "Elementos adicionales recomendados",
    "vencimiento": false,
    "opcional": true
  },
  {"nombre": "Kit antiderrames", "categoria": "Kit antiderrames", "vencimiento": false, "opcional": false}
]''')
        as List)
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList(growable: false);
DateTime hoyColombia([DateTime? ahora]) {
  final d = (ahora ?? DateTime.now()).toUtc().subtract(
    const Duration(hours: 5),
  );
  return DateTime(d.year, d.month, d.day);
}

String fechaKit(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime lunesKit(DateTime d) =>
    DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
bool kitSemanaCompleta(Map datos, DateTime hoy) {
  final d = DateTime.tryParse(datos['fecha']?.toString() ?? '');
  return d != null && !d.isBefore(lunesKit(hoy)) && !d.isAfter(hoy);
}

String? validarKit(Map<String, dynamic> datos, DateTime hoy) {
  if ((datos['inspector']?.toString().trim() ?? '').isEmpty) {
    return 'Escribe el nombre del inspector.';
  }
  final fecha = DateTime.tryParse(datos['fecha']?.toString() ?? '');
  if (fecha == null ||
      fechaKit(fecha) != datos['fecha'] ||
      fecha.isBefore(lunesKit(hoy)) ||
      fecha.isAfter(hoy)) {
    return 'Selecciona una fecha de esta semana, hasta hoy.';
  }
  final respuestas = datos['respuestas'] as Map? ?? {};
  for (final p in catalogoKit) {
    final nombre = p['nombre'] as String;
    final r = respuestas[nombre] as Map? ?? {};
    final estado = r['estado'];
    if (![
      'Buen estado',
      'Con novedad',
      if (p['opcional'] == true) 'No aplica',
    ].contains(estado)) {
      return 'Revisa: $nombre.';
    }
    if (estado == 'Con novedad' &&
        (r['detalle']?.toString().trim() ?? '').isEmpty) {
      return 'Describe la novedad: $nombre.';
    }
    final vencimiento = r['vencimiento']?.toString() ?? '';
    if (vencimiento.isNotEmpty) {
      final d = DateTime.tryParse(vencimiento);
      if (p['vencimiento'] != true ||
          estado == 'No aplica' ||
          d == null ||
          fechaKit(d) != vencimiento) {
        return 'Vencimiento inválido: $nombre.';
      }
      if (d.isBefore(fecha) && estado == 'Buen estado') {
        return 'El elemento $nombre está vencido. Regístralo con novedad.';
      }
    }
  }
  bool presente(String n) => (respuestas[n] as Map?)?['estado'] != 'No aplica';
  final triangulos = [
    'Triángulo reflectivo N.º 1',
    'Triángulo reflectivo N.º 2',
    'Soportes de los triángulos',
  ];
  if (!triangulos.every(presente) &&
      !presente('Lámparas amarillas intermitentes')) {
    return 'Revisa los dos triángulos y sus soportes, o las lámparas alternativas.';
  }
  return null;
}

Map<String, dynamic> resumenKit(Map<String, dynamic> datos) {
  final respuestas = datos['respuestas'] as Map;
  return {
    'fecha': datos['fecha'],
    'novedades':
        respuestas.values.where((r) => r['estado'] == 'Con novedad').length,
    'vencimientos': {
      for (final e in respuestas.entries)
        if (e.value['estado'] != 'No aplica' &&
            (e.value['vencimiento']?.toString() ?? '').isNotEmpty)
          e.key: e.value['vencimiento'],
    },
  };
}

List<String> avisosKit(Map datos, DateTime hoy) {
  final salida = <String>[];
  if (!kitSemanaCompleta(datos, hoy)) {
    salida.add(
      'Revisión semanal pendiente · semana del ${fechaKit(lunesKit(hoy))}',
    );
  }
  if ((datos['novedades'] as num? ?? 0) > 0) {
    salida.add(
      '${datos['novedades']} elementos con novedad en la última revisión',
    );
  }
  for (final e in (datos['vencimientos'] as Map? ?? {}).entries) {
    final fecha = DateTime.tryParse(e.value.toString());
    if (fecha == null) continue;
    final dias = diasRestantes(fecha, hoy);
    if (dias <= 30) {
      salida.add(
        '${e.key}: ${dias < 0
            ? 'vencido hace ${-dias} días'
            : dias == 0
            ? 'vence hoy'
            : 'vence en $dias días · aviso de ${dias <= 7
                ? 7
                : dias <= 15
                ? 15
                : 30} días'}',
      );
    }
  }
  return salida;
}
