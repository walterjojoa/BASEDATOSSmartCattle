# Quien escribe que

Tres servicios comparten esta base. Ninguno es dueno del esquema, y eso es la
causa de casi toda la nulabilidad que hay aqui.

| Tabla | Escribe | Lee |
| --- | --- | --- |
| `cameras` | Backend (estado), personal (altas) | Backend, IA |
| `cameras.reported_status`, `last_report_at`, ... | **Solo** el backend, via `PUT /api/ai/cameras/{id}/status` | Backend |
| `zones` | Nadie todavia (semilla) | IA (la zona segura) |
| `users` | Nadie todavia | Nadie todavia |
| `animals` | Personal; la IA escribiria `last_detection` | Backend |
| `events` | Backend (`POST /api/ai/events`), y la IA puede escribir directo | Backend, tablero |
| `alerts` | Nadie todavia | Nadie todavia |
| `video_analyses`, `video_analysis_alerts` | **Solo** el backend | Backend |

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

`video_analyses` y las columnas de estado de `cameras` las creo el backend con
sus propias migraciones de Alembic y solo el las escribe. Ahi si puede haber
`NOT NULL`, y lo hay.

La diferencia practica: una columna compartida se agrega nulable y se coordina;
una columna de un solo servicio es asunto de ese servicio.

### Lo que todavia no escribe nadie

`users`, `alerts`, `zones` (mas alla de la semilla), `events.level`,
`events.zone_id` y `events.animal_tag`. Estan disenadas y vacias. No es
descuido: `animal_tag` espera a que la IA identifique animales, `level` espera
a que el backend decida la severidad en vez de que la deduzca el frontend por
el tipo de evento, y `users` espera la autenticacion real.

## La regla al cambiar algo compartido

Un rename rompio a los tres servicios a la vez una vez (ver
[decisiones.md](decisiones.md), punto 2). Desde entonces:

1. Columna nueva: **nulable**, y nadie queda obligado.
2. Columna que se va: primero deja de usarse en los tres servicios, despues se
   quita.
3. Rename: se coordina antes, no despues.
