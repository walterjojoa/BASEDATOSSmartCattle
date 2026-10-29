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
