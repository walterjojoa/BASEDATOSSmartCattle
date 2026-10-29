# Restauracion

## Primero: no restaures sobre la base buena

Restaurar sobre una base con datos los mezcla con los del respaldo y el
resultado no es ninguno de los dos estados. Crea una base nueva, restaura ahi,
comprueba, y despues decide.

## Restaurar completo en una base nueva

```powershell
# En Neon: Branches -> New branch, o un proyecto nuevo.
pg_restore --dbname "$env:RESTORE_DATABASE_URL" --no-owner --no-privileges smartcattle-20261029-1430.dump
```

`--no-owner` y `--no-privileges`: el usuario del respaldo no existe en la base
nueva, y sin estas banderas `pg_restore` falla intentando asignar permisos a
alguien que no esta.

## Restaurar una sola tabla

El caso real: alguien borro eventos de mas con un `DELETE` sin `WHERE`.

```powershell
pg_restore --dbname "$env:RESTORE_DATABASE_URL" --table=events --data-only smartcattle-20261029-1430.dump
```

Restaura **a la base nueva**. Despues se copian las filas que faltaban a la
real, con la base de produccion delante y con calma:

```sql
-- Desde la base real, con la restaurada como origen (dblink o export/import).
INSERT INTO events (type, camera_id, detected_at, ai_event_id)
SELECT type, camera_id, detected_at, ai_event_id
FROM eventos_recuperados
ON CONFLICT (ai_event_id) DO NOTHING;
```

El `ON CONFLICT (ai_event_id) DO NOTHING` es lo que hace esto seguro: los
eventos que si sobrevivieron no se duplican. Es el mismo `UNIQUE` que hace
idempotente la ingesta, usado aqui para otra cosa.

Ojo: solo protege a las filas **que tienen** `ai_event_id`. Las que escribio
otro servicio sin el si se pueden duplicar, y hay que cotejarlas a mano.

## Comprobar antes de darlo por bueno

```powershell
psql "$env:RESTORE_DATABASE_URL" -f database/tests/01_tables_and_columns.sql
psql "$env:RESTORE_DATABASE_URL" -f database/tests/05_foreign_keys_are_indexed.sql
```

Las comprobaciones del repositorio sirven igual para validar una restauracion:
si una clave ajena o un indice no sobrevivio, lo dicen.
