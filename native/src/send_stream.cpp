#include "send_stream.h"
#include "send_bus.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

namespace opendou {

void OpenDouSendStream::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_send_id", "id"), &OpenDouSendStream::set_send_id);
	ClassDB::bind_method(D_METHOD("get_send_id"), &OpenDouSendStream::get_send_id);
	ADD_PROPERTY(PropertyInfo(Variant::INT, "send_id"), "set_send_id", "get_send_id");
}

Ref<AudioStreamPlayback> OpenDouSendStream::_instantiate_playback() const {
	Ref<OpenDouSendStreamPlayback> pb;
	pb.instantiate();
	pb->stream = Ref<OpenDouSendStream>(this);
	return pb;
}

int32_t OpenDouSendStreamPlayback::_mix(AudioFrame *p_buffer, float, int32_t p_frames) {
	const int id = stream.is_valid() ? stream->get_send_id() : -1;
	if (tmp_.size() < static_cast<size_t>(p_frames)) {
		tmp_.resize(static_cast<size_t>(p_frames));
	}
	OpenDouSendBus::drain(id, tmp_.data(), p_frames);
	for (int32_t i = 0; i < p_frames; i++) {
		p_buffer[i] = AudioFrame{ tmp_[i], tmp_[i] };
	}
	return p_frames;
}

} // namespace opendou
