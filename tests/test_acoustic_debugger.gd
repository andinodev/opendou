class_name TestAcousticDebugger
extends RefCounted

## Unit tests for OpenDouAcousticDebugger3D and acoustic_sound_field.gdshader.

const OpenDouAcousticDebugger3DClass = preload("res://addons/opendou/nodes/opendou_acoustic_debugger_3d.gd")
const SHADER_PATH = "res://addons/opendou/shaders/acoustic_sound_field.gdshader"

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: Node instantiation, class_name and default properties
	if OpenDouAcousticDebugger3DClass == null:
		failures.append("Test 1 Failed: opendou_acoustic_debugger_3d.gd failed to load")
		return failures
		
	var debugger = OpenDouAcousticDebugger3DClass.new()
	if not (debugger is Node3D):
		failures.append("Test 1a Failed: OpenDouAcousticDebugger3D must extend Node3D")
	if debugger.enabled != true:
		failures.append("Test 1b Failed: enabled default should be true")
	if debugger.probe_ray_count != 24:
		failures.append("Test 1c Failed: probe_ray_count default should be 24, got %d" % debugger.probe_ray_count)
	if debugger.show_unit_size_core != true:
		failures.append("Test 1d Failed: show_unit_size_core default should be true")
	if debugger.show_occlusion_rays != true:
		failures.append("Test 1e Failed: show_occlusion_rays default should be true")
	if debugger.show_sound_field_mesh != true:
		failures.append("Test 1f Failed: show_sound_field_mesh default should be true")
	if debugger.collision_mask != 1:
		failures.append("Test 1g Failed: collision_mask default should be 1, got %d" % debugger.collision_mask)
	if debugger.max_display_emitters != 16:
		failures.append("Test 1h Failed: max_display_emitters default should be 16, got %d" % debugger.max_display_emitters)
	if debugger.listener_node != null:
		failures.append("Test 1i Failed: listener_node default should be null")
		
	# Test 2: Starburst ray probe calculation with unobstructed target distances
	var emitter_pos = Vector3(0.0, 1.0, 0.0)
	var ray_count = 16
	var max_dist = 20.0
	var starburst = debugger.calculate_starburst_distances(emitter_pos, ray_count, max_dist, null)
	if starburst.size() != ray_count:
		failures.append("Test 2a Failed: Expected %d ray probe results, got %d" % [ray_count, starburst.size()])
	else:
		for i in range(starburst.size()):
			var probe = starburst[i]
			if not probe.has("dir") or not probe.has("dist") or not probe.has("is_hit") or not probe.has("hit_pos"):
				failures.append("Test 2b Failed: Starburst item missing required keys at index %d" % i)
				break
			if not is_equal_approx(probe["dist"], max_dist):
				failures.append("Test 2c Failed: Unobstructed ray %d dist should be %f, got %f" % [i, max_dist, probe["dist"]])
				break
			if probe["is_hit"] != false:
				failures.append("Test 2d Failed: Unobstructed ray %d is_hit should be false" % i)
				break
			var expected_hit_pos = emitter_pos + probe["dir"] * max_dist
			if not probe["hit_pos"].is_equal_approx(expected_hit_pos):
				failures.append("Test 2e Failed: hit_pos mismatch on unobstructed ray %d" % i)
				break
				
	# Test 3: Starburst calculation with custom counts / edge conditions
	var empty_starburst = debugger.calculate_starburst_distances(emitter_pos, 0, max_dist, null)
	if empty_starburst.size() != 0:
		failures.append("Test 3a Failed: Starburst with 0 rays should return empty array")
		
	var custom_starburst = debugger.calculate_starburst_distances(Vector3(10.0, 0.0, 5.0), 8, 12.5, null)
	if custom_starburst.size() != 8:
		failures.append("Test 3b Failed: Starburst with 8 rays should return 8 items")
	elif not is_equal_approx(custom_starburst[0]["dist"], 12.5):
		failures.append("Test 3c Failed: Custom starburst max_dist mismatch, got %f" % custom_starburst[0]["dist"])
		
	# Test 4: Emitter-to-listener multi-ray line classification (Green, Yellow, Red)
	# When space_state is null: 0 hits -> Green Color(0.2, 1.0, 0.3, 0.8), occlusion_factor 0.0
	var occ_clear = debugger.evaluate_listener_occlusion(emitter_pos, Vector3(5.0, 1.0, 0.0), null)
	if occ_clear["hit_count"] != 0:
		failures.append("Test 4a Failed: Expected 0 hits for null space_state, got %d" % occ_clear["hit_count"])
	if not is_equal_approx(occ_clear["occlusion_factor"], 0.0):
		failures.append("Test 4b Failed: Expected occlusion_factor 0.0 for clear, got %f" % occ_clear["occlusion_factor"])
	var expected_green = Color(0.2, 1.0, 0.3, 0.8)
	if not occ_clear["color"].is_equal_approx(expected_green):
		failures.append("Test 4c Failed: Expected green color %s, got %s" % [str(expected_green), str(occ_clear["color"])])
		
	# Test 5: Dynamic toggle toggle_debug() and visibility state
	var initial_state = debugger.enabled
	var toggled_1 = debugger.toggle_debug()
	if toggled_1 != (not initial_state) or debugger.enabled != (not initial_state):
		failures.append("Test 5a Failed: toggle_debug() did not invert enabled state to %s" % str(not initial_state))
		
	var toggled_2 = debugger.toggle_debug()
	if toggled_2 != initial_state or debugger.enabled != initial_state:
		failures.append("Test 5b Failed: Second toggle_debug() did not revert enabled state to %s" % str(initial_state))
		
	# Test 6: Shader resource loading and properties
	var shader_res = ResourceLoader.load(SHADER_PATH)
	if shader_res == null:
		failures.append("Test 6a Failed: Shader resource missing at %s" % SHADER_PATH)
	elif not (shader_res is Shader):
		failures.append("Test 6b Failed: Resource at %s is not a Shader" % SHADER_PATH)
	else:
		var code: String = shader_res.code
		if not code.contains("shader_type spatial;"):
			failures.append("Test 6c Failed: Shader must be spatial")
		if not code.contains("blend_add"):
			failures.append("Test 6d Failed: Shader must use blend_add")
		if not code.contains("base_color") or not code.contains("occluded_color"):
			failures.append("Test 6e Failed: Shader missing base_color or occluded_color uniforms")
		if not code.contains("wave_speed") or not code.contains("wave_frequency"):
			failures.append("Test 6f Failed: Shader missing wave animation uniforms")
			
	# Test 7: plugin.gd custom type registration and SVG icon loading
	var script_path = "res://addons/opendou/nodes/opendou_acoustic_debugger_3d.gd"
	var icon_path = "res://addons/opendou/icons/icon_acoustic_debugger.svg"
	
	var scr = ResourceLoader.load(script_path)
	if scr == null:
		failures.append("Test 7a Failed: Script resource missing for OpenDouAcousticDebugger3D at %s" % script_path)
	var icon_res = ResourceLoader.load(icon_path)
	if icon_res == null:
		failures.append("Test 7b Failed: Icon resource missing for OpenDouAcousticDebugger3D at %s" % icon_path)
		
	var plugin_code = FileAccess.get_file_as_string("res://addons/opendou/plugin.gd")
	if plugin_code.is_empty():
		failures.append("Test 7c Failed: Could not read addons/opendou/plugin.gd")
	else:
		if not plugin_code.contains('add_custom_type("OpenDouAcousticDebugger3D"') and not plugin_code.contains("add_custom_type('OpenDouAcousticDebugger3D'"):
			failures.append("Test 7d Failed: plugin.gd missing add_custom_type for OpenDouAcousticDebugger3D")
		if not plugin_code.contains('remove_custom_type("OpenDouAcousticDebugger3D"') and not plugin_code.contains("remove_custom_type('OpenDouAcousticDebugger3D'"):
			failures.append("Test 7e Failed: plugin.gd missing remove_custom_type for OpenDouAcousticDebugger3D")
			
	debugger.free()
	return failures
