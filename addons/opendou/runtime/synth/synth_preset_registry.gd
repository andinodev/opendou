@tool
class_name SynthPresetRegistry
extends RefCounted

## Central persistent repository and runtime registry for OpenDou Procedural Synth presets.
## Manages loading/saving to JSON (opendou_synth_presets.json) and baking AudioStreamWAV instances on-demand.

static var _instance: SynthPresetRegistry = null

## Dictionary containing loaded synth presets keyed by preset name (String -> Dictionary).
var presets: Dictionary = {}

## Cache del hint_string del desplegable de presets del inspector.
##
## _get_property_list() de los emisores lo pedia en CADA refresco del inspector, y
## antes hacia un load() desde disco y enumeraba el registro entero cada vez.
##
## La cache vive aqui, y no en cada nodo, porque este es quien sabe cuando cambian
## los presets: se invalida desde los propios mutadores y nadie tiene que
## acordarse de llamar a nada.
var _hint_cache: String = ""

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
	invalidate_hint_cache()
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
	invalidate_hint_cache()
	presets[str(preset_name)] = preset_dict.duplicate(true)

## Removes a preset from the registry.
## [param preset_name]: The StringName identifier of the preset to delete.
func delete_preset(preset_name: StringName) -> void:
	invalidate_hint_cache()
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

## Returns the category of the given preset (e.g. "Leads", "Pads", "Bass", "Percussion", "Nature/Ambience", "SFX").
func get_preset_category(preset_name: StringName) -> String:
	var p = get_preset(preset_name)
	if p.has("category"):
		return str(p["category"])
	return "General"

## Returns all preset names matching the given category (case-insensitive). If category is "All" or empty, returns all presets.
func get_presets_by_category(category: String) -> Array[StringName]:
	if category.is_empty() or category.to_lower() == "all":
		return get_preset_names()
	var result: Array[StringName] = []
	var cat_lower = category.to_lower()
	for p_name in get_preset_names():
		if get_preset_category(p_name).to_lower() == cat_lower:
			result.append(p_name)
	return result

## Returns a sorted unique list of all categories present across all registered presets.
func get_all_categories() -> Array[String]:
	var cats: Dictionary = {}
	for p_name in get_preset_names():
		var c = get_preset_category(p_name)
		if not c.is_empty():
			cats[c] = true
	var arr: Array[String] = []
	for k in cats.keys():
		arr.append(str(k))
	arr.sort()
	return arr

## hint_string del desplegable de presets: "None" seguido de los nombres.
func get_preset_hint_string() -> String:
	if not _hint_cache.is_empty():
		return _hint_cache
	var names: Array[String] = ["None"]
	for p_name in get_preset_names():
		names.append(str(p_name))
	_hint_cache = ",".join(names)
	return _hint_cache

## Invalida la cache del desplegable.
##
## La llaman los mutadores de este registro. Es publica por si alguien modifica el
## diccionario de presets por fuera.
func invalidate_hint_cache() -> void:
	_hint_cache = ""
