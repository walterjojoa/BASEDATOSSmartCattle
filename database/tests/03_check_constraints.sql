-- Los CHECK que delimitan los valores validos siguen en su sitio.
DO $$
DECLARE
    missing text[];
    required text[] := ARRAY[
        'users_email_check',       -- email = lower(email)
        'users_role_check',        -- owner | worker
        'animals_status_check',    -- active | inactive | lost
        'events_level_check',      -- low | medium | high
        'events_source_check',     -- camera | image
        'events_confidence_check', -- 0..1
        'alerts_channel_check',
        'alerts_status_check'
    ];
BEGIN
    SELECT array_agg(name ORDER BY name) INTO missing
    FROM unnest(required) AS name
    WHERE NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = name AND contype = 'c'
    );

    ASSERT missing IS NULL, format('faltan CHECK: %s', missing);
END $$;

-- Y rechazan de verdad lo que dicen rechazar.
DO $$
BEGIN
    BEGIN
        INSERT INTO users (email, password_hash, full_name) VALUES ('Mayus@finca.com', 'x', 'x');
        ASSERT false, 'users acepto un correo con mayusculas';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    BEGIN
        INSERT INTO animals (tag, status) VALUES ('t-check', 'vendida');
        ASSERT false, 'animals acepto un status fuera de la lista';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
END $$;
