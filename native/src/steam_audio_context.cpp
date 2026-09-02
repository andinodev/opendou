#include "steam_audio_context.h"

#include <godot_cpp/variant/utility_functions.hpp>

namespace opendou {

IPLContext SteamAudioContext::context_ = nullptr;
IPLHRTF SteamAudioContext::hrtf_ = nullptr;
IPLAudioSettings SteamAudioContext::audio_ = { 44100, 512 };

static void steam_audio_log(IPLLogLevel level, const char *message) {
	if (level == IPL_LOGLEVEL_ERROR) {
		godot::UtilityFunctions::push_error("[OpenDou/SteamAudio] ", message);
	} else if (level == IPL_LOGLEVEL_WARNING) {
		godot::UtilityFunctions::push_warning("[OpenDou/SteamAudio] ", message);
	}
}

bool SteamAudioContext::ensure(int sampling_rate, int frame_size) {
	if (is_ready()) {
		return true;
	}
	audio_.samplingRate = sampling_rate;
	audio_.frameSize = frame_size;

	IPLContextSettings settings = {};
	settings.version = STEAMAUDIO_VERSION;
	settings.logCallback = steam_audio_log;
	settings.simdLevel = IPL_SIMDLEVEL_AVX2;
	settings.flags = static_cast<IPLContextFlags>(0);

	if (context_ == nullptr) {
		if (iplContextCreate(&settings, &context_) != IPL_STATUS_SUCCESS) {
			godot::UtilityFunctions::push_error("[OpenDou/SteamAudio] no se pudo crear el contexto");
			context_ = nullptr;
			return false;
		}
	}

	IPLHRTFSettings hrtf_settings = {};
	hrtf_settings.type = IPL_HRTFTYPE_DEFAULT;
	hrtf_settings.volume = 1.0f;
	hrtf_settings.normType = IPL_HRTFNORMTYPE_NONE;
	if (iplHRTFCreate(context_, &audio_, &hrtf_settings, &hrtf_) != IPL_STATUS_SUCCESS) {
		godot::UtilityFunctions::push_error("[OpenDou/SteamAudio] no se pudo crear el HRTF por defecto");
		hrtf_ = nullptr;
		return false;
	}
	return true;
}

void SteamAudioContext::shutdown() {
	if (hrtf_ != nullptr) {
		iplHRTFRelease(&hrtf_);
		hrtf_ = nullptr;
	}
	if (context_ != nullptr) {
		iplContextRelease(&context_);
		context_ = nullptr;
	}
}

} // namespace opendou
