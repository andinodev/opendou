class_name TestTacticalInfiltrationDemoClass
extends RefCounted

## Verification Test Suite for Demo 09: Tactical Infiltration Showcase (TASK-058)

const InfiltrationDemoScene = preload("res://scenes/demos/09_tactical_infiltration/demo_tactical_infiltration.tscn")
const DemoHubClass = preload("res://scenes/demos/demo_hub.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []

	# Test 1: Scene Instantiation & Tree Validation of all 13 OpenDou Nodes
	var demo = InfiltrationDemoScene.instantiate()
	if demo == null:
		failures.append("Test 1 Failed: Could not instantiate demo_tactical_infiltration.tscn")
		return failures

	var acoustic_bake = demo.get_node_or_null("Acoustic_Processor")
	var room_cavern = demo.get_node_or_null("Environment/Outer_Cavern")
	var cavern_reflector = demo.get_node_or_null("Environment/Outer_Cavern/Cavern_Reflector")
	var underground_river = demo.get_node_or_null("Environment/Outer_Cavern/Underground_River")
	var toxic_zone = demo.get_node_or_null("Environment/Toxic_Zone")
	var toxic_spores = demo.get_node_or_null("Environment/Toxic_Zone/Toxic_Spores")
	var access_portal = demo.get_node_or_null("Environment/Bunker_Complex/Access_Portal")
	var room_bunker = demo.get_node_or_null("Environment/Bunker_Complex/Generator_Room")
	var main_generator = demo.get_node_or_null("Environment/Bunker_Complex/Generator_Room/Main_Generator")
	var player_rig = demo.get_node_or_null("Player_Rig")
	var player_anim_sync = demo.get_node_or_null("Player_Rig/AnimationSync")
	var enemy_rig = demo.get_node_or_null("Characters/Elite_Enemy")
	var enemy_anim_sync = demo.get_node_or_null("Characters/Elite_Enemy/EnemyAnimationSync")
	var voice_emitter = demo.get_node_or_null("Characters/Elite_Enemy/VoiceEmitter")
	var dynamic_music = demo.get_node_or_null("Systems/Dynamic_Soundtrack")
	var acoustic_debugger = demo.get_node_or_null("Systems/Acoustic_Debugger")
	var audible_monitor = demo.get_node_or_null("TacticalHUD/AudibleMonitor")

	if not acoustic_bake or not room_cavern or not cavern_reflector or not underground_river:
		failures.append("Test 1 Failed: Missing core cavern acoustic nodes")
	if not toxic_zone or not toxic_spores or not access_portal or not room_bunker or not main_generator:
		failures.append("Test 1 Failed: Missing toxic corridor or bunker generator nodes")
	if not player_rig or not player_anim_sync or not enemy_rig or not enemy_anim_sync or not voice_emitter:
		failures.append("Test 1 Failed: Missing character rigs or animation sync nodes")
	if not dynamic_music or not acoustic_debugger or not audible_monitor:
		failures.append("Test 1 Failed: Missing music player, debugger or audible monitor systems")

	# Test 2: Sector Teleportation Positions
	demo.player = player_rig
	var get_pos = func() -> Vector3: return player_rig.global_position if player_rig.is_inside_tree() else player_rig.position

	demo.teleport_to_sector(1)
	if demo.active_sector_idx != 1 or get_pos.call().distance_to(Vector3(0, 1, 0)) > 0.1:
		failures.append("Test 2 Failed: Sector 1 teleportation mismatch, got %s" % str(get_pos.call()))

	demo.teleport_to_sector(2)
	if demo.active_sector_idx != 2 or get_pos.call().distance_to(Vector3(30, 1, 0)) > 0.1:
		failures.append("Test 2 Failed: Sector 2 teleportation mismatch, got %s" % str(get_pos.call()))

	demo.teleport_to_sector(3)
	if demo.active_sector_idx != 3 or get_pos.call().distance_to(Vector3(60, 1, 0)) > 0.1:
		failures.append("Test 2 Failed: Sector 3 teleportation mismatch, got %s" % str(get_pos.call()))

	demo.teleport_to_sector(4)
	if demo.active_sector_idx != 4 or get_pos.call().distance_to(Vector3(90, 1, 0)) > 0.1:
		failures.append("Test 2 Failed: Sector 4 teleportation mismatch, got %s" % str(get_pos.call()))

	# Test 3: Acoustic Geometry Bake Execution & Extraction
	acoustic_bake.bake_geometry(demo)
	if acoustic_bake.get_baked_triangle_count() == 0:
		failures.append("Test 3 Failed: Acoustic Geometry Bake did not extract triangles from scene obstacles")

	# Test 4: Toxic Corridor Gradient RTPC Modulation
	demo.player = player_rig
	demo.teleport_to_sector(2)
	demo._update_player_locomotion()
	if not is_equal_approx(demo.toxic_tension_value, 0.5):
		failures.append("Test 4 Failed: Toxic tension at sector 2 center should be ~0.50, got %.2f" % demo.toxic_tension_value)

	# Test 5: Blast Door Toggle & Portal Openness Update
	demo.access_portal = access_portal
	var init_door_state = demo.is_blast_door_open
	demo.toggle_blast_door()
	if demo.is_blast_door_open == init_door_state or not is_equal_approx(access_portal.open_factor, 0.0):
		failures.append("Test 5 Failed: Closing blast door did not set open_factor to 0.0")
	demo.toggle_blast_door()
	if not is_equal_approx(access_portal.open_factor, 1.0):
		failures.append("Test 5 Failed: Opening blast door did not set open_factor to 1.0")

	# Test 6: Dynamic Floor Surface Detection
	demo.teleport_to_sector(1)
	demo._update_player_locomotion()
	if demo.active_surface != &"Stone":
		failures.append("Test 6 Failed: Sector 1 floor surface should be Stone, got %s" % str(demo.active_surface))
	demo.teleport_to_sector(3)
	demo._update_player_locomotion()
	if demo.active_surface != &"Metal":
		failures.append("Test 6 Failed: Sector 3 floor surface should be Metal, got %s" % str(demo.active_surface))

	# Test 7: Generator Multi-Position Closest Point Tracking
	demo.generator_multi = main_generator
	var nearest_pt = main_generator.get_closest_point_to(Vector3(60, 1, 0))
	if nearest_pt == Vector3.ZERO:
		failures.append("Test 7 Failed: Generator multi-position nearest vertex failed")

	# Test 8: Player AnimationSync Callbacks
	demo.player_anim_sync = player_anim_sync
	player_anim_sync.play_audio_event(&"Footstep")
	player_anim_sync.footstep(0, &"Metal")

	# Test 9: Enemy Alert Action & Voice Emitter Dispatch
	demo.enemy_anim_sync = enemy_anim_sync
	demo.enemy_rig = enemy_rig
	demo.trigger_enemy_alert()

	# Test 10: HUD Acoustic Debugger Cycle
	demo.acoustic_debugger = acoustic_debugger
	demo._on_toggle_acoustics_pressed()
	if demo.debugger_mode != 1:
		failures.append("Test 10 Failed: Debugger mode should cycle to 1")
	demo._on_toggle_acoustics_pressed()
	if demo.debugger_mode != 2:
		failures.append("Test 10 Failed: Debugger mode should cycle to 2")
	demo._on_toggle_acoustics_pressed()
	if demo.debugger_mode != 0:
		failures.append("Test 10 Failed: Debugger mode should cycle back to 0")

	demo.free()
	return failures
