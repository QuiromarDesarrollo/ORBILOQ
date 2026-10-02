# Edición administrativa — v55, solo pruebas

## Decisión del propietario

Trabajar en `master` y aplicar cambios de base de datos **únicamente en DEV**.
**Prioridad: no perder ningún dato de producción.** No desplegar ahora ni
sincronizar producción con DEV. Cuando se autorice el despliegue, generar un
script independiente a partir de un inventario actualizado de producción.

El archivo `055_edicion_admin.sql` es exclusivo del proyecto de pruebas
`igfuafcekcpugpmsoqbe`. Se preparó con el informe de estructura `(15)` del
1 de octubre de 2026. Rechaza una base que tenga `clientes` o
`devoluciones_cliente`, presentes en el informe de producción `(16)`.
Esta comprobación de estructura es una protección adicional: **verificar
siempre el proyecto seleccionado en el SQL Editor**; no identifica el servidor.

## Aplicación en DEV

1. Seleccionar el proyecto de pruebas en Supabase.
2. Ejecutar todo `055_edicion_admin.sql` en una sola ejecución. Usa transacción
   y puede repetirse. Ante un error, no continuar con fragmentos sueltos.
   Después aplicar `057_corregir_total_sin_lote.sql`. Si 055 o 056 ya están
   instalados, ejecutar únicamente 057. El 056 queda como versión histórica.
   No volver a aplicar 055/056 después de 057: restaurarían reglas anteriores.
3. Actualizar la app local de `master`, apuntando a DEV.
4. Probar con cuentas activas de administrador, Producción y Logística.
5. El SQL Editor debe confirmar éxito antes de considerar la función habilitada.

No se han incorporado credenciales ni un mecanismo de ejecución remota al repo.
Las pruebas automatizadas usan una base PostgreSQL embebida y desechable; no
sustituyen la aceptación con las cuentas y datos de DEV.

## Comportamiento

- Cada celda muestra un lápiz únicamente al administrador, en ambas vistas.
- Se introduce el **total deseado de la fila**, no el incremento.
- La corrección de entregado actúa sobre el total de la fila, sin elegir,
  crear ni modificar lotes. Recepción mantiene su selección de lote; recepción,
  despacho y PNC requieren ubicación.
- Pendientes, estados y días abren el editor de sus datos de origen; no se
  almacenan como valores independientes de las reglas del kardex.
- OP, cliente y fechas esperadas pertenecen a la OP completa. El formulario
  advierte cuántas filas comparten el dato. Código, talla, descripción, OC,
  observación y cantidad pertenecen a la línea; los UUID se conservan.
- La fecha de entrega admite una corrección explícita, incluso quitarla,
  conservando las fechas de los movimientos originales. La corrección tiene
  prioridad sobre la fecha calculada hasta que el admin vuelva a editarla.
- Se revisa una vista previa calculada por el servidor y después se confirma.
  Un token de versión rechaza confirmaciones con información obsoleta, también
  después de una operación exitosa cuya respuesta se haya perdido.
- Todo cambio exige motivo. El historial muestra los últimos 20; el registro
  completo permanece en `admin_correcciones`, con antes/después, actor, lote y
  ubicación. No se borran ni se sobrescriben movimientos del ledger.

## Cambios de base registrados

- Tabla `admin_correcciones`, índices y RLS de consulta para administradores.
- Columnas `items_orden.admin_fecha_entrega`, `admin_fecha_entrega_activa` y
  `movimientos.admin_correccion_id`.
- Las correcciones insertan movimientos con signo del tipo operativo existente,
  vinculados a la auditoría; las operaciones ordinarias siguen siendo positivas.
  Una restricción `NOT VALID` preserva posibles registros históricos inválidos,
  pero se aplica a toda escritura nueva. Revisar los antiguos antes de validarla.
- RPC `admin_es_admin`, `admin_contexto_edicion` y `admin_editar_kardex`.
  Solo cuentas activas con rol admin pueden acceder a las dos últimas.
- Políticas restrictivas impiden que un usuario cambie su propio rol, que un
  cliente inserte/modifique movimientos de corrección directamente y que un
  usuario operativo actualice los datos maestros editables.
- `vista_kardex` conserva las columnas y fórmulas del informe DEV, añadiendo el
  tratamiento de fecha corregida. `vista_stock_ubicacion_detalle` descuenta
  devoluciones con ubicación. `despachar` comprueba ese stock y el saldo global.
- Las RPC de inventario/importación adquieren un bloqueo común **antes** de
  calcular saldos. La corrección es atómica y evita carreras con esas RPC.
  Este bloqueo serializa escrituras en las tablas WMS; tiene espera máxima de
  cinco segundos. Medir con carga DEV antes de aprobarlo para producción.
- Se añaden las tablas maestras a `supabase_realtime` si la publicación existe.

## Corrección del total sin lote (v57, vigente)

El total entregado puede aumentarse o reducirse, incluso a cero, sin depender
de la cantidad de ningún lote. Se agrega un movimiento firmado de entrega,
vinculado a la auditoría y con `lote_id`/`lote_item_id` nulos. No se alteran
lotes, líneas, recepciones, despachos ni existencias por ubicación. Los totales
de los lotes históricos pueden diferir del total corregido; la diferencia
queda explicada por el ajuste administrativo. Afecta solo el producto/talla
de la fila seleccionada, no todos los productos de la OP.

Ejemplo: entregado 10 -> 2 agrega -8 al ledger y recalcula el pendiente.
Se mantienen los límites de cantidades enteras no negativas y de lo pedido,
el motivo obligatorio, los permisos de administrador y la validación de versión.
No modifica retroactivamente correcciones de v55/v56 ya guardadas.

## Corrección independiente de entrega (v56, histórica; sustituida por v57)

Por petición del propietario, el administrador puede reducir el entregado
aunque ya haya más unidades recibidas. Ejemplo: total 28 a 20 aplica -8 al
lote seleccionado; si este tenía enviado 25 y recibido 25, queda enviado 17,
recibido 25 y estado `recibido_con_novedad`. El pendiente de la fila se
recalcula con el entregado 20. Recepciones, despachos y stock no cambian.
La vista previa explica la diferencia, y se conserva el historial completo.
Las demás correcciones pueden conservar o reducir una diferencia ya existente,
pero no incrementarla. El SQL 056 es únicamente de DEV; no ejecutarlo en producción.

## Casos que se rechazan deliberadamente

- Saldos negativos y despachar más de lo recibido/pedido. La entrega corregida
  sí puede quedar por debajo de lo recibido, según la regla v56.
- Reducir una recepción o despacho en una ubicación donde no hay suficiente
  cantidad registrada de esa operación.
- Modificar recepciones de un lote cerrado con faltante definitivo sin
  conciliar primero ese cierre. El total entregado ya no está sujeto a un lote.
- Reducir PNC histórico sin ubicación usando un estante supuesto. Esos eventos
  requieren conciliación explícita previa; no se reparte inventario por defecto.
- Editar cantidades sobre filas ya inconsistentes con las reglas de validación.
  El mensaje no implica que se hayan perdido datos: la transacción no se guarda.

El informe DEV ya presenta diferencias entre PNC, ubicaciones y Aliados. No se
reescriben silenciosamente movimientos históricos ni se migra el flujo de
Aliados como efecto secundario. El modo memoria conserva sus reglas históricas;
las correcciones nuevas sí ajustan el PNC con ubicación. Validar especialmente
los casos históricos en DEV, no solo filas nuevas.

## Pendiente al autorizar despliegue

- Obtener de nuevo la estructura de producción y confirmar la rama publicada.
- Diseñar la migración específica: conservar `clientes`, `devoluciones_cliente`,
  vistas del ERP, importador rico, columnas, restricciones y datos existentes.
- Revisar la restricción positiva de `movimientos` que existe en producción y
  no en DEV. **Este archivo no la elimina ni constituye una migración compatible
  con producción.** También difieren las fórmulas de las vistas de kardex/stock.
- Coordinar la recepción de cinco parámetros con el nuevo frontend. Mantener
  el hotfix de cuatro parámetros hasta el cambio coordinado. Revisar todas las
  sobrecargas; no borrarlas automáticamente ni copiar funciones DEV al ERP.
- Evaluar escrituras directas del ERP y sus transacciones frente al esquema de
  bloqueos. Las RPC cubiertas no garantizan el comportamiento de integraciones
  externas desconocidas.
- Respaldo recuperable verificado, ensayo con estructura equivalente, registro
  de validaciones antes/después, ventana coordinada y recuperación que preserve
  operaciones registradas después del respaldo. No usar reset ni reemplazo de BD.
- Revisar las políticas históricas de acceso directo: esta migración protege
  las nuevas correcciones, pero no convierte toda la aplicación existente a un
  modelo de escritura exclusivo por RPC.

## Validación local reproducible

Flutter: `flutter analyze` y `flutter test --no-pub`.

SQL: instalar `@electric-sql/pglite@0.3.14` dentro de `.dart_tool/sql-test` con
pnpm; esa carpeta está ignorada y es solo una dependencia de pruebas.
Ejecutar `tools/crear_fixture_sql.ps1 -InformePruebas <ruta-del-csv-15>` y
`node tools/test_admin_sql.mjs`. La herramienta reconstruye estructura sin datos
del informe, agrega registros ficticios y comprueba migración repetida, permisos,
rechazos atómicos y conservación de movimientos originales.


## 058: acciones por fila y borrado lógico (solo DEV)

Con 055 y 057 ya aplicados, ejecutar completo `058_borrado_logico_admin.sql` en el proyecto de PRUEBAS y actualizar la app. No volver a ejecutar 055 después: redefine la vista anterior. El script 058 se puede repetir.

- Un lápiz y una papelera por fila, después de Días faltantes, exclusivos del administrador.
- El lápiz abre el formulario existente con lista de campos.
- La papelera solicita confirmación y motivo. Marca `items_orden.admin_eliminado_en` y registra actor, fecha y valores en `admin_correcciones`.
- Oculta solo esa línea de las dos tablas, sus resúmenes filtrados y exportaciones; no elimina la OP ni otras tallas. Los filtros pueden seguir mostrando valores históricos.
- NO anula operaciones ni existencias: los registros siguen disponibles en los flujos operativos e historiales. No es una cancelación de inventario.
- Se conserva el registro original, por lo que es recuperable. No se incluye todavía un botón de restauración; una recuperación debe hacerse mediante una corrección auditada, nunca reimportando ni borrando movimientos.
- La confirmación verifica una versión del servidor; si alguien cambia la OP o sus operaciones, se debe cerrar y abrir nuevamente.

PRODUCCIÓN: pendiente migración específica y revisión del esquema vigente al autorizar despliegue. No ejecutar estos archivos DEV en producción. No se ha conectado ni modificado ninguna base remota.


## 059: reemplazo de tabla por Excel (solo DEV)

Ejecutar `059_importar_tabla_admin.sql` completo DESPUÉS de 055, 057 y 058. Si ya están aplicados, ejecutar solo 059. No ejecutarlo en producción. Luego recargar la aplicación de master.

1. Administrador: en Producción o Logística, pulsar **Exportar tabla**. Se consultan todas las filas activas directamente al servidor, independientemente de filtros/página.
2. Editar la hoja **Kardex**, conservando encabezados, ID FILA y la hoja **Formato**. Para una fila nueva dejar ID vacío. No reutilizar archivos de la exportación antigua.
3. Volver a la misma vista y pulsar **Importar tabla**, seleccionar el archivo e indicar motivo.
4. **Revisar reemplazo** valida todo el archivo y muestra diferencias sin guardarlas. **Confirmar reemplazo de la tabla** aplica todo dentro de una transacción.

Las OP se comparten entre vistas. Los campos no incluidos en una vista se conservan (por ejemplo, importar Producción no reemplaza recibido/despachado ni fecha esperada de Logística). Cantidad pedida y entregado sí afectan ambas. Los estados, pendientes y días se recalculan; las columnas informativas del Excel se ignoran como entrada.

Correcciones de recibido/despachado/PNC: escribir el código de un estante activo en **UBICACIÓN DEL AJUSTE**. Se aplica allí la diferencia de stock. Las cantidades son los totales deseados por fila; los lotes históricos no cambian. Si una reducción abarca varios estantes, conciliarlos antes: el archivo no distribuye cantidades arbitrariamente. No se eliminan ni se reescriben movimientos anteriores.

Protecciones:
- Solo administrador activo, tanto al exportar como al confirmar en SQL.
- Archivo y vista previa obsoletos se rechazan si hubo cambios desde la exportación.
- IDs repetidos, OP/código/talla duplicados, fechas inválidas y cantidades incompatibles abortan toda la transacción.
- Las filas de una misma OP deben coincidir en cliente, número de OP y fecha esperada.
- Archivo vacío rechazado. **Por ahora un archivo que omita filas activas también se rechaza**: está pendiente definir con el usuario el tratamiento de las ausentes. No hay eliminación implícita.
- Máximo 5000 filas y 20 MB por archivo. Si la tabla supera ese límite, ampliar el flujo antes de usarlo; NO dividir el archivo porque es un reemplazo completo.
- `admin_importaciones` guarda contenido importado, motivo, usuario, versión y resumen. `admin_correcciones` conserva el antes/después y los movimientos nuevos enlazados. No hay restauración automática: cualquier reversión debe conciliar las operaciones posteriores.

No ejecutar 055/056 tras las migraciones posteriores. En producción se requiere un paquete específico, previa comparación del esquema y respaldo; no copiar la base de DEV.

Responsive: menú compacto bajo 1200px, fichas de filas bajo 600px, filtros y resúmenes adaptables, paginación multilínea, formularios que apilan campos/acciones, pestañas desplazables y ajustes de login/teclado.


## 060: administración de catálogos y cuentas (solo DEV)

1. Aplicar manualmente `060_administrar_catalogos.sql` en DEV después de 055, 057, 058 y 059. No repetir migraciones anteriores después: pueden reemplazar protecciones y funciones posteriores.
2. Para **crear cuentas**, desplegar también `supabase/functions/admin-crear-usuario` siguiendo su README. El SQL habilita las demás operaciones; crear Auth requiere esta función de servidor. Ninguna clave privilegiada se entrega a Flutter.
3. Recargar la app y entrar como administrador → **Administración**, disponible en las dos vistas y en el menú compacto.

Catálogos: usuarios, estantes, causales de devolución y personal de Logística, Producción y Aliados. Listas con búsqueda y filtro activo/inactivo, creación, edición, desactivación y reactivación. Guardar requiere confirmación.

- Usuarios: número/contraseña inicial en el alta; luego nombre, rol y estado. El número no se cambia para conservar el identificador de acceso. Los registros históricos sin `auth_id` se identifican como sin cuenta de acceso. No se borran cuentas ni movimientos. No se permite desactivar la propia cuenta ni quitar al último administrador con acceso.
- Una cuenta desactivada puede conservar un JWT, pero las tablas/vistas y RPC del sistema rechazan sus operaciones. El perfil se revalida cada 30 segundos; una sesión abierta vuelve al acceso al detectar la baja. La vista elegida por el administrador se conserva durante la revalidación.
- Las funciones operativas validan también el rol vigente en el servidor: Producción y Logística acceden a sus respectivas operaciones; el administrador puede operar en ambas vistas. Una operación que ya estaba en curso al cambiar el perfil puede terminar.
- Estantes: códigos editables sin cambiar el ID. No se pueden desactivar si tienen stock (incluyendo desbalances negativos) o recepciones pendientes. Recepción y Consulta de estantes usan datos activos de Supabase, ya no la lista fija. En memoria se conservan los ejemplos locales.
- Personal: corregir nombres no reescribe los textos históricos. Un nombre desactivado no se reactiva desde «Agregar persona»; debe revisarlo el administrador. Causales conservan su ID y relaciones; al corregir su nombre, los historiales que lo consultan por ID mostrarán la etiqueta corregida.
- Cambios auditados en `admin_catalogos_historial` con actor, fecha y antes/después. Los catálogos no admiten borrado físico desde la aplicación ni escrituras directas de usuarios autenticados.
- Se publica el cambio de catálogos en Realtime cuando la publicación existe, con refresco periódico como respaldo. Selecciones desactivadas se limpian de los formularios.

Pruebas: `node tools/test_admin_sql.mjs`, `node tools/test_admin_usuarios.mjs` (Auth simulado) y `flutter test --no-pub`. La función Auth debe probarse también en DEV tras su despliegue; no se crearon usuarios remotos durante el desarrollo.

PRODUCCIÓN: este archivo no es el paquete de despliegue de producción. Preparar una migración específica contra el esquema vigente y con respaldo cuando se autorice desplegar, conservando todos sus datos.


## 061: operario automático desde la sesión (solo DEV)

Aplicar `061_operario_desde_sesion.sql` completo después de 060, antes de usar los formularios actualizados. No volver a ejecutar 060 después de 061 sin volver a aplicar 061. No ejecutar este archivo en producción.

El responsable de entregas de Producción, reportes no conformes, liberaciones, envíos/liberaciones de Aliados, recepciones, sobrantes e importaciones ERP se obtiene del nombre de la cuenta activa. El formulario lo muestra sin selector. Si un administrador realiza la operación, se registra su nombre.

La base sustituye los parámetros de nombre por el nombre asociado a `auth.uid()` y resuelve las FK del responsable por esa identidad, incluso cuando dos usuarios tienen el mismo nombre. Se mantienen las comprobaciones de roles de 060. Los datos previos no se actualizan ni se borran. Cambiar un nombre en Administración se refleja en operaciones futuras.

Los campos de terceros (quién entregó desde Producción, quién recibió una liberación en Logística, personas de Aliados) siguen siendo independientes del actor que registra la operación. En modo local sin Supabase se muestra «Usuario de demostración».

Pruebas SQL: `node tools/test_admin_sql.mjs`, con base efímera y nombres falsificados; no utiliza conexiones a Supabase. El paquete de producción se preparará contra su esquema real cuando se autorice el despliegue.


## 062: reportes y auditoría del administrador (solo DEV)

Aplicar `062_reportes_admin.sql` después de 061 en PRUEBAS. Luego actualizar la aplicación y abrir menú lateral → Reportes y auditoría. No requiere desplegar otra Edge Function. El SQL agrega únicamente vistas internas y dos RPC de lectura; no modifica ni elimina datos históricos. Las vistas internas no se conceden a clientes; cada RPC verifica administrador activo.

- **Métricas globales:** OP únicas, no líneas/tallas. Activa = alguna línea visible con cantidad pedida mayor a despachada, o NC de Logística/Aliados pendiente. Atrasada = fecha esperada de Producción vencida con saldo por producir, o fecha esperada de Logística vencida con saldo por despachar; fecha comparada en Bogotá. Sin fecha esperada no implica atraso. OP con NC = pendiente_reproceso > 0 o pendiente_aliados > 0. Sobrantes = todos los registros pendientes y sus unidades, aun si su línea fue ocultada.
- **Movimientos completos:** cada fila de movimientos, incluidos ajustes y líneas ocultas. El botón Original muestra todas las columnas originales. Excel incluye una hoja independiente Movimientos originales con todas las columnas, preservando cantidades negativas.
- **No Conforme:** une reportes de devoluciones_produccion y solicitudes de no_conformes_aliados, sin deduplicar eventos reales distintos. Resume reportes y unidades por causal, reportante, cliente, persona relacionada, mes y origen. No representa unidades únicas ni tasa de defectos. El reportante no necesariamente causó el defecto. No existe proveedor de tela estructurado: no se infiere desde notas/personas.
- **Actividad por persona:** movimientos, entregas de lote, última recepción acumulada por línea, NC, liberaciones, sobrantes y resoluciones, correcciones, cambios de catálogo e importaciones. La misma acción puede existir en varias fuentes; se identifica la fuente y no se suman como stock. Las resoluciones históricas sin actor son Sin registrar. Los nombres ligados solo a usuarios se consultan con su nombre actual; los nombres históricos guardados en las fuentes se conservan. Sin una identidad vinculada no se inventa al actor por cercanía de fecha/lote.
- **Filtros:** OP, persona, cliente, tipo, fecha inclusiva de Bogotá, y causal en NC. Se combinan. La vista se pagina en bloques de 50; la descarga incluye todas las coincidencias y criterios, más todas las agrupaciones del consolidado NC. Exportar no modifica tablas.

Carga completa en páginas de 1000 por clave estable y corte temporal del servidor; no existe truncamiento silencioso por el límite de Supabase. Es una consulta de lectura, no un bloqueo del taller: si otras personas corrigen datos durante la carga, actualizar el reporte. Excel usa texto literal (no fórmulas interpretadas desde notas) y cantidades numéricas. Si se exceden límites de Excel, la descarga falla explícitamente y debe acotarse la consulta.

Validación: `node tools/test_admin_sql.mjs` con datos ficticios y sin Supabase, `flutter test --no-pub test/reportes_admin_test.dart`. PRODUCCIÓN requiere su migración específica al preparar el despliegue, conservando todos los registros.

## 063: despacho por cliente y OC (solo DEV)

1. Ejecutar completo `063_despacho_por_oc.sql` en el SQL Editor de **PRUEBAS**, después de 062. No requiere otra Edge Function.
2. Abrir la aplicación actualizada de master. En la importación habitual de órdenes ERP, volver a cargar el Excel con hojas Orden y Tallas si las líneas existentes no tienen OC. El parser relaciona `Orden.Identificador` con `Tallas.Identificador orden` y toma `Orden.No. OC`; conserva texto y ceros iniciales cuando Excel los almacena como texto.
3. La reimportación completa OC vacías en líneas existentes. No reemplaza cantidades ni OC ya registradas, ni borra movimientos. No usar «reemplazar tabla» para este paso.
4. En Logística → Despacho, seleccionar cliente, abrir una card OC y marcar las OP. Cada OP seleccionada muestra sus productos/tallas con cantidades editables; 0 omite esa línea. También se puede completar todo lo pendiente de la OC, incluyendo OP no marcadas.
5. Revisar los retiros por estante antes de confirmar. La distribución usa estantes con stock en orden de código. Si no alcanza el stock para completar una OC, no se guarda parcialmente: elegir cantidades menores mediante selección.

El SQL agrega la cabecera `despachos_oc`, un vínculo nullable en movimientos y RPC con verificación de cuenta activa de Logística/Administrador. La misma transacción valida todas las líneas, pendiente, stock total y por estante, y registra los retiros con el usuario autenticado. La ruta anterior de despacho individual utiliza la misma validación. El identificador de solicitud evita duplicados al reintentar tras una respuesta perdida; mientras se resuelve ese reintento no se puede cambiar la selección. Un fallo al refrescar la tabla después de guardar se informa como actualización pendiente, sin repetir el despacho.

Historial: incluye movimientos de despacho anteriores y nuevos, con cards plegables por cliente/OC/prenda y filtros combinables de OP y fecha. Los registros anteriores sin identidad muestran «Sin registrar». Las operaciones nuevas conservan cabecera de cliente/OC y nombre del actor; los datos descriptivos de prendas antiguas se consultan desde sus maestros. Las correcciones negativas se conservan en el historial.

Pruebas locales: `node tools/test_admin_sql.mjs` y `flutter test --no-pub test/despachos_oc_test.dart test/responsive_test.dart`. No conectan a Supabase. El SQL no elimina ni reinicia tablas. **No ejecutar en PRODUCCIÓN**: al desplegar, preparar una migración contra el esquema vigente, con respaldo verificado y validación de recuentos/saldos, incluyendo la compatibilidad de recepción de 5 parámetros pendiente de ese despliegue. No reaplicar versiones anteriores de las funciones después de 063.

## 064: fecha de despacho e historial por OC (solo DEV)

Aplicar `064_fecha_despacho.sql` completo después de 063 en PRUEBAS. Agrega a `vista_kardex` la fecha del último movimiento positivo de despacho de cada producto/talla. Incluye despachos previos y futuros, y ajustes positivos de despacho; un ajuste negativo no se considera un envío nuevo. No sobrescribe fechas de entrega de Producción ni modifica movimientos. Sin despachos positivos se muestra «Sin fecha» en Logística.

El historial de despachos permite buscar OC y combinar con OP/fecha. Muestra las OP con movimientos coincidentes. Al buscar OC, su estado actual considera todas sus líneas del kardex (incluidas OP sin despachos y líneas ocultas): Completo si ninguna tiene cantidad pendiente por despachar; Parcial en caso contrario. Se separan clientes aunque usen el mismo número OC. El estado no se recalcula sobre los movimientos filtrados. OC históricas que ya no tienen líneas asociadas muestran «Sin datos actuales».

No ejecutar en PRODUCCIÓN: incluir este cambio aditivo en la migración específica del despliegue, preservando todos los datos existentes.
