# `cameras`

Las cámaras del predio. Una fila por cámara física.

| Columna | Tipo | NULL | Por qué |
| --- | --- | --- | --- |
| `id` | `BIGINT` identidad | no | Clave primaria numérica. Aquí sí es correcta: una cámara no tiene identificador natural estable, y `name` cambia cuando el personal la renombra. |
| `name` | `TEXT` | no, `UNIQUE` | El identificador que usan la API y el servicio de IA (`camera-01`). El `UNIQUE` es lo que permite el `ON CONFLICT (name) DO NOTHING` con el que el backend crea la fila sin riesgo cuando dos peticiones llegan a la vez. |
| `source` | `TEXT` | no, `'0'` | Índice USB, ruta de video o URL RTSP. Es configuración del servicio de visión, no de la API; por eso es texto libre y no un enum. |
| `location` | `TEXT` | sí | Descripción para una persona («portón norte»). No la consume ningún servicio. |
| `active` | `BOOLEAN` | no, `TRUE` | Se baja para retirar una cámara sin borrar sus eventos. |
| `created_at` | `TIMESTAMPTZ` | no, `now()` | |

## Columnas que agregó el backend

No están en `schema.sql`: las crea la migración `0002_camera_status` de
SmartCattle-Backend, y **todas admiten `NULL`**, así que no obligan a nada a
los servicios que no reportan estado.

| Columna | Para qué |
| --- | --- |
| `reported_status` | `online`, `offline` o `error`, lo último que dijo la IA. |
| `last_report_at` | Cuándo lo dijo. Es lo que convierte «online» en «online *todavía*»: pasado `CAMERA_OFFLINE_AFTER_SECONDS` el backend la da por caída aunque la columna siga diciendo `online`. |
| `last_online_at` | Última vez que estuvo en línea. Sobrevive a una caída, `last_report_at` no. |
| `last_error` | Mensaje corto. Nunca una URL: podría traer credenciales. |
| `frame_width`, `frame_height`, `fps` | Formato del video observado. |
| `stream_url` | URL pública del video. Sólo se guarda mientras la cámara está en línea, y se rechaza si trae usuario y contraseña, porque esta columna se publica tal cual en `GET /api/cameras`. |

## Trampa

Existen filas de cámaras que **nadie reportó nunca**: la semilla
`Main camera` y las que el backend crea la primera vez que un evento nombra
una cámara. En esas, los dos `*_status` están en `NULL`. `GET /api/cameras`
las filtra por eso; una consulta propia que no lo haga recibe una cámara sin
estado.
