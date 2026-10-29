# Respaldo

**Antes de cualquier migracion.** Varias no se deshacen.

## Con pg_dump

```powershell
pg_dump "$env:DATABASE_URL" --format=custom --file="smartcattle-$(Get-Date -Format yyyyMMdd-HHmm).dump"
```

`--format=custom` y no SQL plano: se restaura de forma selectiva (una tabla
sola) y va comprimido. El nombre lleva la fecha porque el respaldo que se
sobreescribe no es un respaldo.

## Comprobar que sirve

Un respaldo que nadie abrio no se sabe si sirve:

```powershell
pg_restore --list smartcattle-20261029-1430.dump | Select-Object -First 20
```

Tiene que listar las seis tablas. Si falla aqui, falla tambien el dia que
haga falta.

## Solo los datos, sin el esquema

Para repoblar una base de pruebas:

```powershell
pg_dump "$env:DATABASE_URL" --data-only --format=custom --file=datos.dump
```

## Lo que el respaldo NO cubre

- La cadena de conexion y las variables de entorno de Render. Viven en el
  panel de Render, no aqui.
- `AI_API_KEY`, que Render genera. Si se pierde, se regenera y hay que
  actualizarla en el servicio de IA.

## Cuidado con el archivo

El `.dump` lleva **todo**, incluidos los `password_hash`. `.gitignore` ya
ignora `*.dump`, pero el archivo sigue en el disco: no lo dejes en una carpeta
sincronizada ni lo manden por chat.
