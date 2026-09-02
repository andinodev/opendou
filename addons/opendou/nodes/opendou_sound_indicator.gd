class_name OpenDouSoundIndicator
extends Control

## HUD de accesibilidad (Fase 10): un anillo con un punto por sonido audible, en la
## direccion relativa al frente del oyente. Lee lo que el manager ya sabe de cada voz.

const AudibleVoiceMonitorClass = preload("res://addons/opendou/runtime/audible_voice_monitor.gd")

@export var max_items: int = 6
@export var min_db_threshold: float = -40.0
@export var ring_radius_px: float = 80.0
@export_range(0.01, 1.0, 0.01) var poll_interval: float = 0.1

## Manager explicito; sin el, el autoload /root/OpenDou o el primero que haya en el arbol.
var manager_override: Node = null

var _indicators: Array[Dictionary] = []
var _timer: float = 0.0

func _process(delta: float) -> void:
	_timer += delta
	if _timer < poll_interval:
		return
	_timer = 0.0
	_refresh()
	queue_redraw()

## Devuelve [{event_name, angle_rad, level_db}]; angulo 0 = delante, +pi/2 = derecha.
func get_indicators() -> Array[Dictionary]:
	return _indicators

func set_manager(manager: Node) -> void:
	manager_override = manager

func _find_manager():
	if manager_override != null and is_instance_valid(manager_override):
		return manager_override
	var m = get_node_or_null("/root/OpenDou")
	if m != null:
		return m
	var found = AudibleVoiceMonitorClass._find_managers(get_tree())
	return found[0] if not found.is_empty() else null

func _refresh() -> void:
	_indicators.clear()
	var manager = _find_manager()
	if manager == null:
		return
	var listener_pos: Vector3 = manager.active_listener_position
	var inv: Basis = manager.active_listener_basis.inverse()
	for inst in manager.active_instances:
		if inst == null or not inst.has_spatial_position or not inst.is_playing():
			continue
		var level: float = inst.calculated_volume_db
		if level < min_db_threshold:
			continue
		var local: Vector3 = inv * (inst.emitter_position - listener_pos)
		var angle: float = atan2(local.x, -local.z)
		var name: StringName = inst.definition.event_name if inst.definition != null else &""
		_indicators.append({"event_name": name, "angle_rad": angle, "level_db": level})
	_indicators.sort_custom(func(x, y): return x.level_db > y.level_db)
	if _indicators.size() > max_items:
		_indicators.resize(max_items)

func _draw() -> void:
	var center: Vector2 = size * 0.5
	draw_arc(center, ring_radius_px, 0.0, TAU, 48, Color(1, 1, 1, 0.25), 1.5)
	for it in _indicators:
		var p: Vector2 = center + Vector2(sin(it.angle_rad), -cos(it.angle_rad)) * ring_radius_px
		var r: float = clampf(4.0 + (it.level_db + 40.0) * 0.2, 3.0, 12.0)
		draw_circle(p, r, Color(1.0, 0.85, 0.3, 0.9))
