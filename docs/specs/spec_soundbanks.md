# Technical Specification: Monolithic SoundBanks (.bank) & Prefetch + Streaming Architecture (OpenDou Core)

**Module:** `addons/opendou/tools/`, `addons/opendou/runtime/`, `addons/opendou/resources/`
**Status:** Approved / In Progress
**Reference Documents:** 
* [docs/ideas/008.md](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/ideas/008.md)
* [docs/architecture/soundbanks-pipelines.md](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/architecture/soundbanks-pipelines.md)

---

## 1. Objective & Scope

In asset-dense games, loading all audio assets entirely into RAM exhausts mobile/desktop memory budgets, while loading audio files on-demand from disk introduces unacceptable input latency (*stuttering* and *file handle contention*).

The **Monolithic SoundBank Architecture** compiles audio files into single `.bank` files and bifurcates physical playback into two coordinated stages:
1. **Prefetch Stage (RAM):** The first $N$ kilobytes (e.g. 64 KB, ~350 ms) of each audio stream are pre-loaded in a single contiguous memory block during `load_bank()`, ensuring instant zero-latency playback start.
2. **Streaming Stage (Disk):** The remaining stream body is read asynchronously from disk in chunks from the monolithic file without reopening file handles.

---

## 2. Binary File Layout (`.bank` / `.sbk`)

```text
+-------------------------------------------------------------------------------+
| BLOCK 1: HEADER (24 bytes)                                                    |
| Magic ('ODBK'), Version (1), NumStreams, PrefetchBlockSize, StreamBlockOffset |
+-------------------------------------------------------------------------------+
| BLOCK 2: TABLE OF CONTENTS (TOC)                                              |
| Array of StreamMetadata (ID, Codec, Channels, SampleRate, Prefetch & Disk)   |
+-------------------------------------------------------------------------------+
| BLOCK 3: PREFETCH DATA (Contiguous RAM Buffer)                                |
| Sliced attack data for all streams in this bank (single malloc/buffer)        |
+-------------------------------------------------------------------------------+
| BLOCK 4: STREAMING DATA (On-Disk Body)                                        |
| Sequentially packed audio bodies for non-blocking disk reads                  |
+-------------------------------------------------------------------------------+
```

---

## 3. Data Structures

### 3.1. Header Definition
* `magic`: 4 bytes ASCII (`ODBK`)
* `version`: `uint32` (1)
* `num_streams`: `uint32`
* `prefetch_block_size`: `uint32` (Total RAM allocated for Block 3)
* `stream_block_offset`: `uint64` (Byte offset where Block 4 starts)

### 3.2. Stream Metadata Entry
* `stream_id`: `uint32` (Hash / unique identifier)
* `codec`: `uint16` (0 = PCM16, 1 = ADPCM, 2 = Vorbis/OGG)
* `channels`: `uint16` (1 = Mono, 2 = Stereo)
* `sample_rate`: `uint32` (44100 / 48000 Hz)
* `prefetch_offset`: `uint32` (Offset in Block 3)
* `prefetch_length`: `uint32` (Bytes in Block 3)
* `disk_offset`: `uint64` (Absolute byte offset in `.bank` file)
* `disk_length`: `uint64` (Remaining bytes in Block 4)

---

## 4. Acceptance Criteria (DoD)

1. **Deterministic Packing:** `SoundBankCompiler` packages multiple audio streams into aligned binary files.
2. **Zero-Fragmentation Loading:** `SoundBank.load_bank()` reads Header + TOC and loads Block 3 in a single contiguous read.
3. **Instant Attack:** `SoundBank.get_prefetch_slice(stream_id)` returns the exact prefetch bytes.
4. **Streaming Chunks:** `SoundBank.read_stream_chunk(stream_id, offset, length)` seeks and reads remaining stream bytes.
5. **100% Automated Test Coverage:** Complete test suite in `tests/test_soundbanks.gd`.
