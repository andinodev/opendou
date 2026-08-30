class_name TestSynthPresetRegistry
extends RefCounted

const SynthPresetRegistryClass = preload("res://addons/opendou/runtime/synth/synth_preset_registry.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []

	# Test 1: SynthPresetRegistry loads properly
	if SynthPresetRegistryClass == null:
		failures.append("Test 1 Failed: synth_preset_registry.gd failed to load")
		return failures

	# Test 2: Singleton instance retrieval
	var registry = SynthPresetRegistryClass.get_singleton()
	if registry == null:
		failures.append("Test 2 Failed: SynthPresetRegistry.get_singleton() returned null")
		return failures

	# Test 3: Load presets from default JSON path
	var loaded = registry.load_presets("res://opendou_synth_presets.json")
	if not loaded:
		failures.append("Test 3 Failed: load_presets() returned false for res://opendou_synth_presets.json")

	var preset_names = registry.get_preset_names()
	var expected_builtins = [
		"Wind_Canopy",
		"Waterfall_Stream",
		"Bird_Chirp",
		"Thunder_Rumble",
		"Cicada_Swarm",
		"Frog_Croak",
		"Water_Droplet",
		"Cyber_Hornet",
		"SciFi_Heavy_Explosion",
		"Plucked_Wood_Step",
		"EV_Electric_Engine",
		"Rain_Atmosphere",
		"Server_Hum"
	]
	for b in expected_builtins:
		if not preset_names.has(StringName(b)):
			failures.append("Test 3 Failed: get_preset_names() is missing built-in preset '%s'" % b)

	# Test 4: get_preset returns valid dictionary structure
	var wind_dict = registry.get_preset(&"Wind_Canopy")
	if wind_dict.is_empty():
		failures.append("Test 4 Failed: get_preset(&'Wind_Canopy') returned empty dictionary")
	elif wind_dict.get("generator_type", "") != "Filtered_Noise":
		failures.append("Test 4 Failed: Wind_Canopy generator_type should be Filtered_Noise")

	var explosion_dict = registry.get_preset(&"SciFi_Heavy_Explosion")
	if explosion_dict.is_empty():
		failures.append("Test 4 Failed: get_preset(&'SciFi_Heavy_Explosion') returned empty dictionary")
	elif explosion_dict.get("type", "") != "Layer_Container":
		failures.append("Test 4 Failed: SciFi_Heavy_Explosion type should be Layer_Container")
	elif not (explosion_dict.get("layers", []) is Array) or explosion_dict.get("layers", []).size() < 3:
		failures.append("Test 4 Failed: SciFi_Heavy_Explosion should have at least 3 layers")

	# Test 5: get_preset_stream synthesizes valid AudioStreamWAV for all built-ins
	for b in expected_builtins:
		var stream = registry.get_preset_stream(StringName(b), 42)
		if stream == null or not (stream is AudioStreamWAV):
			failures.append("Test 5 Failed: get_preset_stream for '%s' did not return AudioStreamWAV" % b)
		else:
			if stream.data.is_empty():
				failures.append("Test 5 Failed: stream data for '%s' is empty" % b)
			if stream.format != AudioStreamWAV.FORMAT_16_BITS:
				failures.append("Test 5 Failed: stream format for '%s' must be 16-bit PCM" % b)
			if stream.mix_rate <= 0:
				failures.append("Test 5 Failed: stream mix_rate for '%s' is invalid" % b)

			var p_dict = registry.get_preset(StringName(b))
			var is_loop = bool(p_dict.get("loop_mode", false))
			if is_loop and stream.loop_mode != AudioStreamWAV.LOOP_FORWARD:
				failures.append("Test 5 Failed: '%s' is marked loop_mode=true but stream.loop_mode is not LOOP_FORWARD" % b)
			elif not is_loop and stream.loop_mode != AudioStreamWAV.LOOP_DISABLED:
				failures.append("Test 5 Failed: '%s' is marked loop_mode=false but stream.loop_mode is not LOOP_DISABLED" % b)

	# Test 6: Graceful fallback for non-existent preset
	var fallback_stream = registry.get_preset_stream(&"Non_Existent_Preset_XYZ", 999)
	if fallback_stream == null or not (fallback_stream is AudioStreamWAV):
		failures.append("Test 6 Failed: Non-existent preset did not return fallback AudioStreamWAV")
	elif fallback_stream.data.is_empty():
		failures.append("Test 6 Failed: Fallback stream data is empty")

	# Test 7: Custom preset creation, stream synthesis, temporary file save & reload, and deletion
	var custom_name = &"Custom_Laser_Zap"
	var custom_dict = {
		"type": "Single_Generator",
		"generator_type": "FM_Chirp",
		"base_freq": 1500.0,
		"base_freq_var": 0.05,
		"mod_mult": 2.0,
		"mod_index": 3.0,
		"frequency_sweep": {
			"start_mult": 2.0,
			"end_mult": 0.2
		},
		"duration": 0.2,
		"gain_db": -3.0,
		"loop_mode": false
	}
	registry.set_preset(custom_name, custom_dict)
	if not registry.get_preset_names().has(custom_name):
		failures.append("Test 7 Failed: Custom preset was not registered in get_preset_names()")

	var custom_stream = registry.get_preset_stream(custom_name, 123)
	if custom_stream == null or custom_stream.data.is_empty():
		failures.append("Test 7 Failed: Custom preset stream generation failed")

	# Save to temp JSON file
	var temp_json = "res://temp_test_synth_presets.json"
	var save_ok = registry.save_presets(temp_json)
	if not save_ok:
		failures.append("Test 7 Failed: save_presets to temp file failed")
	else:
		var fresh_registry = SynthPresetRegistryClass.new()
		var load_temp_ok = fresh_registry.load_presets(temp_json)
		if not load_temp_ok:
			failures.append("Test 7 Failed: load_presets from temp file failed")
		elif not fresh_registry.get_preset_names().has(custom_name):
			failures.append("Test 7 Failed: Reloaded temp registry missing custom preset '%s'" % custom_name)
		
		# Clean up temp file
		var global_temp = ProjectSettings.globalize_path(temp_json)
		if FileAccess.file_exists(global_temp):
			DirAccess.remove_absolute(global_temp)

	# Delete custom preset
	registry.delete_preset(custom_name)
	if registry.get_preset_names().has(custom_name):
		failures.append("Test 7 Failed: delete_preset did not remove custom preset from registry")

	return failures
