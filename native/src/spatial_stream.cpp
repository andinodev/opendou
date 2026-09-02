#include "spatial_stream.h"
#include "steam_audio_context.h"
#include <phonon_version.h>

#include <godot_cpp/classes/audio_server.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <algorithm>
#include <cmath>
#include <cstring>

using namespace godot;

namespace opendou {

// ------------------------------------------------------------------ OpenDouSpatialStream

float OpenDouSpatialStream::max_propagation_delay_sec_ = 3.0f;

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

	ClassDB::bind_method(D_METHOD("set_distance_gain", "gain"), &OpenDouSpatialStream::set_distance_gain);
	ClassDB::bind_method(D_METHOD("get_distance_gain"), &OpenDouSpatialStream::get_distance_gain);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "distance_gain", PROPERTY_HINT_RANGE, "0,2,0.001"), "set_distance_gain", "get_distance_gain");

	ClassDB::bind_method(D_METHOD("set_cutoff_hz", "hz"), &OpenDouSpatialStream::set_cutoff_hz);
	ClassDB::bind_method(D_METHOD("get_cutoff_hz"), &OpenDouSpatialStream::get_cutoff_hz);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "cutoff_hz", PROPERTY_HINT_RANGE, "20,20000,1"), "set_cutoff_hz", "get_cutoff_hz");

	ClassDB::bind_method(D_METHOD("set_shelf_db", "db"), &OpenDouSpatialStream::set_shelf_db);
	ClassDB::bind_method(D_METHOD("get_shelf_db"), &OpenDouSpatialStream::get_shelf_db);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "shelf_db", PROPERTY_HINT_RANGE, "-80,0,0.1"), "set_shelf_db", "get_shelf_db");

	ClassDB::bind_method(D_METHOD("set_shelf_cutoff_hz", "hz"), &OpenDouSpatialStream::set_shelf_cutoff_hz);
	ClassDB::bind_method(D_METHOD("get_shelf_cutoff_hz"), &OpenDouSpatialStream::get_shelf_cutoff_hz);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "shelf_cutoff_hz", PROPERTY_HINT_RANGE, "100,20000,1"), "set_shelf_cutoff_hz", "get_shelf_cutoff_hz");

	ClassDB::bind_method(D_METHOD("set_output_mode", "mode"), &OpenDouSpatialStream::set_output_mode);
	ClassDB::bind_method(D_METHOD("get_output_mode"), &OpenDouSpatialStream::get_output_mode);
	ADD_PROPERTY(PropertyInfo(Variant::INT, "output_mode", PROPERTY_HINT_ENUM, "Headphones,Speakers"), "set_output_mode", "get_output_mode");
	ClassDB::bind_method(D_METHOD("set_near_field_bass_db", "db"), &OpenDouSpatialStream::set_near_field_bass_db);
	ClassDB::bind_method(D_METHOD("get_near_field_bass_db"), &OpenDouSpatialStream::get_near_field_bass_db);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "near_field_bass_db", PROPERTY_HINT_RANGE, "0,12,0.1"), "set_near_field_bass_db", "get_near_field_bass_db");
	ClassDB::bind_method(D_METHOD("set_near_field_ild_db", "db"), &OpenDouSpatialStream::set_near_field_ild_db);
	ClassDB::bind_method(D_METHOD("get_near_field_ild_db"), &OpenDouSpatialStream::get_near_field_ild_db);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "near_field_ild_db", PROPERTY_HINT_RANGE, "0,12,0.1"), "set_near_field_ild_db", "get_near_field_ild_db");
	ClassDB::bind_method(D_METHOD("set_propagation_delay_sec", "sec"), &OpenDouSpatialStream::set_propagation_delay_sec);
	ClassDB::bind_method(D_METHOD("get_propagation_delay_sec"), &OpenDouSpatialStream::get_propagation_delay_sec);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "propagation_delay_sec", PROPERTY_HINT_RANGE, "0,10,0.001"), "set_propagation_delay_sec", "get_propagation_delay_sec");
	ClassDB::bind_static_method("OpenDouSpatialStream", D_METHOD("configure_max_propagation_delay", "sec"), &OpenDouSpatialStream::configure_max_propagation_delay);
	BIND_ENUM_CONSTANT(OUTPUT_HEADPHONES);
	BIND_ENUM_CONSTANT(OUTPUT_SPEAKERS);

	ClassDB::bind_method(D_METHOD("get_last_peak_delays"), &OpenDouSpatialStream::get_last_peak_delays);
	ClassDB::bind_method(D_METHOD("get_last_applied_itd_ms"), &OpenDouSpatialStream::get_last_applied_itd_ms);

	ClassDB::bind_static_method("OpenDouSpatialStream", D_METHOD("is_native_available"), &OpenDouSpatialStream::is_native_available);
	ClassDB::bind_static_method("OpenDouSpatialStream", D_METHOD("get_frame_size"), &OpenDouSpatialStream::get_frame_size);
	ClassDB::bind_static_method("OpenDouSpatialStream", D_METHOD("get_steam_audio_version"), &OpenDouSpatialStream::get_steam_audio_version);
	ClassDB::bind_static_method("OpenDouSpatialStream", D_METHOD("configure", "frame_size"), &OpenDouSpatialStream::configure);
	ClassDB::bind_static_method("OpenDouSpatialStream", D_METHOD("set_hrtf_default"), &OpenDouSpatialStream::set_hrtf_default);
	ClassDB::bind_static_method("OpenDouSpatialStream", D_METHOD("set_hrtf_sofa", "path"), &OpenDouSpatialStream::set_hrtf_sofa);
	ClassDB::bind_static_method("OpenDouSpatialStream", D_METHOD("get_hrtf_name"), &OpenDouSpatialStream::get_hrtf_name);
	ClassDB::bind_static_method("OpenDouSpatialStream", D_METHOD("get_hrtf_generation"), &OpenDouSpatialStream::get_hrtf_generation);
	ClassDB::bind_static_method("OpenDouSpatialStream", D_METHOD("benchmark_block", "voices"), &OpenDouSpatialStream::benchmark_block);
	ClassDB::bind_static_method("OpenDouSpatialStream", D_METHOD("benchmark_block_mode", "voices", "mode"), &OpenDouSpatialStream::benchmark_block_mode);
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

void OpenDouSpatialStream::set_distance_gain(float p_gain) { distance_gain_.store(std::clamp(p_gain, 0.0f, 2.0f)); }
float OpenDouSpatialStream::get_distance_gain() const { return distance_gain_.load(); }
void OpenDouSpatialStream::set_cutoff_hz(float p_hz) { cutoff_hz_.store(std::clamp(p_hz, 20.0f, 20000.0f)); }
float OpenDouSpatialStream::get_cutoff_hz() const { return cutoff_hz_.load(); }
void OpenDouSpatialStream::set_shelf_db(float p_db) { shelf_db_.store(std::clamp(p_db, -80.0f, 0.0f)); }
float OpenDouSpatialStream::get_shelf_db() const { return shelf_db_.load(); }
void OpenDouSpatialStream::set_shelf_cutoff_hz(float p_hz) { shelf_cutoff_hz_.store(std::clamp(p_hz, 100.0f, 20000.0f)); }
float OpenDouSpatialStream::get_shelf_cutoff_hz() const { return shelf_cutoff_hz_.load(); }
void OpenDouSpatialStream::set_output_mode(int p_mode) { output_mode_.store(p_mode == OUTPUT_SPEAKERS ? OUTPUT_SPEAKERS : OUTPUT_HEADPHONES); }
int OpenDouSpatialStream::get_output_mode() const { return output_mode_.load(); }
void OpenDouSpatialStream::set_near_field_bass_db(float p_db) { near_field_bass_db_.store(std::clamp(p_db, 0.0f, 12.0f)); }
float OpenDouSpatialStream::get_near_field_bass_db() const { return near_field_bass_db_.load(); }
void OpenDouSpatialStream::set_near_field_ild_db(float p_db) { near_field_ild_db_.store(std::clamp(p_db, 0.0f, 12.0f)); }
float OpenDouSpatialStream::get_near_field_ild_db() const { return near_field_ild_db_.load(); }
void OpenDouSpatialStream::set_propagation_delay_sec(float p_sec) { propagation_delay_.store(std::clamp(p_sec, 0.0f, max_propagation_delay_sec_)); }
float OpenDouSpatialStream::get_propagation_delay_sec() const { return propagation_delay_.load(); }
bool OpenDouSpatialStream::configure_max_propagation_delay(float p_sec) {
	max_propagation_delay_sec_ = std::clamp(p_sec, 0.1f, 10.0f);
	return true;
}

Vector2 OpenDouSpatialStream::get_last_peak_delays() const { return Vector2(peak_left_.load(), peak_right_.load()); }

bool OpenDouSpatialStream::is_native_available() {
	const int rate = static_cast<int>(AudioServer::get_singleton()->get_mix_rate());
	return SteamAudioContext::ensure(rate);
}
int OpenDouSpatialStream::get_frame_size() { return SteamAudioContext::audio_settings().frameSize; }
String OpenDouSpatialStream::get_steam_audio_version() {
	return vformat("%d.%d.%d", STEAMAUDIO_VERSION_MAJOR, STEAMAUDIO_VERSION_MINOR, STEAMAUDIO_VERSION_PATCH);
}

bool OpenDouSpatialStream::configure(int frame_size) { return SteamAudioContext::configure_frame_size(frame_size); }
bool OpenDouSpatialStream::set_hrtf_default() { return SteamAudioContext::set_hrtf_default(); }
bool OpenDouSpatialStream::set_hrtf_sofa(const String &path) {
	const String global = ProjectSettings::get_singleton()->globalize_path(path);
	if (!FileAccess::file_exists(global)) {
		UtilityFunctions::push_error("[OpenDou/SteamAudio] SOFA no encontrado: ", global);
		return false;
	}
	return SteamAudioContext::set_hrtf_sofa(std::string(global.utf8().get_data()));
}
String OpenDouSpatialStream::get_hrtf_name() { return String(SteamAudioContext::hrtf_name().c_str()); }
int OpenDouSpatialStream::get_hrtf_generation() { return SteamAudioContext::generation(); }

float OpenDouSpatialStream::benchmark_block(int voices) { return benchmark_block_mode(voices, 0); }

float OpenDouSpatialStream::benchmark_block_mode(int voices, int mode) {
	const int rate = static_cast<int>(AudioServer::get_singleton()->get_mix_rate());
	if (voices <= 0 || !SteamAudioContext::ensure(rate)) {
		return 0.0f;
	}
	IPLAudioSettings audio = SteamAudioContext::audio_settings();
	IPLContext ctx = SteamAudioContext::context();
	SteamAudioContext::HrtfSlot *slot = SteamAudioContext::acquire_hrtf();
	IPLBinauralEffectSettings settings = {};
	settings.hrtf = slot->hrtf;
	IPLBinauralEffect effect = nullptr;
	IPLAudioBuffer in = {}, out = {};
	if (iplBinauralEffectCreate(ctx, &audio, &settings, &effect) != IPL_STATUS_SUCCESS) {
		SteamAudioContext::release_hrtf(slot);
		return 0.0f;
	}
	iplAudioBufferAllocate(ctx, 1, audio.frameSize, &in);
	iplAudioBufferAllocate(ctx, 2, audio.frameSize, &out);
	const float fs = static_cast<float>(audio.samplingRate);
	dsp::Biquad lpf, shelf;
	lpf.set_lowpass(fs, 8000.0f, 0.7071f);
	shelf.set_highshelf_godot(fs, 5000.0f, 0.25f);
	dsp::FractionalDelay dl, dr;
	dl.init(static_cast<int>(0.002f * fs) + 2);
	dr.init(static_cast<int>(0.002f * fs) + 2);
	std::vector<float> inter(static_cast<size_t>(audio.frameSize) * 2);
	float peaks[2] = { 0.0f, 0.0f };
	const uint64_t t0 = Time::get_singleton()->get_ticks_usec();
	const bool do_filters = (mode == 0 || mode == 3);
	const bool do_hrtf = (mode == 0 || mode == 1 || mode == 2);
	for (int v = 0; v < voices; v++) {
		for (int i = 0; i < audio.frameSize; i++) {
			float x = std::sin(0.01f * i * (v + 1));
			if (do_filters) {
				x = shelf.process(lpf.process(x));
			}
			in.data[0][i] = x;
		}
		if (do_hrtf) {
			IPLBinauralEffectParams params = {};
			params.direction = IPLVector3{ 0.7f, 0.0f, -0.7f };
			params.interpolation = (mode == 2) ? IPL_HRTFINTERPOLATION_NEAREST : IPL_HRTFINTERPOLATION_BILINEAR;
			params.spatialBlend = 1.0f;
			params.hrtf = slot->hrtf;
			params.peakDelays = peaks;
			iplBinauralEffectApply(effect, &params, &in, &out);
			iplAudioBufferInterleave(ctx, &out, inter.data());
		} else {
			for (int i = 0; i < audio.frameSize; i++) {
				inter[2 * i] = inter[2 * i + 1] = in.data[0][i];
			}
		}
		if (do_filters) {
			dl.set_target(20.0f, audio.frameSize);
			for (int i = 0; i < audio.frameSize; i++) {
				inter[2 * i] = dl.process(inter[2 * i]);
				inter[2 * i + 1] = dr.process(inter[2 * i + 1]);
			}
		}
	}
	const uint64_t t1 = Time::get_singleton()->get_ticks_usec();
	iplAudioBufferFree(ctx, &in);
	iplAudioBufferFree(ctx, &out);
	iplBinauralEffectRelease(&effect);
	SteamAudioContext::release_hrtf(slot);
	return static_cast<float>(t1 - t0) / static_cast<float>(voices);
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
	if (!SteamAudioContext::ensure(rate)) {
		return false;
	}
	IPLContext ctx = SteamAudioContext::context();
	IPLAudioSettings audio = SteamAudioContext::audio_settings();

	IPLBinauralEffectSettings settings = {};
	SteamAudioContext::HrtfSlot *slot = SteamAudioContext::acquire_hrtf();
	settings.hrtf = slot != nullptr ? slot->hrtf : nullptr;
	const IPLerror created = iplBinauralEffectCreate(ctx, &audio, &settings, &effect_);
	SteamAudioContext::release_hrtf(slot);
	if (created != IPL_STATUS_SUCCESS) {
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
	lpf_.reset();
	shelf_.reset();
	near_shelf_.reset();
	near_applied_db_ = -1.0f;
	const int max_delay = static_cast<int>(0.002f * audio.samplingRate) + 2;
	delay_l_.init(max_delay);
	delay_r_.init(max_delay);
	lpf_applied_hz_ = -1.0f;
	shelf_applied_db_ = 1.0f;
	shelf_applied_hz_ = -1.0f;
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
	lpf_.reset();
	shelf_.reset();
	near_shelf_.reset();
	prop_delay_.reset();
	prop_snapped_ = false;
	delay_l_.reset();
	delay_r_.reset();
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
	const IPLAudioSettings &audio = SteamAudioContext::audio_settings();
	const int frame_size = audio.frameSize;
	const float fs = static_cast<float>(audio.samplingRate);
	// mix_audio devuelve un PackedVector2Array nuevo: reserva memoria en el hilo de audio. La
	// API de GDExtension no ofrece otro camino para tirar de un stream interno. Documentado
	// en el spec 7B (S3) y medido con benchmark_block.
	PackedVector2Array src = inner_->mix_audio(p_rate_scale, frame_size);
	const int got = static_cast<int>(src.size());
	if (got <= 0) {
		return false;
	}
	const Vector2 *s = src.ptr();

	// 1. Filtros: se recalculan solo si el parametro cambio de verdad (mas de 1 %).
	const float cutoff = stream_->cutoff_hz_.load();
	if (std::fabs(cutoff - lpf_applied_hz_) > 0.01f * std::max(cutoff, 1.0f)) {
		lpf_.set_lowpass(fs, cutoff, 0.70710678f);
		lpf_applied_hz_ = cutoff;
	}
	const float shelf_db = stream_->shelf_db_.load();
	const float shelf_hz = stream_->shelf_cutoff_hz_.load();
	if (std::fabs(shelf_db - shelf_applied_db_) > 0.05f || std::fabs(shelf_hz - shelf_applied_hz_) > 0.01f * shelf_hz) {
		if (shelf_db > -0.05f) {
			shelf_.set_identity();
		} else {
			shelf_.set_highshelf_godot(fs, shelf_hz, std::pow(10.0f, shelf_db / 20.0f));
		}
		shelf_applied_db_ = shelf_db;
		shelf_applied_hz_ = shelf_hz;
	}
	const bool lpf_active = cutoff < 19000.0f;

	// 2. Mono + ganancia + filtros.
	const float gain = stream_->distance_gain_.load();
	float *mono = in_buffer_.data[0];
	for (int i = 0; i < frame_size; i++) {
		float x = (i < got) ? 0.5f * (s[i].x + s[i].y) * gain : 0.0f;
		if (lpf_active) {
			x = lpf_.process(x);
		}
		x = shelf_.process(x);
		mono[i] = x;
	}

	// Retardo por distancia, en mono y antes del HRTF. La linea se reserva la primera vez que
	// la voz lo pide (530 KB por voz a 3 s y 44.1 kHz); el primer valor se fija de golpe y
	// los siguientes se rampean: eso ES el doppler fisico.
	const float prop = stream_->propagation_delay_.load();
	if (prop > 0.0f) {
		if (!prop_ready_) {
			prop_delay_.init(static_cast<int>(OpenDouSpatialStream::max_propagation_delay_sec_ * fs) + 4);
			prop_ready_ = true;
			prop_snapped_ = false;
		}
		const float samples = prop * fs;
		if (!prop_snapped_) {
			prop_delay_.snap(samples);
			prop_snapped_ = true;
		} else {
			prop_delay_.set_target(samples, frame_size);
		}
		for (int i = 0; i < frame_size; i++) {
			mono[i] = prop_delay_.process(mono[i]);
		}
	} else {
		prop_snapped_ = false;
	}

	// Campo cercano: refuerzo de graves antes del HRTF.
	const float nf_bass = stream_->near_field_bass_db_.load();
	if (std::fabs(nf_bass - near_applied_db_) > 0.05f) {
		if (nf_bass < 0.05f) {
			near_shelf_.set_identity();
		} else {
			near_shelf_.set_lowshelf(fs, 250.0f, nf_bass);
		}
		near_applied_db_ = nf_bass;
	}
	if (nf_bass >= 0.05f) {
		for (int i = 0; i < frame_size; i++) {
			mono[i] = near_shelf_.process(mono[i]);
		}
	}

	const float dx = stream_->dir_x_.load(), dy = stream_->dir_y_.load(), dz = stream_->dir_z_.load();

	if (stream_->output_mode_.load() == OpenDouSpatialStream::OUTPUT_SPEAKERS) {
		// 3a. Altavoces: paneo de potencia constante, sin HRTF ni ITD. Pasa igualmente por el
		// anillo para que la latencia sea la misma y el conmutador en vivo no salte.
		float gl, gr;
		dsp::constant_power_pan(dx, gl, gr);
		for (int i = 0; i < frame_size; i++) {
			interleaved_[2 * i] = mono[i] * gl;
			interleaved_[2 * i + 1] = mono[i] * gr;
		}
	} else {
		// 3b. Audifonos: HRTF de Steam Audio.
		IPLBinauralEffectParams params = {};
		params.direction = IPLVector3{ dx, dy, dz };
		params.interpolation = IPL_HRTFINTERPOLATION_BILINEAR;
		params.spatialBlend = stream_->spatial_blend_.load();
		// El HRTF puede cambiar en vivo desde el hilo principal: se toma por generacion y se
		// suelta al terminar el bloque, y el viejo se libera cuando nadie lo lee.
		SteamAudioContext::HrtfSlot *slot = SteamAudioContext::acquire_hrtf();
		params.hrtf = slot != nullptr ? slot->hrtf : nullptr;
		params.peakDelays = peak_delays_;
		iplBinauralEffectApply(effect_, &params, &in_buffer_, &out_buffer_);
		SteamAudioContext::release_hrtf(slot);
		stream_->peak_left_.store(peak_delays_[0]);
		stream_->peak_right_.store(peak_delays_[1]);
		iplAudioBufferInterleave(SteamAudioContext::context(), &out_buffer_, interleaved_.data());

		// ITD esferico. La API C de Steam Audio renderiza con fase plana: la salida no lleva
		// retardo interaural, asi que se aplica Woodworth COMPLETO. El spec preveia restar el
		// residuo de peakDelays por si el dataset lo aportaba; medido, no lo aporta: el retardo
		// que sale coincide con el que se aplica, en los dos lados (23 muestras a la derecha con
		// resta de 0.136 ms; 12 a la izquierda con resta de 0.386 ms). Restarlo solo hacia el
		// ITD asimetrico. peak_delays_ se sigue exponiendo como informacion.
		const float blend = params.spatialBlend;
		const float itd = dsp::woodworth_itd_seconds(dx, dy, dz) * blend;
		const float itd_samples = itd * fs;
		// dx > 0: fuente a la derecha, se retrasa el oido IZQUIERDO.
		if (dx >= 0.0f) {
			delay_l_.set_target(itd_samples, frame_size);
			delay_r_.set_target(0.0f, frame_size);
		} else {
			delay_l_.set_target(0.0f, frame_size);
			delay_r_.set_target(itd_samples, frame_size);
		}
		for (int i = 0; i < frame_size; i++) {
			interleaved_[2 * i] = delay_l_.process(interleaved_[2 * i]);
			interleaved_[2 * i + 1] = delay_r_.process(interleaved_[2 * i + 1]);
		}
		stream_->applied_itd_.store(itd);
		// Campo cercano: ILD extra en el oido LEJANO (los HRTF medidos a 1-2 m no la traen).
		const float nf_ild = stream_->near_field_ild_db_.load();
		if (nf_ild > 0.05f) {
			const float g = std::pow(10.0f, -nf_ild / 20.0f);
			const int far = dx >= 0.0f ? 0 : 1;
			for (int i = 0; i < frame_size; i++) {
				interleaved_[2 * i + far] *= g;
			}
		}
	}

	// 4. Al anillo.
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
