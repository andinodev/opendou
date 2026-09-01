class_name TestRuntimeNoResWrites
extends RefCounted

## Guarda estatica: ningun archivo de runtime debe escribir en res://.
##
## Un build exportado no puede escribir en res://, asi que esa combinacion en codigo
## de runtime es siempre un defecto. El editor SI puede y debe escribir ahi: es como
## se autoran datos de proyecto, y por eso addons/opendou/editor/ no se inspecciona.
##
## Se midio que hoy no hay ninguna, y esta guarda existe para que siga siendo verdad.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")

const SCANNED_DIRS: Array[String] = [
	"res://addons/opendou/runtime",
	"res://addons/opendou/nodes",
	"res://addons/opendou/resources",
	"res://addons/opendou/core",
]

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("runtime_no_res_writes")

	var scanned: int = 0
	var offenders: Array[String] = []
	for dir_path in SCANNED_DIRS:
		for file_path in _gd_files_in(dir_path):
			scanned += 1
			var f = FileAccess.open(file_path, FileAccess.READ)
			if f == null:
				continue
			var text: String = f.get_as_text()
			f.close()
			if _writes_to_res(text):
				offenders.append(file_path)

	a.gt(float(scanned), 20.0, "la guarda inspecciono los archivos de runtime")
	a.eq(offenders.size(), 0, "ningun archivo de runtime escribe en res://, sobran: %s" % str(offenders))
	return a

## Busca un FileAccess.open en modo escritura en la misma linea que un literal res://.
static func _writes_to_res(text: String) -> bool:
	for line in text.split("\n"):
		var l: String = line.strip_edges()
		if l.begins_with("#"):
			continue
		if not l.contains("FileAccess.open"):
			continue
		if not (l.contains("FileAccess.WRITE") or l.contains("WRITE_READ")):
			continue
		if l.contains('"res://'):
			return true
	return false

static func _gd_files_in(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				out.append_array(_gd_files_in(full))
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return out
