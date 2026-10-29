# Migraciones

`schema.sql` describe el **estado final**. Sirve para una base nueva, pero
`CREATE TABLE IF NOT EXISTS` no modifica una tabla que ya existe, así que no
sirve para una base con datos. Esa es la función de esta carpeta.

## Convención

Un archivo por cambio, numerado, con el nombre de lo que hace:

```
NNNN_descripcion_corta.sql
```

Se aplican **en orden** y cada uno es **idempotente**: volver a correrlo no
falla ni duplica nada. Eso vale porque varios servicios comparten esta base y
nadie lleva la cuenta de qué se aplicó en cada entorno.

La idempotencia se consigue con `IF NOT EXISTS` cuando existe, y con un bloque
`DO $$ ... $$` que comprueba el catálogo cuando no (por ejemplo para
`ALTER COLUMN`, que no admite `IF NOT EXISTS`).

## Cómo aplicarlas

Respalda primero. Algunas migraciones no se deshacen:

```powershell
pg_dump "$env:DATABASE_URL" -f respaldo.sql
```

Todas, en orden:

```powershell
Get-ChildItem database/migrations/*.sql | Sort-Object Name | ForEach-Object {
  psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f $_.FullName
}
```

Una sola:

```powershell
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f database/migrations/0001_widen_event_confidence.sql
```

`ON_ERROR_STOP=1` importa: sin él `psql` sigue después de un error y deja la
base a mitad de camino.

## Relación con SmartCattle-Backend

El backend lleva sus propias migraciones de Alembic en `migrations/versions/`,
y sólo para las columnas que él agregó (`cameras.reported_status`,
`stream_url`, las tablas `video_analyses`). Las de aquí son las de las tablas
compartidas. Los dos juegos son independientes y no se pisan.
