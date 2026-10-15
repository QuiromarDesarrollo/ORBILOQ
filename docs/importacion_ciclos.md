# Importación de ciclos

La lectura web usa `web/ciclos_excel_worker.js` para no bloquear la interfaz.
El archivo generado debe publicarse junto con Flutter; funciona también bajo
el prefijo `/ORBILOQ/`. Ante un error del worker no se vuelve al lector síncrono.

Después de modificar el lector, regenerar antes de construir o publicar:

```powershell
./tools/compilar_lector_ciclos.ps1
flutter build web
```

Se admiten las once columnas operativas y las referencias opcionales
`FECHA COMPROMETIDA ENTREGA` y `FILA ORIGINAL`. Estas últimas se muestran
en la revisión pero no se persisten ni modifican los indicadores. La fecha
comprometida se valida independientemente de la secuencia de procesos.

La revisión y el guardado usan la RPC transaccional existente, sin dividir la
importación en guardados parciales. El guardado requiere confirmación. El éxito
solo se anuncia después de recibir la respuesta y completar la recarga.
Si falla la recarga tras guardar, el mensaje distingue ambos resultados.
Si vence el tiempo de espera del guardado, el resultado es incierto: actualizar
antes de reintentar; el cliente no puede cancelar la transacción del servidor.

## Rendimiento después de la carga

Cada respuesta del servidor crea una instantánea inmutable. El calendario usa
prefijos de días hábiles por año; las mediciones, metas e indicadores se reutilizan
dentro de esa instantánea. Al cambiar datos, revisión, cliente o fechas se crean
los cálculos correspondientes, sin conservar valores de filtros anteriores.
La preparación inicial cede al navegador cada bloque de unos 8 ms. La lista de
OP atrasadas construye solo las filas visibles.

Medición reproducible: `dart run tools/benchmark_ciclos.dart 10000` (o `50000`).
Compara cálculos, no transferencia de red, persistencia ni renderizado completo.
En el equipo de desarrollo, 10.000 OP pasaron de 12.875 ms a 995 ms inicialmente,
y de 11.593 ms a 17 ms al repetir; la suma de control fue idéntica.
Con 50.000 OP: 4.181 ms iniciales y 82 ms repetidos. Los tiempos varían por equipo.

El límite transaccional existente sigue siendo 10.000 OP por archivo (20 MB).
El histórico acumulado puede superar ese número. Esta optimización no convierte
la carga del histórico completo en ilimitada: para volúmenes mayores deben
evaluarse agregados y filtros en servidor, y paginación de consultas por demanda.
