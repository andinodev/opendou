class_name TestCyberpunkDemo
extends RefCounted

const SCENE_PATH: String = "res://scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn"
const SCRIPT_PATH: String = "res://scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.gd"

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: File existence
	if not ResourceLoader.exists(SCENE_PATH):
		failures.append("Test 1a Failed: demo_cyberpunk_infiltration.tscn does not exist")
		return failures
		
	# Test 2: PackedScene loading
	var scene_res = load(SCENE_PATH)
	if not scene_res or not (scene_res is PackedScene):
		failures.append("Test 1b Failed: demo_cyberpunk_infiltration.tscn failed to load as PackedScene")
		return failures
		
	# Test 3: Scene instantiation and node hierarchy
	var instance = scene_res.instantiate()
	if not instance:
		failures.append("Test 1c Failed: demo_cyberpunk_infiltration scene instantiation failed")
		return failures
		
	# Test 4: Sector geometry presence
	if not instance.has_node("LevelGeometry/Sector1_Rooftop") or not instance.has_node("LevelGeometry/Sector2_ServerRoom"):
		failures.append("Test 1d Failed: Scene missing Sector 1 or Sector 2 geometry nodes")
	if not instance.has_node("LevelGeometry/Sector3_FloodedDrainage") or not instance.has_node("LevelGeometry/Sector4_ExtractionArena"):
		failures.append("Test 1e Failed: Scene missing Sector 3 or Sector 4 geometry nodes")
		
	# Test 5: TacticalHUD CanvasLayer presence
	if not instance.has_node("TacticalHUD"):
		failures.append("Test 1f Failed: Scene missing TacticalHUD CanvasLayer node")
		
	# Test 6: Player controller, Camera3D, and AudioListener3D
	if not instance.has_node("Player") or not instance.has_node("Player/Camera3D") or not instance.has_node("Player/Camera3D/AudioListener3D"):
		failures.append("Test 1g Failed: Scene missing Player, Camera3D, or AudioListener3D")
		
	# Test 7: Emitters presence
	if not instance.has_node("LevelGeometry/Sector1_Rooftop/RainEmitter") or not instance.has_node("LevelGeometry/Sector2_ServerRoom/ServerEmitter"):
		failures.append("Test 1h Failed: Scene missing RainEmitter or ServerEmitter")
	if not instance.has_node("LevelGeometry/Sector3_FloodedDrainage/WaterEmitter") or not instance.has_node("LevelGeometry/Sector4_ExtractionArena/TurretEmitter"):
		failures.append("Test 1i Failed: Scene missing WaterEmitter or TurretEmitter")
		
	# Test 8: Script existence and Coordinator instantiation
	if not ResourceLoader.exists(SCRIPT_PATH):
		failures.append("Test 2a Failed: demo_cyberpunk_infiltration.gd does not exist")
		instance.free()
		return failures
		
	var script_res = load(SCRIPT_PATH)
	if not script_res:
		failures.append("Test 2b Failed: demo_cyberpunk_infiltration.gd failed to load")
		instance.free()
		return failures
		
	var demo = script_res.new()
	if not demo:
		failures.append("Test 2c Failed: Failed to instantiate OpenDouCyberpunkInfiltrationDemo")
		instance.free()
		return failures
		
	# Test 9: Spatial acoustics and 4 acoustic rooms registration
	if demo.spatial_acoustics == null or demo.spatial_acoustics.rooms.size() < 4:
		failures.append("Test 2d Failed: SpatialAcousticsManager not initialized with 4 rooms")
	else:
		if not demo.spatial_acoustics.rooms.has(&"Rooftop_Exterior"):
			failures.append("Test 2e Failed: Missing Rooftop_Exterior room")
		if not demo.spatial_acoustics.rooms.has(&"Server_Room"):
			failures.append("Test 2f Failed: Missing Server_Room room")
		if not demo.spatial_acoustics.rooms.has(&"Flooded_Drainage"):
			failures.append("Test 2g Failed: Missing Flooded_Drainage room")
		if not demo.spatial_acoustics.rooms.has(&"Extraction_Arena"):
			failures.append("Test 2h Failed: Missing Extraction_Arena room")
			
	# Test 10: Server airlock portal registration
	if demo.server_portal == null or demo.server_portal.portal_name != &"Server_Airlock":
		failures.append("Test 2i Failed: Server_Airlock portal not registered")
	elif demo.server_portal.room_a_name != &"Rooftop_Exterior" or demo.server_portal.room_b_name != &"Server_Room":
		failures.append("Test 2j Failed: Server_Airlock portal rooms mismatch")
		
	# Test 11: Airlock portal toggle logic
	demo.is_airlock_open = true
	demo.toggle_server_airlock()
	if demo.is_airlock_open or demo.server_portal.open_factor > 0.1:
		failures.append("Test 2k Failed: Server airlock toggle failed to close portal")
	demo.toggle_server_airlock()
	if not demo.is_airlock_open or not is_equal_approx(demo.server_portal.open_factor, 1.0):
		failures.append("Test 2l Failed: Server airlock toggle failed to reopen portal")
		
	# Test 12: Ducking matrix configuration
	if demo.ducking_matrix == null:
		failures.append("Test 2m Failed: Ducking matrix not initialized")
	else:
		var has_voice_music_rule: bool = false
		var has_sfx_music_rule: bool = false
		for r in demo.ducking_matrix.rules:
			if r.source_bus == &"Voice" and r.target_bus == &"Music":
				has_voice_music_rule = true
			if r.source_bus == &"SFX" and r.target_bus == &"Music":
				has_sfx_music_rule = true
		if not has_voice_music_rule or not has_sfx_music_rule:
			failures.append("Test 2n Failed: Missing Voice->Music or SFX->Music ducking rule in matrix")
			
	# Test 13: Dialogue manager and Music director initialization
	if demo.dialogue_manager == null or demo.dialogue_table == null:
		failures.append("Test 2o Failed: Dialogue manager or table not initialized")
	else:
		demo.set_voice_locale("es")
		if demo.dialogue_manager.current_language != "es":
			failures.append("Test 2p Failed: set_voice_locale failed to set Spanish")
		demo.set_voice_locale("ja")
		if demo.dialogue_manager.current_language != "ja":
			failures.append("Test 2q Failed: set_voice_locale failed to set Japanese")
			
	if demo.music_director == null:
		failures.append("Test 2r Failed: Music director not initialized")
	else:
		if demo.music_director.items.size() < 4:
			failures.append("Test 2s Failed: Music playlist manager does not have 4 segment items")
		demo.set_combat_intensity(0.75)
		if not is_equal_approx(demo.combat_intensity, 0.75):
			failures.append("Test 2t Failed: set_combat_intensity failed to update combat_intensity")
			
	# Test 14: Teleportation in scene instance
	if instance.has_method("teleport_to_sector"):
		instance.teleport_to_sector(1)
		var p = instance.get_node_or_null("Player")
		if not p or absf(p.global_position.x - (-25.0)) > 2.0:
			failures.append("Test 2u Failed: Teleport to sector 1 failed")
		instance.teleport_to_sector(2)
		if not p or absf(p.global_position.x - 0.0) > 2.0:
			failures.append("Test 2v Failed: Teleport to sector 2 failed")
		instance.teleport_to_sector(3)
		if not p or absf(p.global_position.x - 25.0) > 2.0:
			failures.append("Test 2w Failed: Teleport to sector 3 failed")
		instance.teleport_to_sector(4)
		if not p or absf(p.global_position.x - 50.0) > 2.0:
			failures.append("Test 2x Failed: Teleport to sector 4 failed")
	else:
		failures.append("Test 2y Failed: Scene instance root missing teleport_to_sector method")
		
	demo.free()
	instance.free()
	return failures
