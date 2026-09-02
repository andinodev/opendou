class_name OpenDouAIHearing3D
extends Node3D

## Un oido para la IA (Fase 10): consulta la sonoridad de cada voz en su posicion y emite
## sound_heard una vez por voz cuando cruza el umbral hacia arriba; si baja y vuelve a subir,
## otra vez. Las voces terminadas se olvidan.

signal sound_heard(event_name: StringName, loudness_db: float, from_position: Vector3)

const AudibleVoiceMonitorClass = preload("res://addons/opendou/runtime/audible_voice_monitor.gd")

@export var threshold_db: float = -30.0
@export_range(0.01, 2.0, 0.01) var poll_interval_sec: float = 0.1
## Con rayos (oclusion por geometria fisica) o sin ellos (solo distancia y grafo de salas).
@export var use_raycasts: bool = true

## Manager explicito; sin el, el autoload /root/OpenDou o el primero que haya en el arbol.
var manager_override: Node = null

var _timer: float = 0.0
var _heard_ids: Dictionary = {}   # instance_id -> true mientras siga por encima
var _last: Array[Dictionary] = []

func set_manager(manager: Node) -> void:
	manager_override = manager

## La ultima consulta completa, para depurar y para la suite.
func get_last_heard() -> Array[Dictionary]:
	return _last

func _find_manager():
	if manager_override != null and is_instance_valid(manager_override):
		return manager_override
	var m = get_node_or_null("/root/OpenDou")
	if m != null:
		return m
	var found = AudibleVoiceMonitorClass._find_managers(get_tree())
	return found[0] if not found.is_empty() else null

func _process(delta: float) -> void:
	_timer += delta
	if _timer < poll_interval_sec:
		return
	_timer = 0.0
	var manager = _find_manager()
	if manager == null:
		return
	var w3d: World3D = get_world_3d() if use_raycasts else null
	_last = manager.get_loudness_at(global_position, w3d)
	var alive: Dictionary = {}
	for e in _last:
		var id: int = e.instance.get_instance_id()
		alive[id] = true
		if e.loudness_db >= threshold_db:
			if not _heard_ids.has(id):
				_heard_ids[id] = true
				sound_heard.emit(e.event_name, e.loudness_db, e.from_position)
		else:
			_heard_ids.erase(id)
	for id in _heard_ids.keys():
		if not alive.has(id):
			_heard_ids.erase(id)
