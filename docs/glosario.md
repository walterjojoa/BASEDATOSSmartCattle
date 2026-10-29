# Glosario

Los terminos que este repositorio usa con un significado preciso.

**arete** (*ear tag*) — El identificador fisico en la oreja del animal, y la
clave primaria de `animals`. No hay `id` numerico.

**zona segura** (*safe zone*) — El area de la que el ganado no deberia salir.
Un rectangulo en `zones` (`x_min..y_max`), opcionalmente un poligono
(`outline`). Coordenadas **de 0 a 1**, no pixeles.

**caja** (*box*, *bounding box*) — El rectangulo que la IA dibuja alrededor de
un objeto detectado: `events.box`, `[x1, y1, x2, y2]` **en pixeles**.
Normalizarla es dividir por `events.width` y `events.height`.

> La inconsistencia es real y vale la pena saberla: `zones` esta normalizado
> y `events.box` no. La zona se dibuja una vez y tiene que sobrevivir a un
> cambio de resolucion; la caja describe un cuadro concreto, del que se conoce
> la resolucion.

**evento** (*event*) — Una deteccion que disparo una regla. Hoy solo
`cattle_out_of_zone`. Fila en `events`.

**alerta** (*alert*) — El aviso que se manda **a raiz** de un evento. Fila en
`alerts`. Un evento puede producir varias: por correo y por WhatsApp son dos
filas.

**`detected_at`** — Cuando lo detecto la IA. Reloj del PC del predio.

**`received_at`** — Cuando lo recibio el backend. Reloj de Render. La
diferencia entre los dos es el diagnostico, no un dato redundante.

**estado efectivo** (*effective status*) — Lo que una camara esta, no lo que
dijo. `reported_status` es lo ultimo que reporto la IA; el estado efectivo
vence ese reporte a los 60 s. Lo calcula `v_camera_health` y el backend.

**desconocido** (*unknown*) — Una camara que existe como fila y que **nadie
reporto nunca**. No es `offline`: una esta averiada, la otra no esta
configurada.

**perdido** (*lost*) — Un animal que deberia estar y no aparece.
`animals.status = 'lost'`. No es `inactive`, que es una baja administrativa.

**enviada** vs **atendida** (*sent* / *handled*) — `sent` es que el mensaje
salio. `handled` es que **una persona hizo algo**. La diferencia entre
avisamos y alguien fue a ver la vaca.

**idempotente** — Que volver a hacerlo no cambia el resultado. Aplica a dos
cosas distintas aqui: las migraciones (volver a correrlas no falla ni
duplica) y la ingesta de eventos (un reintento con el mismo `ai_event_id` no
crea una segunda fila).

**fila ajena** — Una fila de `events` o `cameras` que escribio un servicio que
no es el backend. Suelen faltarle columnas que la API exige, y por eso
`v_api_events` las filtra.
