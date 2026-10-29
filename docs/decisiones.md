# Registro de decisiones

Las decisiones que ya se tomaron, con lo que se descarto y por que. Sirve para
no volver a discutirlas, y para poder cambiarlas sabiendo que se rompe.

## 1. El arete es la clave primaria de `animals`

**Decidido.** No hay `id` numerico.

Alternativa descartada: `id BIGINT` mas `tag TEXT UNIQUE`. Habria evitado el
`ON UPDATE CASCADE`, pero obliga a traducir entre dos identificadores en cada
consulta y a decidir en cada pantalla cual mostrar. El arete es la identidad
real: la que esta en la oreja del animal y la que usa el personal.

**Que cuesta:** una clave natural cambia. Un arete se cae y se repone, y sin
`ON UPDATE CASCADE` en `events.animal_tag` el historico quedaria apuntando a
un arete inexistente.

## 2. Nombres en ingles

**Decidido.** Tablas y columnas en ingles, igual que la API REST.

Se llego con una migracion que renombro todo, incluidos los valores
guardados (`'activo'` a `'active'`, `'ganado_fuera_zona'` a
`'cattle_out_of_zone'`). **Rompio a los tres servicios a la vez.**

**No se repite.** Cualquier cambio de nombre a partir de aqui se coordina con
el equipo antes de aplicarse.

## 3. `animals` no lleva datos zootecnicos

**Decidido.** Sin raza, sexo ni fecha de nacimiento. Estuvieron en el
planteamiento inicial y se quitaron.

SmartCattle rastrea el ganado **por seguridad**: donde esta y si salio de su
zona. No gestiona el hato ni su valoracion. Esos datos no ayudan a localizar
un animal ni a detectar que se escapo.

`name` si se conserva: el personal reconoce de que animal habla una alerta.

## 4. Los enumerados son `TEXT` con `CHECK`

**Decidido.** No tipos `ENUM` de PostgreSQL.

`ALTER TYPE` para agregar un valor no se puede ejecutar dentro de una
transaccion junto con otros cambios. Un `CHECK` se reemplaza en el mismo
`ALTER TABLE` que el resto de la migracion.

**Excepcion deliberada:** `events.type` no lleva `CHECK`. Los tipos de evento
los define el servicio de IA, que evoluciona aparte. El costo es que quien lee
tiene que filtrar los tipos que no conoce, y el backend lo hace.

## 5. `ai_event_id UUID UNIQUE` para la idempotencia

**Decidido.** La idempotencia de la ingesta la resuelve la base, no la
aplicacion.

Alternativa descartada: que el backend compruebe antes de insertar. Entre la
comprobacion y el `INSERT` cabe otro reintento, asi que dos retries
simultaneos crean dos filas. El `UNIQUE` no tiene esa ventana.

**Que cuesta:** admite `NULL` para no obligar a los demas servicios, y
PostgreSQL permite varios `NULL` bajo un `UNIQUE`. Las filas sin identificador
no estan protegidas, y nada puede distinguir ahi un reintento de dos
detecciones reales.

## 6. `detected_at` y `received_at` separados

**Decidido.** Dos columnas, dos relojes.

Alternativa descartada: un solo timestamp. Es mas simple y borra el
diagnostico: la diferencia entre los dos es lo que revela un reloj desfasado
en el PC del predio, y un valor negativo dice que va adelantado.

## 7. El poligono de zona va en `JSONB`, no en PostGIS

**Decidido.** `zones.outline JSONB`, validado por
`is_valid_zone_outline()`.

Neon no trae PostGIS en el plan gratuito, y para un poligono de cuatro a una
docena de vertices normalizados un indice espacial no aporta nada.

**Que cuesta:** la validacion hay que escribirla a mano, y `JSONB` acepta
cualquier forma sin el `CHECK`. La funcion tiene que ser `IMMUTABLE` para
poder usarse en un `CHECK`, y un `CHECK` no admite subconsultas, que es por lo
que la validacion no esta escrita directamente en la constraint.

## 8. El rectangulo se conserva junto al poligono

**Decidido.** `x_min..y_max` sigue existiendo con `outline`.

No es redundancia: es la caja envolvente, y permite descartar un punto barato
antes de la prueba del poligono. Mientras `outline` sea `NULL`, el rectangulo
manda.

## 9. Las migraciones son idempotentes

**Decidido.** `IF NOT EXISTS` donde exista; un bloque `DO` que consulta el
catalogo donde no.

Alternativa descartada: una tabla de versiones propia, como la
`alembic_version` del backend. Varios servicios comparten esta base y ninguno
es dueno del esquema, asi que una tabla de versiones tendria un solo escritor
autorizado y no lo hay. Que todo se pueda volver a correr resuelve el mismo
problema sin ese supuesto.

## 10. No hay control de roles aqui

**Decidido.** `users.role` registra `owner` o `worker`; lo que cada uno puede
hacer lo tiene que exigir el backend.

Alternativa descartada: row-level security de PostgreSQL. Exige que cada
servicio se conecte con el rol del usuario final, y los tres se conectan con
una sola cadena de conexion de servicio.
