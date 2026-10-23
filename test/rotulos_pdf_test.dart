import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/data/rotulo_empaque_pdf.dart';
import 'package:orbiloq_wms/domain/rotulo_empaque.dart';

void main() {
  final logo =
      File('assets/images/logo_quiromar_vector_bn.svg').readAsBytesSync();
  final regular = ByteData.sublistView(
    File('assets/fonts/LiberationSans-Regular.ttf').readAsBytesSync(),
  );
  final bold = ByteData.sublistView(
    File('assets/fonts/LiberationSans-Bold.ttf').readAsBytesSync(),
  );
  RotuloEmpaque rotulo(int numero, {double peso = 2}) => RotuloEmpaque(
    numero: numero,
    destinatario: {
      'nombre': 'Cliente',
      'direccion': 'Calle 1',
      'ciudad': 'Bogotá',
      'sede': 'Principal',
    },
    oc: 'OC 123',
    empacadoPor: 'Operario',
    tipoEmpaque: 'CAJA',
    pesoBrutoKg: peso,
    productos: [ProductoRotulo('Camisa', 'M', numero, op: '26241')],
  );
  int paginas(Uint8List bytes) =>
      RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length;
  test(
    'Tres empaques generan un solo PDF con tres páginas independientes',
    () async {
      final bytes = await crearRotulosEmpaquePdf(
        [rotulo(1), rotulo(2), rotulo(3)],
        logo: logo,
        fuenteRegular: regular,
        fuenteNegrita: bold,
      );
      expect(latin1.decode(bytes).startsWith('%PDF-'), isTrue);
      expect(paginas(bytes), 3);
    },
  );
  test('La generación individual conserva una página', () async {
    expect(
      paginas(
        await crearRotuloEmpaquePdf(
          rotulo(1),
          logo: logo,
          fuenteRegular: regular,
          fuenteNegrita: bold,
        ),
      ),
      1,
    );
  });
  test(
    'El lote vacío o un empaque inválido no produce un PDF parcial',
    () async {
      for (final lote in [
        <RotuloEmpaque>[],
        [rotulo(1), rotulo(2, peso: 0)],
      ]) {
        await expectLater(
          crearRotulosEmpaquePdf(
            lote,
            logo: logo,
            fuenteRegular: regular,
            fuenteNegrita: bold,
          ),
          throwsFormatException,
        );
      }
    },
  );
}
