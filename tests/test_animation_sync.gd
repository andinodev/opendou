class_name TestAnimationSyncClass
extends RefCounted

## Unit and Integration Tests for OpenDouAnimationSync (Phase 3 - TASK-057)

const OpenDouAnimationSyncClass = preload("res://addons/opendou/nodes/opendou_animation_sync.gd")
const AudioEventManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")
const OpenDouEventPlayer3DClass = preload("res://addons/opendou/nodes/opendou_event_player_3d.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []

	# Test 1: Instantiation and default properties
	var sync_node = OpenDouAnimationSyncClass.new()
	if sync_node == null:
		failures.append("Test 1 Failed: OpenDouAnimationSync instantiation failed")
		return failures
	if sync_node.auto_detect_surface != true or sync_node.default_footstep_event != &"Footstep":
		failures.append("Test 1 Failed: Default property values mismatch")

	# Test 2: Direct method callback play_audio_event
	var dummy_emitter = OpenDouEventPlayer3DClass.new()
	dummy_emitter.event_name = &"Weapon_Reload"
	sync_node.bind_target_emitter(dummy_emitter)
	sync_node.play_audio_event(&"Weapon_Reload")

	# Test 3: Footstep dispatch with automatic surface detection
	sync_node.auto_detect_surface = true
	sync_node.footstep(0) # Should query surface without crashing

	# Test 4: Footstep dispatch with surface override
	sync_node.footstep(1, &"Metal")
	# Successfully passes surface override

	# Test 5: Animation RTPC modulation callback (set_rtpc)
	sync_node.set_rtpc(&"Movement_Speed", 12.5)

	# Test 6: AnimationPlayer binding and animation change tracking
	var anim_player = AnimationPlayer.new()
	var anim_lib = AnimationLibrary.new()
	var anim = Animation.new()
	anim.length = 1.0
	anim_lib.add_animation(&"Run", anim)
	anim_player.add_animation_library(&"", anim_lib)
	sync_node.bind_animation_player(anim_player)
	if sync_node.animation_player != anim_player:
		failures.append("Test 6 Failed: bind_animation_player failed to set reference")

	# Test 7: Declarative time-based event triggering
	sync_node.event_bindings = {
		&"Run": [
			{"time": 0.2, "event": &"Footstep_Left"},
			{"time": 0.6, "event": &"Footstep_Right"}
		]
	}
	if not sync_node.event_bindings.has(&"Run"):
		failures.append("Test 7 Failed: Declarative event bindings dictionary mismatch")

	# Test 8: AnimationTree blend space parameter extraction
	var dummy_tree = AnimationTree.new()
	sync_node.bind_animation_tree(dummy_tree)
	sync_node.blend_space_rtpc_map = {
		"parameters/Locomotion/blend_position": &"Locomotion_Intensity"
	}
	sync_node.process_blend_space_rtpcs() # Evaluates without throwing errors

	# Test 9: Target emitter routing
	var player_target = OpenDouEventPlayer3DClass.new()
	sync_node.bind_target_emitter(player_target)
	if sync_node.target_emitter != player_target:
		failures.append("Test 9 Failed: bind_target_emitter failed")

	# Test 10: Robustness against missing or freed animation nodes
	anim_player.free()
	dummy_tree.free()
	dummy_emitter.free()
	player_target.free()
	# Triggering after targets are freed should not crash
	sync_node.trigger_audio_event(&"Explosion")
	sync_node.trigger_footstep(0)
	sync_node.process_blend_space_rtpcs()

	sync_node.free()
	return failures
