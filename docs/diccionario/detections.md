# `detection_logs`, `detections` y `daily_reports()`

Lo que vio la IA y el informe diario que sale de ahí. Migraciones `0031` y `0032`.

## `detection_logs`

Una fila por cámara y minuto: **el último reporte de ese minuto**. La escribe sólo
el backend (`PUT /api/ai/cameras/{id}/detection-log`), y es la misma tabla de su
migración `0019_detection_logs`. Cada lado la crea sólo si falta.

| Columna | Tipo | NULL | Por qué |
| --- | --- | --- | --- |
| `camera_id` | `BIGINT` → `cameras` | no, PK, `CASCADE` | La PK empieza por esta columna: sirve a la clave ajena y a los rangos por cámara. |
| `minute` | `TIMESTAMPTZ` | no, PK | El minuto, con los segundos en cero. |
| `cattle_lying`, `cattle_standing`, `cattle_walking` | `INTEGER` | no | Reses vistas en esa postura. `CHECK (>= 0)`. |
| `cattle_unknown` | `INTEGER` | no | Reses cuya postura no se pudo estimar. No es lo mismo que de pie. |
| `people` | `INTEGER` | no | Personas vistas. |
| `avg_confidence` | `DOUBLE PRECISION` | sí | Entre 0 y 1. |
| `observed_at` | `TIMESTAMPTZ` | no | Reloj de la IA. Un reporte atrasado no reescribe el minuto. |

Índice extra en `minute`, para la retención y lo que mira todas las cámaras.

**Por qué no una fila por detección.** La IA evalúa varias veces por segundo, y la
regla del proyecto es no guardar por cuadro. Lo que se pierde: no se puede
consultar una detección individual, ni seguir a un animal concreto.

**Crece** unos 64 MB por cámara al año, índices incluidos (medido: 7,9 millones de
filas en 950 MB). El plan gratuito de Neon da 1 GB, así que hay que podar:

```sql
SELECT prune_detection_logs(interval '90 days');
```

Nada la llama sola. Los días podados dejan de aparecer en `daily_reports()`.

## La vista `detections`

Presenta `detection_logs` como una fila por objeto y postura vistos, sin ceros. No
guarda nada.

| Columna | Qué es |
| --- | --- |
| `camera_id`, `account_id` | La cámara y su cuenta **actual**. |
| `object_type` | `cattle` o `person`. |
| `posture` | `lying`, `standing` o `walking`. `NULL`: persona, o res sin postura estimada. |
| `detected_count` | Cuántos se veían en ese minuto. |
| `avg_confidence` | La del minuto entero, no la de este objeto. |
| `timestamp` | El minuto. Va entre comillas dobles en SQL. |

**Trampa:** `detected_count` es lo que se veía, no cuántas detecciones hubo. Las
mismas 10 vacas durante una hora dan 60 filas con 10, no 600 vacas. Se promedia o
se toma el máximo; **sumarlo no significa nada**.

## `daily_reports()`

```sql
SELECT * FROM daily_reports(1, '2026-03-01', '2026-03-31', 'America/Bogota');
```

Una fila por cámara y día, calculada al pedirla. Es función porque así cada día se
convierte en un rango sobre el índice; una vista agruparía antes de filtrar y
recorrería toda la historia de la cuenta. No es tabla porque habría que refrescarla
cada noche y el plan gratuito de Neon no tiene cron.

Un día sin datos no tiene fila: «no hubo nada que resumir» no es cero vacas. La zona
horaria decide dónde corta el día, y una inválida falla.

`GET /api/reports/daily` es el informe de la API. Lo calcula el backend, no llama a
esta función; `daily_reports()` existe para el asistente y para quien tenga `psql`.
Si los dos llegan a diferir, hay que revisar ambos.

Medido con 7,9 millones de filas, en PostgreSQL 18 local y una cuenta de 20 cámaras:
54 ms un día, 856 ms treinta días.
