# Guía del equipo de diseño ORBILOQ

## Decisiones aprobadas
Referencias: Producción, Bodega y Despacho. Primera revisión: Producción. Ajustes menores autorizados se implementan en DEV; los rediseños importantes se presentan antes de implementar. Un coordinador asigna archivos, integra y solicita revisión de cada entrega visual.

## Referencias reales del repositorio
| Área | Archivos de referencia |
| --- | --- |
| Tema y colores | `lib/core/theme/app_theme.dart` |
| Tabla principal | `lib/features/kardex/presentation/kardex_table.dart` |
| Producción | `lib/features/produccion/presentation/entrega_produccion_dialog.dart`, `historial_produccion.dart` |
| Bodega | `lib/features/recepcion/presentation/recepcion_dialog.dart`, `historial_recepcion_vista.dart` |
| Despacho | `lib/features/despacho/presentation/despacho_dialog.dart`, `lista_empaque_dialog.dart`, `historial_despachos_vista.dart` |

Las rutas abreviadas de la tabla corresponden a la misma carpeta que el primer archivo de su fila. Estas pantallas son referencias, no una garantía de que todo su código ya esté normalizado. Comparar comportamientos y estilos antes de copiar.

## Catálogo compartido inicial
Todos estos archivos están en `lib/shared/widgets/`; verificar sus APIs vigentes antes de usarlos.

| Necesidad | Referencia |
| --- | --- |
| Modal, título, cierre y pantalla completa | `wms_dialog.dart` |
| Acciones y estado ocupado | `action_button.dart` |
| Indicadores de carga | `wms_loader.dart` |
| Alertas, confirmación y mensajes | `wms_alert.dart`, `feedback_banner.dart` |
| Estados sin registros | `wms_empty_state.dart` |
| Escáner y cámara | `wms_scan_field.dart`, `wms_camera_scanner.dart` |
| Filtros de selección múltiple | `multi_select_filter.dart` |
| Indicadores y etiquetas | `metric_card.dart`, `status_chip.dart` |
| Distribución adaptable | `responsive_row.dart` |
| Bienvenida y usuario | `bienvenida_usuario.dart`, `operario_actual.dart` |

Usar los tokens de `AppColors` y el tema activo. La paleta corporativa actual define petróleo `#093E52` y lima `#C2D501`; el archivo de tema es la fuente de verdad, no duplicar estos valores en nuevas vistas. Reservar colores semánticos para éxito, advertencia y error. Evitar que un estilo global invalide el contraste de botones o estados deshabilitados.

## Procedimiento por tarea
1. El coordinador identifica objetivo, pantallas, contexto operativo y criterios de aceptación. Revisa cambios locales existentes.
2. UX identifica problemas operativos; UI define composición y estados; componentes identifica reutilización y consumidores. Delegar solo lo necesario y respetar los límites de concurrencia de la sesión.
3. Clasificar: detalle menor o rediseño importante. En el segundo caso producir propuesta revisable y esperar aprobación; en el primero implementar dentro del alcance autorizado.
4. Asignar un único responsable por archivo. Para extraer componentes acordar primero su API y los consumidores.
5. El revisor visual comprueba resultado y evidencia; `orbiloq_responsive_flujos` verifica las tareas afectadas por dispositivo y método de entrada, compartiendo las comprobaciones comunes. El coordinador resuelve hallazgos pertinentes y repite únicamente verificaciones afectadas.
6. Entregar resultado breve con capturas cuando aporten valor, pruebas ejecutadas, limitaciones y estado de disponibilidad en DEV.

## Criterios de aceptación
- Jerarquía clara: título, contexto, acción principal y secundarias. Botones proporcionados a su función; evitar múltiples acciones visualmente dominantes.
- Tablas con encabezados legibles, columnas diferenciadas, ancho aprovechado, alineación numérica y filtros que no aparenten filtrar datos que no están consultados. Scroll horizontal cuando el contenido lo requiere, sin recortar acciones.
- Tarjetas con identidad, datos operativos, avance y controles agrupados. Preservar cantidades y límites del servidor.
- Escaneo y entrada manual: foco predecible, teclado funcional, lecturas repetidas sin duplicación accidental de movimientos, respuesta clara ante código ajeno, exceso o error de red.
- Loaders acordes con el alcance: botón para una acción local, sección para carga parcial, bloqueo general solo si toda la vista realmente está ocupada.
- Verificar tamaños representativos de 320/390, 768 y 1440/1920 px según la vista. Sin overflow; contenido accesible mediante scroll; controles táctiles cómodos y foco visible.
- Verificar contraste, etiquetas accesibles, navegación con teclado y señales de estado que no dependan solo del color.
- Considerar carga, vacío, error, éxito, deshabilitado, listas largas y textos extensos. No eliminar controles necesarios solo para simplificar la apariencia.
- Mantener reglas de negocio y permisos. Si el cambio visual exige modificar comportamiento, explicar y delimitarlo antes de actuar.

## Formato de hallazgo
Severidad · pantalla/archivo · escenario · problema observado · impacto · recomendación · componente reutilizable · evidencia/verificación. Separar hallazgos comprobados de hipótesis. No presentar una prueba automatizada como inspección visual de una sesión real.

## Primera auditoría: Producción
Revisar entregas por escáner y manual, tarjetas de prendas, resúmenes, confirmación del lote, historial, filtros, modales y estados. Comparar con Bodega y Despacho. Preparar lista priorizada antes de ampliar el alcance. La creación de estos archivos no significa que esa auditoría ya se haya ejecutado.

## Responsive y flujo operativo en todos los módulos
El agente `orbiloq_responsive_flujos` revisa módulos existentes y futuros. Se invoca en cambios de pantallas e interacción y en auditorías solicitadas. Su creación no ejecuta una auditoría completa ni activa vigilancia permanente.

Para cada revisión entregar una matriz: módulo/flujo, rol, viewport, método de entrada, estado, resultado, evidencia y pendientes. Cubrir las tareas afectadas desde el inicio hasta la confirmación o recuperación, no solo pantallas estáticas. Utilizar datos de prueba aislados; la revisión visual no autoriza movimientos reales ni cambios en bases compartidas.

La comprobación incluye móvil, tablet y escritorio; breakpoints, altura reducida, teclado abierto, texto ampliado, scroll, foco, cierre y reapertura, estados de carga/error y protección frente a doble envío. Simulación de viewport y dispositivo físico deben identificarse por separado. La ausencia de desbordamientos no basta para aprobar un flujo.

Se coordina con UX para las propuestas, componentes para soluciones reutilizables y revisión visual para la presentación. Solo puede implementar correcciones menores si el coordinador le asigna los archivos; los rediseños importantes siguen el proceso de aprobación existente.

## Invocaciones sugeridas
- «Usa el agente responsive y flujos para revisar este módulo en móvil, tablet y escritorio; informa los recorridos que verificaste y corrige los detalles menores autorizados en DEV».
- «Revisa Producción con los agentes de diseño: detecta inconsistencias y corrige detalles menores en DEV; presenta los rediseños importantes antes de implementarlos».
- «Pide al especialista de componentes que revise si esta vista reutiliza los componentes de ORBILOQ y al revisor visual que compruebe el resultado».
- «Antes de implementar esta pantalla, prepara la propuesta UX/UI siguiendo Producción, Bodega y Despacho».

Los agentes se invocan durante un trabajo; no hay monitorización ni ejecución en segundo plano configurada. No se fija modelo: se hereda el modelo disponible de la sesión.

## Documentación de configuración
Esquema consultado: https://learn.chatgpt.com/docs/agent-configuration/subagents
Instrucciones de proyecto: https://learn.chatgpt.com/docs/agent-configuration/agents-md
