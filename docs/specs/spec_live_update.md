# Technical Specification: Live Update & Profiler (TCP Server & TLV Protocol) (OpenDou Core)

**Module:** `addons/opendou/runtime/network/`
**Status:** Approved / In Progress
**Reference Document:** [docs/ideas/012.md](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/ideas/012.md)

---

## 1. Objective & Scope

The **Live Update & Profiler** subsystem enables live iteration and performance monitoring by connecting an external authoring tool or editor to the running game via TCP:
1. **TLV Binary Network Protocol:** Type-Length-Value packet layout with 8-byte standard headers.
2. **Hot Reloading in RAM:** In-memory modification of `AudioEventDef` volumes, RTPC curves, states, and event triggers without restarting the game.
3. **Real-time Telemetry:** Streaming performance metrics (physical voices, virtual voices, memory usage) to the profiler.

---

## 2. Protocol Specification (TLV Format)

```text
+-------------------------------------------------------------+
| MAGIC (2 bytes) | MSG_TYPE (2 bytes) | PAYLOAD_LEN (4 bytes) |
|      'OD'       |       uint16       |        uint32        |
+-------------------------------------------------------------+
| PAYLOAD (Variable length based on PAYLOAD_LEN)              |
+-------------------------------------------------------------+
```

### Message Types
* `0`: `MSG_HANDSHAKE` (Version check and client identification)
* `1`: `MSG_UPDATE_VOLUME` (Event Name + Volume dB)
* `2`: `MSG_UPDATE_RTPC_CURVE` (Event Name + Parameter Name + Curve Points)
* `3`: `MSG_TRIGGER_EVENT` (Event Name to post)
* `4`: `MSG_SET_RTPC` (RTPC Name + Value)
* `5`: `MSG_SET_STATE` (Group Name + State Name + Transition Sec)
* `6`: `MSG_TELEMETRY` (Physical Voices, Virtual Voices, Active Instances)

---

## 3. Acceptance Criteria (DoD)

1. Binary TLV encoder and decoder serialize/deserialize all message types without corruption.
2. `LiveUpdateServer` dispatches volume, curve, state, and event commands in real-time.
3. Telemetry packet generator outputs accurate runtime profiling data.
4. 100% automated test coverage in `tests/test_live_update.gd`.
