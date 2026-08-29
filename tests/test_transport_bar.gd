class_name TestTransportBar
extends RefCounted

const OpenDouTransportBarClass = preload("res://addons/opendou/editor/opendou_transport_bar.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	var bar = OpenDouTransportBarClass.new()
	
	# Test 1: Event Name Assignment
	bar.set_target_event(&"Rifle_Shot_Impact")
	if not bar.target_event_label.text.contains("Rifle_Shot_Impact"):
		failures.append("Test 1 Failed: Target event label text mismatch")
		
	# Test 2: Transport Play / Stop state
	var flags = {"played": false, "stopped": false}
	bar.play_requested.connect(func(): flags["played"] = true)
	bar.stop_requested.connect(func(): flags["stopped"] = true)
	
	bar._on_play_pressed()
	if not flags["played"] or not bar.is_playing:
		failures.append("Test 2a Failed: Play button state/signal failed")
		
	bar._on_stop_pressed()
	if not flags["stopped"] or bar.is_playing:
		failures.append("Test 2b Failed: Stop button state/signal failed")
		
	# Test 3: Adding Dynamic RTPC Fader
	bar.add_rtpc_fader(&"RPM", 0.0, 8000.0, 1000.0)
	
	if bar.rtpc_faders_container.get_child_count() != 1:
		failures.append("Test 3 Failed: Dynamic RTPC fader container count mismatch")
		
	return failures
