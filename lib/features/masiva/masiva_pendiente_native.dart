final _pendientes = <String, String>{};
String? leerPendienteMasiva(String usuario) => _pendientes[usuario];
void guardarPendienteMasiva(String usuario, String? valor) {
  if (valor == null) {
    _pendientes.remove(usuario);
  } else {
    _pendientes[usuario] = valor;
  }
}
