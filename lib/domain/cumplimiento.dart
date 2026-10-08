import 'models.dart';

enum ResultadoCumplimiento { aTiempo, conRetraso, pendiente, vencido, sinDatos }

/// Clasificación y días numéricos independientes del texto de presentación.
class Cumplimiento {
  const Cumplimiento(this.resultado, this.diasDesviacion, this.detalle);
  final ResultadoCumplimiento resultado;
  /// Fecha real (completa) o día actual (pendiente), menos fecha esperada.
  /// Negativo = antes; positivo = después. Null = no evaluable.
  final int? diasDesviacion;
  final String detalle;

  static Cumplimiento calcular({required bool completa,
    required DateTime? esperada, required DateTime? real, DateTime? hoy}) {
    if (esperada == null) {
      return const Cumplimiento(ResultadoCumplimiento.sinDatos, null, 'Sin fecha esperada');
    }
    if (completa && real == null) {
      return const Cumplimiento(ResultadoCumplimiento.sinDatos, null, 'Sin fecha de entrega');
    }
    final referencia = completa ? real! : hoy ?? DateTime.now();
    // Días calendario, sin diferencias de hora ni horario de verano.
    final dias = DateTime.utc(referencia.year, referencia.month, referencia.day)
        .difference(DateTime.utc(esperada.year, esperada.month, esperada.day)).inDays;
    final cantidad = '${dias.abs()} ${dias.abs() == 1 ? 'día' : 'días'}';
    if (completa) {
      return Cumplimiento(dias <= 0 ? ResultadoCumplimiento.aTiempo : ResultadoCumplimiento.conRetraso,
        dias, dias == 0 ? 'Entregado en fecha' : 'Entregado $cantidad ${dias < 0 ? 'antes' : 'tarde'}');
    }
    return Cumplimiento(dias > 0 ? ResultadoCumplimiento.vencido : ResultadoCumplimiento.pendiente,
      dias, dias == 0 ? 'Vence hoy' : dias > 0 ? 'Vencido $cantidad' : 'Faltan $cantidad');
  }
}

extension CumplimientoKardex on ItemKardex {
  Cumplimiento cumplimientoProduccion({DateTime? hoy}) => Cumplimiento.calcular(
    completa: cantidadPedida > 0 && pendienteProduccion == 0,
    esperada: fechaEsperadaProduccion, real: fechaEntrega, hoy: hoy);
  Cumplimiento cumplimientoLogistica({DateTime? hoy}) => Cumplimiento.calcular(
    completa: cantidadPedida > 0 && pendienteDespacho == 0,
    esperada: fechaEsperadaLogistica, real: fechaDespacho, hoy: hoy);
}
