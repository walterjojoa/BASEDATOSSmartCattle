# Comprobaciones del esquema

SQL plano, sin dependencias. Cada archivo comprueba una cosa y **falla
ruidosamente**: usa `ASSERT`, que aborta la transacción con un mensaje en vez
de devolver una tabla que nadie lee.

Se corren contra una base **desechable**, nunca contra la de producción:

```powershell
psql "$env:TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f database/schema.sql
Get-ChildItem database/migrations/*.sql | Sort-Object Name | ForEach-Object {
  psql "$env:TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f $_.FullName
}
Get-ChildItem database/tests/*.sql | Sort-Object Name | ForEach-Object {
  psql "$env:TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f $_.FullName
}
```

CI hace exactamente eso en cada push, y además **aplica todo dos veces** para
comprobar que `schema.sql` y las migraciones son idempotentes de verdad y no
sólo de palabra.
