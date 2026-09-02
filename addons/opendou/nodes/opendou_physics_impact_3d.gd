@tool
class_name OpenDouPhysicsImpact3D
extends Node3D

## Impactos fisicos sin un script por cuerpo (Fase 11). Hijo de un RigidBody3D: al chocar lee
## el material del otro cuerpo (surface_type), la velocidad normal relativa y la masa, y
## postea el evento con el switch de material y dos RTPC locales.

signal impact_posted(speed: float, mass: float, material: StringName, position: Vector3)

const AudibleVoiceMonitorClass = preload("res://addons/opendou/runtime/audible_voice_monitor.gd")
const SURFACE_KEYWORDS: Array[String] = ["metal", "water", "wood", "glass", "concrete", "tile", "foliage", "stone", "mud", "asphalt", "grass"]

@export var event_name: StringName = &""
@export var event_def: AudioEventDef = null
## Por debajo de esta velocidad normal relativa (m/s), nada.
@export_range(0.0, 50.0, 0.05) var min_speed_mps: float = 0.5
## Recarga entre impactos de este cuerpo.
@export_range(0.0, 5.0, 0.01) var cooldown_sec: float = 0.1
@export var material_switch_group: StringName = &"Material"
@export var force_rtpc: StringName = &"ImpactForce"
@export var mass_rtpc: StringName = &"ImpactMass"
@export var default_material: StringName = &"Concrete"

var last_impact: Dictionary = {}
var _manager: Node = null
var _body: RigidBody3D = null
var _last_time_ms: int = -1000000
## Velocidad al empezar el paso de fisica: cuando llega body_entered el choque ya la resolvio.
var _prev_velocity: Vector3 = Vector3.ZERO

func set_event_manager(manager: Node) -> void:
	_manager = manager

func _find_manager():
	if _manager != null and is_instance_valid(_manager):
		return _manager
	var m = get_node_or_null("/root/OpenDou")
	if m != null:
		return m
	var found = AudibleVoiceMonitorClass._find_managers(get_tree())
	return found[0] if not found.is_empty() else null

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_body = get_parent() as RigidBody3D
	if _body == null:
		push_warning("[OpenDou] %s tiene que ser hijo de un RigidBody3D" % name)
		return
	_body.contact_monitor = true
	_body.max_contacts_reported = maxi(_body.max_contacts_reported, 4)
	if not _body.body_entered.is_connected(_on_body_entered):
		_body.body_entered.connect(_on_body_entered)

func _physics_process(_delta: float) -> void:
	if _body != null:
		_prev_velocity = _body.linear_velocity

## Material del otro cuerpo: metadatos, palabras clave del nombre, o el defecto.
static func material_of(body: Node, fallback: StringName) -> StringName:
	if body == null:
		return fallback
	if body.has_meta("surface_type"):
		return StringName(str(body.get_meta("surface_type")))
	var lower: String = body.name.to_lower()
	for k in SURFACE_KEYWORDS:
		if k in lower:
			return StringName(k.capitalize())
	return fallback

func _on_body_entered(other: Node) -> void:
	if _body == null:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_time_ms < int(cooldown_sec * 1000.0):
		return
	# Normal y punto de contacto: el estado directo del cuerpo los tiene durante el paso de
	# fisica en que se emite body_entered. Si no aparece el contacto, se aproxima.
	var normal: Vector3 = Vector3.ZERO
	var point: Vector3 = _body.global_position
	var state := PhysicsServer3D.body_get_direct_state(_body.get_rid())
	if state != null:
		for i in range(state.get_contact_count()):
			if state.get_contact_collider_object(i) == other:
				normal = state.get_contact_local_normal(i)
				point = state.get_contact_collider_position(i)
				break
	if normal.is_zero_approx():
		if other is Node3D:
			normal = (other.global_position - _body.global_position).normalized()
		if normal.is_zero_approx():
			normal = Vector3.UP
	var other_v: Vector3 = other.linear_velocity if other is RigidBody3D else Vector3.ZERO
	var speed: float = absf((_prev_velocity - other_v).dot(normal))
	if speed < min_speed_mps:
		return
	var manager = _find_manager()
	if manager == null:
		return
	_last_time_ms = now
	var material: StringName = material_of(other, default_material)
	if manager.sync_manager != null and not material_switch_group.is_empty():
		manager.sync_manager.set_switch(material_switch_group, material, self)
	var inst = null
	if event_def != null:
		inst = manager.post_event(event_def, self)
	elif not event_name.is_empty():
		inst = manager.post_event(event_name, self)
	if inst != null:
		inst.set_position(point)
		inst.set_parameter(force_rtpc, speed, true)
		inst.set_parameter(mass_rtpc, _body.mass, true)
	last_impact = {"speed": speed, "mass": _body.mass, "material": material, "position": point}
	impact_posted.emit(speed, _body.mass, material, point)
