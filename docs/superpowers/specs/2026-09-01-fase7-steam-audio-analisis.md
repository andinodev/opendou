# Fase 7 — Steam Audio en OpenDou: análisis previo al diseño

**Fecha:** 2026-09-01
**Estado:** Análisis. No es un spec: es lo que hay que saber antes de escribirlo.
**Godot verificado:** 4.7.2.stable.official.ed1daf0bf
**Steam Audio verificado:** 4.8.1, Apache 2.0 ([releases](https://github.com/ValveSoftware/steam-audio/releases), [repositorio](https://github.com/ValveSoftware/steam-audio))

---

## 1. El problema que abre esta fase

Probando «Una casa canta» con audífonos de 7.1 virtual, el coche que recorre la calle **no
se puede ubicar**. La causa es doble y las dos partes están verificadas:

1. **Godot 4.7 no tiene HRTF.** `AudioStreamPlayer3D` panea por amplitud, aplica un
   paso-bajo opcional y doppler. Eso produce diferencia de *nivel* entre oídos y nada más.
   Faltan la diferencia de *tiempo* (≈0.6 ms entre oídos) y el filtrado espectral del
   pabellón auricular, que son lo único que distingue delante de detrás y arriba de abajo.
2. **El 7.1 virtual de los audífonos procesa encima.** Godot emite un paneo por amplitud y
   el DSP de los audífonos lo virtualiza como si fuera una sala de siete altavoces. Dos
   procesados apilados. CS2 y Valorant hacen el HRTF *dentro* del juego, emiten estéreo
   binaural, y **recomiendan desactivar el surround virtual de los audífonos**.

Y una tercera cosa que este proyecto tiene que decir de sí mismo: **OpenDou ya prometió
binaural una vez y no lo hacía.** `core/spatial/audio_spatial_binaural.gd` calcula
azimut, elevación, ITD, ILD y cortes de pabellón con la fórmula de Woodworth, y **nadie
consume esos valores a frecuencia de audio**: solo los lee un nodo del grafo del editor
titulado «🎧 Binaural HRTF 3D» y un test que comprueba que la aritmética es correcta. La
Fase 1 lo detectó y retiró el toggle `enable_binaural_hrtf` del emisor con esta frase:
*«un toggle que promete algo imposible en esta arquitectura no debe sobrevivir»*. Esta
fase es la que puede hacer que la promesa vuelva a existir, esta vez cierta.

---

## 2. Por qué no se puede hacer con lo que hay

**En GDScript, no.** Un HRTF es una convolución de 256–512 coeficientes por oído, por
muestra, a 44.1/48 kHz: unos **50 millones de multiplicaciones por segundo por voz**.
GDScript hace del orden de 10–50 millones de operaciones simples por segundo *en total*.
No entra una voz. Este proyecto ya lo aprendió: la Fase 2 **borró** el reverb por
convolución en GDScript (512 taps por muestra) porque era inusable. Los 3.9 µs por voz y
frame que medimos en la Fase 6 son el *plano de control*; el DSP a frecuencia de audio
está tres o cuatro órdenes de magnitud por encima.

**Modificando Godot, tampoco.** Un fork con HRTF obligaría a cada usuario del plugin a
compilar su propio motor. Muerto como distribuible.

**Con la integración comunitaria, tampoco tal cual.** Existe
[`godot-steam-audio`](https://github.com/stechyo/godot-steam-audio) (MIT, Godot 4.4). Su
propio autor la declara *alfa*, con caídas conocidas, **sin HRTF binaural** —no era
prioridad— y *«no apta para publicar un juego sin arreglos propios»*. Su arquitectura sí es
una referencia válida: un servidor singleton que posee el contexto y el simulador, un
`AudioStream`/`AudioStreamPlayback` propio que aplica los efectos al mezclar, y nodos de
geometría, oyente y configuración. Es el mismo patrón que hay que construir, pero
construido.

**Lo que sí: una GDExtension propia, pequeña, en C++.** Godot solo deja implementar el
`_mix()` de un `AudioStreamPlayback` desde GDExtension —la documentación lo dice
literalmente: *«no es útil sobrescribirlo en GDScript; solo GDExtension puede aprovecharlo»*—.
Y el proyecto ya lo tenía previsto: `docs/architecture/gdextension_api.md` especifica
desde el principio una capa nativa con **patrón de doble backend** —si la librería está,
se usa; si no, se cae al GDScript— y binarios en `addons/opendou/bin/`. El README lo marca
como *planificado, no implementado*. Esta fase es la que lo implementa.

---

## 3. Qué es Steam Audio 4.8.1, exactamente

Todo lo de abajo está tomado de la [documentación oficial de la C API](https://valvesoftware.github.io/steam-audio/doc/capi/index.html).

| Capacidad | Qué hace | Objeto de la API |
|---|---|---|
| **Binaural HRTF** | Convolución por voz con un HRTF; interpolación *nearest* o *bilineal* entre las 4 direcciones más cercanas; `spatialBlend` 0–1 entre seco y espacializado; entrada mono o estéreo, salida estéreo | `IPLBinauralEffect`, `IPLHRTF` |
| **HRTF personalizado** | Carga archivos **SOFA** (convención `SimpleFreeFieldHRIR`), remuestrea al mix rate en tiempo de ejecución | `IPL_HRTFTYPE_SOFA` |
| **Efecto directo** | Atenuación por distancia (modelo por defecto o propio), **absorción del aire en 3 bandas**, **directividad** (dipolo ponderado: `dipoleWeight`, `dipolePower`), **oclusión** 0–1 (por raycast o **volumétrica** para fuentes no puntuales), **transmisión en 3 bandas** a través del material | `IPLDirectEffect`, `IPLDirectEffectParams` |
| **Reflexiones** | Trazado de rayos contra la geometría; render por **convolución** (IR ambisónica de orden configurable), **paramétrico**, **híbrido** o TrueAudio Next (GPU); en **tiempo real** o **precocinadas** | `IPLReflectionEffect`, `iplSimulatorRunReflections`, `iplReflectionsBakerBake` |
| **Propagación por caminos** | Sondas por el nivel, precocinado, y en tiempo de ejecución el sonido **rodea esquinas y atraviesa puertas** siguiendo caminos válidos; caminos alternativos; salida ambisónica | `IPLPathEffect`, `IPLProbeBatch`, `IPL_BAKEDDATATYPE_PATHING` |
| **Ambisonics** | Codificar mono a orden N, rotar con la orientación del oyente, decodificar a **binaural** o a altavoces | `IPLAmbisonicsEncodeEffect`, `IPLAmbisonicsDecodeEffect` (`binaural = IPL_TRUE`) |
| **Escena** | Mallas **estáticas** e **instanciadas** (rígidas, con transform actualizable); trazador propio, Embree o Radeon Rays | `IPLScene`, `IPLStaticMesh`, `IPLInstancedMesh` |
| **Materiales** | Por triángulo: **absorción, dispersión y transmisión, cada una en 3 bandas** | `IPLMaterial` |
| **Simulador** | Entradas por fuente (posición, flags, oclusión, directividad, reverb por banda, sondas) y compartidas (oyente, rayos, rebotes, duración); salidas por fuente: `direct`, `reflections`, `pathing` | `IPLSimulator`, `IPLSource`, `IPLSimulationOutputs` |
| **Audio** | `samplingRate` 44.1/48 kHz y `frameSize` fijo (p. ej. 1024); los efectos procesan **exactamente** un frame por llamada | `IPLAudioSettings`, `IPLAudioBuffer` |

**Hilos, según la guía oficial:** `iplSimulatorRunDirect` *no debe llamarse desde el hilo
de audio si hay oclusión o transmisión*; `RunReflections` y `RunPathing` *«pueden ser
intensivos en CPU y deben ir en un hilo aparte»*. Las salidas se recogen con
`iplSourceGetOutputs` y los efectos las aplican en el hilo de audio; direct y reflections
pueden ir en hilos distintos **sin sincronización** entre sí.

**Plataformas:** Windows, Linux, macOS, Android, iOS. WebAssembly: **experimental**
(desde la 4.6.0). Eso importa para el patrón de doble backend: la exportación web se
queda con el panner de Godot.

---

## 4. Cómo se engancha con Godot

El hueco que Godot deja abierto es exactamente el que hace falta:

```
OpenDou (GDScript, plano de control)          GDExtension (C++, DSP)
────────────────────────────────────          ─────────────────────────────────────
PhysicalVoiceChannel                          OpenDouSpatialStream : AudioStream
  ├─ decide QUE voz suena                       └─ OpenDouSpatialPlayback : AudioStreamPlayback
  ├─ DONDE (posicion aparente, sala, portal)        ├─ _mix(): tira del stream interno,
  ├─ con QUE filtro/atenuacion                       │   acumula en anillo hasta frameSize,
  └─ set_direction/distance/occlusion cada frame     │   aplica DirectEffect + BinauralEffect,
                                                     │   escribe estereo al buffer de Godot
  reproduce con un AudioStreamPlayer ESTEREO         └─ parametros atomicos, sin bloquear
  normal, saltandose el panner 3D de Godot
```

Tres consecuencias de diseño que ya se ven desde aquí:

1. **El adaptador de frames es obligatorio.** Godot llama a `_mix()` con un número
   variable de frames; Steam Audio consume exactamente `frameSize`. Hace falta un anillo
   entre los dos. Añade latencia: con `frameSize = 1024` a 44.1 kHz son ~23 ms, encima de
   los ~15 ms de salida de Godot. Es el precio del HRTF y hay que medirlo.
2. **El oyente lo ponemos nosotros.** La dirección del `IPLBinauralEffect` va *en el
   sistema de coordenadas del oyente*. El resolutor de oyente de la Fase 1 ya sabe quién
   es; solo hay que darle al stream la posición **relativa y rotada**, cada frame.
3. **Al ser nuestro el panner, el origen aparente relocaliza por fin a los emisores de
   nodo.** La limitación documentada en la Fase 6 —«la música se filtra por la ventana
   pero su paneo sigue dentro»— desaparece sola: no hay ningún `AudioStreamPlayer3D` cuyo
   transform respetar.

---

## 5. Mapa pieza a pieza: lo que tenemos, y qué le pasa

Inventario real del subsistema espacial hoy: 15 archivos en `runtime/spatial/`, 15 nodos
declarativos, más `core/spatial/`. Para cada pieza, una de cuatro cosas: **se queda**,
**se potencia**, **se sustituye** o **se retira**.

### Se queda: el plano de control es nuestro y es bueno

| Pieza | Por qué se queda |
|---|---|
| `AudioEventManager`, pool de voces, voice stealing, HDR | No tienen nada que ver con el render. Steam Audio no gestiona voces ni prioridades: eso lo sigue haciendo OpenDou, y es lo que la Fase 3 y la 5 dejaron sólido |
| Eventos, contenedores (switch/random/blend), RTPC, states, switches, triggers, bancos | Ídem. Steam Audio recibe un buffer y una dirección; de dónde sale ese buffer es cosa nuestra |
| `OpenDouRoom3D`, `OpenDouPortal3D`, grafo de salas, `OpenDouRoomPathDispatcher` | La propagación por caminos de Steam Audio necesita **sondas precocinadas**; nuestro grafo de portales es **autorado**, cuesta 0.093 ms con 200 voces y ya funciona. Se queda como propagación barata y determinista; la de Steam Audio es una opción encima para niveles grandes (§6) |
| `OpenDouAcousticGeometryBake` | **Es la pieza que más se revaloriza.** Hoy recoge triángulos de las mallas del grupo con su material y solo alimenta un raycast propio. Es *exactamente* lo que `IPLStaticMesh` necesita: vértices, triángulos e índices de material. El bake pasa de ser una curiosidad a ser **la escena acústica de Steam Audio** |
| `AcousticLODController` | Steam Audio cobra por fuente y por rayo. Alguien tiene que decidir qué voces reciben reflexiones y cuáles solo direct. Es este |
| Doppler | Steam Audio **no hace doppler**. Hoy lo hace el `AudioStreamPlayer3D` de Godot, y en modo binaural ya no habrá uno. Se implementa en el stream propio vía `calculated_pitch_scale`, que ya existe |
| Voces 2D y no espaciales, radio, música, UI | Pasan de largo. No tocan Steam Audio |

### Se potencia: lo que hoy hacemos a mano, con física de verdad

| Pieza hoy | Con Steam Audio |
|---|---|
| **Oclusión** (`OcclusionScheduler`): un raycast por voz, presupuestado, produce un corte de paso-bajo y una atenuación escalar | `IPLDirectEffect` con **oclusión volumétrica** (una ventana tapa parcialmente, no todo o nada) y **transmisión en 3 bandas por material**: la música a través del cristal suena distinta que a través del ladrillo, porque son coeficientes distintos por banda. El presupuesto y el round-robin se quedan; lo que cambia es la calidad de lo que se calcula |
| **Materiales** (`AcousticMaterialRegistry`): densidad, corte de resonancia y **una** absorción por material | **Tres bandas** de absorción, dispersión y transmisión por material → `IPLMaterial`. El vocabulario de ocho nombres se mantiene; cada nombre gana ocho números más. `surface_type` sigue siendo la metadata que todo lee |
| **Reflexiones tempranas** (`ReflectionDispatcher`): hasta 16 voces del pool reproduciendo copias retrasadas contra reflectores planos autorados | `IPLReflectionEffect` con **IR por convolución trazada contra la geometría real**: no dos rebotes contra cuatro planos declarados, sino cientos de rayos contra cada pared del bake. Los `OpenDouReflector3D` dejan de ser necesarios como fuente de verdad; pueden quedarse como *ajuste artístico* (Steam Audio lo permite explícitamente) |
| **Reverb por sala** (`ReverbBusPool`): hasta 8 `AudioEffectReverb` escalonados por RT60 de Sabine | Dos opciones, no excluyentes: **reverb centrado en el oyente** de Steam Audio (una IR para la sala donde estás, barato, sustituye al pool) o **reflexiones por fuente** (una IR por voz, caro, para las que importan). El pool de Godot se queda como *fallback* del doble backend |
| **`IRRT60Analyzer`** (Schroeder + T20): hoy analiza IRs que nadie produce | Steam Audio **produce IRs reales** de cada sala. El analizador pasa a tener materia prima: derivar el RT60 real de la geometría para alimentar el fallback y para mostrarlo en el depurador |
| **Origen aparente** (Fase 6): posición del portal, pero no relocaliza emisores de nodo | Relocaliza **todo**, porque el panner es nuestro (§4) |
| **`OpenDouAcousticDebugger3D`**: esferas y rayos de oclusión propios | Steam Audio expone un **callback de visualización de caminos** (`pathingVisCallback`). El depurador puede dibujar los rayos y caminos que de verdad se están usando, no una estimación paralela |

### Se sustituye o se retira: lo que ya no tiene sentido mantener

| Pieza | Qué pasa | Por qué |
|---|---|---|
| `AudioSpatialBinaural` (GDScript, Woodworth) | **Se retira** | Calculaba pistas que nadie consumía. El binaural pasa a ser real y en C++. Se conserva en el historial; su test se convierte en el test del binaural de verdad (§8) |
| `EdgeDiffractionEngine` (91 líneas, **inerte**: nadie lo invoca desde el runtime) | **Se retira** | La difracción alrededor de aristas es lo que hace la propagación por caminos de Steam Audio, con sondas y de verdad. Observación 36 cerrada por sustitución |
| `RoomCouplingEngine` (73 líneas, **inerte**) | **Se retira** | El acoplamiento de energía entre salas por portal lo modelan las reflexiones y los caminos de Steam Audio a partir de la geometría |
| `OcclusionManager` (36 líneas: mapea "hay pared" a un corte) | **Se sustituye** por la salida `direct` del simulador | El mapeo a mano queda obsoleto cuando el motor devuelve oclusión y transmisión por banda |
| El panner 3D de Godot para voces del pool | **Se sustituye** por el stream propio en el backend nativo | Es el objeto de la fase |
| El nodo del grafo «🎧 Binaural HRTF 3D» del editor | **Se reescribe** para leer los parámetros reales del efecto binaural | Hoy enseña una fórmula; puede enseñar el HRTF activo, la interpolación y el `spatialBlend` |

---

## 6. Cosas nuevas que se pueden crear

Ordenadas de menos a más ambiciosas. Ninguna existe hoy en el plugin.

1. **Directividad por emisor.** Un export `directivity_dipole_weight` / `dipole_power` en
   `OpenDouEventPlayer3D`. La radio de «La cabina» suena hacia delante; el tubo de escape
   del coche, hacia atrás; una boca humana, hacia donde mira. Steam Audio lo hace en el
   efecto directo; hoy no existe ni la noción.
2. **Transmisión por material en 3 bandas.** La música de «Una casa canta» a través del
   cristal entreabierto, del cristal cerrado, del ladrillo y de la medianera gruesa: cuatro
   timbres distintos con la **misma** fuente, porque cada superficie tiene su
   `transmission[3]`. Hoy son un corte de paso-bajo escalar.
3. **HRTF por usuario y conmutador audífonos/altavoces.** Cargar un SOFA propio desde el
   menú de sonido que la última fase añadió; `spatialBlend` como deslizador («cuánto
   HRTF»); y el conmutador que CS2 y Valorant tienen porque el HRTF **es personal**: los
   datasets genéricos funcionan para la mayoría, no para todos.
4. **Camas ambisónicas.** Un `OpenDouAmbisonicPlayer` para ambientes que **rodean**: la
   lluvia del monzón como campo ambisónico de orden 1 o 2 que rota con la cabeza, en lugar
   de 200 fuentes puntuales. Menos voces, más envolvente, y es lo que hace un ambiente
   sonar a *estar ahí*.
5. **Reverb por convolución desde la geometría.** Adiós a la aproximación de Sabine como
   única fuente: la IR de cada sala sale de trazar rayos contra sus paredes reales, con sus
   materiales reales. La sala de máquinas de metal y la bahía de agua de «Bajo la quilla»
   dejan de ser dos presets y pasan a ser dos respuestas medidas.
6. **Propagación precocinada para niveles grandes.** Sondas por el nivel, bake, y el
   sonido rodea esquinas que ningún portal autorado describió. Complementa al grafo de
   portales, no lo sustituye: el grafo es para lo que el diseñador quiere controlar; las
   sondas, para lo que no quiere autorar a mano.
7. **Simulación en su hilo, con LOD.** Direct para todas las voces físicas; reflexiones
   solo para las que el LOD marque; pathing solo donde haya sondas. El controlador de LOD
   deja de ser un filtro de raycasts y pasa a ser **el presupuesto de la simulación**.
8. **Geometría dinámica.** `IPLInstancedMesh` con transform actualizable: la **hoja de la
   puerta** de «Una casa canta» ya gira; con esto, además de mover el portal, *ocluye* de
   verdad mientras gira.

---

## 7. Lo que cuesta, dicho sin adornos

| Coste | Detalle |
|---|---|
| **Un toolchain nuevo** | C++17, `godot-cpp` para 4.7, CMake o SCons, y la propia Steam Audio como dependencia (binaria o compilada). Nada de esto existe hoy en el repo |
| **Binarios por plataforma** | Windows x64, Linux x64, macOS (universal, y con la firma/notarización de la `.dylib` para que Gatekeeper no la bloquee), Android arm64, iOS. Cada uno hay que compilarlo y probarlo. Un CI que no existe hoy |
| **La promesa «GDScript puro» termina** | Está escrita en el README y en varios specs. Deja de ser cierta y hay que actualizarlo el mismo día que entre la primera línea de C++. El patrón de doble backend hace que **siga siendo cierto que el plugin funciona sin la librería**, pero con el panner de Godot |
| **Latencia** | El anillo de `frameSize` añade ~23 ms a 1024 muestras. Para música y ambientes es irrelevante; para un disparo propio se nota. `frameSize` más pequeño baja la latencia y sube la CPU. Hay que medir y exponerlo como ajuste |
| **CPU real** | Binaural por voz es barato en C++ (un juego mezcla 32 voces binaurales sin despeinarse). Reflexiones por convolución por fuente **no**: por eso el LOD decide y el reverb centrado en el oyente existe |
| **Web** | WebAssembly es experimental en Steam Audio. La exportación web se queda con el fallback. Hay que decirlo en la documentación |
| **Licencia** | Apache 2.0 exige conservar el aviso de copyright y el `NOTICE`. Trivial, pero obligatorio |
| **Verificación auditiva** | La suite puede afirmar ITD, ILD y espectro (§8). Que *suene bien* lo juzgan oídos, y el HRTF es personal |

---

## 8. Cómo se verifica sin engañarnos

La misma disciplina de siempre —aserciones que fallan cuando el mecanismo se rompe— se
puede aplicar al binaural, y de hecho es más fácil que con el paneo por amplitud:

| Qué se afirma | Cómo |
|---|---|
| **ITD**: una fuente a 90° llega antes al oído cercano | Capturar el estéreo del bus de la voz; correlación cruzada L/R; el retardo del pico tiene que estar entre 0.5 y 0.7 ms y con el signo correcto. Con el HRTF apagado (`spatialBlend = 0`) el retardo es **cero**: la aserción tiene que fallar |
| **ILD**: el oído lejano recibe menos nivel | Pico RMS de cada canal; diferencia > 6 dB a 90°, ≈0 dB de frente |
| **Delante / detrás**: distinto espectro | Centroide espectral de una fuente a 0° frente a la misma a 180°: tienen que diferir. Es la aserción que el paneo por amplitud **no puede pasar**, porque para él delante y detrás son idénticos |
| **Elevación** | Ídem con 0° frente a +60° |
| **Transmisión por banda** | La misma fuente tras `Glass` y tras `Concrete`: espectros medibles distintos en el bus |
| **Fallback** | Sin la librería nativa, todo lo anterior se salta y la suite de la Fase 1–6 sigue verde: el plugin funciona sin ella |
| **Latencia y coste** | Frames del anillo y `frameSize` expuestos; una guarda cuenta que ninguna voz se procesa dos veces por frame |

Las de espectro y correlación son aritmética sobre `PackedVector2Array`: caben en el
`OpenDouAudioProbe` que ya existe.

---

## 9. Propuesta de descomposición

Demasiado para un solo spec. Cuatro fases, cada una con su spec, su plan y su verificación,
y cada una útil por sí sola:

| Fase | Entrega | Lo que demuestra |
|---|---|---|
| **7A — El spike** | Toolchain, `godot-cpp`, Steam Audio enlazada, **una** voz binaural con `IPLBinauralEffect` y el adaptador de frames; aserciones de ITD/ILD/delante-detrás; el doble backend funcionando (sin la `.dylib`, panner de Godot) | Que la arquitectura es viable, cuánta latencia cuesta, y que el CI compila en las tres plataformas de escritorio. **Si esto no sale, el resto no se empieza** |
| **7B — Binaural para todas las voces + efecto directo** | Todas las voces físicas por el stream propio; `IPLDirectEffect` sustituye a `OcclusionManager`; materiales a 3 bandas; el bake alimenta `IPLStaticMesh`; doppler propio; origen aparente relocalizando emisores de nodo; menú de sonido con HRTF/SOFA, `spatialBlend` y conmutador | El coche de la calle se ubica. La música atraviesa el cristal y el ladrillo con timbres distintos |
| **7C — Reflexiones y ambisonics** | Reverb centrado en el oyente por convolución; reflexiones por fuente bajo LOD; `IRRT60Analyzer` sobre IRs reales; `OpenDouAmbisonicPlayer`; retirada de `ReflectionDispatcher` como fuente de verdad | La sala de máquinas y la bahía dejan de ser presets. La lluvia rodea |
| **7D — Propagación, directividad y geometría dinámica** | Sondas y bake de pathing; `directivity` en el emisor; `IPLInstancedMesh` para puertas; depurador dibujando los caminos reales; retirada definitiva de `EdgeDiffractionEngine` y `RoomCouplingEngine` | El sonido rodea esquinas que nadie autoró. La puerta ocluye mientras gira |

---

## 10. Preguntas abiertas que el spec de 7A tiene que cerrar

1. **Steam Audio como dependencia binaria o compilada desde fuente?** Binaria es más
   rápido de arrancar; desde fuente da control total y evita depender de que Valve publique
   para cada plataforma. Recomendación provisional: binaria en 7A, decidir en 7B.
2. **CMake o SCons?** `godot-cpp` soporta ambos. Steam Audio usa CMake. Recomendación:
   CMake, para tener una sola herramienta.
3. **Dónde vive el código nativo?** El doc de arquitectura dice `src/` o `native/` en la
   raíz, con binarios en `addons/opendou/bin/`. Hay que fijarlo.
4. **`frameSize` por defecto: 1024 o 512?** Es latencia contra CPU. Recomendación: 512 por
   defecto, exponerlo, medir las dos.
5. **Qué plataformas compila el CI en 7A?** Recomendación: las tres de escritorio.
   Android e iOS en 7B, cuando la arquitectura esté fija.
6. **Se conserva el pool de reverb de Godot como fallback permanente, o solo hasta 7C?**
   Recomendación: permanente, porque la exportación web nunca tendrá la librería.

---

## 11. Resultados del spike 7A (2026-09-02)

La pregunta era: ¿puede una voz de Godot 4.7 salir por Steam Audio, y hace el HRTF algo que se
pueda medir? **Sí a las dos.** Todo lo de abajo lo afirma `tests/test_binaural_spike.gd` sobre
audio capturado del bus, con controles que apagan el HRTF para que la medida no sea vacua.

**Lo construido (código de spike, no de producto).** `native/` con godot-cpp *master* (API 4.7,
no existe rama 4.6/4.7) enlazado a `libphonon.dylib` 4.8.1; una clase `OpenDouSpatialStream`
(`AudioStream`) que envuelve otro stream y lo pasa por `iplBinauralEffectApply` en bloques de
512 muestras con un anillo de 2×512. Carga en el editor y en headless.

| Medida | Resultado | Control (HRTF apagado) |
|---|---|---|
| Latencia añadida | 11.6 ms (512 @ 44.1 kHz) | — |
| ILD, fuente a la derecha | +17 dB (R−L) | 0.00 dB |
| ILD, fuente a la izquierda | −14 dB | — |
| Delante/detrás, banda 5–10 kHz / 1–4 kHz | 15.9 % de diferencia | 2.5 % |
| ITD medido en la salida | **0 muestras** | 0 |
| `peakDelays` reportados, fuente a la derecha | L 0.363 ms, R 0.227 ms | — |
| `peakDelays`, fuente a la izquierda | L 0.136 ms, R 0.522 ms | — |

**Hallazgo principal: la API C pública NO renderiza el ITD.** El estimador de ITD recupera un
retardo sintético de 25 muestras, así que el cero es real. La fuente de Steam Audio lo explica:
`BinauralEffectParams::phaseType` vale `HRTFPhaseType::None` («respuesta de fase plana») por
defecto, `api_binaural_effect.cpp` nunca lo cambia, y `binaural_effect.cpp` solo *escribe* los
retardos de pico en `peakDelays` sin aplicarlos al audio. Steam Audio entrega la magnitud del
HRTF (ILD y coloración del pabellón) y deja el retardo interaural en manos de quien llama.
**Para 7B esto es un requisito, no un detalle:** el panner de OpenDou tiene que aplicar una línea
de retardo fraccionaria por oído con los `peakDelays` de cada bloque (interpolando entre bloques
para no hacer clic al girar). Sin eso, la localización lateral tendría la mitad de las pistas.
El spike lo afirma en la dirección real (lag ≈ 0 y `peakDelays` distintos) para que, si una
versión futura empieza a hornear el ITD, la línea de retardo no lo aplique dos veces.

**Convención de ejes.** Steam Audio es diestro con +X derecha, +Y arriba, −Z adelante: la misma
de Godot. No hace falta convertir direcciones.

**Lecciones de infraestructura.**
- Una `.dylib` descargada desde el navegador trae `com.apple.quarantine` y macOS la rechaza con
  «library load disallowed by system policy». Hay que quitar el atributo y firmar *ad hoc* las
  dos bibliotecas; el CMake lo hace en POST_BUILD. La distribución real (7B) necesita firma.
- `AudioStreamPlayback.mix_audio()` devuelve un `PackedVector2Array` nuevo por llamada: reserva
  memoria en el hilo de audio. Aceptable para el spike; 7B tiene que mezclar sobre un buffer
  propio o cambiar el punto de enganche.
- La medida delante/detrás con ruido blanco continuo oscilaba de 2 a 20 % entre corridas según
  el segmento capturado. Con una fuente periódica de 1024 muestras y bandas alineadas al
  periodo, tres corridas dan valores idénticos. La lección vale para 7B: los tests binaurales
  usan fuentes periódicas.
- El spike no relocaliza emisores propiedad de un nodo (`AudioStreamPlayer3D`): envuelve el
  stream, no el panner. 7B resuelve eso siendo dueño del panner.

## Fuentes

- [Steam Audio — releases](https://github.com/ValveSoftware/steam-audio/releases) · [repositorio](https://github.com/ValveSoftware/steam-audio) (Apache 2.0, 4.8.1)
- [Steam Audio — C API: índice](https://valvesoftware.github.io/steam-audio/doc/capi/index.html) · [guía](https://valvesoftware.github.io/steam-audio/doc/capi/guide.html) · [efecto binaural](https://valvesoftware.github.io/steam-audio/doc/capi/binaural-effect.html) · [efecto directo](https://valvesoftware.github.io/steam-audio/doc/capi/direct-effect.html) · [simulación](https://valvesoftware.github.io/steam-audio/doc/capi/simulation.html)
- [godot-steam-audio (stechyo)](https://github.com/stechyo/godot-steam-audio) — alfa, MIT, Godot 4.4, sin HRTF
- [Godot — `AudioStreamPlayback`](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayback.html) — `_mix()` solo desde GDExtension
- `docs/architecture/gdextension_api.md` — la capa nativa planificada, con doble backend
- `docs/superpowers/specs/2026-09-01-fase1-cadena-audio-real-design.md` §"enable_binaural_hrtf" — la retirada del toggle
