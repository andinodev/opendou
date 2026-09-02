#include "steam_audio_context.h"

#include <godot_cpp/variant/utility_functions.hpp>

namespace opendou {

IPLContext SteamAudioContext::context_ = nullptr;
IPLAudioSettings SteamAudioContext::audio_ = { 44100, 512 };
int SteamAudioContext::requested_frame_size_ = 512;
std::atomic<SteamAudioContext::HrtfSlot *> SteamAudioContext::current_{ nullptr };
SteamAudioContext::HrtfSlot *SteamAudioContext::retired_[8] = {};
std::mutex SteamAudioContext::swap_mutex_;
std::atomic<int> SteamAudioContext::generation_{ 0 };
std::string SteamAudioContext::name_ = "default";

static void steam_audio_log(IPLLogLevel level, const char *message) {
	if (level == IPL_LOGLEVEL_ERROR) {
		godot::UtilityFunctions::push_error("[OpenDou/SteamAudio] ", message);
	} else if (level == IPL_LOGLEVEL_WARNING) {
		godot::UtilityFunctions::push_warning("[OpenDou/SteamAudio] ", message);
	}
}

bool SteamAudioContext::configure_frame_size(int frame_size) {
	if (context_ != nullptr) {
		return requested_frame_size_ == frame_size;
	}
	if (frame_size != 256 && frame_size != 512 && frame_size != 1024) {
		return false;
	}
	requested_frame_size_ = frame_size;
	return true;
}

bool SteamAudioContext::ensure(int sampling_rate) {
	if (is_ready()) {
		return true;
	}
	audio_.samplingRate = sampling_rate;
	audio_.frameSize = requested_frame_size_;

	if (context_ == nullptr) {
		IPLContextSettings settings = {};
		settings.version = STEAMAUDIO_VERSION;
		settings.logCallback = steam_audio_log;
		settings.simdLevel = IPL_SIMDLEVEL_AVX2;
		settings.flags = static_cast<IPLContextFlags>(0);
		if (iplContextCreate(&settings, &context_) != IPL_STATUS_SUCCESS) {
			godot::UtilityFunctions::push_error("[OpenDou/SteamAudio] no se pudo crear el contexto");
			context_ = nullptr;
			return false;
		}
	}
	return set_hrtf_default();
}

bool SteamAudioContext::install_hrtf(IPLHRTFSettings &settings, const std::string &name) {
	if (context_ == nullptr) {
		return false;
	}
	settings.volume = 1.0f;
	// Sin normalizacion: se probo IPL_HRTFNORMTYPE_RMS para cerrar los 2 dB de diferencia
	// frontal con el paneo de Godot y no movio el nivel medido ni una decima.
	settings.normType = IPL_HRTFNORMTYPE_NONE;
	IPLHRTF hrtf = nullptr;
	if (iplHRTFCreate(context_, &audio_, &settings, &hrtf) != IPL_STATUS_SUCCESS || hrtf == nullptr) {
		godot::UtilityFunctions::push_error("[OpenDou/SteamAudio] no se pudo crear el HRTF: ", name.c_str());
		return false;
	}
	std::lock_guard<std::mutex> lock(swap_mutex_);
	collect_retired();
	HrtfSlot *slot = new HrtfSlot();
	slot->hrtf = hrtf;
	slot->generation = generation_.load() + 1;
	HrtfSlot *old = current_.exchange(slot);
	generation_.store(slot->generation);
	name_ = name;
	if (old != nullptr) {
		bool parked = false;
		for (auto &r : retired_) {
			if (r == nullptr) {
				r = old;
				parked = true;
				break;
			}
		}
		if (!parked) {
			// Ocho cambios sin que ningun bloque los soltara: no pasa en la practica. Se
			// espera a que el mas antiguo quede libre y se sustituye.
			while (retired_[0]->refs.load() > 0) {
			}
			iplHRTFRelease(&retired_[0]->hrtf);
			delete retired_[0];
			retired_[0] = old;
		}
	}
	return true;
}

// Libera los HRTF retirados que ya nadie lee. Se llama con swap_mutex_ tomado.
void SteamAudioContext::collect_retired() {
	for (auto &r : retired_) {
		if (r != nullptr && r->refs.load() == 0) {
			iplHRTFRelease(&r->hrtf);
			delete r;
			r = nullptr;
		}
	}
}

bool SteamAudioContext::set_hrtf_default() {
	IPLHRTFSettings s = {};
	s.type = IPL_HRTFTYPE_DEFAULT;
	return install_hrtf(s, "default");
}

bool SteamAudioContext::set_hrtf_sofa(const std::string &path) {
	IPLHRTFSettings s = {};
	s.type = IPL_HRTFTYPE_SOFA;
	s.sofaFileName = path.c_str();
	const size_t cut = path.find_last_of("/\\");
	const std::string name = cut == std::string::npos ? path : path.substr(cut + 1);
	return install_hrtf(s, name);
}

std::string SteamAudioContext::hrtf_name() { return name_; }

SteamAudioContext::HrtfSlot *SteamAudioContext::acquire_hrtf() {
	HrtfSlot *slot = current_.load();
	if (slot != nullptr) {
		// Si justo ahora lo cambiaron, este slot esta retirado pero sigue vivo: refs > 0
		// impide que collect_retired lo libere hasta que este bloque termine.
		slot->refs.fetch_add(1);
	}
	return slot;
}

void SteamAudioContext::release_hrtf(HrtfSlot *slot) {
	if (slot != nullptr) {
		slot->refs.fetch_sub(1);
	}
}

void SteamAudioContext::shutdown() {
	std::lock_guard<std::mutex> lock(swap_mutex_);
	HrtfSlot *cur = current_.exchange(nullptr);
	if (cur != nullptr) {
		iplHRTFRelease(&cur->hrtf);
		delete cur;
	}
	for (auto &r : retired_) {
		if (r != nullptr) {
			iplHRTFRelease(&r->hrtf);
			delete r;
			r = nullptr;
		}
	}
	if (context_ != nullptr) {
		iplContextRelease(&context_);
		context_ = nullptr;
	}
}

} // namespace opendou
