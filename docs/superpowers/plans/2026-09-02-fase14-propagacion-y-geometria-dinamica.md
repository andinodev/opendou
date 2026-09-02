# Fase 14 — Propagación por sondas y geometría dinámica: plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sondas precocinadas en el bake con su archivo `.probes`, caminos de Steam Audio convertidos en dirección aparente y filtro de la voz (el grafo autorado manda), ocluidores dinámicos que Steam Audio ve moverse, el depurador dibujando los caminos reales, y la retirada de dos motores inertes.

**Architecture:** `OpenDouAcousticScene` gana sondas, bake de caminos, serialización y sub-escenas instanciadas; `OpenDouSimulator` gana `PATHING` en el mismo hilo que las reflexiones y expone por fuente dirección (desde los coeficientes SH de orden 1) y ecualización por banda, más los segmentos de visualización. El manager traduce eso a `target_apparent_position` y al corte de la voz, sin tocar las voces gobernadas por portales. El bake sigue las mallas del grupo dinámico con umbral.

**Tech Stack:** Godot 4.7.2, GDExtension C++17, Steam Audio 4.8.1, CMake, suite headless.

**Spec:** `docs/superpowers/specs/2026-09-02-fase14-propagacion-y-geometria-dinamica-design.md` · **Observaciones a resolver antes:** `docs/tasks/observaciones-fases-12-14.md` (A9–A12, B10–B12).

## Global Constraints

- Los de las Fases 12 y 13 (rama, commits, suite, omisión con aviso sin extensión, bus de sonda, CMake, `commit` bajo mutex y nunca durante una corrida).
- `.probes` es binario: se añade a `.gitattributes` como binario y la guarda de assets (`tests/test_scene_guards.gd`, `AUDIO_EXTENSIONS`) no lo considera audio.
- Un test que hace bake de caminos no puede pasar de 5 s: escena pequeña (≈20 sondas).

---

## Estructura de archivos

| Archivo | Responsabilidad |
|---|---|
| `native/src/acoustic_scene.{h,cpp}` | sondas, bake de caminos, `save_probes/load_probes`, sub-escenas instanciadas |
| `native/src/simulator.{h,cpp}` | `PATHING`, `get_pathing`, segmentos de visualización, hilo compartido |
| `addons/opendou/nodes/opendou_acoustic_geometry_bake.gd` | grupo Probes, `bake_probes`, `load_probes`, dinámicos |
| `addons/opendou/editor/opendou_acoustic_geometry_bake_inspector.gd` | botón «Bake probes» y progreso |
| `addons/opendou/runtime/spatial/occlusion_scheduler.gd`, `runtime/audio_event_manager.gd` | fuentes con caminos, origen aparente y filtro |
| `addons/opendou/nodes/opendou_acoustic_debugger_3d.gd` | `show_paths` |
| `addons/opendou/runtime/spatial/spatial_acoustics_manager.gd` | sin difracción ni acoplamiento |
| tests | `test_probes_bake.gd`, `test_pathing_apparent.gd`, `test_dynamic_occluder.gd`, `test_acoustic_debugger.gd` (ampliado), `test_spatial_acoustics_phase2.gd` (convertido) |

---

### Task 1: Sondas en la escena nativa y en el bake (generar, bake, guardar, cargar)

**Files:** `native/src/acoustic_scene.{h,cpp}`, `nodes/opendou_acoustic_geometry_bake.gd`, `editor/opendou_acoustic_geometry_bake_inspector.gd`, `.gitattributes`; test `tests/test_probes_bake.gd`.

**Interfaces:**
- Produces (estáticos en `OpenDouAcousticScene`): `generate_probes(spacing_m: float, height_m: float, bounds: AABB) -> int`, `bake_paths(num_samples: int, radius: float, threshold: float, vis_range: float, path_range: float) -> bool`, `save_probes(path: String) -> bool`, `load_probes(path: String) -> bool`, `probe_count() -> int`, `has_probes() -> bool`; C++: `static IPLProbeBatch probes()`. Bake: exports `probe_spacing_m` (2.0), `probe_height_m` (1.5), `probe_bounds: AABB`, `probes_path: String`, `auto_load_probes` (true); `bake_probes() -> Dictionary {probe_count, bytes}`, `load_probes(path = "") -> bool`, señal `probe_bake_progress(fraction: float)`, `default_probes_path() -> String` (`<ruta de la escena sin extensión>.probes`).

- [ ] **Step 1: Test en rojo**

```gdscript
class_name TestProbesBake
extends RefCounted

## Fase 14: sondas generadas sobre el bake, caminos precocinados, archivo .probes que se
## guarda y recarga con el mismo numero de sondas.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TestSteamSceneClass = preload("res://tests/test_steam_scene.gd")
const BakeScript = preload("res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd")

## Dos habitaciones en L (12 x 6 m, 3 m de alto) sin portal: un muro interior deja la esquina.
static func make_l_rooms(tree: SceneTree) -> Array:
	var bodies: Array = []
	var specs: Array = [
		[Vector3(0, -0.15, 0), Vector3(12, 0.3, 6)],       # suelo
		[Vector3(0, 3.15, 0), Vector3(12, 0.3, 6)],        # techo
		[Vector3(-6.15, 1.5, 0), Vector3(0.3, 3, 6)],      # pared oeste
		[Vector3(6.15, 1.5, 0), Vector3(0.3, 3, 6)],       # pared este
		[Vector3(0, 1.5, -3.15), Vector3(12, 3, 0.3)],     # pared norte
		[Vector3(0, 1.5, 3.15), Vector3(12, 3, 0.3)],      # pared sur
		[Vector3(0, 1.5, -1.0), Vector3(0.3, 3, 4.0)],     # tabique interior: deja hueco en z de +1 a +3
	]
	for sp in specs:
		var body := StaticBody3D.new()
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = sp[1]
		mi.mesh = box
		mi.add_to_group("AcousticObstacle")
		mi.set_meta("acoustic_material", &"Concrete")
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = sp[1]
		cs.shape = sh
		body.add_child(cs)
		tree.root.add_child(body)
		body.global_position = sp[0]
		bodies.append(body)
	return bodies

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("probes_bake")
	if not TestSteamSceneClass._native():
		print("[OpenDou] extension nativa AUSENTE: sondas omitidas")
		return a
	var bodies: Array = make_l_rooms(tree)
	var bake = BakeScript.new()
	bake.auto_bake_on_ready = false
	bake.auto_load_probes = false
	bake.probe_spacing_m = 2.0
	bake.probe_height_m = 1.5
	bake.probes_path = "user://opendou_test_l.probes"
	tree.root.add_child(bake)
	bake.bake_geometry(tree.root)
	a.ok(bake.export_to_native(), "la L es una escena nativa")
	var progress: Array = []
	bake.probe_bake_progress.connect(func(f): progress.append(f))
	var t0: int = Time.get_ticks_msec()
	var result: Dictionary = bake.bake_probes()
	var ms: int = Time.get_ticks_msec() - t0
	print("[OpenDou] sondas: %d generadas, %d bytes, %d ms, progreso %d avisos" % [int(result.get("probe_count", 0)), int(result.get("bytes", 0)), ms, progress.size()])
	a.ok(int(result.probe_count) >= 12 and int(result.probe_count) <= 30, "a 2 m salen entre 12 y 30 sondas (%d)" % int(result.probe_count))
	a.gt(float(result.bytes), 0.0, "el archivo tiene datos")
	a.lt(float(ms), 5000.0, "el bake de caminos baja de 5 s")
	a.ok(FileAccess.file_exists(bake.probes_path), "el .probes existe")
	var n: int = int(result.probe_count)
	OpenDouAcousticScene.clear_probes()
	a.ok(not OpenDouAcousticScene.has_probes(), "sin sondas tras limpiar")
	a.ok(bake.load_probes(), "el .probes se recarga")
	a.eq(OpenDouAcousticScene.probe_count(), n, "con el mismo numero de sondas")
	OpenDouAcousticScene.clear_probes()
	OpenDouAcousticScene.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bake.probes_path))
	tree.root.remove_child(bake); bake.free()
	for b in bodies:
		tree.root.remove_child(b); b.free()
	return a
```
(Añade `clear_probes()` a la interfaz producida.)

- [ ] **Step 2: Correr y ver el fallo.**
- [ ] **Step 3: Implementar.** Nativo:
```cpp
int OpenDouAcousticScene::generate_probes(float spacing, float height, const AABB &bounds) {
	if (!is_ready()) return 0;
	clear_probes();
	IPLProbeArray arr = nullptr;
	if (iplProbeArrayCreate(SteamAudioContext::context(), &arr) != IPL_STATUS_SUCCESS) return 0;
	IPLProbeGenerationParams p = {};
	p.type = IPL_PROBEGENERATIONTYPE_UNIFORMFLOOR;
	p.spacing = spacing; p.height = height;
	p.transform = box_transform(bounds);   // matriz 4x4 fila-mayor: escala = tamano de la caja, traslacion = centro
	iplProbeArrayGenerateProbes(arr, scene_, &p);
	if (iplProbeBatchCreate(SteamAudioContext::context(), &probes_) != IPL_STATUS_SUCCESS) { iplProbeArrayRelease(&arr); probes_ = nullptr; return 0; }
	iplProbeBatchAddProbeArray(probes_, arr);
	iplProbeBatchCommit(probes_);
	probe_count_ = iplProbeArrayGetNumProbes(arr);
	iplProbeArrayRelease(&arr);
	return probe_count_;
}
bool OpenDouAcousticScene::bake_paths(int num_samples, float radius, float threshold, float vis_range, float path_range) {
	if (!is_ready() || probes_ == nullptr) return false;
	IPLPathBakeParams b = {};
	b.scene = scene_; b.probeBatch = probes_;
	b.identifier.type = IPL_BAKEDDATATYPE_PATHING; b.identifier.variation = IPL_BAKEDDATAVARIATION_DYNAMIC;
	b.numSamples = num_samples; b.radius = radius; b.threshold = threshold; b.visRange = vis_range; b.pathRange = path_range; b.numThreads = 2;
	iplPathBakerBake(SteamAudioContext::context(), &b, &progress_callback, nullptr);
	iplProbeBatchCommit(probes_);
	return true;
}
bool OpenDouAcousticScene::save_probes(const String &path) {
	if (probes_ == nullptr) return false;
	IPLSerializedObjectSettings s = {}; IPLSerializedObject obj = nullptr;
	if (iplSerializedObjectCreate(SteamAudioContext::context(), &s, &obj) != IPL_STATUS_SUCCESS) return false;
	iplProbeBatchSave(probes_, obj);
	const IPLsize n = iplSerializedObjectGetSize(obj);
	PackedByteArray bytes; bytes.resize(n); memcpy(bytes.ptrw(), iplSerializedObjectGetData(obj), n);
	iplSerializedObjectRelease(&obj);
	Ref<FileAccess> f = FileAccess::open(path, FileAccess::WRITE);
	if (f.is_null()) return false;
	f->store_buffer(bytes); last_saved_bytes_ = static_cast<int>(n); return true;
}
bool OpenDouAcousticScene::load_probes(const String &path) {
	Ref<FileAccess> f = FileAccess::open(path, FileAccess::READ);
	if (f.is_null()) return false;
	PackedByteArray bytes = f->get_buffer(f->get_length());
	IPLSerializedObjectSettings s = {}; s.data = bytes.ptrw(); s.size = bytes.size();
	IPLSerializedObject obj = nullptr;
	if (iplSerializedObjectCreate(SteamAudioContext::context(), &s, &obj) != IPL_STATUS_SUCCESS) return false;
	clear_probes();
	const IPLerror e = iplProbeBatchLoad(SteamAudioContext::context(), obj, &probes_);
	iplSerializedObjectRelease(&obj);
	if (e != IPL_STATUS_SUCCESS) { probes_ = nullptr; return false; }
	iplProbeBatchCommit(probes_);
	probe_count_ = iplProbeBatchGetNumProbes(probes_);
	probes_generation_++;
	return true;
}
```
Comprobar en `phonon.h` los nombres exactos (`IPLPathBakeParams`, `iplPathBakerBake`, `iplProbeBatchGetNumProbes`, `iplSerializedObjectSettings.data/size`). El progreso: callback estático que guarda `progress_` atómico; el bake GDScript lo emite como señal al terminar (`bake_paths` es sincrónico; se emite 0 y 1) — un progreso fino exige hilo y no entra.
Bake GDScript: exports; `bake_probes()`: `export_to_native()` si no está lista; `generate_probes(spacing, height, bounds vacío → get_baked_aabb_union())`; `bake_paths(8, 1.0, 0.1, 50, 100)`; `save_probes(path)`; devuelve `{probe_count, bytes}`. `load_probes(path = "")`: `probes_path` o `default_probes_path()`; en `_ready` si `auto_load_probes and FileAccess.file_exists(...)`. Inspector: segundo botón «Bake probes» que llama `bake_probes()` y muestra el conteo. `.gitattributes`: `*.probes binary`.

- [ ] **Step 4: Compilar, correr** → verde; anotar sondas y ms medidos en el spec §11.
- [ ] **Step 5: Commit** — `git commit -m "Fase 14: sondas en el bake: generar, precocinar caminos, guardar y recargar .probes"`

---

### Task 2: `PATHING` en el simulador y el origen aparente

**Files:** `native/src/simulator.{h,cpp}`, `runtime/spatial/occlusion_scheduler.gd`, `runtime/audio_event_manager.gd`; test `tests/test_pathing_apparent.gd`.

**Interfaces:**
- Produces: `OpenDouSimulator.set_source_pathing(handle: int, enabled: bool, order: int = 1)`, `start_reflections(hz)` corre también `iplSimulatorRunPathing` cuando hay fuentes con caminos (mismo hilo, alternando), `get_pathing(handle) -> Dictionary {valid: bool, direction: Vector3, eq: Vector3}`, `pathing_generation(handle) -> int`; canal `pathing_enabled: bool`; manager `pathing_enabled: bool = true` y la regla del §4 del spec.

- [ ] **Step 1: Test en rojo** — la L de `TestProbesBake.make_l_rooms`, bake, sondas y caminos (o `load_probes` de un `.probes` generado en el mismo test); manager steam_audio con oyente en (−4, 1.5, 2) (habitación oeste, cerca del hueco) y una voz en (4, 1.5, −2) (habitación este, sin línea de vista: el tabique tapa); `start_reflections(10)`; esperar `pathing_generation` > 0 (máx 3 s); afirmar `get_pathing(h).valid`; la dirección aparente (`inst.current_apparent_position - listener`) apunta a menos de 25° del vector oyente→esquina del hueco `(0, 1.5, 2)` y a más de 60° del vector oyente→emisor real; el RMS en el bus de sonda es menor que con la voz a la vista (misma distancia, sin tabique) y mayor que con `manager.pathing_enabled = false` (solo oclusión directa); con un `OpenDouPortal3D` registrado en el hueco (`room_path_active`), la posición aparente es la del portal, no la de las sondas. Y la comprobación de convención: voz a la vista → `direction` a menos de 10° de la real (B10).
- [ ] **Step 2: Correr y ver el fallo.**
- [ ] **Step 3: Implementar.** Simulador: `configure(...)` con `flags |= PATHING` cuando `OpenDouAcousticScene::has_probes()`; `set_source_pathing(h, on, order)`: `IPLSimulationInputs{flags = PATHING, source, pathingProbes = probes(), visRadius = 1.0, visThreshold = 0.1, visRange = 50, pathingOrder = order, enableValidation = true, findAlternatePaths = false}` guardado por fuente (la posición se actualiza en `set_source_inputs`, que ahora también reescribe las entradas de pathing si la fuente lo tiene); en el hilo, tras `RunReflections`: `if any_pathing: iplSimulatorRunPathing(sim_)` y `iplSourceGetOutputs(PATHING)` con `pathingVisCallback` registrado en `SetSharedInputs(PATHING, {listener, pathingVisCallback = &vis_cb, pathingUserData})`. `get_pathing`: `sh = out.pathing.shCoeffs` (orden 1 → 4 coeficientes ACN: W, Y, Z, X en SN3D); `direction = normalize(Vector3(sh[3], sh[1], -sh[2]))` (**B10**: si el test «a la vista» da espejo, permutar/cambiar signos y anotar); `eq = Vector3(eqCoeffs[0..2])`; `valid = |W| > 1e-4`.
  Scheduler: las fuentes con `enable_direct_simulation` piden también caminos cuando `has_probes()`. Manager `_apply_voices` (antes de `apply_spatial`): si `pathing_enabled and ch.sim_source >= 0 and not instance.room_path_active`: `var p = OpenDouSimulator.get_pathing(ch.sim_source)`; si `p.valid`: `instance.target_apparent_position = active_listener_position + p.direction * instance.emitter_position.distance_to(active_listener_position)`; `cutoff = minf(cutoff, lerpf(1500.0, 20000.0, clampf(p.eq.z, 0.0, 1.0)))` (banda alta → corte). `update_parameters` ya suaviza `current_apparent_position` hacia `target_apparent_position` y solo lo pisa cuando `not room_path_active` → hay que **no** reasignar `target_apparent_position = emitter_position` cuando el pathing la fijó este cuadro: añadir `instance.pathing_active: bool` que `update_parameters` respeta igual que `room_path_active`.
- [ ] **Step 4: Compilar, correr** → verde; anotar ángulos y niveles medidos.
- [ ] **Step 5: Commit** — `git commit -m "Fase 14: caminos de Steam Audio como origen aparente y filtro de la voz; el grafo autorado manda"`

---

### Task 3: Ocluidores dinámicos

**Files:** `native/src/acoustic_scene.{h,cpp}`, `nodes/opendou_acoustic_geometry_bake.gd`; test `tests/test_dynamic_occluder.gd`.

**Interfaces:**
- Produces: `OpenDouAcousticScene.add_instanced(vertices, triangles, material_indices, materials, transform: Transform3D) -> int`, `update_instanced_transform(id: int, transform: Transform3D)`, `remove_instanced(id)`, `commit()`, `instanced_updates() -> int` (contador); bake: `dynamic_group` (`&"AcousticObstacleDynamic"`), `dynamic_position_threshold_m` (0.02), `dynamic_angle_threshold_deg` (1.0), `dynamic_update_count: int`, `_physics_process` que sigue las mallas.

- [ ] **Step 1: Test en rojo** — hoja de puerta (`MeshInstance3D` BoxMesh 1×2.2×0.05 en un `Node3D` pivote) en el grupo dinámico entre la fuente (0,1,−4) y el oyente (0,1,0), bake con `feed_steam_audio`; simulador con una fuente; `run_direct` y `get_direct` a 0° (cerrada, la hoja tapa): `occlusion < 0.3`; pivote girado 45° → `await physics_frame` ×3 → entre 0.3 y 0.8; 90° → > 0.8; 60 cuadros quieta → `bake.dynamic_update_count` no cambia.
- [ ] **Step 2: Correr y ver el fallo.**
- [ ] **Step 3: Implementar.** Nativo: cada `add_instanced` crea una `IPLScene` hija con su `IPLStaticMesh` (mismo código que `build`, factorizado en `make_static_mesh(scene, ...)`), `iplInstancedMeshCreate(scene_, {subScene, transform = to_ipl(transform)}, &im)`, `iplInstancedMeshAdd(im, scene_)`, `iplSceneCommit(scene_)`; `update_instanced_transform` → `iplInstancedMeshUpdateTransform` y marca `dirty_`; `commit()` → `iplSceneCommit` si `dirty_` (una vez por cuadro, llamado por el bake). `to_ipl(Transform3D)`: matriz 4×4 fila-mayor `{basis columnas, origen}` (comprobar la convención de `IPLMatrix4x4.elements[fila][col]`). Bake: recoge el grupo dinámico aparte en `bake_geometry`, crea sus instancias (`_dynamic: Array[Dictionary]{id, node, xform}`), y en `_physics_process` compara `node.global_transform` con el guardado (posición > umbral o ángulo > umbral) → `update_instanced_transform` + `dynamic_update_count += 1`; al final `commit()` si hubo cambios. En `clear_baked_data` quita las instancias.
- [ ] **Step 4: Compilar, correr** → verde; anotar la oclusión medida a 0/45/90°.
- [ ] **Step 5: Commit** — `git commit -m "Fase 14: ocluidores dinamicos: mallas del grupo AcousticObstacleDynamic como IPLInstancedMesh seguidas con umbral"`

---

### Task 4: El depurador dibuja los caminos

**Files:** `native/src/simulator.{h,cpp}` (`get_path_segments() -> PackedVector3Array`, `get_path_segments_occluded() -> PackedByteArray`), `nodes/opendou_acoustic_debugger_3d.gd` (`show_paths`, `path_segment_count() -> int`); test: ampliar `tests/test_acoustic_debugger.gd`.

- [ ] **Step 1: Test** — tras el escenario de la Task 2 con caminos válidos, un `OpenDouAcousticDebugger3D` con `show_paths = true` y `enabled = true`: `path_segment_count() >= 1` tras un cuadro; sin extensión, 0 y sin errores.
- [ ] **Step 2: Implementar.** El callback acumula `(from, to, occluded)` en un búfer de escritura bajo mutex durante `RunPathing`; al terminar la corrida se intercambia con el de lectura. GDScript: el depurador pide los dos arreglos en `_process` y dibuja con un `ImmediateMesh` (`PRIMITIVE_LINES`, verde/rojo).
- [ ] **Step 3: Correr, commit** — `git commit -m "Fase 14: el depurador dibuja los segmentos de camino reales de Steam Audio"`

---

### Task 5: Retirada de `EdgeDiffractionEngine` y `RoomCouplingEngine`

**Files:** borrar `runtime/spatial/edge_diffraction_engine.gd` y `room_coupling_engine.gd` (y sus `.uid`), `runtime/spatial/spatial_acoustics_manager.gd` (quitar precargas y `diffraction_engine`/`coupling_engine`), `tests/test_spatial_acoustics_phase2.gd` (quitar las aserciones que los instancien; conservar el resto), `docs/funcionalidades.md` (§2.3: retirados, con el porqué).

- [ ] **Step 1:** `grep -rn "diffraction_engine\|coupling_engine\|EdgeDiffraction\|RoomCoupling" addons tests scenes docs` y listar usos.
- [ ] **Step 2:** Borrar y ajustar; `./run_tests.sh` verde (la regeneración de la caché de clases quita los `class_name` borrados).
- [ ] **Step 3: Commit** — `git commit -m "Fase 14: retirados EdgeDiffractionEngine y RoomCouplingEngine (inertes; la propagacion por sondas los sustituye)"`

---

### Task 6: Documentos y cierre

- [ ] `funcionalidades.md` (§2.2 bake con sondas y dinámicos, depurador con caminos; §3.2 propagación; §3.5 recortado a CI y plataformas), `AGENTS.md` (observación 53: el grafo autorado manda sobre las sondas; trampas: convención SH, `commit` y hilo, `.probes` binario), `current.md` (siguiente: Fase 15 si se retoma), spec §11, `docs/roadmap` marcar fases hechas.
- [ ] `./run_tests.sh` verde; banco a 200 voces sin regresión; commit `"Fase 14: documentos al dia; observacion 53"`.

---

## Autorevisión

- **Cobertura:** §3 → T1; §4 → T2; §5 → T3; §6 → T4; §7 → T5; §8–§9 repartidos; §10 riesgos en T1 (tiempo del bake), T2 (convención SH), T2 (hilo compartido).
- **Nombres:** `generate_probes/bake_paths/save_probes/load_probes/clear_probes/probe_count/has_probes` (T1, T2); `set_source_pathing/get_pathing/pathing_generation` (T2); `pathing_active` en la instancia (T2); `add_instanced/update_instanced_transform/remove_instanced/commit/instanced_updates` (T3); `get_path_segments/get_path_segments_occluded`, `show_paths`, `path_segment_count` (T4).
- **Sin marcadores de posición:** las comprobaciones «nombre exacto en phonon.h» y «convención de `IPLMatrix4x4`» son verificaciones contra el SDK, no huecos.
