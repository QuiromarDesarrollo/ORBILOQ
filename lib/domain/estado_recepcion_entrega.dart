enum EstadoRecepcionEntrega {
  pendiente('Pendiente por recibir'),
  parcial('Recibido parcial'),
  completado('Completado');

  const EstadoRecepcionEntrega(this.etiqueta);
  final String etiqueta;

  static EstadoRecepcionEntrega calcular(int enviadas, int recibidas) {
    if (enviadas > 0 && recibidas >= enviadas) return completado;
    return recibidas > 0 ? parcial : pendiente;
  }
}
