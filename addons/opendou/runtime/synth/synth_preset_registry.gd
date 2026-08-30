@tool
class_name SynthPresetRegistry
extends RefCounted

## Central persistent repository and runtime registry for OpenDou Procedural Synth presets.
## Manages loading/saving to JSON (opendou_synth_presets.json) and baking AudioStreamWAV instances on-demand.

static var _instance: SynthPresetRegistry = null

## Dictionary containing loaded synth presets keyed by preset name (String -> Dictionary).
var presets: Dictionary = {}

## Returns the singleton instance of SynthPresetRegistry, instantiating and loading default presets if needed.
static func get_singleton() -> SynthPresetRegistry:
	if _instance == null:
		_instance = SynthPresetRegistry.new()
		_instance.load_presets()
	return _instance

## Loads synth presets from a JSON file path.
## [param json_path]: Resource or OS file path to presets JSON.
## [returns]: True if presets loaded successfully, false otherwise.
func load_presets(json_path: String = "res://opendou_synth_presets.json") -> bool:
	if not FileAccess.file_exists(json_path):
		return false

	var file = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		return false

	var content: String = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(content)
	if not (parsed is Dictionary):
		return false

	if parsed.has("presets") and parsed["presets"] is Dictionary:
		presets = (parsed["presets"] as Dictionary).duplicate(true)
	else:
		presets = (parsed as Dictionary).duplicate(true)

	return true

## Saves currently registered synth presets to a JSON file path.
## [param json_path]: Destination file path.
## [returns]: True if saved successfully, false otherwise.
func save_presets(json_path: String = "res://opendou_synth_presets.json") -> bool:
	var save_dict: Dictionary = {
		"presets": presets
	}
	var json_str: String = JSON.stringify(save_dict, "\t")
	var file = FileAccess.open(json_path, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(json_str)
	file.flush()
	file.close()
	return true

## Returns all available preset names as a sorted Array of StringName identifiers.
func get_preset_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for k in presets.keys():
		names.append(StringName(str(k)))
	names.sort()
	return names

## Retrieves the configuration dictionary for a given preset.
## [param preset_name]: The StringName identifier of the preset.
## [returns]: A deep copy of the preset dictionary, or an empty dictionary if not found.
func get_preset(preset_name: StringName) -> Dictionary:
	var key_str: String = str(preset_name)
	if presets.has(key_str) and presets[key_str] is Dictionary:
		return (presets[key_str] as Dictionary).duplicate(true)
	if presets.has(preset_name) and presets[preset_name] is Dictionary:
		return (presets[preset_name] as Dictionary).duplicate(true)
	return {}

## Registers or updates a preset configuration dictionary in the registry.
## [param preset_name]: The StringName identifier of the preset.
## [param preset_dict]: The preset configuration dictionary.
func set_preset(preset_name: StringName, preset_dict: Dictionary) -> void:
	presets[str(preset_name)] = preset_dict.duplicate(true)

## Removes a preset from the registry.
## [param preset_name]: The StringName identifier of the preset to delete.
func delete_preset(preset_name: StringName) -> void:
	presets.erase(str(preset_name))
	presets.erase(preset_name)

## Generates a ready-to-play AudioStreamWAV resource for a registered preset.
## Falls back to a default sine wave tone if the preset is not found.
## [param preset_name]: The preset identifier to synthesize.
## [param rng_seed]: Random seed for stochastic parameter variations (0 for randomized).
## [returns]: A synthesized AudioStreamWAV resource.
func get_preset_stream(preset_name: StringName, rng_seed: int = 0) -> AudioStreamWAV:
	var p_dict = get_preset(preset_name)
	if p_dict.is_empty():
		var fallback_dict: Dictionary = {
			"type": "Single_Generator",
			"generator_type": "Basic_Wave",
			"wave_type": "Sine",
			"base_freq": 440.0,
			"duration": 0.5,
			"gain_db": -6.0,
			"loop_mode": false
		}
		return ModularSynthEngine.synthesize_wav(fallback_dict, rng_seed)

	return ModularSynthEngine.synthesize_wav(p_dict, rng_seed)
