# Fase 2 — Corrección espacial

**Fecha:** 2026-09-01
**Estado:** Diseño aprobado, pendiente de plan de implementación
**Rama:** `main` (este proyecto trabaja en una sola rama)
**Godot verificado:** 4.7.2.stable.official.ed1daf0bf
**Fase anterior:** [`2026-09-01-fase1-cadena-audio-real-design.md`](2026-09-01-fase1-cadena-audio-real-design.md)

---

## 1. Contexto

La Fase 1 hizo que el motor emitiera audio real y verificable: `post_event()` suena,
los parámetros calculados llegan a la salida, las voces terminan, y la suite dejó de
ser ciega a los errores. Cerró las observaciones 1, 3, 4, 5, 6, 8, 12 y 23.

Esta fase corrige la **geometría**. Los defectos que quedan no impiden que suene:
hacen que suene en el sitio equivocado, con las dimensiones equivocadas, o con basura
en lugar de audio.

### Alcance

| Observación | Defecto |
|---|---|
| **7** | El spline emitter se desliza hacia el oyente |
| **9** | Los transforms ignoran rotación y escala, con el helper duplicado en tres archivos |
| **10** | `open_factor` no se propaga al portal en runtime, y `portal_size` no se usa |
| **11** | Tres sitios decodifican WAV asumiendo 16-bit mono |
| *(diferido de la Fase 1)* | Reverb nativo por sala sustituyendo la convolución en GDScript |

---

## 2. Hechos verificados contra Godot 4.7.2

Ejecutados antes de fijar el diseño. No son supuestos.

| Hecho | Verificación |
|---|---|
| **`Area3D.reverb_bus_name` no falla con un bus inexistente: lo coacciona a `"Master"`** | Asignado `"BusQueNoExiste"`, se leyó `"Master"`. Sin error ni aviso. Releer el valor tras asignarlo es obligatorio. |
| Con el bus creado, el nombre se conserva | Asignado `"ProbeReverb"` con el bus existente, se leyó `"ProbeReverb"`. |
| **El reverb nativo de `Area3D` es medible en headless** | Emisor 3D dentro de un `Area3D` con `reverb_bus_enabled`: pico **3,55** en el bus de reverb medido con `AudioEffectCapture`. El subsistema es verificable en CI. |
| `AudioStreamWAV` tiene cuatro formatos y **el defecto es 8-bit** | `FORMAT_8_BITS=0`, `FORMAT_16_BITS=1`, `FORMAT_IMA_ADPCM=2`, `FORMAT_QOA=3`; una instancia nueva reporta `format=0`. No existe API de decodificación a float en GDScript. |
| Crear buses no da problema, pero cuestan | 40 buses creados sin queja. Godot procesa cada bus cada frame, así que el número importa. |
| `AudioEffectReverb` **no** tiene parámetro de RT60 | Expone `predelay_msec`, `predelay_feedback`, `room_size`, `damping`, `spread`, `hipass`, `dry`, `wet`. El mapeo desde RT60 será una aproximación, no una derivación. |
| `AudioServer.remove_bus(i)` desplaza los índices posteriores | Comportamiento documentado del motor. Descarta cualquier diseño que cree y destruya buses dinámicamente. |

---

## 3. Los cuatro arreglos acotados

### 3.1 Observación 7 — la deriva del spline emitter

**Causa.** Un bucle de realimentación. El nodo mueve su propio `global_position` al
punto más cercano de la curva (`opendou_spline_emitter_3d.gd:84`), pero la curva se
interpreta en el espacio local del nodo (`to_local(listener_pos)`, línea 65). Al
moverse el nodo, la curva se mueve con él: el río entero migra hacia el jugador.

**Corrección.** Separar las dos cosas que hoy están confundidas: el **marco de la
curva** y la **cabeza de reproducción**. El nodo captura su `global_transform` en
`_ready()` como ancla de la curva y calcula el punto más cercano contra esa ancla
fija, no contra su transform vivo. Así puede seguir moviéndose como cabeza virtual
sin arrastrar la geometría.

Se expone `reanchor()` para juegos que reubiquen el emisor a propósito (un río sobre
un vehículo en marcha).

### 3.2 Observación 9 — transforms sin rotación ni escala

**Causa.** `_get_world_position_fallback()` suma los `position` de los nodos padres
ignorando rotación y escala, y está **duplicado con el mismo error** en
`opendou_room_3d.gd:185`, `opendou_portal_3d.gd:92` y
`opendou_multi_position_emitter_3d.gd:145`.

Además `Room3D` construye su AABB desde `global_position ± size/2`, así que una sala
rotada tiene límites acústicos incorrectos.

**Corrección.** Un único helper compartido que compone `Transform3D` de verdad
recorriendo la jerarquía. El AABB de `Room3D` pasa a envolver las ocho esquinas
transformadas de la caja.

**Limitación aceptada y documentada.** Un AABB no puede representar exactamente una
sala rotada 45 grados: el resultado queda conservador, más grande que la sala real.
Hacerlo exacto exigiría que `AudioRoom` guardara un `Transform3D` en lugar de un
AABB, lo que cambia su interfaz y las de sus consumidores. Queda fuera de esta fase.

### 3.3 Observación 10 — `open_factor` y `portal_size`

**Causa.** `open_factor` es un export plano: asignarlo directamente —lo natural desde
un tween o un `AnimationPlayer`— no actualiza `runtime_portal`. Hay que acordarse de
llamar `set_open_factor()`. `Room3D` sí usa setters para sus propiedades, así que los
dos nodos hermanos se comportan de forma distinta ante la misma operación.

Y `portal_size` está expuesto y **no se lee en ninguna parte**: `get_diffraction_lpf()`
solo mira `open_factor`, de modo que una gatera y un portón abierto difractan igual.

**Corrección.** `open_factor` pasa a export con setter que sincroniza con el portal en
runtime, siguiendo el patrón que `Room3D` ya usa. `get_diffraction_lpf()` incorpora
`portal_size`: una apertura mayor difracta menos.

### 3.4 Observación 11 — decodificación WAV

**Causa.** Tres sitios decodifican a mano asumiendo 16-bit mono
(`opendou_granular_emitter_3d.gd` en dos lugares y el kernel IR de
`opendou_room_3d.gd`). Con un WAV estéreo, 8-bit, IMA-ADPCM o QOA se lee basura. Y el
formato por defecto de `AudioStreamWAV` es 8-bit, no 16.

**Corrección.** Un único decodificador compartido que lee `wav.format` y `wav.stereo`,
mezcla los canales a mono, y para IMA-ADPCM y QOA **devuelve vacío con un aviso que
nombra el formato**. No hay decodificador de esos formatos en GDScript, y fingir que
sí es peor que decir que no.

---

## 4. El subsistema de reverb por sala

### 4.1 Enfoque elegido

**Buses compartidos por perfil acústico.** Las salas se agrupan por RT60 en escalones
configurables con un techo fijo de buses.

Enfoques descartados:

- **Un bus por sala**: coste lineal en número de salas, y la destrucción dinámica de
  buses desplaza los índices de los posteriores.
- **Un único bus global interpolado hacia la sala del oyente**: coste mínimo, pero
  imposibilita oír dos salas a la vez. El oyente **sí** oye dos salas cuando hay un
  portal abierto entre ellas, y modelar eso es precisamente para lo que existe
  `OpenDouPortal3D`. Un bus global dejaría a los portales sin nada que transmitir.

### 4.2 `OpenDouReverbBusPool`

- `configure(max_buses := 8, rt60_step_sec := 0.3)`.
- `bus_for_rt60(rt60: float, absorption: float) -> StringName` devuelve el nombre del
  bus del escalón más cercano, creándolo la primera vez: `add_bus`, `set_bus_name` a
  `OpenDouReverb_<escalón>`, `set_bus_send` a Master, y un `AudioEffectReverb`.
- Alcanzado el techo, una sala nueva cae al escalón existente más próximo.
- **Los buses se crean una vez y no se destruyen durante la sesión.** `remove_bus`
  desplaza los índices posteriores y corrompería referencias en otras partes del motor.
- Con 100 salas siguen siendo 8 buses.

### 4.3 El mapeo RT60 → `AudioEffectReverb`

`AudioEffectReverb` no expone RT60. El mapeo es una **aproximación calibrada, no una
derivación física**, y debe quedar escrito así en el código en lugar de disfrazarse de
ciencia.

Mapeo de partida, con los coeficientes en constantes nombradas para que sean ajustables
sin tocar la lógica:

```
RT60_REFERENCE_SEC = 6.0   # RT60 que satura room_size a 1.0
room_size = clampf(rt60 / RT60_REFERENCE_SEC, 0.05, 1.0)
damping   = clampf(absorption, 0.0, 1.0)
wet       = 0.5   # el envio lo modula reverb_bus_amount de la sala
dry       = 0.0   # el bus es solo de reverb; la senal directa va por su propio bus
```

`RT60_REFERENCE_SEC = 6.0` sale de que `calculate_sabine_reverb()` ya limita el RT60 a
12 s y los valores de interior habituales caen entre 0,3 y 3 s: 6 s deja margen para
naves y cuevas sin aplastar el rango util.

### 4.4 Integración con `Room3D`

Al registrarse, la sala pide su bus al pool y fija `reverb_bus_enabled`,
`reverb_bus_name`, y dos exports nuevos para `reverb_bus_amount` y
`reverb_bus_uniformity`.

**Tras asignar el nombre hay que releerlo.** Si el bus no existía, Godot no da error:
coacciona el valor a `"Master"` y el reverb se va al bus maestro sin que nadie se
entere. La comprobación del retorno es obligatoria, con `push_error` si falla.

**Restricción heredada del motor.** El reverb nativo solo alcanza a los reproductores
que están **dentro** del área y cuyo `area_mask` corte la capa del `Area3D`. Las voces
del pool nacen con `area_mask = 1`, así que una `Room3D` en una capa distinta de la 1
no las alcanzaría. Se documenta como requisito y se emite un aviso al registrar una
sala cuya capa no incluya la 1.

### 4.5 `ReverbMode` y el IR

El enum queda en dos valores:

- `SABINE_RT60`: el cálculo geométrico actual.
- `IR_DERIVED_RT60`: analiza `impulse_response_stream` para derivar su RT60.

La derivación usa **extrapolación T20**: medir la pendiente del decaimiento entre −5 y
−25 dB y extrapolarla a −60 dB. Es el método de las herramientas de acústica reales.
Buscar ingenuamente la caída de 60 dB no funciona: el ruido de fondo de cualquier IR
medido la enmascara.

`convolution_reverb_node.gd` se elimina. Sus 512 taps en GDScript quedan sin
consumidor, y mantener DSP por muestra en GDScript contradice el objetivo de la
Fase 1.

Los consumidores actuales de `CONVOLUTION_IR` son la demo 08 y dos tests. La demo se
borra en la Fase 5; los tests se actualizan al enum nuevo.

---

## 5. Criterios de aceptación

1. Un spline emitter con el oyente en movimiento **no** desplaza el punto más cercano
   de su curva en el mundo: el río se queda donde se autoró.
2. `reanchor()` reubica el marco de la curva de forma explícita.
3. Una sala hija de un nodo rotado y escalado reporta un AABB que **envuelve** sus
   ocho esquinas reales.
4. `_get_world_position_fallback` no existe duplicado: hay un único helper compartido.
5. Asignar `portal.open_factor = x` directamente actualiza el portal en runtime, sin
   llamar a `set_open_factor()`.
6. Dos portales con el mismo `open_factor` y `portal_size` distinto devuelven cutoffs
   de difracción distintos.
7. El decodificador WAV devuelve muestras correctas para 8-bit mono, 8-bit estéreo,
   16-bit mono y 16-bit estéreo, normalizadas a `[-1, 1]`: las muestras de 8 bits son
   con signo y se dividen entre 128, las de 16 bits son little-endian con signo y se
   dividen entre 32768. El estéreo se promedia a mono.
8. Para IMA-ADPCM y QOA devuelve vacío y avisa nombrando el formato, sin producir
   ruido.
9. Dos salas con RT60 dentro del mismo escalón comparten bus; con RT60 de escalones
   distintos, no.
10. Superado el techo de buses, una sala nueva reutiliza el escalón más próximo y el
    número de buses no crece.
11. Tras registrar una sala, `reverb_bus_name` **no** quedó coaccionado a `"Master"`.
12. El RT60 derivado de un IR sintético de decaimiento conocido cae **dentro del
    ±15 %** del valor real. La tolerancia es amplia a propósito: la extrapolación T20
    mide una pendiente sobre 20 dB y la proyecta a 60, así que triplica cualquier
    error de la medida. Exigir más precisión seria afirmar algo que el método no da.
13. **Una voz dentro de una sala produce energía medible en el bus de reverb de esa
    sala.**
14. `ConvolutionReverbNode` no existe, y ningún archivo lo referencia.
15. La suite sigue en verde con cero `SCRIPT ERROR`, fugas no superiores al techo y el
    árbol de git limpio.

---

## 6. Fuera de alcance

- nº13 búfer circular byte a byte, nº14 SPSC, nº15 `load()` en `_get_property_list()`
  (Fase 3), junto con el cableado del `AudioHDREngine`.
- nº16–22 y el resto de la nº24: empaquetado, rutas `res://`, doble registro de tipos,
  176 `class_name` globales, main screen, `.gitignore` (Fase 4).
- nº2 y las tres demos nuevas (Fase 5).
- Que `AudioRoom` guarde un `Transform3D` en lugar de un AABB, para representar salas
  rotadas con exactitud. Cambia su interfaz y las de sus consumidores.
- Llevar las fugas de ObjectDB a cero: son casi todas de los tests de UI del editor
  (Fase 4).

---

## 7. Riesgos

| Riesgo | Mitigación |
|---|---|
| Anclar la curva del spline en `_ready()` rompe emisores que hoy se mueven a propósito | `reanchor()` lo cubre explícitamente, y el comportamiento anterior era un bug, no una feature: la curva derivaba hacia el oyente. |
| El mapeo RT60 → reverb suena mal en algún caso | Los coeficientes van en constantes nombradas y documentadas como calibración, no como física. Ajustarlos no toca la lógica. |
| El techo de 8 buses resulta escaso en una escena con muchas acústicas distintas | `configure()` lo sube. El techo protege el coste por defecto, no lo impone. |
| Eliminar `ConvolutionReverbNode` rompe la demo 08 y dos tests | La demo se borra en la Fase 5 y los tests se actualizan al enum nuevo. Es trabajo esperado. |
| Una `Room3D` en una capa física distinta de la 1 no alcanza a las voces del pool | Aviso al registrar, y requisito documentado. |
