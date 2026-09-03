class_name TestAcousticMaterial
extends RefCounted

## Fase 12: materiales por banda (absorcion, dispersion, transmision) y su registro.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const MaterialClass = preload("res://addons/opendou/resources/acoustic_material.gd")
const RegistryClass = preload("res://addons/opendou/runtime/spatial/acoustic_material_registry.gd")

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("acoustic_material")
	for name in [&"Concrete", &"Stone", &"Metal", &"Glass", &"Wood", &"Foliage", &"Water", &"Asphalt"]:
		var m = MaterialClass.from_preset(name)
		a.ok(m != null, "preset %s existe" % name)
		var v: PackedFloat32Array = m.to_ipl()
		a.eq(v.size(), 7, "%s: siete numeros" % name)
		var in_range: bool = true
		for x in v:
			if x < 0.0 or x > 1.0:
				in_range = false
		a.ok(in_range, "%s: valores en [0,1]" % name)
	var glass = MaterialClass.from_preset(&"Glass")
	var concrete = MaterialClass.from_preset(&"Concrete")
	a.gt(glass.transmission_high, concrete.transmission_high, "el cristal transmite mas agudos que el hormigon")
	a.gt(MaterialClass.from_preset(&"Foliage").absorption_high, 0.5, "el follaje absorbe los agudos")
	a.eq(MaterialClass.from_preset(&"Velvet"), null, "un preset inexistente es null")
	var reg = RegistryClass.new()
	var custom = MaterialClass.new()
	custom.material_name = &"Velvet"
	custom.absorption_low = 0.2; custom.absorption_mid = 0.5; custom.absorption_high = 0.7
	custom.scattering = 0.3
	custom.transmission_low = 0.1; custom.transmission_mid = 0.05; custom.transmission_high = 0.01
	reg.register_acoustic_material(custom)
	a.approx(reg.get_material(&"Velvet").get("absorption", 0.0), 0.5, "el fallback escalar toma la banda media", 0.0001)
	var path := "user://opendou_materials_test.json"
	a.eq(reg.save_to_json(path), OK, "guarda el JSON")
	var reg2 = RegistryClass.new()
	reg2.load_from_json(path)
	var back = reg2.get_acoustic_material(&"Velvet")
	a.ok(back != null, "el material personalizado se recarga")
	if back != null:
		a.approx(back.absorption_mid, 0.5, "con sus bandas", 0.0001)
		a.approx(back.transmission_high, 0.01, "y su transmision", 0.0001)
	a.eq(String(reg2.get_acoustic_material(&"Metal").material_name), "Metal", "los presets siguen ahi")
	a.eq(reg2.acoustic_material_names().size(), 9, "ocho presets mas el personalizado")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return a
