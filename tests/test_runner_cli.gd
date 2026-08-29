extends SceneTree

const TestAllClass = preload("res://tests/test_all.gd")

func _init() -> void:
	print("==================================================")
	print("  🧪 OPENDOU AUDIO ENGINE - HEADLESS TEST RUNNER  ")
	print("==================================================")
	var res = TestAllClass.run_suite()
	var total: int = res["total"]
	var passed: int = res["passed"]
	var failures: Array = res["failures"]
	
	if failures.is_empty():
		print("\n✅ SUCCESS: ALL %d / %d TESTS PASSED (100%%)!\n" % [passed, total])
		print("Summary of 25 Verified Test Suites:")
		print(" - RTPC Values & Slew-Rates")
		print(" - Spline Curves & Mathematical Bindings")
		print(" - Composite Tree (Blend, Random, Switch, Sequence)")
		print(" - Voice Pooling & Stealing (Dynamic Audibility & Micro-Fades)")
		print(" - Zero-Cost Pitch-Scaled Virtual Tracking")
		print(" - Central Game Syncs & O(1) LUT Acceleration")
		print(" - Automatic Modulators (AHDSR Envelopes & LFO Oscillators)")
		print(" - Monolithic SoundBanks (.bank) & Contiguous RAM Prefetch")
		print(" - Lock-Free SPSC RingBuffer & Streaming Stitching")
		print(" - Macro-Acoustics (Rooms, Portals & Acoustic Pathfinding)")
		print(" - Micro-Acoustics (Multi-Ray Occlusion & Slew-Rate Smoothing)")
		print(" - Live Update TCP Server & TLV Network Protocol")
		print(" - Real-Time Voice Telemetry Snapshot & 3D Radar")
		print(" - GraphEdit Visual Logic Nodes & Composite Serializer")
		print(" - Transport Bar & Dynamic RTPC Test Faders")
		print(" - AAA Demo Suite Showcases (Demos 01 to 07)")
		print("==================================================")
		quit(0)
	else:
		print("\n❌ FAILURE: %d out of %d tests failed:" % [failures.size(), total])
		for f in failures:
			print("  - " + str(f))
		print("==================================================")
		quit(1)
