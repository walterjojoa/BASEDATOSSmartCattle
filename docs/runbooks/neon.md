# Crear la base en Neon

Plan gratuito, sin tarjeta. 1 GB por proyecto, sin caducidad.

## Crear

1. Cuenta en https://neon.com y proyecto nuevo.
   Region: AWS US East (Virginia u Ohio), que es donde corre Render.
   Cruzar continentes agrega latencia a **cada** consulta.
2. **SQL Editor**, pegar `database/schema.sql` completo, **Run**.
3. Aplicar las migraciones en orden (ver
   [aplicar-migraciones.md](aplicar-migraciones.md)).
4. **Tables** tiene que mostrar las seis tablas.

## La cadena de conexion

Boton **Connect**:

```
postgresql://usuario:clave@host/neondb?sslmode=require
```

`sslmode=require` no se quita. Sin el, la contrasena y los datos viajan en
claro por internet.

Va en `.env` (que `.gitignore` ignora) y en las variables de Render. **Nunca
en un commit.**

## Que esperar del plan gratuito

- **Se suspende tras 5 minutos sin uso.** La primera consulta despues de la
  pausa tarda un par de segundos. No es un fallo, y es la razon por la que el
  backend abre el pool con `pool_pre_ping=True`: sin eso, la primera consulta
  tras la pausa usa una conexion ya cerrada y revienta.
- 1 GB por proyecto. `events` es la que lo va a consumir; ver
  [crecimiento.md](crecimiento.md).
- El plan de pago cobra por uso, desde 0,106 USD por CU-hora, sin minimo
  mensual (consultado el 04/10/2026).

## Branches para probar

La funcion mas util para esto: un branch es una copia con copy-on-write,
instantanea y sin costo de almacenamiento al crearla. Es donde se prueba una
migracion antes de tocar la base real.
