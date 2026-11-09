extends Node
## Neon Drift audio: procedural synthwave music loop + synthesized SFX.
## Everything is generated in code at startup, no audio files.
## NOTE: the web build is single-threaded, so Thread is unavailable there.
## Music is generated synchronously in _ready using lookup tables to keep
## it fast (envelope table + sine table, no per-sample function calls).

const MIX_RATE := 22050
const BPM := 116.0
const BARS := 4
const BEAT_LEN := 60.0 / BPM
const BAR_LEN := BEAT_LEN * 4.0
const LOOP_LEN := BAR_LEN * BARS
const SINE_STEPS := 2048
const SINE_SCALE := 325.94932335706835 # SINE_STEPS / TAU

var music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
var music_ready: bool = false
var _sine_table: PackedFloat32Array
var _exp_table: PackedFloat32Array

var _chime_stream: AudioStreamWAV
var _whoosh_stream: AudioStreamWAV
var _thud_stream: AudioStreamWAV

func _ready() -> void:
	_build_tables()
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -9.0
	add_child(music_player)
	for i in 5:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	_generate_sfx()
	_generate_music()

func _build_tables() -> void:
	_sine_table = PackedFloat32Array()
	_sine_table.resize(SINE_STEPS)
	for i in SINE_STEPS:
		_sine_table[i] = sin(TAU * float(i) / SINE_STEPS)
	# exp(-x) for x in [0, 20], used by every envelope instead of exp()
	_exp_table = PackedFloat32Array()
	_exp_table.resize(1024)
	for i in 1024:
		_exp_table[i] = exp(-20.0 * float(i) / 1023.0)

func _exp(x: float) -> float:
	return _exp_table[clampi(int(x * 51.15), 0, 1023)]

func _sin(phase: float) -> float:
	return _sine_table[int(phase * SINE_SCALE) & 2047]

# ---------------------------------------------------------------- music loop

func _generate_music() -> void:
	var total := int(LOOP_LEN * MIX_RATE)
	var delay_samples := int(BEAT_LEN * 0.75 * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(total)
	# Am - F - C - G progression, roots + chord tones (3 per bar, flat)
	var roots := PackedFloat32Array([110.0, 87.31, 130.81, 98.0])
	var chords := PackedFloat32Array([
		220.0, 261.63, 329.63,
		174.61, 220.0, 261.63,
		130.81, 164.81, 196.0,
		196.0, 246.94, 293.66,
	])
	var prev_noise := 0.0
	var peak := 0.001
	var sine := _sine_table
	var expt := _exp_table
	for i in total:
		var t := float(i) / MIX_RATE
		var bar := int(t / BAR_LEN) % BARS
		var bar_t := fmod(t, BAR_LEN)
		var beat_phase := fmod(t, BEAT_LEN)
		var s := 0.0
		# Kick: pitch-dropped sine on every beat
		if beat_phase < 0.28:
			var kp := beat_phase
			var kphase := TAU * (42.0 * kp + 88.0 * (1.0 - expt[clampi(int(kp * 10.0 * 51.15), 0, 1023)]) / 10.0)
			s += sine[int(kphase * SINE_SCALE) & 2047] * expt[clampi(int(kp * 14.0 * 51.15), 0, 1023)] * 0.9
		# Bass: 8th notes on the root, with the fifth on the last 8th of the bar
		var eighth := int(t / (BEAT_LEN * 0.5))
		var ephase := fmod(t, BEAT_LEN * 0.5)
		var root: float = roots[bar]
		if eighth % 8 == 6:
			root *= 1.5
		var benv: float = expt[clampi(int(ephase * 6.0 * 51.15), 0, 1023)]
		s += (sine[int(TAU * root * ephase * SINE_SCALE) & 2047] + 0.4 * sine[int(TAU * 2.0 * root * ephase * SINE_SCALE) & 2047]) * benv * 0.34
		# Pad: detuned chord tones, slow attack per bar
		var pad_env := minf(1.0, bar_t * 2.0) * 0.05
		var c0: float = chords[bar * 3]
		var c1: float = chords[bar * 3 + 1]
		var c2: float = chords[bar * 3 + 2]
		s += (sine[int(TAU * c0 * t * SINE_SCALE) & 2047] + sine[int(TAU * c0 * 1.005 * t * SINE_SCALE) & 2047]) * pad_env
		s += (sine[int(TAU * c1 * t * SINE_SCALE) & 2047] + sine[int(TAU * c1 * 1.005 * t * SINE_SCALE) & 2047]) * pad_env
		s += (sine[int(TAU * c2 * t * SINE_SCALE) & 2047] + sine[int(TAU * c2 * 1.005 * t * SINE_SCALE) & 2047]) * pad_env
		# Arp: 16th-note pluck, chord tone cycling, one octave up
		var sixteenth := int(t / (BEAT_LEN * 0.25))
		var sphase := fmod(t, BEAT_LEN * 0.25)
		var tone: float = chords[bar * 3 + sixteenth % 3] * 2.0
		s += sine[int(TAU * tone * sphase * SINE_SCALE) & 2047] * expt[clampi(int(sphase * 9.0 * 51.15), 0, 1023)] * 0.15
		# Dotted-8th echo of the arp (reads back already-written samples)
		if i > delay_samples:
			s += samples[i - delay_samples] * 0.28
		# Hat: filtered noise on the off-beats
		var hb := fmod(t + BEAT_LEN * 0.5, BEAT_LEN)
		var noise := randf_range(-1.0, 1.0)
		var hp := noise - prev_noise
		prev_noise = noise
		if hb < 0.05:
			s += hp * expt[clampi(int(hb * 60.0 * 51.15), 0, 1023)] * 0.45
		# Soft clip and store
		s = s / (1.0 + absf(s) * 0.6)
		samples[i] = s
		if absf(s) > peak:
			peak = absf(s)
	# Normalize and encode to 16-bit PCM
	var scale := 0.85 / peak
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		var v := int(clampf(samples[i] * scale, -1.0, 1.0) * 32767.0)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = total
	music_player.stream = stream
	music_ready = true

# ---------------------------------------------------------------- SFX

func _make_tone_stream(duration: float, fn: Callable) -> AudioStreamWAV:
	var total := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		var t := float(i) / MIX_RATE
		var v := int(clampf(float(fn.call(t, i)), -1.0, 1.0) * 32767.0)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream

func _generate_sfx() -> void:
	# Gate chime: two bright sine notes
	_chime_stream = _make_tone_stream(0.5, func(t: float, _i: int) -> float:
		var s := 0.0
		s += _sin(TAU * 880.0 * t) * _exp(t * 9.0) * 0.6
		if t > 0.08:
			s += _sin(TAU * 1318.5 * (t - 0.08)) * _exp((t - 0.08) * 8.0) * 0.5
		return s
	)
	# Near-miss whoosh: swept noise
	_whoosh_stream = _make_tone_stream(0.35, func(t: float, _i: int) -> float:
		var env := sin(PI * clampf(t / 0.35, 0.0, 1.0))
		return randf_range(-1.0, 1.0) * env * 0.5
	)
	# Crash thud: low sine drop plus noise burst
	_thud_stream = _make_tone_stream(0.55, func(t: float, _i: int) -> float:
		var phase := TAU * (38.0 * t + 62.0 * (1.0 - _exp(t * 9.0)) / 9.0)
		var s := _sin(phase) * _exp(t * 7.0) * 0.9
		s += randf_range(-1.0, 1.0) * _exp(t * 22.0) * 0.4
		return s
	)

# ---------------------------------------------------------------- public API

func start_music() -> void:
	if music_ready and not music_player.playing:
		music_player.play()

func music_position() -> float:
	if music_player.playing:
		return music_player.get_playback_position()
	return -1.0

func duck_music(ducked: bool) -> void:
	music_player.volume_db = -20.0 if ducked else -9.0

func _play(stream: AudioStreamWAV, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var p := _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_players.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()

func play_chime(combo: int) -> void:
	_play(_chime_stream, 1.0 + minf(combo, 12) * 0.04, -3.0)

func play_whoosh() -> void:
	_play(_whoosh_stream, randf_range(0.9, 1.15), -6.0)

func play_thud() -> void:
	_play(_thud_stream, 1.0, 0.0)
