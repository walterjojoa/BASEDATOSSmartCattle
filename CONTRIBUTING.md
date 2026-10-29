# Como cambiar esta base

Tres servicios leen y escriben aqui. Un cambio mal coordinado los rompe a la
vez, y ya paso una (ver [docs/decisiones.md](docs/decisiones.md), punto 2).

## Agregar una columna

1. Migracion nueva en `database/migrations/`, con el siguiente numero.
2. **Nulable**, o con `DEFAULT`. Una columna `NOT NULL` sin valor por defecto
   falla en una tabla con filas, y obliga a los demas escritores a inventar un
   dato que no tienen.
3. Idempotente: `ADD COLUMN IF NOT EXISTS`.
4. `COMMENT ON COLUMN` si el nombre y el tipo no alcanzan para usarla bien.
5. Agregarla a `database/install.sql`.
6. Comprobacion en `database/tests/` si hay una regla que valga la pena
   sostener.
7. Ficha en `docs/diccionario/`.

## Agregar un indice

En su propia migracion, con **la consulta que lo justifica escrita en el
comentario**. Un indice sin consulta conocida se paga en cada `INSERT` y no lo
usa nadie.

Si la consulta filtra, el indice va parcial: `WHERE status = 'pending'` pesa
lo que la cola, no lo que el historico.

## Quitar algo

En dos pasos, nunca en uno:

1. Dejar de usarlo en los tres servicios. Desplegar.
2. Despues, la migracion que lo quita.

Al revés rompe el servicio que todavía lo leía.

## Renombrar

**Se coordina antes.** Un rename no es compatible hacia atras y no hay forma
de hacerlo gradual en una sola columna. Si se puede evitar, se evita: una
columna nueva mas una vista que presente el nombre viejo migra sin romper.

## Antes de subir

```powershell
./scripts/check-install-lists-migrations.sh

psql "$env:TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f database/install.sql
Get-ChildItem database/tests/*.sql | Sort-Object Name | ForEach-Object {
  psql "$env:TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f $_.FullName
}
```

Contra una base **desechable**. En Neon, un branch sirve y no cuesta nada.

CI corre lo mismo contra PostgreSQL 17, aplica todo dos veces, y repite las
comprobaciones con datos sembrados.

## Lo que no va en un commit

La cadena de conexion, en ninguna forma. `.gitignore` cubre `.env` y `*.dump`,
pero un `psql "postgresql://usuario:clave@..."` pegado en un README no lo
cubre nada.
