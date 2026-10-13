import 'dart:io';
import 'dart:typed_data';
import 'package:orbiloq_wms/data/rotulo_empaque_pdf.dart';
import 'package:orbiloq_wms/domain/rotulo_empaque.dart';

Future<void> main() async {
  final regular = ByteData.sublistView(
    await File('assets/fonts/LiberationSans-Regular.ttf').readAsBytes(),
  );
  final bold = ByteData.sublistView(
    await File('assets/fonts/LiberationSans-Bold.ttf').readAsBytes(),
  );
  final logo =
      await File('assets/images/logo_quiromar_vector_bn.svg').readAsBytes();
  for (final cantidad in [1, 9, 24]) {
    final rotulo = RotuloEmpaque(
      numero: 1,
      tipoEmpaque: cantidad == 1 ? 'Paquete' : 'Caja',
      pesoBrutoKg: 10.5,
      destinatario: {
        'nombre': 'CLIENTE DE EJEMPLO S.A.S.',
        'ciudad': 'BARRANQUILLA',
        'sede': 'SEDE NORTE · BODEGA PRINCIPAL',
        'direccion':
            'Carrera 50 # 29B - 19 Sur, bodega 2, entrada por portería principal',
      },
      oc: 'OC-5153',
      empacadoPor: 'ANDREA · EJEMPLO',
      productos: List.generate(
        cantidad,
        (i) => ProductoRotulo(
          i == 10
              ? 'CHAQUETA IMPERMEABLE CON REFLECTIVOS Y BOLSILLOS EXTERIORES PARA OPERACIÓN LOGÍSTICA'
              : 'CAMISA MANGA LARGA ${i + 1}',
          ['S / 8', 'M / 10', 'L / 12'][i % 3],
          i + 1,
          op: '${90003 + i}',
        ),
      ),
    );
    final bytes = await crearRotuloEmpaquePdf(
      rotulo,
      logo: logo,
      fuenteRegular: regular,
      fuenteNegrita: bold,
    );
    await Directory('output/pdf').create(recursive: true);
    await File('output/pdf/rotulo_integrado_$cantidad.pdf').writeAsBytes(bytes);
  }
}
