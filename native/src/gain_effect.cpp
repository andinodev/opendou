#include "gain_effect.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>

using namespace godot;

namespace opendou {

void OpenDouGainEffect::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_gain_db", "db"), &OpenDouGainEffect::set_gain_db);
	ClassDB::bind_method(D_METHOD("get_gain_db"), &OpenDouGainEffect::get_gain_db);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "gain_db", PROPERTY_HINT_RANGE, "-80,24,0.1"), "set_gain_db", "get_gain_db");
}

Ref<AudioEffectInstance> OpenDouGainEffect::_instantiate() {
	Ref<OpenDouGainEffectInstance> inst;
	inst.instantiate();
	inst->base = Ref<OpenDouGainEffect>(this);
	return inst;
}

void OpenDouGainEffectInstance::_process(const void *p_src_buffer, AudioFrame *r_dst_buffer, int32_t p_frame_count) {
	const AudioFrame *src = static_cast<const AudioFrame *>(p_src_buffer);
	const float g = base.is_valid() ? std::pow(10.0f, base->get_gain_db() / 20.0f) : 1.0f;
	for (int32_t i = 0; i < p_frame_count; i++) {
		r_dst_buffer[i].left = src[i].left * g;
		r_dst_buffer[i].right = src[i].right * g;
	}
}

} // namespace opendou
