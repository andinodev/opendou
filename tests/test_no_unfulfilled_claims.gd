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

	# plugin.cfg sigue sin prometer HRTF: es una descripcion de una linea y no puede
	# matizar. El README SI puede mencionarlo desde la Fase 7B, porque existe y se mide
	# (tests/test_binaural.gd), pero solo si la extension esta en el repo y el texto dice
	# que es opcional y que sin ella todo funciona: la promesa tiene que ir con su limite.
	var cfg = FileAccess.open("res://addons/opendou/plugin.cfg", FileAccess.READ)
	if cfg == null:
		a.ok(false, "no se pudo leer plugin.cfg")
	else:
		var cfg_text: String = cfg.get_as_text().to_lower()
		cfg.close()
		a.ok(not cfg_text.contains("hrtf"), "plugin.cfg no menciona HRTF")
		a.ok(not cfg_text.contains("binaural"), "plugin.cfg no menciona binaural")

	var rf = FileAccess.open("res://README.md", FileAccess.READ)
	if rf != null:
		var rtext: String = rf.get_as_text()
		rf.close()
		var lower := rtext.to_lower()
		var native_exists: bool = FileAccess.file_exists("res://native/src/spatial_stream.cpp")
		if lower.contains("hrtf") or lower.contains("binaural"):
			a.ok(native_exists, "si el README menciona HRTF/binaural, la extension nativa existe en el repo")
			a.ok(lower.contains("sin la extension") or lower.contains("opcional"),
				"y dice que la extension es opcional: sin ella todo funciona")
		if lower.contains("gdextension"):
			a.ok(lower.contains("opcional") or lower.contains("planificad") or lower.contains("planned"),
				"la mencion a GDExtension se marca como opcional (existe) o planificada (no existe)")
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
			"res://addons/opendou/runtime/bank_stream_playback.gd",
			"res://addons/opendou/runtime/spatial/hdr_audio_manager.gd"]:
		a.ok(not FileAccess.file_exists(path), "%s no existe" % path)

	# Los .import llevan el UID del recurso: sin versionarlos, cada clon regenera
	# UIDs distintos. Godot documenta que deben ir al control de versiones.
	var gitignore := FileAccess.open("res://.gitignore", FileAccess.READ)
	if gitignore != null:
		var gtext: String = gitignore.get_as_text()
		gitignore.close()
		var ignores_import := false
		for line in gtext.split("\n"):
			if line.strip_edges() == "*.import":
				ignores_import = true
				break
		a.ok(not ignores_import, ".gitignore no ignora *.import")

	# Y cada icono SVG debe tener su .import al lado.
	var missing: Array[String] = []
	var icons := DirAccess.open("res://addons/opendou/icons")
	if icons != null:
		icons.list_dir_begin()
		var n: String = icons.get_next()
		while n != "":
			if n.ends_with(".svg") and not FileAccess.file_exists("res://addons/opendou/icons/%s.import" % n):
				missing.append(n)
			n = icons.get_next()
		icons.list_dir_end()
	a.eq(missing.size(), 0, "todos los iconos SVG tienen su .import, faltan: %s" % str(missing))

	# Los documentos VIVOS no deben apuntar al disco de otra persona. Los historicos
	# (completed.md, plans/*.md) se dejan a proposito: son registro de lo que se hizo.
	for doc in ["res://README.md", "res://GEMINI.md", "res://docs/README.md",
			"res://docs/tasks/current.md", "res://docs/tasks/backlog.md",
			"res://docs/tasks/roadmap.md"]:
		var df = FileAccess.open(doc, FileAccess.READ)
		if df == null:
			a.ok(false, "no se pudo leer %s" % doc)
			continue
		var dtext: String = df.get_as_text()
		df.close()
		a.ok(not dtext.contains("file:///c:/"), "%s no tiene enlaces file:///c:/" % doc)

	return a
