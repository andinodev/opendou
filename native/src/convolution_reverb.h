#pragma once
// Reverb por convolucion de Steam Audio como AudioEffect de bus (Fase 13). La IR sale de la
// fuente de oyente de la sala (OpenDouSimulator, hilo de reflexiones); el efecto devuelve
// seco + humedo porque dentro de una sala Godot manda la voz entera al bus de reverb (obs 49).
#include <godot_cpp/classes/audio_effect.hpp>
#include <godot_cpp/classes/audio_effect_instance.hpp>
#include <godot_cpp/classes/audio_frame.hpp>
#include <phonon.h>
#include <vector>

namespace opendou {

class OpenDouConvolutionReverb : public godot::AudioEffect {
	GDCLASS(OpenDouConvolutionReverb, godot::AudioEffect)
public:
	void set_dry(float p) { dry_ = p; }
	float get_dry() const { return dry_; }
	void set_wet(float p) { wet_ = p; }
	float get_wet() const { return wet_; }
	void set_room_handle(int p) { room_handle_ = p; }
	int get_room_handle() const { return room_handle_; }
	godot::Ref<godot::AudioEffectInstance> _instantiate() override;

protected:
	static void _bind_methods();

private:
	float dry_ = 1.0f;
	float wet_ = 0.5f;
	int room_handle_ = -1;
};

class OpenDouConvolutionReverbInstance : public godot::AudioEffectInstance {
	GDCLASS(OpenDouConvolutionReverbInstance, godot::AudioEffectInstance)
public:
	~OpenDouConvolutionReverbInstance();
	godot::Ref<OpenDouConvolutionReverb> base;
	void _process(const void *p_src_buffer, godot::AudioFrame *r_dst_buffer, int32_t p_frame_count) override;
	bool _process_silence() const override { return true; }
	bool ensure_effects();

protected:
	static void _bind_methods() {}

private:
	void release_effects();
	IPLReflectionEffect reflection_ = nullptr;
	IPLAmbisonicsDecodeEffect decode_ = nullptr;
	IPLAudioBuffer in_ = {};
	IPLAudioBuffer amb_ = {};
	IPLAudioBuffer out_ = {};
	int frame_size_ = 0;
	int ir_size_ = 0;
	// Godot puede entregar bloques de otro tamano: se acumula en una cola de entrada y se
	// sirve desde una cola de salida (un bloque de latencia).
	std::vector<float> in_fifo_;
	std::vector<godot::AudioFrame> out_fifo_;
	size_t in_count_ = 0;
	size_t out_read_ = 0;
	size_t out_count_ = 0;
};

} // namespace opendou
