class_name OpenDouArmoredVehicle
extends Node3D

## Armored vehicle patrolling in Sector 1 with dynamic RTPC RPM engine sound.

const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

@export var patrol_speed: float = 6.0
@export var waypoints: Array[Vector3] = [
	Vector3(-25, 0.5, -20),
	Vector3(-5, 0.5, -20),
	Vector3(-5, 0.5, 20),
	Vector3(-25, 0.5, 20)
]

var current_waypoint_idx: int = 0
var current_rpm: float = 800.0

@onready var engine_audio: AudioStreamPlayer3D = $EngineAudio

func _ready() -> void:
	if engine_audio:
		engine_audio.stream = AudioSynthesizerClass.create_engine_loop(50.0)
		engine_audio.unit_size = 15.0
		engine_audio.max_distance = 50.0
		engine_audio.play()

func _physics_process(delta: float) -> void:
	if waypoints.is_empty():
		return
		
	var target = waypoints[current_waypoint_idx]
	var dir = (target - position).normalized()
	var dist = position.distance_to(target)
	
	if dist < 1.0:
		current_waypoint_idx = (current_waypoint_idx + 1) % waypoints.size()
	else:
		position += dir * patrol_speed * delta
		look_at(position + dir, Vector3.UP)
		
	# RPM maps to patrol movement
	current_rpm = lerpf(800.0, 3200.0, patrol_speed / 10.0)
	if engine_audio:
		engine_audio.pitch_scale = lerpf(0.7, 1.8, current_rpm / 3200.0)
		engine_audio.volume_db = -4.0
