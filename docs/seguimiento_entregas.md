# Seguimiento de despachos liberados

Aplicar `sql/pruebas/084_seguimiento_entregas.sql` completo en ORBILOQ-DEV después de 082 y actualizar la aplicación. No aplicado remotamente desde esta tarea.

La pestaña Seguimiento contiene «Por liberar» y «Despachos liberados». Al confirmar la salida, se abre la segunda sección: una tabla con búsqueda por LE/cliente y desplazamiento horizontal. La descarga del PDF sigue disponible en el diálogo de confirmación y en Historial.

La LE y las piezas se leen del documento emitido: se cuenta una vez cada número de empaque, aunque contenga varias tallas. Se muestran cajas, empaques y su suma. La fecha de despacho corresponde a la liberación registrada por el servidor, presentada en horario de Colombia.

Cada fila permite escribir transportadora (incluyendo QUIROMAR), placa o guía, fecha de recibido, observaciones y adjuntar una evidencia LE y una evidencia de guía. Los campos son opcionales y se guardan con «Guardar» por fila. Se puede guardar parcialmente y completar después. El calendario y servidor validan que recibido esté entre despacho y hoy.

Las evidencias aceptan PDF, JPG, PNG o WebP hasta 10 MB. Se almacenan en el bucket privado `seguimiento-evidencias`; los enlaces para abrirlas caducan a los cinco minutos. «Reemplazar» sube un archivo nuevo sin sobrescribir el anterior. El vínculo a la LE se confirma al guardar la fila. Los archivos subidos que no se guarden y las versiones reemplazadas se conservan en Storage; la limpieza de esos archivos no está automatizada. No se afirma haber probado la carga contra el Storage remoto ni una impresión física.

Si dos usuarios editan la misma fila, el segundo guardado con versión antigua se rechaza para evitar sobrescribir cambios. Actualizar advierte si hay datos sin guardar; cambiar entre las dos secciones conserva los campos. Antes de cerrar el diálogo, guardar las filas pendientes.

Una corrección del empaque retira temporalmente la LE de liberados. Al liberarla nuevamente se conserva su número pero comienza un seguimiento de la nueva revisión; el anterior permanece en la base como antecedente, sin mezclar fechas o evidencias. Historial conserva el flujo existente de consulta/corrección. El SQL de reinicio 083 se amplió para respaldar y retirar esta nueva tabla si existe.

Validación: pruebas Flutter de tabla y despacho, y `tools/ensayar_seguimiento_entregas.ps1` en PostgreSQL local con interfaz de Storage simulada. Este ensayo comprueba migración repetible, permisos de evidencias, conteo de piezas, versión de edición, fechas, archivo inexistente, corrección/reliberación y reinicio operacional. No toca Supabase.

## Vista de tarjetas (actualización visual)

Despachos liberados presenta tarjetas adaptables de una a tres columnas. Cada tarjeta abre un formulario compacto de hasta 760 px, con dos columnas en escritorio y una en pantallas pequeñas, cabecera y Guardar visibles; el contenido central puede desplazarse en pantallas de poca altura. El formulario conserva borradores al cerrarse dentro de la misma ventana y las tarjetas los señalan como cambios sin guardar.

La búsqueda por LE/cliente se combina con un rango inclusivo de fechas de recibido. Un rango excluye las LE sin fecha de recibido; quitarlo vuelve a incluirlas. Es posible seleccionar el mismo día en ambos extremos. Esta actualización visual reutiliza SQL 084 y no necesita otra migración.

## Estados de envío

Aplicar 085 en DEV después de 084. Las tarjetas y el formulario muestran En tránsito, Entregado o Devuelto por el cliente. Los cambios se guardan junto con los demás datos y respetan la versión de edición. Las filas anteriores con fecha de recibido se inicializan como Entregado; las demás como En tránsito. Después, el estado se elige explícitamente.

Devuelto por el cliente es un estado del envío: no incrementa existencias ni altera el despacho. El reingreso físico requiere un flujo separado de devolución por LE, OP/talla, cantidades, causa y ubicación, con recepción de Bodega y control de cantidades previamente devueltas. Ese formulario de reingreso no forma parte de este cambio de estados.

## Devoluciones parciales, filtro y adjuntos opcionales

Aplicar 086 después de 085 para habilitar Devolución parcial. Este estado indica que solo parte de las prendas despachadas regresó; Entrega parcial describe una entrega todavía incompleta y no sustituye el registro de devolución. Los estados continúan siendo informativos y no generan entradas de inventario.

El filtro de estado se combina con búsqueda por LE/cliente y fecha de recibido. Todos los estados permite retirar ese filtro. Quitar adjunto deja la evidencia vacía en el formulario; Guardar confirma su desvinculación de la LE. Ambas evidencias son opcionales. Los archivos permanecen privados en Storage según la política de conservación existente; quitar un adjunto no elimina físicamente su archivo.
