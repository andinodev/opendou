class_name DemoDynamicOcclusion
extends Node3D

## Demo 05: Dynamic Obstacle Raycast Occlusion & Slew-Rate Smoothing (Moving Obstacles)

const OcclusionManagerClass = preload("res://addons/opendou/runtime/spatial/occlusion_manager.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")

var occlusion_mgr: OcclusionManager
var event_instance: EventInstance

var emitter_pos: Vector3 = Vector3(0.0, 0.0, 0.0)
var listener_pos: Vector3 = Vector3(20.0, 0.0, 0.0)

# Moving obstacle position along Z axis (-10 to +10)
var obstacle_z_pos: float = 0.0
var obstacle_width: float = 6.0

func _ready() -> void:
	setup_occlusion_demo()

func setup_occlusion_demo() -> void:
	occlusion_mgr = OcclusionManagerClass.new()
	
	var def = AudioEventDefClass.new(&"Radio_Emitter")
	def.base_volume_db = 0.0
	def.is_looping = true
	
	event_instance = EventInstanceClass.new(def)
	event_instance.set_position(emitter_pos)
	event_instance.play()

## Updates the moving obstacle position and simulates multi-ray intersections.
func update_obstacle_step(delta: float, obs_z: float) -> void:
	obstacle_z_pos = obs_z
	
	# Ray 1: Center ray (Z = 0)
	# Ray 2: Left ray (Z = -2)
	# Ray 3: Right ray (Z = +2)
	var ray_offsets = [-2.0, 0.0, 2.0]
	var ray_hits: Array[bool] = []
	
	for offset in ray_offsets:
		# Check if ray passes through obstacle bounds
		var hit = abs(offset - obstacle_z_pos) < (obstacle_width * 0.5)
		ray_hits.append(hit)
		
	var occ_res = occlusion_mgr.evaluate_occlusion(emitter_pos, listener_pos, ray_hits)
	event_instance.set_target_lpf(occ_res.target_lpf, occ_res.volume_attenuation_db)
	event_instance.update_parameters(delta)

func get_current_lpf() -> float:
	return event_instance.current_spatial_lpf if event_instance else 20000.0

func get_current_attenuation_db() -> float:
	return event_instance.occlusion_attenuation_db if event_instance else 0.0
