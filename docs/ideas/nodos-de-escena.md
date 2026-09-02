# Ideas de nodos para componer escenas

**Fecha:** 2026-09-02 · **Estado:** ideas, nada de esto existe · **Parte de:** [`docs/funcionalidades.md`](../funcionalidades.md), sección 2

Los nodos de escena son la cara del plugin para quien diseña un nivel: se arrastran, se
configuran y suenan. Hoy hay quince. Este documento propone los siguientes, en tres grupos:
los que **Steam Audio habilita** (su SDK ya trae la física; falta el nodo que la exponga), los
que **Steam Audio no hace y podemos hacer en nuestro C++**, y los que **caben en GDScript**
sobre lo que ya tenemos. Cada idea dice qué problema audible resuelve, cómo se haría, qué cuesta
y cómo se afirmaría en la suite, porque una funcionalidad que no se puede medir no entra.

Al final hay una lista corta recomendada: lo que más se oye por lo que menos cuesta.

**Revisión del 2026-09-02.** Una revisión arquitectónica señaló que varias ideas encajan mejor
como exports o recursos que como nodos, para no ensuciar el árbol de escena, y cuatro huecos
frente al estándar AAA que la primera versión no veía. Las secciones F y G recogen ambas cosas
y la lista corta (D) está revisada en consecuencia.

---

## A. Nodos que Steam Audio habilita

Steam Audio trae la física; estos nodos son la autoría. Todos dependen de la Fase 7C (efecto
directo y geometría) o posteriores.

### A1. `OpenDouAcousticMaterial3D` — materiales acústicos en tres bandas
- **Problema.** Hoy un material es un nombre y una absorción escalar. La música a través del
  cristal y a través del ladrillo suena igual de apagada.
- **Cómo.** Nodo hijo de una malla del grupo `AcousticObstacle` (o un recurso `AcousticMaterial`
  arrastrable) con absorción, dispersión y transmisión **por banda** (graves, medios, agudos),
  con los ocho presets de `AcousticMaterialRegistry` como punto de partida. El bake lo vuelca a
  `IPLMaterial` y la geometría a `IPLStaticMesh`; el efecto directo devuelve la transmisión por
  banda y el stream nativo la aplica con tres shelves.
- **Cuesta.** Fase 7C entera: el bake alimenta a Steam Audio, y el efecto directo entra en la
  cadena. Medio-alto.
- **Se afirma.** La misma voz tras `Glass` y tras `Concrete`: espectros distintos en el bus,
  con el control de `Air` (sin pared) igual al directo.

### A2. Directividad en `OpenDouEventPlayer3D` — el sonido tiene cara
- **Problema.** Una radio, una boca, un tubo de escape y una campana suenan igual desde
  cualquier lado. Hoy no existe la noción.
- **Cómo.** Dos exports en el emisor (`directivity_dipole_weight`, `directivity_power`) y una
  flecha en la vista 3D. Steam Audio lo calcula en el efecto directo con la orientación del
  nodo; sin extensión, una aproximación en GDScript (coseno elevado a la potencia, aplicado al
  volumen) mantiene la paridad.
- **Cuesta.** Bajo una vez exista el efecto directo. La versión GDScript es de una tarde.
- **Se afirma.** El emisor mirando al oyente frente al emisor de espaldas: caída de nivel
  medible; con `dipole_weight = 0`, ninguna.

### A3. `OpenDouAmbisonicBed3D` — ambientes que rodean
- **Problema.** La lluvia del monzón son 200 fuentes puntuales. Un ambiente de verdad es un
  **campo** que gira con la cabeza, no puntos.
- **Cómo.** Reproduce un archivo ambisónico (orden 1 o 2, ACN/SN3D) o codifica al vuelo una
  cama estéreo; Steam Audio lo rota con la orientación del oyente y lo decodifica al HRTF
  (`IPLAmbisonicsRotationEffect` + `IPLAmbisonicsBinauralEffect`). Un solo stream nativo por
  cama, no uno por gota.
- **Cuesta.** Un stream nativo nuevo (`OpenDouAmbisonicStream`) con cuatro o nueve canales de
  entrada; el pool ya sabe alojar streams. Medio. Fase 7D.
- **Se afirma.** Girar al oyente 90° mueve una fuente codificada al frente hacia un lado: la
  ILD cambia de signo sin tocar la fuente. Con la rotación apagada, no cambia.

### A4. `OpenDouAcousticProbes3D` — propagación precocinada
- **Problema.** El grafo de portales suena donde el diseñador puso portales. Un pasillo en L
  sin puertas, un patio, una cueva: nadie va a autorar cada esquina.
- **Cómo.** Volumen que genera sondas (`iplProbeBatch`) con espaciado configurable, botón de
  bake en el inspector (como el del bake de geometría) y un archivo `.probes` versionable.
  El efecto de caminos de Steam Audio da atenuación, dirección aparente y retardo por sonda.
  Convive con los portales: lo autorado gana; las sondas cubren el resto.
- **Cuesta.** Alto: bake offline, formato de archivo, un efecto nuevo en la cadena, y la
  decisión de quién gobierna cuando hay portal **y** sonda. Fase 7E.
- **Se afirma.** Emisor tras una esquina sin portal: con sondas, la voz llega y su dirección
  aparente apunta a la esquina; sin sondas, solo la oclusión por raycast.

### A5. `OpenDouDynamicOccluder3D` — puertas que ocluyen mientras giran
- **Problema.** La hoja de la puerta de «Una casa canta» gira y mueve el portal, pero no
  **tapa** el sonido con su propia masa mientras está a medio abrir.
- **Cómo.** Nodo sobre una malla con transform vivo que la registra como `IPLInstancedMesh`
  y actualiza su transform cada frame que se mueva (con umbral, para no recomputar quieto).
- **Cuesta.** Medio, tras 7C. El coste en runtime es de Steam Audio: hay que medirlo con la
  guarda de DSP.
- **Se afirma.** Puerta a 45° entre emisor y oyente: la oclusión volumétrica es intermedia
  entre abierta y cerrada, y la puerta quieta no dispara actualizaciones.

### A6. `OpenDouReverbZone3D` — reverb por convolución de la geometría real
- **Problema.** Las salas de «Bajo la quilla» son dos presets de Sabine. Un pasillo de metal y
  una bodega de madera del mismo volumen suenan igual.
- **Cómo.** La sala pide una respuesta al impulso trazada contra su geometría y materiales
  (`IPLReflectionEffect`, modo convolución, centrado en el oyente: una IR para la sala donde
  estás, no una por voz). El `OpenDouIRRT60Analyzer`, que hoy no tiene materia prima, pasa a
  derivar el RT60 real y a alimentar el fallback de Sabine cuando la extensión no está.
- **Cuesta.** Alto: el efecto de reflexiones es lo más caro de Steam Audio y exige el hilo
  de simulación. Fase 7D.
- **Se afirma.** La IR de la sala de metal tiene un T20 más largo que la de madera con el
  mismo volumen; y sin extensión, el pool de Sabine recibe el RT60 derivado.

### A7. `OpenDouListener3D` — el oyente como nodo propio
- **Problema.** El oyente es la cámara o un `AudioListener3D`. No hay dónde poner el radio
  de cabeza, la separación de oídos, un HRTF por jugador, ni un enganche de seguimiento de
  cabeza (giroscopio, VR).
- **Cómo.** Nodo que el `ListenerResolver` prefiere si existe, con exports: `head_radius_m`
  (hoy fijo en 8.75 cm en C++), `hrtf_override` (SOFA por jugador), `output_mode`, y una señal
  para inyectar la orientación de un dispositivo. Sin Steam Audio sigue sirviendo de override.
- **Cuesta.** Bajo. Casi todo existe; falta el nodo y pasar el radio al stream.
- **Se afirma.** Con `head_radius_m` al doble, el ITD medido a 90° se dobla.

---

## B. Nodos que Steam Audio no hace y podemos hacer en nuestro C++

Steam Audio no modela el tiempo de vuelo del sonido directo, el doppler, el medio (agua, aire
denso), el viento ni el campo cercano. Son huecos reales que un plugin propio puede llenar,
y nuestro stream nativo ya tiene la línea de retardo, los filtros y la ganancia por bloque.

### B1. Retardo por distancia — el trueno llega tarde
- **Problema.** Una explosión a 340 m se oye en el mismo instante en que se ve. Los juegos
  que suenan grandes retrasan el sonido a 343 m/s; Steam Audio no lo hace para el sonido
  directo.
- **Cómo.** Export `propagation_delay` en el emisor 3D (o en el evento). La línea de retardo
  del stream nativo crece hasta 3 s (ya es fraccionaria y con rampa: un emisor que se acerca
  hace un doppler natural, ver B2). Sin extensión, `AudioStreamPlayer3D` no puede retrasar:
  el fallback es arrancar la voz con retardo fijo desde la distancia inicial.
- **Cuesta.** Bajo en C++ (memoria: 3 s × 44.1 kHz × 2 canales × 4 bytes ≈ 1 MB por voz;
  solo para las voces que lo pidan). Un ajuste `max_propagation_delay_sec` acota la memoria.
- **Se afirma.** Emisor a 343 m: el primer transitorio llega ~1 s después de `post_event`,
  medido en el bus; a 34 m, ~0.1 s.

### B2. Doppler propio — el coche cambia de tono al pasar
- **Problema.** Nadie lo calcula hoy en ningún backend (verificado en la Fase 7B). El coche
  de «Una casa canta» pasa sin cambiar de tono.
- **Cómo.** Velocidad radial emisor-oyente por diferencia de posición entre frames, factor
  `c / (c + v_r)` suavizado, multiplicado en `calculated_pitch_scale`. Sirve en los **dos**
  backends porque actúa sobre `pitch_scale`. Export `doppler_enabled` apagado por defecto para
  no cambiar cómo suenan las escenas existentes. Si B1 existe, el doppler sale gratis de la
  rampa de la línea de retardo y no hay que tocar el tono.
- **Cuesta.** Bajo. Pospuesto por decisión en la Fase 7B; sigue siendo la pieza con mejor
  relación entre lo que se oye y lo que cuesta.
- **Se afirma.** Un tono de 1 kHz acercándose a 30 m/s se mide en el bus por encima de
  1 kHz y alejándose por debajo; con `doppler_enabled = false`, en 1 kHz.

### B3. `OpenDouMediumVolume3D` — bajo el agua, en la niebla
- **Problema.** Meter la cabeza bajo el agua debería cambiar **todo** el sonido: paso-bajo,
  velocidad del sonido cinco veces mayor (el ITD casi desaparece: bajo el agua no localizas),
  tono y reverb distintos.
- **Cómo.** `Area3D` que, con el oyente dentro, fija en el contexto nativo un perfil de medio:
  velocidad del sonido (escala el ITD de Woodworth y el retardo de B1), un paso-bajo global,
  un desvío de tono y una instantánea de mezcla. Sin extensión, la instantánea de mezcla y el
  filtro de bus hacen la mitad del trabajo.
- **Cuesta.** Bajo-medio: es parametrizar lo que ya hay más un `AudioEffectLowPassFilter` en
  Master o en los buses afectados.
- **Se afirma.** Oyente dentro del volumen: el ITD medido a 90° cae a menos de un quinto y la
  banda alta del bus cae; fuera, los valores de siempre.

### B4. `OpenDouWindZone3D` — el viento arrastra el sonido
- **Problema.** Los sonidos lejanos con viento en contra llegan más apagados y rotos; a favor,
  más claros. Es una pista de dirección que los juegos de mundo abierto explotan.
- **Cómo.** Volumen con vector de viento y ráfagas (un LFO ya existe). Para cada voz lejana
  el canal calcula el producto del viento por la dirección emisor-oyente y lo convierte en
  una modulación del shelf de distancia y de la ganancia, con la aleatoriedad de ráfaga.
  Todo en GDScript sobre parámetros que el stream ya tiene; sin extensión, sobre `volume_db`
  y el corte del filtro de Godot.
- **Cuesta.** Bajo. Es aproximación perceptual, no física, y el documento lo diría.
- **Se afirma.** Emisor a 60 m con viento en contra: banda alta menor que con viento a favor;
  con velocidad de viento 0, iguales.

### B5. Campo cercano — el susurro al oído
- **Problema.** Los HRTF se miden a 1–2 m. Una fuente a 20 cm de la oreja tiene un refuerzo
  de graves y una ILD mayores que ningún dataset trae. Es lo que hace que algo suene
  **encima** de ti.
- **Cómo.** En el stream nativo, por debajo de `near_field_distance` (0.5 m por defecto): un
  low-shelf de refuerzo proporcional a la cercanía y una ILD extra en el oído lejano. Es una
  aproximación conocida (modelo de esfera rígida) y barata.
- **Cuesta.** Bajo en C++: un biquad más y una ganancia.
- **Se afirma.** Fuente a 0.2 m frente a 1.0 m a la derecha: más graves y más ILD; con la
  distancia de campo cercano en 0, sin cambio.

### B6. `OpenDouWorldBus3D` — el altavoz del bar
- **Problema.** La música de «La cabina» sale de la radio en estéreo plano. Un juego quiere
  que la **mezcla entera de un bus** (radio, televisor, megafonía) suene como un objeto del
  mundo: con posición, oclusión, reverb de sala y directividad.
- **Cómo.** `AudioEffectCapture` en el bus origen alimenta un `AudioStreamGenerator` que es la
  fuente de un `OpenDouSpatialStream`; el nodo es un emisor 3D cuya voz es «lo que suena en el
  bus Radio». Con directividad (A2) es un altavoz de verdad. El bus origen se silencia en la
  salida directa.
- **Cuesta.** Medio: la latencia del capture más el anillo (dos bloques), y cuidar que el
  generador no se quede sin muestras.
- **Se afirma.** Un tono que suena solo en el bus `Radio` aparece en el bus del emisor 3D con
  la ILD de su posición; al mover el nodo, la ILD cambia.

### B7. `OpenDouEchoZone3D` — el eco del cañón, barato
- **Problema.** Las reflexiones por convolución (A6) son caras y para interiores. Un disparo
  en un valle quiere **un** eco a 400 ms con pérdida de agudos, y eso no necesita rayos.
- **Cómo.** Volumen con distancia a la pared lejana y absorción: el stream nativo mezcla una
  copia retrasada (`2·d / c`) y filtrada de la propia voz. Reutiliza la línea de retardo larga
  de B1. Sin extensión, `ReflectionDispatcher` ya reproduce copias retrasadas con voces del
  pool: el nodo le daría la geometría.
- **Cuesta.** Bajo tras B1.
- **Se afirma.** Un impulso dentro de la zona produce un segundo pico en el bus a `2·d / c`
  con menos banda alta; fuera de la zona, un solo pico.

---

## C. Nodos que caben en GDScript sobre lo que ya hay

### C1. `OpenDouMasterChain` — la cadena de masterización
- **Problema.** Ningún demo tiene limitador en Master (anotado al cerrar la Fase 7B). Una
  mezcla que recorta en el dispositivo tira por tierra todo lo anterior.
- **Cómo.** Nodo que, al entrar en el árbol, garantiza en el bus que se le indique un
  compresor y un limitador de Godot con un preset (juego, cinemática, móvil), compuesto como
  nodo para que la guarda de escenas lo exija en cada demo. Sin DSP propio.
- **Cuesta.** Muy bajo.
- **Se afirma.** Dos voces a +6 dB sumadas: el pico del Master no supera 0 dBFS; sin el nodo,
  lo supera.

### C2. `OpenDouSoundOccluderVolume3D` — cortinas, follaje, lluvia
- **Problema.** La oclusión es un raycast contra geometría sólida: todo o nada. Un seto, una
  cortina de lluvia o el humo atenúan **un poco** y **por volumen atravesado**.
- **Cómo.** `Area3D` con densidad (dB/m) y corte (Hz/m). El `OcclusionScheduler` ya lanza el
  rayo; solo hay que medir la longitud del segmento dentro de cada volumen que atraviese y
  sumar la atenuación y el corte al resultado. Sin extensión ni C++.
- **Cuesta.** Bajo. El coste por rayo sube con los volúmenes atravesados; el presupuesto de
  rayos ya existe.
- **Se afirma.** Emisor tras 4 m de «follaje» a 3 dB/m: −12 dB y corte proporcional; tras
  2 m, la mitad; sin volumen, nada.

### C3. `OpenDouAttenuationCurve` — la caída que el diseñador dibuja
- **Problema.** Tres modelos de atenuación de Godot para todo. Un susurro que muere a 3 m y
  un motor que se oye a 200 pero cae rápido al principio no caben en ninguno.
- **Cómo.** Un recurso `Curve` en la definición del evento o el emisor; `OpenDouDistanceModel`
  gana un modelo `CURVE` que lo evalúa (la curva ya está en el inspector de Godot). Funciona en
  los dos backends porque el canal es quien calcula la distancia desde la Fase 7B.
- **Cuesta.** Muy bajo.
- **Se afirma.** Con una curva que vale 0 dB hasta 5 m y −40 dB a 6 m, el nivel a 5.5 m cae
  ~20 dB; con el modelo inverso, ~1 dB.

### C4. `OpenDouAudioCullingVolume3D` — silencio por región
- **Problema.** En un edificio cerrado, la calle entera sigue gastando raycasts y voces
  aunque no se oiga. La virtualización lo descarta por sonoridad, no por diseño.
- **Cómo.** `Area3D` que, con el oyente dentro, marca categorías o buses como «no audibles»:
  sus voces se virtualizan sin gastar oclusión ni caminos. Se apoya en el pool de voces y en
  `AcousticLODController`.
- **Cuesta.** Bajo.
- **Se afirma.** Con el oyente en el volumen, los raycasts por frame de la categoría
  excluida son 0 y las voces siguen contando su tiempo lógico; al salir, vuelven a sonar en
  la posición correcta del bucle.

### C5. `OpenDouSurfacePaint3D` — pintar superficies sin colisión
- **Problema.** `OpenDouAnimationSync` detecta la superficie por metadatos del cuerpo físico.
  Un charco sobre asfalto, una alfombra sobre madera o una rejilla no tienen cuerpo propio.
- **Cómo.** `Area3D` con `SurfaceType` y prioridad que la detección consulta antes que la
  colisión. Cero DSP.
- **Cuesta.** Muy bajo.
- **Se afirma.** Pisada dentro del área «charco» sobre un suelo «asfalto»: el switch elige la
  rama `Water`; fuera, `Asphalt`.

### C6. `OpenDouSoundTrigger3D` — el evento que dispara el lugar
- **Problema.** Los eventos ambientales puntuales (un crujido al cruzar una puerta, una
  campanada al entrar en la plaza) hoy se disparan desde scripts de gameplay.
- **Cómo.** `Area3D` con evento, probabilidad, tiempo de recarga, «una sola vez» y filtro por
  grupo del cuerpo que entra. `OpenDouParameterArea3D` ya tiene la mitad de la lógica.
- **Cuesta.** Muy bajo.
- **Se afirma.** Un cuerpo del grupo `player` entra: el evento suena una vez y no vuelve a
  sonar antes del tiempo de recarga; un cuerpo de otro grupo no lo dispara.

### C7. `OpenDouAmbienceScheduler3D` — el ambiente que cambia con el tiempo del juego
- **Problema.** Amanecer, tormenta, toque de queda: hoy es un `BlendContainer` gobernado por
  un RTPC que alguien tiene que mover desde código.
- **Cómo.** Nodo con una línea de tiempo (hora del día, estados del juego) que mueve RTPC y
  estados con fundidos, y arranca y para eventos por franja. Reutiliza `GameSyncManager`.
- **Cuesta.** Bajo-medio; más UI que motor.
- **Se afirma.** Al pasar la «hora» de 6 a 7, el RTPC `Dawn` sube con la pendiente
  configurada y el evento `Roosters` arranca una vez.

---

## D. Lista corta recomendada (revisada)

Ordenada por lo que se oye dividido por lo que cuesta, y por lo que desbloquea después. La
columna «Forma» dice si es un export, un recurso, una fusión con un nodo existente o un nodo
nuevo (sección F).

| # | Idea | Forma | Por qué en este puesto |
|---|---|---|---|
| 1 | **G4 Límites de instancias con alcance** | `AudioEventDef` + pool | Limpia la mezcla de golpe; y `max_instances` ya está declarado **sin aplicarse**: hoy es una promesa vacía que hay que cumplir o quitar |
| 2 | **B2 Doppler** | export del emisor | Lo que más se echa en falta en el coche que pasa; una tarde; los dos backends |
| 3 | **G1 Spread por distancia** | export del emisor + stream | La fuente grande deja de colapsar en un punto al acercarte; `spatial_blend` por voz ya existe en el stream, falta el producto con la distancia |
| 4 | **B1 Retardo por distancia** | export del emisor | Hace grandes los espacios abiertos; reutiliza la línea de retardo; habilita B7 y afina B2 |
| 5 | **C1 Cadena de masterización** | nodo (uno por escena) | Protege todo lo demás; casi gratis; la guarda de escenas lo exige |
| 6 | **A7 `OpenDouListener3D`** | nodo nuevo | Ordena radio de cabeza, HRTF por jugador y seguimiento; prepara VR |
| 7 | **G3 Impactos físicos** | nodo nuevo (`OpenDouPhysicsImpact3D`) | Quita el script repetido en cada `RigidBody3D`; velocidad y masa como RTPC |
| 8 | **C2 Volúmenes de oclusión parcial** | `Area3D` nuevo | Follaje y lluvia son la mitad de los exteriores; sobre el raycast que ya existe |
| 9 | **B5 Campo cercano** | export del emisor + stream | Lo que hace que algo suene *encima*; un biquad |
| 10 | **A2 Directividad** | export del emisor | Primera pieza visible de 7C; con fallback en GDScript se puede adelantar |
| 11 | **G2 Emisor de malla** | nodo nuevo (`OpenDouMeshEmitter3D`) | Fuego y lagos irregulares; necesita una BVH propia porque Godot no da el punto más cercano de una malla |
| 12 | **B6 Altavoz de mundo** | nodo nuevo | Convierte la radio de «La cabina» en un objeto; muy demostrable |
| 13 | **A3 Camas ambisónicas** | nodo nuevo + stream | Cambia cómo se hacen los ambientes |
| 14 | **A1 → A5 → A6 → A4** | recurso · nodo · fusión en `Room3D` · nodo | El camino largo de Steam Audio: materiales, geometría dinámica, reverb por convolución, sondas |

Fuera de la lista y por qué: C3, C4, C5 y C7 son comodidad de autoría, no calidad de sonido;
C6 se fusiona en `OpenDouParameterArea3D` cuando un nivel lo pida; B3 y B4 dependen del juego
que se haga con el plugin.

---

## E. Reglas que toda idea tiene que cumplir para entrar

1. **Se afirma sobre audio capturado**, con un control que apague el mecanismo; si no se puede
   medir, no se promete.
2. **Funciona sin la extensión**, aunque sea peor, o dice en el inspector que necesita el
   backend `steam_audio`.
3. **Se compone en la escena** como nodo con sus exports; el script solo conecta.
4. **Paga su coste a la vista**: entra en el banco del bucle de control o en la guarda del DSP.
5. **No duplica**: si extiende un nodo existente (directividad en el emisor, curva en la
   definición), se extiende; los nodos nuevos son para responsabilidades nuevas.

---

## F. Nodo nuevo, export, recurso o fusión

La regla «la estructura vive en el `.tscn`» no significa «un nodo por funcionalidad». Un nodo
nuevo se justifica cuando tiene **ciclo de vida propio**, **canales de entrada o salida
distintos** o **una responsabilidad que ningún nodo existente tiene**. Lo demás son exports en
el nodo que ya existe o recursos arrastrables, que es lo idiomático en Godot y lo que mantiene
limpio el árbol.

| Idea | Forma correcta | Por qué |
|---|---|---|
| B1 retardo, B2 doppler, B5 campo cercano, A2 directividad | **Exports** de `OpenDouEventPlayer3D` (y su equivalente en `AudioEventDef` para voces anónimas) | Son propiedades físicas de la fuente; un nodo por cada una fragmentaría la autoría |
| A1 materiales acústicos | **Recurso** `AcousticMaterial` asignable al `MeshInstance3D` o al registro del `OpenDouAcousticGeometryBake` | Un material es dato, no comportamiento; el bake ya recorre las mallas |
| C3 curva de atenuación | **Recurso** `Curve` en `AudioEventDef` o en el emisor, como modelo nuevo de `OpenDouDistanceModel` | El inspector de Godot ya sabe dibujar curvas |
| A6 reverb por convolución | **Fusión**: `OpenDouRoom3D.reverb_mode = {SABINE, CONVOLUTION}` | La sala ya es la unidad de reverb; un segundo nodo de zona duplicaría sus límites |
| C6 disparador por lugar | **Fusión**: exports `trigger_event`, `trigger_probability`, `trigger_cooldown`, `trigger_once` en `OpenDouParameterArea3D` | Ya reacciona a entrar y salir; con cuidado de no convertirlo en un cajón de sastre: si crece más, se separa |
| A7 oyente, A3 cama ambisónica, B6 altavoz de mundo | **Nodos nuevos** | Ciclo de vida propio (el oyente), canales distintos (cuatro o nueve de entrada; un bus capturado) y un stream nativo específico cada uno |
| B3 medio, B4 viento, C2 oclusión parcial, C4 descarte, C5 superficie pintada | **Nodos nuevos que heredan de `Area3D`** | Comportamientos acústicos puramente espaciales: el volumen es la responsabilidad |
| A4 sondas, A5 ocluidor dinámico | **Nodos nuevos** | El primero es un volumen de bake, como `VoxelGI`; el segundo registra mallas móviles con transform vivo |
| C1 cadena de masterización | **Nodo**, uno por escena | No es una propiedad de nada; y la guarda de composición necesita algo que exigir |
| C7 planificador de ambiente | **Nodo** | Tiene su propia línea de tiempo; pero entra solo cuando un nivel real lo pida |

---

## G. Huecos frente al estándar AAA que la primera versión no veía

Cuatro cosas que Wwise y FMOD resuelven de forma nativa y que ni los quince nodos actuales ni
las ideas de arriba cubren. Con los hechos comprobados en el código.

### G1. Spread y focus — la fuente grande no colapsa en un punto
- **Problema.** Al pegarte a un río o a una nave, el binaural la reduce a un punto entre los
  oídos. Una fuente grande tiene **tamaño aparente**: cuanto más cerca, más ancho, hasta rodear
  al oyente.
- **Hecho comprobado.** El stream nativo ya tiene `spatial_blend` (0 = sin espacializar, 1 =
  binaural completo), pero hoy es **global**: lo fija el menú del jugador para todos los streams
  del pool. No existe un valor por voz.
- **Cómo.** Export `spread_radius_m` en el emisor (y en la definición). El canal calcula por
  voz `spread = clamp(1 − distancia / spread_radius, 0, 1)` con una curva opcional, y el blend
  efectivo del stream es `blend_global × (1 − spread)`. A `spread = 1` la voz suena «dentro de la
  cabeza», que es lo que hace un río cuando estás en él. Segunda etapa, más fiel: renderizar la
  fuente como dos o tres direcciones HRTF repartidas en el ángulo de spread y decorreladas;
  Steam Audio no lo trae, pero son dos aplicaciones más del efecto binaural por voz, y el
  banco del DSP dirá si cabe.
- **Cuesta.** La primera etapa es baja: un export, una multiplicación en `apply_spatial` y que
  el ajuste global sea un factor y no un valor absoluto. La segunda, media, y se mide.
- **Se afirma.** Fuente a 1 m con `spread_radius_m = 10`: ILD e ITD cercanos a cero; la misma
  fuente a 20 m: los de siempre. Con `spread_radius_m = 0`, sin cambio.

### G2. Emisores de malla — fuego y lagos irregulares
- **Problema.** `OpenDouMultiPositionEmitter3D` y `OpenDouSplineEmitter3D` cubren puntos y
  curvas. Una superficie irregular (un lago, un incendio sobre una malla) necesita el punto
  **de la malla** más cercano al oyente como origen aparente.
- **Hecho comprobado.** Godot no ofrece «punto más cercano de una malla»: `Geometry3D` da el
  del segmento y del triángulo, no de una malla entera, y las consultas de `PhysicsServer3D`
  devuelven contactos, no el punto más próximo.
- **Cómo.** `OpenDouMeshEmitter3D` que toma un `Mesh`, construye al entrar en el árbol una
  jerarquía de cajas (BVH) sobre sus triángulos, y cada frame baja por ella hasta el triángulo
  más cercano y proyecta el oyente en él. Ese punto es `set_position()` de la voz, con
  histéresis para que no salte entre triángulos vecinos. El bake acústico ya recorre mallas:
  la BVH se comparte.
- **Cuesta.** Medio: la BVH es código nuestro, pero es un problema resuelto y cabe en GDScript
  para mallas de miles de triángulos; para más, en C++.
- **Se afirma.** Oyente moviéndose a lo largo de un plano inclinado de 1000 triángulos: el
  origen aparente lo sigue a menos de una arista de distancia, y el coste por frame queda bajo
  un techo escrito.

### G3. Impactos físicos — sin un script por cada cuerpo
- **Problema.** Cada `RigidBody3D` que deba sonar al chocar obliga a escribir el mismo script:
  conectar `body_entered`, leer velocidades, decidir el evento por material.
- **Hecho comprobado.** El `PhysicsMaterial` de Godot solo tiene fricción y rebote: no hay
  material acústico en él. La detección de superficie de las pisadas ya usa metadatos
  `SurfaceType` en los cuerpos; el impacto tiene que leer lo mismo.
- **Cómo.** `OpenDouPhysicsImpact3D`, hijo de un `RigidBody3D` (con `contact_monitor` activo),
  que intercepta `body_entered`, lee el `SurfaceType` de los dos cuerpos, calcula la velocidad
  relativa normal y la masa, y postea el evento con dos RTPC locales (`ImpactForce`,
  `ImpactMass`) y el switch de material. Umbral mínimo y tiempo de recarga para no disparar
  en cada micro-rebote; posición real del contacto.
- **Cuesta.** Bajo. Todo existe salvo el nodo.
- **Se afirma.** Dos cuerpos que chocan a 2 m/s y a 8 m/s: el segundo postea con
  `ImpactForce` cuatro veces mayor y la rama `Metal` si el otro cuerpo lo declara; por debajo
  del umbral, ningún evento.

### G4. Límites de instancias con alcance — la mezcla limpia
- **Problema.** El robo de voces elige por peso (prioridad, sonoridad, distancia) y virtualiza
  a coste cero, pero no sabe de **contexto**: veinte pisadas de veinte soldados a cinco metros
  son veinte voces legítimas y una papilla.
- **Hecho comprobado, y es el más importante de este documento.** `AudioEventDef` declara
  `max_instances: int = 5` desde el principio del proyecto y **ningún código del runtime lo
  lee**: hoy es una promesa que el inspector enseña y nadie cumple. La regla del proyecto es
  que eso no puede quedarse así: se implementa o se quita.
- **Cómo.** En `AudioEventDef`: `max_instances` (global por evento, el que ya está declarado),
  `max_instances_per_emitter`, y `max_instances_in_radius` con `instance_radius_m`. En
  `post_event`, antes de crear la instancia: si se supera el límite, la política decide
  (`REJECT_NEW`, `STEAL_OLDEST`, `STEAL_QUIETEST`, `STEAL_FARTHEST`), con un fundido de salida.
  El conteo por radio recorre las instancias activas del mismo evento: con la cuenta actual
  de instancias es una resta de vectores por instancia, y el banco del bucle lo mide.
- **Cuesta.** Bajo-medio. Y cierra una deuda.
- **Se afirma.** Con `max_instances = 3`, el cuarto `post_event` devuelve una instancia que se
  virtualiza o roba la más antigua según la política, y nunca suenan cuatro voces del evento en
  el bus; con `max_instances_in_radius = 2` y radio 5 m, dos emisores a 1 m no suman una
  tercera voz mientras otro a 50 m sí suena.

### Qué cambia en la lista corta

G4 pasa al primer puesto porque además de calidad de mezcla repara una promesa vacía. G1 entra
en el tercero porque la mitad del trabajo ya está hecha en el stream. G3 y G2 entran detrás del
oyente y de la oclusión parcial: valen, pero no cambian lo que se oye en las demos actuales.

---

## H. Segunda revisión: cuatro propuestas más, lo que aún falta, y qué más se puede fusionar

### H1. Las cuatro propuestas de la segunda revisión, contrastadas con el código

| Propuesta | Qué existe ya | Forma correcta | Veredicto |
|---|---|---|---|
| **Disparador de estados de mezcla global** («Baja salud», «Pausa») | `AudioMixSnapshotManager.transition_to()` y `apply_snapshot_instant()` existen; `OpenDouParameterArea3D` ya activa una instantánea por volumen | **Recurso, no nodo.** Un evento no espacial no tiene posición ni ciclo de vida en la escena: es una vinculación `estado → instantánea` en `GameSyncManager` (recurso `MixStateBinding`: estado, instantánea, tiempo de fundido, prioridad). «Baja salud» es un estado del juego que ya existe como concepto; solo falta que un estado pueda arrastrar una instantánea. Cero nodos | Sí, como recurso |
| **Controlador avanzado de vehículos** (RPM, carga, marcha → síntesis granular cruzada) | `AudioBlendContainer` por RTPC, `AudioGranularSynthesizer`, RTPC locales por instancia | **Ejemplo, no nodo del plugin.** Un motor es un `BlendContainer` de capas granulares gobernado por dos RTPC (`RPM`, `Load`) y un switch de marcha, que ya se puede autorar; lo que falta es una **demo** que lo muestre y un preset del grafo. Un nodo `VehicleAudio` metería en el plugin física de un género concreto | Como demo y plantilla del grafo |
| **Splines direccionales de flujo** (río arriba / río abajo) | `OpenDouSplineEmitter3D` proyecta al punto más cercano con `Curve3D.get_closest_point`; no calcula la tangente | **Export del nodo existente**: `flow_directivity` que evalúa la tangente en el punto más cercano (`Curve3D.sample_baked_with_rotation`) y la usa como eje de directividad (A2) y como signo del doppler (B2, un río que corre hacia ti). Sin nodo nuevo | Sí, como export |
| **Emisor de diálogo narrativo** (subtítulos, ducking absoluto, visemas) | `AudioDialogueManager` con `play_dialogue()`, señales `dialogue_started/finished` y ducking; `AudioDialogueTable` por idioma; la cuadrícula del editor. **Ningún nodo de escena** | **Nodo nuevo justificado**: `OpenDouDialogueEmitter3D`. Ciclo de vida propio (una línea, sus subtítulos, su fin), señales distintas (`subtitle_changed`, `mouth_amplitude`) y la prioridad absoluta del ducking. Sobre los visemas, honestidad: Godot no trae fonemas; lo que se puede dar hoy es la **envolvente de amplitud** de la voz por frame (la sonoridad ya se mide en `AudibleVoiceMonitor`) como un valor de boca abierta, y una pista de marcadores de tiempo del propio WAV para visemas autorados. Fonemas automáticos, no | Sí, como nodo, con los visemas acotados |

### H2. Lo que a mi juicio todavía falta para AAA o más

Puntos que ninguna de las dos revisiones ha nombrado, ordenados por lo que distinguen.

1. **La IA oye: consulta de sonoridad en una posición.** Un juego de sigilo necesita preguntar
   «¿cuánto de este disparo llega a la posición del guardia?». El plugin ya sabe la sonoridad
   de cada voz, la oclusión y el camino por portales **hacia el oyente**; falta el mismo cálculo
   **hacia un punto cualquiera**: `manager.get_loudness_at(position, since_sec)` y una señal
   `sound_heard_at(listener_node, event, loudness)` para nodos `OpenDouAIHearing3D` (un
   `Node3D` con umbral). Es reutilizar el grafo de salas y la oclusión con otro destino, y es
   algo que ni Wwise ni FMOD hacen: el sonido como sistema de percepción, no solo de salida.
   Coste medio; se afirma con un emisor tras una pared: la sonoridad en el punto del guardia
   es menor que sin pared, y con la puerta abierta sube.
2. **Medición de sonoridad por norma (LUFS, EBU R128).** Los estudios mezclan a un objetivo
   de sonoridad integrada (−23 o −16 LUFS según plataforma) con tope de pico verdadero. Hoy el
   perfilador enseña picos y la ventana HDR, pero **no hay medidor LUFS** ni guarda. Un medidor
   en la consola de mezcla y una aserción en la suite («la demo X, medida 30 s, queda entre −25
   y −20 LUFS») convierten la mezcla en algo verificable. Es aritmética sobre el bus (filtro K y
   ventanas de 400 ms), cabe en GDScript o en el nativo.
3. **Marcadores en el audio (cue points) → señales.** Un WAV lleva puntos de cue; un evento
   puede llevar marcadores autorados en el grafo. Que al cruzarlos la voz emita una señal
   (`marker_reached(nombre)`) sincroniza destello con disparo, subtítulo con sílaba, visema
   autorado con voz, y golpe de música con corte de cámara. `OpenDouWavDecoder` ya lee el WAV;
   falta leer el chunk `cue` y comparar la posición de reproducción por frame.
4. **Accesibilidad.** Requisito de certificación en las grandes plataformas: mezcla mono,
   compresión de rango dinámico («modo noche»), indicadores visuales de sonidos importantes
   (el radar ya existe, pero en el editor; en el juego sería un HUD de direcciones), subtítulos
   con hablante y dirección. Casi todo son ajustes del jugador junto a los de espacialización
   que ya persisten en `user://`, más un nodo HUD opcional. Barato y con enorme peso en la
   percepción de calidad.
5. **Voz de red espacializada.** El chat de voz de un multijugador como fuente de una voz 3D
   con oclusión, portales y HRTF: es el altavoz de mundo (B6) con un `AudioStreamGenerator`
   alimentado por la red. Si B6 se hace bien, esto es una demo.
6. **Dos oyentes (pantalla partida).** Godot tiene un solo `AudioListener3D` por viewport y
   una salida. El backend nativo podría renderizar dos oyentes en dos pares de canales
   (izquierda y derecha de un 4.0), pero no hay solución limpia para audífonos. Se anota como
   límite conocido, no como tarea: es una decisión del juego, no del plugin.
7. **Bloqueo de la salida surround del backend nativo.** Ya escrito en el spec 7B: el binaural
   es estéreo. Para 5.1/7.1 de verdad con Steam Audio haría falta decodificar ambisonics a
   altavoces (`IPLAmbisonicsPanningEffect`), que es la misma pieza que A3. Al hacer A3, esto
   sale casi gratis y cierra el hueco.

### H3. ¿Sobra algún nodo? Fusiones que aún caben

Aplicando la misma vara que llevó el reverb por convolución a `OpenDouRoom3D`:

| Nodos propuestos | Fusión | Cómo queda |
|---|---|---|
| B3 medio, B4 viento, C2 oclusión parcial, C4 descarte, C5 superficie pintada | **Un solo `OpenDouAcousticVolume3D` (`Area3D`) con un recurso `AcousticEnvironment`** | Igual que `WorldEnvironment` + `Environment` en Godot: el volumen es el nodo, el comportamiento es dato. El recurso tiene secciones opcionales: medio (velocidad del sonido, paso-bajo, tono), viento (vector, ráfagas), oclusión parcial (dB/m, Hz/m), descarte (categorías), superficie (`SurfaceType` con prioridad). Cinco nodos pasan a uno más un recurso reutilizable entre niveles. Es la fusión más rentable de todo el documento |
| A4 sondas, A5 ocluidor dinámico | **Dentro de `OpenDouAcousticGeometryBake`** | El bake ya recorre el grupo `AcousticObstacle`. Gana un volumen de sondas con su botón (un solo nodo de bake para geometría y propagación, como `VoxelGI`), y un grupo `AcousticObstacleDynamic` cuyas mallas registra como `IPLInstancedMesh` y sigue por transform. Cero nodos nuevos |
| G2 emisor de malla | **Modo de `OpenDouMultiPositionEmitter3D`**: `source_mode = {POINTS, MESH}` | Ambos son «una fuente con muchos orígenes posibles»; el de malla solo añade la BVH. El de spline no se fusiona porque hereda de `Path3D` |
| C1 cadena de masterización | **Ajuste de proyecto + recurso `MixChain`, no nodo** | Master es global, no de una escena: el autoload la instala al arrancar y la guarda comprueba el bus, no el árbol. Un nodo «uno por escena» era una torpeza de la primera versión |
| C7 planificador de ambiente, disparador de estados de mezcla | **Recursos de `GameSyncManager`** (`MixStateBinding`, y la hora del día como un RTPC más) | Ninguno tiene posición; son vinculaciones de estado |
| B6 altavoz de mundo | **Modo de `OpenDouEventPlayer3D`**: `source = BUS_CAPTURE` con `capture_bus` | Un emisor 3D cuya fuente es un bus capturado sigue siendo un emisor 3D: misma posición, oclusión, reverb y directividad. Se ahorra un nodo |
| A7 oyente, A3 cama ambisónica, G3 impactos, diálogo | **Se quedan como nodos** | Ciclo de vida, canales o padre distintos: no hay dónde fusionarlos sin forzar |

Con estas fusiones, las ideas de este documento añaden al plugin **cinco nodos nuevos**
(`OpenDouAcousticVolume3D`, `OpenDouListener3D`, `OpenDouAmbisonicBed3D`,
`OpenDouPhysicsImpact3D`, `OpenDouDialogueEmitter3D`), **cuatro recursos**
(`AcousticMaterial`, `AcousticEnvironment`, `MixStateBinding`, `MixChain`) y una docena de
exports en nodos que ya existen. Quince nodos hoy, veinte al final, y el árbol sigue legible.
