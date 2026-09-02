// Contexto compartido de Steam Audio: un IPLContext, el HRTF activo y los ajustes de audio.
//
// Es un singleton estatico y no un Node porque lo necesita el hilo de audio, no el arbol.
// Se crea perezosamente la primera vez que un stream lo pide y vive hasta que la extension
// se descarga.
#pragma once

#include <phonon.h>

#include <atomic>
#include <mutex>
#include <string>

namespace opendou {

class SteamAudioContext {
public:
	// Tamano de bloque. Solo tiene efecto ANTES de crear el contexto; despues devuelve si
	// coincide con el vigente.
	static bool configure_frame_size(int frame_size);
	// Crea el contexto y el HRTF por defecto si aun no existen. Devuelve false si Steam
	// Audio fallo, en cuyo caso los streams tienen que caer al bypass.
	static bool ensure(int sampling_rate);
	static void shutdown();

	static bool is_ready() { return context_ != nullptr && current_.load() != nullptr; }
	static IPLContext context() { return context_; }
	static const IPLAudioSettings &audio_settings() { return audio_; }

	// HRTF con generacion. El hilo de audio toma el HRTF actual con acquire_hrtf() al
	// empezar cada bloque y lo suelta con release_hrtf() al terminar; si mientras tanto el
	// hilo principal cambio el HRTF, el viejo se libera cuando su cuenta llega a cero.
	struct HrtfSlot {
		IPLHRTF hrtf = nullptr;
		std::atomic<int> refs{ 0 };
		int generation = 0;
	};
	static HrtfSlot *acquire_hrtf();
	static void release_hrtf(HrtfSlot *slot);
	static int generation() { return generation_.load(); }
	static bool set_hrtf_default();
	static bool set_hrtf_sofa(const std::string &path);
	static std::string hrtf_name();

private:
	static bool install_hrtf(IPLHRTFSettings &settings, const std::string &name);
	static void collect_retired();

	static IPLContext context_;
	static IPLAudioSettings audio_;
	static int requested_frame_size_;
	static std::atomic<HrtfSlot *> current_;
	static HrtfSlot *retired_[8];
	static std::mutex swap_mutex_;
	static std::atomic<int> generation_;
	static std::string name_;
};

} // namespace opendou
