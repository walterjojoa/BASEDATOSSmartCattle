-- SmartCattle: esquema PostgreSQL (se puede ejecutar varias veces sin romper nada).
-- Zona horaria: todas las fechas se guardan en UTC (timestamptz).

CREATE TABLE IF NOT EXISTS camaras (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      TEXT        NOT NULL UNIQUE,
    fuente      TEXT        NOT NULL DEFAULT '0',  -- índice USB, ruta de video o URL RTSP
    ubicacion   TEXT,
    activa      BOOLEAN     NOT NULL DEFAULT TRUE,
    creada_en   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Zona segura rectangular, coordenadas normalizadas entre 0 y 1 (igual que SAFE_ZONE).
CREATE TABLE IF NOT EXISTS zonas (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    camara_id   BIGINT      NOT NULL REFERENCES camaras(id) ON DELETE CASCADE,
    nombre      TEXT        NOT NULL,
    x_min        REAL        NOT NULL CHECK (x_min BETWEEN 0 AND 1),
    y_min        REAL        NOT NULL CHECK (y_min BETWEEN 0 AND 1),
    x_max        REAL        NOT NULL CHECK (x_max BETWEEN 0 AND 1),
    y_max        REAL        NOT NULL CHECK (y_max BETWEEN 0 AND 1),
    activa      BOOLEAN     NOT NULL DEFAULT TRUE,
    creada_en   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (camara_id, nombre),
    CHECK (x_min < x_max AND y_min < y_max)
);

-- Registro de animales (la identificación individual por la IA es una fase futura).
CREATE TABLE IF NOT EXISTS animales (
    id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    identificador     TEXT        NOT NULL UNIQUE,   -- arete, nombre o código
    estado            TEXT        NOT NULL DEFAULT 'activo'
                      CHECK (estado IN ('activo', 'inactivo', 'perdido')),
    camara_id         BIGINT      REFERENCES camaras(id) ON DELETE SET NULL,
    zona_id           BIGINT      REFERENCES zonas(id)   ON DELETE SET NULL,
    ultima_deteccion  TIMESTAMPTZ,
    creado_en         TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Campos descriptivos que agregó SmartCattle-Backend para su CRUD de
    -- animales. Todos admiten NULL (o traen DEFAULT), así que no obligan a nada
    -- a los demás servicios que escriban en esta tabla.
    nombre            TEXT,
    raza              TEXT,
    sexo              TEXT        CHECK (sexo IN ('macho', 'hembra')),
    fecha_nacimiento  DATE,
    -- Sin CHECK contra CURRENT_DATE a propósito: esa restricción no es inmutable
    -- y un restore de respaldo falla al revalidarla contra un "hoy" distinto.
    -- La regla se valida en la aplicación.
    actualizado_en    TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- El borrado de animales del backend es lógico (estado = 'inactivo'), así que la
-- consulta habitual es "los activos". Sin este índice recorre la tabla entera.
CREATE INDEX IF NOT EXISTS animales_estado_idx ON animales (estado);

-- `actualizado_en` lo mantiene la base, no la aplicación: varios servicios
-- escriben en esta tabla (el de IA actualiza `ultima_deteccion`), y un timestamp
-- que sólo un escritor refresca miente en cuanto otro toca la fila.
CREATE OR REPLACE FUNCTION animales_set_actualizado_en() RETURNS trigger AS $$
BEGIN
    NEW.actualizado_en := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS animales_actualizado_en_trg ON animales;
CREATE TRIGGER animales_actualizado_en_trg
    BEFORE UPDATE ON animales
    FOR EACH ROW EXECUTE FUNCTION animales_set_actualizado_en();

-- Eventos generados por las reglas (hoy: ganado_fuera_zona).
CREATE TABLE IF NOT EXISTS eventos (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo        TEXT        NOT NULL,                -- p. ej. 'ganado_fuera_zona'
    nivel       TEXT        NOT NULL DEFAULT 'media'
                CHECK (nivel IN ('baja', 'media', 'alta')),
    origen      TEXT        NOT NULL DEFAULT 'camara'
                CHECK (origen IN ('camara', 'imagen')),
    camara_id   BIGINT      REFERENCES camaras(id) ON DELETE SET NULL,
    zona_id     BIGINT      REFERENCES zonas(id)   ON DELETE SET NULL,
    animal_id   BIGINT      REFERENCES animales(id) ON DELETE SET NULL,
    clase       TEXT,                                -- 'cow', etc.
    confianza   REAL        CHECK (confianza BETWEEN 0 AND 1),
    caja        JSONB,                               -- [x1, y1, x2, y2] en píxeles
    ancho       INTEGER,
    alto        INTEGER,
    -- 'fecha' es cuando la IA detectó. 'recibido_en' es cuando el backend lo
    -- recibió. Pueden diferir por demoras de red, y la diferencia sirve para
    -- detectar relojes desfasados en el servicio de IA.
    fecha       TIMESTAMPTZ NOT NULL DEFAULT now(),
    recibido_en TIMESTAMPTZ,
    -- Identificador que el servicio de IA genera una vez por detección y reutiliza
    -- en cada reintento. El UNIQUE es lo que hace la ingesta idempotente: la base
    -- rechaza la segunda inserción, así que dos reintentos simultáneos no pueden
    -- crear dos filas. Admite NULL (y PostgreSQL permite varios NULL bajo un
    -- UNIQUE) para no obligar a los demás servicios que escriban aquí.
    ai_event_id UUID        UNIQUE
);
CREATE INDEX IF NOT EXISTS eventos_fecha_idx       ON eventos (fecha DESC);
CREATE INDEX IF NOT EXISTS eventos_tipo_fecha_idx  ON eventos (tipo, fecha DESC);

-- Alertas enviadas (o por enviar) al encargado a partir de un evento.
CREATE TABLE IF NOT EXISTS alertas (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    evento_id   BIGINT      NOT NULL REFERENCES eventos(id) ON DELETE CASCADE,
    canal       TEXT        NOT NULL DEFAULT 'correo'
                CHECK (canal IN ('correo', 'whatsapp', 'telegram', 'sms', 'n8n')),
    estado      TEXT        NOT NULL DEFAULT 'pendiente'
                CHECK (estado IN ('pendiente', 'enviada', 'fallida', 'atendida')),
    detalle     TEXT,
    creada_en   TIMESTAMPTZ NOT NULL DEFAULT now(),
    enviada_en  TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS alertas_estado_idx ON alertas (estado);

-- Datos iniciales: una cámara y la zona segura por defecto del backend.
INSERT INTO camaras (nombre, fuente, ubicacion)
VALUES ('Cámara principal', '0', 'Por definir')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO zonas (camara_id, nombre, x_min, y_min, x_max, y_max)
SELECT id, 'Zona segura', 0.1, 0.1, 0.9, 0.9
FROM camaras WHERE nombre = 'Cámara principal'
ON CONFLICT (camara_id, nombre) DO NOTHING;
