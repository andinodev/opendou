class_name DemoVoiceStress
extends Node3D

## Demo 02: Massive Voice Starvation & Zero-Cost Virtual Tracking (250+ Emitters Stress Test)

const VoicePoolManagerClass = preload("res://addons/opendou/runtime/voice_pool_manager.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")

var pool: VoicePoolManager
var instances: Array[EventInstance] = []
var listener_position: Vector3 = Vector3.ZERO

var total_emitters_count: int = 250
var physical_capacity: int = 16

func _ready() -> void:
	setup_stress_test()

func setup_stress_test(emitter_count: int = 250, hardware_channels: int = 16) -> void:
	total_emitters_count = emitter_count
	physical_capacity = hardware_channels
	
	pool = VoicePoolManagerClass.new(physical_capacity)
	instances.clear()
	
	var def = AudioEventDefClass.new(&"Battlefield_Gunfire")
	def.base_priority = 50.0
	def.base_volume_db = 0.0
	def.stream_length = 4.0
	def.is_looping = true
	def.virtualization_mode = AudioEventDefClass.VirtualizationMode.VIRTUAL_ELAPSED_TIME
	
	# Spawn emitters in a 3D grid
	var side = int(ceil(sqrt(total_emitters_count)))
	var spacing = 10.0
	
	for i in range(total_emitters_count):
		var ix = i % side
		var iz = int(i / side)
		var pos = Vector3((ix - side * 0.5) * spacing, 0.0, (iz - side * 0.5) * spacing)
		
		var inst = EventInstanceClass.new(def)
		inst.set_position(pos)
		inst.play()
		instances.append(inst)
		
	update_frame(0.016)

## Advances frame, moves listener and resolves voice stealing.
func update_frame(delta: float, new_listener_pos: Vector3 = Vector3.ZERO) -> void:
	listener_position = new_listener_pos
	
	for inst in instances:
		inst.update_parameters(delta)
		
	if pool:
		pool.resolve_voice_stealing(instances, listener_position, delta)

func get_active_physical_count() -> int:
	return pool.get_active_physical_count() if pool else 0

func get_active_virtual_count() -> int:
	return pool.get_active_virtual_count(instances) if pool else 0
