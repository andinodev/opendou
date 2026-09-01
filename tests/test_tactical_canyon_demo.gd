class_name TestTacticalCanyonDemo
extends RefCounted

## Verification Test Suite for Tactical Canyon AAA Showcase Demo (Sector 8)

const TacticalCanyonDemoScene = preload("res://scenes/demos/08_tactical_canyon/demo_tactical_canyon.tscn")
const DemoHubClass = preload("res://scenes/demos/demo_hub.gd")
const AcousticLODControllerClass = preload("res://addons/opendou/runtime/spatial/acoustic_lod_controller.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: Scene Instantiation & Node Tree Structure
	var demo = TacticalCanyonDemoScene.instantiate()
	if demo == null:
		failures.append("Test 1 Failed: Could not instantiate demo_tactical_canyon.tscn")
		return failures
		
	var player = demo.get_node_or_null("Player")
	var spline_emitter = demo.get_node_or_null("LevelGeometry/Sector1_RiverGorge/RiverSplineEmitter")
	var bunker_room = demo.get_node_or_null("LevelGeometry/Sector2_Bunker/BunkerRoomArea")
	var bunker_portal = demo.get_node_or_null("LevelGeometry/Sector2_Bunker/BunkerPortal")
	var bunker_door = demo.get_node_or_null("LevelGeometry/Sector2_Bunker/BunkerDoor")
	var wall_concrete = demo.get_node_or_null("LevelGeometry/Sector3_MaterialLab/WallConcrete")
	var wall_metal = demo.get_node_or_null("LevelGeometry/Sector3_MaterialLab/WallMetal")
	var wall_wood = demo.get_node_or_null("LevelGeometry/Sector3_MaterialLab/WallWood")
	var wall_foliage = demo.get_node_or_null("LevelGeometry/Sector3_MaterialLab/WallFoliage")
	var drone_emitter = demo.get_node_or_null("LevelGeometry/Sector4_DroneRange/DroneEmitter")
	var debugger = demo.get_node_or_null("LevelGeometry/AcousticDebugger")
	var hud = demo.get_node_or_null("TacticalHUD")
	
	if not player or not spline_emitter or not bunker_room or not bunker_portal or not bunker_door:
		failures.append("Test 1 Failed: Missing core physical geometry nodes in Tactical Canyon scene tree")
	if not wall_concrete or not wall_metal or not wall_wood or not wall_foliage:
		failures.append("Test 1 Failed: Missing material test wall partitions")
	if not drone_emitter or not debugger or not hud:
		failures.append("Test 1 Failed: Missing drone, acoustic debugger or tactical HUD")
		
	# Test 2: Sector Teleportation & Positions
	var get_pos = func() -> Vector3: return player.global_position if player.is_inside_tree() else player.position
	
	demo.teleport_to_sector(1)
	if demo.active_sector_idx != 1 or get_pos.call().distance_to(Vector3(0, 1, 0)) > 0.1:
		failures.append("Test 2 Failed: Sector 1 teleport failed, got pos %s" % str(get_pos.call()))
		
	demo.teleport_to_sector(2)
	if demo.active_sector_idx != 2 or get_pos.call().distance_to(Vector3(30, 1, 0)) > 0.1:
		failures.append("Test 2 Failed: Sector 2 teleport failed, got pos %s" % str(get_pos.call()))
		
	demo.teleport_to_sector(3)
	if demo.active_sector_idx != 3 or get_pos.call().distance_to(Vector3(60, 1, 0)) > 0.1:
		failures.append("Test 2 Failed: Sector 3 teleport failed, got pos %s" % str(get_pos.call()))
		
	demo.teleport_to_sector(4)
	if demo.active_sector_idx != 4 or get_pos.call().distance_to(Vector3(90, 1, 0)) > 0.1:
		failures.append("Test 2 Failed: Sector 4 teleport failed, got pos %s" % str(get_pos.call()))
		
	demo.teleport_to_sector(5)
	if demo.active_sector_idx != 5 or get_pos.call().distance_to(Vector3(120, 1, 0)) > 0.1:
		failures.append("Test 2 Failed: Sector 5 teleport failed, got pos %s" % str(get_pos.call()))
		
	# Test 3: River Spline Emitter Closest Point Projection
	if spline_emitter:
		var listener_test = Vector3(8.0, 1.0, 0.0)
		var closest = spline_emitter.get_closest_virtual_point(listener_test)
		if closest.distance_to(Vector3(8.0, 0.5, 0.0)) > 2.0:
			failures.append("Test 3 Failed: Spline closest virtual point failed, expected ~(8, 0.5, 0), got %s" % str(closest))
			
	# Test 4: Bunker Air-lock Portal Open/Close State & Reverb Coupling
	if demo.is_bunker_door_open != true:
		failures.append("Test 4 Failed: Bunker door should initially be open")
	demo.toggle_bunker_door()
	if demo.is_bunker_door_open != false or demo.bunker_portal.open_factor != 0.0:
		failures.append("Test 4 Failed: Bunker door toggle should close door and set portal open_factor to 0.0")
	demo.toggle_bunker_door()
	if demo.is_bunker_door_open != true or demo.bunker_portal.open_factor != 1.0:
		failures.append("Test 4 Failed: Bunker door toggle should reopen door and set portal open_factor to 1.0")
		
	# Test 5: Material Mass-Law Transmission Loss Evaluation
	demo.set_test_material(&"Concrete")
	var tl_concrete = demo.spatial_acoustics.material_registry.calculate_transmission_loss(&"Concrete", 0.3, 1000.0)["attenuation_db"]
	demo.set_test_material(&"Metal")
	var tl_metal = demo.spatial_acoustics.material_registry.calculate_transmission_loss(&"Metal", 0.3, 1000.0)["attenuation_db"]
	demo.set_test_material(&"Wood")
	var tl_wood = demo.spatial_acoustics.material_registry.calculate_transmission_loss(&"Wood", 0.3, 1000.0)["attenuation_db"]
	demo.set_test_material(&"Foliage")
	var tl_foliage = demo.spatial_acoustics.material_registry.calculate_transmission_loss(&"Foliage", 0.3, 1000.0)["attenuation_db"]
	
	if not (tl_metal > tl_concrete and tl_concrete > tl_wood and tl_wood > tl_foliage):
		failures.append("Test 5 Failed: Transmission loss ranking invalid: Metal (%.1f) > Concrete (%.1f) > Wood (%.1f) > Foliage (%.1f)" % [
			tl_metal, tl_concrete, tl_wood, tl_foliage
		])
		
	# Test 6: Drone Doppler Pitch & LOD Transitions
	var drone_pos = Vector3(90.0, 3.0, 10.0)
	var drone_vel_approaching = Vector3(0.0, 0.0, -25.0) # Moving towards listener at (90, 1, 0)
	var drone_vel_receding = Vector3(0.0, 0.0, 25.0)    # Moving away
	var listener_pos = Vector3(90.0, 1.0, 0.0)
	
	var pitch_app = demo.spatial_acoustics.calculate_doppler_pitch(drone_vel_approaching, Vector3.ZERO, listener_pos - drone_pos)
	var pitch_rec = demo.spatial_acoustics.calculate_doppler_pitch(drone_vel_receding, Vector3.ZERO, listener_pos - drone_pos)
	
	if pitch_app <= 1.0 or pitch_rec >= 1.0:
		failures.append("Test 6 Failed: Doppler pitch invalid: approaching (%.2f) must be > 1.0, receding (%.2f) must be < 1.0" % [
			pitch_app, pitch_rec
		])
		
	# Test 7: HDR Explosive Detonation & Decay Recovery
	# El motor HDR se consolido en AudioHDREngine, cuya ventana va en dB HDR
	# (fuerte por encima de 0) en lugar de dBFS con techo en -6.
	demo.trigger_hdr_explosion()
	var bounds: Vector2 = demo.hdr_engine.get_window_bounds()
	if bounds.x <= 0.0:
		failures.append("Test 7 Failed: la ventana HDR deberia haber subido, techo %.1f dB" % bounds.x)
	if not is_equal_approx(bounds.y, bounds.x - 40.0):
		failures.append("Test 7 Failed: el suelo deberia estar 40 dB bajo el techo, techo %.1f suelo %.1f" % [bounds.x, bounds.y])

	# Una voz muy por debajo del suelo queda atenuada al minimo.
	var ducked_voice_gain = demo.hdr_engine.calculate_voice_gain(bounds.y - 20.0)
	if ducked_voice_gain >= 0.8:
		failures.append("Test 7 Failed: una voz bajo el suelo deberia estar ducked, ganancia %.2f" % ducked_voice_gain)
		
	# Test 8: DemoHub Registration
	var hub = DemoHubClass.new()
	if hub == null or not hub.DEMO_SCENES.has(8):
		failures.append("Test 8 Failed: DemoHub does not have Demo 8 registered in DEMO_SCENES")
	else:
		if hub.DEMO_SCENES[8] != "res://scenes/demos/08_tactical_canyon/demo_tactical_canyon.tscn":
			failures.append("Test 8 Failed: Demo 8 path mismatch: %s" % hub.DEMO_SCENES[8])
	hub.free()

	# Test 9: Granular Emitter Node Existence & Preset Toggling
	var granular = demo.get_node_or_null("LevelGeometry/Sector1_RiverGorge/CliffsideGranularEmitter")
	if granular == null:
		failures.append("Test 9 Failed: CliffsideGranularEmitter missing from Sector1_RiverGorge")
	else:
		if granular.grain_size_ms != 40.0:
			failures.append("Test 9 Failed: Granular initial grain_size_ms should be 40.0")
		demo.toggle_granular_preset() # switches to WIND
		if demo.granular_mode != 1:
			failures.append("Test 9 Failed: Granular mode toggle failed to switch to 1 (WIND)")
		demo.toggle_granular_preset() # switches back to GRAVEL
		if demo.granular_mode != 0:
			failures.append("Test 9 Failed: Granular mode toggle failed to switch back to 0 (GRAVEL)")

	# Test 10: Bunker Room Reverb Mode & Convolution Toggle
	if demo.is_convolution_active != true:
		failures.append("Test 10 Failed: Bunker convolution should initially be active")
	demo.toggle_reverb_convolution() # pasa a SABINE_RT60
	if demo.is_convolution_active != false or demo.room_bunker.reverb_mode != 0:
		failures.append("Test 10 Failed: Reverb toggle failed to switch to SABINE_RT60")
	demo.toggle_reverb_convolution() # vuelve a IR_DERIVED_RT60
	if demo.is_convolution_active != true or demo.room_bunker.reverb_mode != 1:
		failures.append("Test 10 Failed: Reverb toggle failed to switch back to IR_DERIVED_RT60")

	# Test 11: Monolithic SoundBank Loading & Telemetry
	if demo.soundbank_manager == null:
		failures.append("Test 11 Failed: demo.soundbank_manager is null")
	else:
		var telem = demo.inspect_soundbank()
		if not telem.has("bank_name") or telem["bank_name"] != &"tactical_canyon":
			failures.append("Test 11 Failed: SoundBank telemetry missing bank_name 'tactical_canyon'")
		if not telem.has("prefetch_ram_bytes") or telem["prefetch_ram_bytes"] <= 0:
			failures.append("Test 11 Failed: SoundBank prefetch RAM bytes invalid")

	demo.free()
	return failures
