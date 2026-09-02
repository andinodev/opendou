class_name FootstepEvents
extends RefCounted

## Autora el evento unico de pisada de OpenDou.
##
## UN evento con AudioSwitchContainer sobre el grupo SurfaceType, y una rama
## AudioRandomContainer por superficie con tres variaciones sintetizadas.
##
## La alternativa seria registrar ocho eventos Footstep_<Superficie> y dejar que
## AnimationSync los eligiera concatenando cadenas. Funcionaria, y no demostraria
## nada: la eleccion la haria una busqueda de texto en lugar del plugin. Asi las
## pisadas ejercitan switch containers, random containers y switches de Game Syncs.
##
## AnimationSync no necesita cambios: fija el switch SurfaceType, busca un evento por
## nombre, no lo encuentra, y cae a default_footstep_event, que es este.

const SurfacePatchClass = preload("res://scenes/shared/surface_patch.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioSwitchContainerClass = preload("res://addons/opendou/resources/containers/audio_switch_container.gd")
const AudioRandomContainerClass = preload("res://addons/opendou/resources/containers/audio_random_container.gd")
const AudioPhysicalNodeClass = preload("res://addons/opendou/resources/containers/audio_physical_node.gd")

## Nombre del evento y del grupo de switch. AnimationSync usa este mismo grupo.
const EVENT_NAME: StringName = &"Footstep"
const SWITCH_GROUP: StringName = &"SurfaceType"

## Variaciones sintetizadas por superficie. create_footstep desplaza sus frecuencias
## con el indice, asi que tres dan variacion audible sin repeticion evidente.
const VARIATIONS: int = 3

## Autora el evento y lo registra en el manager. Devuelve la definicion.
static func register(manager) -> AudioEventDef:
	var switch_container = AudioSwitchContainerClass.new(SWITCH_GROUP, &"Concrete")

	for surface in SurfacePatchClass.SURFACES:
		var random_container = AudioRandomContainerClass.new()
		random_container.use_shuffle = true
		# Jitter suave: dos pisadas seguidas no deben sonar identicas, pero tampoco
		# como dos materiales distintos.
		random_container.pitch_jitter_range = Vector2(-0.06, 0.06)
		random_container.volume_jitter_db_range = Vector2(-2.5, 0.0)
		for v in range(1, VARIATIONS + 1):
			var stream := AudioSynthesizerClass.create_footstep(surface, v)
			random_container.add_child_node(AudioPhysicalNodeClass.new(stream))
		switch_container.set_state_node(surface, random_container)

	var def = AudioEventDefClass.new(EVENT_NAME)
	def.root_container = switch_container
	def.base_priority = 40.0
	def.base_volume_db = -4.0
	def.stream_length = 0.22
	def.is_looping = false
	if manager != null:
		manager.register_event_definition(def)
	return def
