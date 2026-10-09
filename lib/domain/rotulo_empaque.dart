import 'dart:convert';

class ProductoRotulo {
  const ProductoRotulo(this.descripcion, this.talla, this.cantidad);
  final String descripcion, talla;
  final int cantidad;
  Map<String, dynamic> toJson() => {
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
  });
  final int numero;
  final Map<String, dynamic> destinatario;
  final String oc, empacadoPor;
  final List<ProductoRotulo> productos;
  String get firma => jsonEncode({
    'numero': numero,
    'destinatario': destinatario,
    'oc': oc,
    'empacadoPor': empacadoPor,
    'productos': productos.map((p) => p.toJson()).toList(),
  });
}
