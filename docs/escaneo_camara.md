# Cámara en móviles y tablets

En los formularios de escaneo, pulsar **Escanear con cámara** y permitir el
acceso. La cámara permanece abierta. La tarjeta superior informa el resultado
real del formulario: conteo acumulado, selección, búsqueda o error.

En Entregas de Producción, Recepción y No Conforme las lecturas se acumulan en
las tarjetas existentes. **Ver tarjetas** cierra la cámara y conserva los datos.
El movimiento se guarda únicamente con los botones de confirmación existentes.
En Reproceso y Aliados el escaneo conserva su función de buscar/seleccionar una
prenda; no convierte esos formularios individuales en operaciones masivas.
En Despacho se pueden seleccionar varias OP de la misma OC, sin sobrescribir
otra orden que ya tenga OP seleccionadas.

Un mismo contenido QR se procesa una vez por sesión para evitar el conteo de
cada fotograma. Para contar otra unidad con exactamente el mismo código, pulsar
**Releer mismo código** y enfocar la etiqueta. Etiquetas con diferentes ID se
detectan como nuevas lecturas aunque pertenezcan a una misma OP.
Si aparecen varias etiquetas simultáneas, enfocar solo una.

**Pausar** libera la cámara temporalmente; **Continuar** la vuelve a abrir.
Cerrar el escáner libera la cámara. El componente de cámara gestiona la pausa
cuando la aplicación pasa a segundo plano. Se mantienen el lector físico y el
ingreso manual como alternativas.

## Publicación y validación

- La app web debe abrirse por **HTTPS** (localhost sirve para desarrollo).
  Un móvil que abra una IP local por HTTP normalmente no tendrá acceso a cámara.
- Dependencia: [mobile_scanner](https://pub.dev/packages/mobile_scanner).
  Requiere Flutter 3.29 o superior y Dart 3.7 o superior.
  Su implementación web puede descargar el decodificador al iniciar; comprobar
  que la red de la empresa permite esa descarga.
- No requiere SQL, cambios de esquema ni credenciales nuevas de Supabase.
- Validar en un Android y un iPhone/iPad reales: permiso aceptado/rechazado,
  varias OP, etiqueta inmóvil, repetición explícita, límite alcanzado, pausa,
  retorno desde segundo plano y cierre con las cantidades conservadas.
- El repositorio actualmente distribuye web/Windows. El botón de cámara se
  ofrece en web y plataformas móviles compatibles; no en Windows nativo.
  Si en el futuro se crea una aplicación iOS nativa, configurar
  `NSCameraUsageDescription` según la documentación del paquete.
