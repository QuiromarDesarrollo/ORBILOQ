/// Contenido real del QR impreso en la marquilla de cada prenda:
/// `url;OP;Código;Descripción;Cliente;NO.OC;ID`
///
/// - El primer segmento (URL) y el último (ID de etiqueta) se ignoran.
/// - La talla NO viene como campo separado: ya está incluida como texto
///   dentro de "Descripción" (ej. "...N/A T. ESPECIAL"), y no se necesita
///   parsearla porque el Código ya identifica la línea exacta (OP + Código
///   es única dentro del Excel de origen).
/// - Descripción, Cliente y NO. OC se guardan como validación cruzada:
///   si no coinciden con lo que hay en la base de datos para esa OP+Código,
///   la pantalla puede advertir una inconsistencia sin bloquear el escaneo.
class QrPrenda {
  const QrPrenda({
    required this.op,
    required this.codigo,
    required this.descripcion,
    required this.cliente,
    required this.noOc,
  });

  final String op;
  final String codigo;
  final String descripcion;
  final String cliente;
  final String noOc;

  static const formato = 'url;OP;Código;Descripción;Cliente;NO.OC;ID';

  /// Devuelve `null` si el QR no cumple el formato mínimo esperado.
  static QrPrenda? tryParse(String raw) {
    final p = raw.split(';').map((e) => e.trim()).toList();
    // Se requieren al menos: url, OP, Código, Descripción, Cliente, NO.OC (6).
    // El ID final de la etiqueta (posición 6) es opcional / se ignora si viene.
    if (p.length < 6) return null;
    final op = p[1];
    final codigo = p[2];
    if (op.isEmpty || codigo.isEmpty) return null;
    return QrPrenda(
      op: op,
      codigo: codigo,
      descripcion: p.length > 3 ? p[3] : '',
      cliente: p.length > 4 ? p[4] : '',
      noOc: p.length > 5 ? p[5] : '',
    );
  }
}
