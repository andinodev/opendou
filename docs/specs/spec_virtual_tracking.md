# Technical Specification: Zero-Cost Virtual Voice Tracking & Bus Routing (OpenDou Core)

**Module:** `addons/opendou/runtime/`, `addons/opendou/resources/`
**Status:** Approved / In Progress
**Reference Document:** [docs/ideas/005-seguimiento-virtual.md](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/ideas/005-seguimiento-virtual.md)

---

## 1. Objective & Scope

This module completes the low-level execution pipeline of the **Virtual Voice System**, implementing:
1. **Mathematical Head Tracking:** Pitch-scaled virtual time advancement and loop wrapping without audio decoding.
2. **Auto-Expiration of Non-Looping Virtual Voices:** Sounds that naturally finish while out of audibility range are cleanly stopped.
3. **Dynamic Bus Routing & Mercenary Channel Reconfiguration:** Physical channels dynamically switch streams, volumes, pitch, and `AudioServer` bus destinations.
4. **Artifact-Free Micro-Fades:** Zero-crossing fades (10–20ms) prevent acoustic pops during voice reallocation.

---

## 2. Mathematical Head Tracking Model

When an `EventInstance` is in `STATE_VIRTUAL`:

### 2.1. Pitch-Scaled Head Advancement
$$\Delta \text{pos} = \Delta t \times \text{calculated\_pitch\_scale}$$
$$\text{logical\_playback\_position} \leftarrow \text{logical\_playback\_position} + \Delta \text{pos}$$

### 2.2. Loop & Duration Handling
* **Looping Streams (`is_looping = true`):**
  $$\text{logical\_playback\_position} = \text{fmod}(\text{logical\_playback\_position}, \text{stream\_length})$$
* **Non-Looping Streams (`is_looping = false`):**
  $$\text{If } \text{stream\_length} > 0 \text{ and } \text{logical\_playback\_position} \ge \text{stream\_length} \implies \text{STATE\_STOPPED}$$

---

## 3. Reactivation Modes Comparison

| Mode | Behavior on Devirtualization | Ideal Use Cases |
|---|---|---|
| `VIRTUAL_KILL_VOICE` | Marked `STATE_KILLED` upon pool eviction. | Explosions, gunshots, impacts, debris. |
| `VIRTUAL_ELAPSED_TIME` | Seeks to `logical_playback_position`. | Ambient loops, rivers, dungeon machinery, background music. |
| `VIRTUAL_PLAY_FROM_START` | Plays from `0.0s`. | Generic ambient NPC barks, reload alerts. |
| `VIRTUAL_RESUME` | Pauses logical time while virtual, unpauses from saved position. | Narrative dialogues, collectible audio logs. |

---

## 4. Mercenary Physical Channel Reconfiguration

Physical voice channels are pre-allocated and agnostic to event types. When assigned:
1. Re-routes `target_bus` in Godot `AudioServer`.
2. Updates 2D/3D spatial transforms.
3. Applies calculated volume and pitch.
4. Initiates a 10ms micro-fade in to smooth the attack.

---

## 5. Acceptance Criteria (DoD)

1. Pitch-scaled virtual time advancement is accurate to within $\pm 0.001\text{s}$.
2. Non-looping virtual voices expire naturally when exceeding `stream_length`.
3. Looping virtual voices wrap modulo `stream_length` seamlessly.
4. Physical channels re-route to destination audio buses without memory leaks or clicks.
5. 100% automated test coverage in `tests/test_virtual_tracking.gd`.
