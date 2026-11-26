extends Node
class_name SoundFX

const CONFIG_PATH := "user://save_progress.cfg"

static var instance: SoundFX = null

var muted: bool = false
var bgm_volume: float = 0.75
var sfx_volume: float = 0.75
var bgm_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer
var ambient_active: bool = false
var ambient_base_db: float = -16.0
var sfx_streams: Dictionary = {}


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_audio_settings()
	_init_audio()


func _load_audio_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		muted = bool(cfg.get_value("audio", "muted", false))
		bgm_volume = clampf(float(cfg.get_value("audio", "bgm_volume", 0.75)), 0.0, 1.0)
		sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", 0.75)), 0.0, 1.0)


func save_audio_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("audio", "bgm_volume", bgm_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.save(CONFIG_PATH)


func _init_audio() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.stream = _make_forest_bgm()
	add_child(bgm_player)
	_apply_bgm_volume()
	bgm_player.play()
	bgm_player.stream_paused = muted or bgm_volume <= 0.001

	sfx_streams["jump"] = _make_sweep(235.0, 455.0, 0.13, 0.44)
	sfx_streams["land"] = _make_thud(145.0, 68.0, 0.10, 0.42)
	sfx_streams["step"] = _make_step()
	sfx_streams["ui_click"] = _make_thud(640.0, 420.0, 0.055, 0.34)
	sfx_streams["ui_hover"] = _make_thud(860.0, 740.0, 0.032, 0.22)
	sfx_streams["mushroom"] = _make_arp([392.0, 523.25], 0.10, 0.42)
	sfx_streams["keepsake"] = _make_arp([440.0, 554.37, 659.25], 0.095, 0.48)
	sfx_streams["gate"] = _make_arp([293.66, 392.0, 493.88, 587.33], 0.088, 0.58)
	sfx_streams["bonk"] = _make_bonk()
	sfx_streams["frog_croak"] = _make_frog_croak()
	sfx_streams["sizzle"] = _make_sizzle()
	sfx_streams["warn"] = _make_sweep(580.0, 660.0, 0.13, 0.42)
	sfx_streams["angry"] = _make_sweep(380.0, 210.0, 0.22, 0.52)
	sfx_streams["victory"] = _make_arp([392.0, 493.88, 587.33, 783.99], 0.13, 0.75)
	sfx_streams["waterfall_hit"] = _make_waterfall_hit()
	sfx_streams["water_ring"] = _make_arp([587.33, 783.99, 1046.50, 1318.51], 0.055, 0.30)
	sfx_streams["pelican_call"] = _make_pelican_call()
	sfx_streams["big_splash"] = _make_big_splash()
	sfx_streams["wind_whoosh"] = _make_wind_whoosh()
	sfx_streams["bead_place"] = _make_bead_place()
	sfx_streams["quiz_pop"] = _make_arp([523.25, 659.25], 0.055, 0.22)
	sfx_streams["quiz_ok"] = _make_arp([587.33, 739.99, 880.0], 0.058, 0.28)
	sfx_streams["bead_scatter"] = _make_bead_scatter()
	sfx_streams["iron_steam"] = _make_iron_steam()
	sfx_streams["door_chime"] = _make_arp([1046.50, 1318.51, 1567.98, 2093.0], 0.085, 0.56)

	ambient_player = AudioStreamPlayer.new()
	ambient_player.stream = _make_waterfall_loop()
	add_child(ambient_player)
	ambient_player.volume_db = -80.0


func _apply_ambient_volume() -> void:
	if not ambient_player:
		return
	if not ambient_active or muted or sfx_volume <= 0.001:
		ambient_player.stream_paused = true
		ambient_player.volume_db = -80.0
	else:
		if not ambient_player.playing:
			ambient_player.play()
		ambient_player.stream_paused = false
		ambient_player.volume_db = ambient_base_db + linear_to_db(sfx_volume)


static func start_waterfall_ambient() -> void:
	if instance == null:
		return
	instance.ambient_active = true
	instance.ambient_base_db = -17.0
	instance._apply_ambient_volume()


static func set_waterfall_intensity(intensity: float) -> void:
	if instance == null or not instance.ambient_player or not instance.ambient_active:
		return
	var k := clampf(intensity, 0.0, 1.0)
	instance.ambient_base_db = lerpf(-21.0, -12.5, k)
	instance.ambient_player.pitch_scale = lerpf(0.86, 1.18, k)
	instance._apply_ambient_volume()


static func stop_waterfall_ambient() -> void:
	if instance == null:
		return
	instance.ambient_active = false
	if instance.ambient_player:
		instance.ambient_player.stop()
		instance.ambient_player.pitch_scale = 1.0


func _apply_bgm_volume() -> void:
	if not bgm_player:
		return
	if muted or bgm_volume <= 0.001:
		bgm_player.stream_paused = true
		bgm_player.volume_db = -80.0
	else:
		bgm_player.stream_paused = false
		bgm_player.volume_db = -14.0 + linear_to_db(bgm_volume)


static func set_muted(m: bool) -> void:
	if instance == null:
		return
	instance.muted = m
	instance._apply_bgm_volume()
	instance._apply_ambient_volume()
	instance.save_audio_settings()


static func toggle_mute() -> bool:
	if instance == null:
		return false
	set_muted(not instance.muted)
	return instance.muted


static func set_bgm_volume(vol: float) -> void:
	if instance == null:
		return
	instance.bgm_volume = clampf(vol, 0.0, 1.0)
	instance._apply_bgm_volume()
	instance.save_audio_settings()


static func set_sfx_volume(vol: float) -> void:
	if instance == null:
		return
	instance.sfx_volume = clampf(vol, 0.0, 1.0)
	instance._apply_ambient_volume()
	instance.save_audio_settings()


static func get_sfx_volume_db(base_db: float = -6.0) -> float:
	if instance == null:
		return base_db
	if instance.muted or instance.sfx_volume <= 0.001:
		return -80.0
	return base_db + linear_to_db(instance.sfx_volume)


static func is_sfx_audible() -> bool:
	if instance == null:
		return true
	return (not instance.muted) and instance.sfx_volume > 0.001


static func play(sfx_name: String, vol_db: float = -7.0, pitch_scale: float = -1.0) -> void:
	if instance == null or not is_sfx_audible():
		return
	if not instance.sfx_streams.has(sfx_name):
		return
	var p := AudioStreamPlayer.new()
	p.stream = instance.sfx_streams[sfx_name]
	p.volume_db = get_sfx_volume_db(vol_db)
	# Pitch micro-randomization (gamedev-craft: prevents mechanical audio fatigue!)
	if pitch_scale > 0.0:
		p.pitch_scale = pitch_scale
	elif sfx_name in ["victory", "gate", "keepsake"]:
		p.pitch_scale = randf_range(0.98, 1.025)
	elif sfx_name == "mushroom":
		p.pitch_scale = randf_range(0.95, 1.07)
	else:
		p.pitch_scale = randf_range(0.91, 1.10)
	instance.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _make_wav(samples: PackedInt32Array, mix_rate: int = 22050, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		data.encode_s16(i * 2, clampi(samples[i], -32767, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


func _make_forest_bgm() -> AudioStreamWAV:
	var rate := 22050
	var notes := [
		392.00, 493.88, 587.33, 493.88,
		440.00, 493.88, 659.25, 587.33,
		392.00, 493.88, 587.33, 783.99,
		659.25, 587.33, 493.88, 440.00,
	]
	var step_dur := 0.50
	var total := int(float(rate) * step_dur * float(notes.size()))
	var buf := PackedInt32Array()
	buf.resize(total)

	for n_idx in range(notes.size()):
		var hz: float = notes[n_idx]
		var start_i := int(float(n_idx) * step_dur * float(rate))
		var note_len := int(0.95 * float(rate))
		for j in range(note_len):
			var idx := (start_i + j) % total
			var t := float(j) / float(rate)
			var attack := 0.5 - 0.5 * cos(PI * minf(1.0, t / 0.022))
			var env := attack * exp(-t * 3.5)
			var w := sin(TAU * hz * t) * 0.78 + sin(TAU * hz * 2.0 * t) * 0.12 * exp(-t * 8.0)
			if n_idx % 4 == 0:
				w += sin(TAU * (hz * 0.5) * t) * 0.28 * exp(-t * 2.4)
			buf[idx] += int(w * env * 9000.0)
	return _make_wav(buf, rate, true)


func _make_sweep(f0: float, f1: float, dur: float, gain: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(float(rate) * dur)
	var buf := PackedInt32Array()
	buf.resize(n)
	var phase := 0.0
	for i in range(n):
		var u := float(i) / float(n)
		var f := lerpf(f0, f1, pow(u, 0.72))
		phase += TAU * f / float(rate)
		var env := minf(1.0, u / 0.10) * pow(1.0 - u, 1.35)
		buf[i] = int(sin(phase) * env * gain * 20000.0)
	return _make_wav(buf, rate)


func _make_thud(f0: float, f1: float, dur: float, gain: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(float(rate) * dur)
	var buf := PackedInt32Array()
	buf.resize(n)
	var ph := 0.0
	for i in range(n):
		var u := float(i) / float(n)
		var f := lerpf(f0, f1, pow(u, 0.55))
		ph += TAU * f / float(rate)
		var env := exp(-u * 6.2) * (1.0 - u)
		buf[i] = int(sin(ph) * env * gain * 19000.0)
	return _make_wav(buf, rate)


func _make_step() -> AudioStreamWAV:
	var rate := 22050
	var n := int(float(rate) * 0.055)
	var buf := PackedInt32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 109
	var ph := 0.0
	for i in range(n):
		var u := float(i) / float(n)
		ph += TAU * lerpf(190.0, 95.0, u) / float(rate)
		var env := minf(1.0, u / 0.12) * exp(-u * 5.8)
		var moss := sin(ph) * 0.65 + rng.randf_range(-1.0, 1.0) * 0.35
		buf[i] = int(moss * env * 12000.0)
	return _make_wav(buf, rate)


func _make_arp(freqs: Array, step_s: float, tail_s: float) -> AudioStreamWAV:
	var rate := 22050
	var total := int(float(rate) * (step_s * float(freqs.size() - 1) + tail_s))
	var buf := PackedInt32Array()
	buf.resize(total)
	for k in range(freqs.size()):
		var hz: float = float(freqs[k])
		var s0 := int(float(k) * step_s * float(rate))
		var len_i := int(tail_s * float(rate))
		for j in range(len_i):
			if s0 + j >= total:
				break
			var t := float(j) / float(rate)
			var attack := 0.5 - 0.5 * cos(PI * minf(1.0, t / 0.020))
			var fade_out := minf(1.0, float(len_i - j) / (0.05 * float(rate)))
			var env := attack * exp(-t * 4.8) * fade_out
			var w := sin(TAU * hz * t) * 0.85 + sin(TAU * hz * 2.0 * t) * 0.12 * exp(-t * 9.0)
			buf[s0 + j] += int(w * env * 13000.0)
	return _make_wav(buf, rate)


func _make_bonk() -> AudioStreamWAV:
	var rate := 22050
	var n := int(float(rate) * 0.20)
	var buf := PackedInt32Array()
	buf.resize(n)
	var ph := 0.0
	for i in range(n):
		var u := float(i) / float(n)
		var f := lerpf(340.0, 125.0, pow(u, 0.45))
		ph += TAU * f / float(rate)
		var env := exp(-u * 6.5)
		buf[i] = int(sin(ph) * env * 19500.0)
	return _make_wav(buf, rate)


func _make_frog_croak() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.26
	var n := int(float(rate) * dur)
	var buf := PackedInt32Array()
	buf.resize(n)
	var ph_base := 0.0
	var ph_form := 0.0
	for i in range(n):
		var t := float(i) / float(rate)
		var u := float(i) / float(n)
		var f_base := lerpf(190.0, 355.0, pow(u, 0.62))
		var f_form := lerpf(560.0, 980.0, pow(u, 0.55))
		ph_base += TAU * f_base / float(rate)
		ph_form += TAU * f_form / float(rate)
		var trill := 0.35 + 0.65 * pow(0.5 + 0.5 * sin(TAU * 36.0 * t), 1.5)
		var env := minf(1.0, u / 0.09) * pow(1.0 - u, 0.85) * trill
		var w := sin(ph_base + 0.85 * sin(ph_base * 0.5)) * 0.45 + sin(ph_form) * 0.40 + sin(ph_base * 2.0) * 0.15
		buf[i] = int(w * env * 21000.0)
	return _make_wav(buf, rate)


func _make_sizzle() -> AudioStreamWAV:
	var rate := 22050
	var n := int(float(rate) * 0.35)
	var buf := PackedInt32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(n):
		var u := float(i) / float(n)
		var env := minf(1.0, u / 0.06) * exp(-u * 4.5)
		buf[i] = int(rng.randf_range(-1.0, 1.0) * env * 11000.0)
	return _make_wav(buf, rate)


func _make_waterfall_loop() -> AudioStreamWAV:
	var rate := 22050
	var n := int(float(rate) * 2.0)
	var buf := PackedInt32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 40404
	var lp1 := 0.0
	var lp2 := 0.0
	var raw: Array[float] = []
	raw.resize(n)
	for i in range(n):
		var w := rng.randf_range(-1.0, 1.0)
		lp1 = lerpf(lp1, w, 0.14)
		lp2 = lerpf(lp2, lp1, 0.05)
		raw[i] = lp2 * 0.65 + (lp1 - lp2) * 0.55 + w * 0.08
	var xfade := int(float(rate) * 0.12)
	for i in range(xfade):
		var t := float(i) / float(xfade)
		raw[i] = lerpf(raw[n - xfade + i], raw[i], t)
	for i in range(n):
		var mod := 0.90 + 0.10 * sin(TAU * float(i) / float(n) * 2.0)
		buf[i] = int(clampf(raw[i] * mod * 11500.0, -30000.0, 30000.0))
	return _make_wav(buf, rate, true)


func _make_waterfall_hit() -> AudioStreamWAV:
	var rate := 22050
	var n := int(float(rate) * 0.28)
	var buf := PackedInt32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 771
	var ph := 0.0
	var lp := 0.0
	for i in range(n):
		var u := float(i) / float(n)
		ph += TAU * lerpf(165.0, 58.0, pow(u, 0.5)) / float(rate)
		var thud := sin(ph) * exp(-u * 8.5) * 0.72
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.24)
		var splash := lp * minf(1.0, u / 0.08) * exp(-u * 4.8) * 0.52
		buf[i] = int((thud + splash) * 22000.0)
	return _make_wav(buf, rate)


func _make_pelican_call() -> AudioStreamWAV:
	var rate := 22050
	var n := int(float(rate) * 0.42)
	var buf := PackedInt32Array()
	buf.resize(n)
	var ph1 := 0.0
	var ph2 := 0.0
	for i in range(n):
		var u := float(i) / float(n)
		var t := float(i) / float(rate)
		var f := 155.0 + 95.0 * sin(u * PI) - 30.0 * u
		ph1 += TAU * f / float(rate)
		ph2 += TAU * (f * 2.45) / float(rate)
		var rasp := 0.55 + 0.45 * sin(TAU * 28.0 * t)
		var env := minf(1.0, u / 0.08) * pow(1.0 - u, 0.72) * rasp
		var w := sin(ph1 + 0.9 * sin(ph1 * 0.5)) * 0.58 + sin(ph2) * 0.34
		buf[i] = int(w * env * 19500.0)
	return _make_wav(buf, rate)


func _make_big_splash() -> AudioStreamWAV:
	var rate := 22050
	var n := int(float(rate) * 0.85)
	var buf := PackedInt32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var ph := 0.0
	var lp := 0.0
	for i in range(n):
		var u := float(i) / float(n)
		ph += TAU * lerpf(135.0, 44.0, pow(u, 0.4)) / float(rate)
		var plunge := sin(ph) * exp(-u * 9.0) * 0.68
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), lerpf(0.32, 0.12, u))
		var foam := lp * minf(1.0, u / 0.05) * exp(-u * 2.8) * 0.65
		buf[i] = int((plunge + foam) * 23500.0)
	return _make_wav(buf, rate)


func _make_wind_whoosh() -> AudioStreamWAV:
	var rate := 22050
	var n := int(float(rate) * 0.30)
	var buf := PackedInt32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 313
	var lp := 0.0
	for i in range(n):
		var u := float(i) / float(n)
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), lerpf(0.10, 0.28, sin(u * PI)))
		var env := sin(u * PI) * 0.9
		buf[i] = int(lp * env * 15000.0)
	return _make_wav(buf, rate)


func _make_bead_place() -> AudioStreamWAV:
	var rate := 22050
	var n := int(float(rate) * 0.068)
	var buf := PackedInt32Array()
	buf.resize(n)
	var ph1 := 0.0
	var ph2 := 0.0
	for i in range(n):
		var u := float(i) / float(n)
		ph1 += TAU * lerpf(920.0, 480.0, pow(u, 0.45)) / float(rate)
		ph2 += TAU * lerpf(1850.0, 1120.0, u) / float(rate)
		var env := minf(1.0, u / 0.04) * exp(-u * 9.5)
		var w := sin(ph1) * 0.65 + sin(ph2) * 0.35 * exp(-u * 14.0)
		buf[i] = int(w * env * 17500.0)
	return _make_wav(buf, rate)


func _make_bead_scatter() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.48
	var n := int(float(rate) * dur)
	var buf := PackedInt32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 50505
	# Low table shake thump + 11 crisp plastic bead clatters scattered across 0.45s
	for i in range(int(float(rate) * 0.14)):
		var u := float(i) / (float(rate) * 0.14)
		buf[i] += int(sin(TAU * lerpf(150.0, 58.0, u) * (float(i) / float(rate))) * exp(-u * 7.5) * 14000.0)
	for k in range(11):
		var start_i := int(rng.randf_range(0.02, 0.38) * float(rate))
		var click_len := int(0.036 * float(rate))
		var f0 := rng.randf_range(950.0, 2100.0)
		var amp := rng.randf_range(7500.0, 14500.0) * (1.0 - float(k) * 0.04)
		var ph := 0.0
		for j in range(click_len):
			if start_i + j >= n:
				break
			var u := float(j) / float(click_len)
			ph += TAU * lerpf(f0, f0 * 0.68, u) / float(rate)
			buf[start_i + j] += int(sin(ph) * exp(-u * 11.0) * amp)
	return _make_wav(buf, rate)


func _make_iron_steam() -> AudioStreamWAV:
	var rate := 22050
	var n := int(float(rate) * 0.32)
	var buf := PackedInt32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 818
	var lp := 0.0
	for i in range(n):
		var u := float(i) / float(n)
		var w := rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, w, 0.35)
		var hp := w - lp * 0.65
		var env := sin(u * PI) * 0.85
		buf[i] = int(hp * env * 10500.0)
	return _make_wav(buf, rate)
