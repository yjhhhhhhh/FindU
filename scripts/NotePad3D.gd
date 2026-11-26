extends Node3D
class_name NotePad3D

var stone_mesh: MeshInstance3D
var stone_mat: StandardMaterial3D
var note_pivot: Node3D
var note_mat: StandardMaterial3D
var audio_player: AudioStreamPlayer

var revealed: bool = false
var lit: bool = false
var spin_time: float = 0.0
var freq_hz: float = 523.25


static func create(p_pos: Vector3, p_freq_hz: float = 523.25) -> NotePad3D:
	var np := NotePad3D.new()
	np.position = p_pos
	np.freq_hz = p_freq_hz
	np._build()
	return np


func _mat(col: Color, rough: float = 0.72, emit_col: Color = Color.BLACK, emit_e: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if emit_e > 0.0:
		m.emission_enabled = true
		m.emission = emit_col
		m.emission_energy_multiplier = emit_e
	return m


func _build() -> void:
	# 1. Raised 3D Beveled Stone Step with non-plastic weathered slate noise
	stone_mesh = MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.85
	bm.bottom_radius = 0.96
	bm.height = 0.28
	bm.radial_segments = 10
	stone_mesh.mesh = bm
	stone_mat = _mat(Color(0.50, 0.56, 0.66), 0.92)
	stone_mat.metallic_specular = 0.14
	stone_mesh.material_override = stone_mat
	stone_mesh.position = Vector3(0, 0.14, 0)
	add_child(stone_mesh)

	# Recessed stone inner ring
	var ring := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.66
	rm.bottom_radius = 0.68
	rm.height = 0.04
	rm.radial_segments = 10
	ring.mesh = rm
	ring.material_override = VisualPolish.make_organic_mat(Color(0.36, 0.42, 0.50), 2.8, 0.78, 0.96)
	ring.position = Vector3(0, 0.27, 0)
	add_child(ring)

	# 2. 3D Musical Note right in the center of the stone step (starts lying down!)
	note_pivot = Node3D.new()
	note_pivot.position = Vector3(0, 0.30, 0)
	# Resting tilted/lying flat on top of the stone before being stepped on
	note_pivot.rotation_degrees = Vector3(74, -20, 0)
	add_child(note_pivot)

	note_mat = _mat(Color(0.84, 0.88, 0.96), 0.35, Color(0.50, 0.58, 0.78), 0.25)

	# Note head (tilted oval)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.16
	hm.height = 0.22
	hm.radial_segments = 14
	hm.rings = 8
	head.mesh = hm
	head.material_override = note_mat
	head.position = Vector3(-0.08, 0.12, 0)
	head.scale = Vector3(1.25, 0.85, 0.65)
	head.rotation_degrees = Vector3(0, 0, 22)
	note_pivot.add_child(head)

	# Upright stem
	var stem := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.036
	sm.bottom_radius = 0.038
	sm.height = 0.52
	sm.radial_segments = 10
	stem.mesh = sm
	stem.material_override = note_mat
	stem.position = Vector3(0.06, 0.38, 0)
	note_pivot.add_child(stem)

	# Curved flag at top of stem
	var flag1 := MeshInstance3D.new()
	var fm1 := BoxMesh.new()
	fm1.size = Vector3(0.22, 0.09, 0.06)
	flag1.mesh = fm1
	flag1.material_override = note_mat
	flag1.position = Vector3(0.15, 0.58, 0)
	flag1.rotation_degrees = Vector3(0, 0, -28)
	note_pivot.add_child(flag1)

	var flag2 := MeshInstance3D.new()
	var fm2 := BoxMesh.new()
	fm2.size = Vector3(0.14, 0.07, 0.055)
	flag2.mesh = fm2
	flag2.material_override = note_mat
	flag2.position = Vector3(0.22, 0.48, 0)
	flag2.rotation_degrees = Vector3(0, 0, -52)
	note_pivot.add_child(flag2)

	# 3. Synthesized warm wooden-marimba chime AudioStreamPlayer
	audio_player = AudioStreamPlayer.new()
	audio_player.stream = _make_chime_wav(freq_hz)
	audio_player.volume_db = -9.0
	add_child(audio_player)


func _make_chime_wav(hz: float) -> AudioStreamWAV:
	# Soft, warm kalimba/marimba resonance (one warm octave lower, smooth cosine attack, zero harsh harmonics!)
	var mix_rate := 22050
	var dur := 0.78
	var num_samples := int(float(mix_rate) * dur)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	var warm_hz := hz * 0.5

	for i in range(num_samples):
		var t := float(i) / float(mix_rate)
		var attack := 0.5 - 0.5 * cos(PI * minf(1.0, t / 0.028))
		var tail_fade := minf(1.0, (dur - t) / 0.08)
		var env := attack * exp(-t * 3.6) * tail_fade
		var wave := (
			sin(TAU * warm_hz * t) * 0.68
			+ sin(TAU * hz * t) * 0.26 * exp(-t * 5.0)
			+ sin(TAU * warm_hz * 1.5 * t) * 0.06 * exp(-t * 9.0)
		)
		var s := clampi(int(wave * env * 13500.0), -32767, 32767)
		data.encode_s16(i * 2, s)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	return wav


func reveal() -> void:
	revealed = true
	visible = true


func activate() -> void:
	if lit:
		return
	lit = true

	# Stone depresses & glows golden
	stone_mat.albedo_color = Color(1.0, 0.84, 0.32)
	stone_mat.emission_enabled = true
	stone_mat.emission = Color(1.0, 0.78, 0.25)
	stone_mat.emission_energy_multiplier = 0.55

	# Note glows warm gold
	note_mat.albedo_color = Color(1.0, 0.94, 0.45)
	note_mat.emission = Color(1.0, 0.84, 0.28)
	note_mat.emission_energy_multiplier = 1.15

	# Play warm chime with subtle micro-pitch variation respecting global SFX volume & mute!
	if audio_player and SoundFX.is_sfx_audible():
		audio_player.volume_db = SoundFX.get_sfx_volume_db(-9.0)
		audio_player.pitch_scale = randf_range(0.985, 1.02)
		audio_player.play()

	GameJuice.hitstop(0.045, 0.08)
	GameJuice.add_trauma(0.28)
	GameJuice.spawn_splash(get_parent(), global_position, Color(1.0, 0.88, 0.36), 16, 1.0, true)

	# Stand-up animation ("扶起来的动画")!
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(stone_mesh, "position:y", 0.06, 0.18)
	tw.parallel().tween_property(note_pivot, "rotation_degrees", Vector3(0, 0, 0), 0.45)
	tw.parallel().tween_property(note_pivot, "position:y", 0.72, 0.45)
	tw.parallel().tween_property(note_pivot, "scale", Vector3.ONE * 1.18, 0.35)


func _process(delta: float) -> void:
	if lit:
		spin_time += delta
		note_pivot.rotation.y += delta * 1.8
		note_pivot.position.y = 0.72 + sin(spin_time * 3.2) * 0.08
