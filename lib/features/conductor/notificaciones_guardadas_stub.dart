final _memoria = <String, String>{};
String? leer(String clave) => _memoria[clave];
void guardar(String clave, String valor) {
  _memoria[clave] = valor;
}
