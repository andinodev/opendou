# Fase 12 — Materiales y efecto directo de Steam Audio

**Fecha:** 2026-09-02
**Estado:** Diseñado sin intervención del usuario; **dudas abiertas en [`docs/tasks/observaciones-fases-12-14.md`](../../tasks/observaciones-fases-12-14.md)**. Pendiente de resolverlas antes de ejecutar.
**Rama:** `main`
**Godot verificado:** 4.7.2.stable.official.ed1daf0bf · **Steam Audio:** 4.8.1 (binario, pinned)
**Hoja de ruta:** [`docs/roadmap/2026-09-02-sprint-aaa.md`](../../roadmap/2026-09-02-sprint-aaa.md), Fase 12
**Fase anterior:** [11](2026-09-02-fase11-emisores-nuevos-y-modos-design.md)

---

## 1. Contexto

Hasta aquí la extensión nativa solo renderiza: HRTF, ITD, filtros, retardo. La **simulación**
sigue siendo nuestra y escalar: un rayo por voz (`OcclusionScheduler`) que produce un corte
de paso-bajo y −6 dB; un registro de materiales con una absorción por material; la
directividad como dipolo en GDScript. Esta fase mete el **efecto directo** de Steam Audio en
la cadena: oclusión volumétrica, transmisión por material en tres bandas, absorción del aire
y directividad nativa, calculadas contra la geometría del bake convertida en `IPLScene`.

Hechos comprobados al preparar el spec (código y `phonon.h` 4.8.1):

- **`IPLMaterial`** = `absorption[3]`, `scattering`, `transmission[3]` (bandas baja / media /
  alta). Steam Audio trae una tabla de referencia (generic, brick, concrete, ceramic, gravel,
  carpet, glass, plaster, wood, metal, rock). Nuestro `AcousticMaterialRegistry` tiene ocho
  nombres con `density`, `resonance_lpf` y **una** `absorption`. El vocabulario (`surface_type`)
  se conserva; cada nombre gana los siete números.
- **`OpenDouAcousticGeometryBake`** ya recoge triángulos con su material por malla del grupo
  `AcousticObstacle` (`get_baked_triangles()`, `export_to_dict()`). Es exactamente lo que
  `iplStaticMeshCreate` necesita: vértices, triángulos, índices de material y materiales.
- **El efecto directo** es `iplDirectEffectCreate(numChannels = 1)` + `iplDirectEffectApply(params)`
  con banderas `APPLYOCCLUSION | APPLYTRANSMISSION | APPLYAIRABSORPTION | APPLYDIRECTIVITY`
  (**no** `APPLYDISTANCEATTENUATION`: la atenuación por distancia sigue siendo la nuestra, con
  paridad exacta con Godot). Los parámetros salen del **simulador**: `iplSimulatorCreate`
  (`flags = DIRECT`, `sceneType = DEFAULT`, `maxNumOcclusionSamples`, `maxNumSources`),
  `iplSourceCreate` por voz, `iplSourceSetInputs` (posición, orientación, `occlusionType`
  `VOLUMETRIC` con `occlusionRadius`, `numOcclusionSamples`, `numTransmissionRays`, modelo de
  aire y directividad), `iplSimulatorRunDirect()` y `iplSourceGetOutputs().direct`.
- **`iplSimulatorRunDirect` es sincrónica y traza rayos**: con 64 fuentes y 16 muestras de
  oclusión son ~1000 rayos contra el bake. Va en el hilo principal, una vez por cuadro, con
  presupuesto del `AcousticLODController` (12.4). Las reflexiones (asíncronas) llegan en la 13.
- El stream nativo tiene el sitio exacto para el efecto: **en mono, tras los filtros y antes del
  HRTF** (la cadena de `OpenDouSpatialStreamPlayback`). Los parámetros se empujan desde el
  canal con una llamada por voz y cuadro, como `set_spatial_params` (deuda de coste pagada).
- El backend `godot` no tiene nada de esto: **`OcclusionManager` queda como fallback**
  (paso-bajo y −6 dB), igual que hoy.
- La directividad GDScript de la Fase 9 (`OpenDouDistanceModel.directivity_db`) da lo mismo que
  `iplDirectivityCalculate` con el mismo dipolo; en steam_audio con efecto directo se apaga la
  nuestra para no aplicarla dos veces.

---

## 2. Alcance

**Entra**

1. Recurso `AcousticMaterial` (por banda) y el registro que lo expone; los ocho presets.
2. `OpenDouAcousticScene` (nativo): la escena de Steam Audio construida desde el bake.
3. `OpenDouSimulator` (nativo, estático): simulador `DIRECT`, fuentes por voz, corrida por
   cuadro, salidas por fuente.
4. `IPLDirectEffect` en el stream nativo (`set_direct_params`), con el canal empujándolo; el
   `OcclusionScheduler` decide qué voces tienen fuente (LOD) y las alimenta; fallback intacto.
5. Presupuesto de simulación: guarda `tests/sim_budget.txt` y banco.
6. Documentación (`funcionalidades.md` §3, `AGENTS.md` observación 51 y trampas, `current.md`).

**No entra**

- Reflexiones, reverb por convolución, ambisonics (Fase 13). Sondas y geometría dinámica (14).
- Atenuación por distancia de Steam Audio (se conserva la nuestra por paridad).
- Materiales en el editor más allá del inspector del recurso (la UI del dock, Fase 15).

---

## 3. `AcousticMaterial`

`Resource`, `class_name AcousticMaterial`, `addons/opendou/resources/acoustic_material.gd`.

| Export | Tipo | Defecto |
|---|---|---|
| `material_name` | `StringName` | `&"Concrete"` |
| `absorption_low / _mid / _high` | float 0..1 | 0.05 / 0.07 / 0.08 |
| `scattering` | float 0..1 | 0.05 |
| `transmission_low / _mid / _high` | float 0..1 | 0.015 / 0.002 / 0.001 |
| `density_kg_m3`, `resonance_lpf_hz` | float | los del registro actual (se conservan para el fallback) |

- `to_ipl() -> PackedFloat32Array` (7 valores en el orden de `IPLMaterial`).
- `static from_preset(name: StringName) -> AcousticMaterial` con la tabla de los ocho:

| Nombre | absorción | scattering | transmisión | Base Steam Audio |
|---|---|---|---|---|
| Concrete | 0.05 0.07 0.08 | 0.05 | 0.015 0.002 0.001 | concrete |
| Stone | 0.13 0.20 0.24 | 0.05 | 0.015 0.002 0.001 | rock |
| Metal | 0.20 0.07 0.06 | 0.05 | 0.200 0.025 0.010 | metal |
| Glass | 0.06 0.03 0.02 | 0.05 | 0.060 0.044 0.011 | glass |
| Wood | 0.11 0.07 0.06 | 0.05 | 0.070 0.014 0.005 | wood |
| Foliage | 0.30 0.60 0.80 | 0.60 | 0.500 0.300 0.150 | propio (poroso, deja pasar) |
| Water | 0.01 0.01 0.02 | 0.05 | 0.010 0.002 0.001 | propio (reflectante) |
| Asphalt | 0.10 0.15 0.20 | 0.10 | 0.010 0.002 0.001 | gravel/concrete |

`AcousticMaterialRegistry` gana `get_acoustic_material(name) -> AcousticMaterial` (preset o
personalizado), `register_acoustic_material(mat)`, y su JSON persiste los siete números. Lo que
ya existe (`calculate_transmission_loss`, densidad, corte) no cambia: es el fallback.

**Se afirma:** los ocho presets cargan con valores en [0,1]; un material guardado y recargado
por JSON conserva los siete números; `Glass` transmite más banda alta que `Concrete`.

---

## 4. `OpenDouAcousticScene` (nativo)

Clase estática registrada como `OpenDouAcousticScene` (`native/src/acoustic_scene.{h,cpp}`):

- `build(vertices: PackedVector3Array, triangles: PackedInt32Array, material_indices: PackedInt32Array, materials: Array) -> bool`:
  `iplSceneCreate(DEFAULT)` si no existe, `iplStaticMeshCreate`, `iplStaticMeshAdd`,
  `iplSceneCommit`. `materials` es un `Array` de `PackedFloat32Array(7)`. Reemplaza la malla
  anterior (remove + release). Godot es Y-arriba y diestro como Steam Audio: **sin conversión
  de ejes**; se comprueba con un rayo de prueba.
- `clear()`, `is_ready() -> bool`, `triangle_count() -> int`, `material_count() -> int`.
- `probe_ray(from: Vector3, to: Vector3) -> bool` (un `iplSimulatorRunDirect` con una fuente
  temporal no es barato: en su lugar, la comprobación de ejes usa la oclusión de una fuente
  real en el test).

`OpenDouAcousticGeometryBake` gana `export_to_native() -> bool`: aplana `get_baked_triangles()`
a los tres `Packed*Array` y pide al registro los materiales; se llama al final de
`bake_geometry()` cuando la extensión está y `feed_steam_audio = true` (export nuevo, `true`).

**Se afirma:** tras el bake de la quilla, `triangle_count()` de la escena nativa es igual a
`get_baked_triangle_count()`; construir y limpiar cien veces no deja fugas (el contador de la
suite); sin extensión, `export_to_native()` devuelve `false` sin error.

---

## 5. `OpenDouSimulator` (nativo)

Clase estática `OpenDouSimulator` (`native/src/simulator.{h,cpp}`):

- `configure(max_sources: int = 64, occlusion_samples: int = 16, transmission_rays: int = 2) -> bool`:
  `iplSimulatorCreate(flags = DIRECT, sceneType = DEFAULT, maxNumOcclusionSamples,
  maxNumSources, samplingRate, frameSize)`, `iplSimulatorSetScene(scene)`, `commit`.
- `create_source() -> int` (handle ≥ 0; −1 si no cabe), `release_source(handle)`. Añadir o
  quitar fuentes exige `iplSimulatorCommit`; se hace una vez por cuadro si hubo cambios.
- `set_source_inputs(handle, position: Vector3, forward: Vector3, up: Vector3, dipole_weight: float, dipole_power: float, occlusion_radius: float)`:
  `IPLSimulationInputs{flags = DIRECT, directFlags = OCCLUSION | TRANSMISSION | AIRABSORPTION |
  DIRECTIVITY, source = espacio, occlusionType = VOLUMETRIC, occlusionRadius,
  numOcclusionSamples, numTransmissionRays, airAbsorptionModel = DEFAULT, directivity}`.
- `set_listener(position, forward, up)` (`iplSimulatorSetSharedInputs`).
- `run_direct()`: `iplSimulatorRunDirect` en el hilo principal. Devuelve los µs que tardó.
- `get_direct(handle) -> PackedFloat32Array(8)`: `[occlusion, tr_low, tr_mid, tr_high,
  air_low, air_mid, air_high, directivity]`.
- `source_count()`, `last_run_usec()`.

**Se afirma:** con la escena de un muro de `Glass` entre fuente y oyente, `occlusion` < 0.3 y
`transmission` alta > baja; con muro de `Concrete`, `transmission` ≈ 0 en las tres bandas;
sin muro, `occlusion` ≈ 1 y `transmission` = 1. A 200 m sin muro, `air_high` < `air_low`.

---

## 6. El efecto directo en la cadena

**Stream nativo.** `OpenDouSpatialStreamPlayback` crea un `IPLDirectEffect` (1 canal) junto al
binaural. Nuevo estado atómico en el stream: `direct_enabled_`, `direct_occlusion_`,
`direct_transmission_[3]`, `direct_air_[3]`, `direct_directivity_`. Método
`set_direct_params(enabled: bool, occlusion: float, transmission: Vector3, air: Vector3, directivity: float)`
(una llamada por voz y cuadro). En el bloque, tras filtros y ganancia y antes del retardo por
distancia: si `direct_enabled_`, `iplDirectEffectApply` con
`flags = OCCLUSION | TRANSMISSION | AIRABSORPTION | DIRECTIVITY`, `transmissionType =
FREQDEPENDENT`, sobre `in_buffer_` (in-place permitido). Con `enabled = false` no cuesta nada.

**Canal.** `PhysicalVoiceChannel` guarda `sim_source: int = -1`. `apply_spatial` en el backend
steam_audio: si `sim_source >= 0`, lee `OpenDouSimulator.get_direct(sim_source)` y llama a
`set_direct_params(true, …)`; además **no** aplica el paso-bajo de oclusión del
`OcclusionManager` (el `cutoff_hz` que llega se ignora cuando el efecto directo está activo) y
el manager **no** suma la directividad GDScript a esa voz.

**Planificador.** `OcclusionScheduler.process(...)` en steam_audio con `OpenDouSimulator.is_ready()`:
las voces elegibles (LOD) sin fuente piden una (`create_source`); las que dejan de ser
elegibles la sueltan; para cada fuente `set_source_inputs(pos, forward, up, dipolo, radio)`;
`set_listener(...)`; `run_direct()` **una vez**; `raycasts_this_frame` pasa a contar fuentes
simuladas. Las voces sin fuente (fuera del alcance del LOD) siguen con el rayo de Godot y el
`OcclusionManager`, como hoy: dos calidades, un solo presupuesto. `sim_source` se suelta en
`virtualize`.

**Doble backend.** Godot: nada cambia. Steam_audio sin escena (`OpenDouAcousticScene.is_ready()
== false`): nada cambia tampoco; el efecto directo exige un bake.

**Se afirma** (bus de sonda, ruido periódico, escena del test con un muro de 0.3 m entre la
fuente a 6 m y el oyente): tras `Glass`, la banda 4–8 kHz cae menos que tras `Concrete` (al
menos 6 dB de diferencia entre materiales); sin muro, el espectro iguala al de la voz sin
efecto (±1 dB por banda); a 200 m sin muro, la banda 4–8 kHz cae al menos 3 dB más que la
banda 200–800 Hz respecto a 10 m (absorción del aire); una fuente con `directivity_dipole_weight
= 1` de espaldas al oyente suena al menos 10 dB menos que de frente, y la suma GDScript +
nativa no se aplica dos veces (medido igual al dipolo solo).

---

## 7. Presupuesto de simulación

`AcousticLODController.get_lod_features` ya trae `enable_physics_occlusion` por nivel; gana
`enable_direct_simulation` (LOD 0 y 1 = true; 2 = false: solo rayo de Godot; 3 = nada). El
número de muestras de oclusión por fuente baja con el LOD (16 en LOD 0, 8 en LOD 1).
`tests/sim_budget.txt`: µs de `run_direct()` con 64 fuentes y la escena de la quilla, medido en
la primera corrida y fijado con margen ×2 (mínimo de cinco corridas, como el presupuesto DSP).
El banco `tools/bench_control_loop.gd` gana `OPENDOU_BENCH_DIRECT=1` (escena + fuentes).

---

## 8. Cambios en lo que existe

| Archivo | Cambio |
|---|---|
| `resources/acoustic_material.gd` (nuevo), `runtime/spatial/acoustic_material_registry.gd` | recurso y registro por banda |
| `native/src/acoustic_scene.{h,cpp}`, `native/src/simulator.{h,cpp}`, `register_types.cpp`, `CMakeLists.txt` | escena y simulador |
| `native/src/spatial_stream.{h,cpp}` | `IPLDirectEffect`, `set_direct_params` |
| `nodes/opendou_acoustic_geometry_bake.gd` | `feed_steam_audio`, `export_to_native()` |
| `runtime/physical_voice_channel.gd`, `runtime/voice_pool_manager.gd` | `sim_source`, empuje de parámetros, liberación |
| `runtime/spatial/occlusion_scheduler.gd`, `runtime/spatial/acoustic_lod_controller.gd` | fuentes por LOD, `run_direct` |
| `runtime/audio_event_manager.gd` | no sumar directividad GDScript a voces con fuente |
| `tests/sim_budget.txt`, `tools/bench_control_loop.gd` | presupuesto |

## 9. Tests

`tests/test_acoustic_material.gd` (síncrono), `tests/test_steam_scene.gd`,
`tests/test_direct_effect.gd`, `tests/test_sim_budget.gd` (todos omitidos con aviso sin
extensión). Reglas de siempre: bus de sonda, cámara, esperar por muestras, `set_manager`.

## 10. Riesgos

- **Ejes y unidades**: Steam Audio es Y-arriba diestro en metros, como Godot; si un test de
  oclusión da «sin muro» con muro, lo primero es el orden de los vértices (winding) y el
  `IPLCoordinateSpace3` del oyente (`ahead = −Z`, `right = +X`, `up = +Y`).
- **`run_direct` en el hilo principal**: si con 64 fuentes supera 1 ms, bajar muestras por LOD
  antes de pensar en un hilo (las reflexiones de la 13 sí van en hilo).
- **Doble oclusión**: rayo de Godot + efecto directo sobre la misma voz sería cobrar dos veces;
  el canal ignora `cutoff_hz` cuando hay fuente. El grafo de salas (`room_path_active`) sigue
  excluyendo la voz del planificador, como hoy.

## 11. Correcciones que la ejecución obligue a hacer

Se anotan aquí, numeradas.
