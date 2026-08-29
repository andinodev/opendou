@tool
class_name AudioMixSnapshot
extends Resource

## Data resource representing a snapshot profile of global mix buses (Volume dB, LPF cutoff Hz, HPF cutoff Hz, Sends, Mutes).

@export var snapshot_name: StringName = &"Default"
@export var default_blend_time: float = 1.0
@export var default_transition_type: Tween.TransitionType = Tween.TRANS_SINE
@export var default_ease_type: Tween.EaseType = Tween.EASE_OUT

## Dictionary of bus configurations:
## {
##   &"Master": { "volume_db": 0.0, "lpf_hz": 20000.0, "hpf_hz": 20.0, "mute": false },
##   &"Music": { "volume_db": -6.0, "lpf_hz": 1500.0, "hpf_hz": 20.0, "mute": false },
##   &"SFX": { "volume_db": 0.0, "lpf_hz": 20000.0, "hpf_hz": 20.0, "mute": false }
## }
@export var bus_settings: Dictionary = {}

func _init(p_name: StringName = &"Default", p_settings: Dictionary = {}, p_blend_time: float = 1.0) -> void:
	snapshot_name = p_name
	bus_settings = p_settings
	default_blend_time = p_blend_time

## Sets configuration for a specific audio bus.
func set_bus_setting(bus_name: StringName, volume_db: float = 0.0, lpf_hz: float = 20000.0, hpf_hz: float = 20.0, mute: bool = false) -> void:
	bus_settings[bus_name] = {
		"volume_db": volume_db,
		"lpf_hz": lpf_hz,
		"hpf_hz": hpf_hz,
		"mute": mute
	}

## Gets setting dictionary for a given bus, falling back to neutral defaults.
func get_bus_setting(bus_name: StringName) -> Dictionary:
	if bus_settings.has(bus_name):
		return bus_settings[bus_name]
	return {
		"volume_db": 0.0,
		"lpf_hz": 20000.0,
		"hpf_hz": 20.0,
		"mute": false
	}
