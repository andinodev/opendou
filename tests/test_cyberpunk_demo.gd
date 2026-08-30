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
		var p = instance.get_node_or_null("Player")
		instance.teleport_to_sector(1)
		var p1 = (p.global_position if p.is_inside_tree() else p.position) if p else Vector3.ZERO
		if not p or absf(p1.x - (-25.0)) > 2.0:
			failures.append("Test 2u Failed: Teleport to sector 1 failed")
		instance.teleport_to_sector(2)
		var p2 = (p.global_position if p.is_inside_tree() else p.position) if p else Vector3.ZERO
		if not p or absf(p2.x - 0.0) > 2.0:
			failures.append("Test 2v Failed: Teleport to sector 2 failed")
		instance.teleport_to_sector(3)
		var p3 = (p.global_position if p.is_inside_tree() else p.position) if p else Vector3.ZERO
		if not p or absf(p3.x - 25.0) > 2.0:
			failures.append("Test 2w Failed: Teleport to sector 3 failed")
		instance.teleport_to_sector(4)
		var p4 = (p.global_position if p.is_inside_tree() else p.position) if p else Vector3.ZERO
		if not p or absf(p4.x - 50.0) > 2.0:
			failures.append("Test 2x Failed: Teleport to sector 4 failed")
	else:
		failures.append("Test 2y Failed: Scene instance root missing teleport_to_sector method")
		
	# Test 15: Footstep surface detection across 4 coordinate zones
	if not demo.has_method("detect_footstep_surface"):
		failures.append("Test 3a Failed: demo missing detect_footstep_surface method")
	else:
		var s1 = demo.detect_footstep_surface(Vector3(-25.0, 1.0, 0.0))
		var s2 = demo.detect_footstep_surface(Vector3(0.0, 1.0, 0.0))
		var s3 = demo.detect_footstep_surface(Vector3(25.0, 1.0, 0.0))
		var s4 = demo.detect_footstep_surface(Vector3(50.0, 1.0, 0.0))
		if s1 != &"Metal":
			failures.append("Test 3b Failed: Sector 1 surface expected &\"Metal\", got %s" % str(s1))
		if s2 != &"Tile":
			failures.append("Test 3c Failed: Sector 2 surface expected &\"Tile\", got %s" % str(s2))
		if s3 != &"Water":
			failures.append("Test 3d Failed: Sector 3 surface expected &\"Water\", got %s" % str(s3))
		if s4 != &"Concrete":
			failures.append("Test 3e Failed: Sector 4 surface expected &\"Concrete\", got %s" % str(s4))
			
	# Test 16: 250-Voice Siege Bombardment virtualization & voice budget
	if not demo.has_method("trigger_siege_bombardment"):
		failures.append("Test 3f Failed: demo missing trigger_siege_bombardment method")
	else:
		demo.trigger_siege_bombardment()
		if demo.bombardment_instances.size() != 250:
			failures.append("Test 3g Failed: trigger_siege_bombardment spawned %d instances, expected 250" % demo.bombardment_instances.size())
		else:
			# Simulate a physics frame to resolve voice pool
			demo.voice_pool.resolve_voice_stealing(demo.bombardment_instances, Vector3(50.0, 1.0, 0.0), 0.016)
			var active_phys = demo.voice_pool.get_active_physical_count()
			var active_virt = demo.voice_pool.get_active_virtual_count(demo.bombardment_instances)
			if active_phys > 16:
				failures.append("Test 3h Failed: Voice pool physical voice cap exceeded (%d > 16)" % active_phys)
			if active_phys == 0:
				failures.append("Test 3i Failed: Voice pool has 0 active physical voices after bombardment")
			if (active_phys + active_virt) != 250:
				failures.append("Test 3j Failed: Total active physical + virtual voices mismatch (%d physical, %d virtual, expected 250)" % [active_phys, active_virt])
		
	# Test 17: TacticalHUD node hierarchy & OpenDouRadarView integration
	var radar_node = instance.get_node_or_null("TacticalHUD/RadarContainer/Margin/RadarVBox/RadarView")
	if not radar_node:
		failures.append("Test 4a Failed: TacticalHUD missing RadarView node")
	elif not radar_node.has_method("update_radar_data"):
		failures.append("Test 4b Failed: RadarView node is not an OpenDouRadarView (missing update_radar_data)")
		
	var lbl_occl = instance.get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblOcclusion")
	var lbl_snap = instance.get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblSnapshot")
	var lbl_subs = instance.get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblSubtitles")
	var slider_int = instance.get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/SliderIntensity")
	if not lbl_occl:
		failures.append("Test 4c Failed: TacticalHUD missing LblOcclusion label")
	if not lbl_snap:
		failures.append("Test 4d Failed: TacticalHUD missing LblSnapshot label")
	if not lbl_subs:
		failures.append("Test 4e Failed: TacticalHUD missing LblSubtitles label")
	if not slider_int:
		failures.append("Test 4f Failed: TacticalHUD missing SliderIntensity HSlider")

	# Test 18: Localized radio dialogue and priority ducking reduction
	if not demo.has_method("play_tactical_radio_line"):
		failures.append("Test 4g Failed: demo missing play_tactical_radio_line method")
	else:
		demo.play_tactical_radio_line(&"sec_clear_01", "es")
		if demo.dialogue_manager.current_language != "es":
			failures.append("Test 4h Failed: play_tactical_radio_line failed to switch language to 'es'")
		if not demo.dialogue_manager.is_speaking:
			failures.append("Test 4i Failed: dialogue_manager not marked is_speaking after play_tactical_radio_line")
		if not demo.ducking_matrix.active_source_buses.get(&"Voice", false):
			failures.append("Test 4j Failed: Voice bus not set to active in ducking matrix")
		demo.ducking_matrix.update(0.1)
		var gr_db = demo.ducking_matrix.get_gain_reduction_db(&"Voice", &"Music")
		if gr_db >= -0.5:
			failures.append("Test 4k Failed: Voice -> Music ducking gain reduction not applied (expected < -0.5 dB, got %.2f dB)" % gr_db)

	# Test 19: Combat intensity RTPC slider and music director updates
	demo.set_combat_intensity(0.85)
	if not is_equal_approx(demo.combat_intensity, 0.85):
		failures.append("Test 4l Failed: set_combat_intensity failed to set 0.85")

	# Test 20: Sector teleportation, acoustic room update, and radar telemetry physics frame
	demo.teleport_to_sector(3)
	demo._physics_process(0.016)
	if demo.active_room_name != &"Flooded_Drainage":
		failures.append("Test 4m Failed: Active room after teleporting to Sector 3 expected Flooded_Drainage, got %s" % str(demo.active_room_name))
	var s_water = demo.detect_footstep_surface(Vector3(25.0, 1.0, 0.0))
	if s_water != &"Water":
		failures.append("Test 4n Failed: Footstep surface in Sector 3 expected Water, got %s" % str(s_water))
		
	# Test 21: DemoHub Demo 7 registration in DEMO_SCENES
	var demo_hub_script = load("res://scenes/demos/demo_hub.gd")
	if not demo_hub_script:
		failures.append("Test 5a Failed: scenes/demos/demo_hub.gd failed to load")
	else:
		var hub = demo_hub_script.new()
		if not hub.DEMO_SCENES.has(7):
			failures.append("Test 5b Failed: DemoHub.DEMO_SCENES missing key 7 for Cyberpunk Infiltration")
		elif hub.DEMO_SCENES[7] != SCENE_PATH:
			failures.append("Test 5c Failed: DemoHub.DEMO_SCENES[7] expected %s, got %s" % [SCENE_PATH, str(hub.DEMO_SCENES[7])])
		hub.free()

	# Test 22: Music Suite multi-stem integration & 3D Emitter Distance Culling
	if demo.active_music_suite != &"Exploration_Ambient_Theme.tres":
		failures.append("Test 6a Failed: Default active music suite expected Exploration_Ambient_Theme.tres, got %s" % str(demo.active_music_suite))
	if demo.stem_players.size() < 2:
		failures.append("Test 6b Failed: Exploration_Ambient_Theme expected at least 2 stem players, got %d" % demo.stem_players.size())
		
	# Test 3D emitter attenuation parameters (max_distance = 15m to prevent bleed between 25m sectors)
	if demo.rain_audio and (demo.rain_audio.max_distance > 16.0 or demo.rain_audio.max_distance < 10.0):
		failures.append("Test 6c Failed: rain_audio max_distance mismatch (expected ~15.0m, got %.1fm)" % demo.rain_audio.max_distance)
	if demo.server_audio and (demo.server_audio.max_distance > 16.0 or demo.server_audio.max_distance < 10.0):
		failures.append("Test 6d Failed: server_audio max_distance mismatch (expected ~15.0m, got %.1fm)" % demo.server_audio.max_distance)
		
	# Test switching to Dynamic_Combat_Suite.tres
	demo.load_music_suite(&"Dynamic_Combat_Suite.tres")
	if demo.active_music_suite != &"Dynamic_Combat_Suite.tres" or demo.stem_players.size() < 3:
		failures.append("Test 6e Failed: Failed to switch to Dynamic_Combat_Suite.tres multi-stem configuration")

	# Test 23: OpenDouAudibleMonitor & Toggle Button integration in HUD
	var monitor_node = instance.get_node_or_null("AudibleMonitor")
	if not monitor_node:
		failures.append("Test 7a Failed: demo_cyberpunk_infiltration.tscn missing AudibleMonitor node")
	elif not (monitor_node is OpenDouAudibleMonitor):
		failures.append("Test 7b Failed: AudibleMonitor node is not an instance of OpenDouAudibleMonitor")
		
	var btn_monitor = instance.get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnToggleMonitor")
	if not btn_monitor:
		failures.append("Test 7c Failed: TacticalHUD BottomBar missing BtnToggleMonitor button")

	# Test 24: Sector 5 Biosphere 7.1 surround emitters and HUD button
	var sec5 = instance.get_node_or_null("LevelGeometry/Sector5_Biosphere")
	if not sec5:
		failures.append("Test 8a Failed: LevelGeometry missing Sector5_Biosphere node")
	else:
		var bio_room = sec5.get_node_or_null("BiosphereRoom")
		if not bio_room or not (bio_room is OpenDouRoom3D):
			failures.append("Test 8b Failed: Sector5_Biosphere missing OpenDouRoom3D child BiosphereRoom")
		elif bio_room.room_name != &"Biosphere_Sanctuary":
			failures.append("Test 8c Failed: BiosphereRoom room_name expected Biosphere_Sanctuary, got %s" % str(bio_room.room_name))
			
		var expected_presets = {
			"CanopyWind_FL": "Wind_Canopy",
			"Waterfall_FR": "Waterfall_Stream",
			"Bird_C": "Bird_Chirp",
			"Thunder_LFE": "Thunder_Rumble",
			"Cicada_SL": "Cicada_Swarm",
			"Frog_SR": "Frog_Croak",
			"Rain_RL": "Rain_Atmosphere",
			"Droplet_RR": "Water_Droplet",
			"OrbitingBeeEmitter": "Cyber_Hornet"
		}
		for em_name in expected_presets.keys():
			var em = sec5.get_node_or_null(em_name)
			if not em:
				failures.append("Test 8d Failed: Sector5_Biosphere missing 7.1 surround emitter: %s" % em_name)
			elif not (em is OpenDouEventPlayer3D):
				failures.append("Test 8e Failed: Emitter %s is not an OpenDouEventPlayer3D" % em_name)
			else:
				var expected_p: String = expected_presets[em_name]
				if em.synth_preset != expected_p:
					failures.append("Test 8f Failed: Emitter %s expected synth_preset '%s', got '%s'" % [em_name, expected_p, em.synth_preset])
				em._apply_synth_preset()
				if em.stream == null or not (em.stream is AudioStreamWAV):
					failures.append("Test 8g Failed: Emitter %s failed to generate AudioStreamWAV for preset '%s'" % [em_name, expected_p])


	# Test 25: Sector 5 Teleportation, Foliage footstep detection, and 360 Orbiting Bee audio
	var demo_sec5 = script_res.new()
	if not demo_sec5:
		failures.append("Test 9a Failed: Failed to instantiate demo script for Sector 5 testing")
	else:
		demo_sec5.teleport_to_sector(5)
		if demo_sec5.active_sector_idx != 5:
			failures.append("Test 9b Failed: Teleport to Sector 5 failed to set active_sector_idx = 5")
		if demo_sec5.active_room_name != &"Biosphere_Sanctuary":
			failures.append("Test 9c Failed: Active room after teleporting to Sector 5 expected Biosphere_Sanctuary, got %s" % str(demo_sec5.active_room_name))
			
		var s_foliage = demo_sec5.detect_footstep_surface(Vector3(80.0, 1.5, 0.0))
		if s_foliage != &"Foliage":
			failures.append("Test 9d Failed: Footstep surface in Sector 5 expected &\"Foliage\", got %s" % str(s_foliage))
			
		var s_foliage_edge = demo_sec5.detect_footstep_surface(Vector3(65.5, 0.0, 0.0))
		if s_foliage_edge != &"Foliage":
			failures.append("Test 9e Failed: Footstep surface at x=65.5 expected &\"Foliage\", got %s" % str(s_foliage_edge))

		demo_sec5.free()

	if instance.has_method("teleport_to_sector"):
		var p_inst = instance.get_node_or_null("Player")
		instance.teleport_to_sector(5)
		var p5 = (p_inst.global_position if p_inst.is_inside_tree() else p_inst.position) if p_inst else Vector3.ZERO
		if not p_inst or absf(p5.x - 80.0) > 2.0:
			failures.append("Test 9f Failed: Scene instance teleport to Sector 5 failed (pos x: %.1f)" % p5.x)
		if instance.active_sector_idx != 5:
			failures.append("Test 9g Failed: Scene instance active_sector_idx not 5")
		if instance.active_room_name != &"Biosphere_Sanctuary":
			failures.append("Test 9h Failed: Scene instance active_room_name not Biosphere_Sanctuary, got %s" % str(instance.active_room_name))

	var bee_node = instance.get_node_or_null("LevelGeometry/Sector5_Biosphere/OrbitingBeeEmitter")
	if not bee_node:
		failures.append("Test 9i Failed: OrbitingBeeEmitter missing in scene instance")
	else:
		var init_pos = bee_node.position
		if instance.has_method("_process"):
			instance._process(0.5)
			if bee_node.position == init_pos:
				failures.append("Test 9j Failed: OrbitingBeeEmitter position did not update after _process")

	# Test 27: OpenDouAcousticDebugger3D node and Tactical HUD 3-state cycling toggle
	var debug_node = instance.get_node_or_null("LevelGeometry/AcousticDebugger")
	if not debug_node:
		failures.append("Test 27a Failed: demo_cyberpunk_infiltration.tscn missing LevelGeometry/AcousticDebugger node")
	elif not (debug_node is OpenDouAcousticDebugger3D):
		failures.append("Test 27b Failed: AcousticDebugger node is not an instance of OpenDouAcousticDebugger3D")
	else:
		if debug_node.probe_ray_count != 24:
			failures.append("Test 27c Failed: AcousticDebugger probe_ray_count expected 24, got %d" % debug_node.probe_ray_count)
		if not debug_node.enabled:
			failures.append("Test 27d Failed: AcousticDebugger enabled expected true by default")
			
	var btn_acoustics = instance.get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnToggleAcoustics")
	if not btn_acoustics:
		btn_acoustics = instance.get_node_or_null("TacticalHUD/ControlsPanel/Margin/HBox/BtnToggleAcoustics")
	if not btn_acoustics:
		failures.append("Test 27e Failed: TacticalHUD missing BtnToggleAcoustics button")
			
	var lbl_sf = instance.get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblSoundField")
	if not lbl_sf:
		failures.append("Test 27f Failed: TacticalHUD missing LblSoundField label")
		
	# Test 3-state cycling of _on_toggle_acoustics_pressed() in instance:
	# Initial (Focused): enabled = true, display_mode = 0
	# Cycle 1 -> All Active: enabled = true, display_mode = 1
	# Cycle 2 -> OFF: enabled = false
	# Cycle 3 -> Focused: enabled = true, display_mode = 0
	if instance.has_method("_on_toggle_acoustics_pressed"):
		if instance.acoustic_debugger == null:
			instance.acoustic_debugger = instance.get_node_or_null("LevelGeometry/AcousticDebugger")
		if instance.lbl_sound_field == null:
			instance.lbl_sound_field = instance.get_node_or_null("TacticalHUD/HUDPanel/Margin/VBox/LblSoundField")
		if instance.btn_toggle_acoustics == null:
			instance.btn_toggle_acoustics = instance.get_node_or_null("TacticalHUD/BottomBar/Margin/HBox/BtnToggleAcoustics")
			
		instance._update_hud()
		
		# Initial state
		if instance.lbl_sound_field:
			if instance.lbl_sound_field.text != "Sound Field: Focused (3D Iso-Bubble)":
				failures.append("Test 27g Failed: Initial lbl_sound_field expected 'Sound Field: Focused (3D Iso-Bubble)', got '%s'" % instance.lbl_sound_field.text)
				
		# 1st toggle: Focused (0) -> All Active (1)
		instance._on_toggle_acoustics_pressed()
		if not instance.acoustic_debugger.enabled or instance.acoustic_debugger.display_mode != 1:
			failures.append("Test 27h Failed: 1st toggle expected enabled=true & display_mode=1 (All Active), got enabled=%s, mode=%d" % [str(instance.acoustic_debugger.enabled), instance.acoustic_debugger.display_mode])
		if btn_acoustics and btn_acoustics.text != "👁️ 3D Bubble: ALL ACTIVE (G)":
			failures.append("Test 27i Failed: 1st toggle button text expected '👁️ 3D Bubble: ALL ACTIVE (G)', got '%s'" % btn_acoustics.text)
		if lbl_sf and lbl_sf.text != "Sound Field: All Active (3D)":
			failures.append("Test 27j Failed: 1st toggle lbl_sound_field expected 'Sound Field: All Active (3D)', got '%s'" % lbl_sf.text)
			
		# 2nd toggle: All Active (1) -> OFF (enabled=false)
		instance._on_toggle_acoustics_pressed()
		if instance.acoustic_debugger.enabled:
			failures.append("Test 27k Failed: 2nd toggle expected enabled=false (OFF), got enabled=true")
		if btn_acoustics and btn_acoustics.text != "👁️ 3D Bubble: OFF (G)":
			failures.append("Test 27l Failed: 2nd toggle button text expected '👁️ 3D Bubble: OFF (G)', got '%s'" % btn_acoustics.text)
		if lbl_sf and lbl_sf.text != "Sound Field: OFF":
			failures.append("Test 27m Failed: 2nd toggle lbl_sound_field expected 'Sound Field: OFF', got '%s'" % lbl_sf.text)
			
		# 3rd toggle: OFF -> Focused (0, enabled=true)
		instance._on_toggle_acoustics_pressed()
		if not instance.acoustic_debugger.enabled or instance.acoustic_debugger.display_mode != 0:
			failures.append("Test 27n Failed: 3rd toggle expected enabled=true & display_mode=0 (Focused), got enabled=%s, mode=%d" % [str(instance.acoustic_debugger.enabled), instance.acoustic_debugger.display_mode])
		if btn_acoustics and btn_acoustics.text != "👁️ 3D Bubble: FOCUSED (G)":
			failures.append("Test 27o Failed: 3rd toggle button text expected '👁️ 3D Bubble: FOCUSED (G)', got '%s'" % btn_acoustics.text)
		if lbl_sf and lbl_sf.text != "Sound Field: Focused (3D Iso-Bubble)":
			failures.append("Test 27p Failed: 3rd toggle lbl_sound_field expected 'Sound Field: Focused (3D Iso-Bubble)', got '%s'" % lbl_sf.text)
	else:
		failures.append("Test 27q Failed: Scene instance missing _on_toggle_acoustics_pressed method")

	demo.free()
	instance.free()
	return failures

