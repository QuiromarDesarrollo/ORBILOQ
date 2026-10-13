import 'dart:io';
import 'dart:typed_data';
import 'package:orbiloq_wms/data/lista_empaque_pdf.dart';
import 'package:orbiloq_wms/data/clientes_empaque_excel.dart';

Future<void> main(List<String> args) async {
  if (args.isNotEmpty) {
    final cs = leerClientesEmpaque(await File(args.first).readAsBytes());
    stdout.writeln('Clientes válidos: ${cs.length}');
  }
  final d = <String, dynamic>{
    'numero': 2971,
    'fecha': '2026-10-07T15:00:00Z',
    'actor': 'Administrador',
    'oc': 'OC-PRUEBA',
    'remision': '',
    'id_oc': '',
    'factura': '',
    'destinatario': {
      'tipo_destinatario': 'internacional',
      'email': 'recepcion@example.com',
      'via': 'AÉREA',
      'tipo_carga': 'SUELTA',
      'embalaje': 'CAJAS DE CARTÓN',
      'puerto_embarque': 'AEROPUERTO INTERNACIONAL EL DORADO',
      'pais_origen': 'COLOMBIA',
      'puerto_destino': 'AEROPUERTO INTERNACIONAL REINA BEATRIX',
      'pais_destino': 'ARUBA',
      'termino_negociacion': 'CIP',
      'nombre': 'CLIENTE DE PRUEBA S.A.S.',
      'nit': '900000000-0',
      'contacto': 'Responsable de recepción',
      'direccion': 'KM 2.5 VIA GALAPA –',
      'sede': 'Recepción “Principal” — Área Nº 2',
      'ciudad': 'BOGOTÁ',
      'telefono': '',
      'celular': '',
    },
    'detalle': [
      for (var i = 0; i < 70; i++)
        {
          'item_id': 'item-$i',
          'op': '9000${i % 3}',
          'producto':
              'CAMISA EMPRESARIAL MANGA LARGA COLOR AZUL REFERENCIA DE PRUEBA',
          'codigo': 'REF-${i % 3}',
          'talla': '${36 + i % 5}',
        },
    ],
    'empaques': [
      for (var i = 0; i < 70; i++)
        {
          'numero': i ~/ 3 + 1,
          'item_id': 'item-$i',
          'cantidad': 5,
          'categoria': i < 3 ? 'BOLSA' : 'CAJA',
          'alto_cm': 37,
          'largo_cm': 58,
          'ancho_cm': 37,
          'peso_neto_kg': 4,
          'peso_bruto_kg': 5,
        },
    ],
  };
  final out = File('.dart_tool/lista-empaque/internacional-larga.pdf');
  await out.parent.create(recursive: true);
  await out.writeAsBytes(
    await crearListaEmpaquePdf(
      d,
      logo: await File('assets/images/logo_quiromar_formato.jpg').readAsBytes(),
      fuenteRegular: ByteData.sublistView(
        await File('assets/fonts/LiberationSans-Regular.ttf').readAsBytes(),
      ),
      fuenteNegrita: ByteData.sublistView(
        await File('assets/fonts/LiberationSans-Bold.ttf').readAsBytes(),
      ),
    ),
  );
  stdout.writeln(out.path);
  final muestra = Map<String, dynamic>.from(d);
  muestra['numero'] = 'MUESTRA';
  muestra['detalle'] = [
    for (final x in (d['detalle'] as List).take(14))
      {...x as Map, 'producto': 'PRENDA EMPRESARIAL DE PRUEBA'},
  ];
  muestra['empaques'] = [
    for (var i = 0; i < 14; i++)
      {
        ...(d['empaques'] as List)[i] as Map,
        'numero': [1, 2, 2, 2, 3, 3, 4, 5, 5, 6, 6, 6, 6, 6][i],
        'categoria': 'CAJA',
        'peso_neto_kg': 9.5,
        'peso_bruto_kg': 10,
      },
  ];
  final demo = File('output/pdf/muestra_lista_empaque_internacional.pdf');
  await demo.parent.create(recursive: true);
  await demo.writeAsBytes(
    await crearListaEmpaquePdf(
      muestra,
      logo: await File('assets/images/logo_quiromar_formato.jpg').readAsBytes(),
      fuenteRegular: ByteData.sublistView(
        await File('assets/fonts/LiberationSans-Regular.ttf').readAsBytes(),
      ),
      fuenteNegrita: ByteData.sublistView(
        await File('assets/fonts/LiberationSans-Bold.ttf').readAsBytes(),
      ),
    ),
  );
  stdout.writeln(demo.path);
  final nacional = Map<String, dynamic>.from(muestra);
  nacional['destinatario'] = Map<String, dynamic>.from(
    muestra['destinatario'] as Map,
  )..remove('tipo_destinatario');
  await File('.dart_tool/lista-empaque/nacional-regresion.pdf').writeAsBytes(
    await crearListaEmpaquePdf(
      nacional,
      logo: await File('assets/images/logo_quiromar_formato.jpg').readAsBytes(),
      fuenteRegular: ByteData.sublistView(
        await File('assets/fonts/LiberationSans-Regular.ttf').readAsBytes(),
      ),
      fuenteNegrita: ByteData.sublistView(
        await File('assets/fonts/LiberationSans-Bold.ttf').readAsBytes(),
      ),
    ),
  );
}
