# Rendimiento

Que indices hay, para que consulta existe cada uno, y como comprobar que
sirven.

## Los indices de `events`

`events` es la tabla que crece sin techo, y la que tiene mas indices. Cada uno
responde a una consulta concreta:

| Indice | Consulta | Origen |
| --- | --- | --- |
| `events_detected_at_idx` | La interfaz, ordenada por cuando paso | `schema.sql` |
| `events_type_detected_idx` | Por tipo, ordenada por fecha | `schema.sql` |
| `events_animal_tag_idx` | Los eventos de este animal | `schema.sql` |
| `events_camera_id_idx` | Los eventos de esta camara, y el `SET NULL` al retirarla | `0002` |
| `events_zone_id_idx` | Igual, por zona | `0002` |
| `events_received_at_idx` | El feed del backend, ordenado por recepcion | `0004` |
| `events_api_listable_idx` | Solo las filas que la API puede representar | `0009` |

Siete indices sobre la tabla de mayor escritura es mucho, y hay que decirlo:
**cada indice se paga en cada `INSERT`**. La ingesta de la IA es un `INSERT`
por deteccion, asi que esto no es gratis. La compensacion es que ninguna
consulta de lectura recorre la tabla completa.

## Comprobar que un indice se usa

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM v_api_events ORDER BY detected_at DESC LIMIT 50;
```

Lo que se busca en la salida:

- `Index Scan` o `Index Only Scan` -> bien.
- `Seq Scan` sobre `events` -> el indice no se esta usando. En una tabla con
  pocas filas eso es **correcto**: recorrer 40 filas es mas rapido que leer un
  indice. Solo es un problema con volumen real.
- `Rows Removed by Filter` alto -> el indice trae filas que luego se
  descartan; falta una condicion en el indice o sobra en la consulta.

`ANALYZE` ejecuta la consulta de verdad. Sobre un `DELETE` o un `UPDATE`,
**lo hace**, asi que se envuelve en una transaccion y se revierte.

## Cual indice no sirve para nada

```sql
SELECT indexrelname, idx_scan, pg_size_pretty(pg_relation_size(indexrelid)) AS tamano
FROM pg_stat_user_indexes
WHERE relname = 'events'
ORDER BY idx_scan;
```

`idx_scan = 0` sobre una base con trafico real quiere decir que ese indice
cuesta escrituras y espacio y no sirve a ninguna consulta.

Dos avisos: el contador se reinicia al reiniciar las estadisticas, asi que un
cero recien reiniciado no prueba nada; y un indice que sostiene un `UNIQUE` o
una clave primaria **no se borra** aunque nunca se escanee, porque su trabajo
es rechazar duplicados, no acelerar lecturas.

## Las estadisticas, cuando el plan es raro

PostgreSQL elige el plan con estadisticas que `ANALYZE` recoge. Despues de una
carga grande -- sembrar datos, restaurar un respaldo -- estan desactualizadas y
el planificador decide con numeros viejos:

```sql
ANALYZE events;
```

Es lo primero que hay que probar cuando una consulta se volvio lenta sin que
cambiara ni la consulta ni los indices.
