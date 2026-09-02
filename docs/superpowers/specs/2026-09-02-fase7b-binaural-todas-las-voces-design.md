# Fase 7B — Binaural para todas las voces

**Fecha:** 2026-09-02
**Estado:** Aprobado en diseño, pendiente de plan.
**Rama:** `main` (este proyecto trabaja en una sola rama)
**Godot verificado:** 4.7.2.stable.official.ed1daf0bf
**Steam Audio:** 4.8.1, binario oficial de Valve, Apache 2.0
**godot-cpp:** rama `master`, commit `26fb7ab` (API 4.7 por defecto; no existe rama 4.6/4.7)
**Fases anteriores:** [1](2026-09-01-fase1-cadena-audio-real-design.md) · [2](2026-09-01-fase2-correccion-espacial-design.md) · [3](2026-09-01-fase3-rendimiento-design.md) · [4A](2026-09-01-fase4a-distribuible-design.md) · [5](2026-09-01-fase5-demos-design.md) · [6](2026-09-01-fase6-portales-audibles-design.md)
**Análisis y spike (7A):** [2026-09-01-fase7-steam-audio-analisis.md](2026-09-01-fase7-steam-audio-analisis.md), §11 para los resultados del spike.

---

## 1. Contexto

El spike 7A respondió la pregunta de viabilidad: una voz de Godot 4.7 sale por Steam Audio
desde una extensión nativa, con 11.6 ms de latencia añadida, y el HRTF produce diferencia de
nivel entre oídos (+17 dB a 90°) y coloración delante/detrás (15.9 % frente a 2.5 % sin HRTF)
medibles sobre audio capturado del bus. También dejó dos hallazgos que esta fase tiene que
absorber, porque cambian el diseño:

1. **La API C pública de Steam Audio no renderiza el retardo interaural (ITD).** El tipo de
   fase interno vale `None` por defecto, la capa C nunca lo cambia y el efecto binaural solo
   *reporta* los retardos de pico en `peakDelays`. Los propios plugins de Valve para FMOD y
   Unity pasan `peakDelays` en nulo y no retrasan nada. Y el HRTF incorporado reporta a 90°
   una diferencia de pico de 0.136 ms cuando una cabeza humana da unos 0.65 ms. Conclusión:
   la pista temporal, dominante para localizar por debajo de 1.5 kHz, **la tiene que poner
   OpenDou**, con un modelo de cabeza esférica y no con `peakDelays`.
2. **OpenDou anula hoy el oscurecimiento por distancia de Godot (observación 42).** Godot
   aplica a cada voz 3D un *high-shelf* cuyo corte es `attenuation_filter_cutoff_hz` (5 kHz
   por defecto) y cuya profundidad es `(1 − min(1, multiplicador)) × attenuation_filter_db`
   (−24 dB por defecto), donde el multiplicador es la atenuación por distancia lineal. El
   canal físico de OpenDou escribe cada frame en ese mismo corte el valor de oclusión, que sin
   oclusión es 20 000 Hz: el shelf queda por encima del oído y una voz lejana suena igual de
   brillante que una cercana. Además la profundidad depende de la distancia, así que una voz
   totalmente ocluida a menos de `unit_size` (10 m) **no se filtra nada**.

Esta fase hace que **todas las voces físicas con posición** salgan por un panner propio sobre
Steam Audio cuando la extensión está presente, y deja el backend de Godot intacto y corregido
cuando no lo está. El plano de control (eventos, pool, robo de voces, HDR, grafo de salas,
oclusión por raycast) no cambia: sigue produciendo los mismos números. Lo que cambia es
**quién convierte esos números en estéreo**.

### Decisiones tomadas en el diseño

| Decisión | Valor | Razón |
|---|---|---|
| Alcance | Solo binaural para todas las voces | El «7B» del análisis era demasiado grande; efecto directo, materiales y geometría van al spec siguiente |
| Steam Audio | Binario oficial 4.8.1 fijado por hash | Arranca ya; compilar desde fuente solo tiene sentido si hay que parchearla |
| Binarios | Compilación local documentada, sin CI | Decisión del proyecto para esta fase; CI queda para después |
| Forma del panner | Reproductor estéreo plano por canal con stream nativo; el canal calcula dirección y distancia | Una sola máquina de espacialización por voz; el origen aparente relocaliza todo |
| Doppler | Fuera de esta fase | Decisión del proyecto; hoy nadie lo calcula en ningún backend |
| ITD | Modelo de cabeza esférica (Woodworth) en C++, restando el residuo del dataset | `peakDelays` es demasiado pequeño y depende del dataset |
| Filtro por distancia | Los números de Godot (5 kHz, −24 dB × (1 − multiplicador)) en ambos backends | Paridad; y corrige la observación 42 |
| Cadena de masterización en Master | Anotada para una fase posterior | Ningún demo tiene limitador; es un nodo en la escena, no es de esta fase |

---

## 2. Arquitectura: un backend espacial elegido al arrancar

El `AudioEventManager` decide **una vez**, en `_init`, el backend espacial:

| Ajuste de proyecto `opendou/spatial/backend` | Efecto |
|---|---|
| `auto` (por defecto) | `steam_audio` si `ClassDB.class_exists("OpenDouSpatialStream")` y `OpenDouSpatialStream.is_native_available()`; si no, `godot` |
| `godot` | Todo como hoy, aunque la extensión esté cargada |
| `steam_audio` | Exige la extensión; si falta, error en consola y cae a `godot` diciéndolo |

El manager expone `spatial_backend: StringName` de solo lectura (`&"godot"` o
`&"steam_audio"`). Lo leen las demos (HUD), el menú de pausa, la suite y el nodo de grafo del
editor. No hay cambio de backend en caliente: los reproductores del pool se crean por tipo y
cambiarlos bajo voces sonando no aporta nada que el conmutador audífonos/altavoces (§6) no dé.

Las voces 2D y las no espaciales no se enteran del backend.

### Componentes

| Componente | Archivo | Responsabilidad |
|---|---|---|
| `OpenDouSpatialStream` / `OpenDouSpatialStreamPlayback` | `native/src/spatial_stream.{h,cpp}` | Envolver un `AudioStream` y producir estéreo binaural por bloque: HRTF, ITD, LPF de oclusión, shelf por distancia, ganancia por distancia, paneo para altavoces |
| `SteamAudioContext` | `native/src/steam_audio_context.{h,cpp}` | Contexto y HRTF globales, con contador de generación para conmutar el HRTF en vivo |
| `OpenDouNativePlayerPool` | `runtime/native_player_pool.gd` | Nuevo tipo `BINAURAL_3D`: `AudioStreamPlayer` con un `OpenDouSpatialStream` permanente |
| `PhysicalVoiceChannel` | `runtime/physical_voice_channel.gd` | Calcular dirección, distancia y filtros desde el oyente y empujarlos al stream o al reproductor 3D |
| `EventInstance` | `runtime/event_instance.gd` | Llevar los parámetros de atenuación de la voz (`unit_size`, `attenuation_max_distance`, `attenuation_model`, `attenuation_filter_cutoff_hz`, `attenuation_filter_db`, `emitter_volume_db`) |
| `VoicePoolManager` | `runtime/voice_pool_manager.gd` | En `steam_audio`, las voces 3D de nodo también van a un canal `BINAURAL_3D` |
| `OpenDouSpatialSettings` | `runtime/spatial/spatial_settings.gd` | Leer y escribir los ajustes del jugador en `user://opendou_audio.cfg` |
| Bloque «Espacialización» | `scenes/shared/pause_menu.tscn` + `pause_menu.gd` | Backend, HRTF, mezcla, audífonos/altavoces, SOFA |
| `native/build.sh` | `native/build.sh` | Compilación reproducible en macOS arm64 |

---

## 3. El stream nativo pasa de spike a producto

`OpenDouSpatialStream` conserva el contrato del spike (`source`, `direction`, `spatial_blend`,
`spatialize`, estáticas `is_native_available`, `get_frame_size`, `get_steam_audio_version`)
y gana lo que le falta para sustituir a un panner. Todas las propiedades se escriben desde el
hilo principal y se leen en el hilo de audio con atómicos, como en el spike.

### Propiedades nuevas

| Propiedad | Tipo | Quién la escribe | Qué hace en el bloque |
|---|---|---|---|
| `distance_gain` | float lineal [0, 2] | El canal, cada frame | Multiplica la entrada mono antes del HRTF |
| `cutoff_hz` | float [20, 20000] | El canal (oclusión) | Paso-bajo Butterworth de 2.º orden sobre la entrada mono; coeficientes recalculados solo si el corte cambia más de 1 % |
| `shelf_db` | float [−80, 0] | El canal (distancia) | *High-shelf* a `shelf_cutoff_hz` con esa ganancia; 0 dB = sin efecto |
| `shelf_cutoff_hz` | float | El canal | Corte del shelf (5000 por defecto, desde la instancia) |
| `output_mode` | enum `HEADPHONES` / `SPEAKERS` | Los ajustes | `HEADPHONES`: HRTF + ITD. `SPEAKERS`: paneo estéreo de potencia constante, sin HRTF ni ITD |

Orden de proceso por bloque: mezcla del stream interno → suma a mono → `distance_gain` →
LPF de oclusión → shelf por distancia → (`HEADPHONES`) HRTF con `spatial_blend`, luego línea
de retardo por oído; (`SPEAKERS`) paneo → anillo de salida.

### El ITD, con la fórmula escrita

Con `dir` la dirección unitaria en el espacio del oyente (Steam Audio y Godot comparten ejes:
+X derecha, +Y arriba, −Z adelante):

```
azimut   θ  = atan2(dir.x, −dir.z)            ∈ (−π, π]
elevación φ = asin(clamp(dir.y, −1, 1))
θ_lateral   = |θ| si |θ| ≤ π/2, si no π − |θ|   (detrás se refleja a su espejo delantero)
ITD_esfera  = (r / c) · (θ_lateral + sin θ_lateral) · cos φ     r = 0.0875 m, c = 343 m/s
residuo     = |peakDelay_lejano − peakDelay_cercano|             (lo que el dataset ya trae)
ITD_aplicado = max(0, ITD_esfera − residuo)
```

A 90° y elevación 0, `ITD_esfera` = 0.656 ms; con el residuo medido del HRTF incorporado
(0.136 ms) se aplican 0.52 ms. El retardo va al oído **lejano** (izquierdo si `dir.x > 0`).
La línea de retardo es fraccionaria con interpolación lineal y 2 ms de longitud máxima; el
objetivo se fija por bloque y se alcanza con una rampa lineal a lo largo del bloque, para que
girar la cabeza no haga clic. Esta fórmula es la de `core/spatial/audio_spatial_binaural.gd`,
que se retira de GDScript (§8) y pasa a C++; por primera vez alguien consume sus números.

### HRTF global conmutable en vivo

`SteamAudioContext` guarda el HRTF activo con un **contador de generación**. Estáticas:

| Estática | Efecto |
|---|---|
| `set_hrtf_default() -> bool` | Vuelve al HRTF incorporado |
| `set_hrtf_sofa(path: String) -> bool` | Carga un SOFA; `false` y error en consola si no es válido, sin tocar el HRTF activo |
| `get_hrtf_name() -> String` | `"default"` o el nombre del archivo SOFA |

Cada playback compara la generación al empezar un bloque; si cambió, termina el bloque con el
HRTF viejo y toma el nuevo en el siguiente. El HRTF viejo se libera cuando su cuenta de
referencias llega a cero. No se recrea ningún efecto binaural: `iplBinauralEffectApply`
recibe el HRTF en los parámetros, que es lo que la guía de Steam Audio prevé.

### Tamaño de bloque

Ajuste de proyecto `opendou/spatial/frame_size` con valores 256, 512 o 1024; 512 por
defecto (11.6 ms a 44.1 kHz, medido en el spike). Se lee al crear el contexto; cambiarlo
exige reiniciar, y el ajuste lo dice en su descripción.

### Lo que no cambia y queda escrito

`AudioStreamPlayback.mix_audio()` devuelve un `PackedVector2Array` nuevo por bloque: una
reserva de memoria en el hilo de audio por voz y bloque. La API de GDExtension no ofrece otra
forma de tirar de un stream interno. Se acepta, se mide con 64 voces (§9) y, si algún día da
problemas, el remedio es cambiar el punto de enganche, no parchear esto. Igualmente: las
fuentes estéreo se suman a mono antes del HRTF, porque una fuente puntual no tiene anchura.
Un efecto estéreo que quiera conservar su anchura debe ser una voz no espacial.

---

## 4. Pool y canal: la dirección y la distancia las calcula OpenDou

### Pool

`OpenDouNativePlayerPool` gana `PlayerKind.BINAURAL_3D`: un `AudioStreamPlayer` con un
`OpenDouSpatialStream` creado una vez; por voz solo se cambia `stream.source`. En backend
`steam_audio`, `_kind_for_instance` devuelve `BINAURAL_3D` para toda instancia con posición
3D; en `godot`, `SPATIAL_3D` como hoy. `release()` deja `source = null`.

### Parámetros de atenuación en la instancia

`EventInstance` gana los campos que hoy viven implícitos en el reproductor 3D de Godot, con
**los valores por defecto de Godot** para que cambiar de backend no cambie el volumen:

| Campo | Por defecto | Origen |
|---|---|---|
| `unit_size` | 10.0 | Emisor de nodo si lo hay; si no, la definición del evento (nuevo export con el mismo defecto) |
| `attenuation_max_distance` | 0.0 (sin límite) | Ídem. Es un campo **nuevo y distinto** del `max_distance = 100.0` que la instancia ya usa para el robo de voces: unificarlos rompería la paridad, porque el pool de Godot atenúa con 0 (sin límite) y el robo necesita los 100 m. El robo no cambia |
| `attenuation_model` | inversa a la distancia | Ídem |
| `attenuation_filter_cutoff_hz` | 5000.0 | Ídem |
| `attenuation_filter_db` | −24.0 | Ídem |
| `emitter_volume_db` | 0.0 | `volume_db` del emisor de nodo; 0 para voces anónimas |

### Lo que el canal calcula cada frame (ambos backends)

El manager pasa a `ch.apply()` la posición y la base del oyente que `OpenDouListenerResolver`
ya resuelve. Con `p` la posición aparente de la voz (`current_apparent_position`, que el
grafo de salas ya gobierna) y `B` la base del oyente (ortonormal, así que su inversa es su
transpuesta):

```
rel = p − p_oyente;  d = |rel|
dir = Bᵀ · rel / d          (si d < 1 mm: dir = (0, 0, −1), sin ITD)

atenuación_db(d) según el modelo, con los cálculos de Godot:
  inversa:            linear_to_db(1 / (d / unit_size + ε))
  inversa cuadrática: linear_to_db(1 / ((d / unit_size)² + ε))
  logarítmica:        −20 · ln(d / unit_size + ε)
  desactivada:        0
V   = calculated_volume_db + ganancia HDR + emitter_volume_db     (sin el fade anti-clic)
att = min(atenuación_db(d) + V, max_db = 3) − V
mult = db_to_linear(att)
si attenuation_max_distance > 0:
    si d > attenuation_max_distance → la voz se silencia (mult = 0);
    si no, mult *= max(0, 1 − d / attenuation_max_distance)
shelf_db = (1 − min(1, mult)) · attenuation_filter_db
```

- **Backend `steam_audio`:** `player.volume_db = V + fade`; `stream.distance_gain = mult`;
  `stream.direction = dir`; `stream.cutoff_hz = corte de oclusión`;
  `stream.shelf_db = shelf_db`; `stream.shelf_cutoff_hz = attenuation_filter_cutoff_hz`.
- **Backend `godot`:** `player.volume_db = V + fade` y posición como hoy; Godot aplica la
  atenuación y el shelf por su cuenta. La corrección de la observación 42: el canal escribe en
  `attenuation_filter_cutoff_hz` **el mínimo** entre el corte de oclusión y el
  `attenuation_filter_cutoff_hz` de la instancia (5 kHz por defecto), en lugar de pisar el
  defecto con 20 000 Hz. Con eso Godot vuelve a oscurecer con la distancia, y la oclusión baja
  el corte desde ahí. La limitación de profundidad (una voz ocluida a menos de `unit_size` no
  se filtra) queda documentada como propia del backend `godot`: el nativo no la tiene, porque
  su LPF de oclusión no depende de la distancia.

El coste añadido es una resta, una transposición aplicada a un vector, una raíz y un
logaritmo por voz: despreciable frente a los 3.9 µs por voz y frame del bucle actual, y el
banco lo comprueba (§9).

---

## 5. Emisores de nodo y origen aparente

En backend `steam_audio`, un `OpenDouEventPlayer3D` **deja de sonar por sí mismo**. En
`resolve_voices`, si la instancia trae un reproductor vinculado que es `AudioStreamPlayer3D`
y el backend es `steam_audio`, el pool adquiere un canal `BINAURAL_3D` y el nodo queda como
**fuente de posición y de parámetros**: el canal guarda una referencia débil al nodo
(`position_node`), y `_apply_voices` lee `global_position` de él cada frame en el bucle que ya
recorre, antes de calcular la posición aparente. Los parámetros de atenuación de la instancia
se rellenan desde los exports del nodo, que ya existen por herencia (`unit_size`,
`max_distance`, `attenuation_model`, `attenuation_filter_cutoff_hz`, `attenuation_filter_db`,
`volume_db`, `bus`). El `AudioStreamPlayer3D` del nodo nunca recibe un stream y no suena.

Consecuencia: el **origen aparente** de la Fase 6 relocaliza también a las voces de nodo,
porque su posición es un dato que pasa por `current_apparent_position` y no un nodo que Godot
lee por su cuenta. La limitación anotada en el spike desaparece por construcción.

En backend `godot` todo sigue como hoy: el nodo suena él mismo y el origen aparente solo
mueve a las voces anónimas del pool. Los emisores 2D no cambian en ningún backend.

---

## 6. Ajustes del jugador y menú de sonido

### `OpenDouSpatialSettings`

`RefCounted` en `runtime/spatial/spatial_settings.gd`, propiedad del manager, que lee al
arrancar y escribe al cambiar `user://opendou_audio.cfg`:

| Sección/clave | Valores | Efecto |
|---|---|---|
| `spatial/hrtf` | `"default"` o ruta a un `.sofa` | `set_hrtf_default()` / `set_hrtf_sofa()`; si el SOFA falla, vuelve a `default` y lo dice |
| `spatial/blend` | 0.0 – 1.0 (1.0 por defecto) | `spatial_blend` de todos los streams del pool |
| `spatial/output` | `"headphones"` (por defecto) / `"speakers"` | `output_mode` de todos los streams del pool |

Los tres se aplican **en vivo**, sin reiniciar: el pool recorre sus streams. Con backend
`godot` los ajustes se guardan igual pero no tienen efecto, y el menú lo muestra.

### El bloque «Espacialización» del menú de pausa

Compuesto como nodos en `pause_menu.tscn` dentro del panel de sonido, según la regla 04; el
script solo conecta señales y rellena valores:

| Nodo | Tipo | Qué muestra o hace |
|---|---|---|
| `SpatialTitle` | `Label` | «Espacialización» |
| `BackendLabel` | `Label` | «Backend: Steam Audio 4.8.1 · HRTF: default» o «Backend: Godot» |
| `BlendSlider` | `HSlider` 0–1 | `spatial/blend`; deshabilitado con backend `godot` |
| `OutputToggle` | `CheckButton` | «Audífonos» / «Altavoces»; deshabilitado con backend `godot` |
| `SofaButton` | `Button` | Abre un `FileDialog` (`*.sofa`, acceso a archivos del sistema) y aplica; deshabilitado con backend `godot` |
| `SofaResetButton` | `Button` | Vuelve al HRTF incorporado |
| `SofaDialog` | `FileDialog` | El diálogo, en la escena |

El HUD de las demos añade el backend activo a la línea de cobertura que ya muestra.

---

## 7. Compilación, distribución y licencia

### `native/build.sh`

Reproducible y sin pasos manuales, para macOS arm64 (la única plataforma **verificada** en
esta fase):

1. Si falta `native/thirdparty/godot-cpp`, lo clona y fija al commit `26fb7ab`.
2. Si falta `native/thirdparty/steamaudio`, descarga el zip 4.8.1 de la release oficial de
   Valve, verifica su SHA-256 contra el valor escrito en el propio script, y lo extrae.
3. Compila godot-cpp (`template_release`, arm64) y la extensión en `Release`.
4. Copia `libphonon.dylib` junto a la extensión, quita `com.apple.quarantine` y firma ad hoc
   las dos bibliotecas (lo que el spike automatizó en POST_BUILD se conserva).
5. Imprime la versión de Steam Audio y la ruta de salida.

El CMake es multiplataforma y el SDK trae bibliotecas para Windows, Linux, Android, iOS y
wasm, pero **no se afirma ninguna plataforma que no se haya compilado y probado**. El
`.gdextension` declara solo `macos.release` en esta fase; las entradas de otras plataformas
se añaden cuando se verifiquen.

### Licencia y promesas escritas

- `addons/opendou/THIRD_PARTY_NOTICES.md`: aviso Apache 2.0 de Steam Audio (copiando lo que
  exige su `THIRDPARTY.md`) y MIT de godot-cpp.
- El README dice hoy «OpenDou es hoy 100 % GDScript». Se reescribe el mismo día que entre la
  primera línea de producto en C++: «GDScript con una extensión nativa opcional para el
  binaural con Steam Audio; sin ella, todo funciona con el panner de Godot».
- `docs/architecture/gdextension_api.md` ya describe la fachada con doble backend; se le
  añade el nombre real de la clase y el ajuste de backend. La regla `02_architecture.md` ya
  contempla C++ y no cambia.
- `AGENTS.md` §5b gana la observación 42 y las trampas del spike (cuarentena y firma;
  godot-cpp `master` para 4.7; `mix_audio` reserva en el hilo de audio).

---

## 8. Retiradas y reescrituras

| Pieza | Qué pasa |
|---|---|
| `core/spatial/audio_spatial_binaural.gd` (Woodworth en GDScript) | Se retira. Su fórmula de ITD vive en C++ (§3). Nadie la consumía |
| `editor/nodes/opendou_binaural_graph_node.gd` | Se reescribe para mostrar backend, HRTF, mezcla y tamaño de bloque reales leídos del manager, en lugar de una fórmula |
| `tests/test_binaural_spike.gd` | Pasa a `tests/test_binaural.gd`, suite de producto. Las aserciones de ITD se **voltean**: ahora sí hay retardo en la salida |
| `tests/test_early_reflections_hrtf.gd` | Su parte de HRTF se funde en `test_binaural.gd`; la de reflexiones se queda |
| `EdgeDiffractionEngine`, `RoomCouplingEngine` | No se tocan: son de la fase de propagación |

---

## 9. Rendimiento con guardas, no con promesas

Dos medidas y dos techos que se aprietan como el de fugas:

| Medida | Cómo | Techo |
|---|---|---|
| Coste del bucle de control | El banco `tests/_bench_loop.gd` que ya mide µs por voz en `_process`, con 200 voces | ≤ 4.3 µs por voz y frame (3.9 actuales + 10 %) |
| Coste del DSP nativo | Estática `OpenDouSpatialStream.benchmark_block(voces: int) -> float` que renderiza un bloque de 512 muestras por voz de forma síncrona y devuelve µs por voz, porque el hilo de audio no se puede cronometrar desde fuera en headless | Se fija con la primera medida y se escribe en `tests/dsp_budget.txt`. Referencia: a 64 voces el DSP debe quedar por debajo del 15 % de un núcleo, es decir ≤ 27 µs por voz y bloque a 44.1 kHz; si la primera medida lo supera, se investiga antes de seguir |

El ratchet de fugas sigue igual. Las voces virtuales no tocan el stream: el coste nativo es
solo por voz física.

**Medido al cerrar la fase (2026-09-02, `tools/bench_control_loop.gd`, 120 llamadas directas a
`_process`, cámara presente):**

| Voces | `godot`, µs por voz | `steam_audio`, µs por voz |
|---|---|---|
| 200 | 4.00 | 4.21 |
| 500 | 3.64 | 3.77 |

El nativo cuesta un 5 % más que Godot en el bucle de control (dirección, distancia y filtros
que Godot calculaba en C++), bajo el techo de 4.3. DSP nativo con `benchmark_block(64)`:
18–28 µs por voz y bloque de 512 según la carga de la máquina; el techo de la suite es 40 en `tests/dsp_budget.txt` (mínimo de cinco medidas, guarda gruesa contra regresiones al doble; la medida fina es del banco); desglose:
HRTF bilineal 16.6, HRTF vecino más cercano 9.1, filtros e ITD 6.7, generar la fuente 2.7.

---

## 10. Verificación

Todo sobre audio capturado del bus con `OpenDouAudioProbe`, con la **fuente periódica de
1024 muestras** del spike (tres corridas idénticas) y con un control que apaga el mecanismo.
Si la extensión no está compilada, `test_binaural.gd` se omite **y lo dice**; el resto de la
suite corre igual.

| Qué se afirma | Cómo | Control |
|---|---|---|
| **ITD en la salida** | Fuente a 90° a la derecha: retardo del pico de correlación cruzada entre 0.45 y 0.75 ms, oído izquierdo por detrás; a la izquierda, signo contrario; de frente, ≤ 3 muestras | `spatial_blend = 0`: retardo cero |
| **ILD** | > 6 dB a 90°, con el signo de cada lado | HRTF apagado: 0 dB |
| **Delante / detrás** | Relación de bandas 5–10 kHz / 1–4 kHz distinta al menos un 10 % | HRTF apagado: < 5 % |
| **LPF de oclusión** | La misma voz con `cutoff_hz` 500 y 20 000: la banda alta cae más de 20 dB | — |
| **Shelf por distancia** | A 40 m con `unit_size` 10: la banda > 5 kHz cae respecto a 10 m; a 10 m el shelf es 0 dB | `attenuation_filter_db = 0`: sin caída |
| **Paridad de nivel entre backends** | Nivel RMS a 2 m y a 16 m con `godot` y con `steam_audio`: diferencia < 1 dB en cada distancia | — |
| **Observación 42 corregida en `godot`** | Voz sin oclusión a 40 m: la banda > 5 kHz cae respecto a 10 m (hoy no cae) | — |
| **Origen aparente relocaliza emisores de nodo** | Un `OpenDouEventPlayer3D` en una sala con el portal a la derecha del oyente produce ILD positivo; con el portal a la izquierda, negativo | Backend `godot`: el ILD no cambia de signo (es la limitación conocida) |
| **HRTF conmutable en vivo** | Cambiar a un SOFA y volver mientras suenan 16 voces: el audio no se corta (ningún bloque en silencio), sin fugas | — |
| **Salida altavoces** | Fuente a la derecha: ILD > 6 dB, ITD cero, espectro delante = detrás dentro del 5 % | — |
| **Ajustes** | Escribir los tres valores, recargar, leer lo mismo; SOFA inválido vuelve a `default` y lo dice | — |
| **Doble backend** | Con `opendou/spatial/backend = godot` forzado, las 995 aserciones actuales siguen verdes | — |
| **Composición** | Las guardas de escena cubren los nodos nuevos del menú y el `.play(` prohibido | — |
| **Rendimiento** | Los dos techos de §9 | — |

---

## 11. Criterios de aceptación

1. Con la extensión compilada, `spatial_backend == &"steam_audio"` y en «Una casa canta» el
   coche que pasa se ubica con audífonos: a la derecha, a la izquierda y detrás, por ITD, ILD
   y espectro medidos, no por impresión.
2. Sin la extensión, `spatial_backend == &"godot"`, la suite completa está verde y la
   binaural se omite diciéndolo.
3. La música de la ventana entreabierta sale **de la ventana** también cuando el emisor es un
   nodo de la escena.
4. El menú de pausa cambia mezcla, salida y HRTF en vivo y lo recuerda entre sesiones.
5. `native/build.sh` produce la extensión en una máquina limpia con macOS arm64 sin pasos a
   mano.
6. README, avisos de licencia y `AGENTS.md` actualizados el mismo día.
7. Los dos techos de rendimiento y el de fugas escritos y verdes.

---

## 12. Fuera de alcance

Por escrito, con su destino:

| Qué | Dónde |
|---|---|
| Doppler | Pospuesto por decisión de hoy; se vuelve a evaluar tras 7C |
| Efecto directo: oclusión volumétrica, transmisión por material en 3 bandas, absorción del aire de Steam Audio, geometría del bake hacia `IPLStaticMesh` | Spec siguiente (7C) |
| Reflexiones y reverb por convolución, ambisonics | 7D |
| Propagación por sondas, directividad, geometría dinámica | 7E |
| CI, Windows, Linux, Android, iOS, web | Fase posterior; el CMake y el SDK lo permiten, pero no se afirma |
| Salida surround del backend nativo | El backend `steam_audio` produce estéreo; quien quiera 5.1/7.1 elige `godot` |
| Cadena de masterización (limitador en Master) | Un nodo en cada escena y una regla; fase posterior |
| Cambio de backend en caliente | No hace falta: el conmutador audífonos/altavoces es en vivo |

---

## 13. Riesgos

| Riesgo | Mitigación |
|---|---|
| Reserva de memoria en el hilo de audio por `mix_audio()` | Medida con 64 voces; documentada; el remedio conocido es cambiar el punto de enganche |
| El ITD esférico sumado a un HRTF que ya trae un residuo suena «doble» | Se resta el residuo reportado; el test exige 0.45–0.75 ms, no más |
| El HRTF incorporado no le sirve a todos: el HRTF es personal | Deslizador de mezcla y carga de SOFA; y el análisis ya lo dijo: que suene bien lo juzgan oídos |
| godot-cpp `master` cambia bajo nuestros pies | Commit fijado en `build.sh`; el spec lo cita |
| Distribuir una `.dylib` sin firma real | Fuera de esta fase; el aviso queda en `AGENTS.md` y en el README de `native/` |
| Fuentes estéreo pierden anchura al sumarse a mono | Documentado: un efecto estéreo con anchura es una voz no espacial |
| Un SOFA malformado en el hilo de audio | Se valida al cargar en el hilo principal; el HRTF activo solo cambia si la carga fue válida |

---

## 14. Preguntas del análisis, cerradas

| Pregunta (§10 del análisis) | Respuesta |
|---|---|
| ¿Binario o desde fuente? | Binario oficial 4.8.1, hash fijado |
| ¿CMake o SCons? | CMake (spike) |
| ¿Dónde vive el código nativo? | `native/` en la raíz; binarios en `addons/opendou/bin/`, ignorados por git (spike) |
| ¿`frameSize` 512 o 1024? | 512 por defecto, medido: 11.6 ms; ajuste con 256/512/1024 |
| ¿Qué plataformas compila el CI? | Sin CI en esta fase; solo macOS arm64 verificado |
| ¿El pool de reverb de Godot como fallback permanente? | Permanente: la exportación web nunca tendrá la biblioteca. Se ratifica; lo ejecuta 7D |

---

## 15. Correcciones que la ejecución obligó a hacer a este spec

1. **El residuo de `peakDelays` no se resta (§3).** El spec preveía aplicar
   `max(0, ITD_esfera − residuo)` por si el dataset aportaba parte del retardo. Medido en la
   Task 7: el retardo que sale coincide con el que se aplica en los dos lados (23 muestras a
   la derecha restando 0.136 ms; 12 a la izquierda restando 0.386 ms), luego la salida de
   Steam Audio con fase plana **no lleva ningún** retardo interaural y restar el residuo solo
   hacía el ITD asimétrico. Se aplica Woodworth completo: 0.656 ms a 90°, y el test exige
   0.55–0.75 ms con el signo de cada lado. `get_last_peak_delays()` se conserva como dato.
2. **La captura de los tests binaurales asienta y mide por muestras, no por frames (§10).**
   En headless un frame dura ~2 ms y seis frames no cubrían la latencia del anillo: la
   medida del paso-bajo oscilaba entre −17 y −44 dB según lo que quedara en vuelo. Con 6144
   muestras de asentamiento y 8192 de captura las medidas son idénticas entre corridas.
3. **El panner de Godot atenúa respecto a su propio oyente (§10, paridad).** La cámara o el
   `AudioListener3D` del viewport, no el oyente de OpenDou. Los tests de paridad ponen una
   `Camera3D` en el origen mirando a −Z, donde OpenDou también coloca su oyente.
4. **El estimador de ITD devuelve 0 con un canal mudo.** Con paneo duro a 90° la ganancia
   del canal lejano es exactamente cero y la correlación es cero en todo el barrido; el
   máximo caía en el primer retardo. Los altavoces se miden a 45°.
5. **El anfitrión del stream nativo es un `AudioStreamPlayer3D` neutralizado, no un
   `AudioStreamPlayer` plano (§3, §4).** El reverb por sala de la Fase 2 vive en el mecanismo
   `Area3D.reverb_bus` de Godot, que solo alimentan los reproductores 3D, y GDExtension no
   expone el mapa de volúmenes por bus con el que Godot lo hace (`AudioServer` publica solo la
   velocidad de reproducción). Con un reproductor plano, la válvula de «Bajo la quilla» dejaba
   de alimentar el reverb de su sala. El anfitrión lleva `panning_strength = 0`, atenuación
   desactivada, filtro a 0 dB y `max_db = 24`: Godot no toca el estéreo binaural (medido: la
   ILD y el ITD del pool se conservan), pero lo envía al bus de reverb del `Area3D` en el que
   está el origen aparente. Consecuencia que hay que saber: un reproductor 3D **no emite nada
   sin un oyente en el viewport** (0.0000 sin cámara, 0.91 con ella), así que los tests del
   backend nativo ponen una `Camera3D`, igual que los de paridad.
6. **El bus lo sigue decidiendo la definición del evento**, también para emisores de nodo en
   `steam_audio`: es la precedencia que ya tenía el backend `godot`. Una primera versión
   tomaba el bus del nodo y dejó mudas las pisadas del rig, cuyo test enruta por la definición.
7. **El shelf por distancia replica el de Godot, no el del «Audio EQ Cookbook» (§3).** Godot
   (`AudioFilterSW::HIGHSHELF`, resonancia 1) usa la ganancia lineal donde la fórmula RBJ usa
   su raíz: un shelf pedido a −12 dB atenúa unos −24 dB reales por encima del corte. Con el
   shelf RBJ, la caída de 2 a 16 m difería 1.7 dB entre backends; con la fórmula de Godot,
   0.94 dB. Medido: −24.5 dB en 8–14 kHz y +0.4 dB en 0.5–2 kHz para −12 dB pedidos.
8. **Paridad absoluta: 2.0 dB de frente (§10).** A 2 m, con el tope de +3 dB en ambos, el
   backend `godot` mide −10.70 dB y el nativo −12.69 dB. Es la ley de paneo de Godot para una
   fuente centrada frente a la respuesta frontal del HRTF; la normalización RMS del HRTF no
   lo movió ni una décima. El test lo afirma con 2.5 dB de margen y deja escrito el valor.
9. **`AudioStreamPlayer3D.new()` nace con `area_mask = 0`** (§4). Los reproductores 3D
   anónimos del pool nunca habían alimentado el reverb de sala en ningún backend: solo los
   emisores de nodo, que en la escena llevan máscara 1. El pool fija la máscara a 1 y el
   anfitrión binaural hereda la del nodo emisor. Observación 44 en `AGENTS.md`.
