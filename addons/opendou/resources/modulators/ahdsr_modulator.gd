@tool
class_name AHDSRModulator
extends AudioModulator

## AHDSR (Attack, Hold, Decay, Sustain, Release) envelope modulator.

const AHDSRStateClass = preload("res://addons/opendou/runtime/modulators/ahdsr_state.gd")

@export var attack_time: float = 0.1
@export var hold_time: float = 0.0
@export var decay_time: float = 0.2
@export var sustain_level: float = 0.8
@export var release_time: float = 0.3

func _init(p_target: StringName = &"volume_db", p_attack: float = 0.1, p_hold: float = 0.0, p_decay: float = 0.2, p_sustain: float = 0.8, p_release: float = 0.3) -> void:
	target_property = p_target
	attack_time = p_attack
	hold_time = p_hold
	decay_time = p_decay
	sustain_level = p_sustain
	release_time = p_release
	depth = 1.0

func create_runtime_state() -> RefCounted:
	return AHDSRStateClass.new(attack_time, hold_time, decay_time, sustain_level, release_time)
