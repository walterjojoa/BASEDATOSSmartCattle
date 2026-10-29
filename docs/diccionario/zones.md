# `zones`

La zona segura de una cámara: el rectángulo del que el ganado no debería
salir. Es el `SAFE_ZONE` del prototipo, movido a la base.

| Columna | Tipo | NULL | Por qué |
| --- | --- | --- | --- |
| `id` | `BIGINT` identidad | no | |
| `camera_id` | `BIGINT` → `cameras` | no, `CASCADE` | Una zona sin cámara no significa nada, así que se va con ella. Es el único `ON DELETE CASCADE` del esquema junto con `alerts`. |
| `name` | `TEXT` | no | `UNIQUE (camera_id, name)`: dos zonas de la misma cámara no pueden llamarse igual, pero dos cámaras sí pueden tener cada una su «Safe zone». |
| `x_min`, `y_min`, `x_max`, `y_max` | `REAL` | no | Coordenadas **normalizadas entre 0 y 1**, no píxeles. |
| `active` | `BOOLEAN` | no, `TRUE` | |
| `created_at` | `TIMESTAMPTZ` | no, `now()` | |

## Por qué las coordenadas son de 0 a 1 y no píxeles

Una zona en píxeles queda atada a la resolución con la que se dibujó. Cambiar
la cámara, o que la IA procese a 640×360 lo que se configuró a 1920×1080,
movería la zona sin que nadie la toque. Normalizada, el mismo rectángulo vale
para cualquier resolución, y el `CHECK (x_min BETWEEN 0 AND 1)` lo sostiene.

El segundo `CHECK`, `x_min < x_max AND y_min < y_max`, descarta el rectángulo
invertido o de área cero: sin él, una zona con las esquinas al revés deja todo
el cuadro «fuera» y dispara una alerta por cada animal visible.

## Lo que todavía no está aquí

`zones` no tiene polígono, sólo rectángulo. El frontend ya sabe dibujar un
polígono (`SafeZone.outline`), y el prototipo usaba la misma regla del
rectángulo. Cuando el polígono se persista, esta tabla es donde va.
