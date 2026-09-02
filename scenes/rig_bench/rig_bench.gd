class_name RigBench
extends Node3D

## Banco de pruebas del rig de personaje.
##
## Tres parches de material, un jugador y un NPC patrullando. Sirve para oir el rig
## aislado y para depurar pisadas sin cargar una demo entera.
##
## Su razon de ser: aqui se valida la convencion de metadata surface_type ANTES de que
## tres escenas dependan de ella.
##
## LA ESCENA lleva los parches, el jugador, el NPC, la luz y el cartel. Este script solo
## autora el evento de pisada, que es la unica excepcion legitima de
## .agents/rules/04_scene_composition.md: los AudioStream se sintetizan en tiempo de
## ejecucion porque el proyecto no tiene assets de audio.

const FootstepEventsClass = preload("res://scenes/shared/footstep_events.gd")
const DemoAudioClass = preload("res://scenes/shared/demo_audio.gd")

## Las superficies que el banco declara, leidas de la metadata de los parches de la
## escena. Se rellena en _ready(): la escena es la fuente de verdad, no una constante.
var patch_surfaces: Array[StringName] = []

func _ready() -> void:
	for child in get_children():
		if child is StaticBody3D and child.has_meta("surface_type"):
			patch_surfaces.append(StringName(child.get_meta("surface_type")))

	# El evento de pisada se autora contra el autoload. register_event_definition()
	# sobrescribe por nombre, asi que volver a autorarlo desde otra escena es inocuo.
	var manager = DemoAudioClass.manager(self)
	if manager != null:
		FootstepEventsClass.register(manager)
