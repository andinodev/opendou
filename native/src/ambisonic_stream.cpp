#include "ambisonic_stream.h"
#include "steam_audio_context.h"

#include <godot_cpp/classes/audio_server.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <algorithm>
#include <cstring>

using namespace godot;

namespace opendou {

void OpenDouAmbisonicStream::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_audio", "audio"), &OpenDouAmbisonicStream::set_audio);
	ClassDB::bind_method(D_METHOD("get_audio"), &OpenDouAmbisonicStream::get_audio);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "audio", PROPERTY_HINT_RESOURCE_TYPE, "Resource"), "set_audio", "get_audio");
	ClassDB::bind_method(D_METHOD("set_listener_basis", "basis"), &OpenDouAmbisonicStream::set_listener_basis);
	ClassDB::bind_method(D_METHOD("get_listener_basis"), &OpenDouAmbisonicStream::get_listener_basis);
	ADD_PROPERTY(PropertyInfo(Variant::BASIS, "listener_basis"), "set_listener_basis", "get_listener_basis");
	ClassDB::bind_method(D_METHOD("set_binaural", "on"), &OpenDouAmbisonicStream::set_binaural);
	ClassDB::bind_method(D_METHOD("is_binaural"), &OpenDouAmbisonicStream::is_binaural);
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "binaural"), "set_binaural", "is_binaural");
	ClassDB::bind_static_method("OpenDouAmbisonicStream", D_METHOD("encode_mono", "samples", "direction", "order"), &OpenDouAmbisonicStream::encode_mono);
}

void OpenDouAmbisonicStream::set_audio(const Ref<Resource> &p_audio) { audio_ = p_audio; }

void OpenDouAmbisonicStream::set_listener_basis(const Basis &b) {
	for (int c = 0; c < 3; c++) {
		for (int r = 0; r < 3; r++) {
			basis_[c * 3 + r].store(b[c][r]);
		}
	}
}

Basis OpenDouAmbisonicStream::get_listener_basis() const {
	Basis b;
	for (int c = 0; c < 3; c++) {
		for (int r = 0; r < 3; r++) {
			b[c][r] = basis_[c * 3 + r].load();
		}
	}
	return b;
}

double OpenDouAmbisonicStream::_get_length() const {
	if (audio_.is_null()) {
		return 0.0;
	}
	Array channels = audio_->get("channels");
	const double rate = static_cast<double>(audio_->get("mix_rate"));
	if (channels.size() == 0 || rate <= 0.0) {
		return 0.0;
	}
	PackedFloat32Array w = channels[0];
	return static_cast<double>(w.size()) / rate;
}

Ref<AudioStreamPlayback> OpenDouAmbisonicStream::_instantiate_playback() const {
	Ref<OpenDouAmbisonicStreamPlayback> pb;
	pb.instantiate();
	pb->setup(Ref<OpenDouAmbisonicStream>(this));
	return pb;
}

Array OpenDouAmbisonicStream::encode_mono(const PackedFloat32Array &samples, const Vector3 &direction, int order) {
	Array out;
	const int rate = static_cast<int>(AudioServer::get_singleton()->get_mix_rate());
	if (!SteamAudioContext::ensure(rate) || order < 1 || order > 2) {
		return out;
	}
	IPLContext ctx = SteamAudioContext::context();
	IPLAudioSettings audio = SteamAudioContext::audio_settings();
	IPLAmbisonicsEncodeEffectSettings es = {};
	es.maxOrder = order;
	IPLAmbisonicsEncodeEffect enc = nullptr;
	if (iplAmbisonicsEncodeEffectCreate(ctx, &audio, &es, &enc) != IPL_STATUS_SUCCESS) {
		return out;
	}
	const int n = (order + 1) * (order + 1);
	IPLAudioBuffer in = {}, amb = {};
	iplAudioBufferAllocate(ctx, 1, audio.frameSize, &in);
	iplAudioBufferAllocate(ctx, n, audio.frameSize, &amb);
	std::vector<std::vector<float>> chans(n, std::vector<float>(samples.size(), 0.0f));
	IPLAmbisonicsEncodeEffectParams p = {};
	p.direction = IPLVector3{ direction.x, direction.y, direction.z };
	p.order = order;
	for (int64_t off = 0; off < samples.size(); off += audio.frameSize) {
		for (int k = 0; k < audio.frameSize; k++) {
			in.data[0][k] = (off + k < samples.size()) ? samples[off + k] : 0.0f;
		}
		iplAmbisonicsEncodeEffectApply(enc, &p, &in, &amb);
		for (int c = 0; c < n; c++) {
			for (int k = 0; k < audio.frameSize && off + k < samples.size(); k++) {
				chans[c][off + k] = amb.data[c][k];
			}
		}
	}
	iplAudioBufferFree(ctx, &in);
	iplAudioBufferFree(ctx, &amb);
	iplAmbisonicsEncodeEffectRelease(&enc);
	for (int c = 0; c < n; c++) {
		PackedFloat32Array pf;
		pf.resize(samples.size());
		std::memcpy(pf.ptrw(), chans[c].data(), sizeof(float) * samples.size());
		out.push_back(pf);
	}
	return out;
}

// ---------------------------------------------------------- playback

OpenDouAmbisonicStreamPlayback::~OpenDouAmbisonicStreamPlayback() { release_effects(); }

void OpenDouAmbisonicStreamPlayback::setup(const Ref<OpenDouAmbisonicStream> &p_stream) { stream_ = p_stream; }

bool OpenDouAmbisonicStreamPlayback::load_channels() {
	channels_.clear();
	if (stream_.is_null() || stream_->audio_.is_null()) {
		return false;
	}
	Array channels = stream_->audio_->get("channels");
	order_ = static_cast<int>(stream_->audio_->get("order"));
	loop_ = static_cast<bool>(stream_->audio_->get("loop"));
	order_ = std::clamp(order_, 1, 2);
	num_channels_ = (order_ + 1) * (order_ + 1);
	if (channels.size() < num_channels_) {
		return false;
	}
	for (int c = 0; c < num_channels_; c++) {
		PackedFloat32Array pf = channels[c];
		channels_.emplace_back(pf.ptr(), pf.ptr() + pf.size());
	}
	return !channels_.empty() && !channels_[0].empty();
}

bool OpenDouAmbisonicStreamPlayback::create_effects() {
	release_effects();
	const int rate = static_cast<int>(AudioServer::get_singleton()->get_mix_rate());
	if (!SteamAudioContext::ensure(rate)) {
		return false;
	}
	IPLContext ctx = SteamAudioContext::context();
	IPLAudioSettings audio = SteamAudioContext::audio_settings();
	frame_size_ = audio.frameSize;
	IPLAmbisonicsRotationEffectSettings rs = {};
	rs.maxOrder = order_;
	if (iplAmbisonicsRotationEffectCreate(ctx, &audio, &rs, &rotation_) != IPL_STATUS_SUCCESS) {
		rotation_ = nullptr;
		return false;
	}
	IPLAmbisonicsDecodeEffectSettings ds = {};
	ds.speakerLayout.type = IPL_SPEAKERLAYOUTTYPE_STEREO;
	ds.maxOrder = order_;
	SteamAudioContext::HrtfSlot *slot = SteamAudioContext::acquire_hrtf();
	ds.hrtf = slot != nullptr ? slot->hrtf : nullptr;
	const IPLerror e = iplAmbisonicsDecodeEffectCreate(ctx, &audio, &ds, &decode_);
	SteamAudioContext::release_hrtf(slot);
	if (e != IPL_STATUS_SUCCESS) {
		decode_ = nullptr;
		release_effects();
		return false;
	}
	if (iplAudioBufferAllocate(ctx, num_channels_, frame_size_, &in_) != IPL_STATUS_SUCCESS || iplAudioBufferAllocate(ctx, num_channels_, frame_size_, &rot_) != IPL_STATUS_SUCCESS || iplAudioBufferAllocate(ctx, 2, frame_size_, &out_) != IPL_STATUS_SUCCESS) {
		release_effects();
		return false;
	}
	ring_.assign(frame_size_ * 4, AudioFrame{ 0.0f, 0.0f });
	ring_read_ = 0;
	ring_available_ = 0;
	return true;
}

void OpenDouAmbisonicStreamPlayback::release_effects() {
	IPLContext ctx = SteamAudioContext::context();
	if (rotation_ != nullptr) {
		iplAmbisonicsRotationEffectRelease(&rotation_);
		rotation_ = nullptr;
	}
	if (decode_ != nullptr) {
		iplAmbisonicsDecodeEffectRelease(&decode_);
		decode_ = nullptr;
	}
	if (ctx != nullptr) {
		if (in_.data != nullptr) {
			iplAudioBufferFree(ctx, &in_);
		}
		if (rot_.data != nullptr) {
			iplAudioBufferFree(ctx, &rot_);
		}
		if (out_.data != nullptr) {
			iplAudioBufferFree(ctx, &out_);
		}
	}
	in_ = {};
	rot_ = {};
	out_ = {};
}

void OpenDouAmbisonicStreamPlayback::_start(double p_from_pos) {
	if (!load_channels() || !create_effects()) {
		active_ = false;
		return;
	}
	const double rate = static_cast<double>(stream_->audio_->get("mix_rate"));
	position_ = static_cast<size_t>(std::max(0.0, p_from_pos) * (rate > 0.0 ? rate : 44100.0));
	loops_ = 0;
	active_ = true;
}

void OpenDouAmbisonicStreamPlayback::_stop() {
	active_ = false;
	ring_available_ = 0;
	ring_read_ = 0;
}

double OpenDouAmbisonicStreamPlayback::_get_playback_position() const {
	if (stream_.is_null() || stream_->audio_.is_null()) {
		return 0.0;
	}
	const double rate = static_cast<double>(stream_->audio_->get("mix_rate"));
	return rate > 0.0 ? static_cast<double>(position_) / rate : 0.0;
}

void OpenDouAmbisonicStreamPlayback::_seek(double p_time) {
	if (stream_.is_null() || stream_->audio_.is_null()) {
		return;
	}
	const double rate = static_cast<double>(stream_->audio_->get("mix_rate"));
	position_ = static_cast<size_t>(std::max(0.0, p_time) * (rate > 0.0 ? rate : 44100.0));
}

bool OpenDouAmbisonicStreamPlayback::render_block() {
	if (channels_.empty()) {
		return false;
	}
	const size_t len = channels_[0].size();
	bool any = false;
	for (int k = 0; k < frame_size_; k++) {
		size_t idx = position_ + k;
		if (idx >= len) {
			if (!loop_) {
				for (int c = 0; c < num_channels_; c++) {
					in_.data[c][k] = 0.0f;
				}
				continue;
			}
			idx %= len;
		}
		any = true;
		for (int c = 0; c < num_channels_; c++) {
			in_.data[c][k] = channels_[c][idx];
		}
	}
	if (!any) {
		active_ = false;
		return false;
	}
	position_ += frame_size_;
	if (loop_ && position_ >= len) {
		position_ %= len;
		loops_++;
	}
	// Rotacion: el campo gira al reves que la cabeza. La orientacion es el espacio del oyente.
	// Basis[i] en godot-cpp es la FILA i; los ejes del oyente son las columnas.
	const Basis b = stream_->get_listener_basis();
	const Vector3 right = b.get_column(0);
	const Vector3 up = b.get_column(1);
	const Vector3 ahead = -b.get_column(2);
	IPLAmbisonicsRotationEffectParams rp = {};
	rp.order = order_;
	rp.orientation.right = IPLVector3{ right.x, right.y, right.z };
	rp.orientation.up = IPLVector3{ up.x, up.y, up.z };
	rp.orientation.ahead = IPLVector3{ ahead.x, ahead.y, ahead.z };
	rp.orientation.origin = IPLVector3{ 0, 0, 0 };
	iplAmbisonicsRotationEffectApply(rotation_, &rp, &in_, &rot_);
	IPLAmbisonicsDecodeEffectParams dp = {};
	dp.order = order_;
	SteamAudioContext::HrtfSlot *slot = SteamAudioContext::acquire_hrtf();
	dp.hrtf = slot != nullptr ? slot->hrtf : nullptr;
	dp.orientation.right = IPLVector3{ 1, 0, 0 };
	dp.orientation.up = IPLVector3{ 0, 1, 0 };
	dp.orientation.ahead = IPLVector3{ 0, 0, -1 };
	dp.binaural = stream_->is_binaural() ? IPL_TRUE : IPL_FALSE;
	iplAmbisonicsDecodeEffectApply(decode_, &dp, &rot_, &out_);
	SteamAudioContext::release_hrtf(slot);
	const size_t cap = ring_.size();
	for (int k = 0; k < frame_size_ && ring_available_ < cap; k++) {
		ring_[(ring_read_ + ring_available_) % cap] = AudioFrame{ out_.data[0][k], out_.data[1][k] };
		ring_available_++;
	}
	return true;
}

int32_t OpenDouAmbisonicStreamPlayback::_mix(AudioFrame *p_buffer, float p_rate_scale, int32_t p_frames) {
	int32_t written = 0;
	if (active_) {
		while (written < p_frames) {
			if (ring_available_ == 0 && !render_block()) {
				break;
			}
			const size_t cap = ring_.size();
			while (written < p_frames && ring_available_ > 0) {
				p_buffer[written++] = ring_[ring_read_];
				ring_read_ = (ring_read_ + 1) % cap;
				ring_available_--;
			}
		}
	}
	for (int32_t i = written; i < p_frames; i++) {
		p_buffer[i] = AudioFrame{ 0.0f, 0.0f };
	}
	return p_frames;
}

} // namespace opendou
