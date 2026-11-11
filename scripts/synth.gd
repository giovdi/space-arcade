class_name Synth
extends RefCounted
## Genera note musicali da zero (nessun file audio necessario).

static var cache := {}


const TIMBRES := 8  # voci diverse: ogni mostro ha la sua (specie % 8) oltre alla sua nota


## timbre 0..7: ogni voce ha un carattere diverso, così i mostri si riconoscono anche a orecchio.
static func note(freq: float, dur := 0.6, timbre := 0) -> AudioStreamWAV:
	timbre = posmod(timbre, TIMBRES)
	var key := "%d_%d_%d" % [int(freq * 10.0), int(dur * 100.0), timbre]
	if cache.has(key):
		return cache[key]
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0  # fase accumulata (serve per vibrato e glissando)
	for i in n:
		var t := float(i) / rate
		var attack := minf(t * 80.0, 1.0)
		var env := exp(-t * 5.0) * attack
		var f := freq
		var s := 0.0
		match timbre:
			0:  # morbido, con armoniche
				ph += TAU * f / rate
				s = (sin(ph) + 0.4 * sin(ph * 2.0) + 0.2 * sin(ph * 3.0)) * 0.4
			1:  # flauto: seno puro con piccolo vibrato
				f = freq * (1.0 + 0.012 * sin(TAU * 5.5 * t))
				ph += TAU * f / rate
				s = sin(ph) * 0.5
				env = exp(-t * 2.5) * attack
			2:  # ronzio: onda quadra
				ph += TAU * f / rate
				s = (sin(ph) + sin(ph * 3.0) / 3.0 + sin(ph * 5.0) / 5.0 + sin(ph * 7.0) / 7.0) * 0.32
			3:  # pizzico: decade in fretta
				ph += TAU * f / rate
				s = (sin(ph) + 0.6 * sin(ph * 2.0) + 0.4 * sin(ph * 3.0) + 0.25 * sin(ph * 4.0)) * 0.3
				env = exp(-t * 11.0) * attack
			4:  # campanella: parziali non armonici
				ph += TAU * f / rate
				s = (sin(ph) + 0.5 * sin(ph * 2.76) + 0.3 * sin(ph * 5.4)) * 0.35
				env = exp(-t * 3.5) * attack
			5:  # tremolo: la voce ondeggia
				ph += TAU * f / rate
				s = (sin(ph) + 0.3 * sin(ph * 2.0)) * 0.45 * (0.65 + 0.35 * sin(TAU * 9.0 * t))
				env = exp(-t * 2.8) * attack
			6:  # sega: tante armoniche, suono aspro
				ph += TAU * f / rate
				for k in range(1, 7):
					s += sin(ph * k) / k
				s *= 0.3
			_:  # boing: parte più alto e scende
				f = freq * (1.0 + 0.6 * exp(-t * 14.0))
				ph += TAU * f / rate
				s = (sin(ph) + 0.35 * sin(ph * 2.0)) * 0.42
		s *= env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	cache[key] = w
	return w
