import 'models.dart';

/// Contenido del QR de una prenda: `OP;CLIENTE;CÓDIGO;DESCRIPCIÓN;TALLA;OC`.
class QrPrenda {
  const QrPrenda({
    required this.op,
    required this.cliente,
    required this.codigo,
    required this.descripcion,
    required this.talla,
    required this.oc,
  });

  final String op;
  final String cliente;
  final String codigo;
  final String descripcion;
  final String talla;
  final String oc;

  String get itemId => buildItemId(op, oc, codigo, talla);

  static const formato = 'OP;CLIENTE;CÓDIGO;DESCRIPCIÓN;TALLA;OC';

  /// Devuelve `null` si el QR no cumple el formato.
  static QrPrenda? tryParse(String raw) {
    final p = raw.split(';').map((e) => e.trim()).toList();
    if (p.length < 6 || p.take(6).any((e) => e.isEmpty)) return null;
    return QrPrenda(
      op: p[0],
      cliente: p[1],
      codigo: p[2],
      descripcion: p[3],
      talla: p[4],
      oc: p[5],
    );
  }
}
