# Diccionario de datos

Una ficha por tabla. Cada columna con su tipo, si admite `NULL`, y **por qué
es así**. El tipo se lee en `schema.sql`; lo que no se lee ahí es el motivo, y
es lo que se pierde primero.

| Tabla | Ficha | Filas que crecen |
| --- | --- | --- |
| `cameras` | [cameras.md](cameras.md) | No (una por cámara del predio) |
| `zones` | [zones.md](zones.md) | No (una o dos por cámara) |
| `users` | [users.md](users.md) | No (el personal del predio) |
| `animals` | [animals.md](animals.md) | Lento (el hato) |
| `events` | [events.md](events.md) | **Sí, sin techo** |
| `alerts` | [alerts.md](alerts.md) | **Sí, con los eventos** |

Las dos últimas son las que mandan en el diseño: todo índice, todo `CASCADE` y
toda decisión de retención se justifica contra ellas.
