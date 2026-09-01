class_name TestNoUnfulfilledClaims
extends RefCounted

## El proyecto solo debe afirmar lo que hace. Este test vigila que las promesas
## retiradas no vuelvan a aparecer en la documentacion ni en los exports.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouEventPlayer3DClass = preload("res://addons/opendou/nodes/opendou_event_player_3d.gd")
const OpenDouEventPlayer2DClass = preload("res://addons/opendou/nodes/opendou_event_player_2d.gd")
const OpenDouEventPlayerClass = preload("res://addons/opendou/nodes/opendou_event_player.gd")

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("no_unfulfilled_claims")

	# El toggle no debe existir en ningun emisor.
	for entry in [[OpenDouEventPlayer3DClass, "3D"], [OpenDouEventPlayer2DClass, "2D"],
			[OpenDouEventPlayerClass, "no espacial"]]:
		var node = entry[0].new()
		a.has_no_property(node, "enable_binaural_hrtf", "emisor %s sin toggle de HRTF" % entry[1])
		node.free()

	# Ni README ni plugin.cfg deben prometer HRTF.
	for path in ["res://README.md", "res://addons/opendou/plugin.cfg"]:
		var f = FileAccess.open(path, FileAccess.READ)
		if f == null:
			a.ok(false, "no se pudo leer %s" % path)
			continue
		var text: String = f.get_as_text().to_lower()
		f.close()
		a.ok(not text.contains("hrtf"), "%s no menciona HRTF" % path)
		a.ok(not text.contains("binaural"), "%s no menciona binaural" % path)

	# El README no debe presentar como existente la capa GDExtension, que no
	# tiene una sola linea de C++ ni de Rust.
	var rf = FileAccess.open("res://README.md", FileAccess.READ)
	if rf != null:
		var rtext: String = rf.get_as_text()
		rf.close()
		var lower := rtext.to_lower()
		if lower.contains("gdextension"):
			a.ok(lower.contains("planificad") or lower.contains("planned"),
				"la mencion a GDExtension se marca como planificada")
		# Los enlaces absolutos de una maquina ajena no sirven a nadie.
		a.ok(not rtext.contains("file:///c:/"), "el README no tiene enlaces file:///c:/")

	# El roadmap no debe afirmar que el buffer es lock-free: en GDScript no hay
	# atomicos y nada corre en otro hilo.
	var rm = FileAccess.open("res://docs/tasks/roadmap.md", FileAccess.READ)
	if rm != null:
		var mtext: String = rm.get_as_text().to_lower()
		rm.close()
		a.ok(not mtext.contains("lock-free"), "el roadmap no afirma lock-free")

	# El streaming asincrono desde disco se retiro: GDScript no puede sostenerlo.
	# Los bancos se precargan como AudioStreamWAV.
	var readme := FileAccess.open("res://README.md", FileAccess.READ)
	if readme != null:
		var rtext: String = readme.get_as_text().to_lower()
		readme.close()
		a.ok(not rtext.contains("asynchronous background disk streaming"),
			"el README no promete streaming asincrono desde disco")

	# Y las clases que lo implementaban no deben volver.
	for path in ["res://addons/opendou/runtime/audio_ring_buffer.gd",
			"res://addons/opendou/runtime/bank_stream_playback.gd"]:
		a.ok(not FileAccess.file_exists(path), "%s no existe" % path)

	return a
