class_name Synth
extends RefCounted
## Genera note musicali da zero (nessun file audio necessario).

static var cache := {}


static func note(freq: float, dur := 0.6) -> AudioStreamWAV:
	var key := "%d_%d" % [int(freq * 10.0), int(dur * 100.0)]
	if cache.has(key):
		return cache[key]
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var env := exp(-t * 5.0) * minf(t * 80.0, 1.0)
		var s := (sin(TAU * freq * t) + 0.4 * sin(TAU * freq * 2.0 * t) + 0.2 * sin(TAU * freq * 3.0 * t)) * env * 0.4
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	cache[key] = w
	return w
