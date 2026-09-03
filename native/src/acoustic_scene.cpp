#include "acoustic_scene.h"
#include "steam_audio_context.h"
#include "simulator.h"

#include <godot_cpp/classes/audio_server.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <cstring>
#include <godot_cpp/variant/utility_functions.hpp>
#include <vector>

using namespace godot;

namespace opendou {

IPLScene OpenDouAcousticScene::scene_ = nullptr;
IPLStaticMesh OpenDouAcousticScene::mesh_ = nullptr;
int OpenDouAcousticScene::triangle_count_ = 0;
int OpenDouAcousticScene::material_count_ = 0;
int OpenDouAcousticScene::generation_ = 0;
IPLProbeBatch OpenDouAcousticScene::probes_ = nullptr;
int OpenDouAcousticScene::probe_count_ = 0;
int OpenDouAcousticScene::probes_generation_ = 0;
std::vector<OpenDouAcousticScene::Instanced> OpenDouAcousticScene::instanced_;
bool OpenDouAcousticScene::dirty_ = false;
int OpenDouAcousticScene::instanced_updates_ = 0;

void OpenDouAcousticScene::_bind_methods() {
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("build", "vertices", "triangles", "material_indices", "materials"), &OpenDouAcousticScene::build);
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("clear"), &OpenDouAcousticScene::clear);
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("is_ready"), &OpenDouAcousticScene::is_ready);
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("triangle_count"), &OpenDouAcousticScene::triangle_count);
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("material_count"), &OpenDouAcousticScene::material_count);
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("generation"), &OpenDouAcousticScene::generation);
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("generate_probes", "spacing_m", "height_m", "bounds"), &OpenDouAcousticScene::generate_probes);
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("bake_paths", "num_samples", "radius", "threshold", "vis_range", "path_range", "num_threads"), &OpenDouAcousticScene::bake_paths);
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("save_probes", "path"), &OpenDouAcousticScene::save_probes);
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("load_probes", "path"), &OpenDouAcousticScene::load_probes);
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("clear_probes"), &OpenDouAcousticScene::clear_probes);
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("probe_count"), &OpenDouAcousticScene::probe_count);
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("has_probes"), &OpenDouAcousticScene::has_probes);
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("probes_generation"), &OpenDouAcousticScene::probes_generation);
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("add_instanced", "vertices", "triangles", "material_indices", "materials", "transform"), &OpenDouAcousticScene::add_instanced);
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("update_instanced_transform", "id", "transform"), &OpenDouAcousticScene::update_instanced_transform);
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("remove_instanced", "id"), &OpenDouAcousticScene::remove_instanced);
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("commit"), &OpenDouAcousticScene::commit);
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("instanced_count"), &OpenDouAcousticScene::instanced_count);
	ClassDB::bind_static_method("OpenDouAcousticScene", D_METHOD("instanced_updates"), &OpenDouAcousticScene::instanced_updates);
}

bool OpenDouAcousticScene::build(const PackedVector3Array &vertices, const PackedInt32Array &triangles, const PackedInt32Array &material_indices, const Array &materials) {
	const int rate = static_cast<int>(AudioServer::get_singleton()->get_mix_rate());
	if (!SteamAudioContext::ensure(rate)) {
		return false;
	}
	if (triangles.size() % 3 != 0 || triangles.size() == 0 || material_indices.size() != triangles.size() / 3 || materials.size() == 0) {
		return false;
	}
	if (!ensure_scene()) {
		return false;
	}
	if (mesh_ != nullptr) {
		iplStaticMeshRemove(mesh_, scene_);
		iplStaticMeshRelease(&mesh_);
		mesh_ = nullptr;
	}
	if (!make_static_mesh(scene_, vertices, triangles, material_indices, materials, &mesh_)) {
		mesh_ = nullptr;
		return false;
	}
	triangle_count_ = static_cast<int>(triangles.size() / 3);
	material_count_ = static_cast<int>(materials.size());
	iplStaticMeshAdd(mesh_, scene_);
	iplSceneCommit(scene_);
	generation_++;
	return true;
}

// Matriz 4x4 (elements[fila][columna], vectores columna) que lleva el cubo CENTRADO en el
// origen ([-0.5, 0.5]^3, como el cubo de Unity) a la caja: escala = tamano, traslacion = centro.
static IPLMatrix4x4 box_matrix(const AABB &box) {
	IPLMatrix4x4 m = {};
	const Vector3 c = box.get_center();
	m.elements[0][0] = box.size.x;
	m.elements[1][1] = box.size.y;
	m.elements[2][2] = box.size.z;
	m.elements[0][3] = c.x;
	m.elements[1][3] = c.y;
	m.elements[2][3] = c.z;
	m.elements[3][3] = 1.0f;
	return m;
}

// Steam Audio 4.8.1 llama al callback de progreso sin comprobar nulo (la documentacion dice
// "puede ser NULL"; con NULL, iplPathBakerBake salta a la direccion 0). Siempre uno vacio.
static void IPLCALL bake_progress_noop(IPLfloat32, void *) {}

int OpenDouAcousticScene::generate_probes(float spacing_m, float height_m, const AABB &bounds) {
	if (!is_ready()) {
		return 0;
	}
	clear_probes();
	IPLProbeArray arr = nullptr;
	if (iplProbeArrayCreate(SteamAudioContext::context(), &arr) != IPL_STATUS_SUCCESS) {
		return 0;
	}
	IPLProbeGenerationParams p = {};
	p.type = IPL_PROBEGENERATIONTYPE_UNIFORMFLOOR;
	p.spacing = spacing_m;
	p.height = height_m;
	p.transform = box_matrix(bounds);
	iplProbeArrayGenerateProbes(arr, scene_, &p);
	const int n = iplProbeArrayGetNumProbes(arr);
	if (n <= 0 || iplProbeBatchCreate(SteamAudioContext::context(), &probes_) != IPL_STATUS_SUCCESS) {
		iplProbeArrayRelease(&arr);
		probes_ = nullptr;
		return 0;
	}
	iplProbeBatchAddProbeArray(probes_, arr);
	iplProbeBatchCommit(probes_);
	iplProbeArrayRelease(&arr);
	probe_count_ = n;
	probes_generation_++;
	return n;
}

bool OpenDouAcousticScene::bake_paths(int num_samples, float radius, float threshold, float vis_range, float path_range, int num_threads) {
	if (!is_ready() || probes_ == nullptr) {
		return false;
	}
	IPLPathBakeParams b = {};
	b.scene = scene_;
	b.probeBatch = probes_;
	b.identifier.type = IPL_BAKEDDATATYPE_PATHING;
	b.identifier.variation = IPL_BAKEDDATAVARIATION_DYNAMIC;
	b.numSamples = num_samples;
	b.radius = radius;
	b.threshold = threshold;
	b.visRange = vis_range;
	b.pathRange = path_range;
	b.numThreads = num_threads < 1 ? 1 : num_threads;
	iplPathBakerBake(SteamAudioContext::context(), &b, &bake_progress_noop, nullptr);
	iplProbeBatchCommit(probes_);
	probes_generation_++;
	return true;
}

bool OpenDouAcousticScene::save_probes(const String &path) {
	if (probes_ == nullptr) {
		return false;
	}
	IPLSerializedObjectSettings ss = {};
	IPLSerializedObject obj = nullptr;
	if (iplSerializedObjectCreate(SteamAudioContext::context(), &ss, &obj) != IPL_STATUS_SUCCESS) {
		return false;
	}
	iplProbeBatchSave(probes_, obj);
	const IPLsize n = iplSerializedObjectGetSize(obj);
	PackedByteArray bytes;
	bytes.resize(static_cast<int64_t>(n));
	std::memcpy(bytes.ptrw(), iplSerializedObjectGetData(obj), n);
	iplSerializedObjectRelease(&obj);
	Ref<FileAccess> f = FileAccess::open(path, FileAccess::WRITE);
	if (f.is_null()) {
		return false;
	}
	f->store_buffer(bytes);
	f->close();
	return true;
}

bool OpenDouAcousticScene::load_probes(const String &path) {
	Ref<FileAccess> f = FileAccess::open(path, FileAccess::READ);
	if (f.is_null()) {
		return false;
	}
	PackedByteArray bytes = f->get_buffer(static_cast<int64_t>(f->get_length()));
	f->close();
	if (bytes.size() == 0) {
		return false;
	}
	const int rate = static_cast<int>(AudioServer::get_singleton()->get_mix_rate());
	if (!SteamAudioContext::ensure(rate)) {
		return false;
	}
	IPLSerializedObjectSettings ss = {};
	ss.data = reinterpret_cast<IPLbyte *>(bytes.ptrw());
	ss.size = static_cast<IPLsize>(bytes.size());
	IPLSerializedObject obj = nullptr;
	if (iplSerializedObjectCreate(SteamAudioContext::context(), &ss, &obj) != IPL_STATUS_SUCCESS) {
		return false;
	}
	clear_probes();
	const IPLerror e = iplProbeBatchLoad(SteamAudioContext::context(), obj, &probes_);
	iplSerializedObjectRelease(&obj);
	if (e != IPL_STATUS_SUCCESS) {
		probes_ = nullptr;
		return false;
	}
	iplProbeBatchCommit(probes_);
	probe_count_ = iplProbeBatchGetNumProbes(probes_);
	probes_generation_++;
	return true;
}


bool OpenDouAcousticScene::ensure_scene() {
	if (scene_ != nullptr) {
		return true;
	}
	const int rate = static_cast<int>(AudioServer::get_singleton()->get_mix_rate());
	if (!SteamAudioContext::ensure(rate)) {
		return false;
	}
	IPLSceneSettings settings = {};
	settings.type = IPL_SCENETYPE_DEFAULT;
	if (iplSceneCreate(SteamAudioContext::context(), &settings, &scene_) != IPL_STATUS_SUCCESS) {
		scene_ = nullptr;
		return false;
	}
	return true;
}

// Malla estatica de Steam Audio a partir de la geometria aplanada (vertices por triangulo).
bool OpenDouAcousticScene::make_static_mesh(IPLScene scene, const PackedVector3Array &vertices, const PackedInt32Array &triangles, const PackedInt32Array &material_indices, const Array &materials, IPLStaticMesh *out) {
	if (triangles.size() % 3 != 0 || triangles.size() == 0 || material_indices.size() != triangles.size() / 3 || materials.size() == 0) {
		return false;
	}
	std::vector<IPLVector3> v(vertices.size());
	for (int64_t i = 0; i < vertices.size(); i++) {
		const Vector3 p = vertices[i];
		v[i] = IPLVector3{ p.x, p.y, p.z };
	}
	std::vector<IPLTriangle> t(triangles.size() / 3);
	for (size_t i = 0; i < t.size(); i++) {
		t[i] = IPLTriangle{ { triangles[3 * i], triangles[3 * i + 1], triangles[3 * i + 2] } };
	}
	std::vector<IPLint32> mi(material_indices.size());
	for (int64_t i = 0; i < material_indices.size(); i++) {
		mi[i] = material_indices[i];
	}
	std::vector<IPLMaterial> m(materials.size());
	for (int64_t i = 0; i < materials.size(); i++) {
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
	if (iplStaticMeshCreate(scene, &s, out) != IPL_STATUS_SUCCESS) {
		*out = nullptr;
		return false;
	}
	iplStaticMeshAdd(*out, scene);
	return true;
}

// Matriz 4x4 de Steam Audio (elements[fila][columna], vectores columna) desde una Transform3D.
static IPLMatrix4x4 to_ipl(const Transform3D &xf) {
	IPLMatrix4x4 m = {};
	for (int c = 0; c < 3; c++) {
		const Vector3 col = xf.basis.get_column(c);
		m.elements[0][c] = col.x;
		m.elements[1][c] = col.y;
		m.elements[2][c] = col.z;
	}
	m.elements[0][3] = xf.origin.x;
	m.elements[1][3] = xf.origin.y;
	m.elements[2][3] = xf.origin.z;
	m.elements[3][3] = 1.0f;
	return m;
}

void OpenDouAcousticScene::release_instanced(Instanced &it) {
	if (it.instance != nullptr) {
		if (scene_ != nullptr) {
			iplInstancedMeshRemove(it.instance, scene_);
		}
		iplInstancedMeshRelease(&it.instance);
	}
	if (it.mesh != nullptr) {
		iplStaticMeshRelease(&it.mesh);
	}
	if (it.sub != nullptr) {
		iplSceneRelease(&it.sub);
	}
	it = Instanced{};
}

int OpenDouAcousticScene::add_instanced(const PackedVector3Array &vertices, const PackedInt32Array &triangles, const PackedInt32Array &material_indices, const Array &materials, const Transform3D &transform) {
	if (!ensure_scene()) {
		return -1;
	}
	Instanced it;
	IPLSceneSettings settings = {};
	settings.type = IPL_SCENETYPE_DEFAULT;
	if (iplSceneCreate(SteamAudioContext::context(), &settings, &it.sub) != IPL_STATUS_SUCCESS) {
		return -1;
	}
	if (!make_static_mesh(it.sub, vertices, triangles, material_indices, materials, &it.mesh)) {
		iplSceneRelease(&it.sub);
		return -1;
	}
	iplSceneCommit(it.sub);
	IPLInstancedMeshSettings is = {};
	is.subScene = it.sub;
	is.transform = to_ipl(transform);
	if (iplInstancedMeshCreate(scene_, &is, &it.instance) != IPL_STATUS_SUCCESS) {
		it.instance = nullptr;
		release_instanced(it);
		return -1;
	}
	iplInstancedMeshAdd(it.instance, scene_);
	dirty_ = true;
	for (size_t i = 0; i < instanced_.size(); i++) {
		if (instanced_[i].instance == nullptr) {
			instanced_[i] = it;
			return static_cast<int>(i);
		}
	}
	instanced_.push_back(it);
	return static_cast<int>(instanced_.size() - 1);
}

void OpenDouAcousticScene::update_instanced_transform(int id, const Transform3D &transform) {
	if (scene_ == nullptr || id < 0 || id >= static_cast<int>(instanced_.size()) || instanced_[id].instance == nullptr) {
		return;
	}
	iplInstancedMeshUpdateTransform(instanced_[id].instance, scene_, to_ipl(transform));
	dirty_ = true;
}

void OpenDouAcousticScene::remove_instanced(int id) {
	if (id < 0 || id >= static_cast<int>(instanced_.size()) || instanced_[id].instance == nullptr) {
		return;
	}
	release_instanced(instanced_[id]);
	dirty_ = true;
}

// Una vez por cuadro (lo llama el bake): aplica altas, bajas y movimientos pendientes.
void OpenDouAcousticScene::commit() {
	if (scene_ == nullptr || !dirty_) {
		return;
	}
	iplSceneCommit(scene_);
	dirty_ = false;
	instanced_updates_++;
}

int OpenDouAcousticScene::instanced_count() {
	int n = 0;
	for (const Instanced &it : instanced_) {
		if (it.instance != nullptr) {
			n++;
		}
	}
	return n;
}

void OpenDouAcousticScene::clear_probes() {
	if (probes_ != nullptr) {
		iplProbeBatchRelease(&probes_);
		probes_ = nullptr;
	}
	probe_count_ = 0;
	probes_generation_++;
}

void OpenDouAcousticScene::clear() {
	clear_probes();
	for (Instanced &it : instanced_) {
		release_instanced(it);
	}
	instanced_.clear();
	dirty_ = false;
	// El simulador apunta a esta escena: sin escena no hay simulador (las fuentes se invalidan).
	OpenDouSimulator::shutdown();
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
