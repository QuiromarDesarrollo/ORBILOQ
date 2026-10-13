import 'dart:convert';

class ProductoRotulo {
  const ProductoRotulo(
    this.descripcion,
    this.talla,
    this.cantidad, {
    required this.op,
  });
  final String descripcion, talla, op;
  final int cantidad;
  Map<String, dynamic> toJson() => {
    'op': op,
    'descripcion': descripcion,
    'talla': talla,
    'cantidad': cantidad,
  };
}

class RotuloEmpaque {
  const RotuloEmpaque({
    required this.numero,
    required this.destinatario,
    required this.oc,
    required this.empacadoPor,
    required this.productos,
    required this.tipoEmpaque,
    required this.pesoBrutoKg,
  });
  final int numero;
  final Map<String, dynamic> destinatario;
  final String oc, empacadoPor, tipoEmpaque;
  final double pesoBrutoKg;
  final List<ProductoRotulo> productos;
  String get firma => jsonEncode({
    'numero': numero,
    'destinatario': destinatario,
    'oc': oc,
    'empacadoPor': empacadoPor,
    'tipoEmpaque': tipoEmpaque,
    'pesoBrutoKg': pesoBrutoKg,
    'productos': productos.map((p) => p.toJson()).toList(),
  });
}
