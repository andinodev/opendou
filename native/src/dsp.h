// DSP de la extension: biquads RBJ, linea de retardo fraccionaria y el modelo de cabeza
// esferica de Woodworth. Sin dependencias de Godot ni de Steam Audio: se puede leer y
// probar solo.
#pragma once

#include <algorithm>
#include <cmath>
#include <vector>

namespace opendou::dsp {

constexpr float kPi = 3.14159265358979323846f;

// Biquad en forma directa II transpuesta, coeficientes del "Audio EQ Cookbook" de RBJ.
struct Biquad {
	float b0 = 1.0f, b1 = 0.0f, b2 = 0.0f, a1 = 0.0f, a2 = 0.0f;
	float z1 = 0.0f, z2 = 0.0f;

	void reset() { z1 = z2 = 0.0f; }

	void set_identity() {
		b0 = 1.0f;
		b1 = b2 = a1 = a2 = 0.0f;
	}

	// Paso-bajo de 2.o orden. q = 0.7071 es Butterworth.
	void set_lowpass(float fs, float fc, float q) {
		fc = std::clamp(fc, 10.0f, fs * 0.45f);
		const float w0 = 2.0f * kPi * fc / fs;
		const float cw = std::cos(w0), sw = std::sin(w0);
		const float alpha = sw / (2.0f * q);
		const float a0 = 1.0f + alpha;
		b0 = ((1.0f - cw) * 0.5f) / a0;
		b1 = (1.0f - cw) / a0;
		b2 = b0;
		a1 = (-2.0f * cw) / a0;
		a2 = (1.0f - alpha) / a0;
	}

	// High-shelf: ganancia gain_db por encima de fc, 0 dB por debajo. Es el filtro que
	// Godot aplica por distancia (set_playback_highshelf_params).
	void set_highshelf(float fs, float fc, float gain_db) {
		fc = std::clamp(fc, 10.0f, fs * 0.45f);
		const float A = std::pow(10.0f, gain_db / 40.0f);
		const float w0 = 2.0f * kPi * fc / fs;
		const float cw = std::cos(w0), sw = std::sin(w0);
		const float alpha = sw / 2.0f * std::sqrt(2.0f); // S = 1
		const float sqA2a = 2.0f * std::sqrt(A) * alpha;
		const float a0 = (A + 1.0f) - (A - 1.0f) * cw + sqA2a;
		b0 = (A * ((A + 1.0f) + (A - 1.0f) * cw + sqA2a)) / a0;
		b1 = (-2.0f * A * ((A - 1.0f) + (A + 1.0f) * cw)) / a0;
		b2 = (A * ((A + 1.0f) + (A - 1.0f) * cw - sqA2a)) / a0;
		a1 = (2.0f * ((A - 1.0f) - (A + 1.0f) * cw)) / a0;
		a2 = ((A + 1.0f) - (A - 1.0f) * cw - sqA2a) / a0;
	}

	inline float process(float x) {
		const float y = b0 * x + z1;
		z1 = b1 * x - a1 * y + z2;
		z2 = b2 * x - a2 * y;
		return y;
	}
};

// Linea de retardo fraccionaria con interpolacion lineal. El retardo objetivo se fija por
// bloque y el actual se acerca en rampa muestra a muestra: girar la cabeza no hace clic.
struct FractionalDelay {
	std::vector<float> buf;
	size_t write = 0;
	float current = 0.0f;
	float target = 0.0f;
	float step = 0.0f;

	void init(int max_samples) {
		buf.assign(static_cast<size_t>(std::max(max_samples, 4)) + 4, 0.0f);
		reset();
	}
	void reset() {
		std::fill(buf.begin(), buf.end(), 0.0f);
		write = 0;
		current = target = step = 0.0f;
	}
	// Retardo en muestras a alcanzar al final de un bloque de block_samples.
	void set_target(float samples, int block_samples) {
		const float max_delay = static_cast<float>(buf.size()) - 3.0f;
		target = std::clamp(samples, 0.0f, max_delay);
		step = (target - current) / static_cast<float>(std::max(block_samples, 1));
	}
	inline float process(float x) {
		buf[write] = x;
		current += step;
		if ((step > 0.0f && current > target) || (step < 0.0f && current < target)) {
			current = target;
		}
		const size_t n = buf.size();
		float rp = static_cast<float>(write) - current;
		while (rp < 0.0f) {
			rp += static_cast<float>(n);
		}
		const size_t i0 = static_cast<size_t>(rp) % n; // muestra mas reciente del par
		const size_t i1 = (i0 + n - 1) % n;             // la anterior en el tiempo
		const float frac = rp - std::floor(rp);
		// rp cae entre i1 (mas antigua) e i0 (mas reciente): frac = 0 lee i0.
		const float y = buf[i0] * (1.0f - frac) + buf[i1] * frac;
		write = (write + 1) % n;
		return y;
	}
};

// Woodworth: ITD de una cabeza esferica de radio r para una direccion unitaria en el
// espacio del oyente (+X derecha, +Y arriba, -Z delante). Devuelve segundos, siempre >= 0;
// el signo (que oido se retrasa) lo decide dir_x.
inline float woodworth_itd_seconds(float dir_x, float dir_y, float dir_z) {
	constexpr float r = 0.0875f;
	constexpr float c = 343.0f;
	float theta = std::fabs(std::atan2(dir_x, -dir_z)); // azimut en [0, pi]
	if (theta > kPi * 0.5f) {
		theta = kPi - theta; // detras se refleja a su espejo delantero
	}
	const float phi = std::asin(std::clamp(dir_y, -1.0f, 1.0f));
	return (r / c) * (theta + std::sin(theta)) * std::cos(phi);
}

// Paneo estereo de potencia constante a partir de dir_x en [-1, 1].
inline void constant_power_pan(float dir_x, float &gain_l, float &gain_r) {
	const float x = std::clamp(dir_x, -1.0f, 1.0f);
	const float angle = (x + 1.0f) * kPi * 0.25f; // 0 = todo izquierda, pi/2 = todo derecha
	gain_l = std::cos(angle);
	gain_r = std::sin(angle);
}

} // namespace opendou::dsp
