extends RefCounted
class_name AudioSynth

const SAMPLE_RATE = 44100


static func create_sfx_library() -> Dictionary:
	return {
		"menu": make_sweep_stream(520.0, 740.0, 0.08, "square", 0.35, 0.03),
		"pause": make_sweep_stream(300.0, 200.0, 0.1, "triangle", 0.4, 0.02),
		"launch": make_sweep_stream(180.0, 520.0, 0.16, "square", 0.45, 0.04),
		"paddle": make_sweep_stream(260.0, 180.0, 0.06, "square", 0.26, 0.02),
		"brick_hit": make_sweep_stream(720.0, 420.0, 0.06, "square", 0.28, 0.06),
		"brick_break": make_sweep_stream(1120.0, 180.0, 0.14, "square", 0.55, 0.14),
		"explosion": make_sweep_stream(220.0, 55.0, 0.34, "noise", 0.82, 0.45),
		"pickup_good": make_sweep_stream(560.0, 1220.0, 0.22, "triangle", 0.46, 0.02),
		"pickup_bad": make_sweep_stream(240.0, 110.0, 0.18, "saw", 0.36, 0.06),
		"laser": make_sweep_stream(1440.0, 920.0, 0.09, "square", 0.42, 0.02),
		"level_clear": make_jingle_stream([72, 76, 79, 84], 0.12, "triangle", 0.34),
		"game_over": make_jingle_stream([72, 68, 63, 56], 0.18, "saw", 0.3)
	}


static func create_music_stream() -> AudioStreamWAV:
	var bpm = 142.0
	var step_duration = 60.0 / bpm / 2.0
	var total_steps = 64
	var total_seconds = step_duration * total_steps
	var sample_count = int(total_seconds * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(sample_count * 2)

	var lead = [79, 81, 84, 88, 84, 81, 79, 76, 79, 81, 84, 91, 88, 84, 81, 79]
	var counter = [91, 88, 86, 84, 83, 84, 86, 88]
	var bass = [36, 36, 43, 43, 41, 41, 43, 43]
	var chords = [
		[60, 64, 67],
		[62, 65, 69],
		[64, 67, 71],
		[65, 69, 72]
	]

	for i in range(sample_count):
		var t = float(i) / SAMPLE_RATE
		var step = int(floor(t / step_duration))
		var half_beat_time = fmod(t, step_duration)
		var beat = int(floor(t / (step_duration * 2.0)))
		var beat_time = fmod(t, step_duration * 2.0)
		var bar = int(floor(t / (step_duration * 8.0)))
		var bar_time = fmod(t, step_duration * 8.0)

		var sample = 0.0
		var lead_note = lead[step % lead.size()]
		var counter_note = counter[(step + 4) % counter.size()]
		var bass_note = bass[beat % bass.size()]
		var chord = chords[bar % chords.size()]
		var arp_note = chord[step % chord.size()]

		sample += voice_note(half_beat_time, step_duration * 0.9, midi_to_hz(lead_note), 0.24, "square", 0.01)
		sample += voice_note(half_beat_time, step_duration * 0.78, midi_to_hz(counter_note), 0.1, "triangle", 0.025)
		sample += voice_note(half_beat_time, step_duration * 0.7, midi_to_hz(arp_note + 12), 0.07, "square", 0.0)
		sample += voice_note(beat_time, step_duration * 1.95, midi_to_hz(bass_note), 0.22, "saw", 0.0)
		for note in chord:
			sample += voice_note(bar_time, step_duration * 7.2, midi_to_hz(note), 0.028, "sine", 0.0)

		if half_beat_time < 0.1:
			sample += drum_kick(half_beat_time, 0.11, 0.42)
		if step % 4 == 2 and half_beat_time < 0.09:
			sample += drum_noise(half_beat_time, 0.11, 0.18)

		data.encode_s16(i * 2, int(clamp(sample, -1.0, 1.0) * 32767.0))

	var stream = AudioStreamWAV.new()
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream


static func make_sweep_stream(freq_start: float, freq_end: float, duration: float, wave: String, volume: float, noise: float) -> AudioStreamWAV:
	var sample_count = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(sample_count * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = int(freq_start * 17.0 + freq_end * 29.0 + duration * 997.0)
	var phase = 0.0

	for i in range(sample_count):
		var t = float(i) / SAMPLE_RATE
		var mix = t / max(duration, 0.001)
		var freq = lerp(freq_start, freq_end, mix)
		phase += TAU * freq / SAMPLE_RATE
		var env = min(t / 0.01, 1.0) * pow(max(0.0, 1.0 - mix), 1.6)
		var sample = wave_value(phase, wave) * env * volume
		sample += (rng.randf_range(-1.0, 1.0) * noise * env)
		data.encode_s16(i * 2, int(clamp(sample, -1.0, 1.0) * 32767.0))

	var stream = AudioStreamWAV.new()
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.data = data
	return stream


static func make_jingle_stream(notes: Array, note_length: float, wave: String, volume: float) -> AudioStreamWAV:
	var total_seconds = notes.size() * note_length
	var sample_count = int(total_seconds * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(sample_count * 2)

	for i in range(sample_count):
		var t = float(i) / SAMPLE_RATE
		var note_index = clamp(int(floor(t / note_length)), 0, notes.size() - 1)
		var local_time = fmod(t, note_length)
		var sample = voice_note(local_time, note_length * 0.95, midi_to_hz(notes[note_index]), volume, wave, 0.0)
		data.encode_s16(i * 2, int(clamp(sample, -1.0, 1.0) * 32767.0))

	var stream = AudioStreamWAV.new()
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.data = data
	return stream


static func voice_note(local_time: float, duration: float, frequency: float, volume: float, wave: String, vibrato_depth: float) -> float:
	if local_time >= duration:
		return 0.0
	var attack = min(local_time / 0.01, 1.0)
	var release = pow(max(0.0, 1.0 - local_time / max(duration, 0.001)), 1.8)
	var env = attack * release
	var vibrato = sin(local_time * TAU * 5.2) * vibrato_depth
	var phase = TAU * (frequency + frequency * vibrato) * local_time
	return wave_value(phase, wave) * env * volume


static func drum_kick(local_time: float, duration: float, volume: float) -> float:
	if local_time >= duration:
		return 0.0
	var env = pow(max(0.0, 1.0 - local_time / duration), 3.0)
	var phase = TAU * (120.0 - local_time * 620.0) * local_time
	return sin(phase) * env * volume


static func drum_noise(local_time: float, duration: float, volume: float) -> float:
	if local_time >= duration:
		return 0.0
	var env = pow(max(0.0, 1.0 - local_time / duration), 2.2)
	var noise = sin(local_time * 9120.0) * sin(local_time * 7160.0)
	return noise * env * volume


static func wave_value(phase: float, wave: String) -> float:
	var unit = fmod(phase / TAU, 1.0)
	match wave:
		"sine":
			return sin(phase)
		"triangle":
			return 1.0 - 4.0 * abs(unit - 0.5)
		"saw":
			return unit * 2.0 - 1.0
		"noise":
			return sin(phase * 1.37) * sin(phase * 0.73)
		_:
			return 1.0 if unit < 0.5 else -1.0


static func midi_to_hz(note: int) -> float:
	return 440.0 * pow(2.0, (float(note) - 69.0) / 12.0)
