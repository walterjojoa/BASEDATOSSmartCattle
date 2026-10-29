# Recetario de consultas

Las preguntas que el equipo hace de verdad, resueltas, con la trampa de cada
una anotada. Pensado para pegar en el SQL Editor de Neon.

## Los ultimos eventos, legibles

```sql
SELECT detected_at, camera_name, detected_object, round(confidence::numeric, 2) AS conf
FROM v_api_events
ORDER BY detected_at DESC
LIMIT 50;
```

Desde `v_api_events` y no desde `events`: la vista ya excluye las filas que
escribio otro servicio sin los datos que la API exige, y ya resolvio el nombre
de la camara.

## Cuantas alertas por dia, ultimas dos semanas

```sql
SELECT date_trunc('day', detected_at)::date AS dia, count(*)
FROM v_api_events
WHERE detected_at >= now() - interval '14 days'
GROUP BY dia
ORDER BY dia DESC;
```

**Trampa:** los dias sin eventos no salen. Un `GROUP BY` no inventa filas que
no existen, asi que una grafica alimentada con esto dibuja una linea continua
donde hubo un hueco. Para que salgan los ceros hay que generar las fechas:

```sql
SELECT dia::date, count(e.id)
FROM generate_series(now() - interval '14 days', now(), interval '1 day') AS dia
LEFT JOIN v_api_events e ON date_trunc('day', e.detected_at) = date_trunc('day', dia)
GROUP BY dia
ORDER BY dia DESC;
```

## Que camaras dejaron de reportar

```sql
SELECT name, effective_status, silent_for
FROM v_camera_health
WHERE effective_status <> 'online'
ORDER BY silent_for DESC NULLS LAST;
```

**Trampa:** `reported_status` no responde esto. Esa columna dice lo ultimo que
dijo la IA, y una IA que se cayo hace una hora sigue diciendo `online`. La
vista aplica la misma regla de vencimiento que el backend, asi que la consulta
no contradice a la API.
