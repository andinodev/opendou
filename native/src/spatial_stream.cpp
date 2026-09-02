#include "spatial_stream.h"
#include "steam_audio_context.h"
#include <phonon_version.h>

#include <godot_cpp/classes/audio_server.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <algorithm>
#include <cstring>

using namespace godot;

namespace opendou {

// ------------------------------------------------------------------ OpenDouSpatialStream

OpenDouSpatialStream::OpenDouSpatialStream() {}

void OpenDouSpatialStream::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_source", "source"), &OpenDouSpatialStream::set_source);
	ClassDB::bind_method(D_METHOD("get_source"), &OpenDouSpatialStream::get_source);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "source", PROPERTY_HINT_RESOURCE_TYPE, "AudioStream"), "set_source", "get_source");

	ClassDB::bind_method(D_METHOD("set_direction", "direction"), &OpenDouSpatialStream::set_direction);
	ClassDB::bind_method(D_METHOD("get_direction"), &OpenDouSpatialStream::get_direction);
	ADD_PROPERTY(PropertyInfo(Variant::VECTOR3, "direction"), "set_direction", "get_direction");

	ClassDB::bind_method(D_METHOD("set_spatial_blend", "blend"), &OpenDouSpatialStream::set_spatial_blend);
	ClassDB::bind_method(D_METHOD("get_spatial_blend"), &OpenDouSpatialStream::get_spatial_blend);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "spatial_blend", PROPERTY_HINT_RANGE, "0,1,0.01"), "set_spatial_blend", "get_spatial_blend");

	ClassDB::bind_method(D_METHOD("set_spatialize", "enabled"), &OpenDouSpatialStream::set_spatialize);
	ClassDB::bind_method(D_METHOD("is_spatialize"), &OpenDouSpatialStream::is_spatialize);
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "spatialize"), "set_spatialize", "is_spatialize");

	ClassDB::bind_method(D_METHOD("get_last_peak_delays"), &OpenDouSpatialStream::get_last_peak_delays);

	ClassDB::bind_static_method("OpenDouSpatialStream", D_METHOD("is_native_available"), &OpenDouSpatialStream::is_native_available);
	ClassDB::bind_static_method("OpenDouSpatialStream", D_METHOD("get_frame_size"), &OpenDouSpatialStream::get_frame_size);
	ClassDB::bind_static_method("OpenDouSpatialStream", D_METHOD("get_steam_audio_version"), &OpenDouSpatialStream::get_steam_audio_version);
}

void OpenDouSpatialStream::set_source(const Ref<AudioStream> &p_source) { source_ = p_source; }
Ref<AudioStream> OpenDouSpatialStream::get_source() const { return source_; }

void OpenDouSpatialStream::set_direction(const Vector3 &p_direction) {
	Vector3 d = p_direction;
	if (d.length_squared() > 0.000001f) {
		d = d.normalized();
	} else {
		d = Vector3(0, 0, -1);
	}
	dir_x_.store(d.x);
	dir_y_.store(d.y);
	dir_z_.store(d.z);
}
Vector3 OpenDouSpatialStream::get_direction() const { return Vector3(dir_x_.load(), dir_y_.load(), dir_z_.load()); }

void OpenDouSpatialStream::set_spatial_blend(float p_blend) { spatial_blend_.store(std::clamp(p_blend, 0.0f, 1.0f)); }
float OpenDouSpatialStream::get_spatial_blend() const { return spatial_blend_.load(); }

void OpenDouSpatialStream::set_spatialize(bool p_enabled) { spatialize_.store(p_enabled); }
bool OpenDouSpatialStream::is_spatialize() const { return spatialize_.load(); }

Vector2 OpenDouSpatialStream::get_last_peak_delays() const { return Vector2(peak_left_.load(), peak_right_.load()); }

bool OpenDouSpatialStream::is_native_available() {
	const int rate = static_cast<int>(AudioServer::get_singleton()->get_mix_rate());
	return SteamAudioContext::ensure(rate, 512);
}
int OpenDouSpatialStream::get_frame_size() { return SteamAudioContext::audio_settings().frameSize; }
String OpenDouSpatialStream::get_steam_audio_version() {
	return vformat("%d.%d.%d", STEAMAUDIO_VERSION_MAJOR, STEAMAUDIO_VERSION_MINOR, STEAMAUDIO_VERSION_PATCH);
}

Ref<AudioStreamPlayback> OpenDouSpatialStream::_instantiate_playback() const {
	Ref<OpenDouSpatialStreamPlayback> playback;
	playback.instantiate();
	playback->setup(Ref<OpenDouSpatialStream>(this));
	return playback;
}
String OpenDouSpatialStream::_get_stream_name() const { return "OpenDouSpatialStream"; }
double OpenDouSpatialStream::_get_length() const { return source_.is_valid() ? source_->get_length() : 0.0; }
bool OpenDouSpatialStream::_is_monophonic() const { return false; }

// ---------------------------------------------------------- OpenDouSpatialStreamPlayback

OpenDouSpatialStreamPlayback::OpenDouSpatialStreamPlayback() {}
OpenDouSpatialStreamPlayback::~OpenDouSpatialStreamPlayback() { release_effect(); }

void OpenDouSpatialStreamPlayback::setup(const Ref<OpenDouSpatialStream> &p_stream) {
	stream_ = p_stream;
	if (stream_.is_valid() && stream_->source_.is_valid()) {
		inner_ = stream_->source_->instantiate_playback();
	}
}

bool OpenDouSpatialStreamPlayback::create_effect() {
	const int rate = static_cast<int>(AudioServer::get_singleton()->get_mix_rate());
	if (!SteamAudioContext::ensure(rate, 512)) {
		return false;
	}
	IPLContext ctx = SteamAudioContext::context();
	IPLAudioSettings audio = SteamAudioContext::audio_settings();

	IPLBinauralEffectSettings settings = {};
	settings.hrtf = SteamAudioContext::hrtf();
	if (iplBinauralEffectCreate(ctx, &audio, &settings, &effect_) != IPL_STATUS_SUCCESS) {
		effect_ = nullptr;
		return false;
	}
	if (iplAudioBufferAllocate(ctx, 1, audio.frameSize, &in_buffer_) != IPL_STATUS_SUCCESS) {
		release_effect();
		return false;
	}
	if (iplAudioBufferAllocate(ctx, 2, audio.frameSize, &out_buffer_) != IPL_STATUS_SUCCESS) {
		release_effect();
		return false;
	}
	interleaved_.assign(static_cast<size_t>(audio.frameSize) * 2, 0.0f);
	// El anillo guarda dos bloques: el que se esta sirviendo y el siguiente.
	ring_.assign(static_cast<size_t>(audio.frameSize) * 2, AudioFrame{ 0.0f, 0.0f });
	ring_read_ = 0;
	ring_available_ = 0;
	return true;
}

void OpenDouSpatialStreamPlayback::release_effect() {
	IPLContext ctx = SteamAudioContext::context();
	if (effect_ != nullptr) {
		iplBinauralEffectRelease(&effect_);
		effect_ = nullptr;
	}
	if (ctx != nullptr) {
		if (in_buffer_.data != nullptr) {
			iplAudioBufferFree(ctx, &in_buffer_);
		}
		if (out_buffer_.data != nullptr) {
			iplAudioBufferFree(ctx, &out_buffer_);
		}
	}
	in_buffer_ = {};
	out_buffer_ = {};
}

void OpenDouSpatialStreamPlayback::_start(double p_from_pos) {
	if (inner_.is_null()) {
		return;
	}
	inner_->start(p_from_pos);
	if (effect_ == nullptr && !create_effect()) {
		UtilityFunctions::push_warning("[OpenDou/SteamAudio] sin efecto binaural: este stream hara bypass");
	}
	active_ = true;
}

void OpenDouSpatialStreamPlayback::_stop() {
	active_ = false;
	if (inner_.is_valid()) {
		inner_->stop();
	}
	if (effect_ != nullptr) {
		iplBinauralEffectReset(effect_);
	}
	ring_read_ = 0;
	ring_available_ = 0;
}

bool OpenDouSpatialStreamPlayback::_is_playing() const {
	return active_ && inner_.is_valid() && inner_->is_playing();
}
int32_t OpenDouSpatialStreamPlayback::_get_loop_count() const { return inner_.is_valid() ? inner_->get_loop_count() : 0; }
double OpenDouSpatialStreamPlayback::_get_playback_position() const { return inner_.is_valid() ? inner_->get_playback_position() : 0.0; }
void OpenDouSpatialStreamPlayback::_seek(double p_position) {
	if (inner_.is_valid()) {
		inner_->seek(p_position);
	}
}

bool OpenDouSpatialStreamPlayback::render_block(float p_rate_scale) {
	const int frame_size = SteamAudioContext::audio_settings().frameSize;
	// mix_audio devuelve un PackedVector2Array: reserva memoria en el hilo de audio. Para el
	// spike vale; en la 7B se busca un camino sin reservas por bloque.
	PackedVector2Array src = inner_->mix_audio(p_rate_scale, frame_size);
	const int got = static_cast<int>(src.size());
	if (got <= 0) {
		return false;
	}
	const Vector2 *s = src.ptr();
	float *mono = in_buffer_.data[0];
	for (int i = 0; i < frame_size; i++) {
		mono[i] = (i < got) ? 0.5f * (s[i].x + s[i].y) : 0.0f;
	}

	IPLBinauralEffectParams params = {};
	params.direction = IPLVector3{ stream_->dir_x_.load(), stream_->dir_y_.load(), stream_->dir_z_.load() };
	params.interpolation = IPL_HRTFINTERPOLATION_BILINEAR;
	params.spatialBlend = stream_->spatial_blend_.load();
	params.hrtf = SteamAudioContext::hrtf();
	params.peakDelays = peak_delays_;
	iplBinauralEffectApply(effect_, &params, &in_buffer_, &out_buffer_);
	stream_->peak_left_.store(peak_delays_[0]);
	stream_->peak_right_.store(peak_delays_[1]);

	iplAudioBufferInterleave(SteamAudioContext::context(), &out_buffer_, interleaved_.data());

	const size_t cap = ring_.size();
	size_t write = (ring_read_ + ring_available_) % cap;
	for (int i = 0; i < frame_size; i++) {
		ring_[write] = AudioFrame{ interleaved_[2 * i], interleaved_[2 * i + 1] };
		write = (write + 1) % cap;
	}
	ring_available_ += static_cast<size_t>(frame_size);
	return true;
}

int32_t OpenDouSpatialStreamPlayback::_mix(AudioFrame *p_buffer, float p_rate_scale, int32_t p_frames) {
	if (!active_ || inner_.is_null()) {
		for (int i = 0; i < p_frames; i++) {
			p_buffer[i] = AudioFrame{ 0.0f, 0.0f };
		}
		return p_frames;
	}

	// Bypass: sin efecto, o con el interruptor apagado. Es el camino del test de control y
	// el del fallback cuando Steam Audio no esta.
	if (effect_ == nullptr || !stream_->spatialize_.load()) {
		PackedVector2Array src = inner_->mix_audio(p_rate_scale, p_frames);
		const int got = static_cast<int>(src.size());
		const Vector2 *s = src.ptr();
		for (int i = 0; i < p_frames; i++) {
			p_buffer[i] = (i < got) ? AudioFrame{ s[i].x, s[i].y } : AudioFrame{ 0.0f, 0.0f };
		}
		return p_frames;
	}

	int32_t written = 0;
	while (written < p_frames) {
		if (ring_available_ == 0 && !render_block(p_rate_scale)) {
			break;
		}
		const size_t cap = ring_.size();
		while (written < p_frames && ring_available_ > 0) {
			p_buffer[written++] = ring_[ring_read_];
			ring_read_ = (ring_read_ + 1) % cap;
			ring_available_--;
		}
	}
	for (int i = written; i < p_frames; i++) {
		p_buffer[i] = AudioFrame{ 0.0f, 0.0f };
	}
	return p_frames;
}

} // namespace opendou
