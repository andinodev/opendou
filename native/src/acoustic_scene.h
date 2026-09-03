#pragma once
// Escena de Steam Audio construida desde el bake (Fase 12). Estatica: hay una escena por
// proceso, igual que un contexto. La malla estatica se sustituye entera en cada build().
#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/array.hpp>
#include <vector>
#include <godot_cpp/variant/aabb.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/string.hpp>
#include <phonon.h>

namespace opendou {

class OpenDouAcousticScene : public godot::Object {
	GDCLASS(OpenDouAcousticScene, godot::Object)
public:
	static bool build(const godot::PackedVector3Array &vertices, const godot::PackedInt32Array &triangles, const godot::PackedInt32Array &material_indices, const godot::Array &materials);
	static void clear();
	static bool is_ready() { return scene_ != nullptr && mesh_ != nullptr; }
	static int triangle_count() { return triangle_count_; }
	static int material_count() { return material_count_; }
	static int generation() { return generation_; }
	static IPLScene scene() { return scene_; }
	// Sondas (Fase 14): generar sobre la escena, precocinar caminos, guardar y cargar .probes.
	static int generate_probes(float spacing_m, float height_m, const godot::AABB &bounds);
	static bool bake_paths(int num_samples, float radius, float threshold, float vis_range, float path_range, int num_threads);
	static bool save_probes(const godot::String &path);
	static bool load_probes(const godot::String &path);
	static void clear_probes();
	static int probe_count() { return probe_count_; }
	static bool has_probes() { return probes_ != nullptr; }
	static int probes_generation() { return probes_generation_; }
	// Bytes de datos de caminos precocinados en el lote (0 = sin bake de caminos).
	static int baked_path_data_size();
	static IPLProbeBatch probes() { return probes_; }
	// Ocluidores dinamicos (Fase 14): mallas instanciadas con transformacion propia.
	static int add_instanced(const godot::PackedVector3Array &vertices, const godot::PackedInt32Array &triangles, const godot::PackedInt32Array &material_indices, const godot::Array &materials, const godot::Transform3D &transform);
	static void update_instanced_transform(int id, const godot::Transform3D &transform);
	static void remove_instanced(int id);
	static void commit();
	static int instanced_count();
	static int instanced_updates() { return instanced_updates_; }

protected:
	static void _bind_methods();

private:
	static IPLScene scene_;
	static IPLStaticMesh mesh_;
	static int triangle_count_;
	static int material_count_;
	static int generation_;
	static IPLProbeBatch probes_;
	static int probe_count_;
	static int probes_generation_;
	struct Instanced {
		IPLScene sub = nullptr;
		IPLStaticMesh mesh = nullptr;
		IPLInstancedMesh instance = nullptr;
	};
	static std::vector<Instanced> instanced_;
	static bool dirty_;
	static int instanced_updates_;
	static bool make_static_mesh(IPLScene scene, const godot::PackedVector3Array &vertices, const godot::PackedInt32Array &triangles, const godot::PackedInt32Array &material_indices, const godot::Array &materials, IPLStaticMesh *out);
	static bool ensure_scene();
	static void release_instanced(Instanced &it);
};

} // namespace opendou
