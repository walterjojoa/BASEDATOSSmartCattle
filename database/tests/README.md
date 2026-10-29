# Comprobaciones del esquema

SQL plano, sin dependencias. Cada archivo comprueba una cosa y **falla
ruidosamente**: usa `ASSERT`, que aborta la transaccion con un mensaje en vez
de devolver una tabla que nadie lee.

**Silencio es exito.**

## Las dos clases de comprobacion

Importa la diferencia, porque las dos hacen falta:

- **Que existe.** Listan nombres: tablas, indices, constraints, vistas,
  funciones, comentarios. Detectan que un `ALTER` se llevo algo.
- **Que funciona.** Insertan una fila mala y exigen que la base la rechace.
  Detectan algo redefinido **conservando el nombre**, que es el caso que la
  primera clase no ve.

`03_check_constraints.sql` lista los `CHECK` por nombre;
`24_check_constraints_reject.sql` comprueba que rechazan. Una constraint se
puede reescribir para que no rechace nada y la primera sigue pasando.

## Los archivos

| Archivo | Que sostiene |
| --- | --- |
| `01_tables_and_columns.sql` | Las seis tablas; `animals.tag` sigue siendo la PK |
| `02_timestamps_are_utc.sql` | Ninguna fecha sin zona horaria |
| `03_check_constraints.sql` | Los `CHECK` existen, y los de enumerados rechazan |
| `04_lowercase_email_is_unique.sql` | Una direccion no se registra dos veces |
| `05_foreign_keys_are_indexed.sql` | Toda clave ajena tiene indice (la convencion, no una lista) |
| `06_idempotency_markers.sql` | La semilla no se duplica; los indices siguen |
| `07_event_idempotency.sql` | `ai_event_id` hace idempotente la ingesta |
| `08_cascade_and_set_null.sql` | El historico sobrevive; las alertas no |
| `09_updated_at_trigger.sql` | El trigger dispara, en las dos tablas |
| `10_partial_indexes.sql` | Los indices parciales **siguen siendo parciales** |
| `11_frame_bounds.sql` | La resolucion es positiva, y opcional |
| `12_alert_recipient.sql` | Retirar una cuenta conserva sus alertas |
| `13_views.sql` | Las vistas aplican su regla |
| `14_retention.sql` | `prune_events` recorta por antiguedad y rechaza cero |
| `15_comments_exist.sql` | Las columnas con trampa estan comentadas |
| `16_cookbook_queries_run.sql` | Las consultas de `docs/consultas.md` se ejecutan |
| `17_zone_outline.sql` | El `CHECK` del poligono rechaza cada forma mala |
| `18_outline_validator.sql` | El validador es `IMMUTABLE` y clasifica bien |
| `19_install_is_complete.sql` | `install.sql` dejo montado todo |
| `20_confidence_precision.sql` | `0.95` se guarda como `0.95` |
| `21_camera_health_view.sql` | Un reporte vencido da `offline` |
| `22_users_role_and_state.sql` | El rol por defecto es el menos privilegiado |
| `23_no_mutable_defaults.sql` | Ningun `DEFAULT` de fecha es naive |
| `24_check_constraints_reject.sql` | Los rangos rechazan, y aceptan sus limites |

## Correrlas

Contra una base **desechable**, nunca la de produccion: varias insertan y
borran filas de prueba.

```powershell
psql "$env:TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f database/install.sql
Get-ChildItem database/tests/*.sql | Sort-Object Name | ForEach-Object {
  psql "$env:TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f $_.FullName
}
```

CI hace eso en cada push contra PostgreSQL 17, aplica todo **dos veces** para
comprobar la idempotencia, y **repite las comprobaciones con datos sembrados**
-- porque con la base vacia la mitad pasa trivialmente.

## Las filas de prueba se limpian

Cada archivo borra lo que inserto. Los identificadores llevan prefijo
`test-` para poder encontrar lo que haya quedado:

```sql
SELECT name FROM cameras WHERE name LIKE 'test-%';
SELECT tag  FROM animals WHERE tag  LIKE 'test-%';
```
