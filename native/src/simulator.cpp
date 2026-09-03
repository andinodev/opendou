#include "simulator.h"
#include "acoustic_scene.h"
#include "steam_audio_context.h"

#include <godot_cpp/classes/audio_server.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <chrono>

using namespace godot;

namespace opendou {

IPLSimulator OpenDouSimulator::sim_ = nullptr;
std::vector<IPLSource> OpenDouSimulator::sources_;
std::vector<IPLSimulationOutputs> OpenDouSimulator::outputs_;
bool OpenDouSimulator::dirty_commit_ = false;
int OpenDouSimulator::occlusion_samples_ = 16;
int OpenDouSimulator::transmission_rays_ = 2;
int OpenDouSimulator::last_run_usec_ = 0;
int OpenDouSimulator::scene_generation_ = -1;
std::vector<int> OpenDouSimulator::source_flags_;
std::vector<IPLSimulationOutputs> OpenDouSimulator::refl_outputs_;
std::vector<int> OpenDouSimulator::refl_generation_;
std::vector<godot::Vector3> OpenDouSimulator::listener_source_pos_;
bool OpenDouSimulator::with_reflections_ = false;
float OpenDouSimulator::max_duration_ = 2.0f;
std::thread OpenDouSimulator::thread_;
std::atomic<bool> OpenDouSimulator::thread_alive_{ false };
std::atomic<bool> OpenDouSimulator::stop_flag_{ false };
std::atomic<bool> OpenDouSimulator::running_{ false };
std::mutex OpenDouSimulator::commit_mutex_;
std::mutex OpenDouSimulator::outputs_mutex_;
int OpenDouSimulator::period_ms_ = 100;

void OpenDouSimulator::_bind_methods() {
	ClassDB::bind_static_method("OpenDouSimulator", D_METHOD("configure", "max_sources", "occlusion_samples", "transmission_rays", "with_reflections", "max_duration", "max_rays"), &OpenDouSimulator::configure, DEFVAL(false), DEFVAL(2.0f), DEFVAL(4096));
	ClassDB::bind_static_method("OpenDouSimulator", D_METHOD("create_listener_source"), &OpenDouSimulator::create_listener_source);
	ClassDB::bind_static_method("OpenDouSimulator", D_METHOD("set_listener_source_position", "handle", "position"), &OpenDouSimulator::set_listener_source_position);
	ClassDB::bind_static_method("OpenDouSimulator", D_METHOD("start_reflections", "hz"), &OpenDouSimulator::start_reflections);
	ClassDB::bind_static_method("OpenDouSimulator", D_METHOD("stop_reflections"), &OpenDouSimulator::stop_reflections);
	ClassDB::bind_static_method("OpenDouSimulator", D_METHOD("is_reflections_running"), &OpenDouSimulator::is_reflections_running);
	ClassDB::bind_static_method("OpenDouSimulator", D_METHOD("get_reverb_times", "handle"), &OpenDouSimulator::get_reverb_times);
	ClassDB::bind_static_method("OpenDouSimulator", D_METHOD("reflections_generation", "handle"), &OpenDouSimulator::reflections_generation);
	ClassDB::bind_static_method("OpenDouSimulator", D_METHOD("shutdown"), &OpenDouSimulator::shutdown);
	ClassDB::bind_static_method("OpenDouSimulator", D_METHOD("is_ready"), &OpenDouSimulator::is_ready);
	ClassDB::bind_static_method("OpenDouSimulator", D_METHOD("create_source"), &OpenDouSimulator::create_source);
	ClassDB::bind_static_method("OpenDouSimulator", D_METHOD("release_source", "handle"), &OpenDouSimulator::release_source);
	ClassDB::bind_static_method("OpenDouSimulator", D_METHOD("set_source_inputs", "handle", "position", "forward", "up", "dipole_weight", "dipole_power", "occlusion_radius"), &OpenDouSimulator::set_source_inputs);
	ClassDB::bind_static_method("OpenDouSimulator", D_METHOD("set_listener", "position", "forward", "up"), &OpenDouSimulator::set_listener);
	ClassDB::bind_static_method("OpenDouSimulator", D_METHOD("run_direct"), &OpenDouSimulator::run_direct);
	ClassDB::bind_static_method("OpenDouSimulator", D_METHOD("get_direct", "handle"), &OpenDouSimulator::get_direct);
	ClassDB::bind_static_method("OpenDouSimulator", D_METHOD("source_count"), &OpenDouSimulator::source_count);
	ClassDB::bind_static_method("OpenDouSimulator", D_METHOD("last_run_usec"), &OpenDouSimulator::last_run_usec);
}

IPLCoordinateSpace3 OpenDouSimulator::space(const Vector3 &pos, const Vector3 &fwd, const Vector3 &up) {
	// Steam Audio: right, up, ahead, origin. Godot mira a -Z: quien llama pasa forward = -basis.z.
	const Vector3 f = fwd.normalized();
	const Vector3 u = up.normalized();
	const Vector3 r = f.cross(u).normalized();
	IPLCoordinateSpace3 s = {};
	s.right = IPLVector3{ r.x, r.y, r.z };
	s.up = IPLVector3{ u.x, u.y, u.z };
	s.ahead = IPLVector3{ f.x, f.y, f.z };
	s.origin = IPLVector3{ pos.x, pos.y, pos.z };
	return s;
}

bool OpenDouSimulator::configure(int max_sources, int occlusion_samples, int transmission_rays, bool with_reflections, float max_duration, int max_rays) {
	const int rate = static_cast<int>(AudioServer::get_singleton()->get_mix_rate());
	if (!SteamAudioContext::ensure(rate) || !OpenDouAcousticScene::is_ready()) {
		return false;
	}
	shutdown();
	IPLSimulationSettings s = {};
	s.flags = with_reflections ? static_cast<IPLSimulationFlags>(IPL_SIMULATIONFLAGS_DIRECT | IPL_SIMULATIONFLAGS_REFLECTIONS) : IPL_SIMULATIONFLAGS_DIRECT;
	s.sceneType = IPL_SCENETYPE_DEFAULT;
	s.reflectionType = IPL_REFLECTIONEFFECTTYPE_HYBRID;
	s.maxNumOcclusionSamples = occlusion_samples;
	s.maxNumRays = max_rays;
	s.numDiffuseSamples = 32;
	s.maxDuration = max_duration;
	s.maxOrder = 1;
	s.maxNumSources = max_sources;
	s.numThreads = 2;
	s.rayBatchSize = 16;
	s.samplingRate = rate;
	s.frameSize = SteamAudioContext::audio_settings().frameSize;
	with_reflections_ = with_reflections;
	max_duration_ = max_duration;
	if (iplSimulatorCreate(SteamAudioContext::context(), &s, &sim_) != IPL_STATUS_SUCCESS) {
		sim_ = nullptr;
		return false;
	}
	iplSimulatorSetScene(sim_, OpenDouAcousticScene::scene());
	iplSimulatorCommit(sim_);
	scene_generation_ = OpenDouAcousticScene::generation();
	occlusion_samples_ = occlusion_samples;
	transmission_rays_ = transmission_rays;
	sources_.assign(max_sources, nullptr);
	outputs_.assign(max_sources, IPLSimulationOutputs{});
	source_flags_.assign(max_sources, 0);
	refl_outputs_.assign(max_sources, IPLSimulationOutputs{});
	refl_generation_.assign(max_sources, 0);
	listener_source_pos_.assign(max_sources, Vector3());
	dirty_commit_ = false;
	return true;
}

bool OpenDouSimulator::commit_if_dirty_locked() {
	// Quien llama tiene commit_mutex_. Nunca mientras corre una simulacion en otro hilo.
	if (dirty_commit_ && !running_.load()) {
		iplSimulatorCommit(sim_);
		dirty_commit_ = false;
		return true;
	}
	return false;
}

int OpenDouSimulator::create_listener_source() {
	if (sim_ == nullptr || !with_reflections_) {
		return -1;
	}
	std::lock_guard<std::mutex> lk(commit_mutex_);
	for (size_t i = 0; i < sources_.size(); i++) {
		if (sources_[i] == nullptr) {
			IPLSourceSettings ss = {};
			ss.flags = IPL_SIMULATIONFLAGS_REFLECTIONS;
			if (iplSourceCreate(sim_, &ss, &sources_[i]) != IPL_STATUS_SUCCESS) {
				sources_[i] = nullptr;
				return -1;
			}
			iplSourceAdd(sources_[i], sim_);
			source_flags_[i] = IPL_SIMULATIONFLAGS_REFLECTIONS;
			refl_outputs_[i] = IPLSimulationOutputs{};
			refl_generation_[i] = 0;
			dirty_commit_ = true;
			return static_cast<int>(i);
		}
	}
	return -1;
}

void OpenDouSimulator::set_listener_source_position(int h, const Vector3 &pos) {
	if (!valid(h) || source_flags_[h] != IPL_SIMULATIONFLAGS_REFLECTIONS) {
		return;
	}
	listener_source_pos_[h] = pos;
	IPLSimulationInputs in = {};
	in.flags = IPL_SIMULATIONFLAGS_REFLECTIONS;
	in.source = space(pos, Vector3(0, 0, -1), Vector3(0, 1, 0));
	in.reverbScale[0] = 1.0f;
	in.reverbScale[1] = 1.0f;
	in.reverbScale[2] = 1.0f;
	in.hybridReverbTransitionTime = 1.0f;
	in.hybridReverbOverlapPercent = 0.25f;
	iplSourceSetInputs(sources_[h], IPL_SIMULATIONFLAGS_REFLECTIONS, &in);
}

void OpenDouSimulator::thread_main() {
	while (!stop_flag_.load()) {
		{
			std::lock_guard<std::mutex> lk(commit_mutex_);
			if (sim_ == nullptr) {
				break;
			}
			commit_if_dirty_locked();
			running_.store(true);
		}
		iplSimulatorRunReflections(sim_);
		{
			std::lock_guard<std::mutex> lk(outputs_mutex_);
			for (size_t i = 0; i < sources_.size(); i++) {
				if (sources_[i] != nullptr && source_flags_[i] == IPL_SIMULATIONFLAGS_REFLECTIONS) {
					iplSourceGetOutputs(sources_[i], IPL_SIMULATIONFLAGS_REFLECTIONS, &refl_outputs_[i]);
					refl_generation_[i]++;
				}
			}
		}
		running_.store(false);
		std::this_thread::sleep_for(std::chrono::milliseconds(period_ms_));
	}
	thread_alive_.store(false);
}

void OpenDouSimulator::start_reflections(float hz) {
	if (sim_ == nullptr || !with_reflections_ || thread_alive_.load()) {
		return;
	}
	period_ms_ = static_cast<int>(1000.0f / std::max(hz, 0.5f));
	stop_flag_.store(false);
	thread_alive_.store(true);
	thread_ = std::thread(&OpenDouSimulator::thread_main);
}

void OpenDouSimulator::stop_reflections() {
	stop_flag_.store(true);
	if (thread_.joinable()) {
		thread_.join();
	}
	thread_alive_.store(false);
	running_.store(false);
}

Vector3 OpenDouSimulator::get_reverb_times(int h) {
	if (!valid(h)) {
		return Vector3();
	}
	std::lock_guard<std::mutex> lk(outputs_mutex_);
	const IPLReflectionEffectParams &r = refl_outputs_[h].reflections;
	return Vector3(r.reverbTimes[0], r.reverbTimes[1], r.reverbTimes[2]);
}

int OpenDouSimulator::reflections_generation(int h) {
	if (!valid(h)) {
		return 0;
	}
	std::lock_guard<std::mutex> lk(outputs_mutex_);
	return refl_generation_[h];
}

bool OpenDouSimulator::copy_reflection_params(int h, IPLReflectionEffectParams &out) {
	if (!valid(h)) {
		return false;
	}
	std::lock_guard<std::mutex> lk(outputs_mutex_);
	if (refl_generation_[h] == 0) {
		return false;
	}
	out = refl_outputs_[h].reflections;
	return true;
}

void OpenDouSimulator::shutdown() {
	stop_reflections();
	for (size_t i = 0; i < sources_.size(); i++) {
		if (sources_[i] != nullptr) {
			iplSourceRemove(sources_[i], sim_);
			iplSourceRelease(&sources_[i]);
			sources_[i] = nullptr;
		}
	}
	sources_.clear();
	outputs_.clear();
	if (sim_ != nullptr) {
		iplSimulatorRelease(&sim_);
		sim_ = nullptr;
	}
}

int OpenDouSimulator::create_source() {
	if (sim_ == nullptr) {
		return -1;
	}
	std::lock_guard<std::mutex> lk(commit_mutex_);
	for (size_t i = 0; i < sources_.size(); i++) {
		if (sources_[i] == nullptr) {
			IPLSourceSettings ss = {};
			ss.flags = IPL_SIMULATIONFLAGS_DIRECT;
			if (iplSourceCreate(sim_, &ss, &sources_[i]) != IPL_STATUS_SUCCESS) {
				sources_[i] = nullptr;
				return -1;
			}
			iplSourceAdd(sources_[i], sim_);
			source_flags_[i] = IPL_SIMULATIONFLAGS_DIRECT;
			outputs_[i] = IPLSimulationOutputs{};
			dirty_commit_ = true;
			return static_cast<int>(i);
		}
	}
	return -1;
}

void OpenDouSimulator::release_source(int h) {
	if (!valid(h)) {
		return;
	}
	std::lock_guard<std::mutex> lk(commit_mutex_);
	iplSourceRemove(sources_[h], sim_);
	iplSourceRelease(&sources_[h]);
	sources_[h] = nullptr;
	source_flags_[h] = 0;
	dirty_commit_ = true;
}

void OpenDouSimulator::set_source_inputs(int h, const Vector3 &pos, const Vector3 &fwd, const Vector3 &up, float dipole_weight, float dipole_power, float occlusion_radius) {
	if (!valid(h) || source_flags_[h] != IPL_SIMULATIONFLAGS_DIRECT) {
		return;
	}
	IPLSimulationInputs in = {};
	in.flags = IPL_SIMULATIONFLAGS_DIRECT;
	in.directFlags = static_cast<IPLDirectSimulationFlags>(IPL_DIRECTSIMULATIONFLAGS_OCCLUSION | IPL_DIRECTSIMULATIONFLAGS_TRANSMISSION | IPL_DIRECTSIMULATIONFLAGS_AIRABSORPTION | IPL_DIRECTSIMULATIONFLAGS_DIRECTIVITY);
	in.source = space(pos, fwd, up);
	in.airAbsorptionModel.type = IPL_AIRABSORPTIONTYPE_DEFAULT;
	in.directivity.dipoleWeight = dipole_weight;
	in.directivity.dipolePower = dipole_power;
	in.occlusionType = IPL_OCCLUSIONTYPE_VOLUMETRIC;
	in.occlusionRadius = occlusion_radius;
	in.numOcclusionSamples = occlusion_samples_;
	in.numTransmissionRays = transmission_rays_;
	iplSourceSetInputs(sources_[h], IPL_SIMULATIONFLAGS_DIRECT, &in);
}

void OpenDouSimulator::set_listener(const Vector3 &pos, const Vector3 &fwd, const Vector3 &up) {
	if (sim_ == nullptr) {
		return;
	}
	IPLSimulationSharedInputs sh = {};
	sh.listener = space(pos, fwd, up);
	sh.numRays = 2048;
	sh.numBounces = 16;
	sh.duration = max_duration_;
	sh.order = 1;
	sh.irradianceMinDistance = 1.0f;
	iplSimulatorSetSharedInputs(sim_, IPL_SIMULATIONFLAGS_DIRECT, &sh);
	if (with_reflections_) {
		iplSimulatorSetSharedInputs(sim_, IPL_SIMULATIONFLAGS_REFLECTIONS, &sh);
	}
}

int OpenDouSimulator::run_direct() {
	if (sim_ == nullptr) {
		return 0;
	}
	// Si el bake se reconstruyo, la escena es la misma pero su malla cambio: hay que recomitear.
	if (scene_generation_ != OpenDouAcousticScene::generation()) {
		iplSimulatorSetScene(sim_, OpenDouAcousticScene::scene());
		scene_generation_ = OpenDouAcousticScene::generation();
		dirty_commit_ = true;
	}
	{
		std::lock_guard<std::mutex> lk(commit_mutex_);
		commit_if_dirty_locked();
	}
	const uint64_t t0 = Time::get_singleton()->get_ticks_usec();
	iplSimulatorRunDirect(sim_);
	for (size_t i = 0; i < sources_.size(); i++) {
		if (sources_[i] != nullptr && source_flags_[i] == IPL_SIMULATIONFLAGS_DIRECT) {
			iplSourceGetOutputs(sources_[i], IPL_SIMULATIONFLAGS_DIRECT, &outputs_[i]);
		}
	}
	last_run_usec_ = static_cast<int>(Time::get_singleton()->get_ticks_usec() - t0);
	return last_run_usec_;
}

PackedFloat32Array OpenDouSimulator::get_direct(int h) {
	PackedFloat32Array out;
	out.resize(8);
	out.fill(1.0f);
	if (!valid(h)) {
		return out;
	}
	const IPLDirectEffectParams &d = outputs_[h].direct;
	out[0] = d.occlusion;
	out[1] = d.transmission[0];
	out[2] = d.transmission[1];
	out[3] = d.transmission[2];
	out[4] = d.airAbsorption[0];
	out[5] = d.airAbsorption[1];
	out[6] = d.airAbsorption[2];
	out[7] = d.directivity;
	return out;
}

int OpenDouSimulator::source_count() {
	int n = 0;
	for (size_t i = 0; i < sources_.size(); i++) {
		if (sources_[i] != nullptr) {
			n++;
		}
	}
	return n;
}

} // namespace opendou
