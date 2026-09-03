#include "simulator.h"
#include "acoustic_scene.h"
#include "steam_audio_context.h"

#include <godot_cpp/classes/audio_server.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/core/class_db.hpp>

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

void OpenDouSimulator::_bind_methods() {
	ClassDB::bind_static_method("OpenDouSimulator", D_METHOD("configure", "max_sources", "occlusion_samples", "transmission_rays"), &OpenDouSimulator::configure);
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

bool OpenDouSimulator::configure(int max_sources, int occlusion_samples, int transmission_rays) {
	const int rate = static_cast<int>(AudioServer::get_singleton()->get_mix_rate());
	if (!SteamAudioContext::ensure(rate) || !OpenDouAcousticScene::is_ready()) {
		return false;
	}
	shutdown();
	IPLSimulationSettings s = {};
	s.flags = IPL_SIMULATIONFLAGS_DIRECT;
	s.sceneType = IPL_SCENETYPE_DEFAULT;
	s.maxNumOcclusionSamples = occlusion_samples;
	s.maxNumSources = max_sources;
	s.numThreads = 1;
	s.samplingRate = rate;
	s.frameSize = SteamAudioContext::audio_settings().frameSize;
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
	dirty_commit_ = false;
	return true;
}

void OpenDouSimulator::shutdown() {
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
	for (size_t i = 0; i < sources_.size(); i++) {
		if (sources_[i] == nullptr) {
			IPLSourceSettings ss = {};
			ss.flags = IPL_SIMULATIONFLAGS_DIRECT;
			if (iplSourceCreate(sim_, &ss, &sources_[i]) != IPL_STATUS_SUCCESS) {
				sources_[i] = nullptr;
				return -1;
			}
			iplSourceAdd(sources_[i], sim_);
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
	iplSourceRemove(sources_[h], sim_);
	iplSourceRelease(&sources_[h]);
	sources_[h] = nullptr;
	dirty_commit_ = true;
}

void OpenDouSimulator::set_source_inputs(int h, const Vector3 &pos, const Vector3 &fwd, const Vector3 &up, float dipole_weight, float dipole_power, float occlusion_radius) {
	if (!valid(h)) {
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
	iplSimulatorSetSharedInputs(sim_, IPL_SIMULATIONFLAGS_DIRECT, &sh);
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
	if (dirty_commit_) {
		iplSimulatorCommit(sim_);
		dirty_commit_ = false;
	}
	const uint64_t t0 = Time::get_singleton()->get_ticks_usec();
	iplSimulatorRunDirect(sim_);
	for (size_t i = 0; i < sources_.size(); i++) {
		if (sources_[i] != nullptr) {
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
