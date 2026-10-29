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

## Animales que no se ven desde hace mucho

```sql
SELECT tag, name, camera_name, unseen_for
FROM v_active_herd
WHERE last_detection IS NULL OR last_detection < now() - interval '2 days'
ORDER BY last_detection NULLS FIRST;
```

**Trampa:** el `IS NULL` va primero y no es un detalle. Un animal que nunca se
detecto tiene `last_detection` en `NULL`, y `NULL < now() - interval '2 days'`
no es verdadero sino **desconocido**, asi que un `WHERE` sin el `IS NULL`
esconde justo a los animales que nunca aparecieron. `NULLS FIRST` los pone
arriba, que es donde deben estar.

## La cola de envio

```sql
SELECT a.id, a.channel, a.created_at, now() - a.created_at AS esperando,
       e.type, c.name AS camera_name
FROM alerts a
JOIN events  e ON e.id = a.event_id
LEFT JOIN cameras c ON c.id = e.camera_id
WHERE a.status = 'pending'
ORDER BY a.created_at;
```

El `JOIN` a `events` es interno porque `alerts.event_id` es `NOT NULL`; el de
`cameras` es `LEFT` porque `events.camera_id` admite `NULL` tras retirar una
camara. Mezclarlos al reves esconde alertas.

Usa `alerts_pending_queue_idx`, el indice parcial de la migracion 0007.

## Reintentos fallidos, con el motivo

```sql
SELECT channel, count(*), max(created_at) AS ultimo, min(detail) AS ejemplo
FROM alerts
WHERE status = 'failed'
GROUP BY channel
ORDER BY count(*) DESC;
```

## Deteccion duplicada: comprobar la idempotencia

```sql
SELECT ai_event_id, count(*)
FROM events
WHERE ai_event_id IS NOT NULL
GROUP BY ai_event_id
HAVING count(*) > 1;
```

Tiene que devolver **cero filas siempre**: el `UNIQUE` lo garantiza. Si alguna
vez devuelve algo, el `UNIQUE` se cayo, y entonces la ingesta dejo de ser
idempotente sin que nadie se enterara.

## Filas que la API no puede listar, y por que

```sql
SELECT count(*) FILTER (WHERE ai_event_id     IS NULL) AS sin_id_de_ia,
       count(*) FILTER (WHERE received_at     IS NULL) AS sin_received_at,
       count(*) FILTER (WHERE detected_object IS NULL) AS sin_objeto,
       count(*) FILTER (WHERE confidence      IS NULL) AS sin_confianza,
       count(*) AS total
FROM events;
```

Util cuando el feed muestra menos eventos de los que hay en la tabla. Dice
cuantas filas quedan fuera y por cual de las cuatro condiciones, que es
exactamente la pregunta siguiente.

## Desfase entre el reloj de la IA y el del backend

```sql
SELECT date_trunc('hour', received_at) AS hora,
       count(*),
       avg(received_at - detected_at)  AS demora_media,
       max(received_at - detected_at)  AS peor
FROM events
WHERE received_at IS NOT NULL AND detected_at IS NOT NULL
  AND received_at >= now() - interval '2 days'
GROUP BY hora
ORDER BY hora DESC;
```

Esta es la consulta para la que existen las dos columnas. Una demora media que
crece sin que la red cambie quiere decir que el reloj del PC del predio se
esta desfasando. Un valor **negativo** es mas claro todavia: el reloj de la IA
va adelantado.
