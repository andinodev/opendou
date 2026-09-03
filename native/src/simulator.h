#pragma once
// Simulador de Steam Audio (Fase 12): fuentes por voz y corrida directa (oclusion volumetrica,
// transmision por material, absorcion del aire, directividad) contra OpenDouAcousticScene.
// Estatico: un simulador por proceso. run_direct() corre en el hilo principal.
#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <phonon.h>
#include <atomic>
#include <mutex>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <array>
#include <thread>
#include <vector>

namespace opendou {

class OpenDouSimulator : public godot::Object {
	GDCLASS(OpenDouSimulator, godot::Object)
public:
	static bool configure(int max_sources, int occlusion_samples, int transmission_rays, bool with_reflections = false, float max_duration = 2.0f, int max_rays = 4096);
	// Reflexiones (Fase 13): una fuente colocada en el oyente da la IR de la sala donde esta.
	static int create_listener_source();
	static void set_listener_source_position(int handle, const godot::Vector3 &position);
	static void start_reflections(float hz);
	static void stop_reflections();
	static bool is_reflections_running() { return thread_alive_.load(); }
	static int reflection_runs() { return reflection_runs_.load(); }
	static std::atomic<int> reflection_runs_;
	static godot::Vector3 get_reverb_times(int handle);
	static int reflections_generation(int handle);
	// Para el efecto de convolucion (hilo de audio): copia los parametros del ultimo resultado.
	static bool copy_reflection_params(int handle, IPLReflectionEffectParams &out);
	// Caminos (Fase 14): por fuente, con el lote de sondas de la escena. Corren en el hilo de
	// reflexiones y salen como direccion aparente + EQ por banda + ganancia (W).
	static void set_source_pathing(int handle, bool enabled, int order = 1);
	static godot::Dictionary get_pathing(int handle);
	static int pathing_generation(int handle);
	static int pathing_runs() { return pathing_runs_.load(); }
	static void set_path_visualization(bool enabled) { visualize_paths_.store(enabled); }
	static godot::PackedVector3Array get_path_segments();
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
	static std::vector<int> source_flags_;
	static std::vector<IPLSimulationOutputs> refl_outputs_;
	static std::vector<int> refl_generation_;
	static std::vector<godot::Vector3> listener_source_pos_;
	static bool with_reflections_;
	static float max_duration_;
	static std::thread thread_;
	static std::atomic<bool> thread_alive_;
	static std::atomic<bool> stop_flag_;
	static std::atomic<bool> running_;
	static std::mutex commit_mutex_;
	static std::mutex outputs_mutex_;
	static int period_ms_;
	static void thread_main();
	static bool commit_if_dirty_locked();
	static bool dirty_commit_;
	static int occlusion_samples_;
	static int transmission_rays_;
	static int last_run_usec_;
	static int scene_generation_;
	static std::vector<char> pathing_on_;
	static std::vector<int> pathing_order_;
	static std::vector<std::array<float, 4>> path_sh_;
	static std::vector<std::array<float, 3>> path_eq_;
	static std::vector<int> path_generation_;
	static IPLProbeBatch attached_probes_;
	static int probes_generation_seen_;
	static std::atomic<int> pathing_runs_;
	static std::atomic<bool> visualize_paths_;
	static std::vector<godot::Vector3> segments_building_;
	static std::vector<godot::Vector3> segments_;
	static void sync_probes_locked();
	static void IPLCALL vis_cb(IPLVector3 from, IPLVector3 to, IPLbool occluded, void *user);
};

} // namespace opendou
