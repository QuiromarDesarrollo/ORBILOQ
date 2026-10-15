# Control de ciclos: acuerdos y evolución pendiente

Registro: 2026-10-14. El usuario pospone el flujo ampliado por falta de información; por ahora quiere trabajar con el Excel actual y evaluar campos adicionales. Este documento no autoriza implementar ni desplegar el flujo futuro.

## Base actual

N° DE ORDEN, CLIENTE, CANTIDAD, FECHA DE INICIO, COMPRAS, TRAZO, CORTE, SEPARADO, ALIADOS, TERMINADO, LOGISTICA.

## Acuerdos del proceso

- Una OP contiene un solo tipo de prenda. El reloj comienza al subir la orden, desde Compras.
- Días hábiles de lunes a viernes, excluidos festivos nacionales de Colombia.
- Objetivos internos: Compras 6, Trazo 3, Corte 3, Separado 4, Aliados 11, Terminado 2 y Despacho 3: total 32 más reserva central de 3. Máximo general 35; rutas cortas con objetivos internos menores, sin redistribuir artificialmente los 32 días.
- Los plazos no se amplían según cantidad ni tipo de prenda.
- La ficha define la ruta. Ejemplos: ruta completa; Compras–Aliados–Terminado–Despacho; Compras–Terminado–Despacho; Compras–Despacho.
- Bordado, estampado y ribetes van en paralelo y pueden ubicarse en distintas áreas. Falta especificar por ruta qué etapa requiere su conclusión.
- Hay transferencias parciales, por cantidad de OP, sin necesidad de talla. El modelo futuro debe conservar primera entrada, parciales y cierre completo sin duplicar cantidades ni sumar duraciones solapadas para el ciclo total.
- La asignación al satélite es la entrega física al taller. Se prevé registrar asignación, recepción e inspección por taller; confirmar detalle operativo de división entre talleres.
- La tabla de objetivos divide Aliados en 2 días de asignación + 7 de confección + 2 de inspección. Sigue pendiente el hito inicial de los 2 días previos a entrega física; no asumirlo.
- Reproceso: máximo 2 días hábiles desde rechazo de inspección. No ampliar la promesa original ni ocultar impacto en carga o reserva. Retornos no cuentan como nuevas prendas.
- Terminado se mide como etapa única; no se medirán botones, ojales, plancha y remate por separado.
- Despacho empieza al recibir físicamente en bodega y termina al salir físicamente de despacho, NO al entregar al cliente. Esta definición reemplaza la propuesta inicial de entrega al cliente.
- Cargas asignadas manualmente por taller, como en el programa actual. Falta confirmar si se captura cantidad asignada, capacidad diaria/semanal o ambas; no confundirlas ni calcular ocupación sin capacidad comparable.
- Cortes del Excel a las 12:00 y aproximadamente 16:00; debe mostrarse corte real de datos.

## Desarrollo futuro pospuesto

Rutas versionadas por ficha y OP; movimientos parciales con identificadores estables; asignaciones e inspecciones; devoluciones y retornos de reproceso; capacidad por proceso/taller y vigencia; calendario; control de importación e idempotencia. Reutilizar registros de ORBILOQ antes de pedir captura duplicada.

Solicitar cuando se retome: fichas/rutas, Excel histórico, ejemplo de asignación manual, capacidades disponibles, corte inicial de OP abiertas, responsables y origen de actualización. No reconstruir parciales ni talleres desde fechas de cierre.

## Propuesta mínima para discusión, aún no aprobada

Conservar columnas de fechas; añadir código de ruta, fecha comprometida de salida y fecha/hora de corte. Catálogo pequeño de rutas con procesos aplicables y tiempos; un vacío en fecha de etapa aplicable significa pendiente, mientras la ruta distingue no aplicable. Definir si las fechas antiguas son realmente cierres completos y si LOGISTICA refleja salida física. Ficha técnica puede incorporarse cuando exista catálogo fiable. No cambiar todavía el importador ni exigir nuevas columnas al archivo actual.
