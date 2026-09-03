#include "send_bus.h"

#include <godot_cpp/core/class_db.hpp>
#include <algorithm>

using namespace godot;

namespace opendou {

OpenDouSendBus::Send OpenDouSendBus::sends_[OpenDouSendBus::MAX_SENDS];

void OpenDouSendBus::_bind_methods() {
	ClassDB::bind_static_method("OpenDouSendBus", D_METHOD("create"), &OpenDouSendBus::create);
	ClassDB::bind_static_method("OpenDouSendBus", D_METHOD("release", "id"), &OpenDouSendBus::release);
	ClassDB::bind_static_method("OpenDouSendBus", D_METHOD("count"), &OpenDouSendBus::count);
	ClassDB::bind_static_method("OpenDouSendBus", D_METHOD("stats", "id"), &OpenDouSendBus::stats);
}

int OpenDouSendBus::create() {
	for (int i = 0; i < MAX_SENDS; i++) {
		if (!sends_[i].used.load()) {
			std::lock_guard<std::mutex> lk(sends_[i].mutex);
			sends_[i].ring.assign(RING, 0.0f);
			sends_[i].head = 0;
			sends_[i].avail = 0;
			sends_[i].accum_calls = sends_[i].accum_frames = sends_[i].drain_calls = sends_[i].drain_frames = 0;
			sends_[i].max_avail = 0;
			sends_[i].used.store(true);
			return i;
		}
	}
	return -1;
}

void OpenDouSendBus::release(int id) {
	if (id < 0 || id >= MAX_SENDS) {
		return;
	}
	sends_[id].used.store(false);
}

int OpenDouSendBus::count() {
	int n = 0;
	for (int i = 0; i < MAX_SENDS; i++) {
		if (sends_[i].used.load()) {
			n++;
		}
	}
	return n;
}

// Varios streams suman sobre la misma region [head, head + n) dentro de un paso; el efecto
// drena n y avanza. Todo ocurre en el hilo de audio, en orden: el mutex solo protege de
// create/release desde el hilo principal.
void OpenDouSendBus::accumulate(int id, const float *mono, int n, float gain) {
	if (id < 0 || id >= MAX_SENDS || !sends_[id].used.load() || n <= 0) {
		return;
	}
	Send &s = sends_[id];
	std::lock_guard<std::mutex> lk(s.mutex);
	if (s.ring.empty()) {
		return;
	}
	const size_t cap = s.ring.size();
	const int m = std::min(n, static_cast<int>(cap));
	for (int i = 0; i < m; i++) {
		s.ring[(s.head + static_cast<size_t>(i)) % cap] += mono[i] * gain;
	}
	s.avail = std::max(s.avail, static_cast<size_t>(m));
	s.max_avail = std::max(s.max_avail, s.avail);
	s.accum_calls++;
	s.accum_frames += m;
}

void OpenDouSendBus::drain(int id, float *out, int n) {
	for (int i = 0; i < n; i++) {
		out[i] = 0.0f;
	}
	if (id < 0 || id >= MAX_SENDS || !sends_[id].used.load() || n <= 0) {
		return;
	}
	Send &s = sends_[id];
	std::lock_guard<std::mutex> lk(s.mutex);
	if (s.ring.empty()) {
		return;
	}
	const size_t cap = s.ring.size();
	for (int i = 0; i < n; i++) {
		const size_t k = (s.head + static_cast<size_t>(i)) % cap;
		if (static_cast<size_t>(i) < s.avail) {
			out[i] = s.ring[k];
		}
		s.ring[k] = 0.0f;
	}
	s.head = (s.head + static_cast<size_t>(n)) % cap;
	s.avail = s.avail > static_cast<size_t>(n) ? s.avail - static_cast<size_t>(n) : 0;
	s.drain_calls++;
	s.drain_frames += n;
}

Dictionary OpenDouSendBus::stats(int id) {
	Dictionary d;
	if (id < 0 || id >= MAX_SENDS) {
		return d;
	}
	Send &s = sends_[id];
	std::lock_guard<std::mutex> lk(s.mutex);
	d["used"] = s.used.load();
	d["accum_calls"] = static_cast<int64_t>(s.accum_calls);
	d["accum_frames"] = static_cast<int64_t>(s.accum_frames);
	d["drain_calls"] = static_cast<int64_t>(s.drain_calls);
	d["drain_frames"] = static_cast<int64_t>(s.drain_frames);
	d["max_avail"] = static_cast<int64_t>(s.max_avail);
	d["avail"] = static_cast<int64_t>(s.avail);
	return d;
}

} // namespace opendou
