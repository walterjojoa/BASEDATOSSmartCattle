# Seguridad de los datos

Lo que esta tabla guarda y lo que pasa si se filtra.

## Lo que hay aqui que no debe salir

| Dato | Donde | Riesgo si se filtra |
| --- | --- | --- |
| `users.password_hash` | `users` | Con bcrypt, inservible por volumen. Con SHA sin salt, las cuentas se recuperan. |
| `users.email`, `full_name` | `users` | Datos personales del personal del predio. |
| `cameras.stream_url` | `cameras` | Acceso al video en vivo si la URL es publica. |
| La cadena de conexion | `.env`, Render | Acceso total a todo lo anterior. |

## Las reglas que ya estan puestas

### La contrasena nunca se guarda

`users.password_hash` guarda **bcrypt**. Es la decision mas importante de este
esquema y la mas facil de deshacer por comodidad.

SHA-256 se recorre a miles de millones de intentos por segundo en una GPU, asi
que un hash sin salt de una contrasena humana se revierte con una tabla.
bcrypt lleva salt por fila y un coste ajustable, y eso es lo que hace inviable
el ataque por volumen.

**Esta deuda esta abierta:** el frontend guarda hoy SHA-256 sin salt en
`localStorage` para su sesion de demostracion. Mientras la autenticacion real
no exista, esa es la que corre en el despliegue.

### `stream_url` no puede traer credenciales

El backend la rechaza si trae usuario y contrasena, porque la columna se
publica tal cual en `GET /api/cameras`. Una URL RTSP de la forma
`rtsp://usuario:clave@camara/stream` convertiria esa respuesta en una fuga.

Por lo mismo, `cameras.last_error` rechaza cualquier texto que contenga
`://`: un mensaje de error de la libreria de video suele incluir la URL que
fallo, con sus credenciales dentro.

### `source` si puede traerlas, y por eso no se publica

`cameras.source` es la configuracion real de captura y **si** puede ser una
URL RTSP con credenciales. No la expone ningun endpoint, y no debe exponerla
ninguno. Es la diferencia entre esa columna y `stream_url`.

### Las cuentas se desactivan, no se borran

`users.is_active` a `false`. Borrar la fila destruye el registro de quien tuvo
acceso, que es justo lo que hace falta al revisar un incidente.

## Lo que falta

- **Nada aplica los roles.** `users.role` registra `owner` o `worker`, y lo
  que cada uno puede hacer no se controla ni aqui ni en el backend. El
  frontend tiene `can(role, permission)` y su propio comentario advierte que
  es solo para la interfaz.
- **No hay bitacora de acceso.** `last_login_at` (migracion 0005) dice cuando
  fue el ultimo, no cuantos intentos fallaron ni desde donde.
- **No hay cifrado en reposo propio.** Lo da Neon a nivel de disco; esta base
  no cifra ninguna columna por separado.
