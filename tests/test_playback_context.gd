class_name TestPlaybackContext
extends RefCounted

## Observacion 26: el contexto de reproduccion no se construia nunca.
##
## AudioSwitchContainer lee context.get_switch() y AudioBlendContainer lee
## context.get_rtpc(), pero devirtualize() invocaba resolve_voices() sin argumento, asi
## que se creaba un contexto vacio: los switch containers resolvian SIEMPRE a su
## default_state y los blend veian SIEMPRE RTPC = 0.0.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const AudioEventManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioSwitchContainerClass = preload("res://addons/opendou/resources/containers/audio_switch_container.gd")
const AudioPhysicalNodeClass = preload("res://addons/opendou/resources/containers/audio_physical_node.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("playback_context")

	var manager = AudioEventManagerClass.new()
	tree.root.add_child(manager)
	await tree.process_frame

	# Dos ramas con streams DISTINGUIBLES: un tono grave y uno agudo. Comparar los
	# streams resueltos es lo que demuestra que el switch llego al contenedor.
	var low := AudioSynthesizerClass.create_tone(200.0, 0.3, 0.8, false)
	var high := AudioSynthesizerClass.create_tone(3000.0, 0.3, 0.8, false)

	var switch_container = AudioSwitchContainerClass.new(&"SurfaceType", &"Concrete")
	switch_container.set_state_node(&"Concrete", AudioPhysicalNodeClass.new(low))
	switch_container.set_state_node(&"Metal", AudioPhysicalNodeClass.new(high))

	var def = AudioEventDefClass.new(&"ContextProbe")
	def.root_container = switch_container
	def.stream_length = 0.3
	manager.register_event_definition(def)

	# Con el switch en Metal, el evento tiene que resolver a la rama de Metal.
	manager.set_switch(&"SurfaceType", &"Metal")
	var inst_metal = manager.post_event(&"ContextProbe", null)
	a.ok(inst_metal != null, "post_event devuelve instancia con switch Metal")
	for _f in range(4):
		await tree.process_frame
	if inst_metal != null:
		var ch = manager.voice_pool.get_channel(inst_metal.assigned_channel_id)
		a.ok(ch != null, "la voz con switch Metal recibio canal")
		if ch != null:
			a.eq(ch.current_stream, high, "resolvio a la rama Metal, no a la rama por defecto")

	# Y con el switch en Concrete, a la otra.
	manager.stop_all()
	manager.set_switch(&"SurfaceType", &"Concrete")
	var inst_conc = manager.post_event(&"ContextProbe", null)
	a.ok(inst_conc != null, "post_event devuelve instancia con switch Concrete")
	for _f in range(4):
		await tree.process_frame
	if inst_conc != null:
		var ch2 = manager.voice_pool.get_channel(inst_conc.assigned_channel_id)
		a.ok(ch2 != null, "la voz con switch Concrete recibio canal")
		if ch2 != null:
			a.eq(ch2.current_stream, low, "resolvio a la rama Concrete")

	# El contexto expone tambien los RTPC vivos, que es lo que necesita el blend
	# container.
	manager.set_rtpc(&"Tension", 0.75, true)
	for _f in range(3):
		await tree.process_frame
	var inst_rtpc = manager.post_event(&"ContextProbe", null)
	a.ok(inst_rtpc != null, "post_event devuelve instancia para medir el RTPC")
	if inst_rtpc != null:
		a.approx(inst_rtpc.playback_context.get_rtpc(&"Tension"), 0.75,
			"el contexto de la instancia ve el RTPC vivo", 0.01)

	manager.stop_all()
	tree.root.remove_child(manager)
	manager.free()
	return a
