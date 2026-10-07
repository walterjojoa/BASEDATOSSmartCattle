# Base de datos de SmartCattle (PostgreSQL)

Archivo: [`schema.sql`](schema.sql). Se puede ejecutar varias veces sin duplicar datos.

## Tablas

| Tabla | Para qué sirve |
| --- | --- |
| `camaras` | Cámaras del predio (fuente: USB, video o RTSP). |
| `zonas` | Zona segura rectangular por cámara (coordenadas de 0 a 1). |
| `animales` | Registro de animales: arete (clave primaria), estado, nombre y dónde se le vigila. |
| `eventos` | Eventos detectados (p. ej. `ganado_fuera_zona`) con clase, confianza, caja y fecha. |
| `alertas` | Alertas por evento: canal (correo, WhatsApp, n8n...) y estado (pendiente, enviada, fallida, atendida). |

```text
camaras 1─┬─* zonas
          ├─* animales
          └─* eventos 1─* alertas

animales 1─* eventos   (eventos.animal_id -> animales.identificador)
```

La clave primaria de `animales` es el **arete** (`identificador`), no un número
de la base: es la identidad real de la vaca, la que está físicamente en la oreja
y con la que la nombra el personal del predio. Un segundo identificador numérico
obligaría a traducir entre los dos en cada consulta.

Trae datos iniciales: una cámara (`Cámara principal`) y una zona (`Zona segura`).

## Columnas que agregó el backend

### En `eventos`

Dos columnas de `eventos` las necesita SmartCattle-Backend para ingerir eventos
de la IA. Ambas admiten `NULL`, así que no obligan a nada a los demás servicios
que escriban en la tabla.

| Columna | Para qué sirve |
| --- | --- |
| `recibido_en TIMESTAMPTZ` | Cuándo recibió el backend el evento. `fecha` es cuándo lo detectó la IA; la diferencia revela demoras de red o relojes desfasados. |
| `ai_event_id UUID UNIQUE` | Identificador que la IA genera una vez por detección y reutiliza en cada reintento. El `UNIQUE` hace la ingesta idempotente: un reintento no crea una segunda fila, y la base resuelve la carrera cuando dos reintentos llegan a la vez. |

Sin `ai_event_id`, un reintento tras un tiempo de espera agotado guarda el mismo
avistamiento dos veces, y la tabla no tiene forma de distinguir un reintento de
dos animales detectados en el mismo segundo: con el contrato actual los dos
casos producen filas idénticas.

### En `animales`

Dos columnas más, para el CRUD de animales del backend
(`POST`/`PUT`/`DELETE /api/animals`). Igual que las anteriores, admiten `NULL` o
traen `DEFAULT`.

| Columna | Para qué sirve |
| --- | --- |
| `nombre TEXT` | Nombre con el que el hato conoce al animal, cuando tiene uno. Sirve para que el personal reconozca de qué animal habla una alerta. |
| `actualizado_en TIMESTAMPTZ` | Cuándo cambió la fila por última vez. La mantiene el trigger `animales_actualizado_en_trg`, no la aplicación: varios servicios escriben aquí (el de IA actualiza `ultima_deteccion`), y un timestamp que sólo un escritor refresca miente en cuanto otro toca la fila. |

**Qué NO lleva esta tabla:** raza, sexo ni fecha de nacimiento. SmartCattle
rastrea el ganado **por seguridad** —dónde está un animal y si salió de su
zona—, no gestiona el hato ni su comercialización. Esos tres datos son de
zootecnia y de valoración comercial: no ayudan a localizar a un animal ni a
detectar que se escapó. Existieron brevemente, siguiendo el planteamiento
inicial, y se quitaron al precisar el alcance del proyecto.

El backend borra animales de forma **lógica** (`estado = 'inactivo'`), nunca con
`DELETE`, porque `eventos.animal_id` es `ON DELETE SET NULL` y un borrado real
dejaría todo el histórico de alertas sin el animal al que se refiere. De ahí el
índice `animales_estado_idx`: «los activos» pasa a ser la consulta habitual.

### El arete como clave primaria

`animales.id` se eliminó: `identificador` pasó a ser la clave primaria, y
`eventos.animal_id` pasó de `BIGINT` a `TEXT` para guardar el arete.

La llave foránea reconstruida lleva **`ON UPDATE CASCADE`**, que la clave
numérica no necesitaba. Una clave primaria natural sí cambia —un arete se cae y
se repone—, y sin la cascada los eventos de ese animal quedarían apuntando a un
arete que ya no existe. Conserva `ON DELETE SET NULL`: borrar un animal no debe
borrar su histórico.

### Para una base que ya existe

`CREATE TABLE IF NOT EXISTS` no agrega columnas a una tabla que ya está creada,
así que sobre una base existente hay que aplicar los `ALTER`. El backend los trae
listos y en forma repetible en
`database/0001_animales_campos_descriptivos.sql` de su repositorio; el
equivalente mínimo es:

```sql
ALTER TABLE eventos  ADD COLUMN IF NOT EXISTS recibido_en TIMESTAMPTZ;
ALTER TABLE eventos  ADD COLUMN IF NOT EXISTS ai_event_id UUID UNIQUE;

ALTER TABLE animales ADD COLUMN IF NOT EXISTS nombre         TEXT;
ALTER TABLE animales ADD COLUMN IF NOT EXISTS actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now();
CREATE INDEX IF NOT EXISTS animales_estado_idx ON animales (estado);

-- Si tu base alcanzó a tener los campos de zootecnia, se quitan así:
ALTER TABLE animales DROP CONSTRAINT IF EXISTS animales_sexo_check;
ALTER TABLE animales DROP COLUMN IF EXISTS raza;
ALTER TABLE animales DROP COLUMN IF EXISTS sexo;
ALTER TABLE animales DROP COLUMN IF EXISTS fecha_nacimiento;
```

Más el trigger de `actualizado_en`, que está al final de `schema.sql`.

Y para pasar al arete como clave primaria (**esto borra `animales.id` y no se
puede deshacer: haz respaldo con `pg_dump` antes**):

```sql
-- Se rellena la columna nueva mientras la relación numérica todavía existe.
ALTER TABLE eventos ADD COLUMN IF NOT EXISTS animal_identificador TEXT;
UPDATE eventos e SET animal_identificador = a.identificador
FROM animales a WHERE a.id = e.animal_id;

ALTER TABLE eventos DROP CONSTRAINT IF EXISTS eventos_animal_id_fkey;
ALTER TABLE eventos DROP COLUMN animal_id;
ALTER TABLE eventos RENAME COLUMN animal_identificador TO animal_id;

ALTER TABLE animales DROP CONSTRAINT animales_pkey;
ALTER TABLE animales DROP COLUMN id;
ALTER TABLE animales DROP CONSTRAINT IF EXISTS animales_identificador_key;
ALTER TABLE animales ADD CONSTRAINT animales_pkey PRIMARY KEY (identificador);

ALTER TABLE eventos ADD CONSTRAINT eventos_animal_id_fkey
    FOREIGN KEY (animal_id) REFERENCES animales(identificador)
    ON DELETE SET NULL ON UPDATE CASCADE;
CREATE INDEX IF NOT EXISTS eventos_animal_id_idx ON eventos (animal_id);
```

El backend trae esto mismo, ya en forma repetible y con una guarda para poder
ejecutarlo dos veces, en `database/0002_animales_pk_identificador.sql`. El
borrado de los campos de zootecnia está en
`database/0003_animales_quitar_campos_zootecnicos.sql`.

## Subirla a la nube gratis con Neon

1. Crea una cuenta en https://neon.com (sin tarjeta) y un proyecto nuevo.
   Región sugerida: AWS US East (Virginia u Ohio).
2. Abre **SQL Editor**, pega todo el contenido de `schema.sql` y pulsa **Run**.
3. En la pestaña **Tables** deben aparecer las cinco tablas.
4. Para conectarte desde otro programa, usa el botón **Connect** y copia la cadena
   `postgresql://usuario:clave@host/neondb?sslmode=require`.

Alternativa por consola (con `psql` instalado):

```powershell
psql "postgresql://usuario:clave@host/neondb?sslmode=require" -f database/schema.sql
```

## Para GitHub

Sube la carpeta `database/`. **No subas la cadena de conexión** (contiene la clave):
guárdala en un archivo `.env` y agrega `.env` al `.gitignore`.

## Plan gratuito de Neon (consultado el 04/10/2026)

1 GB por proyecto, sin caducidad. Se suspende tras 5 minutos sin uso; la primera
consulta después de la pausa tarda un poco más. El plan de pago cobra por uso
(desde 0,106 USD por CU-hora, sin mínimo mensual).
