extends Node3D
class_name Frog3D

var body_pivot: Node3D
var hop_phase: float = 0.0
var flee_dir: Vector3 = Vector3.ZERO
var fleeing: bool = false
var flee_speed: float = 11.0
var home_pos: Vector3 = Vector3.ZERO
var wander_target: Vector3 = Vector3.ZERO
var hop_cooldown: float = 0.0
var airborne_t: float = 0.0
var hit_stun: float = 0.0


static func create(p_home: Vector3, phase_offset: float = 0.0) -> Frog3D:
	var f := Frog3D.new()
	f.home_pos = p_home
	f.position = p_home
	f.hop_phase = phase_offset
	f.hop_cooldown = fmod(phase_offset, 1.4) + 0.2
	f._build()
	return f


func _mat(col: Color, rough: float = 0.55) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	return m


func _sphere(parent: Node3D, pos: Vector3, scale_v: Vector3, mat: Material, seg: int = 16, rings: int = 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = seg
	sm.rings = rings
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale_v
	parent.add_child(mi)
	return mi


func _build() -> void:
	body_pivot = Node3D.new()
	add_child(body_pivot)

	var lime := _mat(Color(0.65, 0.81, 0.36), 0.45)
	var cream := _mat(Color(0.96, 0.95, 0.89), 0.55)
	var dark_eye := _mat(Color(0.08, 0.08, 0.05), 0.12)
	var white := _mat(Color(1.0, 1.0, 1.0), 0.15)
	var nostril := _mat(Color(0.28, 0.38, 0.18), 0.65)

	# Chubby plump body (lime-green dome + creamy round belly)
	_sphere(body_pivot, Vector3(0, 0.34, -0.02), Vector3(0.92, 0.68, 1.02), lime, 24, 16)
	_sphere(body_pivot, Vector3(0, 0.21, 0.14), Vector3(0.84, 0.46, 0.86), cream, 24, 16)

	# Big protruding eyes with lime outer socket + cream iris rim + glossy black eye + white highlight!
	for sx in [-0.28, 0.28]:
		var side := signf(sx)
		_sphere(body_pivot, Vector3(sx, 0.58, 0.28), Vector3(0.32, 0.32, 0.30), lime, 18, 12)
		_sphere(body_pivot, Vector3(sx + side * 0.03, 0.58, 0.33), Vector3(0.26, 0.26, 0.26), cream, 18, 12)
		_sphere(body_pivot, Vector3(sx + side * 0.045, 0.58, 0.36), Vector3(0.21, 0.22, 0.20), dark_eye, 18, 12)
		_sphere(body_pivot, Vector3(sx + side * 0.065, 0.63, 0.44), Vector3(0.065, 0.065, 0.04), white, 10, 6)

	# Two tiny nostrils on the snout
	_sphere(body_pivot, Vector3(-0.06, 0.43, 0.49), Vector3(0.032, 0.032, 0.02), nostril, 8, 6)
	_sphere(body_pivot, Vector3(0.06, 0.43, 0.49), Vector3(0.032, 0.032, 0.02), nostril, 8, 6)

	# Chubby folded hind legs + stubby front legs & little toes
	for sx in [-0.36, 0.36]:
		_sphere(body_pivot, Vector3(sx, 0.18, -0.22), Vector3(0.26, 0.28, 0.38), lime, 14, 10)
		_sphere(body_pivot, Vector3(sx * 0.92, 0.05, -0.08), Vector3(0.18, 0.09, 0.22), lime, 12, 8)
	for sx in [-0.28, 0.28]:
		_sphere(body_pivot, Vector3(sx, 0.14, 0.28), Vector3(0.15, 0.22, 0.15), lime, 12, 8)
		_sphere(body_pivot, Vector3(sx, 0.045, 0.33), Vector3(0.17, 0.08, 0.18), lime, 12, 8)


func scare_away(from_pos: Vector3) -> void:
	if fleeing:
		return
	fleeing = true
	SoundFX.play("frog_croak", -4.5, randf_range(0.92, 1.14))
	var away := Vector3(position.x - from_pos.x, 0.0, position.z - from_pos.z)
	if away.length() < 0.05:
		away = Vector3(1.0, 0.0, 0.5)
	flee_dir = away.normalized()
	rotation.y = atan2(flee_dir.x, flee_dir.z)
	airborne_t = 0.01
	hit_stun = 0.12


func update_frog(delta: float) -> bool:
	# Returns true if frog should stay in scene, false once it fled far off-screen!
	if fleeing:
		if hit_stun > 0.0:
			hit_stun -= delta
			body_pivot.scale = Vector3(1.25, 0.72, 1.25)
			return true
		position += flee_dir * flee_speed * delta
		airborne_t += delta * 5.2
		var arc := absf(sin(airborne_t * PI))
		body_pivot.position.y = arc * 1.15
		body_pivot.scale = Vector3(0.90, 1.15, 0.95) if arc > 0.2 else Vector3(1.15, 0.85, 1.10)
		rotation.y = atan2(flee_dir.x, flee_dir.z)
		if position.distance_to(home_pos) > 26.0:
			return false
		return true

	# Cute idle hopping around the partner!
	if airborne_t > 0.0:
		airborne_t += delta * 2.8
		var dir := (wander_target - position)
		dir.y = 0.0
		if dir.length() > 0.05:
			position += dir.normalized() * 2.2 * delta
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), min(1.0, delta * 10.0))
		if airborne_t >= 1.0:
			airborne_t = 0.0
			body_pivot.position.y = 0.0
			body_pivot.scale = Vector3(1.16, 0.84, 1.12)
			hop_cooldown = randf_range(0.6, 1.6)
		else:
			var h := sin(airborne_t * PI)
			body_pivot.position.y = h * 0.55
			body_pivot.scale = Vector3(0.92, 1.12, 0.94)
	else:
		body_pivot.scale = body_pivot.scale.lerp(Vector3.ONE, min(1.0, delta * 8.0))
		hop_cooldown -= delta
		if hop_cooldown <= 0.0:
			var ang := randf_range(0.0, TAU)
			var rad := randf_range(1.4, 3.6)
			wander_target = home_pos + Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)
			airborne_t = 0.001

	return true
