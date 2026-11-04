-- 0029: preferencias de cada usuario.
--
-- JSONB y no una columna por preferencia: las define el frontend (idioma, zona
-- horaria, tema) y cambian sin tocar el esquema. Ninguna consulta filtra por
-- ellas, asi que no lleva indice.
--
-- NOT NULL con DEFAULT: los escritores actuales no la conocen y siguen
-- insertando igual. El CHECK evita que un '[]' o un 'null' de JSON obliguen a
-- cada lector a comprobar la forma antes de leer una clave.

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS preferences jsonb NOT NULL DEFAULT '{}'::jsonb;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'users_preferences_is_object_check') THEN
        ALTER TABLE users
            ADD CONSTRAINT users_preferences_is_object_check
            CHECK (jsonb_typeof(preferences) = 'object');
    END IF;
END $$;

COMMENT ON COLUMN users.preferences IS
    'Preferencias de la interfaz, siempre un objeto JSON. Nunca secretos: se devuelve tal cual al navegador.';
