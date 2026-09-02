class_name OpenDouEnvironmentState
extends RefCounted

## Estado efectivo del entorno para el oyente, resuelto cada cuadro a partir de los
## volumenes que lo contienen (Fase 10). Medio y viento: el de mayor prioridad; descarte: la
## union. La oclusion parcial y la superficie no son estado del oyente y se consultan aparte.

var speed_of_sound: float = 343.0
var medium_lowpass_hz: float = 20000.0
var medium_pitch_scale: float = 1.0
var medium_snapshot: StringName = &""
var wind_velocity: Vector3 = Vector3.ZERO   # ya con la rafaga aplicada
var wind_min_distance_m: float = 20.0
var culled_buses: Dictionary = {}           # StringName -> true
var inside: Array = []                      # volumenes que contienen al oyente este cuadro
## True el cuadro en que cambio el medio (velocidad, filtro, tono o instantanea).
var medium_changed: bool = false
var _time: float = 0.0

func update(volumes: Array, listener_pos: Vector3, delta: float) -> void:
	_time += delta
	inside.clear()
	culled_buses.clear()
	var medium = null
	var medium_prio: int = -2147483648
	var wind = null
	var wind_prio: int = -2147483648
	for v in volumes:
		if v == null or not is_instance_valid(v) or v.environment == null or not v.is_inside_tree():
			continue
		if not v.contains_point(listener_pos):
			continue
		inside.append(v)
		var env = v.environment
		if env.medium_enabled and v.volume_priority > medium_prio:
			medium = env
			medium_prio = v.volume_priority
		if env.wind_enabled and v.volume_priority > wind_prio:
			wind = env
			wind_prio = v.volume_priority
		if env.cull_enabled:
			for b in env.cull_buses:
				culled_buses[b] = true
	var new_c: float = medium.speed_of_sound_mps if medium != null else 343.0
	var new_lpf: float = medium.medium_lowpass_hz if medium != null else 20000.0
	var new_pitch: float = medium.medium_pitch_scale if medium != null else 1.0
	var new_snap: StringName = medium.medium_snapshot if medium != null else &""
	medium_changed = not is_equal_approx(new_c, speed_of_sound) or not is_equal_approx(new_lpf, medium_lowpass_hz) \
		or not is_equal_approx(new_pitch, medium_pitch_scale) or new_snap != medium_snapshot
	speed_of_sound = new_c
	medium_lowpass_hz = new_lpf
	medium_pitch_scale = new_pitch
	medium_snapshot = new_snap
	if wind != null:
		var gust: float = 1.0 + wind.wind_gust_strength * sin(TAU * wind.wind_gust_rate_hz * _time)
		wind_velocity = wind.wind_velocity * gust
		wind_min_distance_m = wind.wind_min_distance_m
	else:
		wind_velocity = Vector3.ZERO

func has_wind() -> bool:
	return wind_velocity.length_squared() > 1e-6

func is_culled(bus: StringName) -> bool:
	return culled_buses.has(bus)
