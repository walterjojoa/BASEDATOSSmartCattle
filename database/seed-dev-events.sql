-- Eventos de desarrollo. NO correr en produccion.
--
-- Separado de seed-dev.sql porque esto se corre varias veces mientras se
-- trabaja: cada pasada agrega 40 eventos nuevos repartidos en las ultimas 48
-- horas, lo que basta para que las metricas por hora y por dia tengan forma.
--
-- Requiere seed-dev.sql antes (necesita las camaras).

BEGIN;

INSERT INTO events (
    type, level, camera_id, detected_object, confidence, box, width, height,
    detected_at, received_at, ai_event_id
)
SELECT 'cattle_out_of_zone',
       CASE WHEN n % 7 = 0 THEN 'high' WHEN n % 3 = 0 THEN 'low' ELSE 'medium' END,
       (SELECT id FROM cameras WHERE name = format('camera-%s', lpad((1 + n % 3)::text, 2, '0'))),
       'cow',
       -- De 0.72 a 0.97, el rango que produce el motor de deteccion.
       0.72 + (n % 26) * 0.01,
       format('[%s, %s, %s, %s]', 100 + n, 80 + n, 300 + n, 260 + n)::jsonb,
       640, 480,
       now() - make_interval(mins => n * 72),
       -- received_at va despues de detected_at, con demora variable: es lo que
       -- hace que la consulta de desfase de reloj devuelva algo.
       now() - make_interval(mins => n * 72) + make_interval(secs => 1 + n % 4),
       gen_random_uuid()
FROM generate_series(1, 40) AS n;

-- Una fila como la que escribe otro servicio: sin ai_event_id ni received_at,
-- y sin objeto. La API no la lista, y tenerla es lo que comprueba que el filtro
-- sigue puesto.
INSERT INTO events (type, camera_id, detected_at)
SELECT 'cattle_out_of_zone', id, now() - interval '3 hours'
FROM cameras WHERE name = 'camera-01';

COMMIT;
