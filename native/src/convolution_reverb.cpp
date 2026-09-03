#include "convolution_reverb.h"
#include "simulator.h"
#include "steam_audio_context.h"

#include <godot_cpp/classes/audio_server.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <algorithm>
#include <cstring>
#include <cmath>

using namespace godot;

namespace opendou {

void OpenDouConvolutionReverb::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_dry", "v"), &OpenDouConvolutionReverb::set_dry);
	ClassDB::bind_method(D_METHOD("get_dry"), &OpenDouConvolutionReverb::get_dry);
	ClassDB::bind_method(D_METHOD("set_wet", "v"), &OpenDouConvolutionReverb::set_wet);
	ClassDB::bind_method(D_METHOD("get_wet"), &OpenDouConvolutionReverb::get_wet);
	ClassDB::bind_method(D_METHOD("set_room_handle", "h"), &OpenDouConvolutionReverb::set_room_handle);
	ClassDB::bind_method(D_METHOD("get_room_handle"), &OpenDouConvolutionReverb::get_room_handle);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "dry", PROPERTY_HINT_RANGE, "0,1,0.01"), "set_dry", "get_dry");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "wet", PROPERTY_HINT_RANGE, "0,1,0.01"), "set_wet", "get_wet");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "room_handle"), "set_room_handle", "get_room_handle");
}

Ref<AudioEffectInstance> OpenDouConvolutionReverb::_instantiate() {
	Ref<OpenDouConvolutionReverbInstance> inst;
	inst.instantiate();
	inst->base = Ref<OpenDouConvolutionReverb>(this);
	return inst;
}

OpenDouConvolutionReverbInstance::~OpenDouConvolutionReverbInstance() { release_effects(); }

bool OpenDouConvolutionReverbInstance::ensure_effects() {
	if (reflection_ != nullptr && decode_ != nullptr) {
		return true;
	}
	const int rate = static_cast<int>(AudioServer::get_singleton()->get_mix_rate());
	if (!SteamAudioContext::ensure(rate)) {
		return false;
	}
	IPLContext ctx = SteamAudioContext::context();
	IPLAudioSettings audio = SteamAudioContext::audio_settings();
	frame_size_ = audio.frameSize;
	ir_size_ = static_cast<int>(2.0f * static_cast<float>(rate));
	IPLReflectionEffectSettings rs = {};
	rs.type = IPL_REFLECTIONEFFECTTYPE_HYBRID;
	rs.irSize = ir_size_;
	rs.numChannels = 4;
	if (iplReflectionEffectCreate(ctx, &audio, &rs, &reflection_) != IPL_STATUS_SUCCESS) {
		reflection_ = nullptr;
		return false;
	}
	IPLAmbisonicsDecodeEffectSettings ds = {};
	ds.speakerLayout.type = IPL_SPEAKERLAYOUTTYPE_STEREO;
	ds.maxOrder = 1;
	SteamAudioContext::HrtfSlot *slot = SteamAudioContext::acquire_hrtf();
	ds.hrtf = slot != nullptr ? slot->hrtf : nullptr;
	const IPLerror e = iplAmbisonicsDecodeEffectCreate(ctx, &audio, &ds, &decode_);
	SteamAudioContext::release_hrtf(slot);
	if (e != IPL_STATUS_SUCCESS) {
		decode_ = nullptr;
		release_effects();
		return false;
	}
	if (iplAudioBufferAllocate(ctx, 1, frame_size_, &in_) != IPL_STATUS_SUCCESS || iplAudioBufferAllocate(ctx, 4, frame_size_, &amb_) != IPL_STATUS_SUCCESS || iplAudioBufferAllocate(ctx, 2, frame_size_, &out_) != IPL_STATUS_SUCCESS) {
		release_effects();
		return false;
	}
	in_fifo_.assign(frame_size_ * 4, 0.0f);
	out_fifo_.assign(frame_size_ * 4, AudioFrame{ 0.0f, 0.0f });
	in_count_ = 0;
	out_read_ = 0;
	out_count_ = 0;
	return true;
}

void OpenDouConvolutionReverbInstance::release_effects() {
	IPLContext ctx = SteamAudioContext::context();
	if (reflection_ != nullptr) {
		iplReflectionEffectRelease(&reflection_);
		reflection_ = nullptr;
	}
	if (decode_ != nullptr) {
		iplAmbisonicsDecodeEffectRelease(&decode_);
		decode_ = nullptr;
	}
	if (ctx != nullptr) {
		if (in_.data != nullptr) {
			iplAudioBufferFree(ctx, &in_);
		}
		if (amb_.data != nullptr) {
			iplAudioBufferFree(ctx, &amb_);
		}
		if (out_.data != nullptr) {
			iplAudioBufferFree(ctx, &out_);
		}
	}
	in_ = {};
	amb_ = {};
	out_ = {};
}

void OpenDouConvolutionReverbInstance::_process(const void *p_src_buffer, AudioFrame *r_dst_buffer, int32_t p_frame_count) {
	const AudioFrame *src = static_cast<const AudioFrame *>(p_src_buffer);
	const float dry = base.is_valid() ? base->get_dry() : 1.0f;
	const float wet = base.is_valid() ? base->get_wet() : 0.0f;
	const int handle = base.is_valid() ? base->get_room_handle() : -1;
	IPLReflectionEffectParams params = {};
	const bool has_ir = wet > 0.0001f && handle >= 0 && ensure_effects() && OpenDouSimulator::copy_reflection_params(handle, params);
	if (!has_ir) {
		for (int32_t i = 0; i < p_frame_count; i++) {
			r_dst_buffer[i].left = src[i].left * dry;
			r_dst_buffer[i].right = src[i].right * dry;
		}
		return;
	}
	params.type = IPL_REFLECTIONEFFECTTYPE_HYBRID;
	params.numChannels = 4;
	params.irSize = ir_size_;
	// Entrada mono a la cola; por cada bloque completo, convolucion + decodificacion binaural.
	for (int32_t i = 0; i < p_frame_count; i++) {
		if (in_count_ < in_fifo_.size()) {
			in_fifo_[in_count_++] = 0.5f * (src[i].left + src[i].right);
		}
		while (in_count_ >= static_cast<size_t>(frame_size_)) {
			std::memcpy(in_.data[0], in_fifo_.data(), sizeof(float) * frame_size_);
			std::memmove(in_fifo_.data(), in_fifo_.data() + frame_size_, sizeof(float) * (in_count_ - frame_size_));
			in_count_ -= frame_size_;
			iplReflectionEffectApply(reflection_, &params, &in_, &amb_, nullptr);
			IPLAmbisonicsDecodeEffectParams dp = {};
			dp.order = 1;
			SteamAudioContext::HrtfSlot *slot = SteamAudioContext::acquire_hrtf();
			dp.hrtf = slot != nullptr ? slot->hrtf : nullptr;
			dp.orientation.right = IPLVector3{ 1, 0, 0 };
			dp.orientation.up = IPLVector3{ 0, 1, 0 };
			dp.orientation.ahead = IPLVector3{ 0, 0, -1 };
			dp.orientation.origin = IPLVector3{ 0, 0, 0 };
			dp.binaural = IPL_TRUE;
			iplAmbisonicsDecodeEffectApply(decode_, &dp, &amb_, &out_);
			SteamAudioContext::release_hrtf(slot);
			for (int k = 0; k < frame_size_; k++) {
				if (out_count_ < out_fifo_.size()) {
					float l = out_.data[0][k];
					float r = out_.data[1][k];
					// Un NaN de la convolucion envenenaria el bus entero: se corta en cero.
					if (!std::isfinite(l)) {
						l = 0.0f;
					}
					if (!std::isfinite(r)) {
						r = 0.0f;
					}
					out_fifo_[(out_read_ + out_count_) % out_fifo_.size()] = AudioFrame{ l, r };
					out_count_++;
				}
			}
		}
		AudioFrame w{ 0.0f, 0.0f };
		if (out_count_ > 0) {
			w = out_fifo_[out_read_];
			out_read_ = (out_read_ + 1) % out_fifo_.size();
			out_count_--;
		}
		r_dst_buffer[i].left = src[i].left * dry + w.left * wet;
		r_dst_buffer[i].right = src[i].right * dry + w.right * wet;
	}
}

} // namespace opendou
