@tool
class_name AudioDuckingMatrix
extends RefCounted

## Multi-bus sidechain priority ducking matrix for dynamic, click-free attenuation between competing audio categories.

class DuckingRule:
	var source_bus: StringName
	var target_bus: StringName
	var attenuation_db: float = -10.0
	var attack_time_sec: float = 0.05
	var release_time_sec: float = 0.40
	var current_duck_db: float = 0.0
	
	func _init(src: StringName, tgt: StringName, atten: float = -10.0, att: float = 0.05, rel: float = 0.40) -> void:
		source_bus = src
		target_bus = tgt
		attenuation_db = atten
		attack_time_sec = att
		release_time_sec = rel

var rules: Array[DuckingRule] = []
var active_source_buses: Dictionary = {}

func _init() -> void:
	_setup_default_rules()

func _setup_default_rules() -> void:
	# Voice/Dialogue ducks Music (-12dB) and SFX (-4dB)
	add_rule(&"Voice", &"Music", -12.0, 0.04, 0.35)
	add_rule(&"Voice", &"SFX", -4.0, 0.04, 0.25)
	
	# Gunfire / Explosions duck Music (-8dB) and Ambient (-14dB)
	add_rule(&"SFX", &"Music", -8.0, 0.02, 0.30)
	add_rule(&"SFX", &"Ambient", -14.0, 0.02, 0.45)

func add_rule(source_bus: StringName, target_bus: StringName, attenuation_db: float, attack_time: float = 0.05, release_time: float = 0.35) -> void:
	var r = DuckingRule.new(source_bus, target_bus, attenuation_db, attack_time, release_time)
	rules.append(r)

## Signals that a source bus is actively emitting audio (e.g. character is speaking or gun is firing).
func set_bus_active(source_bus: StringName, is_active: bool) -> void:
	active_source_buses[source_bus] = is_active

## Updates continuous ducking envelopes for all target buses.
func update(delta: float) -> void:
	for r in rules:
		var is_active = active_source_buses.get(r.source_bus, false)
		if is_active:
			# Attack
			var rate = absf(r.attenuation_db) / maxf(r.attack_time_sec, 0.001)
			r.current_duck_db = move_toward(r.current_duck_db, r.attenuation_db, rate * delta)
		else:
			# Release
			var rate = absf(r.attenuation_db) / maxf(r.release_time_sec, 0.001)
			r.current_duck_db = move_toward(r.current_duck_db, 0.0, rate * delta)

## Gets total accumulated ducking attenuation (in dB) for a given target bus.
func get_ducking_attenuation_db(target_bus: StringName) -> float:
	var total_duck: float = 0.0
	for r in rules:
		if r.target_bus == target_bus:
			total_duck = minf(total_duck, r.current_duck_db)
	return total_duck
