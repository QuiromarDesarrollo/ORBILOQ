import 'package:orbiloq_wms/domain/rotulo_empaque.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/data/empaques_repository.dart';

void main() {
  test('Cambiar peso o tipo invalida la firma del rótulo impreso', () {
    RotuloEmpaque rotulo(double peso, String tipo) => RotuloEmpaque(
      numero: 1,
      destinatario: {'sede': 'Norte'},
      oc: 'OC1',
      empacadoPor: 'Ana',
      productos: [const ProductoRotulo('Camisa', 'M', 2, op: '90005')],
      tipoEmpaque: tipo,
      pesoBrutoKg: peso,
    );
    expect(rotulo(10, 'Caja').firma, rotulo(10, 'Caja').firma);
    expect(rotulo(10, 'Caja').firma, isNot(rotulo(12, 'Caja').firma));
    expect(rotulo(10, 'Caja').firma, isNot(rotulo(10, 'Paquete').firma));
  });
  test('Peso bruto obligatorio y compatible con decimales de usuario', () {
    expect(validarPesoBruto('10,5', .5), 10.5);
    expect(validarPesoBruto('0.5', .5), .5);
    for (final valor in ['', 'NaN', 'Infinity', '-1', '0', '0.4', '100001']) {
      expect(() => validarPesoBruto(valor, .5), throwsFormatException);
    }
  });
  test(
    'Nombres históricos se muestran como paquetes sin cambiar otras palabras',
    () {
      expect(
        textoEmpaque('BOLSA · Bolsa grande · bolsas'),
        'PAQUETE · Paquete grande · paquetes',
      );
      expect(textoEmpaque('Caja de bolsillo'), 'Caja de bolsillo');
    },
  );
}
