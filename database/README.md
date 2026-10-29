# `database/`

| Archivo | Que es |
| --- | --- |
| [`install.sql`](install.sql) | **Una base nueva se crea con esto.** Aplica el esquema y todas las migraciones, en orden. |
| [`schema.sql`](schema.sql) | Estado final de las **tablas**. No incluye indices, vistas ni comentarios posteriores. |
| [`migrations/`](migrations/) | Un archivo por cambio, numerado, idempotente. |
| [`tests/`](tests/) | Comprobaciones en SQL plano. Silencio es exito. |
| [`seed-dev.sql`](seed-dev.sql) | Camaras, zonas, personal y hato de desarrollo. |
| [`seed-dev-events.sql`](seed-dev-events.sql) | 40 eventos repartidos en 48 horas. Se puede repetir. |

Documentacion en [`../docs/`](../docs/): diccionario por tabla, runbooks,
diagrama, recetario de consultas, convenciones, seguridad y rendimiento.

## `schema.sql` solo no alcanza

Describe las tablas y nada mas. Los indices de claves ajenas, los indices
parciales, las tres vistas, la funcion de retencion, los comentarios de columna
y `zones.outline` llegaron despues, como migraciones.

Una base creada con `schema.sql` a secas tiene las tablas correctas y ninguna
de esas cosas, y la diferencia no se nota hasta que una consulta va lenta o
una vista que el backend espera no existe. Para eso esta `install.sql`.

## Las migraciones

Idempotentes: volver a correrlas no falla ni duplica. `IF NOT EXISTS` donde
PostgreSQL lo admite, y un bloque `DO` que consulta el catalogo donde no, como
en `ALTER COLUMN`.

No hay tabla de versiones. Varios servicios comparten esta base y ninguno es
dueno del esquema, asi que una tabla de versiones tendria que tener un solo
escritor autorizado y no lo hay (ver
[`../docs/decisiones.md`](../docs/decisiones.md), punto 9).

Toda migracion nueva **tiene que** agregarse a `install.sql`.
`scripts/check-install-lists-migrations.sh` lo comprueba en CI, porque esa
omision ya paso una vez y el resto del pipeline no la nota.

## Las del backend son aparte

SmartCattle-Backend lleva sus propias migraciones de Alembic en
`migrations/versions/`, solo para lo que el agrego:
`cameras.reported_status`, `stream_url` y las tablas `video_analyses`. Las
aplica el mismo en cada deploy.

Los dos juegos son independientes. Las de aqui tocan las tablas compartidas;
las suyas, las propias.

**Se tocan en un punto:** `v_camera_health` (migracion `0012`) necesita
`cameras.last_report_at`, que crea el backend. Si no esta, la migracion lo
avisa con un `NOTICE` y se salta la vista en vez de fallar.
