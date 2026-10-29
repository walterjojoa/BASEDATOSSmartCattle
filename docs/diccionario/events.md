# `events`

Lo que detectan las reglas. **La tabla que más crece**, y la que manda en el
diseño del esquema.

| Columna | Tipo | NULL | Por qué |
| --- | --- | --- | --- |
| `id` | `BIGINT` identidad | no | |
| `type` | `TEXT` | no | Hoy sólo `cattle_out_of_zone`. Texto libre, no enum: ver abajo. |
| `level` | `TEXT` | no, `'medium'` | `low`, `medium`, `high`. **Ningún servicio la escribe todavía.** |
| `source` | `TEXT` | no, `'camera'` | `camera` o `image`. |
| `camera_id` | `BIGINT` → `cameras` | sí, `SET NULL` | Retirar una cámara no borra su histórico. |
| `zone_id` | `BIGINT` → `zones` | sí, `SET NULL` | De qué zona salió. Sin usar aún. |
| `animal_tag` | `TEXT` → `animals` | sí, `SET NULL` + `ON UPDATE CASCADE` | El arete. Sin usar aún: la IA no identifica animales todavía. |
| `detected_object` | `TEXT` | sí | `cow`, etc. |
| `confidence` | `DOUBLE PRECISION` | sí | De 0 a 1, con `CHECK`. Era `REAL`; ver migración `0001`. |
| `box` | `JSONB` | sí | `[x1, y1, x2, y2]` **en píxeles**, no normalizado como `zones`. |
| `width`, `height` | `INTEGER` | sí | Resolución del cuadro, que es lo que da sentido a `box`. |
| `detected_at` | `TIMESTAMPTZ` | no, `now()` | Cuándo lo detectó la IA. |
| `received_at` | `TIMESTAMPTZ` | sí | Cuándo lo recibió el backend. |
| `ai_event_id` | `UUID` | sí, `UNIQUE` | Lo que hace idempotente la ingesta. |

## `detected_at` y `received_at` son dos relojes distintos

`detected_at` es el reloj del servicio de IA, que corre en el PC del predio.
`received_at` es el del backend. Se separan bajo demora de red, y **la
diferencia entre los dos es la señal**: si crece sin que la red cambie, el
reloj del predio está desfasado. Un solo timestamp borra ese diagnóstico.

La interfaz ordena por `detected_at` (es cuándo pasó); el feed del backend
ordena por `received_at` (es lo único que el backend controla). De ahí que
existan los dos índices.

## `ai_event_id` es lo que hace idempotente la ingesta

La IA genera el UUID una vez por detección y lo reutiliza en cada reintento.
El `UNIQUE` es el mecanismo: la base rechaza el segundo `INSERT`, así que dos
reintentos simultáneos no pueden crear dos filas. Es la base la que resuelve
la carrera, no la aplicación.

Admite `NULL` — y PostgreSQL permite varios `NULL` bajo un `UNIQUE` — para no
obligar a los demás servicios a generarlo.

Sin él, un reintento tras un tiempo de espera agotado guarda el mismo
avistamiento dos veces, y la tabla no tiene cómo distinguir eso de dos
animales detectados en el mismo segundo.

## Columnas que nadie escribe todavía

`level`, `zone_id` y `animal_tag` están definidas y vacías. No es descuido:
`animal_tag` espera a que la IA identifique animales, y `level` espera a que
el backend decida la severidad en vez de que la deduzca el frontend por el
tipo de evento, que es lo que hace hoy.

## Columnas nulables, y lo que cuestan

Casi todo aquí admite `NULL`, porque varios servicios escriben en la tabla y
ninguno tiene todos los datos. El costo lo paga quien lee: el esquema `Event`
de la API **exige** `detected_object`, `confidence` y un `type` conocido, así
que el backend filtra en SQL las filas que no puede representar. Una consulta
propia que no filtre recibe filas a medias.
