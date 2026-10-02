# Dashboard ejecutivo — Bloques 1 a 4

Acceso desde el menú lateral del Administrador → **Dashboard ejecutivo**.
Pantalla de solo lectura, con los temas y componentes compartidos de la app.
Los cuatro bloques están integrados en la misma pantalla de consulta.

## Vista compacta ejecutiva

- Es la vista inicial. Ocho tarjetas en tres filas en escritorio, con altura
  ajustada al espacio disponible; en tablet se distribuyen en dos columnas y
  en móvil en una. Las listas largas se recorren dentro de su tarjeta.
- Filtros comunes de cliente y últimas 4/8/12/26 semanas. Cliente se aplica a
  movimientos, recepción, sobrantes, NC, salud, tablero y alertas. El período
  aplica a indicadores temporales; tablero/alertas usan pendientes actuales.
- Causales conserva el comparativo fijo últimas 4 semanas frente al histórico;
  el cliente seleccionado sí restringe ambos grupos. Esta excepción se explica
  en su ayuda para no confundir ventanas de distinta duración.
- Cada gráfico tiene ayuda `?` que abre una explicación breve de cálculo,
  denominadores, exclusiones y alcance. Las dos mini tendencias tienen ayuda
  individual además de la explicación conjunta de su tarjeta.
- Salud permite ampliar la tabla con todos los clientes, búsqueda y paginación.
  El botón de vista detallada en la cabecera conserva el desglose anterior.
- No cambia cálculos operativos, permisos, escritura ni esquema de datos.
- Carga inicial al entrar y actualización manual con «Actualizar datos».
  El switch «Tiempo real» inicia apagado en cada visita. Al activarlo consulta
  cada 5 minutos (primera recarga a los 5 minutos); apagarlo o cerrar la pantalla
  cancela el temporizador. No inicia otra consulta si hay una carga en curso.
  Desactivar el switch no cancela una petición que ya se esté procesando.
  La revalidación de sesión de seguridad (cada 30 segundos) se observa solo
  por identidad y rol: volver a recibir el mismo perfil no invalida reportes.
  Cambiar de cuenta, perder el rol, cerrar sesión o fallar su validación sí
  invalida el acceso; no se desactiva esta comprobación de seguridad.
  El kardex del dashboard usa una consulta puntual independiente del stream
  operativo. Eventos en tiempo real, filtros y cambio entre vistas compacta y
  detallada no vuelven a consultar. El botón recarga movimientos, auditoría,
  NC y snapshot; se deshabilita mientras cualquiera continúa cargando.

## Criterios del volumen semanal

- Tres líneas en un solo eje: `entrega_produccion`, `recepcion` y `despacho`.
- Fuente: `movimientos` a través de los reportes administrativos existentes.
  La RPC valida el rol en el servidor y pagina todo el historial.
- Cantidades positivas agrupadas por su propia fecha. No utiliza la fecha de
  última recepción acumulada de `lote_items`.
- Excluye movimientos con `admin_correccion_id`, incluidos ajustes de importación,
  cantidades negativas y tipos ajenos a las tres series. Es volumen bruto de
  actividad registrada, no saldo neto ni cantidad corregida a posteriori.
- Semanas de lunes a domingo en Bogotá (UTC-5); rellena con cero las semanas
  sin movimientos. El corte procede del reloj del servidor de reportes.
- 12 semanas por defecto, selección entre 4, 8, 12 y 26. La semana actual es
  parcial y se indica expresamente. No representa una proyección de cierre.
- Incluye el historial de líneas archivadas para no borrar actividad pasada.
- Una fecha o cantidad inválida se excluye y se informa. Un error de consulta
  muestra un estado de error, no cifras en cero.

Tocar o pasar el cursor sobre la gráfica consulta las tres cantidades de una
semana. «Ver datos por semana» ofrece el mismo detalle en una tabla accesible.
Los filtros operativos del kardex no restringen este panorama global.

## Calidad de recepción (Bloque 2)

- Reutiliza el reporte de auditoría de la RPC 062. Selecciona los orígenes
  `Recepción` y `Sobrantes`, sin volver a contar los eventos `Resoluciones`.
- Dona: una línea de `lote_items` cuenta una vez; solo se clasifican estados
  `recibido_conforme` y `recibido_con_novedad`. El período se aplica a su última
  recepción. El estado es el actual, no una reconstrucción del estado pasado.
  Las líneas parcialmente recibidas todavía en tránsito se muestran aparte.
- Tasa de sobrantes: unidades de `sobrantes_bodega` registradas en el período
  divididas por unidades recibidas operativas del mismo período × 100.
  Se mantiene este criterio como propuesta a falta de una preferencia distinta.
  No es el porcentaje de recepciones afectadas; puede superar el 100 %.
- Resolución: media por registro de `(fecha_resolucion - fecha)` en días con
  fracciones. Incluye registros resueltos dentro del período aunque se hayan
  creado antes. No pondera por cantidad ni promedia los promedios semanales.
- Las mini tendencias agrupan la tasa por semana de registro y el tiempo por
  semana de resolución. Sin denominador o sin resueltos se muestra «Sin datos»
  y se deja un hueco; no se inventa un cero. Los pendientes no entran al promedio.
- El bloque tiene carga/error independientes para conservar disponible la
  gráfica de volumen si falla la consulta de recepción.

## Clientes y causales (Bloque 3)

- Top 10 por unidades despachadas positivas en el período, excluyendo ajustes
  administrativos. Elección confirmada por el usuario.
- Salud incluye todos los clientes del kardex vigente y del historial hasta el
  corte, con búsqueda y páginas de 10. No se limita al top 10.
- Evalúa fechas esperadas de Producción y Logística de etapas con pendientes;
  cuenta OP distintas por cliente. Usa la fecha civil de Bogotá al corte.
- Rojo: alguna OP vencida o tasa NC superior al 5 %. Amarillo: fechas a 3 días
  o menos, tasa superior al 2 %, fechas faltantes o ausencia de denominador.
  Verde: ninguna de estas alertas. Son criterios iniciales explícitos en pantalla.
- Tasa NC: unidades reportadas en Logística + Aliados / unidades entregadas por
  Producción durante el período. Puede superar 100 % y contar la misma prenda
  en varios reportes; no es un porcentaje de prendas únicas defectuosas.
- Causales: reporte `nc` existente, deduplicado por registro. Dos barras por
  causal: últimas 4 semanas calendario (actual parcial) y todo el histórico
  hasta el corte, que incluye esas semanas. No compara tasas normalizadas.
- Se conservan estados separados de carga, error y ausencia de datos. Las
  fechas y pendientes provienen del snapshot actual del kardex, no de una
  reconstrucción histórica. No hay acciones que escriban datos.

## Atención requerida y mapa de OP (Bloque 4)

- Consulta global del estado actual, independiente del selector de semanas.
- Tablero: una OP se cuenta una vez, en la primera etapa pendiente entre todas
  sus líneas vigentes. Producción incluye reprocesos y Aliados pendientes;
  luego recepción, despacho y completo. Excluye líneas eliminadas.
- Fechas: agrupa por OP, cliente y etapa; muestra el plazo más antiguo y suma
  unidades de las líneas que están dentro de la ventana o ya vencidas.
- Sobrantes: registros pendientes con más de 7 días civiles desde su creación.
- NC: saldo pendiente actual del kardex, separado por Logística y Aliados,
  con más de 7 días desde el último reporte o liberación de la línea. No es la
  antigüedad exacta de cada prenda ni una asignación FIFO de liberaciones.
  Las liberaciones de Aliados se enlazan por solicitud al ítem original.
- Plazos configurables solo en pantalla: próximos 1/3/7 días y antigüedad
  mayor que 3/7/14/30 días. Por defecto 3 y 7. Fechas civiles de Bogotá.
- Orden: pendientes antiguos y fechas vencidas/hoy primero, de mayor a menor
  antigüedad; después próximos vencimientos, empezando por el más cercano.
- Sin fechas o historial enlazable no se infiere antigüedad. Un error de
  consulta se muestra como error; nunca como ausencia de alertas.
- Reutiliza las consultas del kardex y auditoría, sin nuevas RPC ni escrituras.
  Actualizar dashboard vuelve a consultar también su snapshot independiente,
  sin invalidar ni publicar eventos en el kardex de las pantallas operativas.

## Base de datos utilizada

Reutiliza `sql/pruebas/062_reportes_admin.sql`; si ya está aplicado en pruebas,
este bloque no requiere SQL adicional. No se ejecutaron cambios en Supabase ni
se publicó código. No aplicar el SQL de pruebas directamente a producción.

Las capturas de revisión usan datos de demostración y renderizan la pantalla
real. La pantalla conectada consulta datos reales; no sustituye errores o
ausencia de conexión con cifras de ejemplo.
