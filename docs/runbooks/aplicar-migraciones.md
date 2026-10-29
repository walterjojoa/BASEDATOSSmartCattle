# Aplicar migraciones

`schema.sql` describe el estado final y sirve para una base **nueva**.
`CREATE TABLE IF NOT EXISTS` no modifica una tabla que ya existe, asi que para
una base con datos van las migraciones.

## Orden

1. **Respalda.** Ver [respaldo.md](respaldo.md).
2. Prueba en una copia primero. En Neon, un branch cuesta nada:
   Branches -> New branch.
3. Aplica en orden, parando en el primer error.
4. Corre las comprobaciones.
5. Avisa al equipo, porque hay mas servicios leyendo esta base.

## Aplicar

```powershell
Get-ChildItem database/migrations/*.sql | Sort-Object Name | ForEach-Object {
  Write-Host "-- $($_.Name)"
  psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f $_.FullName
  if ($LASTEXITCODE -ne 0) { throw "fallo en $($_.Name)" }
}
```

`ON_ERROR_STOP=1` no es opcional: sin el, `psql` sigue despues de un error y
deja la base a medio migrar, que es el peor de los estados posibles.

## Comprobar

```powershell
Get-ChildItem database/tests/*.sql | Sort-Object Name | ForEach-Object {
  psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f $_.FullName
}
```

Silencio es exito: las comprobaciones usan `ASSERT`, que solo habla cuando
algo esta mal.

## Volver a correrlas es seguro

Todas son idempotentes, y CI lo comprueba aplicandolas dos veces en cada push.
Si una se corto a mitad, se vuelve a correr la tanda completa.

## Las del backend son aparte

SmartCattle-Backend lleva sus propias migraciones de Alembic, solo para las
columnas que el agrego (`cameras.reported_status`, `stream_url`, las tablas
`video_analyses`). Las aplica solo, en cada deploy:

```
alembic upgrade head && uvicorn app.main:app
```

Los dos juegos son independientes. Las de aqui tocan las tablas compartidas;
las suyas, las propias.

**Una depende de la otra en un punto:** `v_camera_health` (migracion 0012)
necesita `cameras.last_report_at`, que crea el backend. Si no esta, la
migracion lo avisa con un `NOTICE` y se salta la vista en vez de fallar.
