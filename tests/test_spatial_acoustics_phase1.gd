class_name TestSpatialAcousticsPhase1
extends RefCounted

const AcousticMaterialRegistryClass = preload("res://addons/opendou/runtime/spatial/acoustic_material_registry.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	var registry = AcousticMaterialRegistryClass.get_singleton()
	
	# Test 1: Canonical materials verification
	var canonical_materials: Array[StringName] = [
		&"Concrete",
		&"Stone",
		&"Metal",
		&"Glass",
		&"Wood",
		&"Foliage",
		&"Water",
		&"Asphalt"
	]
	
	for mat_name in canonical_materials:
		var data = registry.get_material(mat_name)
		if data.is_empty():
			failures.append("Test 1 Failed: Canonical material '%s' not found in registry" % mat_name)
			continue
		if not data.has("density") or data["density"] <= 0.0:
			failures.append("Test 1 Failed: Material '%s' invalid density (%s)" % [mat_name, str(data.get("density"))])
		if not data.has("resonance_lpf") or data["resonance_lpf"] <= 0.0:
			failures.append("Test 1 Failed: Material '%s' invalid resonance_lpf (%s)" % [mat_name, str(data.get("resonance_lpf"))])
		if not data.has("absorption") or data["absorption"] < 0.0 or data["absorption"] > 1.0:
			failures.append("Test 1 Failed: Material '%s' invalid absorption (%s)" % [mat_name, str(data.get("absorption"))])
	
	# Fallback verification for unknown material
	var unknown_mat = registry.get_material(&"Unobtanium")
	if unknown_mat.is_empty() or not unknown_mat.has("density"):
		failures.append("Test 1 Failed: Unknown material fallback should return default (Concrete) data")
	
	# Test 2: calculate_transmission_loss & Custom material registration
	var concrete_loss = registry.calculate_transmission_loss(&"Concrete", 0.5, 1000.0)
	var wood_loss = registry.calculate_transmission_loss(&"Wood", 0.5, 1000.0)
	
	if not (concrete_loss.has("attenuation_db") and concrete_loss.has("cutoff_lpf")):
		failures.append("Test 2 Failed: calculate_transmission_loss returned missing keys for Concrete")
	else:
		if concrete_loss["attenuation_db"] <= wood_loss["attenuation_db"]:
			failures.append("Test 2 Failed: 0.5m Concrete attenuation (%.2f dB) should be > 0.5m Wood (%.2f dB)" % [
				concrete_loss["attenuation_db"], wood_loss["attenuation_db"]
			])
		if concrete_loss["cutoff_lpf"] > 500.0:
			failures.append("Test 2 Failed: 0.5m Concrete cutoff LPF should be <= 500 Hz, got %.2f Hz" % concrete_loss["cutoff_lpf"])
	
	var thin_wood_loss = registry.calculate_transmission_loss(&"Wood", 0.1, 1000.0)
	if thin_wood_loss["cutoff_lpf"] <= 5000.0:
		failures.append("Test 2 Failed: 0.1m Wood cutoff LPF should be > 5000 Hz, got %.2f Hz" % thin_wood_loss["cutoff_lpf"])
	
	# Custom material registration
	registry.register_custom_material(&"LeadShield", 11340.0, 150.0, 0.01)
	var lead_mat = registry.get_material(&"LeadShield")
	if is_equal_approx(lead_mat.get("density", 0.0), 11340.0) == false or is_equal_approx(lead_mat.get("resonance_lpf", 0.0), 150.0) == false:
		failures.append("Test 2 Failed: Custom material LeadShield was not registered correctly")
	
	var lead_loss = registry.calculate_transmission_loss(&"LeadShield", 0.1, 1000.0)
	if lead_loss["attenuation_db"] <= 0.0:
		failures.append("Test 2 Failed: LeadShield transmission loss attenuation should be > 0 dB")
	
	return failures
