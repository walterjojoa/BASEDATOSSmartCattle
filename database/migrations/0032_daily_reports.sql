-- 0032: informe diario de una cuenta, calculado al pedirlo.
--
--     SELECT * FROM daily_reports(1, '2026-03-01', '2026-03-31', 'America/Bogota');
--
-- Funcion y no vista: una vista agrupa por dia y filtra despues, recorriendo toda
-- la historia de la cuenta. Aqui cada dia se convierte en un rango de minute, que
-- usa la clave primaria (camera_id, minute). Y no tabla: habria que refrescarla
-- cada noche y el plan gratuito de Neon no tiene cron, asi que quedaria vieja sin
-- que nadie lo note.
--
-- Una camara sin datos ese dia no tiene fila: "no hubo nada que resumir" no es
-- lo mismo que cero vacas. Los conteos de detection_logs son lo que se veia en
-- cada minuto, por eso se promedian y no se suman.

CREATE OR REPLACE FUNCTION daily_reports(
    report_account_id bigint,
    first_day date,
    last_day date,
    day_time_zone text DEFAULT 'America/Bogota'
) RETURNS TABLE (
    report_date date,
    camera_id bigint,
    camera text,
    minutes_observed integer,
    avg_cattle numeric,
    max_cattle integer,
    avg_cattle_lying numeric,
    avg_cattle_standing numeric,
    avg_cattle_walking numeric,
    max_people integer,
    minutes_with_people integer,
    avg_confidence numeric,
    first_seen_at timestamptz,
    last_seen_at timestamptz,
    out_of_zone_events integer,
    max_cattle_outside integer
)
LANGUAGE sql
STABLE
AS $$
    SELECT day::date,
           c.id,
           coalesce(c.display_name, c.name),
           d.minutes,
           d.avg_cattle, d.max_cattle,
           d.avg_lying, d.avg_standing, d.avg_walking,
           d.max_people, d.minutes_with_people,
           d.avg_confidence,
           d.first_seen, d.last_seen,
           e.out_of_zone,
           o.max_outside
      FROM cameras c
     CROSS JOIN generate_series(first_day::timestamp, last_day::timestamp, interval '1 day') AS day
     CROSS JOIN LATERAL (
           -- Timestamps sin zona a proposito: asi un dia con cambio de hora dura
           -- lo que dura, y no 24 horas fijas.
           SELECT day AT TIME ZONE day_time_zone AS day_start,
                  (day + interval '1 day') AT TIME ZONE day_time_zone AS day_end
     ) AS bounds
     CROSS JOIN LATERAL (
           SELECT count(*)::integer AS minutes,
                  round(avg(x.cattle_lying + x.cattle_standing + x.cattle_walking + x.cattle_unknown)::numeric, 1) AS avg_cattle,
                  max(x.cattle_lying + x.cattle_standing + x.cattle_walking + x.cattle_unknown) AS max_cattle,
                  round(avg(x.cattle_lying)::numeric, 1) AS avg_lying,
                  round(avg(x.cattle_standing)::numeric, 1) AS avg_standing,
                  round(avg(x.cattle_walking)::numeric, 1) AS avg_walking,
                  max(x.people) AS max_people,
                  (count(*) FILTER (WHERE x.people > 0))::integer AS minutes_with_people,
                  round(avg(x.avg_confidence)::numeric, 3) AS avg_confidence,
                  min(x.minute) AS first_seen,
                  max(x.minute) AS last_seen
             FROM detection_logs x
            WHERE x.camera_id = c.id AND x.minute >= bounds.day_start AND x.minute < bounds.day_end
     ) AS d
     CROSS JOIN LATERAL (
           SELECT count(*)::integer AS out_of_zone
             FROM events x
            WHERE x.camera_id = c.id AND x.type = 'cattle_out_of_zone'
              AND x.detected_at >= bounds.day_start AND x.detected_at < bounds.day_end
     ) AS e
     CROSS JOIN LATERAL (
           SELECT max(x.cattle_outside) AS max_outside
             FROM occupancy_samples x
            WHERE x.camera_id = c.id AND x.minute >= bounds.day_start AND x.minute < bounds.day_end
     ) AS o
     WHERE c.account_id = report_account_id
       AND (d.minutes > 0 OR e.out_of_zone > 0 OR o.max_outside IS NOT NULL)
     ORDER BY 1, 3
$$;

COMMENT ON FUNCTION daily_reports(bigint, date, date, text) IS
    'Informe por camara y dia de una cuenta. Se calcula al pedirlo; los dias podados dejan de aparecer.';
