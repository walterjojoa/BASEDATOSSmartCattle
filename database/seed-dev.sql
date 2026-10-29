-- Datos de desarrollo. NO correr en produccion.
--
-- Suficientes filas para que el tablero, el feed y las metricas muestren algo
-- creible sin esperar a que el servicio de IA produzca eventos reales.
--
-- Idempotente, como todo aqui: los identificadores llevan el prefijo `dev-`
-- para poder borrarlos de un golpe, y los INSERT usan ON CONFLICT.
--
--   psql "$env:TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f database/seed-dev.sql

BEGIN;

-- Camaras
INSERT INTO cameras (name, source, location) VALUES
    ('camera-01', '0', 'Porton norte'),
    ('camera-02', '1', 'Bebedero'),
    ('camera-03', 'rtsp://ejemplo/stream', 'Potrero sur')
ON CONFLICT (name) DO NOTHING;

-- Una zona segura por camara
INSERT INTO zones (camera_id, name, x_min, y_min, x_max, y_max)
SELECT id, 'Safe zone', 0.1, 0.1, 0.9, 0.9 FROM cameras
WHERE name IN ('camera-01', 'camera-02', 'camera-03')
ON CONFLICT (camera_id, name) DO NOTHING;

-- Personal: una dueña y un trabajador. La contrasena es un hash bcrypt de
-- ejemplo, no corresponde a ninguna contrasena util.
INSERT INTO users (email, password_hash, full_name, role) VALUES
    ('dev-owner@finca.test',  '$2b$12$devdevdevdevdevdevdevdevdevdevdevdevdevdevdevdevdevdevdev', 'Dueña de prueba', 'owner'),
    ('dev-worker@finca.test', '$2b$12$devdevdevdevdevdevdevdevdevdevdevdevdevdevdevdevdevdevdev', 'Trabajador de prueba', 'worker')
ON CONFLICT (email) DO NOTHING;

-- Hato: 12 animales activos, uno inactivo y uno perdido, para que las tres
-- ramas del CHECK de status tengan datos.
INSERT INTO animals (tag, name, status, camera_id, last_detection)
SELECT format('dev-%s', n),
       format('Vaca %s', n),
       CASE WHEN n = 13 THEN 'inactive' WHEN n = 14 THEN 'lost' ELSE 'active' END,
       (SELECT id FROM cameras WHERE name = 'camera-01'),
       -- Una sin detectar nunca: es el caso que esconde un WHERE mal escrito.
       CASE WHEN n = 1 THEN NULL ELSE now() - make_interval(hours => n) END
FROM generate_series(1, 14) AS n
ON CONFLICT (tag) DO NOTHING;

COMMIT;
