#pragma once
// Fase 15 (C1): stream que vuelca el envio acumulado (OpenDouSendBus) de un bus del pool. Un
// AudioStreamPlayer del bus de reverb lo reproduce en bucle: asi el bus tiene un reproductor
// real y Godot lo mantiene activo (un bus sin reproductores no manda su salida a Master ni
// limpia su bufer entre pasos, aunque sus efectos procesen en silencio).
#include <godot_cpp/classes/audio_stream.hpp>
#include <godot_cpp/classes/audio_stream_playback.hpp>
#include <godot_cpp/classes/audio_frame.hpp>
#include <vector>

namespace opendou {

class OpenDouSendStream : public godot::AudioStream {
	GDCLASS(OpenDouSendStream, godot::AudioStream)
public:
	void set_send_id(int p) { send_id_ = p; }
	int get_send_id() const { return send_id_; }
	godot::Ref<godot::AudioStreamPlayback> _instantiate_playback() const override;
	godot::String _get_stream_name() const override { return "OpenDouSendStream"; }
	bool _is_monophonic() const override { return false; }
	double _get_length() const override { return 0.0; }

protected:
	static void _bind_methods();

private:
	int send_id_ = -1;
};

class OpenDouSendStreamPlayback : public godot::AudioStreamPlayback {
	GDCLASS(OpenDouSendStreamPlayback, godot::AudioStreamPlayback)
public:
	godot::Ref<OpenDouSendStream> stream;
	void _start(double) override { active_ = true; }
	void _stop() override { active_ = false; }
	bool _is_playing() const override { return active_; }
	int32_t _get_loop_count() const override { return 0; }
	double _get_playback_position() const override { return 0.0; }
	void _seek(double) override {}
	int32_t _mix(godot::AudioFrame *p_buffer, float p_rate_scale, int32_t p_frames) override;

protected:
	static void _bind_methods() {}

private:
	bool active_ = false;
	std::vector<float> tmp_;
};

} // namespace opendou
