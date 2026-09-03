@tool
class_name AcousticMaterialRegistry
extends RefCounted

const DataPathsClass = preload("res://addons/opendou/runtime/data_paths.gd")

## Centralized physical acoustic material matrix and mass-law transmission loss engine.
## Provides physically grounded density, structural resonance LPF cutoff, and absorption coefficients.

static var _instance: RefCounted = null

## Canonical physical materials dictionary (Immutable defaults).
const DEFAULT_MATERIALS: Dictionary = {
	&"Concrete": {
		"density": 2400.0,
		"resonance_lpf": 350.0,
		"absorption": 0.05
	},
	&"Stone": {
		"density": 2400.0,
		"resonance_lpf": 350.0,
		"absorption": 0.05
	},
	&"Metal": {
		"density": 7800.0,
		"resonance_lpf": 1200.0,
		"absorption": 0.02
	},
	&"Glass": {
		"density": 2500.0,
		"resonance_lpf": 800.0,
		"absorption": 0.03
	},
	&"Wood": {
		"density": 700.0,
		"resonance_lpf": 2000.0,
		"absorption": 0.15
	},
	&"Foliage": {
		"density": 150.0,
		"resonance_lpf": 4500.0,
		"absorption": 0.85
	},
	&"Water": {
		"density": 1000.0,
		"resonance_lpf": 600.0,
		"absorption": 0.01
	},
	&"Asphalt": {
		"density": 2100.0,
		"resonance_lpf": 400.0,
		"absorption": 0.08
	}
}

## Registered materials (loaded defaults + custom user materials).
var _materials: Dictionary = {}
## Materiales por banda (Fase 12): nombre -> AcousticMaterial. Los ocho presets al arrancar.
var _acoustic: Dictionary = {}
const AcousticMaterialClass = preload("res://addons/opendou/resources/acoustic_material.gd")

func _init() -> void:
	_reset_to_defaults()
	load_from_json()

static func get_singleton():
	if _instance == null:
		var script = load("res://addons/opendou/runtime/spatial/acoustic_material_registry.gd") as GDScript
		_instance = script.new()
	return _instance

static func get_instance():
	return get_singleton()

func _reset_to_defaults() -> void:
	_materials.clear()
	for k in DEFAULT_MATERIALS.keys():
		_materials[k] = DEFAULT_MATERIALS[k].duplicate(true)
	_acoustic.clear()
	for k in AcousticMaterialClass.PRESETS.keys():
		_acoustic[k] = AcousticMaterialClass.from_preset(k)

## Material por banda registrado o preset; null si no existe.
func get_acoustic_material(mat_name: StringName) -> AcousticMaterial:
	if _acoustic.has(mat_name):
		return _acoustic[mat_name]
	return AcousticMaterialClass.from_preset(mat_name)

## Registra un material por banda y actualiza el fallback escalar con sus numeros.
func register_acoustic_material(mat: AcousticMaterial) -> void:
	if mat == null:
		return
	_acoustic[mat.material_name] = mat
	register_custom_material(mat.material_name, mat.density_kg_m3, mat.resonance_lpf_hz, mat.absorption_mid)

func acoustic_material_names() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in _acoustic:
		out.append(k)
	return out

## Guarda todos los materiales por banda en JSON (los presets tambien: el archivo es completo).
func save_to_json(path: String) -> Error:
	var data: Dictionary = {}
	for k in _acoustic:
		data[String(k)] = (_acoustic[k] as AcousticMaterial).to_dict()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return OK

## Returns material property dictionary copy, or default (Concrete) if not found.
func get_material(mat_name: StringName) -> Dictionary:
	if _materials.has(mat_name):
		return (_materials[mat_name] as Dictionary).duplicate(true)
	# Fallback to Concrete
	return (_materials.get(&"Concrete", DEFAULT_MATERIALS[&"Concrete"]) as Dictionary).duplicate(true)

## Returns true if material is registered.
func has_material(mat_name: StringName) -> bool:
	return _materials.has(mat_name)

## Returns material resonance LPF cutoff frequency in Hz.
func get_material_cutoff(mat_name: StringName) -> float:
	return float(get_material(mat_name).get("resonance_lpf", 350.0))

## Returns material physical density in kg/m3.
func get_material_density(mat_name: StringName) -> float:
	return float(get_material(mat_name).get("density", 2400.0))

## Registers or overrides a custom physical acoustic material.
func register_custom_material(mat_name: StringName, density: float, resonance_lpf: float, absorption: float) -> void:
	_materials[mat_name] = {
		"density": maxf(1.0, density),
		"resonance_lpf": clampf(resonance_lpf, 20.0, 20000.0),
		"absorption": clampf(absorption, 0.0, 1.0)
	}

## Calculates physical mass-law transmission loss and effective LPF cutoff frequency through a barrier.
## Returns Dictionary {"attenuation_db": float, "cutoff_lpf": float}
func calculate_transmission_loss(mat_name: StringName, thickness_meters: float, center_freq: float = 1000.0) -> Dictionary:
	var mat = get_material(mat_name)
	var density: float = float(mat.get("density", 2400.0))
	var res_lpf: float = float(mat.get("resonance_lpf", 350.0))
	
	var safe_thickness: float = maxf(0.001, thickness_meters)
	var safe_freq: float = maxf(20.0, center_freq)
	
	# Acoustic Mass-Law Formulation for Game Audio:
	# TL_dB = 20.0 * log10(1.0 + (density / 500.0) * thickness * sqrt(freq / 1000.0))
	var mass_factor: float = (density / 500.0) * safe_thickness * sqrt(safe_freq / 1000.0)
	var attenuation_db: float = clampf(20.0 * (log(1.0 + mass_factor) / log(10.0)), 0.0, 48.0)
	
	# LPF Cutoff Interpolation: thicker walls lower the cutoff towards the material's resonance LPF
	var thickness_ratio: float = clampf(safe_thickness / 0.5, 0.0, 1.0)
	var cutoff_lpf: float = lerpf(20000.0, res_lpf, thickness_ratio)
	
	return {
		"attenuation_db": attenuation_db,
		"cutoff_lpf": cutoff_lpf
	}

## Loads optional custom material overrides from project JSON.
## Carga materiales acusticos desde JSON, si hay archivo.
##
## No hay default en el addon a proposito: los coeficientes ya estan en codigo, y un
## JSON duplicado seria dos fuentes de verdad para lo mismo. Este archivo es un
## override opcional del proyecto.
func load_from_json(path: String = "") -> void:
	if path.is_empty():
		path = DataPathsClass.resolve(DataPathsClass.ACOUSTIC_MATERIALS)
	if path.is_empty():
		return
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json_str = file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(json_str)
	if typeof(parsed) == TYPE_DICTIONARY:
		for k in parsed.keys():
			var item = parsed[k]
			if typeof(item) == TYPE_DICTIONARY:
				var density = float(item.get("density", 2400.0))
				var resonance = float(item.get("resonance_lpf", 350.0))
				var absorption = float(item.get("absorption", 0.05))
				register_custom_material(StringName(str(k)), density, resonance, absorption)
				# Bandas (Fase 12): si el JSON las trae, el material por banda tambien.
				_acoustic[StringName(str(k))] = AcousticMaterialClass.from_dict(StringName(str(k)), item)
