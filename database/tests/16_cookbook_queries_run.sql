-- Las consultas de docs/consultas.md se ejecutan.
--
-- Un recetario es documentacion que caduca en silencio: se renombra una
-- columna, se cambia una vista, y la consulta sigue publicada y ya no corre.
-- Aqui se ejecuta cada una contra el esquema real.
--
-- No se comprueba el resultado, solo que la consulta es valida: con la base
-- vacia casi todas devuelven cero filas, y exigir un resultado concreto
-- obligaria a sembrar datos y volveria fragil la comprobacion.

DO $$
BEGIN
    -- Los ultimos eventos, legibles.
    PERFORM detected_at, camera_name, detected_object, round(confidence::numeric, 2)
    FROM v_api_events ORDER BY detected_at DESC LIMIT 50;

    -- Alertas por dia, con los dias vacios incluidos.
    PERFORM dia::date, count(e.id)
    FROM generate_series(now() - interval '14 days', now(), interval '1 day') AS dia
    LEFT JOIN v_api_events e ON date_trunc('day', e.detected_at) = date_trunc('day', dia)
    GROUP BY dia;

    -- Animales que no se ven desde hace mucho.
    PERFORM tag, name, camera_name, unseen_for
    FROM v_active_herd
    WHERE last_detection IS NULL OR last_detection < now() - interval '2 days';

    -- La cola de envio.
    PERFORM a.id, a.channel, now() - a.created_at, e.type, c.name
    FROM alerts a
    JOIN events e ON e.id = a.event_id
    LEFT JOIN cameras c ON c.id = e.camera_id
    WHERE a.status = 'pending';

    -- Reintentos fallidos.
    PERFORM channel, count(*), max(created_at), min(detail)
    FROM alerts WHERE status = 'failed' GROUP BY channel;

    -- Desfase entre relojes.
    PERFORM date_trunc('hour', received_at), count(*),
            avg(received_at - detected_at), max(received_at - detected_at)
    FROM events
    WHERE received_at IS NOT NULL AND detected_at IS NOT NULL
    GROUP BY 1;

    -- Filas que la API no puede listar, desglosadas.
    PERFORM count(*) FILTER (WHERE ai_event_id IS NULL),
            count(*) FILTER (WHERE received_at IS NULL),
            count(*) FILTER (WHERE detected_object IS NULL),
            count(*) FILTER (WHERE confidence IS NULL)
    FROM events;
END $$;

-- La de duplicados tiene que devolver cero filas siempre: lo garantiza el
-- UNIQUE sobre ai_event_id. Esta si se comprueba.
DO $$
DECLARE
    duplicated bigint;
BEGIN
    SELECT count(*) INTO duplicated FROM (
        SELECT ai_event_id FROM events
        WHERE ai_event_id IS NOT NULL
        GROUP BY ai_event_id HAVING count(*) > 1
    ) d;

    ASSERT duplicated = 0,
           format('hay %s ai_event_id duplicados: el UNIQUE se cayo', duplicated);
END $$;
