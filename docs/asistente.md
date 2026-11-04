# Acceso del asistente de IA

Migración `0033`. Esto es sólo la parte de la base: **el asistente todavía no existe**
en ningún servicio. Cuando exista, entra por aquí.

## La regla

**El backend consulta con SQL fijo y parámetros. El modelo nunca escribe SQL.** El
modelo elige una herramienta («informe de estos días»), y el backend corre la
consulta de esa herramienta con la cuenta de la sesión del usuario.

No es una preferencia. Con SQL libre, el propio modelo podría ejecutar
`RESET ROLE` o reescribir `app.current_account_id`, y las dos barreras de abajo
dejarían de servir: bastaría una frase maliciosa en una pregunta.

## Cómo se abre una consulta

```sql
BEGIN READ ONLY;
SET LOCAL ROLE smartcattle_assistant;
SELECT set_config('app.current_account_id', $1, true);  -- la cuenta, de la sesión
SELECT ... FROM v_assistant_events WHERE detected_at >= $2;
COMMIT;
```

`SET LOCAL` y el `true` de `set_config` duran sólo la transacción. Eso es lo que
permite usarlo con la conexión con pooler de Neon, donde la siguiente transacción
puede ser de otro usuario.

La cuenta sale del token, **nunca del texto de la pregunta**. Es el `account_id` de
quien pregunta: un trabajador usa el de su dueño.

## Lo que puede leer

| Objeto | Qué responde |
| --- | --- |
| `assistant_daily_reports(first_day, last_day, tz)` | El informe diario de la cuenta. Ver [diccionario/detections.md](diccionario/detections.md). |
| `v_assistant_detections` | Ganado por postura y personas, por cámara y minuto. |
| `v_assistant_events` | Incidentes, como `cattle_out_of_zone`. |
| `v_assistant_cameras` | Cámaras y su estado efectivo. Requiere las columnas del backend. |
| `v_assistant_alerts` | Alertas del tablero y su atención. Requiere `security_alerts`. |

## Lo que lo protege

- **El rol no tiene permiso sobre ninguna tabla.** Sólo estas vistas y esa función.
- **Sin cuenta, cero filas.** Si el backend olvida fijarla, el asistente se queda sin
  datos en vez de ver los de todos.
- **Las vistas dejan fuera lo sensible:** `password_hash`, correos, nombres,
  `cameras.source`, `stream_url`, `last_error`. La prueba `28` falla si una vista
  nueva saca alguna de esas columnas.
- **`assistant_daily_reports` no acepta una cuenta como parámetro.** Es lo único con
  `SECURITY DEFINER`, y por eso no está abierta a `PUBLIC`.

## Lo que no protege

- `message` de `v_assistant_alerts` es texto que puede venir de fuera. El modelo lo
  debe tratar como dato, no como instrucción.
- El tamaño de la respuesta: el backend debe acotar rangos de fechas y filas antes
  de pasarle el resultado al modelo.

## Si la migración avisa de que falta el rol

Crear el rol pide `CREATEROLE`, y los roles son de todo el servidor. La migración
no frena el despliegue por esto: emite un `WARNING`, sigue, y `SET LOCAL ROLE` falla
hasta que un administrador ejecute lo que falte:

```sql
CREATE ROLE smartcattle_assistant NOLOGIN;
GRANT smartcattle_assistant TO <usuario del backend>;
```

Después se vuelve a correr `0033`, que otorga el acceso a las vistas.
