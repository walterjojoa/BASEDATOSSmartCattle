-- Cada cuenta tiene sus camaras y no repite nombre entre las suyas.
--
-- cameras.name sigue siendo unico en toda la base: la ingesta del backend usa
-- ON CONFLICT (name), y sin ese UNIQUE falla en cada evento.
BEGIN;

DO $$
DECLARE
    ana  bigint;
    luis bigint;
BEGIN
    INSERT INTO users (email, password_hash, full_name) VALUES ('t26-ana@x.co', 'h', 'Ana') RETURNING id INTO ana;
    INSERT INTO users (email, password_hash, full_name) VALUES ('t26-luis@x.co', 'h', 'Luis') RETURNING id INTO luis;

    INSERT INTO cameras (name, account_id, display_name) VALUES ('t26-a1', ana, 'Corral');
    INSERT INTO cameras (name, account_id, display_name) VALUES ('t26-a2', ana, 'Establo');

    -- Otra cuenta si puede llamarla igual.
    INSERT INTO cameras (name, account_id, display_name) VALUES ('t26-l1', luis, 'Corral');

    -- Una cuenta no puede repetirlo, ni cambiando mayusculas.
    BEGIN
        INSERT INTO cameras (name, account_id, display_name) VALUES ('t26-a3', ana, 'CORRAL');
        ASSERT false, 'una cuenta no deberia repetir el nombre de una camara';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;

    -- Camaras sin dueno o sin nombre no chocan entre si.
    INSERT INTO cameras (name) VALUES ('t26-n1'), ('t26-n2');
    INSERT INTO cameras (name, account_id) VALUES ('t26-a4', ana), ('t26-a5', ana);

    -- Quitarla del tablero libera el nombre, como hace el backend al olvidarla.
    UPDATE cameras SET display_name = NULL, active = FALSE WHERE name = 't26-a2';
    INSERT INTO cameras (name, account_id, display_name) VALUES ('t26-a6', ana, 'Establo');

    -- El identificador global sigue siendo unico.
    BEGIN
        INSERT INTO cameras (name, account_id) VALUES ('t26-a1', luis);
        ASSERT false, 'cameras.name deberia seguir siendo unico en toda la base';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;

    -- El ON CONFLICT que usa la ingesta del backend sigue funcionando.
    INSERT INTO cameras (name) VALUES ('t26-a1') ON CONFLICT (name) DO NOTHING;
    ASSERT (SELECT account_id FROM cameras WHERE name = 't26-a1') = ana,
           'la ingesta no deberia cambiar el dueno de una camara existente';

    -- No se puede apuntar a una cuenta que no existe.
    BEGIN
        INSERT INTO cameras (name, account_id) VALUES ('t26-x', -1);
        ASSERT false, 'account_id no deberia aceptar una cuenta inexistente';
    EXCEPTION WHEN foreign_key_violation THEN NULL;
    END;

    -- Borrar la cuenta deja la camara sin dueno, no la borra.
    DELETE FROM users WHERE id = luis;
    ASSERT (SELECT account_id FROM cameras WHERE name = 't26-l1') IS NULL,
           'cameras.account_id deberia quedar en NULL al borrar la cuenta';
END $$;

DO $$
DECLARE
    bad jsonb;
BEGIN
    INSERT INTO users (email, password_hash, full_name) VALUES ('t26-pref@x.co', 'h', 'P');
    ASSERT (SELECT preferences FROM users WHERE email = 't26-pref@x.co') = '{}'::jsonb,
           'preferences deberia empezar como un objeto vacio';

    FOREACH bad IN ARRAY ARRAY['[]'::jsonb, 'null'::jsonb, '1'::jsonb] LOOP
        BEGIN
            UPDATE users SET preferences = bad WHERE email = 't26-pref@x.co';
            ASSERT false, format('preferences no deberia aceptar %s', bad);
        EXCEPTION WHEN check_violation THEN NULL;
        END;
    END LOOP;
END $$;

ROLLBACK;
