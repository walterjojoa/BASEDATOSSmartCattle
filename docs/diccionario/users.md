# `users`

Las personas que usan el sistema. **Ningún servicio la consume todavía**: el
backend no tiene endpoints de autenticación y el frontend usa una sesión de
demostración en el navegador. La tabla existe para cuando los tenga.

| Columna | Tipo | NULL | Por qué |
| --- | --- | --- | --- |
| `id` | `BIGINT` identidad | no | |
| `email` | `TEXT` | no, `UNIQUE` | Con `CHECK (email = lower(email))`. Ver abajo. |
| `password_hash` | `TEXT` | no | Un hash **bcrypt**. Nunca la contraseña. |
| `full_name` | `TEXT` | no | |
| `role` | `TEXT` | no, `'worker'` | `owner` o `worker`. Indexada por `users_role_idx`. |
| `is_active` | `BOOLEAN` | no, `TRUE` | Se baja para retirar el acceso. |
| `created_at` | `TIMESTAMPTZ` | no, `now()` | |
| `updated_at` | `TIMESTAMPTZ` | no, `now()` | Lo refresca el trigger `users_updated_at_trg`, no la aplicación. |

## El `CHECK` de minúsculas sostiene al `UNIQUE`

El `UNIQUE` compara cadenas. Sin el `CHECK`, `Ana@finca.com` y `ana@finca.com`
son dos cadenas distintas y la misma persona se registra dos veces, cada una
con su contraseña. Peor: al iniciar sesión, cuál de las dos filas contesta
depende de cómo escribió el correo esa vez.

Normalizar en la aplicación no basta, porque hay más de un escritor. La regla
tiene que estar donde está el dato.

## `password_hash` guarda bcrypt, no SHA

Una tabla filtrada no debe entregar las cuentas que describe. SHA-256 se
recorre a miles de millones de intentos por segundo en una GPU, así que un
hash sin salt de una contraseña humana se revierte por tabla. bcrypt lleva
salt propio por fila y un coste ajustable, que es lo que hace inviable el
ataque por volumen.

Esto importa ahora mismo: el frontend hoy guarda **SHA-256 sin salt** en
`localStorage` para su sesión de demostración. Esa es la razón por la que esta
columna dice bcrypt — para que la autenticación real no herede el atajo de la
maqueta.

## `role` se registra aquí, no se aplica aquí

La columna dice si la persona es dueña o trabaja en el predio. Lo que cada rol
*puede hacer* no se controla en la base: lo tiene que exigir el backend. El
frontend ya tiene la función `can(role, permission)`, y su propio comentario
advierte que es sólo para la interfaz.
