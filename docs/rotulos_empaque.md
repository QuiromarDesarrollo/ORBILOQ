# Destinatario y rótulos al empacar

## Activación en pruebas

Aplicar `sql/pruebas/082_destinatario_antes_empaque.sql` completo en ORBILOQ-DEV, después de 081, y actualizar la aplicación con estos cambios. No se aplicó a Supabase desde esta tarea. No ejecutar esta migración en producción ni reinstalar 081 encima: sus permisos anteriores permitirían omitir el destinatario.

## Uso

1. En Despacho, seleccionar destinatario/sede antes de distribuir prendas.
2. Seleccionar cliente de las órdenes, OC y OP, y distribuir las prendas entre las piezas físicas. Se puede compartir una pieza entre tallas.
3. Generar el rótulo de cada pieza. El PDF es de 100 × 100 mm; imprimir al 100 %, sin ajustar al tamaño de una hoja A4. Se descarga para abrirlo e imprimirlo en la impresora configurada.
4. Confirmar empaque para guardar y reservar las prendas. Descargar rótulos no guarda un borrador: cerrar sin confirmar pierde la distribución nueva.
5. Seguimiento revisa el destinatario conservado y confirma la salida y la LE. Para cambiarlo se debe regresar a Corregir despacho, reempacar y reemplazar los rótulos afectados.

Los rótulos muestran el logo QUIROMAR aprobado, remitente, destinatario, OC, ciudad, descripción, talla, cantidad y empacador. No incluyen observación, QR ni serial. El total de `PIEZA N DE ____` queda vacío. Si el contenido requiere varios rótulos, todos conservan el mismo número de pieza y tienen su propio contador de páginas. La cantidad aparece una sola vez si una descripción excepcionalmente larga necesita continuar en otra página.

Si cambia una pieza después de descargar su rótulo en la misma sesión, se indica que debe regenerarse antes de confirmar. Al corregir un empaque ya guardado se deben reemplazar sus rótulos impresos. El destinatario y su versión se validan en servidor, se guardan junto al empaque y se conservan en la LE aunque el catálogo cambie posteriormente. Las LE anteriores sin destinatario guardado mantienen la selección en Seguimiento por compatibilidad.

## Validación

`tools/ensayar_lista_empaque.ps1` ensaya las migraciones y las pruebas SQL en PostgreSQL local desechable, incluyendo 082 dos veces y `tools/test_destinatario_empaque.sql`. Las pruebas verifican destinatario obligatorio, versión vigente, idempotencia, reservas, corrección de destinatario manteniendo LE y contador, y rechazo de cambios de destinatario fuera de la corrección.

`tools/preview_rotulo.dart` genera muestras de 9 y 24 productos con el generador real. La segunda incluye descripción larga y continúa en varias páginas. Las muestras se verificaron visualmente y su tamaño es 100 × 100 mm. La impresión física en la térmica del usuario queda por comprobar.

## Idea futura, no implementada

Identificador único por pieza física vinculado a su LE, con lectura para verificar empaque, entrega y trazabilidad. Reimpresiones de una misma pieza conservarían su identidad; las correcciones tendrían control de versión para detectar rótulos desactualizados. Definir formato, lector y compatibilidad logística antes de implementar. Por decisión del usuario, esta entrega no añade QR, códigos de barras ni serial shipping.
