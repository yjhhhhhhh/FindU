extends Node
class_name GameJuice

## Global engine-neutral Game Feel (Juice) manager:
## - Real-time safe Hitstop (unscaled micro-usec clock, newest-call ownership)
## - Trauma-based camera shake (shake = trauma^2, summed incommensurate sines, never random static)
## - Gravity-affected 3D particle splashes & ground shockwave rings

static var instance: GameJuice = null

var trauma: float = 0.0
var trauma_decay: float = 1.65
var shake_strength: float = 1.0
var _shake_clock: float = 0.0

var _hitstop_id: int = 0
var _hitstop_end_usec: int = 0
var _active_particles: Array[Dictionary] = []


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if instance == self:
		instance = null


func _process(delta: float) -> void:
	var now_u := Time.get_ticks_usec()
	if _hitstop_end_usec > 0 and now_u >= _hitstop_end_usec:
		_hitstop_end_usec = 0
		Engine.time_scale = 1.0

	var real_dt := delta / maxf(Engine.time_scale, 0.001)
	real_dt = minf(real_dt, 0.05)

	if trauma > 0.0:
		trauma = maxf(0.0, trauma - trauma_decay * real_dt)
		_shake_clock += real_dt

	# Update pooled/active 3D physics splash particles (asymmetric drag & gravity)
	for i in range(_active_particles.size() - 1, -1, -1):
		var p: Dictionary = _active_particles[i]
		var node: MeshInstance3D = p["node"]
		if not is_instance_valid(node):
			_active_particles.remove_at(i)
			continue
		p["age"] += delta
		var t_norm: float = p["age"] / p["life"]
		if t_norm >= 1.0:
			node.queue_free()
			_active_particles.remove_at(i)
			continue
		var vel: Vector3 = p["vel"]
		vel.y -= float(p["grav"]) * delta
		vel.x *= (1.0 - 2.8 * delta)
		vel.z *= (1.0 - 2.8 * delta)
		p["vel"] = vel
		node.position += vel * delta
		if node.position.y < 0.05 and vel.y < 0.0:
			node.position.y = 0.05
			p["vel"].y = -vel.y * 0.35
		# Snappy ease-out shrink
		var ease_rem := 1.0 - pow(t_norm, 2.2)
		node.scale = p["base_scale"] * maxf(0.02, ease_rem)
		node.rotation.x += delta * 5.0
		node.rotation.z += delta * 4.0


static func add_trauma(amount: float) -> void:
	if instance == null:
		return
	instance.trauma = clampf(instance.trauma + amount, 0.0, 1.0)


static func hitstop(duration_sec: float = 0.048, slow_scale: float = 0.06) -> void:
	if instance == null or duration_sec <= 0.0:
		return
	instance._hitstop_id += 1
	var target_end := Time.get_ticks_usec() + int(duration_sec * 1000000.0)
	if target_end > instance._hitstop_end_usec:
		instance._hitstop_end_usec = target_end
	Engine.time_scale = clampf(slow_scale, 0.02, 1.0)


static func apply_camera_shake(cam: Camera3D, max_h: float = 0.22, max_v: float = 0.15) -> void:
	if cam == null:
		return
	if instance == null or instance.trauma <= 0.0001:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
		return
	var sh := instance.trauma * instance.trauma * instance.shake_strength
	var t := instance._shake_clock * 26.0
	# Summed sines at incommensurate frequencies (Squirrel Eiserloh trauma model)
	var nx := 0.62 * sin(t * 1.7 + 0.8) + 0.38 * sin(t * 3.1 + 2.1)
	var ny := 0.58 * sin(t * 2.3 + 1.4) + 0.42 * sin(t * 3.9 + 0.3)
	cam.h_offset = max_h * sh * nx
	cam.v_offset = max_v * sh * ny


static func spawn_splash(parent: Node, origin: Vector3, col: Color, count: int = 14, speed_scale: float = 1.0, shockwave: bool = true) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var accent := col.lightened(0.28)
	for i in range(count):
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var sz := randf_range(0.07, 0.14)
		bm.size = Vector3(sz, sz * randf_range(0.8, 1.6), sz)
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		var c := col if i % 3 != 0 else accent
		mat.albedo_color = c
		mat.roughness = 0.35
		mat.metallic_specular = 0.18
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = 1.25
		mi.material_override = mat
		mi.position = origin + Vector3(randf_range(-0.15, 0.15), randf_range(0.22, 0.58), randf_range(-0.15, 0.15))
		mi.rotation = Vector3(randf_range(0, TAU), randf_range(0, TAU), randf_range(0, TAU))
		parent.add_child(mi)

		var ang := (float(i) / float(max(1, count))) * TAU + randf_range(-0.32, 0.32)
		var h_spd := randf_range(1.6, 4.2) * speed_scale
		var v_spd := randf_range(2.6, 5.8) * speed_scale
		if instance != null:
			instance._active_particles.append({
				"node": mi,
				"vel": Vector3(cos(ang) * h_spd, v_spd, sin(ang) * h_spd),
				"grav": 13.5,
				"age": 0.0,
				"life": randf_range(0.36, 0.64),
				"base_scale": Vector3.ONE,
			})
		else:
			var tw := parent.create_tween()
			tw.tween_property(mi, "scale", Vector3.ONE * 0.02, 0.45)
			tw.tween_callback(mi.queue_free)

	if shockwave:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.42
		tm.outer_radius = 0.52
		tm.rings = 16
		tm.ring_segments = 6
		ring.mesh = tm
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(col.r, col.g, col.b, 0.88)
		rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rmat.emission_enabled = true
		rmat.emission = col
		rmat.emission_energy_multiplier = 1.35
		ring.material_override = rmat
		ring.position = Vector3(origin.x, maxf(0.08, origin.y + 0.08), origin.z)
		ring.scale = Vector3(0.45, 0.25, 0.45)
		parent.add_child(ring)
		var rtw := parent.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		rtw.tween_property(ring, "scale", Vector3(2.8 * speed_scale, 0.12, 2.8 * speed_scale), 0.34)
		rtw.parallel().tween_property(rmat, "albedo_color:a", 0.0, 0.34)
		rtw.tween_callback(ring.queue_free)
