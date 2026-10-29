# Incidentes

Que mirar primero, por sintoma. El orden importa: cada paso descarta una
causa.

## El feed de eventos esta vacio o muestra menos de lo que hay

1. Cuantas filas hay y cuantas puede listar la API:

   ```sql
   SELECT count(*) AS total, (SELECT count(*) FROM v_api_events) AS listables
   FROM events;
   ```

2. Si la diferencia es grande, por que quedan fuera:

   ```sql
   SELECT count(*) FILTER (WHERE ai_event_id     IS NULL) AS sin_id_de_ia,
          count(*) FILTER (WHERE received_at     IS NULL) AS sin_received_at,
          count(*) FILTER (WHERE detected_object IS NULL) AS sin_objeto,
          count(*) FILTER (WHERE confidence      IS NULL) AS sin_confianza
   FROM events;
   ```

El esquema `Event` de la API exige esas cuatro columnas y aqui las cuatro
admiten `NULL`. Una fila incompleta **no** tumba la respuesta -- el backend
las filtra en SQL a proposito -- pero tampoco se lista. Si todas las filas
caen en una misma columna, el escritor que las produce esta mal configurado.

## Una camara aparece caida y el servicio de IA esta corriendo

```sql
SELECT name, reported_status, effective_status, silent_for, last_error
FROM v_camera_health WHERE name = 'camera-01';
```

- `effective_status = 'offline'` con `reported_status = 'online'`: la IA dejo
  de reportar. Mira `silent_for`. No es la base, es el enlace o el proceso.
- `effective_status = 'unknown'`: la fila existe pero nadie reporto nunca.
  Normal en una camara que solo nombro un evento.
- `last_error` con texto: la IA si reporto, y reporto un fallo.

## Las metricas dan cero con eventos en la tabla

Las metricas filtran por `detected_at`, no por `received_at`:

```sql
SELECT min(detected_at), max(detected_at), min(received_at), max(received_at)
FROM events WHERE ai_event_id IS NOT NULL;
```

Si `detected_at` esta en el futuro, la ventana de la metrica lo descarta: el
reloj del PC del predio va adelantado. Si esta muy en el pasado con
`received_at` de hoy, va atrasado. Las dos cosas se ven en la misma consulta,
y es para esto que las dos columnas existen separadas.

## Un evento llego dos veces

No deberia:

```sql
SELECT ai_event_id, count(*) FROM events
WHERE ai_event_id IS NOT NULL
GROUP BY ai_event_id HAVING count(*) > 1;
```

Cero filas es lo correcto. Si devuelve algo, el `UNIQUE` sobre `ai_event_id`
no esta, y la ingesta dejo de ser idempotente:

```sql
SELECT conname FROM pg_constraint WHERE conrelid = 'events'::regclass AND contype = 'u';
```

Duplicados **sin** `ai_event_id` son otra cosa: esas filas las escribio un
servicio que no genera el identificador, y nada puede distinguir un reintento
de dos detecciones reales. Se arregla en el escritor, no aqui.

## La base no responde

Si es Neon en plan gratuito, se suspende tras 5 minutos sin uso y la primera
consulta tarda un par de segundos. No es un fallo.

Si tarda mas, o falla con la conexion cerrada, mira el numero de conexiones
abiertas:

```sql
SELECT count(*), state FROM pg_stat_activity GROUP BY state;
```

Un deploy que no libero su pool deja conexiones colgadas y el plan gratuito
las cuenta. Es lo que arregla el `engine.dispose()` del backend al apagarse.
