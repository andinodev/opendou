# Directrices para Asistentes de IA (AGENTS.md)

Este documento es la **fuente única de verdad** para el comportamiento, arquitectura, gestión de tareas y desarrollo asistido por IA en el proyecto **OpenDou**.

---

## 1. Filosofía y Reglas Fundamentales de Operación

1. **Cero Asunciones Críticas:**
   * Si un requerimiento es ambiguo, impacta la arquitectura o introduce dependencias pesadas, documenta las alternativas o consulta antes de realizar cambios destructivos.
2. **Modelo Lingüístico Híbrido:**
   * **Español:** Comunicación con el usuario, definición de reglas, gestión de tareas en `docs/tasks/` y notas operativas.
   * **Inglés:** Nombres de variables/clases/funciones en el código, arquitectura técnica (`docs/architecture/`), especificaciones (`docs/specs/`) y comentarios de código público.
3. **Desarrollo Guiado por Calidad (TDD / Verificación Continua):**
   * Todo módulo, adaptador o función debe contar con casos de prueba o plan de verificación reproducible antes de considerarse completada.
4. **Diseño Modular y Desacoplado:**
   * Separar la lógica pura (reglas del motor/audio) de los adaptadores del motor Godot y de las capas visuales/UI.
5. **Construcción Declarativa de Escenas (`.tscn`):**
   * Toda escena (demos, sandbox, herramientas) DEBE construirse como un archivo `.tscn` con sus nodos 3D/2D, UI, cámaras, luces y componentes montados visualmente en el árbol de escenas.
   * Los scripts `.gd` deben reservarse para la lógica de control, reactividad y conexión de señales, evitando la generación procedimental manual de interfaces completas por código.

---

## 2. Flujo de Gestión de Tareas

Toda tarea debe seguir este ciclo estricto a través de `docs/tasks/`:

```text
[ docs/tasks/backlog.md ] ──▶ [ docs/tasks/current.md ] ──▶ [ docs/tasks/completed.md ]
     (Planificada)                  (En ejecución)                  (Verificada)
```

### Protocolo:
* **Al iniciar:** Mover la tarea de `backlog.md` a `current.md`, asegurando que cuente con *Criterios de Aceptación (Definition of Done)* claros.
* **Durante el desarrollo:** Marcar pasos con checklists `[ ]` / `[x]`.
* **Al finalizar:** **OBLIGATORIO:** Ejecutar `powershell -ExecutionPolicy Bypass -File .\run_tests.ps1` (o `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`) y confirmar que todos los tests pasen al 100% (código de salida 0, sin errores ni advertencias de compilación/parseo). Solo entonces actualizar la documentación relevante y mover la tarea a `completed.md`. Si algún test o parseo falla, se debe corregir y verificar antes de continuar.

---

## 3. Registro de Decisiones de Arquitectura (ADRs)

Cuando se tome una decisión que afecte:
* Elección de lenguajes (GDScript vs C++ GDExtension vs Rust).
* Protocolos de red, sincronización o serialización de estados.
* Estructuras de datos centrales de cartas, mazos o reglas.

**Se DEBE crear un ADR** en `docs/decisions/` siguiendo la plantilla `docs/templates/template_adr.md` y numerado correlativamente (ej. `0002-nombre-decision.md`).

---

## 4. Estructura de Directorios

```text
opendou/
├── .agents/rules/          # Reglas modulares detalladas (estilo, arquitectura, workflow)
├── AGENTS.md               # Este archivo (reglas generales)
├── GEMINI.md               # Compatibilidad con herramientas de Gemini
├── README.md               # Portada del proyecto y guía de inicio
├── docs/                   # Documentación centralizada
│   ├── architecture/       # Diseño técnico y subsistemas (EN)
│   ├── specs/              # Especificaciones funcionales y de módulos (EN)
│   ├── decisions/          # Architecture Decision Records (ADRs)
│   ├── tasks/              # Gestión de tareas (ES) (roadmap, current, backlog, completed)
│   └── templates/          # Plantillas estándar para ADRs, specs y tareas
├── addons/opendou/         # Plugin distribuible para Godot 4.x
│   ├── plugin.cfg          # Configuración del plugin
│   └── plugin.gd           # Entrypoint en el editor de Godot
└── tests/                  # Pruebas unitarias y de integración
```

---

## 5. Ejecutar los tests (obligatorio antes de dar algo por hecho)

Usa **siempre** `./run_tests.sh` (macOS/Linux) o `run_tests.ps1` (Windows). No
invoques Godot a mano: el runner hace tres comprobaciones que la suite por si
sola no hace, y sin ellas es posible reportar exito con el motor roto.

1. **`SCRIPT ERROR` y `Parse Error` son fatales.** En GDScript una llamada a un
   metodo inexistente emite error, aborta la funcion que la contiene y devuelve
   `null`. Un test puede por tanto reportar PASSED mientras el motor grita: asi
   convivieron durante 58 tareas un "337/337 PASSED" con cinco defectos reales.
2. **Trinquete de fugas de ObjectDB.** El techo vive en `tests/leak_budget.txt`
   con su justificacion escrita. Si sube, investiga antes de tocar el numero:
   cada subida de esta fase delato fugas preexistentes (399 objetos en total).
3. **Regeneracion de la cache de clases.** Un `class_name` recien anadido **no
   existe como tipo global** hasta que Godot regenera
   `.godot/global_script_class_cache.cfg`, y sin editor eso solo ocurre al
   importar. Anotar un tipo nuevo antes de eso produce `Parse Error: Could not
   find type ... in the current scope`, tumba la compilacion de toda la suite y
   deja a Godot colgado. El runner compara los `class_name` declarados con los
   que la cache conoce e importa solo si falta alguno.

Nota para evitar un diagnostico equivocado: las funciones **estaticas con
`await` y tipo de retorno propio funcionan correctamente entre scripts**. Si una
falla al compilar, la causa es el punto 3, no la corrutina.

Aserciones de audio: no cuentes frames fijos para afirmar silencio. En headless
el bucle corre a maxima velocidad, asi que los frames no son proporcionales al
tiempo de audio. Usa `OpenDouAudioProbe.await_silence()`. Y ojo con sus valores
por defecto: cuatro frames seguidos bajo umbral los cumple un stinger con un
bache momentaneo de amplitud sin haber terminado. Sube `consecutive` cuando midas
contra una cola musical.

Una asercion de audio puede pasar sin probar lo que dice. Dos casos reales de
esta fase: comparar los **picos** de dos pisadas no prueba que cambiara el
material, porque el `AudioRandomContainer` aplica jitter de tono y volumen y dos
pisadas cualesquiera dan picos distintos; y comparar el pico de un bus antes y
despues de un trueno no prueba el ducking cuando 120 instancias rotan por 16
voces, porque el pico fluctua solo. **Muta el codigo y comprueba que la asercion
falla.** Si no falla, no afirma lo que crees.

---

## 5b. Trampas del motor descubiertas en la Fase 5

Diez defectos que no estaban entre las 24 observaciones iniciales. Estan
arreglados, con aserciones; se listan porque el patron se repite.

**Cosas que parecian funcionar y no sonaban:**

* `set_max_physical_voices()` sustituia el pool entero sin pasarle los
  reproductores: el motor se quedaba **mudo**. Era la llamada mas obvia al
  arrancar un juego.
* `play_event()` no detenia la voz anterior del mismo nodo, y la vieja le ganaba
  a la nueva por el bonus de histeresis: **dos disparos seguidos del mismo emisor
  dejaban muda la segunda**.
* Dos canales podian apuntar al mismo reproductor de nodo, y el primero al
  terminar paraba el audio del segundo.
* `OpenDouAnimationSync` creaba su **propio** `AudioEventManager` huerfano en
  `_ready()`: no estaba conectado al autoload, asi que sus `set_switch` no
  llegaban a nadie.

**Cosas que no paraban ni terminaban:**

* `stop_all()` no paraba nada: `EventInstance.stop()` ponia
  `assigned_channel_id = -1` sin pasar por `virtualize()`, asi que el canal
  seguia ocupado y el reproductor sonando -para siempre si el evento era un
  bucle-.
* `AudioEventDef.is_looping = false` **es una mentira si el `AudioStreamWAV` trae
  `loop_mode = LOOP_FORWARD`**, y varios de los sintetizados lo traen. El
  reproductor no emite `finished` jamas. Hoy el reloj logico del motor lo corta a
  `stream_length`, pero al autorar conviene mirar el `loop_mode` del stream.

**Trampas de API que hay que conocer antes de escribir una escena:**

* `post_event(def, caller)` hace que el transform del `caller` sea **autoritativo
  cada frame**: no se puede postear con caller y luego colocar el sonido en otro
  sitio con `set_position()`. Para posicion propia, `caller = null`.
* `OpenDouAcousticGeometryBake` recolecta `MeshInstance3D`, **no cuerpos**. Un
  `StaticBody3D` en el grupo produce un bake de **cero triangulos sin un solo
  aviso**.
* El HDR solo alcanza a las voces que pasan por el pool. Los nodos emisores
  nativos con `autoplay` suenan por su cuenta y **no se duckean**.
* `AudioEventDef.max_instances` no lo hace cumplir nadie: es un boton de autoria
  que no hace nada.
* Un literal de array sin tipar asignado a un `Array[Vector3]` -`waypoints`,
  `emission_points`- **aborta con error de tipo en tiempo de ejecucion**. Usa un
  local tipado.
* Los datos JSON del addon tienen **override de proyecto**:
  `res://opendou_<nombre>.json` gana a `addons/opendou/data/<nombre>.json`.
  Editar el default del addon no tiene efecto si existe el override.
* El proyecto **solo tiene el bus `Master`**: no hay `default_bus_layout.tres`.
  Crea los buses que necesites con `DemoAudio.ensure_bus()` y **no los destruyas
  nunca**, porque `AudioServer.remove_bus(i)` desplaza los indices siguientes.

**El techo de voces, medido (Fase 6).** El bucle de OpenDou cuesta **3.9 µs por voz y
frame** en la máquina de desarrollo. Mantenerlo por debajo de 1 ms son **~256 voces**;
por debajo de 2 ms, **~512**. En una máquina 3–5× más lenta esas cifras se dividen
igual. «Cientos de voces» se sostiene con margen; **«miles» no, y no debe afirmarse en
la documentación.** El techo no lo pone ninguna feature: lo pone que el motor sea
GDScript.

Antes de añadir trabajo por voz y por frame, mídelo. Las tres reglas que salieron de la
Fase 6, con lo que costó cada una:

* **Solo las voces físicas.** Una voz virtual no suena, así que calcular su filtro es
  trabajo tirado. Y no basta con saltárselas dentro del bucle: **recorrer** las 200
  instancias para atender a 16 costaba un 17 %. Itera los canales del pool.
* **Cachea por lo que de verdad varía**, no por voz. El recorrido del grafo de salas
  depende del par de salas, no de la posición de cada emisor.
* **No formatees cadenas por voz y por frame.** Una clave de caché `"%s|%s"` con 16
  voces se notaba en el presupuesto. Un diccionario anidado no cuesta nada.

Juntas bajaron el paso del grafo de salas de un **+100 %** a un **+8.5 %** (0.093 ms con
200 voces y tres salas).

**Trampas nuevas de la Fase 6:**

* **Las salas y los portales NO se desregistraban** hasta la Fase 6. Si escribes un nodo
  que se registra en un manager global, dale su `_exit_tree`: un juego que carga y
  descarga niveles acumulaba salas muertas, y una sala muerta que envuelva el nivel nuevo
  **tapa todas sus salas**.
* **`AudioEventDef.is_looping = true` no loopea si el WAV no loopea.** El reproductor
  emite `finished` y la instancia muere tras una pasada. Es el espejo de la trampa
  contraria, ya documentada. Mira siempre el `loop_mode` del stream.
* **Borrar un bus de audio reenruta lo que esté sonando.** `AudioServer.remove_bus(i)`
  desplaza los índices siguientes, y Godot resuelve el bus de una voz **por índice** al
  arrancar la reproducción. Dentro de una suite que crea y borra buses, las mediciones
  por bus se contaminan entre sí: por eso la verificación audible de los portales vive
  aislada en `tools/verify_portal_audio.gd` y no en la suite.
* **Matar un Godot headless a media ejecución puede reescribir `project.godot`** sin sus
  secciones `[autoload]` ni `[editor_plugins]`, que deja el plugin muerto. Si matas una
  corrida, mira `git status` antes de seguir.

**Observaciones y trampas de la Fase 7 (Steam Audio):**

* **Observación 42.** `AudioStreamPlayer3D` aplica por distancia un *high-shelf* cuyo corte
  es `attenuation_filter_cutoff_hz` y cuya profundidad es
  `(1 − min(1, multiplicador)) × attenuation_filter_db`. OpenDou escribía en ese corte el de
  oclusión (20 kHz sin oclusión) y anulaba el oscurecimiento por distancia. Ahora se escribe
  el mínimo de los dos. Limitación del backend `godot` que queda: a menos de `unit_size` la
  profundidad es 0 y una voz ocluida no se filtra; el backend nativo no la tiene.
* **Observación 43.** El test de «Una casa canta» falla de forma intermitente (una de cada
  varias corridas) con el origen aparente en la puerta cerrada en lugar de la ventana:
  una carrera entre la puerta poniendo su `open_factor` a cero en `_ready` y el despachador
  de caminos. Pendiente de arreglar; si te sale, repite la corrida antes de buscar culpables.
* **Observación 44.** `AudioStreamPlayer3D.new()` nace con `area_mask = 0`: no encuentra
  ningún `Area3D` y no alimenta ningún bus de reverb. Las voces anónimas del pool nunca
  habían tenido reverb de sala; el pool fija la máscara a 1.
* **Un reproductor 3D no emite nada sin oyente en el viewport** (medido: 0.0000 sin cámara,
  0.91 con ella). Un test que reproduzca por un `AudioStreamPlayer3D` pone una `Camera3D`.
* **El shelf de Godot aplica el doble de decibelios de los pedidos** (`AudioFilterSW`
  HIGHSHELF usa la ganancia lineal donde el «cookbook» usa su raíz). El DSP nativo lo replica
  a propósito, por paridad.
* **La API C de Steam Audio no renderiza el ITD** (fase plana por defecto, sin acceso al
  `SphereITD` interno); OpenDou lo aplica en C++ con Woodworth **completo**: el residuo de
  `peakDelays` no está en la salida y restarlo dejaba el ITD asimétrico.
* **Extensión nativa.** Una `.dylib` bajada del navegador trae `com.apple.quarantine` y
  macOS la rechaza («library load disallowed by system policy»); `native/build.sh` la
  limpia y firma ad hoc. godot-cpp no tiene rama 4.7: `master` @ `26fb7ab`.
  `AudioStreamPlayback.mix_audio()` reserva memoria en el hilo de audio; medido y aceptado.
* **Tests binaurales: asentar y medir por MUESTRAS, no por frames.** En headless un frame
  dura ~2 ms y seis frames no cubren la latencia del anillo. Y fuente periódica de 1024
  muestras con bandas alineadas al periodo, o la medida espectral oscila entre corridas.
* **`var x := load(...)...()` no infiere el tipo** desde un script cargado con `load()`:
  rompe el parseo del archivo entero y la suite dice «Nonexistent function» en otro sitio.
  Tipo explícito siempre que el receptor venga de `load()`.

**Observaciones y trampas de la Fase 8 (higiene y deuda):**

* **Observación 43, no reproducida y endurecida.** Quince corridas (diez aisladas, cinco de la
  suite) con traza idéntica; las dos apariciones fueron durante la 7B. Se endureció el
  despachador: la caché del grafo se invalida por **generación** (registrar o desregistrar
  salas y portales) y con el grafo vacío. `tools/repeat_street_test.gd` y la variable
  `OPENDOU_TRACE_OBS43` quedan para cazarla si asoma.
* **Observación 45.** Hasta la Fase 8, `AudioMixSnapshotManager` y `AudioDuckingMatrix`
  calculaban estados que **nadie escribía en el `AudioServer`**, `OpenDouParameterArea3D`
  llamaba a un `push_snapshot` que el manager no tenía (silenciado por un `has_method`), y
  `AudioEventDef.max_instances` no lo leía nadie. Regla: **un `has_method` antes de llamar a
  algo propio es una promesa vacía en potencia**; si el método es nuestro, se llama directo.
* **Observación 46.** `EventInstance.stop(fade)` ignoraba su parámetro; y la limpieza del
  manager pasaba las instancias terminadas por `virtualize()`, que las dejaba en
  `STATE_VIRTUAL`: una instancia terminada respondía `is_playing() == true`. Ambos corregidos.
* **Godot: el volumen de un bus se aplica AL ENVIARLO** al bus siguiente, después de sus
  efectos. Un `AudioEffectCapture` dentro del bus **no ve** el volumen del bus: para medir el
  volumen hay que capturar en el bus destino.
* **Godot: un bus solo puede enviar a otro de índice menor.** Un `set_bus_send` a un bus
  creado después produce silencio, sin error.
* **Godot: `AudioEffectLimiter` está obsoleto desde 4.3**; la cadena usa `AudioEffectHardLimiter`.
* **Godot: `pop`/transición sin tiempo usa el fundido por defecto de la instantánea destino**
  (`default_blend_time`, 1 s en las incorporadas). Un test que espera 0.5 s ve la transición a
  medias.
* **El medidor LUFS en GDScript cuesta 91 ms por segundo de audio** (~9 % de un núcleo).
  Apagado por defecto; la aceleración nativa es una tarea pendiente.
* **El cajón de mezcla del editor no puede leer el runtime**: vive en otro proceso. Lo que se
  quiera ver en vivo va al HUD del juego (`OpenDouAudibleMonitor`) o por Live Update.

**Observaciones y trampas de la Fase 9 (el emisor completo):**

* **Observación 47.** `OpenDouSplineEmitter3D` no pasa por el sistema de voces: reproduce por
  su cuenta, con su propio `SpatialAcousticsManager`, y no lo alcanzan el pool, el robo de
  voces, el grafo de salas ni el backend binaural. En la Fase 9 solo gana el flujo
  (`flow_speed_mps`) dentro de su doppler propio. Integrarlo es tarea de otra fase.
* **Godot: `Curve.sample()` interpola con Hermite.** A mitad de camino entre dos puntos da lo
  que dicen las tangentes, no la recta; un test que espera interpolacion lineal falla.
* **Godot: `Curve3D.sample_baked_with_rotation` entrega la tangente como `-basis.z`.**
* **Godot: los reproductores anonimos del pool nacen con la atenuacion por defecto**
  (inversa, `unit_size` 10, `max_distance` 0). Hasta la Fase 9 una instancia con otro modelo
  sonaba con el de Godot en el backend `godot`; ahora el canal le copia modelo, `unit_size`,
  `max_distance` y filtro de la instancia en cada `apply_spatial`.
* **El robo de voces descarta por `max_distance` (100 m por defecto) antes de que suene
  nada.** Un test que pone una fuente a 343 m no oye silencio por el retardo: no oye nada
  porque la voz nunca se devirtualizo. Hay que subir `max_distance` en la instancia.
* **El multiplicador de la curva alimenta tambien el shelf por distancia** en ambos backends:
  una curva a -20 dB mide unos -30 dB sobre ruido de banda ancha. Coherente entre backends
  (paridad < 1.5 dB), pero no es igual a la curva.
* **La mezcla HRTF del jugador es un factor, no un valor.** El canal escribe
  `default_spatial_blend x (1 - spread)` en cada voz ocupada; el menu solo toca los flujos libres.
* **Los tests sincronos corren desde `_init` del runner, sin arbol.** Un test que anade nodos
  va a `run_async_suite(tree)` aunque no espere nada; `Engine.get_main_loop()` ahi es nulo.
* **La suite ya pasa de 90 s** (unos 88 s en frio, con picos por encima): el vigilante de
  `run_tests.sh` esta en 180 s (`OPENDOU_TEST_TIMEOUT`).
* **Un `python`/`sed` que edita en memoria no edita nada**: la primera pasada de la senal
  `marker_reached` se perdio por no escribir el archivo, y el error salio como
  `Identifier not declared`. Comprobar con `grep` antes de correr la suite.

**Observaciones y trampas de la Fase 10 (el oyente y el entorno):**

* **Observación 48.** El oyente no es un cuerpo: un `Area3D` no puede detectarlo con
  `body_entered`. `OpenDouAcousticVolume3D` decide la pertenencia del oyente por geometria
  (caja, esfera y cilindro analiticos; otras formas por su AABB) una vez por cuadro. Es
  determinista y no depende del paso de fisica.
* **Godot: `Area3D` ya tiene un miembro `priority`** (el de gravedad y amortiguacion). Un
  `@export var priority` en un nodo que hereda de `Area3D` es `Parse Error: Member redefined`.
  El del volumen se llama `volume_priority`.
* **Medir en Master es medir tras el compresor de la cadena `GAME`** (umbral -12 dB, 3:1):
  un -12 dB en la voz sale como -4 y un -6 como +1 respecto a otra medida. Las diferencias
  de nivel se miden en el bus de sonda (`TestBackendParity.BUS`) con `def.target_bus`; en
  Master solo lo que vive en Master (el paso-bajo del medio, el mono, el modo noche).
* **En la suite existe el autoload `/root/OpenDou`**, vacio. Un nodo que busca «el manager»
  por esa ruta encuentra ese y no el de la prueba: los nodos que consultan el manager
  (`OpenDouSoundIndicator`, `OpenDouAIHearing3D`) tienen `set_manager()` y el test lo usa.
* **Godot: `AudioEffectStereoEnhance` con `pan_pullout = 0` es mono de verdad**: ILD de
  17.7 dB a 0.00 medido en Master.
* **Un `AudioEffectCapture` solo ve los efectos anteriores a el en el bus.** Para medir un
  efecto que se anade despues, hay que volver a enganchar la sonda.
* **`unit_size` de la instancia es 10 por defecto** (el de Godot), no 1: a 20 m con modelo
  inverso son -6 dB, no -26. Los tests calculan la esperanza con `attenuation_db` y no a mano.
* **El pico espurio del medidor LUFS** (`pico muestral -23 dBFS`, medido -4.6 a -6.7 dBFS)
  aparecio cuatro veces en la Fase 10 y una en la 9, siempre sin cambios en ese test. El tono
  de 1 kHz cabe exacto en 1 s (sin clic de bucle) y nada mas envia a ese bus. Sigue abierto.
* **La velocidad del sonido es una variable en cuatro sitios** (C++ `configure_listener`,
  `VoicePoolManager.speed_of_sound` que llega a cada canal, `SpatialAcousticsManager.
  speed_of_sound` para el doppler). Un medio nuevo tiene que tocar `_update_environment`, no
  un 343 suelto.
* **`Array.sort_custom` con lambda es el mayor coste del bucle de control.** A 200 voces, el
  robo de voces y el planificador de oclusion ordenaban con una lambda cada cuadro: 338 y
  219 us. Pares `[clave, valor]` con `sort()` nativo: 245 y 51. Regla: en un bucle por cuadro,
  nunca `sort_custom`.
* **`get_lod_features()` construye un `Dictionary` por llamada.** Llamarlo por instancia y
  cuadro son 200 asignaciones; `physics_occlusion_max_distance()` lo resume en una distancia.
* **Nueve escrituras de propiedad a un stream nativo cuestan mas que una llamada con nueve
  argumentos.** `OpenDouSpatialStream.set_spatial_params(...)` reemplaza a las escrituras
  del canal por voz y cuadro. `tools/profile_control_loop.gd` mide el bucle por etapas.

**Observaciones y trampas de la Fase 11 (emisores nuevos y modos):**

* **Observación 49.** Dentro de un `Area3D` con `reverb_bus_enabled`, Godot manda la salida de
  un `AudioStreamPlayer3D` **solo** al bus de reverb del area: el bus propio del reproductor
  no recibe nada (`tools/probe_area_reverb.gd`: seco -200 dB con `area_mask = 1`, -19 dB con
  `area_mask = 0`). Consecuencia: `target_bus`, instantaneas y ducking por bus **no alcanzan a
  las voces 3D dentro de salas**; el bus de reverb del pool lleva seco y mojado a Master. Para
  medir una voz dentro de una sala hay que capturar en el bus de reverb de la sala. El envio
  de reverb propio (sin el mecanismo del Area3D) queda como deuda para la fase de reverb.
* **Observación 50.** Hasta la Fase 11 `VoicePoolManager.devirtualize` reproducia solo
  `voices[0].stream` del arbol de contenedores y tiraba `volume_offset_db` y
  `pitch_modifier`: un `AudioBlendContainer` no cruzaba nada y el jitter del aleatorio no se
  oia. Ahora cada voz resuelta tiene su canal (`layer_channel_ids`, hasta 4 extra) y, si el
  arbol es determinista (`is_deterministic()`: sin aleatorios ni secuencias), los
  desplazamientos se re-resuelven cada cuadro.
* **`RTPCValue` interpola a 10 unidades por segundo en valor absoluto.** Un RPM de 900 a 5000
  tardaba siete minutos. Los RTPC locales (`EventInstance.set_parameter`) escalan la
  velocidad con el salto y asientan en 0.25 s; la API global con velocidades explicitas no
  cambia.
* **Godot: cuando llega `body_entered` la velocidad del cuerpo ya esta resuelta** (0 tras
  el choque). La velocidad de impacto se guarda en `_physics_process`, antes del paso.
* **Godot: en 2 cm de caida la gravedad suma 0.66 m/s.** Un test de «bajo el umbral» a 0.2 m/s
  con umbral 0.5 dispara igual; el umbral del caso es 1.0.
* **Godot: `AudioStreamWAV` con `loop_end = num_samples` pica en el punto de bucle** (el
  interpolador lee mas alla del bufer): un tono de -23 dBFS daba picos de -5 a -7. Con
  `num_samples - 1`, exacto. El sintetizador y los tonos de los tests ya lo hacen asi.
* **Dos managers peleando por un bus.** El autoload gobierna todo bus que una regla de ducking
  o una instantanea nombre (`managed_buses`), aunque el bus lo toque un test con su propio
  manager. Los tests que tocan buses compartidos (`Radio`) usan el autoload, como las demos;
  `BUS_CAPTURE` fija el volumen del bus tambien en la BASE del aplicador de mezcla.
* **El centroide espectral de la suite empieza en 229 Hz.** Un motor entre 40 y 160 Hz mide
  «0 Hz». Para graves, energia por bandas.
* **`OpenDouMultiPositionEmitter3D` hereda de `AudioStreamPlayer3D`** y reproduce su propio
  stream: no postea eventos ni pasa por el pool (como el spline, obs 47).

**Observaciones y trampas de la Fase 12 (efecto directo de Steam Audio):**

* **Observación 51.** El bake ES la escena acustica: `OpenDouAcousticGeometryBake.export_to_native()`
  vuelca sus triangulos y materiales a `IPLScene` + `IPLStaticMesh`. La escena es **una por
  proceso** y la limpia el bake que la alimento al salir del arbol: sin eso, los mamparos de la
  quilla seguian ocluyendo en el test de paridad de la suite siguiente. `OpenDouSimulator` se
  apaga con la escena y los `sim_source` de los canales quedan invalidos (el planificador los
  suelta al cuadro siguiente).
* **`spatialize = false` salta TODA la cadena del stream nativo**, tambien el efecto directo.
  Para medir sin colorear el HRTF: `spatialize = true` y `spatial_blend = 0`.
* **Con fuente del simulador el planificador no lanza el rayo**, asi que el corte que llega al
  canal ya no trae el del rayo: no hay que ignorarlo (trae el del grafo de salas y los volumenes).
  Ignorarlo dejaba la escotilla de la quilla en 20 kHz.
* **Steam Audio: `IPL_AIRABSORPTIONTYPE_DEFAULT`** (no `...MODELTYPE...`); `IPLCoordinateSpace3`
  es `{right, up, ahead, origin}` y Godot mira a -Z: `ahead = -basis.z`, `right = ahead x up`.
  Un muro delante da `occlusion = 0.00` con oclusion volumetrica de radio 0.5.
* **`iplDirectEffectApply` acepta in-place** sobre el bufer mono (B3 resuelta).
* **La transmision del efecto directo es fisica: un muro de hormigon deja pasar casi nada**
  (0.015 / 0.002 / 0.001). La diferencia entre cristal y hormigon medida en el bus fue de 49 dB en
  la banda alta: las aserciones piden «al menos 6», no igualdad.
* **El ultimo test de la suite tiene que esperar ~300 ms tras parar sus voces**: el hilo de
  audio suelta los playbacks en su siguiente mezcla y, si el proceso termina antes, quedan como
  fugas (64 `AudioStreamPlaybackWAV`). `--verbose` lista las clases fugadas.
* **El filtro de commit tiene que mirar el codigo de salida de `run_tests.sh`**, no solo
  `STATUS: PASSED`: el trinquete de fugas falla aparte.
* **Un `AudioEffect` por GDExtension funciona** (spike B5): `_instantiate()` devuelve la
  instancia y `_process(const void *src, AudioFrame *dst, int32_t n)` recibe `AudioFrame`s.
  `_tone()` de los tests tiene pico -6 dBFS: con `volume_db = -6` mide -12, no -6.

**Observaciones y trampas de la Fase 13 (reflexiones y ambisonics):**

* **Observación 52.** Un `AudioEffect` nativo por GDExtension funciona en un bus
  (`OpenDouGainEffect`, `OpenDouConvolutionReverb`): `_instantiate()` + `_process(const void*,
  AudioFrame*, int32_t)`. Con la observacion 49, el bus de reverb de la sala recibe la voz entera,
  asi que el efecto de convolucion devuelve seco + humedo.
* **godot-cpp: `Basis[i]` es la FILA i, no la columna.** Los ejes del oyente son
  `get_column(0..2)`; usar filas invierte la rotacion (la cama ambisonica giraba al reves).
* **El simulador solo se configuraba cuando habia voces**: `OcclusionScheduler.process()` vuelve
  antes si la lista esta vacia. La sala del oyente llama a `ensure_simulator()` por su cuenta.
* **El oyente compartido del simulador (`iplSimulatorSetSharedInputs`) hay que fijarlo aunque
  no haya voces simuladas**: sin el, las reflexiones no trazan nada (RT60 0).
* **Los buses del pool de reverb son compartidos y sobreviven al manager**: un efecto de
  convolucion instalado por un manager steam seguia en el bus cuando llegaba uno godot. La sala
  vuelve a Sabine si `convolution_allowed` es falso y el bus trae convolucion.
* **`reverb_bus_amount = 0` en el Area3D no manda nada al bus** (ni seco ni humedo, obs 49):
  el «wet 0» se fija en el efecto, no en el envio de la sala.
* **La cola de una caja de 6 m con RT60 0.4 s dura 0.3 s**: medir a 0.5-0.8 s tras el tono da
  silencio (-158 dB). Las ventanas van alineadas al inicio real del tono, que tarda cuadros.
* **Los materiales de la tabla no siguen la intuicion:** Metal y Wood comparten las bandas media
  y alta; para contrastar RT60 sirven Concrete (0.05/0.07/0.08) frente a Foliage (0.3/0.6/0.8).
* **Las reflexiones tempranas mueven el tono seco hasta 4 dB** (filtro de peine) en la ventana
  del tono: «el seco pasa igual» se afirma con `wet = 0`, no comparando wet 1 con wet 0.
* **Con `--check-only --script` Godot da el error de parse exacto** de un test que la suite solo
  reporta como «Could not preload». Una variable `shape` repetida en el mismo ambito lo era.

**Observaciones y trampas de la Fase 14 (sondas, caminos, geometria dinamica):**

* **Observacion 53.** El grafo autorado manda sobre las sondas: una voz gobernada por un portal
  (`room_path_active`) no pide caminos, y `pathing_active` respeta el mismo contrato en
  `update_parameters`. Sin salas, el hilo de simulacion arranca igual cuando hay sondas y voces
  simuladas (`_update_listener_room`).
* **`iplPathBakerBake` con `progressCallback` nulo salta a la direccion 0** en Steam Audio 4.8.1
  (la documentacion dice «puede ser NULL»; el lambda interno no lo comprueba). Siempre un
  callback vacio. El crash aparecia «intermitente» solo porque se alternaron compilaciones con
  y sin callback; el informe de macOS (`~/Library/Logs/DiagnosticReports`) dio el hilo real.
* **`IPLProbeGenerationParams.transform` lleva un cubo CENTRADO en el origen** ([-0.5, 0.5]^3,
  como el cubo de Unity), no [0, 1]^3: la traslacion es el centro de la caja. Con la esquina
  salian 8 sondas en vez de 28. `IPLMatrix4x4.elements[fila][columna]` con vectores columna.
* **Convencion de los SH de pathing (B10):** ACN orden 1 = W, Y, Z, X ambisonicos, donde Y es
  IZQUIERDA (-x), Z arriba (+y) y X FRENTE (-z); direccion = (-sh[1], sh[2], -sh[3]). W trae la
  amplitud del camino ya con su 1/d y el factor 1/sqrt(4 pi): a 6 m a la vista, W = 0.047 =
  (1/6) / 3.545. La ganancia relativa a la distancia directa es W * sqrt(4 pi) * d (1 a la vista).
* **Las mallas dinamicas NO deben entrar en la malla estatica**: `scan_child_meshes` recorre
  todo el arbol y horneaba la puerta cerrada para siempre (oclusion 0 a cualquier angulo).
* **La oclusion volumetrica muestrea una esfera de radio 0.5 en la fuente**: una hoja a 45
  grados aun la tapa entera; para «a medias» hace falta que el borde parta la esfera (60 grados).
* **Godot enruta la voz al bus de reverb del `Area3D` con hasta un bloque de retraso** (obs 49):
  el tono llega al bus recortado por delante en algunas corridas. Las ventanas de medida se
  alinean al FINAL del tono (bloques de 10 ms, ultimo a -3 dB del mas fuerte), no al inicio.
* **`lldb` no puede adjuntarse a Godot en esta maquina** (macOS lo niega); el `.ips` de
  DiagnosticReports trae la pila de todos los hilos con el desplazamiento en `libphonon`, y
  `lipo -thin arm64` + `llvm-objdump --start-address` desensambla el punto exacto.
* **`near_field` (Fase 9) fluctua a veces** (+2.5 dB por +3.6 pedidos, una corrida de ~10):
  candidato a alinear como la convolucion. Anotado, no corregido.

**Observaciones y trampas de la Fase 15 (deudas C1-C5):**

* **Observacion 54.** El envio propio de reverb (`OpenDouSendBus` + `OpenDouSendStream`) sustituye
  al `reverb_bus` del `Area3D` en `steam_audio`: la voz vuelve a su `target_bus` y solo las voces
  de OpenDou (del manager que conoce la sala) reciben el reverb de la sala. La observacion 49
  queda acotada al backend `godot`.
* **Un bus sin reproductores esta INACTIVO para Godot**: sus efectos procesan (con
  `process_silence`) pero su salida no llega a Master (pico -200) y su bufer no se limpia entre
  pasos, asi que un efecto que sume algo al `src` realimenta el residuo y explota (+400 dB en
  segundos). El envio sale por un `AudioStream` reproducido en el bus, no por un `AudioEffect`.
* **Los reproductores de envio del autoload siguen sonando al cerrar**: sus playbacks quedan
  vivos en el AudioServer y el trinquete de fugas los cuenta (+8, dos objetos por envio). El
  manager los libera en `_exit_tree` y el runner los para 300 ms antes del recuento.
* **Los buses del pool sobreviven al manager, los reproductores no**: los ids de envio viven
  en un `static var` del pool; un manager nuevo crea su reproductor con el id existente.
* **La cache de caminos por par de salas ignoraba la posicion del emisor**: la primera voz
  fijaba el portal de todas (desde el fondo de la casa gana la puerta cerrada). La clave lleva
  ahora la celda de 4 m del emisor. Aparecio al cambiar el orden de las voces (C3).
* **`post_event(def, caller)` con un `Node3D` como caller fija la posicion del emisor CADA
  cuadro desde `caller.global_position`**: un proveedor de posicion tiene que publicar con
  `caller = null` y fijar `position_provider` en la instancia.
* **`scan_child_meshes` y los grupos: una malla dinamica no puede estar tambien en la
  estatica** (Fase 14); analogamente un `AudioStreamPlayer3D` proveedor no puede ser a la vez
  el reproductor de su voz: `_provider_tick()` lo para si alguien llamo a `play()`.
* **El driver de audio headless corre mas lento que el reloj de pared bajo carga** (0.84 s de
  audio por segundo en la suite completa). Todo lo que espere «N segundos de audio» tiene que
  contar muestras o `processed_seconds`, no `Time.get_ticks_msec()`; y un retardo descontado con
  `delta` (backend godot) se afirma con el reloj, no en muestras.
* **`_band_energy_stereo` sumaba periodos completos**: la captura trae 1 o 2 periodos segun
  caigan los bloques y dos medidas del mismo sonido diferian 3 dB. Ahora promedia por periodo.
* **El tono del test de convolucion llega al bus de reverb recortado por delante** (Godot
  enruta el `Area3D` con hasta un bloque de retraso): las ventanas se alinean al FINAL del tono.
* **`AudioServer.get_bus_effect(idx, 0)` ya no es necesariamente el reverb** del pool: se
  busca por tipo (`is AudioEffectReverb`) o por marca (`resource_name`).

**Observaciones y trampas de la Fase 16 («La presa»):**

* **Observacion 55.** Una escena grande destapa lo que las suites unitarias no: el planificador
  de oclusion guardaba el pool de voces viejo tras `set_max_physical_voices` (ninguna voz recibia
  efecto directo ni caminos cuando otra demo habia cambiado el presupuesto antes); las capas de
  un contenedor no heredaban la fuente del simulador (sonaban sin efecto directo); y un camino
  «a la vista» quedaba congelado al cortarse la linea de vision. Las tres son del plugin, no de
  la demo, y ahora tienen su regla: el pool se reapunta, las capas comparten fuente/camino/envio,
  y solo gobiernan los caminos que desvian mas de 10 grados.
* **En un `.tscn`, `script = ExtResource(...)` va ANTES de las propiedades que el script
  define**: las que llegan antes no existen todavia y Godot las descarta en silencio (turbinas,
  goteo, bocina y camion mudos; `doppler_enabled` ignorado).
* **La geometria «de relleno» es real para el trazador**: el muro de la presa como caja unica
  cruzaba la galeria (el goteo estaba dentro del hormigon) y el canal del aliviadero nacia dentro
  del muro. Los tuneles se abren en el volumen que atraviesan.
* **La caja de sondas mapea un cubo CENTRADO** (traslacion = centro) y los rayos bajan desde su
  techo: si el techo coincide con una losa, no hay sondas dentro. El oido del jugador va a 2.6 m
  del suelo (capsula + camara): un tunel de 2.5 m lo dejaba fuera de la sala y pegado al techo.
* **Steam Audio no borra la salida de pathing cuando no encuentra camino**: la fuente fuera de
  las sondas conserva su ultimo resultado (el «a la vista»); con `pathing_gain = 1` la compuerta
  no ocluia nada. De ahi la regla de los 10 grados en el manager.
* **La transmision del efecto directo aplica el coeficiente al CUADRADO**: cristal 0.06 da
  -49 dB, hormigon 0.015 da -77, 0.5 plano da -12. Las bandas son < 800 Hz, 800-8k, > 8k: hay
  que medir donde la fuente tiene energia (un zumbido, en 100-700 Hz).
* **Un bus de reverb por convolucion en una nave lisa de 36 m satura** (+14 dB con envio 0.8):
  el envio es el fader del reverb y salas grandes piden 0.15-0.3; si el limitador de Master
  recorta, sus armonicos parecen «agudos» que ningun filtro quita.
* **La ventana rectangular del analizador de bandas se fuga desde los graves** (-46 dB por
  lobulos): con graves 70 dB por encima, cualquier filtro «desaparece». Para senales
  arbitrarias, `_band_energy_stereo_windowed` (Hann); para el ruido periodico de los tests, la
  rectangular es exacta y Hann mezclaria bins.
* **Las curvas de un `AudioBlendContainer` son dB** (0 suena, -60 calla), no pesos 0..1.
* **`OpenDouEventPlayer3D` en `BUS_CAPTURE` y `OpenDouEventPlayer`: el bus de la fuente baja a
  -80 y otra regla puede sumarle mas** (-90 medido): se afirma `<= -79`, no igual a -80.
* **Observacion 56.** Una bandera GDScript que refleja estado NATIVO se queda rancia. El manager
  guardaba `_reflections_started` y no volvia a arrancar el hilo de reflexiones y caminos cuando
  otro test lo habia apagado con `shutdown()`: RT60 0 y ningun camino, con las sondas cargadas y
  adjuntas. La verdad la tiene el nativo (`is_reflections_running()`), y ahora se le pregunta.
  Regla: si el estado vive en C++, no lo caches en GDScript para DECIDIR.
* **Dos aserciones median con el reloj y fluctuaban.** La cola del hormigon del test de
  convolucion saltaba 14 dB (de -16 a -30 dB) porque un `RT60 > 0` dice que el hilo trazo UNA
  vez, no que el efecto tenga la IR viva: hay que esperar dos corridas mas
  (`reflection_runs`). Y el trueno de «La presa» no llegaba en algunas corridas porque se
  esperaban 2.5 s de RELOJ para 1 s de retardo: en headless el driver da ~0.84 s de audio por
  segundo. Con las dos correcciones, tres corridas seguidas dan cola -13.3/-14.1/-14.7 dB y
  trueno a 1.11 s.
* **Godot puede reescribir un `.tscn` de demo por su cuenta.** Observado una vez en esta sesion
  (no reproducido despues en cinco corridas): `street_demo.tscn` aparecio modificado con
  `reverb_mode = 2` anadido a sus cuatro salas y **sin** el `material_preset`/`floor_surface`
  `Stone` de `HouseC`, y `presa_demo.tscn` convertido a la forma `uid://`. Un `git add -A`
  habria comprometido la regresion. Regla: antes de comprometer, `git status` y `git diff` de
  todo `.tscn` que no hayas editado a mano.
* **Herramientas que se quedan**: `tools/probe_presa*.gd` (la demo cargada, medidas por zona),
  `tools/probe_transmission.gd` (transmision por material en el stream),
  `tools/probe_master_lpf.gd` / `probe_subbus_lpf.gd` (filtros de Master), `tools/gen_presa_tscn.py`
  (genera la escena UNA vez) y `tools/bake_presa_probes.gd` (rehornea el `.probes`).

---

## 6. Reglas Modulares de Referencia

Para directivas detalladas, consulta:
* [Reglas de Estilo y Código](.agents/rules/01_code_style.md)
* [Reglas de Arquitectura y Patrones](.agents/rules/02_architecture.md)
* [Flujo de Trabajo y Commits](.agents/rules/03_workflow.md)
* [Composición de Escenas](.agents/rules/04_scene_composition.md) — **todo lo que una
  escena necesita se compone como nodos dentro de la escena**; el código solo para lo
  dinámico
