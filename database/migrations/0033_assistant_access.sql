-- 0033: lo que puede leer el asistente de IA.
--
-- El asistente responde con datos de la cuenta de quien pregunta. Si el aislamiento
-- dependiera de que el modelo escriba bien un WHERE, una pregunta mal planteada
-- o una inyeccion en el texto mostraria la finca de otro. Por eso:
--
-- - El rol smartcattle_assistant no tiene permiso sobre ninguna tabla. Solo lee
--   estas vistas, que dejan fuera lo sensible: password_hash, correos,
--   cameras.source y stream_url, que pueden llevar credenciales o abrir video.
-- - Cada vista filtra por la cuenta de la sesion. Sin cuenta devuelve cero filas:
--   un olvido del backend deja al asistente sin datos, no con los de todos.
--
-- El backend abre cada consulta asi, con SQL fijo y parametros, nunca con SQL
-- que haya escrito el modelo (ver docs/asistente.md):
--
--     BEGIN READ ONLY;
--     SET LOCAL ROLE smartcattle_assistant;
--     SELECT set_config('app.current_account_id', $1, true);
--     SELECT ... FROM v_assistant_events WHERE ...;
--     COMMIT;

-- Crear el rol y otorgarlo pide permisos que no todo usuario tiene, y el backend
-- corre esto al arrancar. Solo el asistente depende de ello, asi que sin permisos
-- la migracion avisa y sigue: el resto de la API no debe caerse por esto. Cuando
-- un administrador cree el rol, volver a correr este archivo completa los permisos.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'smartcattle_assistant') THEN
        BEGIN
            CREATE ROLE smartcattle_assistant NOLOGIN;
        EXCEPTION WHEN insufficient_privilege THEN
            RAISE WARNING 'Falta el rol smartcattle_assistant y % no puede crearlo. El asistente no funciona hasta que exista. Ver docs/asistente.md', current_user;
            RETURN;
        END;
    END IF;

    -- Desde PostgreSQL 16 quien crea un rol no puede hacer SET ROLE a el sin este
    -- GRANT, y en Neon el backend no es superusuario. Los roles son de todo el
    -- servidor: si otro usuario creo este, no se puede otorgar desde aqui.
    IF NOT pg_has_role(current_user, 'smartcattle_assistant', 'SET') THEN
        BEGIN
            GRANT smartcattle_assistant TO CURRENT_USER;
        EXCEPTION WHEN insufficient_privilege THEN
            RAISE WARNING 'Falta GRANT smartcattle_assistant TO %: lo debe correr quien creo el rol. El asistente no funciona hasta entonces.', current_user;
        END;
    END IF;
END $$;

-- NULLIF: terminada una transaccion con set_config local, la variable queda en ''
-- y no en NULL, y ''::bigint fallaria en vez de no devolver nada.
CREATE OR REPLACE FUNCTION assistant_account_id() RETURNS bigint
LANGUAGE sql
STABLE
AS $$
    SELECT NULLIF(current_setting('app.current_account_id', true), '')::bigint
$$;

COMMENT ON FUNCTION assistant_account_id() IS
    'Cuenta de la sesion del asistente. NULL si el backend no la fijo, y entonces las vistas no devuelven filas.';

-- security_barrier: impide que un filtro con efectos del que consulta vea filas
-- antes de que la vista descarte las de otras cuentas.
CREATE OR REPLACE VIEW v_assistant_detections WITH (security_barrier = true) AS
SELECT coalesce(c.display_name, c.name) AS camera,
       d.object_type,
       d.posture,
       d.detected_count,
       d.avg_confidence,
       d."timestamp"
  FROM detections d
  JOIN cameras c ON c.id = d.camera_id
 WHERE d.account_id = assistant_account_id();

CREATE OR REPLACE VIEW v_assistant_events WITH (security_barrier = true) AS
SELECT e.id,
       coalesce(c.display_name, c.name) AS camera,
       e.type,
       e.level,
       e.detected_object,
       e.confidence,
       e.detected_at
  FROM events e
  JOIN cameras c ON c.id = e.camera_id
 WHERE c.account_id = assistant_account_id();

-- SECURITY DEFINER: daily_reports() lee tablas a las que este rol no tiene acceso.
-- Es seguro porque no recibe la cuenta como parametro, la toma de la sesion, y
-- search_path fijo porque una funcion asi no puede resolver nombres con el del
-- que la llama.
CREATE OR REPLACE FUNCTION assistant_daily_reports(
    first_day date,
    last_day date,
    day_time_zone text DEFAULT 'America/Bogota'
) RETURNS TABLE (
    report_date date,
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
SECURITY DEFINER
SET search_path FROM CURRENT
AS $$
    SELECT r.report_date, r.camera, r.minutes_observed, r.avg_cattle, r.max_cattle,
           r.avg_cattle_lying, r.avg_cattle_standing, r.avg_cattle_walking,
           r.max_people, r.minutes_with_people, r.avg_confidence,
           r.first_seen_at, r.last_seen_at, r.out_of_zone_events, r.max_cattle_outside
      FROM daily_reports(assistant_account_id(), first_day, last_day, day_time_zone) AS r
$$;

REVOKE ALL ON FUNCTION assistant_daily_reports(date, date, text) FROM PUBLIC;

COMMENT ON FUNCTION assistant_daily_reports(date, date, text) IS
    'daily_reports() de la cuenta de la sesion. Es lo unico con SECURITY DEFINER: no acepta otra cuenta.';

-- El estado de conexion y las alertas viven en columnas y tablas que crea el
-- backend, asi que estas dos se saltan hasta que existan, como en 0012 y 0028.
DO $$
BEGIN
    IF to_regclass('v_camera_health') IS NULL THEN
        RAISE NOTICE 'v_assistant_cameras omitida: falta v_camera_health (migraciones del backend)';
        RETURN;
    END IF;

    CREATE OR REPLACE VIEW v_assistant_cameras WITH (security_barrier = true) AS
    SELECT h.id,
           coalesce(c.display_name, c.name) AS camera,
           h.location,
           h.active,
           h.effective_status AS status,
           h.last_report_at,
           h.last_online_at
      FROM v_camera_health h
      JOIN cameras c ON c.id = h.id
     WHERE c.account_id = assistant_account_id();
END $$;

DO $$
BEGIN
    IF to_regclass('security_alerts') IS NULL THEN
        RAISE NOTICE 'v_assistant_alerts omitida: falta security_alerts (migraciones del backend)';
        RETURN;
    END IF;

    CREATE OR REPLACE VIEW v_assistant_alerts WITH (security_barrier = true) AS
    SELECT a.id,
           coalesce(c.display_name, c.name) AS camera,
           a.alert_type,
           a.severity,
           a.status,
           a.message,
           a.created_at,
           a.acknowledged_at,
           a.resolved_at
      FROM security_alerts a
      JOIN cameras c ON c.id = a.camera_id
     WHERE c.account_id = assistant_account_id();
END $$;

-- Al final y en un solo sitio: las vistas de arriba pueden no existir todavia, y
-- el rol tampoco.
DO $$
DECLARE
    view_name text;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'smartcattle_assistant') THEN
        RETURN;
    END IF;

    FOREACH view_name IN ARRAY ARRAY['v_assistant_detections', 'v_assistant_events', 'v_assistant_cameras', 'v_assistant_alerts'] LOOP
        IF to_regclass(view_name) IS NOT NULL THEN
            EXECUTE format('GRANT SELECT ON %I TO smartcattle_assistant', view_name);
        END IF;
    END LOOP;

    GRANT EXECUTE ON FUNCTION assistant_daily_reports(date, date, text) TO smartcattle_assistant;
END $$;
