# Base de datos de SmartCattle (PostgreSQL)

Archivo: [`schema.sql`](schema.sql). Se puede ejecutar varias veces sin duplicar datos.

## Tablas

| Tabla | Para qué sirve |
| --- | --- |
| `camaras` | Cámaras del predio (fuente: USB, video o RTSP). |
| `zonas` | Zona segura rectangular por cámara (coordenadas de 0 a 1). |
| `animales` | Registro de animales. |
| `eventos` | Eventos detectados (p. ej. `ganado_fuera_zona`) con clase, confianza, caja y fecha. |
| `alertas` | Alertas por evento: canal (correo, WhatsApp, n8n...) y estado (pendiente, enviada, fallida, atendida). |

```text
camaras 1─┬─* zonas
          ├─* animales
          └─* eventos 1─* alertas
```

Trae datos iniciales: una cámara (`Cámara principal`) y una zona (`Zona segura`).

## Columnas que agregó el backend

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

Para una base que ya existe:

```sql
ALTER TABLE eventos ADD COLUMN IF NOT EXISTS recibido_en TIMESTAMPTZ;
ALTER TABLE eventos ADD COLUMN IF NOT EXISTS ai_event_id UUID UNIQUE;
```

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
