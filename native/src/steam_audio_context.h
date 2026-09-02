// Contexto compartido de Steam Audio: un IPLContext, un HRTF y los ajustes de audio.
//
// Es un singleton estatico y no un Node porque lo necesita el hilo de audio, no el arbol.
// Se crea perezosamente la primera vez que un stream lo pide y vive hasta que la extension
// se descarga.
#pragma once

#include <phonon.h>

namespace opendou {

class SteamAudioContext {
public:
	// Crea el contexto y el HRTF por defecto si aun no existen. Devuelve false si Steam
	// Audio fallo, en cuyo caso los streams tienen que caer al bypass.
	static bool ensure(int sampling_rate, int frame_size);
	static void shutdown();

	static bool is_ready() { return context_ != nullptr && hrtf_ != nullptr; }
	static IPLContext context() { return context_; }
	static IPLHRTF hrtf() { return hrtf_; }
	static const IPLAudioSettings &audio_settings() { return audio_; }

private:
	static IPLContext context_;
	static IPLHRTF hrtf_;
	static IPLAudioSettings audio_;
};

} // namespace opendou
