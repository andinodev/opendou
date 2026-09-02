class_name TestVirtualTracking
extends RefCounted

const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")
const VoicePoolManagerClass = preload("res://addons/opendou/runtime/voice_pool_manager.gd")
const NativePlayerPoolClass = preload("res://addons/opendou/runtime/native_player_pool.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

static func run_all() -> Array[String]:
	# Un AudioEventDef sin stream ya no obtiene canal fisico: conceder hardware
	# para emitir silencio no tiene sentido. Los tests que afirman que una voz es
	# fisica necesitan por tanto una voz que pueda sonar de verdad.
	var _test_tone := AudioSynthesizerClass.create_tone(440.0, 0.1, 0.5, false)
	var failures: Array[String] = []
	
	# Test 1: Pitch-scaled virtual time advancement
	var def_pitch = AudioEventDefClass.new(&"Motor_RPM", _test_tone)
	def_pitch.virtualization_mode = AudioEventDefClass.VirtualizationMode.VIRTUAL_ELAPSED_TIME
	var inst_pitch = EventInstanceClass.new(def_pitch)
	inst_pitch.calculated_pitch_scale = 1.5 # 50% faster
	inst_pitch.play() # Starts in STATE_VIRTUAL
	
	inst_pitch.advance_virtual_time(2.0) # 2 sec * 1.5 pitch = 3.0 sec
	if not is_equal_approx(inst_pitch.logical_playback_position, 3.0):
		failures.append("Test 1 Failed: Pitch-scaled virtual time expected 3.0s, got %f" % inst_pitch.logical_playback_position)
		
	# Test 2: Looping Modulo Wrapping
	var def_loop = AudioEventDefClass.new(&"Ambient_River", _test_tone)
	def_loop.stream_length = 10.0
	def_loop.is_looping = true
	def_loop.virtualization_mode = AudioEventDefClass.VirtualizationMode.VIRTUAL_ELAPSED_TIME
	var inst_loop = EventInstanceClass.new(def_loop)
	inst_loop.play()
	
	inst_loop.advance_virtual_time(23.5) # 23.5 % 10.0 = 3.5s
	if not is_equal_approx(inst_loop.logical_playback_position, 3.5):
		failures.append("Test 2 Failed: Loop wrapping expected 3.5s, got %f" % inst_loop.logical_playback_position)
		
	# Test 3: Non-Looping Natural Auto-Expiration
	var def_oneshot = AudioEventDefClass.new(&"Voice_Bark", _test_tone)
	def_oneshot.stream_length = 4.0
	def_oneshot.is_looping = false
	def_oneshot.virtualization_mode = AudioEventDefClass.VirtualizationMode.VIRTUAL_ELAPSED_TIME
	var inst_oneshot = EventInstanceClass.new(def_oneshot)
	inst_oneshot.play()
	
	inst_oneshot.advance_virtual_time(5.0) # Exceeds 4.0s duration -> should stop
	if inst_oneshot.voice_state != EventInstanceClass.VoiceState.STATE_STOPPED or inst_oneshot.is_playing():
		failures.append("Test 3 Failed: Non-looping virtual sound should be STATE_STOPPED after duration expires")
		
	# Test 4: VIRTUAL_RESUME Mode (Frozen Position)
	var def_dialogue = AudioEventDefClass.new(&"Hero_Dialogue", _test_tone)
	def_dialogue.virtualization_mode = AudioEventDefClass.VirtualizationMode.VIRTUAL_RESUME
	var inst_dialogue = EventInstanceClass.new(def_dialogue)
	inst_dialogue.play()
	inst_dialogue.logical_playback_position = 1.25 # Stored position
	
	inst_dialogue.advance_virtual_time(10.0) # Should NOT add time in RESUME mode
	if not is_equal_approx(inst_dialogue.logical_playback_position, 1.25):
		failures.append("Test 4 Failed: VIRTUAL_RESUME should freeze logical position, got %f" % inst_dialogue.logical_playback_position)
		
	# Test 5: Dynamic Bus Routing on Devirtualization
	var pool = VoicePoolManagerClass.new(1)
	# Una voz solo puede volverse fisica si hay un reproductor real que la sirva.
	pool.set_player_pool(NativePlayerPoolClass.new(64))
	var def_sfx = AudioEventDefClass.new(&"Laser", _test_tone)
	def_sfx.target_bus = &"SFX_Weapons"
	var inst_sfx = EventInstanceClass.new(def_sfx)
	inst_sfx.play()
	
	pool.resolve_voice_stealing([inst_sfx], Vector3.ZERO, 0.016)
	
	if inst_sfx.voice_state != EventInstanceClass.VoiceState.STATE_PHYSICAL:
		failures.append("Test 5a Failed: Instance should be physical")
	elif inst_sfx.assigned_channel_id < 0:
		failures.append("Test 5b Failed: Instance assigned channel ID invalid")
	else:
		var ch = pool.channels[inst_sfx.assigned_channel_id]
		if ch.target_bus != &"SFX_Weapons":
			failures.append("Test 5c Failed: Mercenary channel target_bus expected 'SFX_Weapons', got '%s'" % str(ch.target_bus))
			
	# El pool de reproductores es un Node: liberarlo es responsabilidad de quien
	# lo inyecta, o el trinquete de fugas lo detecta.
	pool.player_pool.free()
	return failures
