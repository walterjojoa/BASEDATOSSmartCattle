# Comprobar una base sin tocarla

Para responder "esta bien esta base?" sin escribir nada. Util contra
produccion, donde las comprobaciones de `database/tests/` **no** se pueden
correr porque insertan filas.

## Esta completa

```sql
-- Las seis tablas
SELECT count(*) FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('alerts', 'animals', 'cameras', 'events', 'users', 'zones');
-- Esperado: 6

-- Las vistas de las migraciones
SELECT count(*) FROM information_schema.views
WHERE table_schema = 'public' AND table_name LIKE 'v_%';
-- Esperado: 3 (2 si faltan las columnas de estado del backend)

-- confidence se amplio
SELECT data_type FROM information_schema.columns
WHERE table_name = 'events' AND column_name = 'confidence';
-- Esperado: double precision
```

Si `confidence` dice `real`, la migracion `0001` no se aplico, y entonces
probablemente ninguna.

## Cuanto pesa y donde

```sql
SELECT relname,
       pg_size_pretty(pg_total_relation_size(relid)) AS total,
       pg_size_pretty(pg_indexes_size(relid))        AS indices,
       n_live_tup                                    AS filas_aprox
FROM pg_catalog.pg_statio_user_tables s
JOIN pg_stat_user_tables USING (relid)
ORDER BY pg_total_relation_size(relid) DESC;
```

## Hay filas que la API no puede listar

```sql
SELECT count(*) AS total,
       (SELECT count(*) FROM v_api_events) AS listables,
       count(*) FILTER (WHERE ai_event_id IS NULL) AS sin_id_de_ia
FROM events;
```

Una diferencia grande no es un error: significa que otro servicio escribe
directo. Lo que importa es si **crece**.

## Las camaras responden

```sql
SELECT name, effective_status, silent_for FROM v_camera_health ORDER BY name;
```

## Hay conexiones colgadas

```sql
SELECT state, count(*), max(now() - state_change) AS mas_vieja
FROM pg_stat_activity
WHERE datname = current_database()
GROUP BY state;
```

`idle` con una antiguedad grande y en cantidad quiere decir que algun
despliegue no libero su pool. El plan gratuito de Neon las cuenta contra el
limite.

## Las estadisticas estan frescas

```sql
SELECT relname, last_analyze, last_autoanalyze
FROM pg_stat_user_tables ORDER BY relname;
```

Un `last_analyze` muy viejo en `events` explica un plan de consulta raro. Se
arregla con `ANALYZE events;`, que es lo primero que hay que probar cuando una
consulta se volvio lenta sin que cambiara nada.
