class_name OpenDouWavMarkers
extends RefCounted

## Lee los marcadores (chunk `cue`) de un archivo WAV en disco, con sus etiquetas
## (LIST/adtl/labl), y los devuelve como AudioMarker en segundos. AudioStreamWAV no conserva
## estos chunks, por eso se lee el archivo original.

const AudioMarkerClass = preload("res://addons/opendou/resources/audio_marker.gd")

static func read_cues(path: String) -> Array:
	var out: Array = []
	if not FileAccess.file_exists(path):
		return out
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() < 12 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF" or bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		return out
	var rate: int = 44100
	var cues: Dictionary = {}   # id -> muestra
	var labels: Dictionary = {} # id -> nombre
	var pos: int = 12
	while pos + 8 <= bytes.size():
		var cid: String = bytes.slice(pos, pos + 4).get_string_from_ascii()
		var size: int = bytes.decode_u32(pos + 4)
		var body: int = pos + 8
		if body + size > bytes.size():
			break
		match cid:
			"fmt ":
				rate = bytes.decode_u32(body + 4)
			"cue ":
				var count: int = bytes.decode_u32(body)
				for i in range(count):
					var e: int = body + 4 + i * 24
					if e + 24 <= body + size:
						cues[bytes.decode_u32(e)] = bytes.decode_u32(e + 20)
			"LIST":
				if bytes.slice(body, body + 4).get_string_from_ascii() == "adtl":
					var p: int = body + 4
					while p + 8 <= body + size:
						var sub: String = bytes.slice(p, p + 4).get_string_from_ascii()
						var sub_size: int = bytes.decode_u32(p + 4)
						if sub == "labl" and sub_size >= 4:
							var cue_id: int = bytes.decode_u32(p + 8)
							var text: PackedByteArray = bytes.slice(p + 12, p + 8 + sub_size)
							var end: int = text.find(0)
							labels[cue_id] = (text.slice(0, end) if end >= 0 else text).get_string_from_ascii()
						p += 8 + sub_size + (sub_size % 2)
		pos = body + size + (size % 2)
	var ids: Array = cues.keys()
	ids.sort_custom(func(x, y): return cues[x] < cues[y])
	for cue_id in ids:
		var mk = AudioMarkerClass.new()
		mk.name = StringName(str(labels.get(cue_id, "cue_%d" % cue_id)))
		mk.time_sec = float(cues[cue_id]) / float(maxi(rate, 1))
		out.append(mk)
	return out
