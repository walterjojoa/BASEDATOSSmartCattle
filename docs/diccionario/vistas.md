# Vistas y funciones

No estan en `schema.sql`: las crean las migraciones `0011` a `0014` y `0020`.

## `v_api_events`

Los eventos que el esquema `Event` de la API puede representar, con el nombre
de la camara resuelto.

El filtro existe porque cuatro columnas que la API **exige** admiten `NULL`
aqui: `ai_event_id`, `received_at`, `detected_object` y `confidence`. Estaba
escrito tres veces -- feed, metricas, consultas a mano -- y las copias
divergieron.

Usar esta vista en vez de `events` es el habito correcto para cualquier
consulta que quiera "los eventos" como los entiende la aplicacion.

## `v_camera_health`

El estado **efectivo** de cada camara.

`reported_status` dice lo ultimo que dijo el servicio de IA, y una IA que se
cayo hace una hora sigue diciendo `online`. La vista aplica el mismo
vencimiento que el backend (60 s) y expone `silent_for`.

Tres valores de `effective_status`:

- `online` / `error`: lo que reporto, y el reporte esta fresco.
- `offline`: el reporte vencio, **sin importar** lo que diga la columna.
- `unknown`: nadie reporto nunca. **No es lo mismo que `offline`:** es una
  camara que existe como fila pero que nadie configuro, y eso pide una
  respuesta distinta que una averiada.

La crea `0012`, que se salta con un `NOTICE` si faltan las columnas de estado
(las agrega el backend con su propia migracion).

## `v_active_herd`

El hato activo con camara y zona resueltas, mas `unseen_for`.

Los dos `JOIN` son `LEFT` a proposito: `camera_id` y `zone_id` admiten `NULL`,
y un `INNER JOIN` esconderia a los animales que todavia no se han ubicado --
que son justo los que hay que mirar.

## `prune_events(interval)`

Borra eventos anteriores al intervalo y devuelve cuantos borro. Las alertas se
van con ellos por el `CASCADE`.

Rechaza un intervalo nulo o no positivo: "mas viejo que ahora" es toda la
tabla.

No esta programada. PostgreSQL no tiene cron y el plan gratuito de Neon no
trae `pg_cron`, asi que la llama quien decida la politica. Ver
[../runbooks/crecimiento.md](../runbooks/crecimiento.md).

## `is_valid_zone_outline(jsonb)`

Valida un poligono de zona: arreglo de 3 a 64 vertices `{x, y}` numericos de 0
a 1.

Es una funcion y no un `CHECK` escrito en la tabla porque recorrer los
vertices necesita una subconsulta, y un `CHECK` no admite subconsultas.
`IMMUTABLE` es obligatorio para poder llamarla desde un `CHECK`.

## `set_updated_at()`

El trigger que refresca `updated_at` en `animals` y `users`. La unica que si
esta en `schema.sql`.
