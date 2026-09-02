# Fase 12 — Materiales y efecto directo: plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Materiales acústicos por banda, la geometría del bake convertida en escena de Steam Audio, y el efecto directo (oclusión volumétrica, transmisión, aire, directividad) en la cadena del stream nativo, bajo presupuesto del LOD.

**Architecture:** Un recurso `AcousticMaterial` con los siete números de `IPLMaterial`; dos clases estáticas nativas nuevas (`OpenDouAcousticScene`, `OpenDouSimulator`); el stream nativo gana un `IPLDirectEffect` alimentado por el canal con una llamada por voz y cuadro; el `OcclusionScheduler` reparte fuentes del simulador según el LOD y conserva el rayo de Godot para el resto y para el backend `godot`.

**Tech Stack:** Godot 4.7.2 (GDScript), GDExtension C++17 (`native/`), Steam Audio 4.8.1 binario, CMake, suite headless `./run_tests.sh`.

**Spec:** `docs/superpowers/specs/2026-09-02-fase12-efecto-directo-design.md` · **Observaciones a resolver antes:** `docs/tasks/observaciones-fases-12-14.md` (A1–A3, A13, B1–B4, B13).

## Global Constraints

- Rama `main`, un commit por tarea, mensajes en español sin acentos en la primera línea; comentarios de código en español sin acentos.
- `./run_tests.sh` verde antes de cada commit; fugas ≤ `tests/leak_budget.txt` (540; hoy 527). Vigilante 180 s.
- Tests nativos: se **omiten con aviso** si `OpenDouSpatialStream.is_native_available()` es falso (patrón de `tests/test_binaural.gd`).
- Diferencias de nivel en el bus de sonda (`TestBackendParity.BUS`); cámara para que suene un 3D; esperar por muestras; `set_event_manager()`.
- Compilar: `/Applications/CMake.app/Contents/bin/cmake --build native/build/ext --parallel`. Añadir cada `.cpp` nuevo a `native/CMakeLists.txt` (`add_library(opendou_native SHARED …)`).
- Ejes: Steam Audio es Y-arriba diestro en metros, como Godot; `IPLCoordinateSpace3{right = +X, up = +Y, ahead = −Z, origin}`.

---

## Estructura de archivos

| Archivo | Responsabilidad |
|---|---|
| `addons/opendou/resources/acoustic_material.gd` | recurso por banda, presets, `to_ipl()` |
| `addons/opendou/runtime/spatial/acoustic_material_registry.gd` | `get_acoustic_material`, `register_acoustic_material`, JSON |
| `native/src/acoustic_scene.{h,cpp}` | `IPLScene` + `IPLStaticMesh` desde el bake |
| `native/src/simulator.{h,cpp}` | `IPLSimulator` DIRECT, fuentes, `run_direct` |
| `native/src/spatial_stream.{h,cpp}` | `IPLDirectEffect`, `set_direct_params` |
| `addons/opendou/nodes/opendou_acoustic_geometry_bake.gd` | `feed_steam_audio`, `export_to_native()` |
| `addons/opendou/runtime/spatial/occlusion_scheduler.gd` | fuentes por LOD, `run_direct` |
| `addons/opendou/runtime/physical_voice_channel.gd`, `voice_pool_manager.gd`, `audio_event_manager.gd` | `sim_source`, empuje, liberación, sin doble directividad |
| `addons/opendou/runtime/spatial/acoustic_lod_controller.gd` | `enable_direct_simulation`, muestras por LOD |
| tests | `test_acoustic_material.gd`, `test_steam_scene.gd`, `test_direct_effect.gd`, `test_sim_budget.gd`; `tests/sim_budget.txt` |

---

### Task 1: `AcousticMaterial` y el registro por banda

**Files:**
- Create: `addons/opendou/resources/acoustic_material.gd`
- Modify: `addons/opendou/runtime/spatial/acoustic_material_registry.gd`
- Test: `tests/test_acoustic_material.gd` (síncrono; registrar en `run_suite` de `tests/test_all.gd` junto a los demás síncronos)

**Interfaces:**
- Produces: `AcousticMaterial` (exports del spec §3), `to_ipl() -> PackedFloat32Array` (7), `static from_preset(name: StringName) -> AcousticMaterial`, `static PRESETS: Dictionary`; `AcousticMaterialRegistry.get_acoustic_material(name) -> AcousticMaterial`, `register_acoustic_material(mat: AcousticMaterial)`, JSON con clave `bands`.

- [ ] **Step 1: Test en rojo**

```gdscript
class_name TestAcousticMaterial
extends RefCounted

## Fase 12: materiales por banda (absorcion, dispersion, transmision) y su registro.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const MaterialClass = preload("res://addons/opendou/resources/acoustic_material.gd")
const RegistryClass = preload("res://addons/opendou/runtime/spatial/acoustic_material_registry.gd")

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("acoustic_material")
	for name in [&"Concrete", &"Stone", &"Metal", &"Glass", &"Wood", &"Foliage", &"Water", &"Asphalt"]:
		var m = MaterialClass.from_preset(name)
		a.ok(m != null, "preset %s existe" % name)
		var v: PackedFloat32Array = m.to_ipl()
		a.eq(v.size(), 7, "%s: siete numeros" % name)
		for x in v:
			a.ok(x >= 0.0 and x <= 1.0, "%s: valores en [0,1]" % name)
	var glass = MaterialClass.from_preset(&"Glass")
	var concrete = MaterialClass.from_preset(&"Concrete")
	a.gt(glass.transmission_high, concrete.transmission_high, "el cristal transmite mas agudos que el hormigon")
	a.gt(MaterialClass.from_preset(&"Foliage").absorption_high, 0.5, "el follaje absorbe los agudos")
	var reg = RegistryClass.new()
	var custom = MaterialClass.new()
	custom.material_name = &"Velvet"
	custom.absorption_low = 0.2; custom.absorption_mid = 0.5; custom.absorption_high = 0.7
	custom.scattering = 0.3
	custom.transmission_low = 0.1; custom.transmission_mid = 0.05; custom.transmission_high = 0.01
	reg.register_acoustic_material(custom)
	var path := "user://opendou_materials_test.json"
	reg.save_to_json(path)
	var reg2 = RegistryClass.new()
	reg2.load_from_json(path)
	var back = reg2.get_acoustic_material(&"Velvet")
	a.ok(back != null, "el material personalizado se recarga")
	if back != null:
		a.approx(back.absorption_mid, 0.5, "con sus bandas", 0.0001)
		a.approx(back.transmission_high, 0.01, "y su transmision", 0.0001)
	a.eq(String(reg2.get_acoustic_material(&"Metal").material_name), "Metal", "los presets siguen ahi")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return a
```
Comprobar si el registro ya tiene `save_to_json`; si no, añadirlo simétrico a `load_from_json`.

- [ ] **Step 2: Correr y ver el fallo.**
- [ ] **Step 3: Implementar**

```gdscript
@tool
class_name AcousticMaterial
extends Resource

## Material acustico por banda (Fase 12): los siete numeros de IPLMaterial de Steam Audio mas
## la densidad y el corte que usa el fallback GDScript. Bandas: baja, media, alta.

@export var material_name: StringName = &"Concrete"
@export_group("Absorcion")
@export_range(0.0, 1.0, 0.001) var absorption_low: float = 0.05
@export_range(0.0, 1.0, 0.001) var absorption_mid: float = 0.07
@export_range(0.0, 1.0, 0.001) var absorption_high: float = 0.08
@export_group("Dispersion")
@export_range(0.0, 1.0, 0.001) var scattering: float = 0.05
@export_group("Transmision")
@export_range(0.0, 1.0, 0.001) var transmission_low: float = 0.015
@export_range(0.0, 1.0, 0.001) var transmission_mid: float = 0.002
@export_range(0.0, 1.0, 0.001) var transmission_high: float = 0.001
@export_group("Fallback GDScript")
@export var density_kg_m3: float = 2400.0
@export var resonance_lpf_hz: float = 350.0

## nombre -> [abs_l, abs_m, abs_h, scat, tr_l, tr_m, tr_h, densidad, corte]
const PRESETS: Dictionary = {
	&"Concrete": [0.05, 0.07, 0.08, 0.05, 0.015, 0.002, 0.001, 2400.0, 350.0],
	&"Stone":    [0.13, 0.20, 0.24, 0.05, 0.015, 0.002, 0.001, 2400.0, 350.0],
	&"Metal":    [0.20, 0.07, 0.06, 0.05, 0.200, 0.025, 0.010, 7800.0, 1200.0],
	&"Glass":    [0.06, 0.03, 0.02, 0.05, 0.060, 0.044, 0.011, 2500.0, 800.0],
	&"Wood":     [0.11, 0.07, 0.06, 0.05, 0.070, 0.014, 0.005, 700.0, 2000.0],
	&"Foliage":  [0.30, 0.60, 0.80, 0.60, 0.500, 0.300, 0.150, 150.0, 4500.0],
	&"Water":    [0.01, 0.01, 0.02, 0.05, 0.010, 0.002, 0.001, 1000.0, 600.0],
	&"Asphalt":  [0.10, 0.15, 0.20, 0.10, 0.010, 0.002, 0.001, 2100.0, 400.0],
}

static func from_preset(name: StringName) -> AcousticMaterial:
	if not PRESETS.has(name):
		return null
	var p: Array = PRESETS[name]
	var m := AcousticMaterial.new()
	m.material_name = name
	m.absorption_low = p[0]; m.absorption_mid = p[1]; m.absorption_high = p[2]
	m.scattering = p[3]
	m.transmission_low = p[4]; m.transmission_mid = p[5]; m.transmission_high = p[6]
	m.density_kg_m3 = p[7]; m.resonance_lpf_hz = p[8]
	return m

## Orden de IPLMaterial: absorption[3], scattering, transmission[3].
func to_ipl() -> PackedFloat32Array:
	return PackedFloat32Array([absorption_low, absorption_mid, absorption_high, scattering, transmission_low, transmission_mid, transmission_high])

func to_dict() -> Dictionary:
	return {"bands": Array(to_ipl()), "density": density_kg_m3, "resonance_lpf": resonance_lpf_hz}

static func from_dict(name: StringName, d: Dictionary) -> AcousticMaterial:
	var m := AcousticMaterial.new()
	m.material_name = name
	var b: Array = d.get("bands", [])
	if b.size() == 7:
		m.absorption_low = b[0]; m.absorption_mid = b[1]; m.absorption_high = b[2]
		m.scattering = b[3]
		m.transmission_low = b[4]; m.transmission_mid = b[5]; m.transmission_high = b[6]
	m.density_kg_m3 = float(d.get("density", 2400.0))
	m.resonance_lpf_hz = float(d.get("resonance_lpf", 350.0))
	return m
```
Registro: `var _acoustic: Dictionary = {}` (nombre → `AcousticMaterial`); en `_init`/`_reset_to_defaults` cargar los ocho presets; `get_acoustic_material(name)` devuelve el registrado o `AcousticMaterial.from_preset(name)` o `null`; `register_acoustic_material(mat)` guarda y actualiza también `_materials[name]` (densidad, corte, absorción media) para el fallback; `load_from_json` lee la clave `bands` si está; `save_to_json(path)` escribe `to_dict()` por material.

- [ ] **Step 4: Correr** → verde.
- [ ] **Step 5: Commit** — `git commit -m "Fase 12: AcousticMaterial por banda y registro con los ocho presets"`

---

### Task 2: `OpenDouAcousticScene` (nativo) y `export_to_native()` del bake

**Files:**
- Create: `native/src/acoustic_scene.h`, `native/src/acoustic_scene.cpp`
- Modify: `native/CMakeLists.txt`, `native/src/register_types.cpp`, `addons/opendou/nodes/opendou_acoustic_geometry_bake.gd`
- Test: `tests/test_steam_scene.gd`

**Interfaces:**
- Produces (estáticos, clase `OpenDouAcousticScene`): `build(vertices: PackedVector3Array, triangles: PackedInt32Array, material_indices: PackedInt32Array, materials: Array) -> bool`, `clear()`, `is_ready() -> bool`, `triangle_count() -> int`, `material_count() -> int`; C++: `static IPLScene scene()` para el simulador. Bake: `@export var feed_steam_audio: bool = true`, `export_to_native() -> bool`, `get_flat_geometry() -> Dictionary {vertices, triangles, material_indices, material_names}`.

- [ ] **Step 1: Test en rojo**

```gdscript
class_name TestSteamScene
extends RefCounted

## Fase 12: la geometria del bake se convierte en la escena de Steam Audio.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const BakeScript = preload("res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd")

static func _native() -> bool:
	return ClassDB.class_exists("OpenDouAcousticScene") and ClassDB.class_exists("OpenDouSpatialStream") and bool(ClassDB.class_call_static("OpenDouSpatialStream", "is_native_available"))

## Un muro de `material` de 4 x 3 x thickness en `pos`, en el grupo del bake.
static func make_wall(tree: SceneTree, pos: Vector3, material: StringName, thickness: float = 0.3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.set_meta("surface_type", material)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4, 3, thickness)
	mi.mesh = box
	mi.add_to_group("AcousticObstacle")
	mi.set_meta("acoustic_material", material)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	cs.shape = shape
	body.add_child(cs)
	tree.root.add_child(body)
	body.global_position = pos
	return body

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("steam_scene")
	if not _native():
		print("[OpenDou] extension nativa AUSENTE: escena de Steam Audio omitida")
		return a
	var wall := make_wall(tree, Vector3(0, 1.5, -3), &"Glass")
	var bake = BakeScript.new()
	bake.auto_bake_on_ready = false
	tree.root.add_child(bake)
	var result: Dictionary = bake.bake_geometry(tree.root)
	a.eq(bake.get_baked_triangle_count(), 12, "una caja son 12 triangulos")
	a.ok(bake.export_to_native(), "la escena nativa se construye")
	a.ok(bool(ClassDB.class_call_static("OpenDouAcousticScene", "is_ready")), "y esta lista")
	a.eq(int(ClassDB.class_call_static("OpenDouAcousticScene", "triangle_count")), bake.get_baked_triangle_count(), "con el mismo numero de triangulos que el bake")
	a.eq(int(ClassDB.class_call_static("OpenDouAcousticScene", "material_count")), 1, "y un material")
	for i in range(100):
		bake.export_to_native()
	a.eq(int(ClassDB.class_call_static("OpenDouAcousticScene", "triangle_count")), 12, "reconstruir cien veces no acumula mallas")
	ClassDB.class_call_static("OpenDouAcousticScene", "clear")
	a.ok(not bool(ClassDB.class_call_static("OpenDouAcousticScene", "is_ready")), "clear la deja vacia")
	tree.root.remove_child(bake); bake.free()
	tree.root.remove_child(wall); wall.free()
	return a
```
Comprobar en `bake_geometry` cómo lee el material de una malla (`acoustic_material` en metadatos de la malla o del cuerpo, o `default_acoustic_material`); el test pone ambos.

- [ ] **Step 2: Correr y ver el fallo.**
- [ ] **Step 3: Implementar**

`native/src/acoustic_scene.h`:
```cpp
#pragma once
#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/array.hpp>
#include <phonon.h>
#include <vector>

namespace opendou {

// Escena de Steam Audio construida desde el bake (Fase 12). Estatica: hay una escena por
// proceso, igual que un contexto. La malla estatica se sustituye entera en cada build().
class OpenDouAcousticScene : public godot::Object {
	GDCLASS(OpenDouAcousticScene, godot::Object)
public:
	static bool build(const godot::PackedVector3Array &vertices, const godot::PackedInt32Array &triangles, const godot::PackedInt32Array &material_indices, const godot::Array &materials);
	static void clear();
	static bool is_ready() { return scene_ != nullptr && mesh_ != nullptr; }
	static int triangle_count() { return triangle_count_; }
	static int material_count() { return material_count_; }
	static IPLScene scene() { return scene_; }
	static int generation() { return generation_; }
protected:
	static void _bind_methods();
private:
	static IPLScene scene_;
	static IPLStaticMesh mesh_;
	static int triangle_count_;
	static int material_count_;
	static int generation_;
};

} // namespace opendou
```
`acoustic_scene.cpp`:
```cpp
#include "acoustic_scene.h"
#include "steam_audio_context.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/audio_server.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

using namespace godot;
namespace opendou {

IPLScene OpenDouAcousticScene::scene_ = nullptr;
IPLStaticMesh OpenDouAcousticScene::mesh_ = nullptr;
int OpenDouAcousticScene::triangle_count_ = 0;
int OpenDouAcousticScene::material_count_ = 0;
int OpenDouAcousticScene::generation_ = 0;

void OpenDouAcousticScene::_bind_methods() {
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("build", "vertices", "triangles", "material_indices", "materials"), &OpenDouAcousticScene::build);
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("clear"), &OpenDouAcousticScene::clear);
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("is_ready"), &OpenDouAcousticScene::is_ready);
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("triangle_count"), &OpenDouAcousticScene::triangle_count);
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("material_count"), &OpenDouAcousticScene::material_count);
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("generation"), &OpenDouAcousticScene::generation);
}

bool OpenDouAcousticScene::build(const PackedVector3Array &vertices, const PackedInt32Array &triangles, const PackedInt32Array &material_indices, const Array &materials) {
	const int rate = static_cast<int>(AudioServer::get_singleton()->get_mix_rate());
	if (!SteamAudioContext::ensure(rate)) {
		return false;
	}
	if (triangles.size() % 3 != 0 || material_indices.size() != triangles.size() / 3 || materials.size() == 0) {
		return false;
	}
	if (scene_ == nullptr) {
		IPLSceneSettings settings = {};
		settings.type = IPL_SCENETYPE_DEFAULT;
		if (iplSceneCreate(SteamAudioContext::context(), &settings, &scene_) != IPL_STATUS_SUCCESS) {
			scene_ = nullptr;
			return false;
		}
	}
	if (mesh_ != nullptr) {
		iplStaticMeshRemove(mesh_, scene_);
		iplStaticMeshRelease(&mesh_);
		mesh_ = nullptr;
	}
	std::vector<IPLVector3> v(vertices.size());
	for (int i = 0; i < vertices.size(); i++) {
		const Vector3 p = vertices[i];
		v[i] = IPLVector3{ p.x, p.y, p.z };
	}
	std::vector<IPLTriangle> t(triangles.size() / 3);
	for (size_t i = 0; i < t.size(); i++) {
		t[i] = IPLTriangle{ { triangles[3 * i], triangles[3 * i + 1], triangles[3 * i + 2] } };
	}
	std::vector<IPLint32> mi(material_indices.size());
	for (int i = 0; i < material_indices.size(); i++) {
		mi[i] = material_indices[i];
	}
	std::vector<IPLMaterial> m(materials.size());
	for (int i = 0; i < materials.size(); i++) {
		PackedFloat32Array f = materials[i];
		if (f.size() != 7) {
			return false;
		}
		m[i] = IPLMaterial{ { f[0], f[1], f[2] }, f[3], { f[4], f[5], f[6] } };
	}
	IPLStaticMeshSettings s = {};
	s.numVertices = static_cast<IPLint32>(v.size());
	s.numTriangles = static_cast<IPLint32>(t.size());
	s.numMaterials = static_cast<IPLint32>(m.size());
	s.vertices = v.data();
	s.triangles = t.data();
	s.materialIndices = mi.data();
	s.materials = m.data();
	if (iplStaticMeshCreate(scene_, &s, &mesh_) != IPL_STATUS_SUCCESS) {
		mesh_ = nullptr;
		return false;
	}
	iplStaticMeshAdd(mesh_, scene_);
	iplSceneCommit(scene_);
	triangle_count_ = s.numTriangles;
	material_count_ = s.numMaterials;
	generation_++;
	return true;
}

void OpenDouAcousticScene::clear() {
	if (mesh_ != nullptr && scene_ != nullptr) {
		iplStaticMeshRemove(mesh_, scene_);
		iplSceneCommit(scene_);
	}
	if (mesh_ != nullptr) {
		iplStaticMeshRelease(&mesh_);
		mesh_ = nullptr;
	}
	if (scene_ != nullptr) {
		iplSceneRelease(&scene_);
		scene_ = nullptr;
	}
	triangle_count_ = 0;
	material_count_ = 0;
	generation_++;
}

} // namespace opendou
```
Registrar `GDREGISTER_CLASS(opendou::OpenDouAcousticScene)` y añadir `src/acoustic_scene.cpp` al CMake. `clear()` en `uninitialize` de la extensión.

Bake:
```gdscript
## Alimentar la escena de Steam Audio al terminar el bake (Fase 12). Sin extension no hace nada.
@export var feed_steam_audio: bool = true

## Vertices, triangulos e indices de material aplanados, listos para la escena nativa.
func get_flat_geometry() -> Dictionary:
	var vertices := PackedVector3Array()
	var triangles := PackedInt32Array()
	var indices := PackedInt32Array()
	var names: Array[StringName] = []
	var name_to_index: Dictionary = {}
	for tri in get_baked_triangles():
		var mat: StringName = StringName(str(tri.get("material", default_acoustic_material)))
		if not name_to_index.has(mat):
			name_to_index[mat] = names.size()
			names.append(mat)
		for k in ["v0", "v1", "v2"]:
			triangles.append(vertices.size())
			vertices.append(tri[k])
		indices.append(int(name_to_index[mat]))
	return {"vertices": vertices, "triangles": triangles, "material_indices": indices, "material_names": names}

## Construye la escena de Steam Audio con la geometria del bake. false sin extension o sin datos.
func export_to_native() -> bool:
	if not ClassDB.class_exists("OpenDouAcousticScene"):
		return false
	var g: Dictionary = get_flat_geometry()
	if (g.triangles as PackedInt32Array).is_empty():
		return false
	var registry = AcousticMaterialRegistryClass.get_singleton()
	var materials: Array = []
	for n in g.material_names:
		var m = registry.get_acoustic_material(n) if registry != null else null
		materials.append(m.to_ipl() if m != null else AcousticMaterialClass.from_preset(&"Concrete").to_ipl())
	return bool(ClassDB.class_call_static("OpenDouAcousticScene", "build", g.vertices, g.triangles, g.material_indices, materials))
```
Comprobar las claves reales de los triángulos del bake (`get_baked_triangles()`); al final de `bake_geometry`: `if feed_steam_audio: export_to_native()`.

- [ ] **Step 4: Compilar, correr** → verde. Registrar el test en la suite asíncrona.
- [ ] **Step 5: Commit** — `git commit -m "Fase 12: OpenDouAcousticScene: la geometria del bake se convierte en IPLScene con materiales por banda"`

---

### Task 3: `OpenDouSimulator` (DIRECT) y su test de oclusión por material

**Files:**
- Create: `native/src/simulator.h`, `native/src/simulator.cpp`
- Modify: `native/CMakeLists.txt`, `native/src/register_types.cpp`
- Test: `tests/test_direct_effect.gd` (parte A: simulador solo)

**Interfaces:**
- Produces (estáticos): `configure(max_sources: int, occlusion_samples: int, transmission_rays: int) -> bool`, `is_ready() -> bool`, `create_source() -> int`, `release_source(handle: int)`, `set_source_inputs(handle, position: Vector3, forward: Vector3, up: Vector3, dipole_weight: float, dipole_power: float, occlusion_radius: float)`, `set_listener(position, forward, up)`, `run_direct() -> int` (µs), `get_direct(handle) -> PackedFloat32Array(8)`, `source_count() -> int`.

- [ ] **Step 1: Test en rojo**

```gdscript
class_name TestDirectEffect
extends RefCounted

## Fase 12: el simulador de Steam Audio ve el bake (oclusion, transmision por material, aire).

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TestSteamSceneClass = preload("res://tests/test_steam_scene.gd")
const BakeScript = preload("res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd")

static func _sim(method: String, args: Array = []) -> Variant:
	return ClassDB.class_call_static("OpenDouSimulator", method) if args.is_empty() else ClassDB.class_call_staticv("OpenDouSimulator", method, args)

static func _direct_behind(tree: SceneTree, material: StringName) -> PackedFloat32Array:
	var wall := TestSteamSceneClass.make_wall(tree, Vector3(0, 1.5, -3), material)
	var bake = BakeScript.new()
	bake.auto_bake_on_ready = false
	tree.root.add_child(bake)
	bake.bake_geometry(tree.root)
	bake.export_to_native()
	_sim("configure", [8, 16, 2])
	var h: int = int(_sim("create_source"))
	_sim("set_listener", [Vector3(0, 1.5, 0), Vector3(0, 0, -1), Vector3.UP])
	_sim("set_source_inputs", [h, Vector3(0, 1.5, -6), Vector3(0, 0, 1), Vector3.UP, 0.0, 1.0, 0.5])
	_sim("run_direct")
	var out: PackedFloat32Array = _sim("get_direct", [h])
	_sim("release_source", [h])
	tree.root.remove_child(bake); bake.free()
	tree.root.remove_child(wall); wall.free()
	ClassDB.class_call_static("OpenDouAcousticScene", "clear")
	return out

static func run_simulator_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("direct_simulator")
	if not TestSteamSceneClass._native() or not ClassDB.class_exists("OpenDouSimulator"):
		print("[OpenDou] extension nativa AUSENTE: simulador omitido")
		return a
	var glass: PackedFloat32Array = _direct_behind(tree, &"Glass")
	var concrete: PackedFloat32Array = _direct_behind(tree, &"Concrete")
	print("[OpenDou] efecto directo: tras Glass occl=%.2f tr=(%.3f %.3f %.3f) | tras Concrete occl=%.2f tr=(%.3f %.3f %.3f)" % [glass[0], glass[1], glass[2], glass[3], concrete[0], concrete[1], concrete[2], concrete[3]])
	a.lt(glass[0], 0.3, "el muro de cristal ocluye (occlusion < 0.3)")
	a.lt(concrete[0], 0.3, "y el de hormigon tambien")
	a.gt(glass[1], concrete[1] + 0.02, "el cristal transmite mas graves que el hormigon")
	a.gt(glass[3], concrete[3], "y mas agudos")
	# Sin muro: nada ocluye y todo se transmite; a 200 m el aire come la banda alta.
	_sim("configure", [8, 16, 2])
	var h: int = int(_sim("create_source"))
	_sim("set_listener", [Vector3.ZERO, Vector3(0, 0, -1), Vector3.UP])
	_sim("set_source_inputs", [h, Vector3(0, 0, -10), Vector3(0, 0, 1), Vector3.UP, 0.0, 1.0, 0.5])
	_sim("run_direct")
	var near: PackedFloat32Array = _sim("get_direct", [h])
	_sim("set_source_inputs", [h, Vector3(0, 0, -200), Vector3(0, 0, 1), Vector3.UP, 0.0, 1.0, 0.5])
	_sim("run_direct")
	var far: PackedFloat32Array = _sim("get_direct", [h])
	print("[OpenDou] aire: 10 m (%.3f %.3f %.3f), 200 m (%.3f %.3f %.3f); occl sin muro %.2f" % [near[4], near[5], near[6], far[4], far[5], far[6], near[0]])
	a.gt(near[0], 0.95, "sin muro no hay oclusion")
	a.lt(far[6], far[4], "a 200 m el aire absorbe mas la banda alta que la baja")
	a.lt(far[6], near[6], "y mas que a 10 m")
	_sim("release_source", [h])
	return a
```
Si `class_call_staticv` no existe en 4.7, usar `Callable(ClassDB, "class_call_static").bindv(...)` o llamadas directas `OpenDouSimulator.configure(...)` (la clase existe en tiempo de ejecución; el parser acepta el nombre si la extensión está registrada; envolver en `if ClassDB.class_exists`).

- [ ] **Step 2: Correr y ver el fallo.**
- [ ] **Step 3: Implementar** (`simulator.h/.cpp`): estáticos `IPLSimulator sim_`, `std::vector<IPLSource> sources_` (huecos = nullptr), `std::vector<IPLSimulationOutputs> outputs_`, `bool dirty_commit_`.

```cpp
bool OpenDouSimulator::configure(int max_sources, int occlusion_samples, int transmission_rays) {
	const int rate = static_cast<int>(AudioServer::get_singleton()->get_mix_rate());
	if (!SteamAudioContext::ensure(rate) || !OpenDouAcousticScene::is_ready()) return false;
	if (sim_ != nullptr) { release_all_sources(); iplSimulatorRelease(&sim_); sim_ = nullptr; }
	IPLSimulationSettings s = {};
	s.flags = IPL_SIMULATIONFLAGS_DIRECT;
	s.sceneType = IPL_SCENETYPE_DEFAULT;
	s.maxNumOcclusionSamples = occlusion_samples;
	s.maxNumSources = max_sources;
	s.samplingRate = rate;
	s.frameSize = SteamAudioContext::audio_settings().frameSize;
	if (iplSimulatorCreate(SteamAudioContext::context(), &s, &sim_) != IPL_STATUS_SUCCESS) { sim_ = nullptr; return false; }
	iplSimulatorSetScene(sim_, OpenDouAcousticScene::scene());
	iplSimulatorCommit(sim_);
	occlusion_samples_ = occlusion_samples; transmission_rays_ = transmission_rays;
	sources_.assign(max_sources, nullptr); outputs_.assign(max_sources, IPLSimulationOutputs{});
	return true;
}
int OpenDouSimulator::create_source() {
	if (sim_ == nullptr) return -1;
	for (size_t i = 0; i < sources_.size(); i++) if (sources_[i] == nullptr) {
		IPLSourceSettings ss = {}; ss.flags = IPL_SIMULATIONFLAGS_DIRECT;
		if (iplSourceCreate(sim_, &ss, &sources_[i]) != IPL_STATUS_SUCCESS) { sources_[i] = nullptr; return -1; }
		iplSourceAdd(sources_[i], sim_); dirty_commit_ = true; return static_cast<int>(i);
	}
	return -1;
}
void OpenDouSimulator::release_source(int h) { if (valid(h)) { iplSourceRemove(sources_[h], sim_); iplSourceRelease(&sources_[h]); sources_[h] = nullptr; dirty_commit_ = true; } }
void OpenDouSimulator::set_source_inputs(int h, const Vector3 &pos, const Vector3 &fwd, const Vector3 &up, float dipole_weight, float dipole_power, float occlusion_radius) {
	if (!valid(h)) return;
	IPLSimulationInputs in = {};
	in.flags = IPL_SIMULATIONFLAGS_DIRECT;
	in.directFlags = (IPLDirectSimulationFlags)(IPL_DIRECTSIMULATIONFLAGS_OCCLUSION | IPL_DIRECTSIMULATIONFLAGS_TRANSMISSION | IPL_DIRECTSIMULATIONFLAGS_AIRABSORPTION | IPL_DIRECTSIMULATIONFLAGS_DIRECTIVITY);
	in.source = space(pos, fwd, up);
	in.airAbsorptionModel.type = IPL_AIRABSORPTIONMODELTYPE_DEFAULT;
	in.directivity.dipoleWeight = dipole_weight; in.directivity.dipolePower = dipole_power;
	in.occlusionType = IPL_OCCLUSIONTYPE_VOLUMETRIC; in.occlusionRadius = occlusion_radius;
	in.numOcclusionSamples = occlusion_samples_; in.numTransmissionRays = transmission_rays_;
	iplSourceSetInputs(sources_[h], IPL_SIMULATIONFLAGS_DIRECT, &in);
}
void OpenDouSimulator::set_listener(const Vector3 &pos, const Vector3 &fwd, const Vector3 &up) {
	if (sim_ == nullptr) return;
	IPLSimulationSharedInputs sh = {}; sh.listener = space(pos, fwd, up);
	iplSimulatorSetSharedInputs(sim_, IPL_SIMULATIONFLAGS_DIRECT, &sh);
}
int OpenDouSimulator::run_direct() {
	if (sim_ == nullptr) return 0;
	if (dirty_commit_) { iplSimulatorCommit(sim_); dirty_commit_ = false; }
	const uint64_t t0 = Time::get_singleton()->get_ticks_usec();
	iplSimulatorRunDirect(sim_);
	for (size_t i = 0; i < sources_.size(); i++) if (sources_[i] != nullptr) iplSourceGetOutputs(sources_[i], IPL_SIMULATIONFLAGS_DIRECT, &outputs_[i]);
	last_run_usec_ = static_cast<int>(Time::get_singleton()->get_ticks_usec() - t0);
	return last_run_usec_;
}
PackedFloat32Array OpenDouSimulator::get_direct(int h) {
	PackedFloat32Array out; out.resize(8);
	if (!valid(h)) { out.fill(1.0f); return out; }
	const IPLDirectEffectParams &d = outputs_[h].direct;
	out[0] = d.occlusion; out[1] = d.transmission[0]; out[2] = d.transmission[1]; out[3] = d.transmission[2];
	out[4] = d.airAbsorption[0]; out[5] = d.airAbsorption[1]; out[6] = d.airAbsorption[2]; out[7] = d.directivity;
	return out;
}
```
`space(pos, fwd, up)`: `IPLCoordinateSpace3{right = fwd.cross(up), up, ahead = fwd, origin = pos}` (Steam Audio: `ahead` es la dirección hacia delante; Godot mira a −Z, así que quien llama pasa `forward = -basis.z`). Comprobar en `phonon.h` los nombres exactos de `IPLDirectSimulationFlags` y `IPL_AIRABSORPTIONMODELTYPE_DEFAULT`.

- [ ] **Step 4: Compilar, correr** → verde; anotar los valores medidos en el spec §11. Si «sin muro» da oclusión con muro, invertir el winding en `get_flat_geometry` (B2).
- [ ] **Step 5: Commit** — `git commit -m "Fase 12: OpenDouSimulator DIRECT: fuentes, oclusion volumetrica, transmision por material y aire"`

---

### Task 4: `IPLDirectEffect` en el stream y `set_direct_params`

**Files:**
- Modify: `native/src/spatial_stream.h`, `native/src/spatial_stream.cpp`
- Test: `tests/test_direct_effect.gd` (parte B: audio)

**Interfaces:**
- Produces: `OpenDouSpatialStream.set_direct_params(enabled: bool, occlusion: float, transmission: Vector3, air: Vector3, directivity: float)`; atómicos `direct_enabled_`, `direct_occlusion_`, `direct_tr_[3]`, `direct_air_[3]`, `direct_dir_`.

- [ ] **Step 1: Test en rojo** (stream directo, sin manager, como `test_binaural`):

```gdscript
static func run_stream_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("direct_stream")
	if not TestSteamSceneClass._native():
		return a
	var TB = load("res://tests/test_binaural.gd")
	var probe = load("res://tests/support/audio_probe.gd").new()
	var bus := &"DirectProbe"
	if AudioServer.get_bus_index(String(bus)) < 0:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx); AudioServer.set_bus_name(idx, String(bus)); AudioServer.set_bus_send(idx, "Master")
	probe.attach_to_existing_bus(bus, 2.0)
	var stream = ClassDB.instantiate("OpenDouSpatialStream")
	stream.source = TB._periodic_noise(int(AudioServer.get_mix_rate()))
	stream.spatialize = false
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = String(bus)
	player.volume_db = -6.0
	tree.root.add_child(player)
	player.play()
	var rate: float = AudioServer.get_mix_rate()
	var base := await TB._capture(tree, probe)
	var base_hi: float = linear_to_db(TB._band_energy_stereo(base, rate, 4000.0, 8000.0))
	var base_lo: float = linear_to_db(TB._band_energy_stereo(base, rate, 200.0, 800.0))
	# Transmision tipo cristal: pasa mas la banda alta que la baja... y oclusion parcial.
	stream.set_direct_params(true, 0.2, Vector3(0.06, 0.044, 0.5), Vector3(1, 1, 1), 1.0)
	var glass := await TB._capture(tree, probe)
	var glass_hi: float = linear_to_db(TB._band_energy_stereo(glass, rate, 4000.0, 8000.0))
	var glass_lo: float = linear_to_db(TB._band_energy_stereo(glass, rate, 200.0, 800.0))
	stream.set_direct_params(true, 0.2, Vector3(0.015, 0.002, 0.001), Vector3(1, 1, 1), 1.0)
	var concrete := await TB._capture(tree, probe)
	var concrete_hi: float = linear_to_db(TB._band_energy_stereo(concrete, rate, 4000.0, 8000.0))
	stream.set_direct_params(false, 1.0, Vector3(1, 1, 1), Vector3(1, 1, 1), 1.0)
	var off := await TB._capture(tree, probe)
	var off_hi: float = linear_to_db(TB._band_energy_stereo(off, rate, 4000.0, 8000.0))
	print("[OpenDou] efecto directo en el stream: base %.1f/%.1f, cristal %.1f/%.1f, hormigon agudos %.1f, apagado %.1f" % [base_lo, base_hi, glass_lo, glass_hi, concrete_hi, off_hi])
	a.lt(glass_hi, base_hi - 3.0, "tras el cristal (occl 0.2) cae la banda alta")
	a.gt(glass_hi, concrete_hi + 6.0, "el cristal deja pasar al menos 6 dB mas de agudos que el hormigon")
	a.approx(off_hi, base_hi, "apagado, igual que sin efecto", 1.0)
	player.stop(); tree.root.remove_child(player); player.free(); probe.teardown()
	return a
```

- [ ] **Step 2: Correr y ver el fallo.**
- [ ] **Step 3: Implementar.** En el playback: `IPLDirectEffect direct_ = nullptr` creado en `create_effect()` con `IPLDirectEffectSettings{numChannels = 1}`; liberado en `release_effect()`. En el bloque, tras llenar `mono` (paso 2) y antes del retardo por distancia:
```cpp
	if (stream_->direct_enabled_.load() && direct_ != nullptr) {
		IPLDirectEffectParams p = {};
		p.flags = (IPLDirectEffectFlags)(IPL_DIRECTEFFECTFLAGS_APPLYOCCLUSION | IPL_DIRECTEFFECTFLAGS_APPLYTRANSMISSION | IPL_DIRECTEFFECTFLAGS_APPLYAIRABSORPTION | IPL_DIRECTEFFECTFLAGS_APPLYDIRECTIVITY);
		p.transmissionType = IPL_TRANSMISSIONTYPE_FREQDEPENDENT;
		p.distanceAttenuation = 1.0f;
		p.occlusion = stream_->direct_occlusion_.load();
		for (int b = 0; b < 3; b++) { p.transmission[b] = stream_->direct_tr_[b].load(); p.airAbsorption[b] = stream_->direct_air_[b].load(); }
		p.directivity = stream_->direct_dir_.load();
		iplDirectEffectApply(direct_, &p, &in_buffer_, &in_buffer_);  // in-place (B3); si falla, bufer auxiliar
	}
```
`set_direct_params` escribe los atómicos; bind en `_bind_methods`.

- [ ] **Step 4: Compilar, correr** → verde.
- [ ] **Step 5: Commit** — `git commit -m "Fase 12: IPLDirectEffect en el stream nativo, en mono antes del HRTF"`

---

### Task 5: El planificador reparte fuentes por LOD y el canal empuja el efecto

**Files:**
- Modify: `addons/opendou/runtime/spatial/acoustic_lod_controller.gd`, `addons/opendou/runtime/spatial/occlusion_scheduler.gd`, `addons/opendou/runtime/physical_voice_channel.gd`, `addons/opendou/runtime/voice_pool_manager.gd`, `addons/opendou/runtime/audio_event_manager.gd`
- Test: `tests/test_direct_effect.gd` (parte C: voz completa) y `tests/test_backend_parity.gd` sigue verde

**Interfaces:**
- Produces: `AcousticLODController.direct_simulation_max_distance() -> float` (LOD 0 y 1), `occlusion_samples_for(distance) -> int` (16 / 8); `PhysicalVoiceChannel.sim_source: int = -1`, `uses_direct_effect() -> bool`; `OcclusionScheduler.simulated_this_frame: int`; manager no suma directividad GDScript a canales con fuente.

- [ ] **Step 1: Test en rojo** — una voz posteada a 6 m tras un muro de `Glass` (bake) frente a la misma tras `Concrete`, medida en el bus de sonda en steam_audio: banda 4–8 kHz al menos 6 dB mayor tras el cristal; sin muro, igual que sin bake (±1 dB); `manager.occlusion_scheduler.simulated_this_frame == 1`; el canal `uses_direct_effect()`; una voz con `directivity_dipole_weight = 1` de espaldas mide al menos 10 dB menos que de frente, y quitar la directividad GDScript no cambia nada (`_apply_voices` la salta con fuente). Reutilizar `TestParityClass.make_manager(tree, "steam_audio")`, `make_listener_camera`, `TestSteamSceneClass.make_wall` y un `OpenDouAcousticGeometryBake` en el árbol con `auto_bake_on_ready = true`.

- [ ] **Step 2: Correr y ver el fallo.**
- [ ] **Step 3: Implementar.**
  - LOD: `get_lod_features` gana `"enable_direct_simulation": true` en LOD 0 y 1, `false` en 2 y 3; `direct_simulation_max_distance()` como `physics_occlusion_max_distance()` pero con esa clave; `occlusion_samples_for(d) = 16 if d <= lod_0_max_distance else 8`.
  - Scheduler `process(...)`: si `spatial_backend_is_steam and ClassDB.class_exists("OpenDouSimulator") and OpenDouSimulator.is_ready()` (el manager le pasa `use_simulator: bool` al construirlo o como propiedad): para cada elegible dentro de `direct_simulation_max_distance()`, `ch = channel_of(inst)` (el manager le da el pool: `scheduler.voice_pool = voice_pool`); si `ch.sim_source < 0`: `ch.sim_source = OpenDouSimulator.create_source()`; `set_source_inputs(ch.sim_source, inst.emitter_position, inst.emitter_forward, Vector3.UP, inst.directivity_dipole_weight, inst.directivity_power, 0.5)`. Para los elegibles fuera de ese alcance con fuente: `release_source` y `-1`. Tras el bucle: `set_listener(listener_pos, -listener_basis.z, listener_basis.y)`, `run_direct()`, `simulated_this_frame = n`. Las voces **sin** fuente siguen el camino del rayo de Godot (código actual).
  - Canal: `var sim_source: int = -1`; `func uses_direct_effect() -> bool: return sim_source >= 0`; en `apply_spatial` (steam): `if sim_source >= 0: var d = OpenDouSimulator.get_direct(sim_source); s.set_direct_params(true, d[0], Vector3(d[1], d[2], d[3]), Vector3(d[4], d[5], d[6]), d[7]); cutoff_hz = 20000.0` (el paso-bajo del rayo no se aplica) `else: s.set_direct_params(false, 1, Vector3.ONE, Vector3.ONE, 1)` solo cuando cambió (bandera `_direct_was_on`).
  - Pool `virtualize`: `if ch.sim_source >= 0: OpenDouSimulator.release_source(ch.sim_source); ch.sim_source = -1` (y en `stop_immediate`).
  - Manager `_apply_voices`: `if instance.has_spatial_position and instance.directivity_dipole_weight > 0.0 and not ch.uses_direct_effect():` (la nativa ya la aplica).
  - Manager `_init`: tras crear el scheduler, `occlusion_scheduler.voice_pool = voice_pool` y `occlusion_scheduler.use_simulator = is_steam_audio_backend()`.

- [ ] **Step 4: Correr** → verde (paridad incluida: sin bake la paridad no cambia porque no hay escena).
- [ ] **Step 5: Commit** — `git commit -m "Fase 12: el planificador reparte fuentes del simulador por LOD y el canal empuja el efecto directo; el rayo de Godot queda como fallback"`

---

### Task 6: Presupuesto de simulación

**Files:**
- Create: `tests/sim_budget.txt`, `tests/test_sim_budget.gd`
- Modify: `tools/bench_control_loop.gd` (`OPENDOU_BENCH_DIRECT=1`: bake con seis muros y fuentes para todas las voces)

- [ ] **Step 1: Test** — escena de la quilla instanciada (como `run_keel_async`), 64 voces posteadas alrededor del oyente con `max_distance = 200`, cinco corridas de `manager._process`, mínimo de `OpenDouSimulator.last_run_usec()`; primera corrida imprime y no falla si el archivo no tiene valor; después `a.lt(min_usec, techo)`.
- [ ] **Step 2: Fijar** el techo = mínimo medido × 2 en `tests/sim_budget.txt` (`run_direct_usec_64 <valor>`).
- [ ] **Step 3: Banco** con `OPENDOU_BENCH_DIRECT=1`; anotar en el spec §11.
- [ ] **Step 4: Commit** — `git commit -m "Fase 12: presupuesto de simulacion directa (64 fuentes) y banco"`

---

### Task 7: Documentos y cierre

- [ ] `docs/funcionalidades.md` §3.2 (efecto directo ✅, materiales por banda), §3.5 (quitar efecto directo y materiales de «lo que no hace»), tabla de recursos (`AcousticMaterial`); `AGENTS.md` (observación 51: el bake es la escena; trampas: winding, in-place, `commit` tras altas/bajas, doble oclusión); `docs/tasks/current.md`; spec §11.
- [ ] `./run_tests.sh` verde; `git commit -m "Fase 12: documentos al dia; observacion 51"`.

---

## Autorevisión

- **Cobertura:** §3 → T1; §4 → T2; §5 → T3; §6 → T4 y T5; §7 → T5 y T6; §8–§9 repartidos; §10 riesgos nombrados en T2 (winding), T4 (in-place), T5 (doble oclusión).
- **Nombres consistentes:** `OpenDouAcousticScene.build/clear/is_ready/triangle_count/material_count` (T2, T3); `OpenDouSimulator.configure/create_source/release_source/set_source_inputs/set_listener/run_direct/get_direct` (T3, T5, T6); `set_direct_params(enabled, occlusion, transmission: Vector3, air: Vector3, directivity)` (T4, T5); `sim_source`, `uses_direct_effect()` (T5); `feed_steam_audio`, `export_to_native()`, `get_flat_geometry()` (T2, T5).
- **Sin marcadores de posición:** las comprobaciones «nombre exacto en phonon.h» (T3) y «claves de los triángulos del bake» (T2) son verificaciones contra código existente.
