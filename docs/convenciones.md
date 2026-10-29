# Convenciones

Reglas que ya sigue el esquema. Escritas para que el siguiente cambio no las
rompa sin darse cuenta.

## Nombres en ingles

Tablas y columnas en ingles, igual que la API REST, para que ningun servicio
traduzca entre los dos. Se llego aqui con una migracion que renombro todo
(`activo` paso a `active`, `ganado_fuera_zona` paso a `cattle_out_of_zone`), y
fue un cambio que rompio a todos los servicios a la vez. No se repite.

La documentacion va en espanol, porque la lee el equipo.

## Plural para las tablas, singular para las columnas

`cameras`, `events`, `alerts`. Una columna que apunta a otra tabla lleva el
singular mas `_id`: `camera_id`, `event_id`. La excepcion es `animal_tag`,
porque no apunta a un `id` sino al arete.

## Todo timestamp es TIMESTAMPTZ

Nunca `TIMESTAMP`. Lo comprueba `database/tests/02_timestamps_are_utc.sql`. Un
timestamp sin zona se lee con la del cliente, y aqui hay clientes en dos husos:
el PC del predio y Render.

## Los enumerados son TEXT con CHECK, no ENUM

`status`, `role`, `channel`, `level`, `source`. Un tipo `ENUM` de PostgreSQL
obliga a `ALTER TYPE` para agregar un valor, y eso no se puede hacer dentro de
una transaccion con otros cambios. Un `CHECK` se reemplaza en el mismo
`ALTER TABLE` que el resto de la migracion.

`type` en `events` es la excepcion: no lleva `CHECK`. Los tipos de evento los
define el servicio de IA, que evoluciona aparte, y un `CHECK` aqui lo
bloquearia. El costo es que el backend tiene que filtrar los tipos que no
conoce.

## Se desactiva, no se borra

`animals.status`, `users.is_active`, `cameras.active`, `zones.active`. Una fila
borrada deja huerfano su historico y no se distingue de una que nunca existio.
Por eso hay indices sobre esas columnas: filtrar es la consulta habitual.

## Toda clave ajena lleva indice

PostgreSQL no los crea. Sin ellos se paga dos veces: al consultar por la
relacion y al borrar el padre, que recorre la tabla hija con el padre
bloqueado. Lo comprueba `database/tests/05_foreign_keys_are_indexed.sql`.

Unica excepcion admitida: cuando un `UNIQUE` compuesto ya deja un indice cuya
**primera** columna es la clave ajena, como `zones (camera_id, name)`.

## updated_at lo mantiene la base

Con el trigger `set_updated_at()`, no la aplicacion. Varios servicios escriben
en estas tablas, y un timestamp que solo un escritor refresca empieza a mentir
en cuanto otro toca la fila.

## Toda migracion es idempotente

`IF NOT EXISTS` donde exista; un bloque `DO` que consulta el catalogo donde no,
como en `ALTER COLUMN`. CI lo comprueba aplicando todo dos veces.
