# ORBILOQ WMS

Sistema de control de producción, inventario, bodega y despachos, desarrollado con Flutter, Riverpod y Supabase (PostgreSQL, Auth, Storage y Realtime). Incluye un repositorio en memoria para pruebas locales.

**Última revisión documental: 20 de octubre de 2026.** Este README describe el código disponible en desarrollo; no certifica que todos los cambios estén desplegados ni que sus migraciones estén aplicadas en una base particular.

## Mantenimiento del repositorio (20/oct)

La primera etapa de limpieza afectó únicamente documentación y seguimiento de archivos en Git. Las dependencias de `outputs/ciclos_limpieza_20261014/node_modules` y el archivo temporal de Office dejaron de versionarse sin borrar la instalación local. Esa etapa no modificó el código Flutter, los paquetes de `pubspec.yaml`, los lectores web, las migraciones ni los despliegues.

En el paso 2 se retiraron tres componentes sin consumidores en la aplicación ni en herramientas: el antiguo selector de destino de recepción, la tarjeta independiente de pendientes de recepción y el cálculo independiente de avance de despacho. Se retiraron también sus pruebas exclusivas. Se conservan las implementaciones vigentes y sus pruebas de recepción, inventario y despacho, así como el lector de clientes Excel utilizado por herramientas de PDF. No se cambiaron dependencias, entornos ni SQL.

La carpeta `outputs` también contiene evidencias y SQL usados por herramientas: no debe eliminarse completa. Las herramientas históricas `preparar.mjs` de esa carpeta requieren el paquete privado `@oai/artifact-tool` del entorno de generación de documentos; no es una dependencia de ORBILOQ ni se instala con `flutter pub get`. En otro equipo se necesita ese entorno para volver a generar dichos entregables. Sus dependencias locales se excluyen con `**/node_modules/`.

La configuración actual de Flutter sigue entrando por `--dart-define`; esta limpieza no añade ni carga un `.env`. Las reglas nuevas de `.gitignore` previenen versionar configuraciones locales si se crean en el futuro y permiten plantillas `.env.example` sin credenciales.

Los apartados fechados siguientes describen etapas de implementación; no reemplazan las instrucciones de migración de cada entorno. En el código actual se admite despacho de varias referencias y tallas de un mismo cliente con una OC y un destinatario, usando la preparación de orígenes y las migraciones 111–112. El historial ampliado requiere 113. Esto no certifica su aplicación remota.

## Conductores (pruebas)

Portal adaptable a móvil en master: inspecciones de inicio/cierre por categorías,
documentos, avisos internos, tanqueos, mantenimiento, novedades e historial.
Acceso: menú de administración → Conductores · Pruebas; las cuentas Conductor
entran directamente. Habilitado solo en demo local y ORBILOQ-DEV.
Requiere aplicar la migración 114 y actualizar admin-crear-usuario en DEV;
activación remota pendiente. Las fotos se asocian mediante enlaces de Drive;
subida automática y notificaciones push pendientes de conexión.
Ver [configuración y límites](docs/conductores-pruebas.md).

## Inventario por ficha técnica (pruebas)

**Solo prendas ingresadas (19/oct):** la tabla y sus KPI de página incluyen únicamente combinaciones cliente + ficha técnica con entradas reales por transferencia o Excel. No incluye fichas que solo existen en Producción/Bodega. Conserva las ingresadas con saldo disponible cero para consultar reservas, despachos y reversiones. Se mantienen las columnas de Producción/Bodega como contexto de las fichas incluidas. El filtro se aplica en servidor antes de contar y paginar; requiere [106_inventario_solo_ingresadas.sql](sql/pruebas/106_inventario_solo_ingresadas.sql), después de 105, en ORBILOQ-DEV (aplicación remota pendiente).


**Entradas por Excel (19/oct):** Bodega y Administración tienen **Importar inventario Excel** y descarga de plantilla. Columnas obligatorias: `NOMBRE FICHA TECNICA`, `CLIENTE`, `CODIGO`, `DESCRIPCION`, `TALLAS NOMBRE`, `CANTIDAD`. `ESTANTE` es opcional: si falta la columna o la celda está vacía, se usa el estante predeterminado seleccionado en el diálogo. Se elige la única hoja que contiene los seis encabezados obligatorios en la primera fila; si hay más de una, se rechaza para evitar elegir la incorrecta. Cantidades enteras positivas: **se suman**, nunca reemplazan. Se agrupan las filas repetidas por cliente/ficha/código/talla/estante; cliente y ficha se normalizan por mayúsculas y espacios, conservando la versión y los ceros iniciales de códigos almacenados como texto. La tabla general separa cliente + ficha + talla; el detalle conserva cada entrada y ubicación. Máximo 10 MB, 5000 filas leídas y 1000 combinaciones agrupadas por carga.

La vista previa valida todos los estantes activos antes de confirmar. Una huella del contenido agrupado evita duplicar una carga incluso si se renombra el archivo; un reintento conserva el mismo identificador. La operación es atómica: un error no deja una entrada parcial. La lectura web usa `operativo_excel_worker.js?v=20261019-3` (recompilar con `tools/compilar_lector_operativo.ps1` al cambiar el parser). No se crean OP ficticias ni entregas de Producción: se almacenan artículos de origen inventario sin OP, con su recepción física y entrada auditada. Pueden reservarse, cancelarse y despacharse con el asistente normal; no admiten «Devolver a OP original» porque no tienen una. Requiere **105_inventario_excel.sql**, después de 101–104, únicamente en ORBILOQ-DEV. Aplicación remota pendiente.


Despacho integrado (19/oct): **Despachar → Seleccionar para despacho** cierra el selector y abre el asistente habitual **Destino → Prendas → Empaques → Confirmar**, con el cliente y la transferencia de origen fijos. Permite indicar la OC de destino, seleccionar destinatario y repartir la cantidad libre en varios empaques. La LE queda reservada en Seguimiento. Requiere [104_inventario_despacho_flujo.sql](sql/pruebas/104_inventario_despacho_flujo.sql) en ORBILOQ-DEV (pendiente aplicación remota); conserva validación de stock, roles e idempotencia en una transacción.


Corrección de carga (19/oct): las lecturas de Inventario terminan con un error recuperable tras 20 segundos; las escrituras no se reintentan automáticamente. Los cargadores de pestañas ocultas ya no bloquean el diálogo visible y Enter/lupa cancelan la búsqueda diferida para evitar consultas duplicadas. Aplicar en DEV [103_inventario_consulta_agrupada.sql](sql/pruebas/103_inventario_consulta_agrupada.sql), después de 101/102: calcula los saldos de inventario una sola vez por consulta, evitando la agregación lateral por cada línea del kardex. Validado en PostgreSQL local; aplicación remota pendiente. No modifica cantidades ni movimientos.


Implementado en `master`, habilitado únicamente cuando `SUPABASE_URL` corresponde a ORBILOQ-DEV (`igfuafcekcpugpmsoqbe`). Para bases que ya tienen 101, aplicar también [102_inventario_origenes_visibles.sql](sql/pruebas/102_inventario_origenes_visibles.sql), pendiente de aplicación remota. Requiere aplicar [101_inventario_ficha.sql](sql/pruebas/101_inventario_ficha.sql) en esa base antes de usar la nueva versión; no ejecutar este archivo en producción. La validación local no equivale a una migración remota aplicada.

- Acceso desde las acciones de Bodega, **Inventario**; Gerencia lo abre desde Indicadores. Tabla paginada de 25 filas por ficha y talla con búsqueda por ficha, producto o cliente. Conserva la versión completa de `NOMBRE FICHA TECNICA`, leída de la hoja Orden del ERP; una OP sin ficha no puede transferirse a inventario.
- Columnas: ficha, producto, cliente, pendiente de producir, bodega para OP, stock libre, reservado y despachado desde inventario. El detalle conserva OP, talla, estante, cantidad original, reversiones y despachos. Una ficha del mismo código en otro cliente constituye otro inventario.
- **Bodega (`logistica`) y Administrador** transfieren cantidades recibidas y revierten únicamente saldo libre, con motivo obligatorio. Las operaciones son inmutables y la reversión es un registro compensatorio; devuelve las prendas a la OP/talla/estante originales. No crea recepciones adicionales ni borra movimientos.
- Nueva pestaña **A inventario**, entre **Pendientes** e **Historial** en Recepción de DEV. Bodega y Administración pueden buscar por OP, ficha, producto o cliente y transferir una cantidad libre de una talla/estante, indicando motivo. Reutiliza `inventario_origenes` e `inventario_transferir`, con paginación de 50; actualiza orígenes y kardex después de guardar. No duplica la recepción. La consulta corregida en 102 muestra también existencias sin ficha, sin saldo libre o en estantes inactivos y explica por qué no se pueden transferir. La búsqueda se ejecuta automáticamente tras 350 ms y también con Enter/lupa.
- Recepción mantiene el formulario sencillo: cabecera con OP destacada, talla y contadores de recibidas/pendientes; estante y cantidad en paralelo en escritorio, controles − / + / Recibir todo, observación opcional y acciones secundarias discretas. La franja inferior muestra el saldo resultante, el estante y Confirmar recepción; el mensaje de cero pendientes solo aparece cuando la cantidad ingresada completa la entrega. Al validar se muestra solo la entrega elegida, se ocultan buscador y pestañas, y **Volver a entregas** recupera la lista. El marco y la cabecera son compactos; − / cantidad / + / Recibir todo comparten fila en escritorio. La confirmación permanece fija fuera del contenido desplazable en todos los tamaños. En móvil los campos se apilan y el contenido puede desplazarse. No muestra reparto ni opciones de inventario; toda recepción queda asignada a su OP. Para pasar prendas ya recibidas al stock libre, usar **Inventario → Transferir desde OP**. La recepción en DEV conserva la operación atómica y su clave para evitar duplicados al reintentar.
- Acceso directo **Inventario** en las acciones de Bodega (junto a Recibir lote y Producto no conforme), solo en DEV. Abre una pantalla independiente con estilo de Control de operaciones: cabecera, acciones, cinco indicadores y tabla azul. Los indicadores resumen las unidades de la página actual y se etiquetan así, no son totales globales. La tabla separa ficha técnica y producto y conserva cliente, pendiente de producir, bodega asignada a OP, stock disponible, reservado y despachado desde inventario.
- Vista de inventario: tabla compacta de ancho completo en escritorio y tarjetas en móvil; producto y ficha aparecen en columnas separadas en escritorio, se destaca el stock libre y se atenúan los ceros. Búsqueda y paginación conservan su alcance; el contador de fichas con stock indica explícitamente que corresponde a la página visible. **Despachar** aparece junto a cada prenda con saldo libre para Administración/Despacho y abre la selección por talla y origen. **Seleccionar para despacho** continúa al formulario de cantidad, OC del mismo cliente, destinatario y empaque; genera una LE reservada cuya salida se confirma en Seguimiento. Los demás roles conservan consulta y sus permisos de transferencia.
- Pruebas de interfaz: `flutter test test/inventario_test.dart test/recepcion_agrupada_test.dart`. La recepción agrupada verifica el formulario sin opciones de inventario y la confirmación visible con tema corporativo en 1366×768, 1093×614, 390×844 y 320×568; la vista de inventario verifica adaptación y permisos.
- **Despacho y Administrador** pueden reservar una transferencia para una OC de destino del mismo cliente, seleccionando destinatario y una caja/paquete con peso real. Esta primera interfaz crea una LE por transferencia seleccionada; no mezcla orígenes ni inventa OP nuevas. La salida se confirma desde Seguimiento por sus roles habituales. El PDF, seguimiento y facturación conservan la nueva OC; su ID OC se completa en facturación y no se copia del pedido original.
- Una reserva de inventario puede liberarse con motivo desde su detalle. La LE cancelada conserva su numeración para auditoría y no puede confirmarse ni imprimirse como salida. No se usa la corrección convencional de LE para modificar un despacho de inventario. Las unidades ya despachadas no son reversibles como transferencia.
- El kardex operativo descuenta el inventario de la disponibilidad de la OP sin alterar sus cifras históricas de recibido. La base valida saldo y permisos, incluso si el navegador está desactualizado, y serializa las operaciones que compiten por existencias. Realtime avisa cambios de transferencias y reversiones.

Validación: `flutter test test/inventario_test.dart` cubre disponibilidad, permisos visibles, búsqueda/paginación y pantallas de 390/1440 px. `tools/ensayar_trazabilidad_op.ps1` (PowerShell 7 y PostgreSQL local) aplica 101 dos veces y ejecuta `tools/test_inventario.sql`: roles, aislamiento por cliente/versión, reintentos, límites, reservas, cancelación, salida, reversiones y recepción atómica. Los datos sintéticos se revierten y el ensayo no se conecta a Supabase.

## Entornos y conservación de datos

- **Despliegue verificado el 15/10/2026:** producción actualizada con SQL 011 y web `31f9f87`; 82 tablas y 10.374 filas originales conservadas, más respaldo de 23 adjuntos en D:. Evidencia y límites de verificación en [el registro de producción](sql/produccion/README.md). No volver a ejecutar la migración 011.
- El desarrollo se realiza en `master`.
- **La prioridad es conservar los datos y el historial de producción.** No reemplazar producción con el esquema ni los datos de DEV.
- Las migraciones de [sql/pruebas](sql/pruebas/README.md) son exclusivas de desarrollo. Revisar las dependencias y validaciones de cada archivo; no ejecutar todos los SQL de la carpeta indiscriminadamente.
- Producción tiene sus propios [scripts e instrucciones](sql/produccion/README.md). Antes de desplegar: identificar la versión aplicada, respaldar, revisar la migración correspondiente, coordinar la sincronización de usuarios y verificar los resultados.
- Las recuperaciones puntuales de datos no son migraciones generales. Los scripts de `outputs/diagnostico_ordenes_20261015/` corresponden a un diagnóstico y UUID específicos; no reutilizarlos para otras importaciones o bases.

## Requisitos y ejecución local

Los requisitos declarados son Dart `^3.7.0` y Flutter `>=3.29.0`; consultar [pubspec.yaml](pubspec.yaml) y conservar el archivo de dependencias bloqueadas. Usar una versión de Flutter compatible con las API del código y validar con el analizador.

Desde la raíz del proyecto:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Sin configuración de Supabase, la aplicación usa datos de prueba en memoria. No modifica la base real.

Para conectar un entorno Supabase, proporcionar su URL y clave pública:

```powershell
flutter run -d chrome --dart-define=SUPABASE_URL=https://TU_PROYECTO.supabase.co --dart-define=SUPABASE_ANON_KEY=TU_CLAVE_PUBLICA
```

No incluir claves `service_role` ni credenciales privilegiadas en Flutter. La creación de cuentas utiliza la [Edge Function de administración](supabase/functions/admin-crear-usuario/README.md).

## Módulos principales

- **Kardex y producción:** consulta por OP, código y talla, entregas, historial y edición administrativa con permisos y auditoría.
- **Bodega:** recepción, ubicaciones, existencias, no conformes y reprocesos. La bandeja de sobrantes y su formulario se retiraron; los registros históricos se conservan.
- **Despachos:** selección de destinatario, empaques, peso bruto por empaque, rótulos, listas de empaque nacionales e internacionales y seguimiento.
- **Administración:** usuarios con uno o varios roles, personal, ubicaciones, causales, empaques y destinatarios. Las operaciones administrativas requieren validación en el servidor.
- **Dashboards:** resumen ejecutivo y tiempos de ciclo con vistas de Resumen, Capacidad y Detalle por OP.
- **Interfaz adaptable:** navegación móvil, formularios y diálogos ampliables; controles y tablas adaptados a distintos anchos.

### Destinatarios

El catálogo se consulta dentro de Administración. Permite crear destinatarios nacionales e internacionales. Los campos adicionales internacionales se muestran al seleccionar ese tipo.

El código de desarrollo incorpora edición y eliminación desde el menú de cada destinatario, solo para cuentas con rol Administrador, también cuando tienen varios roles. Requiere aplicar en DEV [095_admin_destinatarios.sql](sql/pruebas/095_admin_destinatarios.sql), después de sus dependencias.

- Editar conserva el identificador del destinatario y los datos históricos de los documentos emitidos.
- Eliminar requiere confirmación y se rechaza cuando existen despachos vinculados.
- El servidor rechaza ediciones o eliminaciones si el registro cambió desde que se abrió el formulario.

## Importaciones Excel: tres flujos diferentes

### 1. Órdenes del ERP

Utiliza las hojas **Orden** y **Tallas**; la hoja Instrucciones no se importa.

| Hoja | Datos y función |
| --- | --- |
| Orden | Cabecera de la OP: Identificador, cliente, OC, fechas, ficha, cantidad total y observaciones. |
| Tallas | Detalle por OP, código y talla; la columna Cantidad determina las unidades de cada línea del Kardex. |

`Identificador` en Orden se relaciona con `Identificador orden` en Tallas. La OC de la cabecera prevalece en el proceso de importación. La cantidad total de Orden se compara con la suma de las tallas; no sustituye ese detalle.

**El importador actual solo inserta OP nuevas.** Si el número de OP ya existe, no actualiza la cabecera ni completa las tallas. Solo inserta líneas con cantidad positiva, código y talla. Por eso una carga con cantidades ausentes puede crear una cabecera sin líneas, y subir después el archivo corregido no la repara.

Antes de importar, comprobar que cada OP de Orden tenga sus líneas y cantidades en Tallas. Si el archivo contiene solo un subconjunto que se desea cargar, ambas hojas deben corresponder a ese mismo conjunto. Para recuperar OP existentes sin tallas, diagnosticar primero y preparar una recuperación específica; no borrar OP para forzar su reimportación.

### 2. Tabla del Kardex

Flujo administrativo separado: **Exportar tabla → editar Excel → Importar tabla → Revisar reemplazo → Confirmar**. La exportación incluye todas las filas activas, sin limitarse a los filtros o la página visible.

Este flujo usa validaciones de versión, permisos y auditoría. No confundir su formato con el de las hojas Orden/Tallas del ERP. Consultar [las instrucciones SQL de desarrollo](sql/pruebas/README.md).

### 3. Históricos de tiempos de ciclo

Columnas operativas:

`N° DE ORDEN`, `CLIENTE`, `CANTIDAD`, `FECHA DE INICIO`, `COMPRAS`, `TRAZO`, `CORTE`, `SEPARADO`, `ALIADOS`, `TERMINADO`, `LOGISTICA`.

También se admiten `FECHA COMPROMETIDA ENTREGA` y `FILA ORIGINAL` como referencias opcionales de revisión; no se persisten ni alteran los indicadores.

- El modelo actual es secuencial: cada proceso se mide desde la fecha del anterior; Compras comienza en Fecha de inicio.
- Se calculan días hábiles con calendario colombiano.
- La lectura web del Excel utiliza un worker para evitar bloquear la interfaz.
- El guardado es transaccional. El mensaje distingue el resultado del guardado del resultado de la recarga.
- Límite actual por archivo: 10.000 OP y 20 MB. El histórico acumulado puede ser mayor; no implica capacidad ilimitada de carga o visualización.
- Los datos históricos de Logística pueden representar entrega al cliente. No interpretarlos automáticamente como salida física de despacho.

Ver [importación y rendimiento de ciclos](docs/importacion_ciclos.md). Las rutas por ficha, los parciales y el control ampliado por taller son [alcance futuro pendiente](docs/ciclos_alcance_futuro.md), no funcionalidades ya implementadas.

### KPI generales de logística

Diagnóstico de pruebas: [preparar reinicio de OP 90006](sql/diagnostico/preparar_reinicio_op_90006.sql) consulta dependencias y validaciones instaladas, sin modificar datos. Con el resultado del 15/10/2026 se preparó [reiniciar únicamente OP 90006](sql/diagnostico/reiniciar_op_90006_pruebas.sql): respalda los registros, conserva la orden y sus 30 unidades pedidas, y cancela ante cambios, dependencias compartidas o repetición. Ensayado con PostgreSQL embebido mediante `node tools/test_reinicio_op_90006.mjs`, con las filas aportadas y relaciones relevantes (no sustituye la ejecución en Supabase). Pendiente de ejecución por el usuario en desarrollo; no usar reinicios operacionales generales para limpiar una sola OP. Conserva archivos de Storage y consecutivos de documentos. El diagnóstico confirmó que la validación de stock de devoluciones ya está instalada.

Las cinco tarjetas muestran acumulados actuales de las líneas de OP vigentes del Kardex del cliente seleccionado (o todos los clientes), sin recorte por fechas. El alcance aparece encima de las tarjetas; los filtros de las gráficas mantienen su funcionamiento.

- **Unidades pedidas:** suma de las cantidades solicitadas.
- **Entregado a Logística:** suma del saldo entregado por Producción.
- **Pendiente por entregar a Logística:** suma de max(0, pedidas − entregadas) por línea; los excedentes no compensan faltantes de otras líneas.
- **Recibido en Bodega:** suma de recepción neta confirmada, incluidas devoluciones y ajustes del Kardex.
- **Despachadas:** suma del saldo despachado.

Desde Entregado a Logística se muestran porcentajes con su base explícita: entregado / pedido, pendiente / pedido, recibido / entregado y despachado / recibido, multiplicados por 100. Sin denominador positivo se muestra «—»; los excesos no se limitan artificialmente al 100 %. Unidades pedidas no lleva porcentaje. El pendiente sigue calculándose por línea para evitar compensaciones entre faltantes y excedentes.

Se excluyen líneas eliminadas. La fila reemplaza el KPI de Alertas y mantiene retirados los de conformidad y sobrantes; el detalle de atención requerida y calidad permanece en sus paneles. No se muestra el botón de revisión de saldos sobre los KPI.

## Sincronización y rendimiento

### Facturación de listas de empaque

La pestaña **Facturación** aparece junto a Seguimiento para Administrador y Seguimiento. Requiere aplicar [SQL 097](sql/pruebas/097_facturacion_le.sql) en ORBILOQ-DEV; pendiente de ejecución remota. Solo incluye LE despachadas con fecha de recibido por el cliente en su revisión vigente, independientemente de la etiqueta del estado de entrega.

Cada tarjeta muestra N° de remisión e ID OC editables, orden de compra y número de LE. El ID OC inicial procede de `ordenes_produccion.oc_id_erp`: el importador ya lee **ID. OC** de la hoja **Orden**, sin distinguir mayúsculas. No se toma el OC ID de Tallas como sustituto. Si la LE contiene varios ID OC del ERP, no se elige uno automáticamente: se muestran las opciones detectadas y se permite diligenciar el campo. Las ediciones quedan en Facturación y no reescriben el ERP ni los PDF históricos.

Al guardar, una LE con remisión, ID OC, OC y número de LE completos aparece en **Facturadas completas**; en caso contrario permanece en **Facturadas sin completar**. Se permite guardar avances y volver a editar completas. Quitar la fecha en Seguimiento oculta la tarjeta sin borrar sus datos; una nueva revisión de la LE no hereda silenciosamente la facturación anterior. El servidor valida permisos, revisión y versiones de facturación/seguimiento. Esta clasificación indica campos completos, no emisión de factura fiscal.

Pruebas: `node tools/test_facturacion_le.mjs` (PostgreSQL embebido, permisos, concurrencia, fecha, ERP y clasificación) y `flutter test test/facturacion_le_test.dart` (importación y edición responsive).

### Despachos por mes y entregas con novedad

En desarrollo, el seguimiento incorpora **Entregado con novedad** (`entregado_con_novedad`) en el editor, filtros e historial. Requiere ejecutar [SQL 096](sql/pruebas/096_entregado_con_novedad_dashboard.sql) en ORBILOQ-DEV antes de usarlo; pendiente de aplicación remota. La migración amplía la restricción de estados sin reescribir registros y crea un reporte de solo lectura autorizado para Administración/Gerencia.

La tarjeta «Órdenes de producción hoy» se reemplaza por **Despachos por mes**, con columnas verticales agrupadas: total de despachos confirmados, sin contratiempo (estado Entregado) y con contratiempo (Entregado con novedad). Cuenta una vez cada despacho, no unidades, por mes de salida en Bogotá; utiliza el estado actual de la revisión vigente. Aplica cliente y período seleccionado, incluidos los lunes a viernes del calendario del dashboard. Tránsito y devoluciones solo suman al total: las dos categorías de entregados no tienen que sumar el total. No es un indicador de puntualidad ni una fotografía histórica del estado al cierre de mes.

El cálculo se agrega en SQL para evitar descargar el historial completo; muestra meses sin despachos y estados de carga/error. Recargar el dashboard actualiza el reporte. Ensayo de migración y conteos: `node tools/test_despachos_mensuales.mjs`; pruebas de presentación: `test/dashboard_resumen_test.dart`.

El repositorio Supabase consulta el Kardex, las existencias por ubicación, las líneas de lotes y las reservas. Las lecturas están paginadas para superar el límite de filas por respuesta del servidor.

El cambio de desarrollo del 15 de octubre de 2026:

- Agrupa avisos Realtime en ventanas de 350 ms.
- Evita varias recargas completas simultáneas.
- Conserva una recarga posterior si llegan solicitudes durante una lectura.
- Consulta las cuatro fuentes independientes en paralelo.
- Cancela el temporizador al cerrar el repositorio y conserva la notificación de errores y el refresco manual.

La prueba local con 50 solicitudes durante una lectura produjo dos snapshots completos. Es una comprobación de concurrencia, no una medición de latencia en producción. La aplicación todavía descarga el conjunto completo de esas fuentes; para mayores volúmenes se deberá evaluar consulta por demanda y agregación en servidor.

## Rendimiento de importación de Excel

Los lectores de ERP (Orden/Tallas), fechas esperadas y Kardex materializan las filas de cada hoja una sola vez. Antes, la propiedad `Sheet.rows` reconstruía toda la hoja en cada vuelta del recorrido, multiplicando el trabajo con el volumen del archivo.

En web, estos lectores se ejecutan en workers; el importador de ciclos también usa su worker. En otras plataformas, la lectura se delega a `compute`. Se conservan los formatos, las validaciones y las operaciones transaccionales existentes; esta optimización no cambia cantidades ni sobrescribe órdenes existentes. ERP informa las etapas de lectura, archivo, guardado y recarga. ERP y fechas mantienen bloqueada una nueva importación hasta finalizar la recarga.

Medición local del lector ERP con un Excel sintético de 2.500 OP y 2.500 tallas: antes 12.719 ms, después 543 ms (aproximadamente 23 veces más rápido). No incluye red, Storage ni SQL, ni garantiza ese tiempo en producción. Los workers tienen un límite de lectura de dos minutos y devuelven errores legibles antes de enviar datos al servidor. La recarga completa del Kardex y el procesamiento de Supabase pueden seguir influyendo con volúmenes mayores.

Comprobación reproducible del lector actual y de equivalencia entre Dart y los workers JavaScript:

```powershell
dart run tools/benchmark_importacion_erp.dart
node tools/test_lectores_excel.mjs
```

## Compilar la web

Si se modifica un lector, regenerar su worker antes de compilar. Los tres archivos JavaScript generados deben incluirse en la publicación:

```powershell
./tools/compilar_lector_ciclos.ps1
./tools/compilar_lector_ordenes.ps1
./tools/compilar_lector_operativo.ps1
flutter build web --release --base-href /ORBILOQ/ --dart-define=SUPABASE_URL=https://TU_PROYECTO.supabase.co --dart-define=SUPABASE_ANON_KEY=TU_CLAVE_PUBLICA
```

`/ORBILOQ/` corresponde a la publicación bajo ese prefijo; ajustarlo para otro alojamiento. Compilar no publica ni aplica migraciones. Reiniciar la ejecución local de Flutter cuando sea necesario cargar cambios en la inicialización del repositorio.

## Validaciones

```powershell
flutter analyze
flutter test --no-pub
```

Pruebas enfocadas en cambios recientes:

```powershell
flutter test --no-pub test/supabase_sincronizacion_test.dart
flutter test --no-pub test/dashboard_catalogo_test.dart
flutter test --no-pub test/destinatario_editor_test.dart test/destinatario_internacional_test.dart
```

[tools/ensayar_trazabilidad_op.ps1](tools/ensayar_trazabilidad_op.ps1) ensaya migraciones y reglas de despacho en PostgreSQL local desechable. Revisar su parámetro `PgBin` y las dependencias del ensayo antes de ejecutarlo. No se conecta a Supabase de producción.

Validaciones registradas durante los cambios recientes: suite seleccionada de 253 pruebas de vistas y responsive aprobada el 14 de octubre; pruebas de concurrencia y recuperación de errores de sincronización aprobadas el 15 de octubre. Estos resultados no sustituyen ejecutar las pruebas tras nuevos cambios ni verificar una sesión real.

## Estructura del proyecto

```text
lib/
  main.dart / app.dart   Composición, entorno, sesión y repositorios
  core/                 Tema, utilidades y resultados
  domain/               Modelos, reglas, métricas y contratos
  data/                 Supabase, memoria, lectores Excel y documentos PDF
  application/          Providers, filtros y preparación de datos
  features/             Pantallas y formularios por módulo
  shared/               Componentes, descargas, escaneo y utilidades comunes
test/                   Pruebas de lógica, integración simulada y widgets
sql/pruebas/            Migraciones y guías exclusivas de DEV
sql/produccion/         Diagnósticos y migraciones específicos de producción
supabase/functions/     Funciones del servidor
web/                    Recursos web, incluido el worker de ciclos
tools/                  Ensayos locales y generación de recursos
docs/                   Documentación funcional y técnica por tema
```

## Documentación complementaria

- [Dashboard ejecutivo](docs/dashboard_ejecutivo.md)
- [Seguimiento de entregas](docs/seguimiento_entregas.md)
- [Rótulos de empaque](docs/rotulos_empaque.md)
- [Escaneo con cámara](docs/escaneo_camara.md)
- [Tema corporativo](docs/tema_corporativo.md)

## Mantenimiento de este README

Actualizar este documento junto con los cambios que afecten funciones, permisos, importaciones, migraciones, configuración o despliegue. Mantener separados el código disponible, lo verificado localmente y lo efectivamente desplegado. Registrar cambios de comportamiento importantes y enlazar la documentación detallada; no incluir contraseñas, tokens ni datos operativos de clientes.

## Facturación de despachos semanales

El Resumen ejecutivo reemplaza Calidad en recepción por una dona: facturación completada frente a pendientes, con total de despachos y selector de semana. Cuenta despachos confirmados, no prendas, por fecha de salida en Bogotá (lunes a viernes), recortados al período y cliente seleccionados. La semana más reciente se muestra inicialmente. Pendientes incluye despachos aún sin entrega registrada; una semana vacía muestra «Sin despachos», no 100 %.

La condición de completada reutiliza `facturacion_le_dato`: fecha de entrega registrada, LE, OC, remisión e ID OC completos en la revisión vigente. Es el estado documental actual de esos despachos, no un cierre histórico ni emisión de factura fiscal. Guardar Facturación y actualizar el dashboard invalidan el reporte.

Requiere aplicar en desarrollo `sql/pruebas/098_dashboard_facturacion_semanal.sql` después de 097. La RPC es de solo lectura y exige permiso de dashboard (Administración/Gerencia); no modifica inventario ni facturas. Pendiente de aplicación remota. Ensayo SQL: `node tools/test_facturacion_le.mjs`.

## Opciones administrativas por LE

En Confirmar salida, solo Administrador puede activar un número LE exclusivo de ese despacho y/o elegir la fecha de salida (hasta hoy, Bogotá). Si no activa las opciones, conserva número reservado y fecha automática. Un número ya utilizado se rechaza; el consecutivo global no se reconfigura, y la asignación automática omite números ocupados cuando llega a ellos. El número automático previamente reservado queda sin reutilizar. La fecha elegida queda en el despacho, su documento PDF y los movimientos de esa salida; una auditoría privada conserva la fecha real de registro y el administrador. Los reintentos de la misma revisión no duplican salidas. Solo aplica antes de liberar, no renumera documentos ya emitidos.

En Empaques, «Empacar OC completa» prepara todas las OP de la OC y cliente seleccionados en una caja elegida por el administrador. Reemplaza la distribución que se está editando tras mostrar el resumen. Usa el mínimo entre existencia disponible y pendiente, excluyendo reservas ajenas; las unidades sin existencia permanecen pendientes. Exige peso bruto y conserva revisión, validación de estantes y confirmación de salida. El servidor valida el rol para cargas marcadas como masivas.

Requiere `sql/pruebas/099_opciones_admin_le.sql`, después de 092, en desarrollo. No aplicado remotamente. Ensayo aislado: `tools/ensayar_trazabilidad_op.ps1` (incluye permisos, duplicados, documento, reintentos, conservación del consecutivo y compatibilidad).

## Puntualidad mensual de despachos

El panel Salud de clientes se reemplaza por columnas agrupadas: total de LE liberadas, completadas a tiempo y completadas con retraso. Completar significa salir de bodega. Cuenta una vez cada despacho, por mes de `despachos_oc.fecha` en Bogotá, con filtro de cliente, período y lunes a viernes. Incluye las fechas de salida personalizadas por Administrador.

Compara la salida con `ordenes_produccion.fecha_esperada_logistica` de todas las OP del detalle: a tiempo si no supera ninguna (incluye igualdad); retraso si supera al menos una. Si falta una fecha o un vínculo, la LE cuenta solo en total y se informa como sin fecha esperada completa. Por ello las dos clasificaciones pueden sumar menos que el total. Usa las fechas esperadas actuales, no una instantánea histórica de las metas. No utiliza la fecha de entrega al cliente ni confunde novedades con retrasos.

Requiere `sql/pruebas/100_dashboard_puntualidad_mensual.sql` en DEV. Consulta de solo lectura con acceso de dashboard; pendiente de aplicación remota. Ensayo aislado: `node tools/test_puntualidad_mensual.mjs`.

### Inventario por talla (107, solo pruebas)

`107_inventario_por_talla.sql` separa el listado por ficha técnica completa, cliente y talla. Solo aparecen combinaciones con entradas reales desde OP o Excel; conserva históricos sin stock libre. Cada fila muestra sus propias cantidades y el detalle/despacho filtra la talla antes de paginar. Aplicar después de 106 en ORBILOQ-DEV antes de usar la nueva interfaz; no modifica cantidades ni datos de producción.

### Recepción en bodega: presentación

Pestañas con indicador inferior, resumen de entregas/unidades pendientes y tarjetas con avance de recepción. A inventario muestra talla, estante, ficha y saldo libre; el formulario presenta el origen, límite y motivo con controles de cantidad. Mantiene validaciones y operaciones existentes; no requiere migración SQL. No se presenta un total diario basado en recepciones acumuladas.

### 108 · Estante de destino al enviar a inventario

El formulario permite elegir un estante activo y conserva el origen de la OP. La migración `108_inventario_estante_destino.sql` registra la ubicación de origen en un ledger privado e inmutable y actualiza los saldos por estante, sin generar recepciones ni despachos ficticios. La reversión libre devuelve las prendas al estante original; las reservas y salidas usan el destino. Roles: Bodega/Administrador. Aplicar después de 107 exclusivamente en ORBILOQ-DEV; aplicación remota pendiente.

### 109 · Historial de transferencias a inventario

Nueva pestaña Historial junto a Disponibles, tanto en Transferir desde OP como en A inventario de Recepción. Reutiliza HistorialAgrupado (búsqueda por OP, fechas, tarjetas desplegables y totales separados de transferencias/reversiones). Carga al abrir la pestaña y vuelve a consultar al entrar de nuevo; incluye fecha, cantidad, motivo, responsable y estantes de origen/destino. Solo Bodega/Administrador. Requiere aplicar `109_inventario_historial.sql` después de 108 en DEV; aplicación remota pendiente.

### Diseño del despacho desde inventario

Destino presenta tarjetas de cliente/ficha/OP, aviso de asignación a otra OC del mismo cliente y selector de destinatario con búsqueda en ventana. Incluye actualización de destinatarios y Cancelar en el primer paso; conserva las validaciones y el asistente normal de empaque. Cambio de interfaz, sin migración SQL.

### Despacho normal: diseño de Destino

Dos tarjetas separan destinatario/sede y cliente. El selector de destinatario reutiliza la búsqueda del despacho de inventario, con actualización de catálogo. Pestañas con subrayado verde corporativo, etapas en azul petróleo y Cancelar en el primer paso. Conserva permisos, catálogo/consecutivo y validaciones. Sin cambios de base de datos.

La importación de inventario admite Excel sin la columna ESTANTE o con celdas vacías. Estas filas usan el estante predeterminado mostrado en el diálogo (primer estante activo del catálogo, modificable antes de confirmar). Los valores explícitos conservan su validación. La vista previa y la confirmación envían las mismas ubicaciones; cambiar el predeterminado vuelve a validar el archivo. No requiere migración SQL adicional.

Inventario: `110_inventario_eliminar_excel.sql` habilita eliminar una entrada Excel completa exclusivamente para administradores, con motivo obligatorio. Rechaza reservas, despachos y ajustes posteriores. Archiva una copia inmutable de la entrada y sus movimientos antes de retirar la recepción del stock; conserva la importación original y su protección contra cargas duplicadas. El botón aparece en el detalle de una entrada Excel. Aplicar únicamente en ORBILOQ-DEV después de las migraciones de inventario anteriores.

Despacho múltiple de inventario: `111_inventario_despacho_multiple.sql` (solo DEV, después de 110) permite marcar varias fichas/tallas del mismo cliente, conservar la selección entre filtros y páginas y revisar cantidades antes del asistente habitual. Preparación FIFO por fecha e ID, limitada a estantes activos, sin reservar hasta confirmar el empaque. Una OC, un destinatario y una LE; las asignaciones por entrada comparten solicitud y LE con clave `(solicitud, transferencia)`. El servidor bloquea y valida todas las existencias, compara empaques por artículo y guarda atómicamente. Cancelar libera todos los orígenes; confirmar salida mantiene trazabilidad por transferencia. Se exige distribuir toda la cantidad seleccionada para conservar el reparto FIFO propuesto. Reintentos son idempotentes. Ensayo local incluye clientes distintos, insuficiencia, roles, rollback, reserva, cancelación y salida múltiple.
