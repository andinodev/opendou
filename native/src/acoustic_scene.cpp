#include "acoustic_scene.h"
#include "steam_audio_context.h"

#include <godot_cpp/classes/audio_server.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <vector>

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
	if (triangles.size() % 3 != 0 || triangles.size() == 0 || material_indices.size() != triangles.size() / 3 || materials.size() == 0) {
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
