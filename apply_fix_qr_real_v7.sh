#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Arregla de verdad el parser del QR (v7)
# Este archivo se me habia quedado pendiente de enviar por error.
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_fix_qr_real_v7.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi

echo "Aplicando el arreglo real del parser de QR..."

echo "  - lib/domain/qr_prenda.dart"
mkdir -p "$(dirname 'lib/domain/qr_prenda.dart')"
cat > 'lib/domain/qr_prenda.dart' << 'ORBILOQ_EOF'
/// Contenido real del QR impreso en la marquilla de cada prenda:
/// `<url>?OP;Código;Descripción;Cliente;NO.OC;ID`
///
/// Ejemplo real:
///   https://www.atom.bio/grupoquiromarsas?25079;202674809;BLUSA...;TV COLOMBIA DIGITAL;PEDIDO AGOSTO;ID0016
///
/// - Todo lo que viene ANTES del primer `?` es la URL del sistema origen y se
///   descarta. El OP queda pegado justo después del `?`, sin punto y coma de
///   por medio — por eso se corta ahí, no por ';'.
/// - El último segmento (ID de la etiqueta) se ignora.
/// - La talla NO viene como campo separado: ya está incluida como texto
///   dentro de "Descripción" (ej. "...T. S/8"), y no se necesita parsearla
///   porque el Código ya identifica la línea exacta (OP + Código es única).
/// - Descripción, Cliente y NO. OC se guardan como validación cruzada.
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

  static const formato = 'url?OP;Código;Descripción;Cliente;NO.OC;ID';

  /// Devuelve `null` si el QR no cumple el formato mínimo esperado.
  static QrPrenda? tryParse(String raw) {
    final texto = raw.trim();
    if (texto.isEmpty) return null;

    // Todo lo anterior al primer '?' es la URL del sistema; se descarta.
    final posInterrogacion = texto.indexOf('?');
    var contenido = posInterrogacion == -1 ? texto : texto.substring(posInterrogacion + 1);

    // Tolerancia: si alguna variante trae un ';' extra justo después del '?'
    // (formato antiguo que se mencionó en algún momento), se ignora.
    while (contenido.startsWith(';')) {
      contenido = contenido.substring(1);
    }

    final p = contenido.split(';').map((e) => e.trim()).toList();
    // Se requieren al menos: OP, Código, Descripción, Cliente, NO.OC (5).
    // El ID final de la etiqueta es opcional / se ignora si viene.
    if (p.length < 5) return null;
    final op = p[0];
    final codigo = p[1];
    if (op.isEmpty || codigo.isEmpty) return null;
    return QrPrenda(
      op: op,
      codigo: codigo,
      descripcion: p.length > 2 ? p[2] : '',
      cliente: p.length > 3 ? p[3] : '',
      noOc: p.length > 4 ? p[4] : '',
    );
  }
}
ORBILOQ_EOF

echo ""
echo "Listo. Siguiente paso:"
echo "  flutter analyze"
echo "  flutter test   (deberian pasar las 11)"
