// OpenDouSpatialStream: envuelve otro AudioStream y lo renderiza en binaural con el HRTF de
// Steam Audio. Se reproduce con un AudioStreamPlayer ESTEREO normal, saltandose el panner 3D
// de Godot; la direccion la pone cada frame el plano de control de OpenDou.
//
// ES UN SPIKE. Responde a "puede una voz salir por Steam Audio dentro de Godot 4.7, y cuanto
// cuesta". Lo que aqui se decida mal se rehace en la 7B; lo que se aprenda va al spec.
#pragma once

#include <godot_cpp/classes/audio_stream.hpp>
#include <godot_cpp/classes/audio_stream_playback.hpp>
#include <godot_cpp/classes/audio_frame.hpp>

#include <phonon.h>

#include <atomic>
#include <vector>

namespace opendou {

class OpenDouSpatialStream : public godot::AudioStream {
	GDCLASS(OpenDouSpatialStream, godot::AudioStream)

public:
	OpenDouSpatialStream();

	void set_source(const godot::Ref<godot::AudioStream> &p_source);
	godot::Ref<godot::AudioStream> get_source() const;

	// Vector unitario del oyente hacia la fuente, en coordenadas DEL OYENTE. Mismo sistema
	// que Godot: +X derecha, +Y arriba, -Z delante.
	void set_direction(const godot::Vector3 &p_direction);
	godot::Vector3 get_direction() const;

	// 0 = sin espacializar (solo el sonido seco), 1 = binaural completo.
	void set_spatial_blend(float p_blend);
	float get_spatial_blend() const;

	// Interruptor duro: con false el stream hace bypass y no toca Steam Audio. Es lo que
	// permite que un test afirme que el HRTF hace algo: apagado, el ITD tiene que ser cero.
	void set_spatialize(bool p_enabled);
	bool is_spatialize() const;

	// true si Steam Audio esta cargado y el contexto se creo.
	// Ultimos retardos de pico (izquierdo, derecho) en segundos que Steam Audio escribio al
	// renderizar. Si el HRTF trae los picos alineados, el ITD NO esta en el audio de salida
	// y hay que aplicarlo aparte: este valor es la prueba.
	godot::Vector2 get_last_peak_delays() const;

	static bool is_native_available();
	static int get_frame_size();
	static godot::String get_steam_audio_version();

	godot::Ref<godot::AudioStreamPlayback> _instantiate_playback() const override;
	godot::String _get_stream_name() const override;
	double _get_length() const override;
	bool _is_monophonic() const override;

protected:
	static void _bind_methods();

private:
	friend class OpenDouSpatialStreamPlayback;
	godot::Ref<godot::AudioStream> source_;
	std::atomic<float> dir_x_{ 0.0f };
	std::atomic<float> dir_y_{ 0.0f };
	std::atomic<float> dir_z_{ -1.0f };
	std::atomic<float> spatial_blend_{ 1.0f };
	std::atomic<bool> spatialize_{ true };
	std::atomic<float> peak_left_{ 0.0f };
	std::atomic<float> peak_right_{ 0.0f };
};

class OpenDouSpatialStreamPlayback : public godot::AudioStreamPlayback {
	GDCLASS(OpenDouSpatialStreamPlayback, godot::AudioStreamPlayback)

public:
	OpenDouSpatialStreamPlayback();
	~OpenDouSpatialStreamPlayback();

	void setup(const godot::Ref<OpenDouSpatialStream> &p_stream);

	void _start(double p_from_pos) override;
	void _stop() override;
	bool _is_playing() const override;
	int32_t _get_loop_count() const override;
	double _get_playback_position() const override;
	void _seek(double p_position) override;
	int32_t _mix(godot::AudioFrame *p_buffer, float p_rate_scale, int32_t p_frames) override;

protected:
	static void _bind_methods() {}

private:
	bool create_effect();
	void release_effect();
	// Tira un bloque de frame_size del stream interno, lo renderiza y lo deja en el anillo.
	bool render_block(float p_rate_scale);

	godot::Ref<OpenDouSpatialStream> stream_;
	godot::Ref<godot::AudioStreamPlayback> inner_;
	bool active_ = false;

	IPLBinauralEffect effect_ = nullptr;
	IPLAudioBuffer in_buffer_ = {};
	IPLAudioBuffer out_buffer_ = {};
	std::vector<float> interleaved_;
	float peak_delays_[2] = { 0.0f, 0.0f };

	// Anillo de salida: Godot pide un numero variable de frames y Steam Audio produce
	// exactamente frameSize. El anillo desacopla los dos. Es la latencia del sistema.
	std::vector<godot::AudioFrame> ring_;
	size_t ring_read_ = 0;
	size_t ring_available_ = 0;
};

} // namespace opendou
