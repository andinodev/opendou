#pragma once
// Escena de Steam Audio construida desde el bake (Fase 12). Estatica: hay una escena por
// proceso, igual que un contexto. La malla estatica se sustituye entera en cada build().
#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/array.hpp>
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
