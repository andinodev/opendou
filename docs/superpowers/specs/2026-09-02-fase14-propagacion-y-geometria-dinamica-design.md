# Fase 14 — Propagación por sondas y geometría dinámica

**Fecha:** 2026-09-02
**Estado:** Diseñado sin intervención del usuario; **dudas abiertas en [`docs/tasks/observaciones-fases-12-14.md`](../../tasks/observaciones-fases-12-14.md)**. Pendiente de resolverlas antes de ejecutar.
**Rama:** `main`
**Godot verificado:** 4.7.2 · **Steam Audio:** 4.8.1
**Hoja de ruta:** [`docs/roadmap/2026-09-02-sprint-aaa.md`](../../roadmap/2026-09-02-sprint-aaa.md), Fase 14
**Fase anterior:** [13](2026-09-02-fase13-reflexiones-y-ambisonics-design.md)

---

## 1. Contexto

El grafo de salas y portales (Fase 6) es propagación **autorada**: barata, determinista y bajo
el control del diseñador. Lo que nadie autoró (una esquina sin portal, un pasillo en L) hoy
no propaga nada: la voz se ocluye y ya. Steam Audio resuelve eso con **sondas precocinadas**
(`IPLProbeBatch`) y el efecto de caminos, que entrega por fuente una **dirección aparente** y
una **atenuación por banda**. Y las puertas que giran hoy solo mueven el portal: con
`IPLInstancedMesh` también **ocluyen** de verdad mientras giran.

Hechos comprobados al preparar el spec:

- **Sondas**: `iplProbeArrayCreate` → `iplProbeArrayGenerateProbes(scene, params{type =
  UNIFORMFLOOR, spacing, height, transform})` → `iplProbeBatchCreate` + `AddProbeArray` +
  `Commit`; **bake de caminos** offline `iplPathBakerBake(context, params{scene, probeBatch,
  identifier{type = PATHING}, numSamples, radius, threshold, visRange, pathRange, numThreads},
  progress)`; guardado con `iplProbeBatchSave(batch, serializedObject)` (bytes) y carga con
  `iplProbeBatchLoad`. Es la pieza de editor: un botón en el inspector del bake, como el bake
  de geometría (`OpenDouAcousticGeometryBakeInspectorPlugin` ya existe).
- **Caminos en runtime**: fuente con `flags = PATHING`, entradas `pathingProbes`, `visRadius`,
  `visThreshold`, `visRange`, `pathingOrder`, `enableValidation`, `findAlternatePaths`;
  `iplSimulatorRunPathing` (en hilo, como las reflexiones); salidas `IPLPathEffectParams`
  (`eqCoeffs[3]`, `shCoeffs[]` de orden `pathingOrder`, `normalizeEQ`). **Los coeficientes SH de
  orden 1 codifican la dirección aparente** (X, Y, Z) y `eqCoeffs` la atenuación por banda: es
  todo lo que el **origen aparente** de la Fase 6 (`current_apparent_position`) necesita. No hace
  falta `iplPathEffectApply` ni decodificar ambisonics por voz: la voz sigue saliendo por
  nuestro panner, con la dirección y la banda que dan las sondas. Barato y coherente con el
  grafo de portales.
- **Geometría dinámica**: `iplInstancedMeshCreate(scene, {subScene, transform})`,
  `iplInstancedMeshAdd`, `iplInstancedMeshUpdateTransform(mesh, scene, matrix)`, `iplSceneCommit`
  tras cambios. Cada malla dinámica es su **propia sub-escena** (una `IPLScene` con un
  `IPLStaticMesh`) instanciada en la escena principal.
- **Visualización**: `IPLSimulationSharedInputs.pathingVisCallback(from, to, occluded)` se
  invoca durante `iplSimulatorRunPathing`; el nativo acumula segmentos y GDScript los lee.
- `EdgeDiffractionEngine` y `RoomCouplingEngine` siguen **inertes** (nadie los invoca; solo los
  precarga `SpatialAcousticsManager`). Sus tests, si existen, afirman aritmética sin consumidor.

---

## 2. Alcance

**Entra**

1. Sondas en el bake: exports, `bake_probes()`, archivo `.probes`, carga en runtime.
2. `OpenDouSimulator` gana `PATHING` (hilo compartido con reflexiones) y `get_pathing(handle)
   -> {direction, eq}`; el manager convierte dirección y banda en origen aparente y filtro de
   la voz, con prioridad del grafo autorado.
3. Ocluidores dinámicos: grupo `AcousticObstacleDynamic`, `OpenDouAcousticScene.add_instanced`,
   `update_instanced_transform`, seguimiento con umbral en el bake.
4. Depurador: `OpenDouAcousticDebugger3D.show_paths` dibuja los segmentos reales.
5. Retirada de `EdgeDiffractionEngine` y `RoomCouplingEngine` y conversión de sus tests.
6. Documentación.

**No entra**

- Bake de reflexiones precocinadas (`IPL_BAKEDDATATYPE_REFLECTIONS`): las reflexiones son en
  vivo (Fase 13).
- `iplPathEffectApply` (render ambisónico del camino por voz): el camino solo aporta dirección
  y banda. Se documenta como opción futura.
- Geometría **deformable** (solo transformaciones rígidas).

---

## 3. Sondas en el bake

`OpenDouAcousticGeometryBake` gana el grupo «Probes»: `probe_spacing_m` (2.0), `probe_height_m`
(1.5), `probe_bounds: AABB` (vacío = AABB del bake), `probes_path: String`
(`res://<escena>.probes`; vacío = junto a la escena), `auto_load_probes` (true).

- `bake_probes() -> Dictionary {probe_count, bytes}` (editor, botón «Bake probes» en el
  inspector junto a «Bake»): exige escena nativa lista; `OpenDouAcousticScene.generate_probes(spacing,
  height, aabb) -> int`, `bake_paths(num_samples = 8, radius = 1.0, threshold = 0.1,
  vis_range = 50, path_range = 100) -> bool`, `save_probes(path) -> bool` (bytes del
  `IPLSerializedObject` a `FileAccess`). Progreso por señal `probe_bake_progress(fraction)`.
- `load_probes(path) -> bool` en `_ready` si `auto_load_probes` y el archivo existe:
  `iplProbeBatchLoad` + `iplSimulatorAddProbeBatch` + commit. Sin archivo: aviso una vez, sin
  caminos (todo lo demás funciona).
- `.probes` es binario versionable (Steam Audio lo serializa); se añade a los patrones de la
  guarda de assets como permitido (no es audio).

**Se afirma:** en la escena del test (dos habitaciones en L sin portal, 12 × 6 m), generar
sondas a 2 m da entre 15 y 25 sondas; el bake de caminos termina y el archivo se guarda y
recarga con el mismo número de sondas; el conteo tras recargar es igual.

---

## 4. Caminos como origen aparente

`OpenDouSimulator`: `flags` gana `PATHING`; `set_source_pathing(handle, enabled, order = 1)`
fija `pathingProbes` (el lote cargado), `visRadius` 1, `visThreshold` 0.1, `visRange` 50,
`pathingOrder` 1, `enableValidation` true, `findAlternatePaths` false (hasta la 14.2 con
dinámicos: true). `iplSimulatorRunPathing` corre en el **mismo hilo** que las reflexiones,
alternando. `get_pathing(handle) -> Dictionary {valid: bool, direction: Vector3, eq: Vector3}`:
`direction` = normalizada de `(shCoeffs[3], shCoeffs[1], −shCoeffs[2])` (ACN orden 1: Y, Z, X →
convención SN3D de Steam Audio comprobada en el test con una fuente a la vista: la dirección
tiene que coincidir con la real), `eq` = `eqCoeffs`; `valid` cuando la energía SH no es cero.

**Manager.** Para las voces físicas con fuente de caminos: si `room_path_active` (el grafo
autorado gobierna) **no se toca**: el diseñador manda. Si no, y `valid`: `target_apparent_position
= listener + direction · distancia_real` y el corte de paso-bajo se deriva de `eq` (banda alta
< 0.5 → corte 4 kHz; < 0.2 → 1.5 kHz; interpolado) sumado a la oclusión directa. Sin caminos
válidos (sin sondas o sin línea de propagación), nada cambia.

**Se afirma:** emisor tras la esquina de la L sin portal: `valid`, la dirección aparente
apunta a la esquina (a menos de 25° del vector oyente→esquina) y no al emisor real (más de 60°
de diferencia); el nivel es menor que a la vista y mayor que sin caminos (donde solo hay
oclusión directa); con un `OpenDouPortal3D` autorado en la esquina, manda el grafo (posición
aparente = portal, sin cambio respecto a la Fase 6).

---

## 5. Ocluidores dinámicos

Grupo `AcousticObstacleDynamic`. `OpenDouAcousticGeometryBake` los recoge aparte
(`dynamic_group`, `&"AcousticObstacleDynamic"`): por cada `MeshInstance3D` crea una sub-escena
(`OpenDouAcousticScene.add_instanced(vertices, triangles, material_indices, materials, transform)
-> int`) y guarda `{id, node, last_transform}`. En `_process` (o `_physics_process`) del bake:
si el transform cambió más de `dynamic_position_threshold_m` (0.02) o `dynamic_angle_threshold_deg`
(1.0): `update_instanced_transform(id, transform)` y marca sucio; un `commit()` por cuadro si
hubo cambios. El efecto directo (Fase 12) los ve sin más: la escena es la misma.

**Se afirma:** una hoja de puerta (`AcousticObstacleDynamic`) entre fuente y oyente: cerrada
(0°), `occlusion` del efecto directo < 0.3; a 45°, entre 0.3 y 0.8; abierta (90°), > 0.8;
quieta durante 60 cuadros, cero `update_instanced_transform` (contador expuesto).

---

## 6. El depurador dibuja los caminos reales

`OpenDouSimulator.get_path_segments() -> PackedVector3Array` (pares from/to) y
`get_path_segments_occluded() -> PackedByteArray`, llenados por `pathingVisCallback` durante
la última corrida (doble búfer). `OpenDouAcousticDebugger3D.show_paths` (true) los dibuja
con `ImmediateMesh` (verde libre, rojo ocluido). **Se afirma:** estructura (tras una corrida
con caminos válidos hay al menos un segmento) y ausencia de errores.

---

## 7. Retirada de `EdgeDiffractionEngine` y `RoomCouplingEngine`

Se borran los dos archivos y sus precargas en `SpatialAcousticsManager` (`diffraction_engine`,
`coupling_engine` pasan a no existir; la suite avisa si alguien los referencia). Sus tests, si
afirmaban la aritmética, se retiran; si afirmaban comportamiento del portal (`test_portal_
diffraction.gd` afirma el LPF del portal, que es del grafo), se quedan. `docs/funcionalidades.md`
los saca de la tabla (⚪ → retirado, con el porqué).

---

## 8. Cambios en lo que existe

| Archivo | Cambio |
|---|---|
| `native/src/acoustic_scene.{h,cpp}` | sondas, bake de caminos, guardado/carga, sub-escenas instanciadas |
| `native/src/simulator.{h,cpp}` | `PATHING`, hilo compartido, `get_pathing`, segmentos |
| `nodes/opendou_acoustic_geometry_bake.gd`, `editor/…bake_inspector_plugin.gd` | grupo Probes, botón, dinámicos |
| `nodes/opendou_acoustic_debugger_3d.gd` | `show_paths` |
| `runtime/audio_event_manager.gd`, `runtime/spatial/occlusion_scheduler.gd` | fuentes con caminos, origen aparente y filtro |
| `runtime/spatial/spatial_acoustics_manager.gd` | sin difracción ni acoplamiento |
| `tests/test_scene_guards.gd` | `.probes` permitido |

## 9. Tests

`tests/test_probes_bake.gd` (generar, bake, guardar, recargar), `tests/test_pathing_apparent.gd`
(la L, la esquina, el portal manda), `tests/test_dynamic_occluder.gd` (la puerta a 0/45/90°),
`tests/test_acoustic_debugger.gd` (segmentos). Todos omitidos con aviso sin extensión.

## 10. Riesgos

- **Tiempo del bake de caminos** en la suite: la L es pequeña (20 sondas); si supera 5 s se
  baja `numSamples` a 4 y `pathRange` a 30.
- **Convención de los coeficientes SH**: si la dirección sale espejada, el test «fuente a la
  vista» lo detecta y se permutan los índices; se anota.
- **Un hilo para reflexiones y caminos**: alternar puede bajar la frecuencia de cada uno a 5 Hz;
  aceptable para reverb y caminos (el origen aparente se suaviza con `apparent_smoothing_speed`).

## 11. Correcciones que la ejecución obligue a hacer

Se anotan aquí, numeradas.
