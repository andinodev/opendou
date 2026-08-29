class_name AHDSRState
extends RefCounted

## Dynamic runtime evaluation state for an AHDSR envelope generator.

enum State {
	ATTACK,
	HOLD,
	DECAY,
	SUSTAIN,
	RELEASE,
	IDLE
}

var attack_time: float = 0.1
var hold_time: float = 0.0
var decay_time: float = 0.2
var sustain_level: float = 0.8
var release_time: float = 0.3

var current_state: State = State.ATTACK
var timer: float = 0.0
var current_output: float = 0.0
var release_start_output: float = 0.0

func _init(p_attack: float = 0.1, p_hold: float = 0.0, p_decay: float = 0.2, p_sustain: float = 0.8, p_release: float = 0.3) -> void:
	attack_time = maxf(0.001, p_attack)
	hold_time = maxf(0.0, p_hold)
	decay_time = maxf(0.001, p_decay)
	sustain_level = clampf(p_sustain, 0.0, 1.0)
	release_time = maxf(0.001, p_release)
	current_state = State.ATTACK
	timer = 0.0
	current_output = 0.0

## Advances envelope state machine and returns output gain [0.0, 1.0].
func process(delta: float, is_key_on: bool) -> float:
	if not is_key_on and current_state != State.RELEASE and current_state != State.IDLE:
		current_state = State.RELEASE
		timer = 0.0
		release_start_output = current_output
		
	var rem: float = delta
	while rem > 0.0:
		match current_state:
			State.ATTACK:
				var needed = attack_time - timer
				if rem >= needed:
					rem -= needed
					timer = 0.0
					current_output = 1.0
					current_state = State.HOLD if hold_time > 0.0 else State.DECAY
				else:
					timer += rem
					current_output = clampf(timer / attack_time, 0.0, 1.0)
					rem = 0.0
			State.HOLD:
				var needed = hold_time - timer
				if rem >= needed:
					rem -= needed
					timer = 0.0
					current_output = 1.0
					current_state = State.DECAY
				else:
					timer += rem
					current_output = 1.0
					rem = 0.0
			State.DECAY:
				var needed = decay_time - timer
				if rem >= needed:
					rem -= needed
					timer = 0.0
					current_output = sustain_level
					current_state = State.SUSTAIN
				else:
					timer += rem
					current_output = lerpf(1.0, sustain_level, timer / decay_time)
					rem = 0.0
			State.SUSTAIN:
				current_output = sustain_level
				rem = 0.0
			State.RELEASE:
				var needed = release_time - timer
				if rem >= needed:
					rem -= needed
					timer = 0.0
					current_output = 0.0
					current_state = State.IDLE
				else:
					timer += rem
					current_output = lerpf(release_start_output, 0.0, timer / release_time)
					rem = 0.0
			State.IDLE:
				current_output = 0.0
				rem = 0.0
				
	return current_output
