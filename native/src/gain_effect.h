#pragma once
// Spike B5 (Fase 13): un AudioEffect nativo minimo. Si esto funciona en un bus, la convolucion
// y el medidor LUFS nativo pueden ser efectos de bus.
#include <godot_cpp/classes/audio_effect.hpp>
#include <godot_cpp/classes/audio_effect_instance.hpp>
#include <godot_cpp/classes/audio_frame.hpp>

namespace opendou {

class OpenDouGainEffect : public godot::AudioEffect {
	GDCLASS(OpenDouGainEffect, godot::AudioEffect)
public:
	void set_gain_db(float p_db) { gain_db_ = p_db; }
	float get_gain_db() const { return gain_db_; }
	godot::Ref<godot::AudioEffectInstance> _instantiate() override;

protected:
	static void _bind_methods();

private:
	float gain_db_ = 0.0f;
};

class OpenDouGainEffectInstance : public godot::AudioEffectInstance {
	GDCLASS(OpenDouGainEffectInstance, godot::AudioEffectInstance)
public:
	godot::Ref<OpenDouGainEffect> base;
	void _process(const void *p_src_buffer, godot::AudioFrame *r_dst_buffer, int32_t p_frame_count) override;
	bool _process_silence() const override { return false; }

protected:
	static void _bind_methods() {}
};

} // namespace opendou
