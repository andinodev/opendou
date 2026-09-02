class_name NpcController
extends CharacterBody3D

## NPC que patrulla entre waypoints. SIN oyente, a proposito.
##
## Sus pisadas son emisores como cualquier otro, asi que en las demos presionan el
## pool de voces y se oyen a traves de portales y oclusion.

@export var waypoints: Array[Vector3] = []
@export var move_speed: float = 2.2
@export var arrive_radius: float = 0.4

var rig: CharacterAudioRig = null

var _target_index: int = 0

func _ready() -> void:
	# El rig viene de la ESCENA. Ver .agents/rules/04_scene_composition.md.
	rig = $CharacterAudioRig

func _physics_process(delta: float) -> void:
	if waypoints.is_empty():
		return

	var target: Vector3 = waypoints[_target_index % waypoints.size()]
	var to_target := target - global_position
	to_target.y = 0.0
	if to_target.length() <= arrive_radius:
		_target_index += 1
		return

	var direction := to_target.normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	velocity.y -= 9.8 * delta
	var before := global_position
	move_and_slide()

	if rig != null:
		var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
		rig.notify_moved(moved)
