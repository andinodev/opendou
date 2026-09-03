#pragma once
// Fase 15 (C1): envios de reverb propios. Un acumulador mono por bus del pool: los streams
// suman su senal (pre-HRTF) durante la mezcla y el efecto OpenDouReverbSendInput lo vuelca al
// bus en el mismo paso del hilo de audio. Sin el Area3D de Godot, la voz vuelve a su target_bus.
#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <atomic>
#include <mutex>
#include <vector>

namespace opendou {

class OpenDouSendBus : public godot::Object {
	GDCLASS(OpenDouSendBus, godot::Object)
public:
	static const int MAX_SENDS = 32;
	static const size_t RING = 16384;

	static int create();
	static void release(int id);
	static int count();
	// Hilo de audio.
	static void accumulate(int id, const float *mono, int n, float gain);
	static void drain(int id, float *out, int n);
	// Diagnostico: {accum_calls, accum_frames, drain_calls, drain_frames, max_avail, avail}.
	static godot::Dictionary stats(int id);

protected:
	static void _bind_methods();

private:
	struct Send {
		std::atomic<bool> used{ false };
		std::mutex mutex;
		std::vector<float> ring;
		size_t head = 0;
		size_t avail = 0;
		long accum_calls = 0;
		long accum_frames = 0;
		long drain_calls = 0;
		long drain_frames = 0;
		size_t max_avail = 0;
	};
	static Send sends_[MAX_SENDS];
};

} // namespace opendou
