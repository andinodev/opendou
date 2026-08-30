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
			
	# Test 8: show_in_editor default (false), display_mode enum, sphere parameters
	if debugger.get("show_in_editor") != false:
		failures.append("Test 8a Failed: show_in_editor default should be false, got %s" % str(debugger.get("show_in_editor")))
	if debugger.get("display_mode") != 0:
		failures.append("Test 8b Failed: display_mode default should be 0 (Only_Selected), got %s" % str(debugger.get("display_mode")))
	if debugger.get("sphere_rings") != 8:
		failures.append("Test 8c Failed: sphere_rings default should be 8, got %s" % str(debugger.get("sphere_rings")))
	if debugger.get("sphere_segments") != 16:
		failures.append("Test 8d Failed: sphere_segments default should be 16, got %s" % str(debugger.get("sphere_segments")))
	if not (debugger.get("selected_emitters") is Array):
		failures.append("Test 8e Failed: selected_emitters should be an Array")
		
	# Test 9: 3D Geodesic / Spherical Probe Direction Generator
	if not debugger.has_method("generate_sphere_probe_directions"):
		failures.append("Test 9a Failed: debugger missing generate_sphere_probe_directions method")
	else:
		var empty_dirs = debugger.generate_sphere_probe_directions(0, 0)
		if empty_dirs.size() != 0:
			failures.append("Test 9b Failed: generate_sphere_probe_directions(0,0) should be empty")
			
		var dirs = debugger.generate_sphere_probe_directions(8, 16)
		# 1 top pole + (8-1)*16 intermediate ring points + 1 bottom pole = 114
		var expected_count = 2 + (8 - 1) * 16
		if dirs.size() != expected_count:
			failures.append("Test 9c Failed: Expected %d sphere directions, got %d" % [expected_count, dirs.size()])
		else:
			var has_north_pole = false
			var has_south_pole = false
			var has_equator = false
			for d in dirs:
				if not is_equal_approx(d.length(), 1.0):
					failures.append("Test 9d Failed: Sphere probe direction %s is not normalized (length: %f)" % [str(d), d.length()])
					break
				if d.is_equal_approx(Vector3.UP):
					has_north_pole = true
				if d.is_equal_approx(Vector3.DOWN):
					has_south_pole = true
				if is_zero_approx(d.y):
					has_equator = true
			if not has_north_pole:
				failures.append("Test 9e Failed: Sphere directions missing North Pole Vector3.UP")
			if not has_south_pole:
				failures.append("Test 9f Failed: Sphere directions missing South Pole Vector3.DOWN")
			if not has_equator:
				failures.append("Test 9g Failed: Sphere directions missing equatorial points")
				
	# Test 10: 3D Spherical Bubble Mesh calculation
	if not debugger.has_method("calculate_spherical_bubble_mesh"):
		failures.append("Test 10a Failed: debugger missing calculate_spherical_bubble_mesh method")
	else:
		var center = Vector3(0.0, 5.0, 0.0)
		var test_dist = 15.0
		var bubble_mesh = debugger.calculate_spherical_bubble_mesh(center, test_dist, null, 8, 16)
		if not bubble_mesh.has("vertices") or not bubble_mesh.has("normals") or not bubble_mesh.has("colors") or not bubble_mesh.has("indices"):
			failures.append("Test 10b Failed: calculate_spherical_bubble_mesh missing required dict keys")
		else:
			var verts: PackedVector3Array = bubble_mesh["vertices"]
			var norms: PackedVector3Array = bubble_mesh["normals"]
			var cols: PackedColorArray = bubble_mesh["colors"]
			var idxs: PackedInt32Array = bubble_mesh["indices"]
			
			if verts.size() != 114:
				failures.append("Test 10c Failed: Expected 114 vertices, got %d" % verts.size())
			if norms.size() != 114:
				failures.append("Test 10d Failed: Expected 114 normals, got %d" % norms.size())
			if cols.size() != 114:
				failures.append("Test 10e Failed: Expected 114 colors, got %d" % cols.size())
			if idxs.size() == 0 or idxs.size() % 3 != 0:
				failures.append("Test 10f Failed: Expected non-empty multiple of 3 indices, got %d" % idxs.size())
			if verts.size() > 0:
				var first_vert_dist = center.distance_to(verts[0])
				if not is_equal_approx(first_vert_dist, test_dist):
					failures.append("Test 10g Failed: Vertex distance should equal max_dist %f, got %f" % [test_dist, first_vert_dist])
			if cols.size() > 0:
				var expected_cyan = Color(0.1, 0.85, 1.0, 0.45)
				if not cols[0].is_equal_approx(expected_cyan):
					failures.append("Test 10h Failed: Unobstructed vertex color should be cyan %s, got %s" % [str(expected_cyan), str(cols[0])])
					
	# Test 11: Emitter filtering and display_mode logic
	if not debugger.has_method("_get_emitters_to_render"):
		failures.append("Test 11a Failed: debugger missing _get_emitters_to_render method")
	else:
		# Create test root and test AudioStreamPlayer3D children
		var test_root = Node3D.new()
		var player1 = AudioStreamPlayer3D.new()
		player1.name = "Player1"
		player1.set_meta("playing", true)
		test_root.add_child(player1)
		
		var player2 = AudioStreamPlayer3D.new()
		player2.name = "Player2"
		player2.set_meta("playing", false)
		test_root.add_child(player2)
		
		test_root.add_child(debugger)
		
		# In editor with show_in_editor = false -> returns empty
		debugger.show_in_editor = false
		if Engine.is_editor_hint():
			var editor_emitters = debugger._get_emitters_to_render()
			if editor_emitters.size() != 0:
				failures.append("Test 11b Failed: In editor with show_in_editor=false should return empty list")
				
		# In active game / tool with show_in_editor = true:
		debugger.show_in_editor = true
		
		# display_mode = 0 (Only_Selected): selected_emitters points to player2
		debugger.display_mode = 0
		var sel_paths: Array[NodePath] = [NodePath("Player2")]
		debugger.selected_emitters = sel_paths
		var selected_res = debugger._get_emitters_to_render()
		if not selected_res.has(player2) or selected_res.has(player1):
			failures.append("Test 11c Failed: display_mode=Only_Selected did not filter correctly to selected_emitters")
			
		# display_mode = 1 (Active_Audible_Only): only playing player1
		debugger.display_mode = 1
		var active_res = debugger._get_emitters_to_render()
		if not active_res.has(player1) or active_res.has(player2):
			failures.append("Test 11d Failed: display_mode=Active_Audible_Only should only include playing emitters")
			
		# display_mode = 2 (All_Emitters): includes both player1 and player2
		debugger.display_mode = 2
		var all_res = debugger._get_emitters_to_render()
		if not all_res.has(player1) or not all_res.has(player2):
			failures.append("Test 11e Failed: display_mode=All_Emitters should include all visible emitters")
			
		test_root.remove_child(debugger)
		player1.free()
		player2.free()
		test_root.free()
		
	debugger.free()
	return failures

