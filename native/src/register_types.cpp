// Punto de entrada de la extension nativa de OpenDou.
#include "register_types.h"

#include "acoustic_scene.h"
#include "ambisonic_stream.h"
#include "convolution_reverb.h"
#include "gain_effect.h"
#include "send_stream.h"
#include "send_bus.h"
#include "simulator.h"
#include "spatial_stream.h"
#include "steam_audio_context.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_opendou_native(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(opendou::OpenDouSpatialStream);
	GDREGISTER_CLASS(opendou::OpenDouSpatialStreamPlayback);
	GDREGISTER_CLASS(opendou::OpenDouAcousticScene);
	GDREGISTER_CLASS(opendou::OpenDouSimulator);
	GDREGISTER_CLASS(opendou::OpenDouGainEffect);
	GDREGISTER_CLASS(opendou::OpenDouGainEffectInstance);
	GDREGISTER_CLASS(opendou::OpenDouConvolutionReverb);
	GDREGISTER_CLASS(opendou::OpenDouConvolutionReverbInstance);
	GDREGISTER_CLASS(opendou::OpenDouAmbisonicStream);
	GDREGISTER_CLASS(opendou::OpenDouAmbisonicStreamPlayback);
	GDREGISTER_CLASS(opendou::OpenDouSendBus);
	GDREGISTER_CLASS(opendou::OpenDouSendStream);
	GDREGISTER_CLASS(opendou::OpenDouSendStreamPlayback);
}

void uninitialize_opendou_native(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	opendou::OpenDouSimulator::shutdown();
	opendou::OpenDouAcousticScene::clear();
	opendou::SteamAudioContext::shutdown();
}

extern "C" {
GDExtensionBool GDE_EXPORT opendou_native_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_opendou_native);
	init_obj.register_terminator(uninitialize_opendou_native);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
