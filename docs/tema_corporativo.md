# Modo Corporativo Quiromar

Tercera apariencia visual, junto a Claro y Oscuro. Seleccionable desde «Elegir apariencia» en Kardex y dashboards; en la barra compacta, desde el menú de opciones. No requiere SQL ni modifica datos operativos. La preferencia es de la sesión, igual que el selector anterior.

Colores principales muestreados del logo adjunto: petróleo #093E52 y celeste #268CC0, complementados por celeste suave #9DD8F2. El tema usa superficies blancas y fondo gris azulado, navegación petróleo con texto claro, botones principales petróleo, selecciones celestes con texto petróleo y celeste en la paleta de gráficos. Para textos informativos sobre blanco se utiliza un celeste más oscuro (#176888). Se elimina el verde lima de los acentos de la interfaz; el logo conserva su identidad original.

Se conserva el significado de los colores de estados operativos. El verde de una entrega completada y el rojo de una devolución no se sustituyen por colores de marca. Las tablas usan cabeceras petróleo con texto blanco y filas claras para facilitar la lectura. Los formularios mantienen superficies claras con los acentos corporativos.

La implementación usa ThemeData/ColorScheme y AppPalette de Flutter (no CSS), un selector común y una paleta específica para navegación. Los modos Claro y Oscuro siguen disponibles. Los diálogos utilitarios conservan su comportamiento claro anterior en esos dos modos y reciben los acentos corporativos en el nuevo.

Validación: contraste mínimo 4.5:1 en las parejas de texto/superficie principales comprobadas por `test/tema_corporativo_test.dart`; selección de tres modos y propagación a diálogos. Se verificaron los dashboards en móvil, tablet y escritorio con los tests existentes que recorren TemaModo.values. Esto no constituye una auditoría completa de accesibilidad de todos los componentes.

Actualización de mayor presencia corporativa: fondo azul gris más marcado, tarjetas KPI en degradado petróleo con cifras blancas e iconos celestes, cabeceras de tabla petróleo con texto blanco, superficies de gráficas celestes y selecciones celestes más visibles. Se mantienen las filas y campos de lectura claros.

Preferencia actual: se conserva el verde habitual (#0F766E) para acciones, enlaces e iconos, con selecciones verde suave y acentos menta sobre navegación oscura. Solo se excluye el verde lima. El petróleo y celeste siguen presentes en estructura, fondos y gráficas.

Preferencia definitiva indicada por código: acentos #C2D501 (verde lima), con texto petróleo para contraste, sobre la estructura petróleo y celeste. Sustituye la preferencia anterior de eliminar lima. Los colores semánticos de estados se conservan.
