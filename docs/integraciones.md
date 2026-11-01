# Quien escribe que

Tres servicios comparten esta base. Ninguno es dueno del esquema, y eso es la
causa de casi toda la nulabilidad que hay aqui.

| Tabla | Escribe | Lee |
| --- | --- | --- |
| `cameras` | Backend (estado), personal (altas) | Backend, IA |
| `cameras.reported_status`, `last_report_at`, ... | **Solo** el backend, via `PUT /api/ai/cameras/{id}/status` | Backend |
| `zones` | Backend (`/api/zones`, lo que dibuja el personal) | Backend, IA (la zona segura) |
| `users` | Backend (`/api/auth/*`, `/api/users`) | Backend |
| `animals` | Backend (`/api/animals`); la IA reporta `last_detection` por el backend | Backend |
| `events` | Backend (`POST /api/ai/events`), y la IA puede escribir directo | Backend, tablero |
| `alerts` | Nadie todavia | Nadie todavia |
| `farms`, `lots`, `security_alerts`, `camera_occupancy`, `video_uploads` | **Solo** el backend | Backend |
| `video_analyses`, `video_analysis_alerts` | **Solo** el backend | Backend |
| `occupancy_samples`, `camera_status_changes`, `audit_log` | **Solo** el backend | Backend (`/api/reports/*`, `/api/audit-log`), y cualquiera por las vistas `v_*` |
| Catalogos (`lot_kinds`, `user_roles`, ...) | Nadie: los siembra la migracion `0015` del backend | Backend (`/api/catalogs`) |

## Lo que se deduce de la tabla anterior

### Casi todo admite `NULL` porque hay mas de un escritor

Ningun servicio tiene todos los datos. La IA detecta un objeto y no sabe de
que animal es; el personal registra un animal y no sabe donde esta. Una
columna `NOT NULL` obligaria al escritor que no tiene ese dato a inventarlo.

**El costo lo paga quien lee.** El esquema `Event` de la API exige
`detected_object`, `confidence`, `received_at` y un `type` conocido, y las
cuatro admiten `NULL` aqui. El backend las filtra en SQL, y `v_api_events`
existe para que ese filtro este escrito una sola vez.

### Las tablas que son de un solo servicio

Las columnas de estado de `cameras` y las siete tablas de
[diccionario/tablas-del-backend.md](diccionario/tablas-del-backend.md) las
creo el backend con sus propias migraciones de Alembic y solo el las escribe.
Ahi si puede haber `NOT NULL`, y lo hay.

La diferencia practica: una columna compartida se agrega nulable y se coordina;
una columna de un solo servicio es asunto de ese servicio.

### Lo que todavia no escribe nadie

`alerts`, `events.zone_id` y `events.animal_tag`. Estan disenadas y vacias.
No es descuido: `animal_tag` espera a que la IA identifique animales, y
`alerts` a que existan las notificaciones salientes. Los incidentes que el
personal atiende en el tablero van en `security_alerts`, del backend.

## La regla al cambiar algo compartido

Un rename rompio a los tres servicios a la vez una vez (ver
[decisiones.md](decisiones.md), punto 2). Desde entonces:

1. Columna nueva: **nulable**, y nadie queda obligado.
2. Columna que se va: primero deja de usarse en los tres servicios, despues se
   quita.
3. Rename: se coordina antes, no despues.
