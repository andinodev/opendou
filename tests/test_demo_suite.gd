class_name TestDemoSuite
extends RefCounted

const DemoRoomsPortalsClass = preload("res://scenes/demos/01_spatial_rooms_portals/demo_rooms_portals.gd")
const DemoVoiceStressClass = preload("res://scenes/demos/02_massive_voice_stress/demo_voice_stress.gd")
const DemoSurfaceSwitchesClass = preload("res://scenes/demos/03_surface_switches_3d/demo_surface_switches.gd")
const DemoVehicleRPMClass = preload("res://scenes/demos/04_vehicle_blend_rpm/demo_vehicle_rpm.gd")
const DemoDynamicOcclusionClass = preload("res://scenes/demos/05_dynamic_occlusion_ray/demo_dynamic_occlusion.gd")
const DemoSoundBankStreamingClass = preload("res://scenes/demos/06_soundbank_streaming/demo_soundbank_streaming.gd")
const DemoHubClass = preload("res://scenes/demos/demo_hub.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: Demo 01 - Macro-Acoustics & Portals
	var d1 = DemoRoomsPortalsClass.new()
	d1.setup_acoustics()
	d1.set_door_open_factor(1.0)
	if not is_equal_approx(d1.calculated_path.accumulated_lpf, 20000.0):
		failures.append("Test 1a Failed: Open door LPF expected 20000Hz, got %f" % d1.calculated_path.accumulated_lpf)
	d1.set_door_open_factor(0.0)
	if not is_equal_approx(d1.calculated_path.accumulated_lpf, 200.0):
		failures.append("Test 1b Failed: Closed door LPF expected 200Hz, got %f" % d1.calculated_path.accumulated_lpf)
		
	# Test 2: Demo 02 - Massive Voice Stress
	var d2 = DemoVoiceStressClass.new()
	d2.setup_stress_test(100, 16)
	if d2.get_active_physical_count() > 16:
		failures.append("Test 2a Failed: Hardware physical channels exceeded capacity (got %d)" % d2.get_active_physical_count())
	if d2.get_active_virtual_count() != 84:
		failures.append("Test 2b Failed: Expected 84 virtual voices, got %d" % d2.get_active_virtual_count())
		
	# Test 3: Demo 03 - Surface Switches
	var d3 = DemoSurfaceSwitchesClass.new()
	d3.setup_surface_system()
	var wood_voices = d3.trigger_footstep(&"Wood")
	var concrete_voices = d3.trigger_footstep(&"Concrete")
	if wood_voices.is_empty() or concrete_voices.is_empty():
		failures.append("Test 3 Failed: Surface voice resolution empty (wood=%d, concrete=%d, root=%s)" % [wood_voices.size(), concrete_voices.size(), str(d3.footstep_event_def.root_container)])
	elif wood_voices[0].stream.resource_name == concrete_voices[0].stream.resource_name:
		failures.append("Test 3b Failed: Wood and Concrete should resolve different sample paths")
		
	# Test 4: Demo 04 - Vehicle RPM Blend
	var d4 = DemoVehicleRPMClass.new()
	d4.setup_engine_blend()
	var idle_v = d4.set_rpm(1000.0)
	var high_v = d4.set_rpm(7500.0)
	if idle_v.is_empty() or high_v.is_empty():
		failures.append("Test 4 Failed: Vehicle RPM blend empty (idle=%d, high=%d, layers=%d)" % [idle_v.size(), high_v.size(), d4.blend_container.layers.size() if d4.blend_container else -1])
		
	# Test 5: Demo 05 - Dynamic Occlusion
	var d5 = DemoDynamicOcclusionClass.new()
	d5.setup_occlusion_demo()
	# Step with obstacle at Z=0 (blocking line of sight)
	d5.update_obstacle_step(0.1, 0.0)
	if d5.get_current_lpf() >= 20000.0:
		failures.append("Test 5 Failed: Occlusion did not attenuate LPF")
		
	# Test 6: Demo 06 - SoundBank Streaming
	var d6 = DemoSoundBankStreamingClass.new()
	d6.setup_streaming_demo("user://test_demo_stream.bank")
	if not d6.is_stream_ready:
		failures.append("Test 6a Failed: SoundBank streaming demo setup failed")
	var chunk1 = d6.mix_audio_chunk(512)
	if chunk1.size() != 512:
		failures.append("Test 6b Failed: Mix audio chunk size mismatch")
		
	# Test 7: Demo 07 - Hub Launcher
	var d7 = DemoHubClass.new()
	d7.launch_demo(1, "Test Desc")
	if not d7.active_demo_node:
		failures.append("Test 7 Failed: DemoHub failed to launch demo 1")
		
	# Test 8: Declarative PackedScene (.tscn) Parsing & Instantiation Validation
	var scene_paths: Array[String] = [
		"res://scenes/demos/01_spatial_rooms_portals/demo_rooms_portals.tscn",
		"res://scenes/demos/02_massive_voice_stress/demo_voice_stress.tscn",
		"res://scenes/demos/03_surface_switches_3d/demo_surface_switches.tscn",
		"res://scenes/demos/04_vehicle_blend_rpm/demo_vehicle_rpm.tscn",
		"res://scenes/demos/05_dynamic_occlusion_ray/demo_dynamic_occlusion.tscn",
		"res://scenes/demos/06_soundbank_streaming/demo_soundbank_streaming.tscn",
		"res://scenes/demos/demo_hub.tscn"
	]
	for p in scene_paths:
		var packed: PackedScene = load(p)
		if not packed:
			failures.append("Test 8 Failed: ResourceLoader could not load PackedScene: %s" % p)
		else:
			var node = packed.instantiate()
			if not node:
				failures.append("Test 8 Failed: Could not instantiate PackedScene: %s" % p)
			else:
				node.free()
				
	return failures
