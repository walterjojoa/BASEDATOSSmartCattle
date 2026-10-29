# `animals`

El registro de animales. La identificación individual por IA es una fase
futura: hoy esta tabla la llena el personal, no la visión.

| Columna | Tipo | NULL | Por qué |
| --- | --- | --- | --- |
| `tag` | `TEXT` | no, **PK** | El arete. Ver abajo. |
| `status` | `TEXT` | no, `'active'` | `active`, `inactive` o `lost`. Indexada por `animals_status_idx`. |
| `camera_id` | `BIGINT` → `cameras` | sí, `SET NULL` | Dónde se vio por última vez. Retirar una cámara no borra al animal. |
| `zone_id` | `BIGINT` → `zones` | sí, `SET NULL` | |
| `name` | `TEXT` | sí | Para que el personal reconozca de qué animal habla una alerta. |
| `last_detection` | `TIMESTAMPTZ` | sí | Lo escribe el servicio de IA. |
| `created_at` | `TIMESTAMPTZ` | no, `now()` | |
| `updated_at` | `TIMESTAMPTZ` | no, `now()` | Trigger `animals_updated_at_trg`. |

## El arete es la clave primaria

No hay `id` numérico. El arete es la identidad real del animal: la que está
físicamente en su oreja y la que usa el personal. Un segundo identificador
obligaría a traducir entre los dos en cada consulta y a decidir, en cada
pantalla, cuál de los dos mostrar.

El precio de una clave natural es que **cambia**: un arete se cae y se repone.
De ahí que `events.animal_tag` lleve `ON UPDATE CASCADE` — sin él, reponer un
arete deja todo el histórico de ese animal apuntando a uno que ya no existe.

## `status` en vez de borrar

Un animal borrado deja su histórico de alertas sin el animal al que se
refiere. `status` pasa a `inactive` o `lost` y la fila se queda. Por eso «el
hato activo» es la consulta habitual y por eso existe `animals_status_idx`:
sin él recorre la tabla.

`lost` no es lo mismo que `inactive`. `inactive` es una baja administrativa;
`lost` es un animal que debería estar y no aparece, que es exactamente lo que
el sistema existe para detectar.

## Lo que no lleva, a propósito

No hay raza, sexo ni fecha de nacimiento. SmartCattle rastrea el ganado **por
seguridad** — dónde está y si salió de su zona —, no gestiona el hato ni su
valoración comercial. Esos datos son zootécnicos: no ayudan a localizar a un
animal ni a detectar que se escapó. Estuvieron en el planteamiento inicial y
se quitaron al precisar el alcance.
