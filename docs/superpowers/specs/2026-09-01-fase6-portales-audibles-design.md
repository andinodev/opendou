# Fase 6 — Los portales se oyen

**Fecha:** 2026-09-01
**Estado:** Implementada. Este documento lleva al final las correcciones que la ejecución obligó a hacerle.
**Rama:** `main` (este proyecto trabaja en una sola rama)
**Godot verificado:** 4.7.2.stable.official.ed1daf0bf
**Fases anteriores:** [1](2026-09-01-fase1-cadena-audio-real-design.md) · [2](2026-09-01-fase2-correccion-espacial-design.md) · [3](2026-09-01-fase3-rendimiento-design.md) · [4A](2026-09-01-fase4a-distribuible-design.md) · [5](2026-09-01-fase5-demos-design.md)

---

## 1. Contexto

Al probar «Bajo la quilla» apareció que pulsar **E** —la tecla que cierra la escotilla—
no producía ningún cambio audible. La causa no es la tecla.

`SpatialAcousticsManager.calculate_acoustic_path()` recorre el grafo de salas y portales
y devuelve la distancia virtual del camino, el corte acumulado y el origen aparente del
sonido. Está implementado, tiene tests, y **se invoca únicamente desde los tests**:

```
$ grep -rn 'calculate_acoustic_path' --include='*.gd' addons/ tests/ | grep -v spatial_acoustics_manager
tests/test_spatial_acoustics.gd:30
tests/test_spatial_acoustics.gd:41
tests/test_spatial_acoustics.gd:57
tests/test_declarative_nodes.gd:274
```

`AudioEventManager._process()` no lo llama en ninguno de sus ocho pasos. **Salas,
portales, difracción de portal y acoplamiento entre salas están calculados y son inertes
en la cadena de audio.** Es la feature de cabecera de un middleware espacial y no hace
nada.

Y la aserción que la Fase 5 escribió para la escotilla afirmaba que
`get_diffraction_lpf()` devolvía otro número. Es una aserción de propiedad: comprobaba
que un cálculo cambiaba, no que el sonido cambiara. Es el mismo defecto que esa fase
persiguió cinco veces en tests ajenos, cometido en uno propio.

**Observación 35.**

---

## 2. Qué se aplica a la cadena de audio

El grafo devuelve tres cosas por voz. Se aplican **las tres**:

| Dato del grafo | Cómo se aplica | Qué se oye |
|---|---|---|
| `accumulated_lpf` | Va a `target_spatial_lpf`, que ya existe y ya se suaviza | Cerrar la escotilla apaga los agudos |
| `virtual_distance` | Atenuación en dB por el tramo que Godot no ve | Rodear cuesta volumen |
| `apparent_origin` | Sustituye la posición que se pasa al canal físico | El sonido viene **de la escotilla**, no de atrás del mamparo |

El origen aparente es lo que perceptualmente significa «suena a través del portal», y el
dato ya está calculado, así que cuesta lo mismo que aplicar solo el filtro.

### La atenuación, con precisión

Con el origen aparente en el portal, Godot atenúa por la distancia **oyente → portal**.
El tramo **emisor → portal** no lo ve nadie. La compensación es la pérdida por
distancia de la diferencia:

```
extra_db = -20 * log10(virtual_distance / dist(apparent_origin, listener))
```

Siempre negativa o cero, porque el camino completo nunca es más corto que su último
tramo. Se acota a un suelo de −40 dB para que un camino larguísimo no deje la voz en
silencio absoluto de golpe.

**El divisor necesita un suelo.** Si el oyente se planta justo en el portal, la
distancia oyente → portal tiende a cero y la fórmula tiende a −infinito: la voz se
apagaría del todo en el momento exacto en que debería oírse mejor. El divisor se acota
por debajo a **0.5 m**, que es el orden del tamaño de la cabeza y por debajo del cual la
atenuación por distancia ya no significa nada.

### El origen aparente se mueve suavizado

Al cruzar la escotilla, la posición aparente pasa del portal al emisor real. Si salta,
se oye el chasquido del paneo. Se interpola con limitación de pendiente, igual que ya se
hace con el filtro de oclusión.

---

## 3. Quién gobierna cada voz

Oclusión por raycast y camino por portales describen el mismo mamparo. Sumarlos cobra
dos veces por la misma pared y suena a barro.

**Regla:** si el emisor y el oyente están en **salas distintas**, el camino por portales
gobierna esa voz y la oclusión no la toca. Si están en la misma sala —o si alguno no
está en ninguna sala registrada— gobierna la oclusión y el grafo no interviene.

Cada mecanismo manda donde sabe más. El grafo sabe que hay un mamparo y por dónde se
rodea; el raycast sabe qué hay entre dos puntos de una misma sala.

**Un efecto secundario que conviene:** las voces gobernadas por el grafo **no necesitan
raycast**, así que el presupuesto de raycasts de la Fase 3 alcanza para más voces de las
que sí lo necesitan.

---

## 4. El coste, medido antes de diseñar

La preocupación es legítima: esto corre en el frame de un jugador. Todo lo de abajo está
medido en la máquina de desarrollo (macOS, headless, GDScript), no estimado.

| Qué | Coste |
|---|---|
| Bucle actual de OpenDou, por voz y frame | **3.9 µs** |
| Bucle actual con 200 voces | **0.77 ms/frame** (4.6 % de un frame a 60 fps) |
| `get_room_at_position()` | 0.41 µs |
| `calculate_acoustic_path()`, 1 portal | 2.87 µs |
| `calculate_acoustic_path()`, 2 portales | 4.04 µs |

**La versión ingenua es inaceptable y hay que decirlo:** evaluar el camino por voz y por
frame costaría 200 × ~3.9 µs = **0.78 ms**, que **duplica el coste completo del motor**.

Dos decisiones lo bajan dos órdenes de magnitud:

**Solo las voces físicas.** Una voz virtual no suena: calcular su filtro es trabajo
tirado. El valor se necesita en el instante en que se vuelve física, y ahí se calcula
una vez. Eso pasa de 200 candidatas a 32.

**Caché por par de salas.** El recorrido depende del par (sala del emisor, sala del
oyente) y del estado de los portales, no de la posición exacta de cada voz. Con tres
salas hay como mucho nueve pares y en la práctica dos o tres.

| Variante | Coste añadido |
|---|---|
| Ingenua: 200 voces × recorrido propio | 0.78 ms — **+100 %** |
| Solo físicas: 32 × recorrido propio | 0.125 ms — +16 % |
| **Solo físicas + caché** | **~0.025 ms — +3 %** |

### Cómo se invalida la caché

Una vez por frame se calcula un **digest** de los `open_factor` de todos los portales.
Si cambia respecto al frame anterior, la caché se limpia entera. Es O(P) por frame con P
portales —no por voz—, y cubre también el caso de que se abra un portal que no estaba en
ningún camino cacheado y que ahora crea uno más corto. La caché se limpia además al
registrar una sala o un portal nuevos.

Con esto, pulsar E surte efecto en el frame siguiente y la validación no cuesta nada por
voz.

### El techo real de este plugin

A 3.9 µs por voz y frame: mantener el audio por debajo de 1 ms son **~256 voces**; por
debajo de 2 ms, **~512**. En una máquina 3–5× más lenta esas cifras se dividen por
igual.

**Se escribe aquí porque el proyecto no lo tenía anotado en ninguna parte.** «Cientos de
voces» se sostiene con margen. «Miles» no, y no debe afirmarse en la documentación. Y el
techo no lo pone el grafo de portales: lo pone que el motor sea GDScript.

---

## 5. Arquitectura

Una pieza nueva, `OpenDouRoomPathDispatcher`, y un paso nuevo en el bucle de frame.

Sigue los dos precedentes que el motor ya tiene: `OpenDouOcclusionScheduler` (Fase 3) y
`OpenDouReflectionDispatcher` (Fase 1). Se descartaron dos alternativas: meterlo dentro
del planificador de oclusión —mezcla dos responsabilidades y su presupuesto está
expresado en raycasts, que esto no necesita— y calcularlo en
`EventInstance.update_parameters()` —un recorrido por instancia y por frame, que es
justo el coste que la Fase 3 quitó—.

### Componentes

| Componente | Responsabilidad |
|---|---|
| `OpenDouRoomPathDispatcher` (nuevo) | La caché por par de salas, su digest de invalidación, el conteo de recorridos y la traducción camino → valores de voz |
| `EventInstance` | Tres campos nuevos: `room_path_active`, `target_apparent_position`, `current_apparent_position` |
| `AudioEventManager` | Un paso nuevo en `_process()`, antes de la oclusión |
| `OpenDouOcclusionScheduler` | Excluye de sus candidatas las instancias con `room_path_active` |
| `SpatialAcousticsManager` | Sin cambios. Ya expone todo lo necesario |

### El paso en el bucle

Va **antes** de la oclusión, para que la oclusión pueda saltarse las voces gobernadas y
no gastar raycasts en ellas.

1. Resolver el oyente *(ya existe)*
2. Live Update *(ya existe)*
3. Game Syncs *(ya existe)*
4. **Camino por salas y portales** ← nuevo
5. Oclusión presupuestada *(ya existe, ahora salta las gobernadas)*
6. Parámetros de instancia y limpieza *(ya existe)*
7. Ventana HDR *(ya existe)*
8. Voice stealing *(ya existe)*
9. Aplicar a los reproductores *(ya existe, ahora usa la posición aparente)*
10. Reflexiones y telemetría *(ya existe)*

### Flujo de datos

El dispatcher recibe las instancias activas y la posición del oyente. Resuelve la sala
del oyente **una vez**, no por voz. Para cada instancia **física** con posición
espacial, resuelve su sala y:

- Si la sala coincide con la del oyente, o alguna es vacía: `room_path_active = false`,
  `target_apparent_position = emitter_position`. El grafo no toca nada más.
- Si difieren: pide el camino a la caché, y de ahí salen el corte del filtro, la
  atenuación en dB y el origen aparente. `room_path_active = true`.

`_apply_voices()` pasa al canal `current_apparent_position` en lugar de
`emitter_position`. Cuando una voz deja de estar gobernada, su posición aparente
interpola de vuelta a la real, así que la transición al cruzar el portal es continua sin
ramas en el código de aplicación.

---

## 6. Casos límite

| Situación | Comportamiento |
|---|---|
| Ninguna sala registrada | Cero recorridos, cero coste, nada cambia. Es el caso de «El monzón», que **no debe verse afectada** |
| Emisor y oyente en la misma sala | Gobierna la oclusión; el grafo no interviene |
| Emisor u oyente fuera de toda sala | Gobierna la oclusión |
| Dos salas sin camino de portales | El grafo ya devuelve su fallback sellado de 200 Hz, que es lo correcto para un mamparo cerrado |
| Voz no espacial (música, radio, UI) | Excluida: `has_spatial_position == false` |
| Voz virtual | Excluida. Se calcula al volverse física |

No hay flag de opt-in por evento. Las voces que no deben verse afectadas ya quedan
fuera por las reglas de arriba, así que un flag sería configuración que nadie tocaría.

---

## 7. Verificación

**Tres aserciones de audio real** que sustituyen a la de propiedad de la Fase 5. Las
tres con `OpenDouAudioProbe` sobre un bus medido:

1. Válvula en la sala de máquinas, oyente en el pasillo, escotilla **abierta**: el pico
   medido es alto.
2. Misma geometría, escotilla **cerrada**: el pico cae **al menos a la mitad**. Se
   escribe el umbral en lugar de «cae de forma medible» para que la aserción no pueda
   pasar con una caída de ruido de fondo.
3. Emisor y oyente en la **misma sala**: cerrar la escotilla deja el pico **dentro de un
   ±20 %** del que había con la escotilla abierta. Es la aserción que prueba que el
   grafo no gobierna donde no debe, y sin ella las dos primeras podrían pasar con una
   implementación que apagara todo indiscriminadamente.

**Dos aserciones de la posición aparente:**

4. Con la escotilla abierta y el oyente en el pasillo, la posición que llega al canal
   está **más cerca del portal que del emisor**.
5. Con el oyente en la misma sala que el emisor, la posición que llega al canal **es la
   del emisor**.

**Dos guardas de coste que cuentan trabajo, no milisegundos.** Un test de tiempo sería
frágil entre máquinas; un conteo es determinista:

6. Con 200 emisores y tres salas, `traversals_this_frame` **nunca supera el número de
   pares de salas distintos**. Es lo que protege contra que la versión ingenua vuelva a
   colarse.
7. Con 200 emisores y **ninguna sala registrada**, `traversals_this_frame` es **cero**.

**Una de no regresión:**

8. Cambiar el `open_factor` de un portal invalida la caché: el recorrido siguiente
   devuelve un corte distinto sin necesidad de reiniciar nada.

---

## 8. Criterios de aceptación

1. Pulsar **E** en «Bajo la quilla» produce un cambio **audible** en el silbido de la
   válvula oído desde el pasillo.
2. Las ocho aserciones del apartado 7 pasan.
3. La aserción de propiedad de la Fase 5 sobre `get_diffraction_lpf()` **se sustituye**
   por las de audio real. No se conserva «por si acaso»: afirmaba algo que no importaba.
4. «El monzón» no cambia de comportamiento ni de coste: no tiene salas registradas.
5. El coste añadido con 200 emisores y tres salas se mide y se anota en el commit. Si
   supera el **+10 %** sobre el bucle actual, la implementación está mal y hay que
   revisar la caché antes de seguir.
6. La suite sigue en verde con cero `SCRIPT ERROR`, fugas no superiores al techo y el
   árbol de git limpio.
7. El techo de voces medido queda escrito en `AGENTS.md`, junto a las demás trampas del
   motor.

---

## 9. Fuera de alcance

- **El acoplamiento de reverb entre salas** (`reverb_send_factor` de
  `evaluate_acoustic_path`): que un sonido de otra sala alimente el reverb de la sala del
  oyente a través del portal. Es una feature distinta, con su propia superficie de
  riesgo sobre los buses de reverb del pool, y merece su fase.
- **La difracción por aristas** (`EdgeDiffractionEngine`), que es otro subsistema
  igualmente inerte. Se anota como observación aparte; no se toca aquí.
- Optimizar el bucle actual para bajar de 3.9 µs por voz. Es trabajo real y no es este.

---

## 10. Riesgos

| Riesgo | Mitigación |
|---|---|
| La posición aparente pelea con el reverb nativo por área, que depende de dónde crea Godot que está el reproductor | La aserción 3 lo detecta: si el reverb se descuadra, el pico en la misma sala cambia cuando no debería |
| El suavizado de la posición aparente enmascara el efecto en los tests | Los tests esperan a que el suavizado converja, no cuentan frames fijos |
| La caché devuelve un camino obsoleto | El digest por frame cubre cualquier cambio de portal, incluido uno que cree un camino más corto |
| El coste real en máquina lenta | El techo queda escrito; el conteo de recorridos es la guarda que no depende de la máquina |


---

## 11. Correcciones que la ejecución obligó a hacer a este spec

Se dejan aquí en lugar de reescribir el documento, para que se vea qué se supuso mal.

**«`SpatialAcousticsManager` — sin cambios» era falso.** Cambió, y hubo que cambiarlo para
que la fase funcionara en cualquier proyecto real, no solo en el test:

* **Observación 38 — las salas y los portales nunca se desregistraban.** `rooms` y
  `portals` solo crecían: ni `OpenDouRoom3D` ni `OpenDouPortal3D` tenían `_exit_tree`. Un
  juego que carga y descarga niveles acumula salas muertas para siempre, y una sala
  muerta que envuelva el nivel nuevo **tapa todas sus salas**. Lo delató una sala de
  30×12×30 que un test dejaba registrada y que se comía la nave entera de «Bajo la
  quilla». Ahora los dos nodos se dan de baja, y dar de baja una sala se lleva los
  portales que la tocaban.
* **Observación 39 — `get_room_at_position()` devolvía la primera coincidencia**, así que
  con salas anidadas —un hangar que contiene oficinas— el resultado dependía del orden de
  inserción del diccionario. Ahora gana la más pequeña, que es la más específica.

**El apartado 7 prometía tres aserciones de audio real en la suite. No se pudieron
sostener ahí.**

* **Observación 40 —** `OpenDouAudioProbe.teardown()` borra su bus, `remove_bus()`
  desplaza los índices, y Godot resuelve el bus de una voz **por índice** al arrancar la
  reproducción: borrar un bus mientras algo suena reenruta esa voz. La comparación de
  picos fallaba entre una y tres corridas de cada cinco con picos de 5 a 9 sobre una señal
  que no pasa de 0.12. Se intentaron cuatro arreglos —drenar durante las esperas,
  silenciar el autoload, no borrar nunca los buses (rompe doce aserciones ajenas) y
  cambiar el orden de ejecución (lo empeora)—.
* **Lo que quedó:** en la suite, las aserciones deterministas de lo que llega al
  **mezclador** —el corte que Godot aplica, el origen aparente, y quién gobierna cada
  voz—, más la de misma sala que impide que pasen con una implementación que apague todo.
  La verificación **audible** vive en `tools/verify_portal_audio.gd`, aislada y estable:
  **0.1196 con el portal abierto y 0.0010 cerrado, una caída de 114×**.

**El coste medido, y lo que costó cumplirlo.** El criterio 5 fijaba un techo del +10 %. La
primera implementación daba **+17 %**: recorría las 200 instancias para atender a las 16
físicas. Iterar los canales del pool y sustituir la clave de caché de texto por un
diccionario anidado lo dejaron en **+8.5 %, 0.093 ms** con 200 voces y tres salas
—medianas de tres pares de 60 iteraciones—.

**Una limitación conocida que no estaba prevista.** El origen aparente **no se aplica a
los emisores de nodo** (`OpenDouEventPlayer*`): `PhysicalVoiceChannel.apply()` no mueve un
reproductor que pertenece a un nodo, y moverlo significaría mover el nodo del juego. Para
esos emisores llegan el filtro y la atenuación, pero no la relocalización. Las voces del
pool sí la reciben.

**Y una observación más, sin arreglar:** la observación 37, espejo de la 31 —`is_looping =
true` no loopea si el `AudioStreamWAV` no trae `loop_mode`, y la instancia muere tras una
pasada—.
