# Cuando la base se acerca al limite

Neon da 1 GB. La tabla que lo va a consumir es `events`, y con ella `alerts`.

## Ver donde esta el espacio

```sql
SELECT relname AS tabla,
       pg_size_pretty(pg_total_relation_size(relid)) AS total,
       pg_size_pretty(pg_relation_size(relid))       AS solo_filas,
       pg_size_pretty(pg_indexes_size(relid))        AS indices
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;
```

`pg_total_relation_size` incluye los indices, y esa es la cifra que importa:
en `events` los indices pesan comparable a las filas, porque hay siete.

## Contar antes de borrar

```sql
SELECT count(*) FROM events WHERE detected_at < now() - interval '90 days';
```

Siempre antes del borrado. El `count` es lo que convierte "creo que sobran
unos cuantos" en una decision.

## Recortar

```sql
SELECT prune_events(interval '90 days');
```

Devuelve cuantas filas borro. Las alertas se van con sus eventos por el
`ON DELETE CASCADE`.

## Recuperar el espacio de verdad

Un `DELETE` no devuelve el espacio al sistema: marca las filas como muertas y
las reutiliza para escrituras futuras. Si hace falta el espacio **ahora**:

```sql
VACUUM (ANALYZE) events;
```

Esto basta en la mayoria de los casos. `VACUUM FULL` si devuelve el espacio al
disco, pero **bloquea la tabla completa** mientras la reescribe, asi que no se
corre en horario de operacion.

## Antes de borrar nada, mira si sobran indices

Siete indices sobre `events` es mucho. Esta consulta dice cuales no se usan:

```sql
SELECT indexrelname, idx_scan, pg_size_pretty(pg_relation_size(indexrelid))
FROM pg_stat_user_indexes
WHERE relname = 'events'
ORDER BY idx_scan;
```

`idx_scan = 0` sobre una base con trafico real quiere decir que ese indice
cuesta escrituras y espacio y no sirve a ninguna consulta. Ojo: el contador se
reinicia con las estadisticas, asi que un cero recien reiniciado no prueba
nada.
