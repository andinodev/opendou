#include "loudness_tap.h"

#include <godot_cpp/classes/audio_server.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <cmath>

using namespace godot;

namespace opendou {

void OpenDouLoudnessTap::_bind_methods() {
	ClassDB::bind_method(D_METHOD("take_blocks"), &OpenDouLoudnessTap::take_blocks);
	ClassDB::bind_method(D_METHOD("take_peak"), &OpenDouLoudnessTap::take_peak);
	ClassDB::bind_method(D_METHOD("processed_frames"), &OpenDouLoudnessTap::processed_frames);
	ClassDB::bind_method(D_METHOD("reset"), &OpenDouLoudnessTap::reset);
}

Ref<AudioEffectInstance> OpenDouLoudnessTap::_instantiate() {
	Ref<OpenDouLoudnessTapInstance> inst;
	inst.instantiate();
	inst->setup(static_cast<float>(AudioServer::get_singleton()->get_mix_rate()));
	live_ = inst;
	return inst;
}

PackedFloat32Array OpenDouLoudnessTap::take_blocks() {
	PackedFloat32Array out;
	if (live_.is_null()) {
		return out;
	}
	const int w = live_->write_.load(std::memory_order_acquire);
	while (live_->read_ != w) {
		out.push_back(live_->ring_[live_->read_ % OpenDouLoudnessTapInstance::RING]);
		live_->read_ = (live_->read_ + 1) % (OpenDouLoudnessTapInstance::RING * 2);
	}
	return out;
}

float OpenDouLoudnessTap::take_peak() {
	if (live_.is_null()) {
		return 0.0f;
	}
	return live_->peak_.exchange(0.0f);
}

int OpenDouLoudnessTap::processed_frames() const {
	return live_.is_null() ? 0 : live_->frames_.load();
}

void OpenDouLoudnessTap::reset() {
	if (live_.is_null()) {
		return;
	}
	live_->reset_pending_.store(true);
	live_->read_ = live_->write_.load();
	live_->peak_.store(0.0f);
	live_->frames_.store(0);
}

// Coeficientes RBJ con los parametros de la norma: shelf f0 = 1681.97 Hz, Q = 0.7071752,
// +3.99984 dB; paso-alto f0 = 38.13547 Hz, Q = 0.5003270 (los mismos que el GDScript).
void OpenDouLoudnessTapInstance::setup(float rate) {
	rate_ = rate > 1.0f ? rate : 44100.0f;
	block_samples_ = static_cast<int>(rate_ * 0.1f);
	const double A = std::pow(10.0, 3.999843853973347 / 40.0);
	{
		const double w0 = 2.0 * M_PI * 1681.974450955533 / rate_;
		const double cw = std::cos(w0), sw = std::sin(w0);
		const double alpha = sw / (2.0 * 0.7071752369554196);
		const double s2a = 2.0 * std::sqrt(A) * alpha;
		const double a0 = (A + 1.0) - (A - 1.0) * cw + s2a;
		for (Biquad &b : shelf_) {
			b.b0 = static_cast<float>(A * ((A + 1.0) + (A - 1.0) * cw + s2a) / a0);
			b.b1 = static_cast<float>(-2.0 * A * ((A - 1.0) + (A + 1.0) * cw) / a0);
			b.b2 = static_cast<float>(A * ((A + 1.0) + (A - 1.0) * cw - s2a) / a0);
			b.a1 = static_cast<float>(2.0 * ((A - 1.0) - (A + 1.0) * cw) / a0);
			b.a2 = static_cast<float>(((A + 1.0) - (A - 1.0) * cw - s2a) / a0);
		}
	}
	{
		const double w0 = 2.0 * M_PI * 38.13547087602444 / rate_;
		const double cw = std::cos(w0), sw = std::sin(w0);
		const double alpha = sw / (2.0 * 0.5003270373238773);
		const double a0 = 1.0 + alpha;
		for (Biquad &b : hpf_) {
			b.b0 = static_cast<float>((1.0 + cw) * 0.5 / a0);
			b.b1 = static_cast<float>(-(1.0 + cw) / a0);
			b.b2 = static_cast<float>((1.0 + cw) * 0.5 / a0);
			b.a1 = static_cast<float>(-2.0 * cw / a0);
			b.a2 = static_cast<float>((1.0 - alpha) / a0);
		}
	}
	reset_state();
}

void OpenDouLoudnessTapInstance::reset_state() {
	for (int c = 0; c < 2; c++) {
		shelf_[c].reset();
		hpf_[c].reset();
		acc_[c] = 0.0;
	}
	count_ = 0;
}

void OpenDouLoudnessTapInstance::_process(const void *p_src_buffer, AudioFrame *r_dst_buffer, int32_t p_frame_count) {
	const AudioFrame *src = static_cast<const AudioFrame *>(p_src_buffer);
	if (reset_pending_.exchange(false)) {
		reset_state();
	}
	float peak = 0.0f;
	for (int32_t i = 0; i < p_frame_count; i++) {
		r_dst_buffer[i] = src[i];
		const float l = src[i].left, r = src[i].right;
		const float yl = hpf_[0].process(shelf_[0].process(l));
		const float yr = hpf_[1].process(shelf_[1].process(r));
		acc_[0] += static_cast<double>(yl) * yl;
		acc_[1] += static_cast<double>(yr) * yr;
		peak = std::max(peak, std::max(std::fabs(l), std::fabs(r)));
		if (++count_ >= block_samples_) {
			const float n = static_cast<float>(count_);
			const int w = write_.load(std::memory_order_relaxed);
			ring_[w % RING] = static_cast<float>(acc_[0] / n + acc_[1] / n);
			write_.store((w + 1) % (RING * 2), std::memory_order_release);
			acc_[0] = acc_[1] = 0.0;
			count_ = 0;
		}
	}
	frames_.fetch_add(p_frame_count);
	float cur = peak_.load();
	while (peak > cur && !peak_.compare_exchange_weak(cur, peak)) {
	}
}

} // namespace opendou
