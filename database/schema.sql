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

-- Registro de animales (la identificación individual es una fase futura).
CREATE TABLE IF NOT EXISTS animales (
    id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    identificador     TEXT        NOT NULL UNIQUE,   -- arete, nombre o código
    estado            TEXT        NOT NULL DEFAULT 'activo'
                      CHECK (estado IN ('activo', 'inactivo', 'perdido')),
    camara_id         BIGINT      REFERENCES camaras(id) ON DELETE SET NULL,
    zona_id           BIGINT      REFERENCES zonas(id)   ON DELETE SET NULL,
    ultima_deteccion  TIMESTAMPTZ,
    creado_en         TIMESTAMPTZ NOT NULL DEFAULT now()
);

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
    fecha       TIMESTAMPTZ NOT NULL DEFAULT now()
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
