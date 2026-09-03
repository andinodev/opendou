#pragma once
// Cama ambisonica (Fase 13): un AudioStream cuyo recurso trae N canales ambisonicos (orden 1 o
// 2, ACN/SN3D). Por bloque: rotacion con la orientacion del oyente y decodificacion al HRTF.
#include <godot_cpp/classes/audio_stream.hpp>
#include <godot_cpp/classes/audio_stream_playback.hpp>
#include <godot_cpp/classes/audio_frame.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/basis.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/array.hpp>
#include <phonon.h>
#include <atomic>
#include <mutex>
#include <vector>

namespace opendou {

class OpenDouAmbisonicStream : public godot::AudioStream {
	GDCLASS(OpenDouAmbisonicStream, godot::AudioStream)
public:
	void set_audio(const godot::Ref<godot::Resource> &p_audio);
	godot::Ref<godot::Resource> get_audio() const { return audio_; }
	void set_listener_basis(const godot::Basis &p_basis);
	godot::Basis get_listener_basis() const;
	void set_binaural(bool p_on) { binaural_.store(p_on); }
	bool is_binaural() const { return binaural_.load(); }
	// Codifica un mono en `order` con el propio codificador de Steam Audio: Array de canales.
	static godot::Array encode_mono(const godot::PackedFloat32Array &samples, const godot::Vector3 &direction, int order);

	godot::Ref<godot::AudioStreamPlayback> _instantiate_playback() const override;
	godot::String _get_stream_name() const override { return "OpenDouAmbisonicStream"; }
	double _get_length() const override;
	bool _is_monophonic() const override { return false; }

	godot::Ref<godot::Resource> audio_;
	std::atomic<float> basis_[9]{ 1, 0, 0, 0, 1, 0, 0, 0, 1 };
	std::atomic<bool> binaural_{ true };

protected:
	static void _bind_methods();
};

class OpenDouAmbisonicStreamPlayback : public godot::AudioStreamPlayback {
	GDCLASS(OpenDouAmbisonicStreamPlayback, godot::AudioStreamPlayback)
public:
	OpenDouAmbisonicStreamPlayback() {}
	~OpenDouAmbisonicStreamPlayback();
	void setup(const godot::Ref<OpenDouAmbisonicStream> &p_stream);
	void _start(double p_from_pos) override;
	void _stop() override;
	bool _is_playing() const override { return active_; }
	int32_t _get_loop_count() const override { return loops_; }
	double _get_playback_position() const override;
	void _seek(double p_time) override;
	int32_t _mix(godot::AudioFrame *p_buffer, float p_rate_scale, int32_t p_frames) override;

protected:
	static void _bind_methods() {}

private:
	bool load_channels();
	bool create_effects();
	void release_effects();
	bool render_block();
	godot::Ref<OpenDouAmbisonicStream> stream_;
	std::vector<std::vector<float>> channels_;
	int order_ = 1;
	int num_channels_ = 4;
	bool loop_ = true;
	size_t position_ = 0;
	int loops_ = 0;
	bool active_ = false;
	IPLAmbisonicsRotationEffect rotation_ = nullptr;
	IPLAmbisonicsDecodeEffect decode_ = nullptr;
	IPLAudioBuffer in_ = {};
	IPLAudioBuffer rot_ = {};
	IPLAudioBuffer out_ = {};
	int frame_size_ = 0;
	std::vector<godot::AudioFrame> ring_;
	size_t ring_read_ = 0;
	size_t ring_available_ = 0;
};

} // namespace opendou
