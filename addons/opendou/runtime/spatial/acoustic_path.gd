class_name AcousticPath
extends RefCounted

## Result of an acoustic spatial pathfinding query between sound emitter and listener.

var virtual_distance: float = 0.0
var accumulated_lpf: float = 20000.0 # Lowest LPF frequency in path (Hz)
var apparent_origin: Vector3 = Vector3.ZERO
var is_direct_los: bool = true
var portals_traversed: Array = []

func _init(p_dist: float = 0.0, p_lpf: float = 20000.0, p_origin: Vector3 = Vector3.ZERO, p_direct: bool = true) -> void:
	virtual_distance = p_dist
	accumulated_lpf = p_lpf
	apparent_origin = p_origin
	is_direct_los = p_direct
	portals_traversed = []
