@tool
class_name SynthLayerOps
extends RefCounted

## Pure operations on the `layers` array of a Layer_Container preset.
##
## Exists so the risky half of the layer editor — the half that can corrupt a
## preset — can be tested headless. The UI only calls in here; it owns buttons,
## not data.
##
## Every function takes the preset dictionary and mutates it in place, because
## that is what the workspace already does with `active_preset_dict`, and
## returning copies would silently drop edits.

## A brand new layer, with the fields the engine actually reads. Deliberately
## audible: a silent default layer looks like a broken editor.
const NUEVA_CAPA := {
	"name": "Layer",
	"generator_type": "Basic_Wave",
	"wave_type": "Sine",
	"base_freq": 440.0,
	"gain_db": -6.0,
	"start_offset": 0.0,
	"envelope": {"attack": 0.005, "decay": 0.12, "sustain": 0.0, "release": 0.05},
}


## Is this preset a layered container?
static func is_container(preset: Dictionary) -> bool:
	return str(preset.get("type", "Single_Generator")) == "Layer_Container"


## The layers array, always an Array — never null, so callers need no guard.
static func layers(preset: Dictionary) -> Array:
	var l = preset.get("layers", [])
	return l if l is Array else []


static func count(preset: Dictionary) -> int:
	return layers(preset).size()


## Is `idx` a real layer of this preset?
static func valid(preset: Dictionary, idx: int) -> bool:
	return idx >= 0 and idx < count(preset)


## The layer at `idx`, or an empty dictionary.
##
## Returns the LIVE dictionary, not a copy: the editor writes through it. A copy
## here would make every knob a no-op, which is the bug this whole module exists
## to fix.
static func at(preset: Dictionary, idx: int) -> Dictionary:
	if not valid(preset, idx):
		return {}
	var l = layers(preset)[idx]
	return l if l is Dictionary else {}


## Appends a layer and returns its index.
static func add(preset: Dictionary, capa: Dictionary = {}) -> int:
	if not preset.has("layers") or not (preset["layers"] is Array):
		preset["layers"] = []
	var nueva: Dictionary = NUEVA_CAPA.duplicate(true) if capa.is_empty() else capa.duplicate(true)
	if capa.is_empty():
		nueva["name"] = "Layer %d" % (preset["layers"].size() + 1)
	preset["layers"].append(nueva)
	return preset["layers"].size() - 1


## Removes the layer at `idx`. Returns the index that should be selected after,
## clamped into range, or -1 when nothing is left.
static func remove(preset: Dictionary, idx: int) -> int:
	if not valid(preset, idx):
		return clampi(idx, -1, count(preset) - 1)
	preset["layers"].remove_at(idx)
	var n := count(preset)
	if n == 0:
		return -1
	return clampi(idx, 0, n - 1)


## Duplicates the layer at `idx` right after it. Returns the new index.
##
## The copy is deep: a shallow one would share the `envelope` and `filter`
## sub-dictionaries, so editing the copy would silently edit the original too.
static func duplicate_at(preset: Dictionary, idx: int) -> int:
	if not valid(preset, idx):
		return idx
	var copia: Dictionary = at(preset, idx).duplicate(true)
	copia["name"] = str(copia.get("name", "Layer")) + " copy"
	preset["layers"].insert(idx + 1, copia)
	return idx + 1


## Moves a layer by `delta` positions. Returns its new index.
##
## Order is cosmetic for the engine — layers are summed, and addition commutes —
## but it is how a person reads the preset, so it is worth getting right.
static func move(preset: Dictionary, idx: int, delta: int) -> int:
	if not valid(preset, idx) or delta == 0:
		return idx
	var destino := clampi(idx + delta, 0, count(preset) - 1)
	if destino == idx:
		return idx
	var capa = preset["layers"][idx]
	preset["layers"].remove_at(idx)
	preset["layers"].insert(destino, capa)
	return destino


## Turns a Single_Generator into a Layer_Container, carrying its settings into
## the first layer instead of throwing them away.
##
## Without this, switching type in the workspace silently discarded the sound
## you had built and left an empty container.
static func to_container(preset: Dictionary) -> void:
	if is_container(preset):
		return
	var capa := {}
	for k in preset.keys():
		# These belong to the container, not to a layer.
		if k in ["type", "layers", "duration", "loop_mode", "sample_rate", "pan", "fx", "category"]:
			continue
		capa[k] = preset[k]
	for k in capa.keys():
		preset.erase(k)
	capa["name"] = "Layer 1"
	preset["type"] = "Layer_Container"
	preset["layers"] = [capa] if not capa.is_empty() else []


## Which dictionary the generator, envelope, filter and LFO controls should read
## from and write to.
##
## THE bug this module fixes: the workspace read and wrote those fields on the
## preset root always. On a Layer_Container the root holds none of them, so
## every knob showed its default and every turn wrote a field that
## `synthesize_wav` never reads. Sound unchanged, knobs lying, dead keys left
## behind in the JSON.
static func target(preset: Dictionary, idx: int) -> Dictionary:
	if not is_container(preset):
		return preset
	return at(preset, idx)


## Layer-level keys sitting on a container root, where nothing reads them.
##
## They are the fossils of the bug above. Reported rather than deleted on sight:
## they may hold values someone meant to dial in, and the person should choose.
static func stray_root_keys(preset: Dictionary) -> Array:
	if not is_container(preset):
		return []
	var sueltas: Array = []
	for k in ["generator_type", "base_freq", "base_freq_var", "wave_type", "envelope",
			"filter", "lfo", "noise_type", "pitch_envelope", "start_offset"]:
		if preset.has(k):
			sueltas.append(k)
	sueltas.sort()
	return sueltas
