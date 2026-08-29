class_name TestModulators
extends RefCounted

const AHDSRStateClass = preload("res://addons/opendou/runtime/modulators/ahdsr_state.gd")
const LFOStateClass = preload("res://addons/opendou/runtime/modulators/lfo_state.gd")
const AHDSRModulatorClass = preload("res://addons/opendou/resources/modulators/ahdsr_modulator.gd")
const LFOModulatorClass = preload("res://addons/opendou/resources/modulators/lfo_modulator.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: AHDSR Envelope Lifecycle
	# Attack: 1.0s, Hold: 0.5s, Decay: 1.0s, Sustain: 0.6, Release: 1.0s
	var ahdsr = AHDSRStateClass.new(1.0, 0.5, 1.0, 0.6, 1.0)
	
	# 1a. Mid-Attack (0.5s into 1.0s attack -> gain = 0.5)
	var out_attack = ahdsr.process(0.5, true)
	if not is_equal_approx(out_attack, 0.5):
		failures.append("Test 1a Failed: AHDSR Attack mid expected 0.5, got %f" % out_attack)
		
	# 1b. Complete Attack + Mid Hold (0.5s + 0.25s -> gain = 1.0)
	var out_hold = ahdsr.process(0.75, true)
	if not is_equal_approx(out_hold, 1.0):
		failures.append("Test 1b Failed: AHDSR Hold expected 1.0, got %f" % out_hold)
		
	# 1c. Complete Hold + Mid Decay (0.25s hold + 0.5s decay -> gain = 0.8)
	var out_decay = ahdsr.process(0.75, true)
	if not is_equal_approx(out_decay, 0.8):
		failures.append("Test 1c Failed: AHDSR Decay expected 0.8, got %f" % out_decay)
		
	# 1d. Complete Decay -> Sustain (0.5s decay -> gain = 0.6)
	var out_sustain = ahdsr.process(0.5, true)
	if not is_equal_approx(out_sustain, 0.6):
		failures.append("Test 1d Failed: AHDSR Sustain expected 0.6, got %f" % out_sustain)
		
	# 1e. Release Phase (is_key_on = false, 0.5s into 1.0s release -> 0.3)
	var out_rel = ahdsr.process(0.5, false)
	if not is_equal_approx(out_rel, 0.3):
		failures.append("Test 1e Failed: AHDSR Release expected 0.3, got %f" % out_rel)
		
	# 1f. Full Release -> IDLE (0.5s -> 0.0)
	var out_idle = ahdsr.process(0.5, false)
	if not is_equal_approx(out_idle, 0.0) or ahdsr.current_state != AHDSRStateClass.State.IDLE:
		failures.append("Test 1f Failed: AHDSR should reach IDLE with 0.0 gain")
		
	# Test 2: LFO Waveforms
	# 2a. Sine Wave (Freq 1 Hz, depth 1.0)
	var lfo_sine = LFOStateClass.new(LFOStateClass.Waveform.SINE, 1.0, 1.0, 0.0)
	lfo_sine.process(0.25) # 90 degrees -> sin(PI/2) = 1.0
	if not is_equal_approx(lfo_sine.process(0.0), 1.0):
		failures.append("Test 2a Failed: LFO Sine at 0.25 phase expected 1.0")
		
	# 2b. Square Wave (Freq 1 Hz, depth 1.0)
	var lfo_sq = LFOStateClass.new(LFOStateClass.Waveform.SQUARE, 1.0, 1.0, 0.0)
	var sq_first_half = lfo_sq.process(0.2)
	var sq_second_half = lfo_sq.process(0.4)
	if not is_equal_approx(sq_first_half, 1.0) or not is_equal_approx(sq_second_half, -1.0):
		failures.append("Test 2b Failed: LFO Square expected 1.0 and -1.0")
		
	# Test 3: Integrated EventInstance Modulation
	var event_def = AudioEventDefClass.new(&"Siren_Sound")
	event_def.base_pitch_scale = 1.0
	var lfo_mod = LFOModulatorClass.new(&"pitch_scale", LFOModulatorClass.Waveform.SQUARE, 2.0, 0.2, 0.0)
	event_def.add_modulator(lfo_mod)
	
	var inst = EventInstanceClass.new(event_def)
	inst.play()
	inst.update_parameters(0.1) # Pitch should be 1.0 + 0.2 = 1.2
	
	if not is_equal_approx(inst.calculated_pitch_scale, 1.2):
		failures.append("Test 3 Failed: Integrated LFO pitch modulation expected 1.2, got %f" % inst.calculated_pitch_scale)
		
	return failures
