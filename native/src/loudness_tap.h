#pragma once
// Fase 15 (C4): la parte cara del medidor LUFS (BS.1770-4) en nativo. El efecto filtra con la
// curva K muestra a muestra y entrega POTENCIAS por bloque de 100 ms y el pico muestral; la
// compuerta y las ventanas (10 numeros por segundo) siguen en GDScript (OpenDouLoudnessMeter).
#include <godot_cpp/classes/audio_effect.hpp>
#include <godot_cpp/classes/audio_effect_instance.hpp>
#include <godot_cpp/classes/audio_frame.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <array>
#include <atomic>
#include <mutex>

namespace opendou {

class OpenDouLoudnessTapInstance;

class OpenDouLoudnessTap : public godot::AudioEffect {
	GDCLASS(OpenDouLoudnessTap, godot::AudioEffect)
public:
	godot::Ref<godot::AudioEffectInstance> _instantiate() override;
	// Bloques cerrados desde la ultima llamada (potencia media L+R por bloque), en orden.
	godot::PackedFloat32Array take_blocks();
	// Pico muestral (lineal) desde la ultima llamada.
	float take_peak();
	int processed_frames() const;
	void reset();

protected:
	static void _bind_methods();

private:
	godot::Ref<OpenDouLoudnessTapInstance> live_;
};

class OpenDouLoudnessTapInstance : public godot::AudioEffectInstance {
	GDCLASS(OpenDouLoudnessTapInstance, godot::AudioEffectInstance)
public:
	static const int RING = 64;
	void _process(const void *p_src_buffer, godot::AudioFrame *r_dst_buffer, int32_t p_frame_count) override;
	bool _process_silence() const override { return true; }
	void setup(float rate);
	void reset_state();

	// Un escritor (audio) y un lector (principal): indices atomicos sobre un anillo fijo.
	std::array<float, RING> ring_{};
	std::atomic<int> write_{ 0 };
	int read_ = 0;
	std::atomic<float> peak_{ 0.0f };
	std::atomic<int> frames_{ 0 };
	std::atomic<bool> reset_pending_{ false };

protected:
	static void _bind_methods() {}

private:
	struct Biquad {
		float b0 = 1, b1 = 0, b2 = 0, a1 = 0, a2 = 0, z1 = 0, z2 = 0;
		inline float process(float x) {
			const float y = b0 * x + z1;
			z1 = b1 * x - a1 * y + z2;
			z2 = b2 * x - a2 * y;
			return y;
		}
		void reset() { z1 = z2 = 0.0f; }
	};
	Biquad shelf_[2], hpf_[2];
	float rate_ = 0.0f;
	int block_samples_ = 4410;
	int count_ = 0;
	double acc_[2] = { 0.0, 0.0 };
};

} // namespace opendou
