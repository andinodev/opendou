class_name TestVoicePool
extends RefCounted

const VoicePoolManagerClass = preload("res://addons/opendou/runtime/voice_pool_manager.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Setup VoicePool with only 2 channels for deterministic testing
	var pool = VoicePoolManagerClass.new(2)
	
	var def_low = AudioEventDefClass.new(&"Footstep")
	def_low.base_priority = 20.0
	
	var def_high = AudioEventDefClass.new(&"Explosion")
	def_high.base_priority = 90.0
	
	var inst1 = EventInstanceClass.new(def_low)
	var inst2 = EventInstanceClass.new(def_low)
	var inst3 = EventInstanceClass.new(def_high)
	
	inst1.play()
	inst2.play()
	inst3.play()
	
	var active_list: Array[EventInstance] = [inst1, inst2, inst3]
	
	# Test 1: Pool capacity & voice stealing (inst3 should be physical, one inst of low should be physical, one virtual)
	pool.resolve_voice_stealing(active_list, Vector3.ZERO, 0.1)
	
	if pool.get_active_physical_count() != 2:
		failures.append("Test 1 Failed: Expected exactly 2 physical voices, got %d" % pool.get_active_physical_count())
		
	if inst3.voice_state != EventInstanceClass.VoiceState.STATE_PHYSICAL:
		failures.append("Test 1 Failed: High priority Explosion should be PHYSICAL")
		
	# Test 2: Distance Virtualization
	var def_distant = AudioEventDefClass.new(&"Distant_Gunshot")
	def_distant.base_priority = 100.0
	var inst_distant = EventInstanceClass.new(def_distant)
	inst_distant.set_position(Vector3(500.0, 0.0, 0.0))
	inst_distant.max_distance = 100.0 # 500m is way beyond 100m
	inst_distant.play()
	
	var distant_list: Array[EventInstance] = [inst_distant]
	pool.resolve_voice_stealing(distant_list, Vector3.ZERO, 0.1)
	
	if inst_distant.voice_state == EventInstanceClass.VoiceState.STATE_PHYSICAL:
		failures.append("Test 2 Failed: Out of range event should NOT be PHYSICAL (expected VIRTUAL/weight 0)")
		
	# Test 3: Virtual Elapsed Time Tracking
	var inst_virtual = EventInstanceClass.new(def_low)
	inst_virtual.play()
	inst_virtual.voice_state = EventInstanceClass.VoiceState.STATE_VIRTUAL
	inst_virtual.advance_virtual_time(0.5)
	
	if not is_equal_approx(inst_virtual.logical_playback_position, 0.5):
		failures.append("Test 3 Failed: Virtual time tracking expected 0.5s, got %f" % inst_virtual.logical_playback_position)
		
	# Test 4: VirtualizationMode.VIRTUAL_KILL_VOICE
	var pool_tiny = VoicePoolManagerClass.new(1)
	var def_kill = AudioEventDefClass.new(&"Debris")
	def_kill.base_priority = 5.0
	
	var inst_kill = EventInstanceClass.new(def_kill)
	inst_kill.virtualization_mode = EventInstanceClass.VirtualizationMode.VIRTUAL_KILL_VOICE
	inst_kill.play()
	
	var inst_hero = EventInstanceClass.new(def_high)
	inst_hero.play()
	
	var test_kill_list: Array[EventInstance] = [inst_hero, inst_kill]
	pool_tiny.resolve_voice_stealing(test_kill_list, Vector3.ZERO, 0.1)
	
	if inst_kill.voice_state != EventInstanceClass.VoiceState.STATE_KILLED:
		failures.append("Test 4 Failed: Event with KILL_VOICE mode should be STATE_KILLED when losing pool channel")
		
	return failures
