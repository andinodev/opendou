@tool
class_name AcousticMaterial
extends Resource

## Material acustico por banda (Fase 12): los siete numeros de IPLMaterial de Steam Audio mas
## la densidad y el corte que usa el fallback GDScript. Bandas: baja, media, alta.

@export var material_name: StringName = &"Concrete"
@export_group("Absorcion")
@export_range(0.0, 1.0, 0.001) var absorption_low: float = 0.05
@export_range(0.0, 1.0, 0.001) var absorption_mid: float = 0.07
@export_range(0.0, 1.0, 0.001) var absorption_high: float = 0.08
@export_group("Dispersion")
@export_range(0.0, 1.0, 0.001) var scattering: float = 0.05
@export_group("Transmision")
@export_range(0.0, 1.0, 0.001) var transmission_low: float = 0.015
@export_range(0.0, 1.0, 0.001) var transmission_mid: float = 0.002
@export_range(0.0, 1.0, 0.001) var transmission_high: float = 0.001
@export_group("Fallback GDScript")
@export var density_kg_m3: float = 2400.0
@export var resonance_lpf_hz: float = 350.0

## nombre -> [abs_l, abs_m, abs_h, scat, tr_l, tr_m, tr_h, densidad, corte]
const PRESETS: Dictionary = {
	&"Concrete": [0.05, 0.07, 0.08, 0.05, 0.015, 0.002, 0.001, 2400.0, 350.0],
	&"Stone":    [0.13, 0.20, 0.24, 0.05, 0.015, 0.002, 0.001, 2400.0, 350.0],
	&"Metal":    [0.20, 0.07, 0.06, 0.05, 0.200, 0.025, 0.010, 7800.0, 1200.0],
	&"Glass":    [0.06, 0.03, 0.02, 0.05, 0.060, 0.044, 0.011, 2500.0, 800.0],
	&"Wood":     [0.11, 0.07, 0.06, 0.05, 0.070, 0.014, 0.005, 700.0, 2000.0],
	&"Foliage":  [0.30, 0.60, 0.80, 0.60, 0.500, 0.300, 0.150, 150.0, 4500.0],
	&"Water":    [0.01, 0.01, 0.02, 0.05, 0.010, 0.002, 0.001, 1000.0, 600.0],
	&"Asphalt":  [0.10, 0.15, 0.20, 0.10, 0.010, 0.002, 0.001, 2100.0, 400.0],
}

static func from_preset(name: StringName) -> AcousticMaterial:
	if not PRESETS.has(name):
		return null
	var p: Array = PRESETS[name]
	var m := AcousticMaterial.new()
	m.material_name = name
	m.absorption_low = p[0]; m.absorption_mid = p[1]; m.absorption_high = p[2]
	m.scattering = p[3]
	m.transmission_low = p[4]; m.transmission_mid = p[5]; m.transmission_high = p[6]
	m.density_kg_m3 = p[7]; m.resonance_lpf_hz = p[8]
	return m

## Orden de IPLMaterial: absorption[3], scattering, transmission[3].
func to_ipl() -> PackedFloat32Array:
	return PackedFloat32Array([absorption_low, absorption_mid, absorption_high, scattering, transmission_low, transmission_mid, transmission_high])

func to_dict() -> Dictionary:
	return {"bands": Array(to_ipl()), "density": density_kg_m3, "resonance_lpf": resonance_lpf_hz, "absorption": absorption_mid}

static func from_dict(name: StringName, d: Dictionary) -> AcousticMaterial:
	var m := AcousticMaterial.new()
	m.material_name = name
	var b: Array = d.get("bands", [])
	if b.size() == 7:
		m.absorption_low = float(b[0]); m.absorption_mid = float(b[1]); m.absorption_high = float(b[2])
		m.scattering = float(b[3])
		m.transmission_low = float(b[4]); m.transmission_mid = float(b[5]); m.transmission_high = float(b[6])
	else:
		# JSON antiguo: una sola absorcion, en las tres bandas.
		var a: float = float(d.get("absorption", 0.05))
		m.absorption_low = a; m.absorption_mid = a; m.absorption_high = a
	m.density_kg_m3 = float(d.get("density", 2400.0))
	m.resonance_lpf_hz = float(d.get("resonance_lpf", 350.0))
	return m
