# Continuidad de procesos ante recargas

Implementación del 30 de octubre de 2026. El borrador no confirma operaciones, no mueve inventario ni vuelve a ejecutar solicitudes al recuperarse.

## Alcance implementado

| Flujo | Información conservada |
| --- | --- |
| Producción, entrega QR y manual | Tarjetas por identificador, cantidades escritas, conteo y texto de búsqueda |
| Recepción de Bodega | Línea abierta, cantidades, conteos, orden de tarjetas, estante, nota y solicitud de recepción |
| No conformes de Bodega, QR y manual | Tarjetas, cantidades, causal, persona que entregó, notas y búsqueda |
| Reproceso | Cantidades por prenda, persona receptora y filtro de OP |
| Operación de Inventario | Cantidad, motivo, OC, peso, destino, empaque, estante y solicitud; separado por operación y registro |
| Masiva | Sección, operación, búsqueda, lista, kit seleccionado, datos de empaque y tarjetas de recepción pendientes |
| Despacho | Copia local automática del paso, destino, selección de OP, empaques, cantidades, pesos y solicitud; se contrasta con la versión del borrador remoto |

Transporte conserva su mecanismo previo de borradores con evidencias en IndexedDB. No se cambió su almacenamiento.

## Uso y límites

Al actualizar, entrar con el mismo usuario y volver a abrir el mismo proceso/pestaña recupera su borrador. No se reabre automáticamente el modal ni se restaura toda la navegación de la aplicación. Las nuevas copias locales pertenecen al mismo navegador y origen; no sustituyen el guardado remoto de Despacho para cambiar de equipo. Cambiar de host/puerto, usar incógnito o eliminar los datos del sitio impide recuperar esa copia.

El almacenamiento separa entorno, usuario y proceso. Para formularios pequeños en web la escritura es síncrona en cada cambio, sin esperar al cierre. No almacena contraseñas ni autorizaciones. La recuperación usa referencias a registros existentes; los permisos y validaciones del servidor siguen siendo obligatorios al confirmar. Los fallos al leer o guardar bloquean la continuación y muestran Reintentar.

Una recarga durante un envío deja una advertencia y exige revisar el historial antes de continuar. No debe considerarse una implementación de idempotencia para endpoints que no la tenían. Recepción, Inventario y Despacho conservan sus identificadores de solicitud. Los cambios confirmados se retiran del borrador. En Despacho, No guardar descarta la copia local y conserva el último guardado remoto; una versión remota más nueva tiene prioridad.

No hay una captura genérica de todos los formularios del sistema: importaciones de archivos, edición administrativa, Seguimiento/Facturación y No Conformes de Aliados no reciben persistencia nueva en este cambio. Su incorporación requiere tratar sus archivos y solicitudes concretas, sin guardar accidentalmente acciones ya confirmadas.

## Verificación

- 52 pruebas de regresión en Producción, Recepción, Masiva, Despacho, Reproceso, No Conformes e Inventario pasaron.
- Producción conserva cantidades al desmontar y reconstruir la pantalla en 320, 768 y 1440 px; no crea lotes por recuperar el borrador. Se revisó captura de 320 px con acción principal accesible.
- Dos pruebas del mecanismo común verifican aislamiento entre usuarios/entornos, bloqueo de envíos inciertos, limpieza y recuperación de error de almacenamiento.
- Se añadió una regresión de Producción que confirma un lote en memoria y comprueba que no reaparezca como pendiente al volver a abrir.
- La prueba adicional en Chrome del almacenamiento síncrono quedó detenida durante la carga del runner y fue cancelada. No se declara verificada una pulsación real de F5 en navegador; la recuperación de las pantallas se comprobó mediante reconstrucción de widgets.
- Las pruebas usan datos ficticios y repositorios de prueba; no se ejecutaron movimientos reales para verificarlas.
- No requiere SQL nuevo. El cliente se compila con `.env.pruebas.json` validando el host de ORBILOQ-DEV. Una compilación local no equivale a publicar producción.
