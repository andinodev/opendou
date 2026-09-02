# Fase 5 — Las tres demos

**Fecha:** 2026-09-01
**Estado:** Diseño aprobado, pendiente de plan de implementación
**Rama:** `main` (este proyecto trabaja en una sola rama)
**Godot verificado:** 4.7.2.stable.official.ed1daf0bf
**Fases anteriores:** [1](2026-09-01-fase1-cadena-audio-real-design.md) · [2](2026-09-01-fase2-correccion-espacial-design.md) · [3](2026-09-01-fase3-rendimiento-design.md) · [4A](2026-09-01-fase4a-distribuible-design.md)

---

## 1. Contexto

Cuando el proyecto se descompuso en cinco fases, las demos se definieron como **el
criterio de aceptación de todo lo demás**: si las tres se pueden construir con
`post_event()` en lugar de `.play()` nativo, el motor está arreglado de verdad.

Llevamos cuatro fases y 611 aserciones arreglando el motor, y **nadie lo ha usado
todavía como lo usaría un diseñador de audio en una escena real**. Esta fase es esa
prueba.

Las 10 demos actuales se borran. Su test más profundo afirmaba `chunk.size() != 12`, y
seis de ellas ni siquiera podían sonar antes de la Fase 1.

### Dos defectos que esta fase tiene que arreglar primero

Al revisar cómo se construyen las pisadas apareció un defecto que no estaba entre las
24 observaciones. `OpenDouAnimationSync.trigger_footstep()` invoca:

```gdscript
surface = _event_manager.spatial_acoustics.detect_surface_at(pos)
```

con un solo argumento. La firma es `detect_surface_at(pos, world_3d = null)`, y su
**prioridad 1 —el raycast hacia abajo— solo se ejecuta si `world_3d != null`**. Así que
`AnimationSync` nunca raycastea: cae directo a la prioridad 2, el `floor_surface` de la
sala que contenga la posición.

Consecuencia: **las pisadas solo varían si el personaje está dentro de un
`OpenDouRoom3D` con `floor_surface` puesto**. Caminar sobre tres parches de material
distinto dentro de la misma sala produce tres pisadas idénticas.

Es la **observación 25** del proyecto, y va como primer trabajo de la fase: el rig de
personaje y el banco dependen de que la detección funcione.

#### Observación 26: el contexto de reproducción no se construye nunca

Más grave que la anterior. `AudioSwitchContainer` lee `context.get_switch()` y
`AudioBlendContainer` lee `context.get_rtpc()`, pero **nadie en el runtime construye un
`AudioPlaybackContext` poblado**: `VoicePoolManager.devirtualize()` invoca
`instance.definition.resolve_voices()` sin argumento, así que se crea uno vacío.

| Contenedor | Lee del contexto | Estado real en runtime |
|---|---|---|
| `AudioSwitchContainer` | `get_switch()` | Resuelve **siempre** a `default_state` |
| `AudioBlendContainer` | `get_rtpc()` | Ve **siempre** RTPC = 0.0 |
| `AudioRandomContainer` | nada | Funciona |
| `AudioSequenceContainer` | nada | Funciona |

Una pisada con switch container sonaría siempre a la misma superficie, y un motor con
blend container se quedaría siempre en ralentí.

**Los tests pasan** porque construyen el contexto a mano
(`AudioPlaybackContext.new({&"RPM": 4000.0})`): correcto en aislamiento, desconectado
en el camino real. Es **exactamente la misma forma que la observación 1** — la
maquinaria calcula bien y nadie la alimenta.

**Dirección del arreglo.** El contexto es **por instancia**, no global: `EventInstance`
ya tiene `local_rtpcs` y `GameSyncManager` tiene switches por entidad, así que el
contexto correcto compone globales con locales en el momento de resolver.
`AudioEventManager` ya pasa `global_rtpcs` a `update_parameters()` cada frame; falta
hacer lo propio con los switches y que `devirtualize()` pase el contexto a
`resolve_voices()`.

Va como segundo trabajo de la fase, porque el evento de pisada del apartado 3.3
depende de él.

### Marco elegido: una tesis por demo

Cada demo prueba **una** cosa difícil de falsear. La cobertura de nodos es
consecuencia, no objetivo: un catálogo de características no convence a nadie de que
el motor funciona.

---

## 2. Restricciones de diseño

**Cero assets de audio.** Clonar el repositorio y pulsar play debe dar un paisaje
sonoro completo sin un solo `.wav`. Es la propiedad más distintiva de estas demos, y
la paleta del addon está construida para ello: 22 generadores en `AudioSynthesizer`
(lluvia, viento, truenos, cigarras, ranas, gotas, pájaros, motor, disparos, pisadas
por superficie, stems musicales, stingers), el motor modular con osciladores y filtros,
y 104 presets autorados.

**La clave de metadata es `surface_type`.** Es la que leen **los dos** sistemas:
`detect_surface_at()` busca `surface_type` en el collider, y `AcousticReflectorEngine`
busca `acoustic_material` primero pero acepta `surface_type` como alternativa. Usar
`acoustic_material` funcionaría para las reflexiones y no para las pisadas.

**Ocho nombres de superficie, no once.** `create_footstep` acepta 11 superficies y el
registro acústico define 8. Los **8 comunes** —`Concrete`, `Stone`, `Metal`, `Glass`,
`Wood`, `Foliage`, `Water`, `Asphalt`— son el vocabulario de la metadata. Los tres que
solo existen para pisadas (`Grass`, `Mud`, `Tile`) no se usan en las demos: una
superficie que el motor de reflexiones no entiende produciría acústica y pisadas
incoherentes.

**`OpenDouEventPlayer2D` queda cubierto solo por los tests.** No tiene hogar natural en
tres escenas 3D y forzarlo produciría una capa 2D artificial. Decisión explícita, no
descuido.

---

## 3. El rig de personaje compartido

Vive en `scenes/shared/`, **no en el addon**: es contenido de juego con opiniones (qué
es una pisada, cómo patrulla un NPC), y la Fase 4A acabó de dejar el addon
autocontenido.

Las tres demos y el banco lo instancian. No es solo ahorro de trabajo: **mejora las
demos**. Unos pasos de NPC oídos a través de una escotilla que se cierra demuestran
más que una válvula, porque el oyente *sabe* cómo deberían sonar unos pasos. Y en «El
monzón» los NPC pasan a ser parte de los emisores que presionan el pool.

### 3.1 Cinco decisiones de diseño

**El oyente lo lleva solo el jugador.** El resolutor de la Fase 1 usa el
`AudioListener3D` activo y, en su defecto, la cámara activa. Si el rig incluyera un
listener y se instanciase para tres NPC, habría cuatro oyentes compitiendo. El rig se
parte: **cuerpo y emisores** son comunes; **el oyente es del jugador**.

**La detección de superficie no se escribe: ya existe.** El diseño inicial preveía un
`surface_probe.gd` propio. Es innecesario:
`SpatialAcousticsManager.detect_surface_at()` ya hace exactamente eso, y con más
prioridades —raycast leyendo metadata, material físico del cuerpo, palabras clave del
nombre del collider, `floor_surface` de la sala, y `Concrete` como último recurso—.
El rig usa `AnimationSync`, que ya la invoca.

Lo que sí es una decisión: **una sola clave de metadata**, `surface_type`, consumida
tanto por el motor de reflexiones como por las pisadas. El suelo dice lo que es una
vez. Dos convenciones para la misma cosa es cómo se acumulan las inconsistencias.

**Composición, no herencia.** Un rig de audio autocontenido que no sabe si lo mueve un
humano o una IA, y dos controladores hermanos que mueven el mismo cuerpo. Si el rig
tuviera que saberlo, cada demo acabaría con su variante.

**Los controladores son andamio.** Caminar y patrullar. Ni salto, ni escalada, ni
máquina de estados de combate: no es trabajo de audio y engordaría la fase sin
demostrar nada del plugin.

**El rig es testeable en headless.** Se puede afirmar que un paso dispara su evento,
que la superficie cambia con la metadata que hay debajo, y que el jugador lleva oyente
y el NPC no.

### 3.2 Componentes

| Archivo | Responsabilidad |
|---|---|
| `scenes/shared/character_audio_rig.gd` | El rig: `OpenDouEventPlayer3D` para pisadas y foley, `OpenDouAnimationSync` para el despacho por superficie. Sin oyente. |
| `scenes/shared/player_controller.gd` | Entrada WASD, cámara y **el `AudioListener3D`**. |
| `scenes/shared/npc_controller.gd` | Patrulla entre waypoints. Sin oyente. |

### 3.3 La pisada se autora con un switch container, no con ocho eventos

`AnimationSync.trigger_footstep()` fija el switch `SurfaceType` y luego busca un evento
llamado `Footstep_<Superficie>` en el registro; si no lo encuentra, cae a
`default_footstep_event`. Registrar los ocho eventos por nombre funcionaría, pero
**no demostraría nada**: la elección la haría una búsqueda de cadenas, no el plugin.

El camino idiomático usa el mecanismo que existe para esto, y **no requiere tocar
`AnimationSync`**: basta con no registrar ningún `Footstep_<Superficie>` y definir un
único evento:

```
AudioEventDef("Footstep")
  root_container = AudioSwitchContainer(switch_group_name = "SurfaceType")
    "Concrete" → AudioRandomContainer[ create_footstep("Concrete", 1..3) ]
    "Metal"    → AudioRandomContainer[ create_footstep("Metal", 1..3) ]
    ... una rama por cada uno de los ocho nombres
```

Así las pisadas ejercitan `AudioSwitchContainer`, `AudioRandomContainer` y los switches
de Game Syncs, en lugar de una concatenación de cadenas.

**El papel de `create_footstep` queda claro:** es el **generador de los streams** que
rellenan las ramas, no el mecanismo de despacho. Cubre los ocho nombres del vocabulario
con seis timbres distintos, porque `Stone` comparte rama con `Asphalt` y `Foliage` con
`Grass`. En un proyecto con audio real, esas ramas se rellenarían con archivos; aquí se
sintetizan.

---

## 4. Las tres demos y el banco

### 4.1 «Bajo la quilla» — *la acústica compuesta*

Sección inundada de un submarino. Una válvula rota silba en la sala de máquinas y
**nunca se ve**: solo se oye. Y suena como cuatro cosas distintas según dónde estés y
si la escotilla está abierta: directa a través de la escotilla, difractada y sin agudos
al cerrarla girando la rueda, como cola de reverb a través del mamparo desde el
pasillo, y opaca al bajar a la bahía inundada.

**Ejercita:** tres `OpenDouRoom3D` con perfiles distintos (`Metal`, `Concrete`,
`Water`) sobre buses de reverb compartidos, `OpenDouPortal3D` con apertura animada,
`OpenDouReflector3D` en los mamparos, oclusión por presupuesto de raycasts,
`OpenDouParameterArea3D` para la profundidad del agua, `OpenDouAcousticGeometryBake`
sobre el casco, y `OpenDouAcousticDebugger3D` con una tecla.

**Difícil de falsear:** es **el mismo emisor sin tocar**, cambiando de carácter solo
por geometría. Aísla la variable.

### 4.2 «El monzón» — *el pool y el HDR bajo presión*

Noche en una terraza de arroz. Lluvia sobre tres superficies, un canal de riego a lo
largo del terraplén, enjambres de cigarras, ranas, viento en el dosel. Truenos
acercándose.

**200 emisores y un presupuesto de 32 voces físicas**, así que 168 quedan virtuales y
el voice stealing tiene que decidir cuáles cada frame. La telemetría en pantalla
muestra instancias, físicas y virtuales. Cuando cae el trueno, el ambiente se hunde y
vuelve, y no porque nadie lo programara: porque la ventana HDR subió.

**Ejercita:** `post_event` masivo, voice stealing por prioridad y distancia,
`OpenDouMultiPositionEmitter3D` para el canal como objeto grande,
`OpenDouSplineEmitter3D`, `OpenDouGranularEmitter3D` para el enjambre, HDR con el
trueno a +18 dB, `OpenDouAudibleMonitor`, y los cuatro escalones del LOD acústico.

**Difícil de falsear:** la telemetría es observable, el ducking es audible, y el tiempo
de frame se mantiene plano mientras el número de emisores no lo hace.

### 4.3 «La cabina» — *eventos y syncs conduciendo un momento*

Torre de control aérea, de noche. La situación se degrada: rutina → alerta →
emergencia. La música cruza sus stems, la radio cambia de estación, los stingers
entran cuantizados al reloj musical, y las pisadas del operador cambian al pasar de la
moqueta a la rejilla metálica.

**Ejercita:** `OpenDouMusicPlayer` multi-stem, `States` con crossfade, un RTPC de
tensión que mueve **a la vez** la intensidad musical, un filtro sobre la radio y el
envío de reverb, `Triggers` → stingers, tablas de diálogo con `Switches` por estación,
`OpenDouAnimationSync`, `OpenDouEventPlayer` no espacial, y un SoundBank precargado
para el banco de radio.

**Difícil de falsear:** un solo valor de RTPC moviéndose conduce tres cosas distintas
de forma coherente, y los estados **cruzan** en lugar de cortar.

**Honestidad de diseño:** sin assets de voz, el «diálogo» es **chatter de radio**, no
habla inteligible. La ficción se eligió para que la limitación sea invisible: la radio
es el único caso donde una voz sintetizada —filtrada, con squelch, ininteligible por
diseño— resulta creíble.

### 4.4 El banco del rig

Escena minúscula: un suelo con tres parches —`Concrete`, `Metal` y `Water`, los tres
más distinguibles al oído de los ocho del vocabulario—, el jugador y un NPC
patrullando. Sirve para oír el rig aislado y para depurar pisadas sin cargar una demo
entera. **Es donde se prueba que la convención de metadata funciona antes de que tres
escenas dependan de ella.**

### 4.5 Cobertura resultante

Las tres demos más el banco cubren **14 de los 15** tipos de nodo. El único ausente es
`OpenDouEventPlayer2D`, por la decisión del apartado 2.

---

## 5. El hub y lo que se borra

El hub se conserva y pasa a cuatro entradas: las tres demos y el banco del rig.

**Se eliminan** los diez directorios de `scenes/demos/0*` y `master_sandbox`, sus 14
scripts y las 14 clases globales que aportaban, junto con sus suites:
`test_demo_suite.gd`, `test_cyberpunk_demo.gd`, `test_tactical_canyon_demo.gd` y
`test_tactical_infiltration_demo.gd`.

**El conteo de aserciones bajará** y es correcto: esas suites cubrían escenas que
dejan de existir. No se compensa artificialmente.

---

## 6. Verificación

Cada demo lleva **su propia suite de aserciones de audio real** con
`OpenDouAudioProbe`. Es lo que las distingue de las diez que se borran, cuyo test más
profundo afirmaba el tamaño de un array de bytes.

| Demo | Aserción que fallaría si la feature se rompiera |
|---|---|
| Bajo la quilla | El bus de reverb de la sala de máquinas recibe energía mientras el del pasillo no. Cerrar el portal baja el corte de difracción del camino directo. |
| El monzón | El conteo de voces físicas nunca supera el presupuesto. El pico del ambiente cae cuando suena el trueno. `active_instances` no crece de forma monótona. |
| La cabina | Subir el RTPC de tensión desplaza la energía entre stems. Un trigger produce un stinger medible. Un switch cambia qué línea de radio suena. |
| Banco del rig | Un paso sobre metadata `Metal` dispara un evento con el switch `Metal`. El jugador expone oyente y el NPC no. |

Las lecciones de las fases anteriores aplican y están en `AGENTS.md`: no contar frames
fijos para afirmar silencio, un `AudioStreamPlayer3D` sin oyente activo no emite nada,
y una cámara con `make_current()` hay que limpiarla con `clear_current()` antes de
liberarla.

---

## 7. Criterios de aceptación

1. Las tres demos y el banco arrancan desde el hub sin errores.
2. **Ningún script de `scenes/`** invoca `.play()` sobre un `AudioStreamPlayer`,
   `AudioStreamPlayer2D` o `AudioStreamPlayer3D`: las demos disparan audio con
   `post_event()`, con `play_event()` de los nodos declarativos, o con los métodos
   propios de cada nodo (`play_granular()`, el `MusicPlayer`). Se verifica con una
   comprobación estática sobre `scenes/**/*.gd`, igual que la guarda de escrituras a
   `res://`. **Es el criterio que cierra la observación 2**, cuya medición original
   fue «26 llamadas a `.play()` nativo frente a 6 a `play_event()`».
3. Ningún archivo de `scenes/` referencia un `.wav`, `.ogg` o `.mp3`.
4. El rig de personaje se instancia en las cuatro escenas.
5. El jugador expone un `AudioListener3D`; el NPC no.
6. `detect_surface_at()` **con el mundo físico** devuelve el nombre de la metadata
   `surface_type` del collider bajo los pies, y `Concrete` cuando no hay ninguna.
6b. `AnimationSync.trigger_footstep()` pasa el `World3D` a `detect_surface_at()`, así
   que el raycast se ejecuta. Caminar sobre tres parches de material distinto **dentro
   de la misma sala** produce tres switches de superficie distintos. Cierra la
   observación 25.
6c. Existe **un solo** `AudioEventDef` de pisada, con un `AudioSwitchContainer` sobre
   `SurfaceType`; no hay eventos `Footstep_<Superficie>` registrados.
6d. Un evento con `AudioSwitchContainer` resuelve a la rama del switch **activo**, no a
   `default_state`, cuando se dispara por el camino real de `post_event()`. Y un evento
   con `AudioBlendContainer` responde al valor **vivo** del RTPC. Cierra la
   observación 26.
6e. La aserción de audio correspondiente: dos pisadas sobre superficies distintas
   producen **timbres medibles distintos** en el bus de sonda, no el mismo stream dos
   veces.
7. Todas las aserciones de la tabla del apartado 6 pasan: son nueve en total,
   repartidas entre las cuatro escenas.
8. Los diez directorios de demos viejas y sus cuatro suites no existen.
9. El hub lista exactamente cuatro entradas.
10. Las tres demos juntas instancian 14 de los 15 tipos de nodo; solo falta
    `OpenDouEventPlayer2D`.
11. La suite sigue en verde con cero `SCRIPT ERROR`, fugas no superiores al techo y el
    árbol de git limpio.

---

## 8. Fuera de alcance

- **Observación 19**, la limpieza del namespace: Fase 4B, ya diseñada y pendiente. Las
  demos nuevas se escriben contra los nombres actuales y 4B las renombrará en la misma
  pasada.
- Versión 2 del formato ODBK con tabla de nombres.
- Llevar las fugas de ObjectDB a cero.
- Assets de audio reales. Ver apartado 2.
- Un sistema de personaje completo: salto, escalada, combate, animación esqueletal.
- `OpenDouEventPlayer2D` en una escena jugable.

---

## 9. Riesgos

| Riesgo | Mitigación |
|---|---|
| El chatter de radio sintetizado suena a ruido y no a radio | La ficción se eligió porque la limitación es invisible ahí. Si aun así no convence, se reduce su peso en la escena: la tesis de «La cabina» es la coherencia de los syncs, no el realismo vocal. |
| Tres escenas complejas son mucho trabajo y la fase se alarga | El rig compartido y el banco reducen la parte no-audio. Si hay que recortar, se recorta **geometría y visuales**, nunca aserciones. |
| Los NPC como emisores masivos disparan las fugas de ObjectDB | Cada demo libera lo que instancia, y el trinquete lo detecta. Ya delató 399 objetos en fases anteriores. |
| La convención de metadata falla y tres escenas dependen de ella | Por eso el banco del rig existe y se construye **antes** de las tres demos, y por eso el arreglo de la observación 25 va primero: sin el raycast, la detección de superficie no funciona en absoluto. |
| Arreglar el contexto de reproducción cambia el comportamiento de eventos existentes | Hoy todos los switch y blend containers resuelven a su rama por defecto. Al alimentarlos, un evento mal autorado puede pasar a resolver a una rama vacía. Los tests de contenedores existentes cubren la resolución; los de audio real cubren el resultado. |
| Una demo pasa sus aserciones pero suena mal | Las aserciones prueban que el mecanismo funciona, no que el diseño sonoro sea bueno. Eso solo se juzga escuchándolo, y es trabajo del autor tras la fase. |
