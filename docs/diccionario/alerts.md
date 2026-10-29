# `alerts`

Lo que se le manda a la persona a cargo, derivado de un evento. Un evento
puede producir varias alertas: la misma salida de zona por correo y por
WhatsApp son dos filas.

| Columna | Tipo | NULL | Por qué |
| --- | --- | --- | --- |
| `id` | `BIGINT` identidad | no | |
| `event_id` | `BIGINT` → `events` | no, **`CASCADE`** | Una alerta sin su evento no se puede explicar. |
| `channel` | `TEXT` | no, `'email'` | `email`, `whatsapp`, `telegram`, `sms`, `n8n`. |
| `status` | `TEXT` | no, `'pending'` | `pending`, `sent`, `failed`, `handled`. Indexada. |
| `detail` | `TEXT` | sí | El error del proveedor cuando `status = 'failed'`. |
| `created_at` | `TIMESTAMPTZ` | no, `now()` | Cuándo se encoló. |
| `sent_at` | `TIMESTAMPTZ` | sí | Cuándo salió. `NULL` mientras siga pendiente. |

## `CASCADE` aquí, `SET NULL` en todo lo demás

Es la excepción deliberada del esquema. En `events`, borrar una cámara o un
animal hace `SET NULL`, porque el histórico vale aunque el origen se retire.
Una alerta es distinta: es *sobre* un evento. Sin él no dice nada, no se puede
auditar y no se puede reenviar. Se va con él.

Eso convierte `alerts_event_id_idx` (migración `0003`) en algo necesario y no
cosmético: sin él, borrar un solo evento recorre `alerts` completa buscando
hijos.

## `status` distingue `sent` de `handled`

`sent` es que el mensaje salió. `handled` es que **una persona hizo algo**. Es
la diferencia entre «avisamos» y «alguien fue a ver la vaca», y es la que
importa cuando se revisa qué pasó esa noche.

`alerts_status_idx` existe porque la consulta habitual es `WHERE status =
'pending'`: la cola de envío.

## Sin usar todavía

Ningún servicio escribe aquí. El backend guarda eventos y no manda
notificaciones; `docs/ARCHITECTURE.md` las deja fuera de alcance por ahora. La
tabla y sus canales ya están decididos para cuando se implementen.
