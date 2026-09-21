class_name TestLayerOps
extends RefCounted

## Tests for the pure layer operations behind the Synth Rack layer editor.
##
## The bug these exist for: the workspace read and wrote generator, envelope,
## filter and LFO settings on the preset ROOT for every preset. On a
## Layer_Container the root holds none of them, so every knob showed its default
## and every turn wrote a key `synthesize_wav` never reads.

const LayerOpsClass = preload("res://addons/opendou/runtime/synth/layer_ops.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []

	if LayerOpsClass == null:
		failures.append("Test 1 Failed: layer_ops.gd failed to load")
		return failures

	# Test 2: target() is the whole point — root for a single generator, the
	# selected layer for a container.
	var single = {"generator_type": "Basic_Wave", "base_freq": 330.0}
	var t_single = LayerOpsClass.target(single, 0)
	if float(t_single.get("base_freq", 0.0)) != 330.0:
		failures.append("Test 2 Failed: a Single_Generator must target its own root")

	var container = {
		"type": "Layer_Container",
		"duration": 0.3,
		"layers": [
			{"name": "a", "base_freq": 110.0},
			{"name": "b", "base_freq": 880.0},
		],
	}
	if float(LayerOpsClass.target(container, 0).get("base_freq", 0.0)) != 110.0:
		failures.append("Test 2 Failed: layer 0 not targeted")
	if float(LayerOpsClass.target(container, 1).get("base_freq", 0.0)) != 880.0:
		failures.append("Test 2 Failed: layer 1 not targeted")
	# The root of a container must NOT answer for layer fields — that is exactly
	# the defect. Reading it should find nothing.
	if container.has("base_freq"):
		failures.append("Test 2 Failed: container root should hold no layer fields")

	# Test 3: target() returns the LIVE layer, not a copy
	# A copy would make every knob a silent no-op, which is worse than the bug.
	var live = LayerOpsClass.target(container, 0)
	live["base_freq"] = 220.0
	if float(container["layers"][0]["base_freq"]) != 220.0:
		failures.append("Test 3 Failed: target() returned a copy, edits are lost")

	# Test 4: out-of-range indices never crash and never invent a layer
	if not LayerOpsClass.target(container, 99).is_empty():
		failures.append("Test 4 Failed: an out-of-range index must return empty")
	if not LayerOpsClass.target(container, -1).is_empty():
		failures.append("Test 4 Failed: a negative index must return empty")
	if LayerOpsClass.count(container) != 2:
		failures.append("Test 4 Failed: probing bad indices changed the layer count")

	# Test 5: add / remove, and what stays selected afterwards
	var editable = {"type": "Layer_Container", "layers": []}
	var i0 = LayerOpsClass.add(editable)
	var i1 = LayerOpsClass.add(editable)
	if i0 != 0 or i1 != 1 or LayerOpsClass.count(editable) != 2:
		failures.append("Test 5 Failed: add returned %d and %d for %d layers" % [i0, i1, LayerOpsClass.count(editable)])
	# A fresh layer must be audible: a silent default looks like a broken editor.
	if float(LayerOpsClass.at(editable, 0).get("base_freq", 0.0)) <= 0.0:
		failures.append("Test 5 Failed: a new layer has no frequency")
	var sel = LayerOpsClass.remove(editable, 1)
	if LayerOpsClass.count(editable) != 1 or sel != 0:
		failures.append("Test 5 Failed: after removing the last layer, selection should fall back to 0 (got %d)" % sel)
	sel = LayerOpsClass.remove(editable, 0)
	if LayerOpsClass.count(editable) != 0 or sel != -1:
		failures.append("Test 5 Failed: emptying the list should report -1 (got %d)" % sel)

	# Test 6: duplicate is DEEP
	# A shallow copy would share the envelope sub-dictionary, so editing the copy
	# would silently edit the original — the kind of bug found days later.
	var dup_preset = {
		"type": "Layer_Container",
		"layers": [{"name": "orig", "envelope": {"attack": 0.01, "decay": 0.2}}],
	}
	var d_idx = LayerOpsClass.duplicate_at(dup_preset, 0)
	if d_idx != 1 or LayerOpsClass.count(dup_preset) != 2:
		failures.append("Test 6 Failed: duplicate should insert right after the original")
	else:
		LayerOpsClass.at(dup_preset, 1)["envelope"]["attack"] = 0.99
		if float(LayerOpsClass.at(dup_preset, 0)["envelope"]["attack"]) != 0.01:
			failures.append("Test 6 Failed: duplicate is shallow, the copy shares the original's envelope")

	# Test 7: move, and clamping at the ends
	var mv = {
		"type": "Layer_Container",
		"layers": [{"name": "a"}, {"name": "b"}, {"name": "c"}],
	}
	if LayerOpsClass.move(mv, 0, 1) != 1:
		failures.append("Test 7 Failed: move down returned the wrong index")
	if str(LayerOpsClass.at(mv, 0).get("name", "")) != "b":
		failures.append("Test 7 Failed: move did not reorder")
	if LayerOpsClass.move(mv, 0, -5) != 0:
		failures.append("Test 7 Failed: moving past the top should clamp, not wrap")
	if LayerOpsClass.move(mv, 2, 9) != 2:
		failures.append("Test 7 Failed: moving past the end should clamp, not wrap")
	if LayerOpsClass.count(mv) != 3:
		failures.append("Test 7 Failed: moving changed the layer count")

	# Test 8: converting to a container carries the sound over
	# Switching type used to discard everything and leave an empty container.
	var conv = {
		"generator_type": "Filtered_Noise", "noise_type": "Pink",
		"base_freq": 200.0, "duration": 0.4, "loop_mode": true,
		"filter": {"type": "LowPass", "cutoff_hz": 900.0},
	}
	LayerOpsClass.to_container(conv)
	if not LayerOpsClass.is_container(conv):
		failures.append("Test 8 Failed: to_container did not set the type")
	elif LayerOpsClass.count(conv) != 1:
		failures.append("Test 8 Failed: to_container should produce exactly one layer")
	else:
		var moved = LayerOpsClass.at(conv, 0)
		if str(moved.get("generator_type", "")) != "Filtered_Noise":
			failures.append("Test 8 Failed: the generator was lost in conversion")
		if float(moved.get("filter", {}).get("cutoff_hz", 0.0)) != 900.0:
			failures.append("Test 8 Failed: the filter was lost in conversion")
		# Container-level settings stay on the container.
		if float(conv.get("duration", 0.0)) != 0.4:
			failures.append("Test 8 Failed: duration should stay on the container")
		if not bool(conv.get("loop_mode", false)):
			failures.append("Test 8 Failed: loop_mode should stay on the container")
		# And the layer fields must be GONE from the root, or the old bug is back.
		if conv.has("generator_type") or conv.has("filter"):
			failures.append("Test 8 Failed: layer fields left behind on the container root")
	# Converting twice must not wrap a container inside itself.
	LayerOpsClass.to_container(conv)
	if LayerOpsClass.count(conv) != 1:
		failures.append("Test 8 Failed: converting an existing container changed it")

	# Test 9: stray root keys are reported
	# 23 of the shipped containers carry these fossils: keys the old editor wrote
	# to the root, that synthesize_wav never reads.
	var fossil = {
		"type": "Layer_Container",
		"base_freq": 440.0,
		"filter": {"type": "LowPass"},
		"layers": [{"name": "a"}],
	}
	var strays = LayerOpsClass.stray_root_keys(fossil)
	if not (strays.has("base_freq") and strays.has("filter")):
		failures.append("Test 9 Failed: stray root keys not reported (got %s)" % str(strays))
	if not LayerOpsClass.stray_root_keys({"generator_type": "Basic_Wave"}).is_empty():
		failures.append("Test 9 Failed: a Single_Generator has no stray keys by definition")

	return failures
