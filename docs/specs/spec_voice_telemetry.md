# Technical Specification: Real-Time Voice Telemetry & 3D Audio Profiler (OpenDou Core)

**Module:** `addons/opendou/runtime/network/`
**Status:** Approved / In Progress
**Reference Document:** [docs/ideas/013.md](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/ideas/013.md)

---

## 1. Objective & Scope

The **Real-Time Voice Telemetry & Profiler** broadcasts deep runtime metrics from the engine to connected editor tools at 30 FPS:
1. **Global Snapshot:** Active physical channels, virtual instances, estimated DSP/mix time, and SoundBank RAM utilization.
2. **Individual Voice Telemetry:** Position $(x, y, z)$, loudness (dB), virtualization state, and dynamic weight per active emitter for 3D radar rendering.
3. **Compact Binary Serialization:** High-efficiency binary streaming with zero memory allocations in the audio thread.

---

## 2. Telemetry Binary Layout

```text
+-------------------------------------------------------------------------------+
| HEADER (8 bytes): Magic ('OD'), Type (6 = MSG_TELEMETRY), PayloadLength      |
+-------------------------------------------------------------------------------+
| GLOBAL SNAPSHOT (20 bytes):                                                   |
| - physical_voices (uint32)                                                    |
| - virtual_voices (uint32)                                                     |
| - total_dsp_cpu_time_ms (float32)                                             |
| - prefetch_ram_kb (uint32)                                                    |
| - num_voices (uint32)                                                         |
+-------------------------------------------------------------------------------+
| VOICE RECORDS (Array of VoiceTelemetryData, 25 bytes each):                   |
| - event_id / name_hash (uint32)                                               |
| - volume_db (float32)                                                         |
| - pos_x, pos_y, pos_z (float32 x 3 = 12 bytes)                                |
| - is_virtual (uint8)                                                          |
| - dynamic_weight (float32)                                                    |
+-------------------------------------------------------------------------------+
```

---

## 3. Acceptance Criteria (DoD)

1. Telemetry collector extracts active voice transforms, dB levels, and states accurately.
2. Binary encoder/decoder handles variable voice counts with exact binary fidelity.
3. 100% automated test coverage in `tests/test_voice_telemetry.gd`.
