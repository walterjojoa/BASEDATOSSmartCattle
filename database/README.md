# Base de datos de SmartCattle (PostgreSQL)

Archivo: [`schema.sql`](schema.sql). Se puede ejecutar varias veces sin duplicar datos.

Los nombres de tablas y columnas están **en inglés**, igual que la API REST, así
que ningún servicio tiene que traducir entre los dos. Las fechas se guardan en
UTC (`timestamptz`).

## Tablas

| Tabla | Para qué sirve |
| --- | --- |
| `cameras` | Cámaras del predio (`source`: USB, video o RTSP). |
| `zones` | Zona segura rectangular por cámara (coordenadas de 0 a 1). |
| `users` | Personas que usan el sistema: nombre, correo, contraseña hasheada y si es dueño de la finca o trabajador. |
| `animals` | Registro de animales. La clave primaria es el arete. |
| `events` | Eventos detectados (p. ej. `cattle_out_of_zone`) con clase, confianza, caja y fecha. |
| `alerts` | Alertas por evento: canal (`email`, `whatsapp`, `n8n`...) y estado (`pending`, `sent`, `failed`, `handled`). |

```text
cameras 1--+--* zones
           +--* animals        (camera_id, zone_id: ON DELETE SET NULL)
           +--* events 1--* alerts   (event_id: ON DELETE CASCADE)

animals 1--* events            (events.animal_tag -> animals.tag)

users                          (independiente: nada la referencia todavía)
```

Trae datos iniciales: una cámara (`Main camera`) y una zona (`Safe zone`).

## Decisiones que conviene conocer

### El arete es la clave primaria de `animals`

No hay `id` numérico: `tag` es la clave primaria. El arete es la identidad real
de la vaca, la que está físicamente en la oreja y con la que la nombra el
personal del predio. Un segundo identificador numérico obligaría a traducir
entre los dos en cada consulta.

Por eso `events.animal_tag` es `TEXT` y no `BIGINT`, y lleva **`ON UPDATE
CASCADE`**: una clave primaria natural sí cambia —un arete se cae y se repone—,
y sin la cascada los eventos de ese animal quedarían apuntando a un arete que ya
no existe. Conserva `ON DELETE SET NULL`, porque borrar un animal no debe borrar
su histórico.

### `animals` no lleva raza, sexo ni fecha de nacimiento

SmartCattle rastrea el ganado **por seguridad** —dónde está un animal y si salió
de su zona—, no gestiona el hato ni su comercialización. Esos datos son de
zootecnia y de valoración comercial: no ayudan a localizar a un animal ni a
detectar que se escapó. Existieron brevemente, siguiendo el planteamiento
inicial, y se quitaron al precisar el alcance del proyecto.

`name` sí se conserva: sirve para que el personal reconozca de qué animal habla
una alerta.

### Los animales y las cuentas se desactivan, no se borran

`animals.status` pasa a `inactive` y `users.is_active` a `false`. La fila se
queda. Un animal borrado dejaría su histórico de alertas sin el animal al que se
refiere, y una cuenta borrada no se distingue de una que nunca existió, lo que
destruye el registro de quién tuvo acceso. De ahí los índices
`animals_status_idx` y `users_role_idx`: filtrar pasa a ser la consulta habitual.

### `users.password_hash` nunca guarda la contraseña

Guarda un hash **bcrypt**, que no se puede revertir. Si la tabla se filtra, no
debe entregar las cuentas que describe. El `CHECK (email = lower(email))` obliga
a guardar el correo en minúsculas: sin él, `Ana@finca.com` y `ana@finca.com`
serían dos filas distintas bajo el `UNIQUE` y la misma persona podría
registrarse dos veces.

La columna `role` registra si la persona es `owner` o `worker`. Lo que puede
hacer cada rol **no se controla aquí** todavía.

### `updated_at` lo mantiene la base, no la aplicación

El trigger `set_updated_at()` lo refresca en `animals` y en `users`. Varios
servicios escriben en estas tablas —el de IA actualiza `last_detection`—, y un
timestamp que sólo un escritor refresca miente en cuanto otro toca la fila.

## Columnas que pidió el backend

Dos columnas de `events` las necesita SmartCattle-Backend para ingerir eventos de
la IA. Ambas admiten `NULL`, así que no obligan a nada a los demás servicios.

| Columna | Para qué sirve |
| --- | --- |
| `received_at TIMESTAMPTZ` | Cuándo recibió el backend el evento. `detected_at` es cuándo lo detectó la IA; la diferencia revela demoras de red o relojes desfasados. |
| `ai_event_id UUID UNIQUE` | Identificador que la IA genera una vez por detección y reutiliza en cada reintento. El `UNIQUE` hace la ingesta idempotente: un reintento no crea una segunda fila, y la base resuelve la carrera cuando dos reintentos llegan a la vez. |

Sin `ai_event_id`, un reintento tras un tiempo de espera agotado guarda el mismo
avistamiento dos veces, y la tabla no tiene forma de distinguir un reintento de
dos animales detectados en el mismo segundo.

## Para una base nueva

Basta `schema.sql`: describe el estado final, incluida la tabla `users`.

```powershell
psql -h TU_HOST -U TU_USUARIO -d TU_BASE -f database/schema.sql
```

## Para una base que ya tiene datos

`CREATE TABLE IF NOT EXISTS` no modifica una tabla que ya existe, así que hay que
aplicar los cambios con `ALTER`. **Respalda antes**, porque algunos borran
columnas y eso no se deshace:

```powershell
pg_dump -h TU_HOST -U TU_USUARIO -d TU_BASE -f respaldo.sql
```

SmartCattle-Backend los trae listos, repetibles y en orden, en su carpeta
`database/`:

| Archivo | Qué hace |
| --- | --- |
| `0001_animales_campos_descriptivos.sql` | Agrega `nombre`, `actualizado_en` y el trigger. |
| `0002_animales_pk_identificador.sql` | El arete pasa a ser la clave primaria. **Borra `animales.id`.** |
| `0003_animales_quitar_campos_zootecnicos.sql` | Quita raza, sexo y fecha de nacimiento. |
| `0004_esquema_en_ingles.sql` | Renombra todo a inglés y convierte los valores guardados. |
| `0005_users.sql` | Crea la tabla `users`. |

**El `0004` rompe a cualquier otro servicio** que lea o escriba estas tablas
hasta que se actualice: cambian los nombres de tablas, los de columnas y también
los valores (`'activo'` pasa a `'active'`, `'ganado_fuera_zona'` pasa a
`'cattle_out_of_zone'`). Coordínalo con el equipo.

## Subirla a la nube gratis con Neon

1. Crea una cuenta en https://neon.com (sin tarjeta) y un proyecto nuevo.
   Región sugerida: AWS US East (Virginia u Ohio).
2. Abre **SQL Editor**, pega todo el contenido de `schema.sql` y pulsa **Run**.
3. En la pestaña **Tables** deben aparecer las seis tablas.
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
