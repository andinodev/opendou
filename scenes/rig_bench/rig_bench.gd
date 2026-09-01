class_name RigBench
extends Node3D

## Banco de pruebas del rig de personaje.
##
## Tres parches de material, un jugador y un NPC patrullando. Sirve para oir el rig
## aislado y para depurar pisadas sin cargar una demo entera.
##
## Su razon de ser: aqui se valida la convencion de metadata surface_type ANTES de que
## tres escenas dependan de ella.

const SurfacePatchClass = preload("res://scenes/shared/surface_patch.gd")
const FootstepEventsClass = preload("res://scenes/shared/footstep_events.gd")
const PlayerControllerClass = preload("res://scenes/shared/player_controller.gd")
const NpcControllerClass = preload("res://scenes/shared/npc_controller.gd")
const DemoAudioClass = preload("res://scenes/shared/demo_audio.gd")

## Los tres mas distinguibles al oido de los ocho del vocabulario: un golpe seco, un
## resonador metalico y un chapoteo.
const PATCH_SURFACES: Array[StringName] = [&"Concrete", &"Metal", &"Water"]

const PATCH_SIZE: Vector3 = Vector3(8.0, 1.0, 8.0)
const PATCH_SPACING: float = 9.0

var patch_surfaces: Array[StringName] = PATCH_SURFACES

var _built: bool = false

func _ready() -> void:
	build()

## Construye el banco. Idempotente: llamarlo dos veces no duplica nada.
func build() -> void:
	if _built:
		return
	_built = true

	# El evento de pisada se autora contra el autoload. register_event_definition()
	# sobrescribe por nombre, asi que volver a autorarlo desde otra escena es inocuo.
	var manager = DemoAudioClass.manager(self)
	if manager != null:
		FootstepEventsClass.register(manager)

	for i in range(patch_surfaces.size()):
		var pos := Vector3(float(i) * PATCH_SPACING, -0.5, 0.0)
		add_child(SurfacePatchClass.make(patch_surfaces[i], PATCH_SIZE, pos))

	var player = PlayerControllerClass.new()
	player.name = "Player"
	player.position = Vector3(0.0, 1.0, 0.0)
	add_child(player)

	# El NPC patrulla los tres parches, asi que se le oye cambiar de superficie.
	var npc = NpcControllerClass.new()
	npc.name = "Npc"
	npc.position = Vector3(0.0, 1.0, 3.0)
	# El literal tiene que ir en un local TIPADO: waypoints es Array[Vector3] y
	# asignarle un Array sin tipar aborta con un error de tipo en tiempo de ejecucion.
	var route: Array[Vector3] = [
		Vector3(0.0, 1.0, 3.0),
		Vector3(PATCH_SPACING, 1.0, 3.0),
		Vector3(PATCH_SPACING * 2.0, 1.0, 3.0),
	]
	npc.waypoints = route
	add_child(npc)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	add_child(light)
