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

---

## 6. Reglas Modulares de Referencia

Para directivas detalladas, consulta:
* [Reglas de Estilo y Código](.agents/rules/01_code_style.md)
* [Reglas de Arquitectura y Patrones](.agents/rules/02_architecture.md)
* [Flujo de Trabajo y Commits](.agents/rules/03_workflow.md)
* [Composición de Escenas](.agents/rules/04_scene_composition.md) — **todo lo que una
  escena necesita se compone como nodos dentro de la escena**; el código solo para lo
  dinámico
