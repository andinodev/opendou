#pragma once
// Simulador de Steam Audio (Fase 12): fuentes por voz y corrida directa (oclusion volumetrica,
// transmision por material, absorcion del aire, directividad) contra OpenDouAcousticScene.
// Estatico: un simulador por proceso. run_direct() corre en el hilo principal.
#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <phonon.h>
#include <vector>

namespace opendou {

class OpenDouSimulator : public godot::Object {
	GDCLASS(OpenDouSimulator, godot::Object)
public:
	static bool configure(int max_sources, int occlusion_samples, int transmission_rays);
	static void shutdown();
	static bool is_ready() { return sim_ != nullptr; }
	static int create_source();
	static void release_source(int handle);
	static void set_source_inputs(int handle, const godot::Vector3 &position, const godot::Vector3 &forward, const godot::Vector3 &up, float dipole_weight, float dipole_power, float occlusion_radius);
	static void set_listener(const godot::Vector3 &position, const godot::Vector3 &forward, const godot::Vector3 &up);
	static int run_direct();
	static godot::PackedFloat32Array get_direct(int handle);
	static int source_count();
	static int last_run_usec() { return last_run_usec_; }

protected:
	static void _bind_methods();

private:
	static bool valid(int h) { return sim_ != nullptr && h >= 0 && h < static_cast<int>(sources_.size()) && sources_[h] != nullptr; }
	static IPLCoordinateSpace3 space(const godot::Vector3 &pos, const godot::Vector3 &fwd, const godot::Vector3 &up);
	static IPLSimulator sim_;
	static std::vector<IPLSource> sources_;
	static std::vector<IPLSimulationOutputs> outputs_;
	static bool dirty_commit_;
	static int occlusion_samples_;
	static int transmission_rays_;
	static int last_run_usec_;
	static int scene_generation_;
};

} // namespace opendou
