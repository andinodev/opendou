class_name TestPresetHintCache
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const SynthPresetRegistryClass = preload("res://addons/opendou/runtime/synth/synth_preset_registry.gd")
const OpenDouEventPlayer3DClass = preload("res://addons/opendou/nodes/opendou_event_player_3d.gd")

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("preset_hint_cache")

	var reg = SynthPresetRegistryClass.get_singleton()
	a.ok(reg != null, "el registro de presets existe")
	if reg == null:
		return a

	# El hint empieza por "None" y lista los presets.
	var hint: String = reg.get_preset_hint_string()
	a.ok(hint.begins_with("None"), "el hint empieza por None")

	# Dos llamadas devuelven exactamente lo mismo: la cache funciona.
	a.eq(reg.get_preset_hint_string(), hint, "dos llamadas devuelven el mismo hint")

	# Un preset nuevo APARECE sin que nadie invalide a mano: el registro se invalida
	# solo desde sus mutadores. Sin eso, la cache seria un defecto peor que el que
	# arregla.
	var probe_name := &"__ProbePresetParaCache__"
	reg.set_preset(probe_name, {"type": "Single_Generator", "generator_type": "Sine", "duration": 0.1})
	var hint_after: String = reg.get_preset_hint_string()
	a.ok(hint_after.contains(String(probe_name)), "un preset nuevo aparece en el hint")
	a.ok(hint_after != hint, "el hint cambio al anadir el preset")

	# Y desaparece al borrarlo.
	reg.delete_preset(probe_name)
	a.ok(not reg.get_preset_hint_string().contains(String(probe_name)),
		"el preset borrado desaparece del hint")

	# La propiedad synth_preset sigue existiendo en el emisor, con su desplegable:
	# la cache no puede romper la persistencia en escena.
	# synth_preset aparece DOS veces en get_property_list(): una como variable de
	# script, que el inspector no muestra, y otra la que anade
	# _get_property_list(), que es la del desplegable. Hay que buscar esa segunda,
	# no cortar en la primera coincidencia.
	var emitter = OpenDouEventPlayer3DClass.new()
	var dropdown_hint := ""
	var found_dropdown := false
	for p in emitter.get_property_list():
		if String(p["name"]) == "synth_preset" and int(p["hint"]) == PROPERTY_HINT_ENUM:
			found_dropdown = true
			dropdown_hint = String(p["hint_string"])
			break
	a.ok(found_dropdown, "synth_preset sigue expuesta como desplegable en el inspector")
	a.ok(dropdown_hint.begins_with("None"), "el desplegable arranca en None")
	emitter.free()

	return a
