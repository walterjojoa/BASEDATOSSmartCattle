# SmartCattle — base de datos

PostgreSQL. El esquema compartido por los tres servicios de SmartCattle.

```
database/
  install.sql      <- una base nueva se crea con esto
  schema.sql         estado final de las tablas
  migrations/        un archivo por cambio, en orden, idempotentes
  tests/             comprobaciones en SQL plano
  seed-dev.sql       datos de desarrollo
docs/
  diccionario/       ficha por tabla: cada columna y por que es asi
  runbooks/          respaldo, restauracion, migraciones, Neon, incidentes
  erd.md             diagrama del modelo
  consultas.md       recetario, con la trampa de cada consulta
  convenciones.md    reglas que sigue el esquema
  seguridad.md       que guarda y que pasa si se filtra
  rendimiento.md     los indices y como comprobar que sirven
```

## Empezar

Base nueva:

```powershell
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f database/install.sql
```

**No basta `schema.sql`.** Describe las tablas, pero los indices, las vistas,
los comentarios y la funcion de retencion llegaron en migraciones.
`install.sql` aplica las dos cosas en orden.

Base que ya tiene datos: ver
[docs/runbooks/aplicar-migraciones.md](docs/runbooks/aplicar-migraciones.md).
**Respalda primero.**

## Comprobar

```powershell
Get-ChildItem database/tests/*.sql | Sort-Object Name | ForEach-Object {
  psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f $_.FullName
}
```

Silencio es exito: usan `ASSERT`, que solo habla cuando algo esta mal.

CI corre esto en cada push contra un PostgreSQL 17 real, aplica todo **dos
veces** para comprobar la idempotencia, y repite las comprobaciones con datos
sembrados.

## Las tablas

| Tabla | Para que | Crece |
| --- | --- | --- |
| `cameras` | Camaras del predio | No |
| `zones` | Zona segura por camara, de 0 a 1 | No |
| `users` | Personal: correo, hash bcrypt, rol | No |
| `animals` | Registro de animales, PK el arete | Lento |
| `events` | Detecciones (`cattle_out_of_zone`) | **Sin techo** |
| `alerts` | Avisos por evento: canal y estado | **Con los eventos** |

Detalle columna por columna en [docs/diccionario/](docs/diccionario/).

## Las tres decisiones que conviene saber antes de tocar nada

1. **El arete es la clave primaria de `animals`.** No hay `id` numerico. El
   precio es que una clave natural cambia, y de ahi el `ON UPDATE CASCADE` en
   `events.animal_tag`.
2. **Se desactiva, no se borra.** `animals.status`, `users.is_active`,
   `cameras.active`. El historico sobrevive a que se retire su origen; la
   unica excepcion es `alerts`, que se va con su evento.
3. **`users.password_hash` es bcrypt, nunca SHA.** Ver
   [docs/seguridad.md](docs/seguridad.md).

El resto en [docs/convenciones.md](docs/convenciones.md).

## Nada de credenciales en el repositorio

La cadena de conexion lleva la clave. Va en `.env`, que `.gitignore` ignora.
Plantilla en [.env.example](.env.example).
