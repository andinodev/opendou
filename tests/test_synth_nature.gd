class_name TestSynthNature
extends RefCounted

const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")
const OpenDouEventPlayer3DClass = preload("res://addons/opendou/nodes/opendou_event_player_3d.gd")
const OpenDouEventPlayerClass = preload("res://addons/opendou/nodes/opendou_event_player.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []

	# Test 1: create_canopy_wind_loop produces valid non-empty AudioStreamWAV with LOOP_FORWARD
	var wind_stream = AudioSynthesizerClass.create_canopy_wind_loop(1.5)
	if wind_stream == null or not (wind_stream is AudioStreamWAV):
		failures.append("Test 1 Failed: create_canopy_wind_loop must return an AudioStreamWAV")
	else:
		if wind_stream.data.is_empty():
			failures.append("Test 1 Failed: wind stream data is empty")
		if wind_stream.loop_mode != AudioStreamWAV.LOOP_FORWARD:
			failures.append("Test 1 Failed: wind stream must have LOOP_FORWARD enabled")
		if wind_stream.loop_end <= 0:
			failures.append("Test 1 Failed: wind stream loop_end must be > 0")
		if wind_stream.format != AudioStreamWAV.FORMAT_16_BITS:
			failures.append("Test 1 Failed: wind stream format must be 16-bit")
		if wind_stream.mix_rate != 44100:
			failures.append("Test 1 Failed: wind stream mix_rate must be 44100")

	# Test 2: create_bird_chirp produces valid non-empty AudioStreamWAV
	var bird_stream = AudioSynthesizerClass.create_bird_chirp(2400.0, 0.35)
	if bird_stream == null or not (bird_stream is AudioStreamWAV):
		failures.append("Test 2 Failed: create_bird_chirp must return an AudioStreamWAV")
	else:
		if bird_stream.data.is_empty():
			failures.append("Test 2 Failed: bird chirp stream data is empty")
		if bird_stream.format != AudioStreamWAV.FORMAT_16_BITS:
			failures.append("Test 2 Failed: bird chirp format must be 16-bit")
		if bird_stream.mix_rate != 44100:
			failures.append("Test 2 Failed: bird chirp mix_rate must be 44100")

	# Test 3: create_thunder_rumble produces valid non-empty AudioStreamWAV
	var thunder_stream = AudioSynthesizerClass.create_thunder_rumble(1.5)
	if thunder_stream == null or not (thunder_stream is AudioStreamWAV):
		failures.append("Test 3 Failed: create_thunder_rumble must return an AudioStreamWAV")
	else:
		if thunder_stream.data.is_empty():
			failures.append("Test 3 Failed: thunder rumble stream data is empty")
		if thunder_stream.format != AudioStreamWAV.FORMAT_16_BITS:
			failures.append("Test 3 Failed: thunder rumble format must be 16-bit")
		if thunder_stream.mix_rate != 44100:
			failures.append("Test 3 Failed: thunder rumble mix_rate must be 44100")

	# Test 4: create_cicada_swarm_loop produces valid non-empty AudioStreamWAV with LOOP_FORWARD
	var cicada_stream = AudioSynthesizerClass.create_cicada_swarm_loop(1.2)
	if cicada_stream == null or not (cicada_stream is AudioStreamWAV):
		failures.append("Test 4 Failed: create_cicada_swarm_loop must return an AudioStreamWAV")
	else:
		if cicada_stream.data.is_empty():
			failures.append("Test 4 Failed: cicada swarm stream data is empty")
		if cicada_stream.loop_mode != AudioStreamWAV.LOOP_FORWARD:
			failures.append("Test 4 Failed: cicada swarm stream must have LOOP_FORWARD enabled")
		if cicada_stream.loop_end <= 0:
			failures.append("Test 4 Failed: cicada swarm stream loop_end must be > 0")

	# Test 5: create_frog_croak and create_water_droplet produce valid streams
	var frog_stream = AudioSynthesizerClass.create_frog_croak(0.45)
	if frog_stream == null or not (frog_stream is AudioStreamWAV) or frog_stream.data.is_empty():
		failures.append("Test 5 Failed: create_frog_croak must return a valid non-empty AudioStreamWAV")

	var droplet_stream = AudioSynthesizerClass.create_water_droplet(1200.0)
	if droplet_stream == null or not (droplet_stream is AudioStreamWAV) or droplet_stream.data.is_empty():
		failures.append("Test 5 Failed: create_water_droplet must return a valid non-empty AudioStreamWAV")

	# Test 6: OpenDouEventPlayer3D & OpenDouEventPlayer with nature presets auto-generate streams on _ready()
	var nature_presets = ["Wind_Canopy", "Bird_Chirp", "Thunder_Rumble", "Cicada_Swarm", "Frog_Croak", "Water_Droplet", "Cyber_Hornet"]
	for preset in nature_presets:
		var p3d = OpenDouEventPlayer3DClass.new()
		p3d.synth_preset = preset
		p3d._ready()
		if p3d.stream == null or not (p3d.stream is AudioStreamWAV) or p3d.stream.data.is_empty():
			failures.append("Test 6 Failed: OpenDouEventPlayer3D failed to generate stream for preset '%s'" % preset)
		p3d.free()

		var p = OpenDouEventPlayerClass.new()
		p.synth_preset = preset
		p._ready()
		if p.stream == null or not (p.stream is AudioStreamWAV) or p.stream.data.is_empty():
			failures.append("Test 6 Failed: OpenDouEventPlayer failed to generate stream for preset '%s'" % preset)
		p.free()

	# Test auto-infer presets from event_name
	var infer_tests: Dictionary = {
		"amb_canopy_wind": "Wind_Canopy",
		"sfx_bird_chirp_distant": "Bird_Chirp",
		"weather_thunder_strike": "Thunder_Rumble",
		"amb_cicada_swarm_summer": "Cicada_Swarm",
		"sfx_frog_croak_pond": "Frog_Croak",
		"sfx_water_droplet_cave": "Water_Droplet"
	}
	for ev_name in infer_tests.keys():
		var expected_preset: String = infer_tests[ev_name]
		var p_infer = OpenDouEventPlayer3DClass.new()
		p_infer.event_name = StringName(ev_name)
		p_infer._ready()
		if p_infer.synth_preset != expected_preset:
			failures.append("Test 6 Failed: Auto-infer for '%s' expected '%s', got '%s'" % [ev_name, expected_preset, p_infer.synth_preset])
		if p_infer.stream == null:
			failures.append("Test 6 Failed: Auto-infer for '%s' did not create stream" % ev_name)
		p_infer.free()

	# Test 7: Standardized Footstep DSP for all 10 surfaces & SurfaceType sync verification
	var expected_surfaces = ["Wood", "Concrete", "Metal", "Water", "Tile", "Foliage", "Stone", "Asphalt", "Mud", "Glass"]
	for surface in expected_surfaces:
		for v in [1, 2, 3]:
			var footstep = AudioSynthesizerClass.create_footstep(StringName(surface), v)
			if footstep == null or not (footstep is AudioStreamWAV):
				failures.append("Test 7 Failed: create_footstep('%s', %d) must return AudioStreamWAV" % [surface, v])
			else:
				var expected_bytes = int(0.22 * 44100) * 2
				if footstep.data.size() != expected_bytes:
					failures.append("Test 7 Failed: footstep '%s' var %d size mismatch (got %d, expected %d)" % [surface, v, footstep.data.size(), expected_bytes])
				if footstep.format != AudioStreamWAV.FORMAT_16_BITS:
					failures.append("Test 7 Failed: footstep '%s' format must be 16-bit" % surface)
				if footstep.mix_rate != 44100:
					failures.append("Test 7 Failed: footstep '%s' mix_rate must be 44100" % surface)
				var expected_name = "%s_%d.wav" % [surface.to_lower(), v]
				if footstep.resource_name != expected_name:
					failures.append("Test 7 Failed: footstep '%s' resource_name mismatch (got '%s', expected '%s')" % [surface, footstep.resource_name, expected_name])

	# Alias check: Grass should also produce valid footstep
	var grass_step = AudioSynthesizerClass.create_footstep(&"Grass", 1)
	if grass_step == null or grass_step.data.is_empty() or grass_step.resource_name != "grass_1.wav":
		failures.append("Test 7 Failed: Grass footstep alias failed")

	# Verify opendou_syncs.json SurfaceType definition
	var syncs_file = FileAccess.open("res://opendou_syncs.json", FileAccess.READ)
	if syncs_file == null:
		failures.append("Test 7 Failed: Cannot open res://opendou_syncs.json")
	else:
		var json_str = syncs_file.get_as_text()
		syncs_file.close()
		var json_obj = JSON.parse_string(json_str)
		if json_obj == null or not json_obj.has("switches") or not json_obj["switches"].has("SurfaceType"):
			failures.append("Test 7 Failed: opendou_syncs.json missing switches.SurfaceType")
		else:
			var surface_list: Array = json_obj["switches"]["SurfaceType"]
			var required_10 = ["Asphalt", "Concrete", "Foliage", "Glass", "Metal", "Mud", "Stone", "Tile", "Water", "Wood"]
			for req in required_10:
				if not surface_list.has(req):
					failures.append("Test 7 Failed: SurfaceType in opendou_syncs.json is missing '%s'" % req)

	return failures
