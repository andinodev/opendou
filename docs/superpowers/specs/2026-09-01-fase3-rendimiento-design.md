# Fase 3 — Rendimiento y consolidación

**Fecha:** 2026-09-01
**Estado:** Diseño aprobado, pendiente de plan de implementación
**Rama:** `main` (este proyecto trabaja en una sola rama)
**Godot verificado:** 4.7.2.stable.official.ed1daf0bf
**Fases anteriores:** [Fase 1](2026-09-01-fase1-cadena-audio-real-design.md) · [Fase 2](2026-09-01-fase2-correccion-espacial-design.md)

---

## 1. Contexto

La Fase 1 hizo que el motor emitiera audio real y verificable. La Fase 2 corrigió la
geometría. Esta fase ataca el rendimiento, y resulta que **su mayor parte se resuelve
borrando código**, no optimizándolo.

### Alcance

| Observación | Defecto | Cómo se resuelve |
|---|---|---|
| **13** | Búfer circular copiando byte a byte en GDScript | Por eliminación |
| **14** | Se afirma "SPSC lock-free" sin atómicos ni hilos | Por eliminación |
| **15** | `load()` desde disco en `_get_property_list()` | Caché estática con invalidación |
| *(diferido de la Fase 1)* | `AudioHDREngine` huérfano | Consolidación y cableado por voz |

### La dependencia que se resolvió antes de empezar

Las observaciones 13 y 14 hablan del pipeline ODBK. Antes de diseñar nada se comprobó
quién lo consume:

| Componente | Consumidores reales |
|---|---|
| `AudioRingBuffer` | Solo `bank_stream_playback.gd` y su propio test |
| `BankStreamPlayback` | Solo la demo 06, que la Fase 5 borra, y su test |
| `BankStreamPlayback.mix()` | **Nadie** |

La cadena búfer → playback → `mix()` no produce sonido en ningún sitio. Optimizar el
bucle byte a byte habría sido optimizar código muerto.

**Decisión tomada:** el pipeline ODBK se convierte en **precarga real a
`AudioStreamWAV`**. Un banco pasa a ser lo que un banco debe ser —un archivo
monolítico con metadatos del que sale audio que suena— y se renuncia al streaming
desde disco, que GDScript no puede sostener.

---

## 2. Hechos verificados contra el código y contra Godot 4.7.2

| Hecho | Verificación |
|---|---|
| El formato ODBK **hace round-trip correctamente** | Escritor y lector coinciden: cabecera de 24 bytes (`ODBK`, versión, num_streams, prefetch_block_size, `store_64(stream_block_offset)`) y entradas de TOC de 36 bytes. Una sospecha inicial de desajuste resultó infundada. |
| El TOC **no guarda el nombre** de los streams | `SoundBankMetadata` tiene `stream_name`, el compilador lo recibe en su diccionario y nunca lo escribe. Un banco cargado solo se direcciona por id entero. |
| `calculate_voice_gain_db()` devuelve el **nivel de salida absoluto**, no una ganancia que sumar | Su cuerpo es `clampf(loudness - window_top, -80.0, 0.0)`. Su entrada es la sonoridad de diseño del evento, no el nivel de mezcla. |
| Con sonoridad 0.0 en todos los eventos, HDR contribuye **exactamente 0 dB** | La ventana arranca en `min_window_top_db` = 0.0, todas las voces empujan 0.0, el objetivo queda en 0 y la ganancia sale 0. Por eso es seguro activarlo por defecto. |
| **Hay dos implementaciones de HDR duplicadas** | `AudioHDREngine` (core, escala HDR con fuerte > 0 dB) la usa solo el mixer del editor. `HDRAudioManager` (runtime/spatial, escala dBFS con techo en −6) la instancia `SpatialAcousticsManager` y solo la acciona la demo 08, que la Fase 5 borra. |
| `load()` en `_get_property_list()` está en los tres emisores | `opendou_event_player.gd:32`, `opendou_event_player_2d.gd:32`, `opendou_event_player_3d.gd:32`. El inspector invoca ese método en cada refresco. |

### Baseline al empezar

`495/495 PASSED`, cero `SCRIPT ERROR`, fugas **595** (techo en `tests/leak_budget.txt`),
árbol de git limpio.

---

## 3. El pipeline ODBK pasa a precarga real

### 3.1 `SoundBank.build_stream()`

`SoundBank` gana `build_stream(stream_id: int) -> AudioStreamWAV`. Compone el slice de
prefetch con el cuerpo en disco, lee `codec`, `channels` y `sample_rate` del TOC, y
devuelve un `AudioStreamWAV` real.

Para **codec 0 (PCM16)** produce un stream utilizable. Para **codec 1 (ADPCM)** y
**codec 2 (Vorbis)** devuelve `null` con un aviso que nombra el codec: no hay
decodificador de esos formatos en GDScript, y fingir que sí es peor que decir que no.
Es el mismo principio que rige el decodificador WAV de la Fase 2.

`read_stream_chunk()` se conserva: es cómo se lee el cuerpo del banco.

### 3.2 Caché y API pública

`SoundBankManager` cachea de forma perezosa los streams ya construidos, para no
recomponer el mismo `AudioStreamWAV` en cada petición. `AudioEventManager` expone
`get_bank_stream(bank_name: StringName, stream_id: int) -> AudioStreamWAV`.

### 3.3 Lo que se elimina

- `addons/opendou/runtime/audio_ring_buffer.gd` — el bucle byte a byte de la nº13.
- `addons/opendou/runtime/bank_stream_playback.gd` — el `mix()` que nadie consumía.
- `tests/test_ringbuffer.gd` — su cobertura desaparece con ellos.

La nº13 y la nº14 quedan resueltas porque desaparece aquello de lo que hablaban.

### 3.4 Corrección de afirmaciones

El README y el roadmap anuncian "prefetch de RAM + streaming asíncrono desde disco".
Con este enfoque el prefetch existe —es el bloque contiguo del formato— pero el
streaming desde disco no: el stream se carga completo. Hay que corregirlo **en esta
fase**, no aplazarlo, porque la afirmación queda falsa en el momento en que se borre el
ring buffer.

### 3.5 Limitación conocida que NO se aborda

El TOC no guarda nombres, así que un banco solo se direcciona por id entero:
`get_bank_stream(&"Weapons", 7)`. Para un middleware publicable eso es incómodo, pero
arreglarlo es una **versión 2 del formato**, y meter un cambio de formato en una fase de
rendimiento la ensancharía sin necesidad. Queda documentado como limitación con su
propia decisión más adelante.

---

## 4. HDR: consolidar y cablear por voz

### 4.1 Consolidación

Se conserva **`AudioHDREngine`** y se elimina **`HDRAudioManager`**.

`AudioHDREngine` gana porque tiene ataque y liberación separados, límites de ventana,
señal de cambio, y API tanto en lineal como en dB; y porque su escala —fuerte por encima
de 0 dB— es la convención de Wwise y encaja con un campo de sonoridad por evento.

Consumidores de `HDRAudioManager` que hay que actualizar: `SpatialAcousticsManager` (lo
instancia), la demo 08 y `test_tactical_canyon_demo.gd`. Cambio mínimo en los dos
últimos: la demo se borra en la Fase 5.

### 4.2 Por voz, no por bus

La spec de la Fase 1 esbozó "controlador de ganancia por categoría de bus más
`AudioEffectLimiter`". **Se descarta ese boceto.** La API real del motor es por voz, y
por voz es mejor: eso *es* HDR, una ventana que decide qué voces son audibles, y encaja
en el paso «aplicar» que la Fase 1 ya construyó.

El `AudioEffectLimiter` se descarta por YAGNI: la ventana ya acota el rango dinámico, y
poner un limitador en Master es una decisión de mezcla del usuario, no del middleware.

### 4.3 La sonoridad es una propiedad de diseño del evento

`calculate_voice_gain_db()` **no** recibe el nivel de mezcla: recibe cuánto suena esa
cosa en el mundo. Son dos magnitudes distintas y conflacionarlas daría un resultado sin
sentido.

`AudioEventDef` gana `hdr_loudness_db: float = 0.0`. Explosión +18, disparo +6,
pisada −20. El valor por defecto de 0.0 hace que HDR contribuya exactamente 0 dB, así
que **se activa por defecto sin alterar la mezcla existente**. Dejarlo desactivado
habría movido el huérfano del editor al runtime en lugar de arreglarlo.

### 4.4 Orden en el ciclo por frame

El orden importa y se inserta entre los pasos que la Fase 1 fijó:

1. Los parámetros de instancia se calculan (paso ya existente).
2. **Cada instancia empuja al motor la sonoridad de su definición**, o sea
   `instance.definition.hdr_loudness_db`.
3. **El motor actualiza la ventana con `update(delta)`.**
4. Al aplicar, la salida de cada voz suma `calculate_voice_gain_db(hdr_loudness_db)`,
   que es siempre ≤ 0 y por tanto funciona como atenuación.

Un interruptor `hdr_enabled` en el manager permite desactivarlo, con valor `true`.

---

## 5. La observación 15

Los tres emisores llaman `load()` desde `_get_property_list()`, método que el inspector
invoca en cada refresco: una lectura de disco y una enumeración del registro de presets
por refresco.

Pasa a una **caché estática del `hint_string`** —un `static var` a nivel de clase, que
GDScript soporta desde Godot 4.1— calculada la primera vez que se pide, más
`refresh_preset_hints()` para invalidarla. La invalidación no es opcional: sin ella un
preset recién añadido desde el workspace de síntesis no aparecería en el desplegable,
que es un defecto peor que el que se arregla.

La referencia al registro deja de ser `load()` en runtime y pasa a `const preload`.

---

## 6. Criterios de aceptación

1. `SoundBank.build_stream()` de un banco compilado con un tono PCM16 devuelve un
   `AudioStreamWAV` con el `mix_rate`, el número de canales y el formato correctos.
2. Las muestras del stream reconstruido coinciden **exactamente** con las del tono
   original. El banco almacena los bytes PCM16 sin transformarlos y `build_stream()`
   los reconcatena, así que el round-trip es byte-exacto: pedir solo "dentro del error
   de cuantización" seria afirmar menos de lo que el formato garantiza.
3. Para codec ADPCM y Vorbis devuelve `null` y avisa nombrando el codec, sin producir
   ruido.
4. `get_bank_stream()` devuelve el mismo objeto en dos llamadas seguidas: la caché
   funciona.
5. **Un evento cuyo stream viene de un banco produce audio medible**, con pico por
   encima de −40 dBFS en el bus de sonda.
6. `AudioRingBuffer` y `BankStreamPlayback` no existen, y ningún archivo los referencia.
7. El README y el roadmap no afirman streaming asíncrono desde disco.
8. `HDRAudioManager` no existe, y ningún archivo lo referencia.
9. Con todos los eventos a `hdr_loudness_db = 0.0`, el pico medido de una voz es el
   mismo que sin HDR: la contribución es nula.
10. Con una voz de `hdr_loudness_db = 18.0` activa, una voz de `-50.0` queda por debajo
    del suelo de la ventana: su pico medido cae **respecto al de la misma voz medida sin
    la voz fuerte presente**. La comparación tiene que ser contra ese control, no contra
    un valor absoluto, porque el nivel base depende del tono de prueba.
11. `hdr_enabled = false` desactiva por completo la contribución.
12. `_get_property_list()` no invoca `load()`: la caché se calcula una vez.
13. `refresh_preset_hints()` hace que un preset añadido después aparezca en el
    `hint_string`.
14. La suite sigue en verde con cero `SCRIPT ERROR`, fugas no superiores al techo y el
    árbol de git limpio.

---

## 7. Fuera de alcance

- Versión 2 del formato ODBK con tabla de nombres (ver 3.5).
- nº16–22 y el resto de la nº24: empaquetado, rutas `res://` en el addon, doble registro
  de tipos, 176 `class_name` globales, main screen, `.gitignore` (Fase 4).
- nº2 y las tres demos nuevas (Fase 5).
- Llevar las fugas de ObjectDB a cero: son casi todas de los tests de UI del editor
  (Fase 4).
- Streaming real desde disco vía `AudioStreamPlayback` propio. Se descartó en la Fase 1
  por meter GDScript en el hilo de audio, y esa razón no ha cambiado.

---

## 8. Riesgos

| Riesgo | Mitigación |
|---|---|
| Un banco grande cargado completo consume más RAM que el streaming que se retira | Es el coste explícito de la decisión. La carga es perezosa por stream, así que solo se materializa lo que se pide. |
| Activar HDR por defecto altera la mezcla de algún proyecto existente | Verificado que con la sonoridad por defecto la contribución es exactamente 0 dB, y hay interruptor. |
| Eliminar `HDRAudioManager` rompe la demo 08 y su test | Cambio mínimo a `AudioHDREngine`; la demo se borra en la Fase 5. |
| La caché del `hint_string` deja presets nuevos fuera del desplegable | Por eso `refresh_preset_hints()` es parte del diseño y no un añadido opcional. |
| Borrar `test_ringbuffer.gd` reduce el número de aserciones | El conteo baja y es correcto: esas aserciones cubrían código que ya no existe. |
