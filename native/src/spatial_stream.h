// OpenDouSpatialStream: envuelve otro AudioStream y lo renderiza en estereo espacializado
// con el HRTF de Steam Audio (audifonos) o con paneo de potencia constante (altavoces). Se
// reproduce con un AudioStreamPlayer ESTEREO normal, saltandose el panner 3D de Godot; la
// direccion, la ganancia por distancia y los filtros los pone cada frame el plano de
// control de OpenDou (PhysicalVoiceChannel.apply_spatial).
//
// Cadena por bloque: mezcla del stream interno -> mono -> distance_gain -> LPF de oclusion
// (cutoff_hz) -> high-shelf por distancia (shelf_db @ shelf_cutoff_hz) -> HRTF o paneo ->
// anillo de salida.
#pragma once

#include <godot_cpp/classes/audio_stream.hpp>
#include <godot_cpp/classes/audio_stream_playback.hpp>
#include <godot_cpp/classes/audio_frame.hpp>
#include <godot_cpp/core/binder_common.hpp>

#include <phonon.h>

#include <atomic>
#include <vector>

#include "dsp.h"

namespace opendou {

class OpenDouSpatialStream : public godot::AudioStream {
	GDCLASS(OpenDouSpatialStream, godot::AudioStream)

public:
	enum OutputMode {
		OUTPUT_HEADPHONES = 0,
		OUTPUT_SPEAKERS = 1,
	};

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

	// Ganancia lineal por distancia, calculada por el canal con las formulas de Godot.
	void set_distance_gain(float p_gain);
	float get_distance_gain() const;

	// Paso-bajo de oclusion (Butterworth de 2.o orden). 20000 = sin efecto.
	void set_cutoff_hz(float p_hz);
	float get_cutoff_hz() const;

	// High-shelf por distancia: la profundidad (0 = nada) y el corte (5 kHz en Godot).
	void set_shelf_db(float p_db);
	float get_shelf_db() const;
	void set_shelf_cutoff_hz(float p_hz);
	float get_shelf_cutoff_hz() const;

	// Audifonos (HRTF) o altavoces (paneo de potencia constante). Cambia en vivo.
	void set_output_mode(int p_mode);
	int get_output_mode() const;

	// Campo cercano (Fase 9): refuerzo de graves (low-shelf a 250 Hz) e ILD extra en el oido
	// lejano, en dB. 0 = sin efecto. Los calcula el canal segun la distancia.
	void set_near_field_bass_db(float p_db);
	float get_near_field_bass_db() const;
	void set_near_field_ild_db(float p_db);
	float get_near_field_ild_db() const;

	// Ultimos retardos de pico (izquierdo, derecho) en segundos que Steam Audio escribio al
	// renderizar. El HRTF trae los picos alineados: el ITD NO esta en su salida y OpenDou lo
	// aplica aparte; este valor es el residuo que se resta.
	godot::Vector2 get_last_peak_delays() const;

	// ITD aplicado en el ultimo bloque, en milisegundos: Woodworth menos el residuo.
	float get_last_applied_itd_ms() const { return applied_itd_.load() * 1000.0f; }

	static bool is_native_available();
	static int get_frame_size();
	static godot::String get_steam_audio_version();
	// Tamano de bloque; solo antes de crear el contexto (ver SteamAudioContext).
	static bool configure(int frame_size);
	// HRTF global, conmutable en vivo.
	static bool set_hrtf_default();
	static bool set_hrtf_sofa(const godot::String &path);
	static godot::String get_hrtf_name();
	static int get_hrtf_generation();
	// Renderiza `voices` bloques de forma sincrona con la cadena completa y devuelve
	// microsegundos por voz: la guarda de coste del DSP (tests/dsp_budget.txt).
	static float benchmark_block(int voices);
	// Desglose: 0 = cadena completa, 1 = solo HRTF bilineal, 2 = solo HRTF vecino mas
	// cercano, 3 = solo filtros + ITD, 4 = solo generar la fuente (el suelo de la medida).
	static float benchmark_block_mode(int voices, int mode);

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
	std::atomic<float> distance_gain_{ 1.0f };
	std::atomic<float> cutoff_hz_{ 20000.0f };
	std::atomic<float> shelf_db_{ 0.0f };
	std::atomic<float> shelf_cutoff_hz_{ 5000.0f };
	std::atomic<int> output_mode_{ OUTPUT_HEADPHONES };
	std::atomic<float> near_field_bass_db_{ 0.0f };
	std::atomic<float> near_field_ild_db_{ 0.0f };
	std::atomic<float> peak_left_{ 0.0f };
	std::atomic<float> peak_right_{ 0.0f };
	std::atomic<float> applied_itd_{ 0.0f };
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
	// Tira un bloque de frame_size del stream interno, lo procesa y lo deja en el anillo.
	bool render_block(float p_rate_scale);

	godot::Ref<OpenDouSpatialStream> stream_;
	godot::Ref<godot::AudioStreamPlayback> inner_;
	bool active_ = false;

	IPLBinauralEffect effect_ = nullptr;
	IPLAudioBuffer in_buffer_ = {};
	IPLAudioBuffer out_buffer_ = {};
	std::vector<float> interleaved_;
	float peak_delays_[2] = { 0.0f, 0.0f };

	dsp::Biquad lpf_;
	dsp::Biquad shelf_;
	float lpf_applied_hz_ = -1.0f;
	float shelf_applied_db_ = 1.0f; // imposible a proposito: fuerza el primer calculo
	float shelf_applied_hz_ = -1.0f;
	dsp::Biquad near_shelf_;
	float near_applied_db_ = -1.0f;

	// ITD esferico: una linea de retardo por oido; se retrasa el oido LEJANO.
	dsp::FractionalDelay delay_l_;
	dsp::FractionalDelay delay_r_;

	// Anillo de salida: Godot pide un numero variable de frames y Steam Audio produce
	// exactamente frameSize. El anillo desacopla los dos. Es la latencia del sistema.
	std::vector<godot::AudioFrame> ring_;
	size_t ring_read_ = 0;
	size_t ring_available_ = 0;
};

} // namespace opendou

VARIANT_ENUM_CAST(opendou::OpenDouSpatialStream::OutputMode);
