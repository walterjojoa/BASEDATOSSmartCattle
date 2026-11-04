-- 0030: cada camara pertenece a una cuenta, y su dueno le pone nombre.
--
-- account_id es el id en users del dueno de la cuenta: un trabajador comparte el
-- de su dueno, y por eso no se llama user_id. Son las columnas de la migracion
-- 0018_accounts del backend; da igual cual corra primero.
--
-- cameras.name sigue con su UNIQUE global: es el identificador que usan la API
-- y la IA, y el backend crea camaras con ON CONFLICT (name) DO NOTHING. Quitarlo
-- rompe esa ingesta. El nombre que elige la persona va en display_name.
--
-- account_id admite NULL: una camara que la IA reporta y nadie guardo no es de
-- nadie, y nadie la ve.

ALTER TABLE cameras ADD COLUMN IF NOT EXISTS account_id bigint;
ALTER TABLE cameras ADD COLUMN IF NOT EXISTS display_name text;

-- 0018_accounts la crea sin clave ajena. SET NULL: una cuenta borrada a mano deja
-- la camara sin dueno y conserva su historial.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'cameras_account_id_fkey') THEN
        ALTER TABLE cameras
            ADD CONSTRAINT cameras_account_id_fkey
            FOREIGN KEY (account_id) REFERENCES users (id) ON DELETE SET NULL;
    END IF;
END $$;

-- Consulta: las camaras de una cuenta, en cada pagina y en cada reporte.
--     SELECT ... FROM cameras WHERE account_id = $1
-- El nombre es el de 0018_accounts, para no dejar dos indices iguales.
CREATE INDEX IF NOT EXISTS ix_cameras_account_id ON cameras (account_id);

-- Una cuenta no repite nombre, sin distinguir mayusculas: "Corral" y "corral" se
-- confunden en un tablero. Una base en uso puede tener ya repetidos, y borrar o
-- renombrar los de alguien no le toca a una migracion. En ese caso avisa y sigue;
-- arreglados los nombres, volver a correrla crea el indice.
DO $$
DECLARE
    repeated bigint;
BEGIN
    IF to_regclass('cameras_account_display_name_key') IS NOT NULL THEN
        RETURN;
    END IF;

    SELECT count(*) INTO repeated FROM (
        SELECT 1 FROM cameras
         WHERE account_id IS NOT NULL AND display_name IS NOT NULL
         GROUP BY account_id, lower(display_name)
        HAVING count(*) > 1
    ) AS duplicates;

    IF repeated > 0 THEN
        RAISE WARNING 'cameras_account_display_name_key omitido: % nombres repetidos dentro de una cuenta. Ver docs/diccionario/cameras.md', repeated;
        RETURN;
    END IF;

    CREATE UNIQUE INDEX cameras_account_display_name_key
        ON cameras (account_id, lower(display_name))
        WHERE account_id IS NOT NULL AND display_name IS NOT NULL;
END $$;

COMMENT ON COLUMN cameras.account_id IS
    'Cuenta duena: el id en users de su dueno. NULL: la IA la reporta y nadie la guardo, asi que nadie la ve.';
COMMENT ON COLUMN cameras.display_name IS
    'Nombre que le dio su dueno, unico por cuenta. NULL mientras no este guardada. No confundir con name, el identificador global.';
