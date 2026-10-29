# Como se relacionan `animals` y `events`

La relacion mas sutil del esquema, y la unica que todavia no se usa.

## Hoy: un evento no sabe de que animal es

`events.animal_tag` existe y esta **vacio en todas las filas**. El servicio de
IA detecta *una vaca*, no *esa vaca*: identifica la clase del objeto
(`detected_object = 'cow'`), no al individuo.

Por eso el tablero cuenta animales detectados y no puede decir cuales. La
identificacion individual es una fase futura.

## Cuando se use: la cascada importa

`events.animal_tag` apunta a `animals.tag`, que es una clave primaria
**natural**. Un arete se cae y se repone, asi que el valor cambia.

```sql
-- Reponer un arete
UPDATE animals SET tag = 'A-442' WHERE tag = 'A-441';
```

Con `ON UPDATE CASCADE`, los eventos de ese animal siguen el cambio. Sin ella,
el `UPDATE` fallaria -- la clave ajena lo rechazaria -- o, si alguien la
hubiera definido sin accion, dejaria el historico apuntando a un arete que no
existe.

Es el costo de una clave natural, y el motivo por el que esa clausula esta
ahi (ver [../decisiones.md](../decisiones.md), punto 1).

## Y el borrado no

`ON DELETE SET NULL`. Retirar un animal **no** borra sus eventos: el
historico de alertas vale aunque el animal ya no este en el predio.

En la practica los animales no se borran, se desactivan (`status`), asi que
esta rama casi no se usa. Esta por si alguien si borra.

## La consulta que esto habilita

Cuando `animal_tag` se llene:

```sql
SELECT a.tag, a.name, count(e.id) AS salidas, max(e.detected_at) AS ultima
FROM animals a
LEFT JOIN events e ON e.animal_tag = a.tag
                  AND e.detected_at >= now() - interval '30 days'
WHERE a.status = 'active'
GROUP BY a.tag, a.name
ORDER BY salidas DESC;
```

"Que animales se escapan mas", que es la pregunta de manejo que el sistema
puede responder y hoy no.

Dos detalles: el `LEFT JOIN` incluye a los que nunca salieron -- con cero,
que es informacion -- y el filtro de fecha va **en el `ON`** y no en el
`WHERE`, porque en el `WHERE` convertiria el `LEFT JOIN` en interno y
desapareceria justo ese grupo.

`events_animal_tag_idx` ya existe en `schema.sql` para esta consulta.
