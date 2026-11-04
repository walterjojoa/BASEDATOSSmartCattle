-- 0031: lo que vio la IA, por camara y minuto.
--
-- No es events: events guarda incidentes que dispara una regla. Tampoco es una
-- fila por deteccion: la IA evalua varias veces por segundo y guardarlas serian
-- decenas de miles de filas por camara al dia. Una por minuto, el ultimo reporte
-- de ese minuto, son 1 440 y alcanzan para saber cuanto paso el hato echado o de
-- pie.
--
-- La escribe solo el backend. Es la misma de su migracion 0019_detection_logs;
-- cada lado la crea solo si falta, asi que da igual cual corra primero.

CREATE TABLE IF NOT EXISTS detection_logs (
    camera_id       bigint           NOT NULL REFERENCES cameras (id) ON DELETE CASCADE,
    minute          timestamptz      NOT NULL,
    cattle_lying    integer          NOT NULL,
    cattle_standing integer          NOT NULL,
    cattle_walking  integer          NOT NULL,
    cattle_unknown  integer          NOT NULL,
    people          integer          NOT NULL,
    avg_confidence  double precision,
    observed_at     timestamptz      NOT NULL,
    -- Empieza por camera_id: sirve a la clave ajena, y a la consulta de los
    -- graficos, que pide las camaras de una cuenta en un rango de fechas.
    CONSTRAINT detection_logs_pkey PRIMARY KEY (camera_id, minute),
    CONSTRAINT detection_logs_cattle_lying_check    CHECK (cattle_lying >= 0),
    CONSTRAINT detection_logs_cattle_standing_check CHECK (cattle_standing >= 0),
    CONSTRAINT detection_logs_cattle_walking_check  CHECK (cattle_walking >= 0),
    CONSTRAINT detection_logs_cattle_unknown_check  CHECK (cattle_unknown >= 0),
    CONSTRAINT detection_logs_people_check          CHECK (people >= 0),
    CONSTRAINT detection_logs_avg_confidence_check  CHECK (avg_confidence BETWEEN 0 AND 1)
);

-- Consulta: la retencion y lo que mira todas las camaras a la vez.
--     DELETE FROM detection_logs WHERE minute < $1
CREATE INDEX IF NOT EXISTS detection_logs_minute_idx ON detection_logs (minute);

-- La misma forma de consultar que events: una fila por objeto y postura vistos,
-- sin filas en cero. No guarda nada; lee detection_logs.
CREATE OR REPLACE VIEW detections AS
SELECT l.camera_id,
       c.account_id,
       x.object_type,
       x.posture,
       x.detected_count,
       l.avg_confidence,
       l.minute AS "timestamp"
  FROM detection_logs l
  JOIN cameras c ON c.id = l.camera_id
 CROSS JOIN LATERAL (VALUES
       ('cattle', 'lying',    l.cattle_lying),
       ('cattle', 'standing', l.cattle_standing),
       ('cattle', 'walking',  l.cattle_walking),
       ('cattle', NULL,       l.cattle_unknown),
       ('person', NULL,       l.people)
 ) AS x (object_type, posture, detected_count)
 WHERE x.detected_count > 0;

-- Igual que prune_events (0014): sin cron en el plan gratuito de Neon, la llama
-- quien decida la politica.
CREATE OR REPLACE FUNCTION prune_detection_logs(older_than interval)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    removed bigint;
BEGIN
    IF older_than IS NULL OR older_than <= interval '0' THEN
        RAISE EXCEPTION 'prune_detection_logs necesita un intervalo positivo, recibio %', older_than;
    END IF;

    DELETE FROM detection_logs WHERE minute < now() - older_than;
    GET DIAGNOSTICS removed = ROW_COUNT;
    RETURN removed;
END $$;

COMMENT ON TABLE detection_logs IS
    'Lo que vio la IA por camara y minuto: el ultimo reporte de ese minuto. Crece ~1 440 filas por camara al dia.';
COMMENT ON COLUMN detection_logs.minute IS 'El minuto, con los segundos en cero (UTC).';
COMMENT ON COLUMN detection_logs.cattle_unknown IS 'Reses cuya postura la IA no pudo estimar. No es lo mismo que de pie.';
COMMENT ON COLUMN detection_logs.observed_at IS 'Reloj de la IA del reporte que quedo. Uno atrasado no reescribe el minuto.';
COMMENT ON VIEW detections IS
    'detection_logs por objeto y postura. detected_count es cuantos se veian en ese minuto, no cuantas detecciones hubo.';
COMMENT ON COLUMN detections.posture IS 'lying, standing o walking. NULL: persona, o res cuya postura no se pudo estimar.';
COMMENT ON FUNCTION prune_detection_logs(interval) IS
    'Borra lo anterior al intervalo dado y devuelve cuantas filas. Esos dias dejan de aparecer en daily_reports().';
