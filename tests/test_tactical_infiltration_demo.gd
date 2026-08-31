class_name TestTacticalInfiltrationDemoClass
extends RefCounted

## Verification Test Suite for Demo 09: Tactical Infiltration Showcase (TASK-058)

const InfiltrationDemoScene = preload("res://scenes/demos/09_tactical_infiltration/demo_tactical_infiltration.tscn")
const InfiltrationDemoScript = preload("res://scenes/demos/09_tactical_infiltration/demo_tactical_infiltration.gd")
const TacticalEnemyClass = preload("res://scenes/demos/09_tactical_infiltration/tactical_enemy.gd")
const DemoHubClass = preload("res://scenes/demos/demo_hub.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []

	# Test 1: Scene Instantiation & Tree Validation of all 13 OpenDou Nodes
	var scene_instance = InfiltrationDemoScene.instantiate()
	if scene_instance == null:
		failures.append("Test 1 Failed: Could not instantiate demo_tactical_infiltration.tscn")
		return failures

	var acoustic_bake = scene_instance.get_node_or_null("Acoustic_Processor")
	var room_cavern = scene_instance.get_node_or_null("Environment/Outer_Cavern")
	var cavern_reflector = scene_instance.get_node_or_null("Environment/Outer_Cavern/Cavern_Reflector")
	var underground_river = scene_instance.get_node_or_null("Environment/Outer_Cavern/Underground_River")
	var toxic_zone = scene_instance.get_node_or_null("Environment/Toxic_Zone")
	var toxic_spores = scene_instance.get_node_or_null("Environment/Toxic_Zone/Toxic_Spores")
	var access_portal = scene_instance.get_node_or_null("Environment/Bunker_Complex/Access_Portal")
	var blast_door_body = scene_instance.get_node_or_null("Environment/Bunker_Complex/Access_Portal/Blast_Door_Body")
	var room_bunker = scene_instance.get_node_or_null("Environment/Bunker_Complex/Generator_Room")
	var main_generator = scene_instance.get_node_or_null("Environment/Bunker_Complex/Generator_Room/Main_Generator")
	var player_rig = scene_instance.get_node_or_null("Player_Rig")
	var player_anim_sync = scene_instance.get_node_or_null("Player_Rig/AnimationSync")
	var enemy_rig = scene_instance.get_node_or_null("Characters/Elite_Enemy")
	var enemy_anim_sync = scene_instance.get_node_or_null("Characters/Elite_Enemy/EnemyAnimationSync")
	var voice_emitter = scene_instance.get_node_or_null("Characters/Elite_Enemy/VoiceEmitter")
	var dynamic_music = scene_instance.get_node_or_null("Systems/Dynamic_Soundtrack")
	var acoustic_debugger = scene_instance.get_node_or_null("Systems/Acoustic_Debugger")
	var audible_monitor = scene_instance.get_node_or_null("TacticalHUD/AudibleMonitor")

	if not acoustic_bake or not room_cavern or not cavern_reflector or not underground_river:
		failures.append("Test 1 Failed: Missing core cavern acoustic nodes")
	if not toxic_zone or not toxic_spores or not access_portal or not blast_door_body or not room_bunker or not main_generator:
		failures.append("Test 1 Failed: Missing toxic corridor or bunker generator nodes")
	if not player_rig or not player_anim_sync or not enemy_rig or not enemy_anim_sync or not voice_emitter:
		failures.append("Test 1 Failed: Missing character rigs or animation sync nodes")
	if not dynamic_music or not acoustic_debugger or not audible_monitor:
		failures.append("Test 1 Failed: Missing music player, debugger or audible monitor systems")

	var demo = scene_instance
	if demo.has_method("_init_scene_references"):
		demo._init_scene_references()

	# Test 2: Sector Teleportation Positions
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
	acoustic_bake.bake_geometry(scene_instance)
	if acoustic_bake.get_baked_triangle_count() == 0:
		failures.append("Test 3 Failed: Acoustic Geometry Bake did not extract triangles from scene obstacles")

	# Test 4: Toxic Corridor Gradient RTPC Modulation
	demo.teleport_to_sector(2)
	demo._update_player_locomotion()
	if not is_equal_approx(demo.toxic_tension_value, 0.5):
		failures.append("Test 4 Failed: Toxic tension at sector 2 center should be ~0.50, got %.2f" % demo.toxic_tension_value)

	# Test 5: Blast Door Toggle, Movement & Portal Openness Update
	var init_door_state = demo.is_blast_door_open
	demo.toggle_blast_door()
	if demo.is_blast_door_open == init_door_state or not is_equal_approx(access_portal.open_factor, 0.0):
		failures.append("Test 5 Failed: Closing blast door did not set open_factor to 0.0")
	if blast_door_body.position.y > 0.1:
		failures.append("Test 5 Failed: Closed blast door body should be at y=0.0")

	demo.toggle_blast_door()
	if not is_equal_approx(access_portal.open_factor, 1.0):
		failures.append("Test 5 Failed: Opening blast door did not set open_factor to 1.0")
	if blast_door_body.position.y < 3.0:
		failures.append("Test 5 Failed: Opened blast door body should slide up to y=3.8")

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
	var nearest_pt = main_generator.get_closest_point_to(Vector3(60, 1, 0))
	if nearest_pt == Vector3.ZERO:
		failures.append("Test 7 Failed: Generator multi-position nearest vertex failed")

	# Test 8: Player AnimationSync Callbacks
	player_anim_sync.play_audio_event(&"Footstep")
	player_anim_sync.footstep(0, &"Metal")

	# Test 9: Tactical Enemy AI State Transitions & Weapon Fire
	if enemy_rig is TacticalEnemyClass:
		enemy_rig.target_player = player_rig
		enemy_rig.hear_noise(Vector3(80, 1, 0), 1.5)
		if enemy_rig.current_state != TacticalEnemyClass.State.SUSPICIOUS:
			failures.append("Test 9 Failed: Enemy hearing noise did not enter SUSPICIOUS state")
		enemy_rig.trigger_alert()
		if enemy_rig.current_state != TacticalEnemyClass.State.CHASE:
			failures.append("Test 9 Failed: Enemy trigger_alert did not enter CHASE state")
		enemy_rig._fire_weapon()
		enemy_rig._process_footstep_audio(0.5)

	# Test 10: Ambient Audio Streams & Real-Time Acoustic Filtering
	demo._setup_audio_dsp_buses()
	demo._start_ambient_audio_streams()
	if demo.generator_multi.stream == null or demo.river_spline.stream == null or demo.spore_granular.stream == null:
		failures.append("Test 10 Failed: Ambient audio streams were not initialized")

	demo.teleport_to_sector(1) # Outside in cavern
	demo.is_blast_door_open = false
	access_portal.set_open_factor(0.0)
	demo._update_acoustic_propagation(1.0)
	if demo.generator_filtered_lpf > 500.0:
		failures.append("Test 10 Failed: Closed door should filter generator LPF to ~300Hz, got %.1fHz" % demo.generator_filtered_lpf)
	if demo.generator_attenuation_db > -5.0:
		failures.append("Test 10 Failed: Closed door should attenuate generator volume, got %.1fdB" % demo.generator_attenuation_db)

	demo.teleport_to_sector(3) # Inside bunker with generator
	demo._update_acoustic_propagation(1.0)
	if demo.generator_filtered_lpf < 15000.0:
		failures.append("Test 10 Failed: Inside bunker should hear full 20kHz spectrum, got %.1fHz" % demo.generator_filtered_lpf)
	if demo.generator_attenuation_db < 0.0:
		failures.append("Test 10 Failed: Inside bunker should have full volume (+2dB), got %.1fdB" % demo.generator_attenuation_db)

	# Test 11: HUD Acoustic Debugger Cycle
	demo._on_toggle_acoustics_pressed()
	if demo.debugger_mode != 1:
		failures.append("Test 11 Failed: Debugger mode should cycle to 1")
	demo._on_toggle_acoustics_pressed()
	if demo.debugger_mode != 2:
		failures.append("Test 11 Failed: Debugger mode should cycle to 2")
	demo._on_toggle_acoustics_pressed()
	if demo.debugger_mode != 0:
		failures.append("Test 11 Failed: Debugger mode should cycle back to 0")

	scene_instance.free()
	return failures
