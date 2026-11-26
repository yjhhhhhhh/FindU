extends Node3D
class_name Level1Scene

signal level_cleared(stats: Dictionary)
signal back_to_select
signal restart_level

# 3D World dimensions (in meters/units): X in [-24, 24], Z in [-16, 16]
const HALF_W := 24.0
const HALF_D := 16.0

const START_POS := Vector3(-18.0, 0.0, 10.5)
const GOAL_POS := Vector3(18.0, 0.0, -9.5)
const BRIDGE_POS := Vector3(7.5, 0.0, 0.0)

const MUSHROOM_CONFIGS := [
	{"pos": Vector3(-11.5, 0.0, 6.0), "reveal": "keepsake"},
	{"pos": Vector3(-10.0, 0.0, -8.5), "reveal": "pad0"},
	{"pos": Vector3(0.5, 0.0, 8.5), "reveal": "pad1"},
	{"pos": Vector3(13.5, 0.0, -2.5), "reveal": "goal_path"},
]

const KEEPSAKE_POS := Vector3(-8.5, 0.0, 3.8)
const PAD_POSITIONS := [Vector3(-6.2, 0.0, -9.2), Vector3(3.2, 0.0, 5.8)]
const EGG_POS := Vector3(-16.5, 0.0, -4.5)

var role: String = "boy"
var partner_role: String = "girl"

var player: PlayerController
var camera: Camera3D

var sway_nodes: Array[Dictionary] = []
var water_ripples: Array[Dictionary] = []
var mushroom_nodes: Array[Dictionary] = []
var pad_nodes: Array[Dictionary] = []

var lit_mushrooms: int = 0
var lit_pads: int = 0

var gate_data: Dictionary = {}
var gate_open: bool = false

var keepsake_node: Node3D
var keepsake_revealed: bool = false
var keepsake_found: bool = false

var egg_node: Node3D
var egg_visited: bool = false
var partner_node: Node3D
var cleared: bool = false

var toast_panel: Control
var toast_label: Label
var hud_label: Label
var minimap: MiniMap
var toast_timer: float = 0.0
var butterfly: Node3D = null
var butterfly_wing_l: Node3D = null
var butterfly_wing_r: Node3D = null
var butterfly_vel := Vector3.ZERO
var butterfly_life: float = 0.0
var partner_model: Chibi3D = null


func init_role(p_role: String) -> void:
	role = p_role
	partner_role = "girl" if role == "boy" else "boy"


func _ready() -> void:
	_build_sky_and_lighting()
	_build_lowpoly_terrain()
	_build_stream_and_bridge()
	_build_lowpoly_forest_obstacles()
	_build_interactives()
	_build_player_and_camera()
	_build_hud()

	var start_msg := (
		"欢迎来到 3D 微光森林！按 WASD 奔跑、Space 跳跃、E/H 召唤蝴蝶指路。先去点亮「发光蘑菇」吧~"
		if role == "boy"
		else "欢迎来到 3D 微光森林！按 WASD 奔跑、Space 跳跃、E/H 召唤蝴蝶指路。先去点亮「发光蘑菇」吧~"
	)
	_show_toast(start_msg, 6.0)


func _mat(col: Color, roughness: float = 0.85, emission: Color = Color.BLACK, emit_energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = roughness
	m.metallic_specular = 0.14 if roughness > 0.45 else 0.36
	if emit_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emit_energy
	return m


func _build_sky_and_lighting() -> void:
	# Cool twilight forest atmosphere + warm golden dusk sun + cool moonlight rim (cold/warm contrast)
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.09, 0.20, 0.36)
	sky_mat.sky_horizon_color = Color(0.28, 0.44, 0.56)
	sky_mat.ground_bottom_color = Color(0.08, 0.16, 0.15)
	sky_mat.ground_horizon_color = Color(0.20, 0.36, 0.28)
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.24, 0.34, 0.46)
	env.ambient_light_energy = 0.46
	env.fog_enabled = true
	env.fog_light_color = Color(0.16, 0.30, 0.38)
	env.fog_density = 0.012

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.86, 0.66)
	sun.light_energy = 0.68
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-52, -32, 0)
	add_child(sun)

	var cool_rim := DirectionalLight3D.new()
	cool_rim.light_color = Color(0.36, 0.62, 0.92)
	cool_rim.light_energy = 0.26
	cool_rim.rotation_degrees = Vector3(-30, 148, 0)
	add_child(cool_rim)


func _build_lowpoly_terrain() -> void:
	# Main 3D grassy island slab with procedural fBm moss, sunlit clover & shadow pockets
	var ground_body := StaticBody3D.new()
	var g_col := CollisionShape3D.new()
	var g_box := BoxShape3D.new()
	g_box.size = Vector3(HALF_W * 2.0, 1.0, HALF_D * 2.0)
	g_col.shape = g_box
	g_col.position = Vector3(0, -0.5, 0)
	ground_body.add_child(g_col)

	var grass_mesh := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(HALF_W * 2.0, 0.5, HALF_D * 2.0)
	grass_mesh.mesh = gm
	grass_mesh.material_override = VisualPolish.make_terrain_mat(
		Color(0.19, 0.43, 0.24), Color(0.36, 0.56, 0.27), Color(0.08, 0.20, 0.22), 0.48
	)
	grass_mesh.position = Vector3(0, -0.25, 0)
	ground_body.add_child(grass_mesh)

	var dirt_mesh := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(HALF_W * 2.0 - 0.1, 1.8, HALF_D * 2.0 - 0.1)
	dirt_mesh.mesh = dm
	dirt_mesh.material_override = VisualPolish.make_organic_mat(Color(0.42, 0.28, 0.18), 1.2, 0.80, 0.98)
	dirt_mesh.position = Vector3(0, -1.4, 0)
	ground_body.add_child(dirt_mesh)
	add_child(ground_body)

	# Winding 3D dirt footpath stones with pebble roughness breakup
	var path_nodes := [
		START_POS, Vector3(-14.5, 0, 8.0), Vector3(-11.5, 0, 6.0), Vector3(-8.5, 0, 3.8),
		Vector3(-12.0, 0, -2.0), Vector3(-10.0, 0, -8.5), Vector3(-6.2, 0, -9.2),
		Vector3(-2.0, 0, -4.0), Vector3(0.5, 0, 3.5), Vector3(0.5, 0, 8.5),
		Vector3(3.2, 0, 5.8), Vector3(5.2, 0, 2.2), BRIDGE_POS,
		Vector3(11.5, 0, -1.5), Vector3(13.5, 0, -2.5), Vector3(16.0, 0, -6.0), GOAL_POS
	]
	var path_mat := VisualPolish.make_organic_mat(Color(0.68, 0.56, 0.38), 1.9, 0.78, 0.97)
	for i in range(path_nodes.size() - 1):
		var a: Vector3 = path_nodes[i]
		var b: Vector3 = path_nodes[i + 1]
		var seg := a.lerp(b, 0.5)
		var dist := a.distance_to(b)
		var p_mesh := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 1.15
		pm.bottom_radius = 1.25
		pm.height = 0.06
		pm.radial_segments = 8
		p_mesh.mesh = pm
		p_mesh.material_override = path_mat
		p_mesh.position = Vector3(seg.x, 0.02, seg.z)
		p_mesh.scale = Vector3(1.0, 1.0, max(1.0, dist * 0.46))
		add_child(p_mesh)
		p_mesh.look_at(Vector3(b.x, 0.02, b.z), Vector3.UP)

	# Low-poly decorative grass hills & wildflowers
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var fl_mat1 := _mat(Color(1.0, 0.88, 0.35))
	var fl_mat2 := _mat(Color(1.0, 0.58, 0.78))
	for i in range(45):
		var fx := rng.randf_range(-HALF_W + 2.0, HALF_W - 2.0)
		var fz := rng.randf_range(-HALF_D + 2.0, HALF_D - 2.0)
		if abs(fx - 7.5) < 2.2:
			continue
		var fl := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = 0.16
		fm.height = 0.18
		fm.radial_segments = 6
		fm.rings = 3
		fl.mesh = fm
		fl.material_override = fl_mat1 if i % 2 == 0 else fl_mat2
		fl.position = Vector3(fx, 0.08, fz)
		add_child(fl)


func _build_stream_and_bridge() -> void:
	# 3D Stream channel at X = 7.5 with animated shader caustics & shoreline foam!
	var water := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(3.2, 0.04, HALF_D * 2.0)
	water.mesh = wm
	water.material_override = VisualPolish.make_water_mat(
		Color(0.05, 0.26, 0.42), Color(0.15, 0.65, 0.74), Vector2(0.0, 1.0), 0.58
	)
	water.position = Vector3(7.5, 0.015, 0.0)
	add_child(water)

	# Animated 3D water ripples ("微波粼粼"), skipping directly under bridge planks
	var rip_mat := _mat(Color(0.82, 0.96, 1.0), 0.1, Color(0.6, 0.9, 1.0), 0.4)
	for i in range(16):
		var rz := -HALF_D + float(i) * 2.0
		if absf(rz) < 2.3:
			continue
		var r := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.85, 0.016, 0.24)
		r.mesh = rm
		r.material_override = rip_mat
		var rx := 7.5 + sin(float(i)) * 0.7
		r.position = Vector3(rx, 0.042, rz)
		add_child(r)
		water_ripples.append({"node": r, "base_x": rx, "phase": float(i) * 0.8})

	# Stream colliders leaving exact bridge gap (Z in [-1.9, 1.9])
	_add_3d_box_collider(Vector3(7.5, 1.0, -9.0), Vector3(3.0, 2.5, 14.2))
	_add_3d_box_collider(Vector3(7.5, 1.0, 9.0), Vector3(3.0, 2.5, 14.2))

	# 3D Arched Wooden Bridge at BRIDGE_POS clearly ABOVE water with smooth sloped ramps!
	var bridge := Node3D.new()
	bridge.position = BRIDGE_POS
	add_child(bridge)

	var wood_mat := _mat(Color(0.70, 0.48, 0.26), 0.88)
	var post_mat := _mat(Color(0.46, 0.29, 0.15), 0.90)

	var deck_body := StaticBody3D.new()
	var d_col := CollisionShape3D.new()
	var d_box := BoxShape3D.new()
	d_box.size = Vector3(3.8, 0.14, 3.8)
	d_col.shape = d_box
	d_col.position = Vector3(0, 0.08, 0)
	deck_body.add_child(d_col)
	# Gentle sloped entry/exit ramps so player walks smoothly onto bridge with zero snagging!
	for side in [-1.0, 1.0]:
		var r_col := CollisionShape3D.new()
		var r_box := BoxShape3D.new()
		r_box.size = Vector3(1.1, 0.14, 3.8)
		r_col.shape = r_box
		r_col.position = Vector3(side * 2.25, 0.01, 0)
		r_col.rotation_degrees = Vector3(0, 0, -side * 9.0)
		deck_body.add_child(r_col)
	bridge.add_child(deck_body)

	# Longitudinal dark support beams beneath planks (still well above water top 0.035!)
	for bz in [-1.35, 1.35]:
		var beam := MeshInstance3D.new()
		var bmm := BoxMesh.new()
		bmm.size = Vector3(4.3, 0.08, 0.22)
		beam.mesh = bmm
		beam.material_override = post_mat
		beam.position = Vector3(0, 0.08, bz)
		bridge.add_child(beam)

	# Outer abutment planks intact; center 3 planks start sunken/broken & entangled in blossom vines!
	for px_end in [-1.6, 1.6]:
		var plank := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.72, 0.09, 3.8)
		plank.mesh = pm
		plank.material_override = wood_mat
		plank.position = Vector3(float(px_end), 0.11, 0)
		bridge.add_child(plank)

	for pz in [-1.8, 1.8]:
		for px in [-1.7, 1.7]:
			var post := MeshInstance3D.new()
			var psm := BoxMesh.new()
			psm.size = Vector3(0.24, 0.92, 0.24)
			post.mesh = psm
			post.material_override = post_mat
			post.position = Vector3(px, 0.56, pz)
			bridge.add_child(post)
		var rail := MeshInstance3D.new()
		var rlm := BoxMesh.new()
		rlm.size = Vector3(3.6, 0.12, 0.14)
		rail.mesh = rlm
		rail.material_override = wood_mat
		rail.position = Vector3(0, 0.86, pz)
		bridge.add_child(rail)

	gate_data = ObstacleBuilder.build_level1_broken_bridge_vine(self, BRIDGE_POS)


func _build_lowpoly_forest_obstacles() -> void:
	# World borders
	_add_3d_box_collider(Vector3(0, 1.5, -HALF_D - 0.5), Vector3(HALF_W * 2.0, 4.0, 1.0))
	_add_3d_box_collider(Vector3(0, 1.5, HALF_D + 0.5), Vector3(HALF_W * 2.0, 4.0, 1.0))
	_add_3d_box_collider(Vector3(-HALF_W - 0.5, 1.5, 0), Vector3(1.0, 4.0, HALF_D * 2.0))
	_add_3d_box_collider(Vector3(HALF_W + 0.5, 1.5, 0), Vector3(1.0, 4.0, HALF_D * 2.0))

	# Low-poly stylized Pine & Round Trees of varied scales
	var trees := [
		[Vector3(-20.5, 0, -11.5), 1.35, true], [Vector3(-13.5, 0, -12.5), 1.15, false],
		[Vector3(-3.0, 0, -12.0), 1.40, true], [Vector3(3.5, 0, -11.5), 1.10, false],
		[Vector3(-20.5, 0, 2.0), 1.25, true], [Vector3(-14.5, 0, 1.5), 0.95, false],
		[Vector3(-4.5, 0, 1.0), 1.30, true], [Vector3(-3.0, 0, 11.5), 1.35, false],
		[Vector3(3.8, 0, 12.0), 1.15, true], [Vector3(12.0, 0, -12.0), 1.30, true],
		[Vector3(20.5, 0, -3.5), 1.40, false], [Vector3(16.0, 0, 6.5), 1.25, true],
		[Vector3(11.5, 0, 11.0), 1.05, false], [Vector3(20.5, 0, 11.5), 1.20, true],
	]
	for t in trees:
		_spawn_lowpoly_tree(t[0], t[1], t[2])

	# Low-poly Berry Bushes
	var bushes := [
		[Vector3(-21.0, 0, 7.5), 1.15], [Vector3(-14.0, 0, 12.8), 1.25],
		[Vector3(-7.5, 0, 9.8), 0.90], [Vector3(-14.5, 0, -7.0), 0.85],
		[Vector3(1.0, 0, -7.5), 1.10], [Vector3(4.5, 0, -4.0), 1.05],
		[Vector3(12.0, 0, 4.0), 1.15], [Vector3(20.5, 0, -12.5), 1.00],
	]
	for b in bushes:
		_spawn_lowpoly_bush(b[0], b[1])

	# Low-poly Mossy Boulders
	var rocks := [
		[Vector3(-7.0, 0, -3.2), 1.15], [Vector3(-3.2, 0, 4.5), 0.90],
		[Vector3(3.5, 0, -1.5), 1.05], [Vector3(-11.0, 0, 12.2), 1.25],
		[Vector3(12.2, 0, -7.5), 0.95], [Vector3(17.5, 0, 1.5), 1.20],
	]
	for r in rocks:
		_spawn_lowpoly_rock(r[0], r[1])


func _spawn_lowpoly_tree(pos: Vector3, sc: float, is_pine: bool) -> void:
	var tree := Node3D.new()
	tree.position = pos
	# Break mechanical symmetry with subtle organic yaw & non-uniform proportion variation
	var asym := 0.94 + 0.12 * absf(sin(pos.x * 1.3 + pos.z * 0.9))
	tree.scale = Vector3(sc * asym, sc * (2.0 - asym), sc)
	tree.rotation.y = fmod(absf(pos.x * 2.1 + pos.z * 3.7), TAU)

	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.28
	tm.bottom_radius = 0.42
	tm.height = 1.9
	tm.radial_segments = 6
	trunk.mesh = tm
	trunk.material_override = VisualPolish.make_organic_mat(Color(0.46, 0.30, 0.19), 2.4, 0.78, 0.96)
	trunk.position = Vector3(0, 0.95, 0)
	tree.add_child(trunk)

	var canopy := Node3D.new()
	canopy.position = Vector3(0, 1.8, 0)
	tree.add_child(canopy)

	if is_pine:
		for i in range(2):
			var cone := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = 1.45 - i * 0.35
			cm.height = 1.8
			cm.radial_segments = 7
			cone.mesh = cm
			cone.material_override = VisualPolish.make_organic_mat(
				Color(0.15, 0.48, 0.26) if i == 0 else Color(0.24, 0.64, 0.32), 1.5, 0.68, 0.92
			)
			cone.position = Vector3(0, 0.7 + i * 1.0, 0)
			canopy.add_child(cone)
	else:
		for lobe in [
			[Vector3(0, 0.85, 0), Vector3(1.0, 1.0, 1.0)],
			[Vector3(-0.48, 0.55, 0.22), Vector3(0.68, 0.62, 0.68)],
			[Vector3(0.45, 0.62, -0.20), Vector3(0.62, 0.58, 0.64)],
		]:
			var crown := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 1.32
			sm.height = 2.05
			sm.radial_segments = 7
			sm.rings = 4
			crown.mesh = sm
			crown.material_override = VisualPolish.make_organic_mat(Color(0.22, 0.58, 0.30), 1.4, 0.66, 0.92)
			crown.position = lobe[0]
			crown.scale = lobe[1]
			canopy.add_child(crown)

	add_child(tree)
	sway_nodes.append({"node": canopy, "phase": pos.x * 0.4 + pos.z * 0.3, "amp": 0.04})

	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.55 * sc
	cyl.height = 2.2
	col.shape = cyl
	col.position = Vector3(0, 1.1, 0)
	body.add_child(col)
	add_child(body)


func _spawn_lowpoly_bush(pos: Vector3, sc: float) -> void:
	var bush := Node3D.new()
	bush.position = pos
	bush.scale = Vector3.ONE * sc
	bush.rotation.y = pos.x * 1.7 + pos.z * 0.9

	var bush_mat := VisualPolish.make_organic_mat(Color(0.24, 0.62, 0.32), 1.8, 0.66, 0.92)
	for lobe in [
		[Vector3(0, 0.44, 0), Vector3(1.0, 0.88, 0.96)],
		[Vector3(-0.38, 0.32, 0.18), Vector3(0.68, 0.65, 0.72)],
		[Vector3(0.36, 0.35, -0.16), Vector3(0.64, 0.68, 0.66)],
	]:
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.82
		sm.height = 1.15
		sm.radial_segments = 7
		sm.rings = 4
		m.mesh = sm
		m.material_override = bush_mat
		m.position = lobe[0]
		m.scale = lobe[1]
		bush.add_child(m)

	add_child(bush)
	sway_nodes.append({"node": bush, "phase": pos.x * 0.5, "amp": 0.035})

	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.80 * sc
	col.shape = sph
	col.position = Vector3(0, 0.5, 0)
	body.add_child(col)
	add_child(body)


func _spawn_lowpoly_rock(pos: Vector3, sc: float) -> void:
	var rock := Node3D.new()
	rock.position = pos
	rock.scale = Vector3(sc * 1.12, sc * 0.86, sc * 0.96)
	rock.rotation.y = pos.x * 2.3 - pos.z * 1.1

	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.85
	sm.height = 1.05
	sm.radial_segments = 5
	sm.rings = 3
	m.mesh = sm
	m.material_override = VisualPolish.make_organic_mat(Color(0.48, 0.53, 0.60), 2.2, 0.76, 0.98)
	m.position = Vector3(0, 0.35, 0)
	rock.add_child(m)
	add_child(rock)

	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.80 * sc
	col.shape = sph
	col.position = Vector3(0, 0.4, 0)
	body.add_child(col)
	add_child(body)


func _add_3d_box_collider(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)
	add_child(body)


func _build_interactives() -> void:
	# 1. 3D Low-Poly Glowing Mushrooms
	for cfg in MUSHROOM_CONFIGS:
		var m := Node3D.new()
		m.position = cfg["pos"]

		var stem := MeshInstance3D.new()
		var stm := CylinderMesh.new()
		stm.top_radius = 0.18
		stm.bottom_radius = 0.24
		stm.height = 0.65
		stm.radial_segments = 7
		stem.mesh = stm
		stem.material_override = _mat(Color(0.95, 0.90, 0.80))
		stem.position = Vector3(0, 0.32, 0)
		m.add_child(stem)

		var cap := MeshInstance3D.new()
		var cm := SphereMesh.new()
		cm.radius = 0.62
		cm.height = 0.65
		cm.radial_segments = 8
		cm.rings = 4
		cap.mesh = cm
		var cap_mat := _mat(Color(0.72, 0.48, 0.84))
		cap.material_override = cap_mat
		cap.position = Vector3(0, 0.72, 0)
		m.add_child(cap)

		var light := OmniLight3D.new()
		light.light_color = Color(0.45, 1.0, 0.80)
		light.light_energy = 0.2
		light.omni_range = 4.2
		light.position = Vector3(0, 0.9, 0)
		m.add_child(light)

		add_child(m)
		sway_nodes.append({"node": m, "phase": cfg["pos"].x * 0.4, "amp": 0.03})
		mushroom_nodes.append({
			"pos": cfg["pos"], "reveal": cfg["reveal"],
			"mat": cap_mat, "light": light, "lit": false
		})

	# 2. Hidden 3D Raised Stone Note Pads (with center 3D musical note + stand-up animation & chime!)
	var freqs := [523.25, 659.25]  # C5, E5
	for i in range(PAD_POSITIONS.size()):
		var pad := NotePad3D.create(PAD_POSITIONS[i], freqs[i])
		pad.visible = false
		add_child(pad)
		pad_nodes.append({"node": pad, "pos": PAD_POSITIONS[i], "revealed": false, "lit": false})

	# 3. Hidden Signature Keepsake (3D Rose-Gold Pink Crystal Swan Necklace or Earbuds Case!)
	var kind := "swan_necklace" if role == "boy" else "earbuds_case"
	keepsake_node = Keepsake3D.create(kind)
	keepsake_node.position = KEEPSAKE_POS
	keepsake_node.visible = false
	add_child(keepsake_node)

	# 4. Sculpted 3D Cute Sleeping Hedgehog Easter Egg (spiky back, tan face, nose & paws!)
	egg_node = Node3D.new()
	egg_node.position = EGG_POS
	var h_spine := _mat(Color(0.46, 0.32, 0.22), 0.90)
	var h_face := _mat(Color(0.92, 0.80, 0.66), 0.78)
	var h_dark := _mat(Color(0.10, 0.08, 0.08), 0.25)

	var h_body := MeshInstance3D.new()
	var hbm := SphereMesh.new()
	hbm.radius = 0.36; hbm.height = 0.56
	h_body.mesh = hbm; h_body.material_override = h_spine
	h_body.position = Vector3(0, 0.26, -0.05); h_body.scale = Vector3(1.05, 0.95, 1.2)
	egg_node.add_child(h_body)

	var h_snout := MeshInstance3D.new()
	var hsm := SphereMesh.new()
	hsm.radius = 0.24; hsm.height = 0.34
	h_snout.mesh = hsm; h_snout.material_override = h_face
	h_snout.position = Vector3(0, 0.22, 0.30); h_snout.scale = Vector3(0.92, 0.85, 1.15)
	egg_node.add_child(h_snout)

	# Tiny nose & cute beady eyes
	var h_nose := MeshInstance3D.new()
	var hnm := SphereMesh.new()
	hnm.radius = 0.055; hnm.height = 0.11
	h_nose.mesh = hnm; h_nose.material_override = h_dark
	h_nose.position = Vector3(0, 0.23, 0.54)
	egg_node.add_child(h_nose)
	for ex in [-0.11, 0.11]:
		var eye := MeshInstance3D.new()
		var eym := SphereMesh.new()
		eym.radius = 0.04; eym.height = 0.08
		eye.mesh = eym; eye.material_override = h_dark
		eye.position = Vector3(ex, 0.28, 0.44)
		egg_node.add_child(eye)

	# Crown of tiny spiky quills along its back!
	for i in range(12):
		var a := float(i) / 12.0 * TAU
		var sp := MeshInstance3D.new()
		var spm := CylinderMesh.new()
		spm.top_radius = 0.0; spm.bottom_radius = 0.065; spm.height = 0.24; spm.radial_segments = 5
		sp.mesh = spm; sp.material_override = h_spine
		sp.position = Vector3(cos(a) * 0.28, 0.42 + sin(a * 2.0) * 0.04, -0.06 + sin(a) * 0.28)
		sp.rotation_degrees = Vector3(sin(a) * 38.0, 0, -cos(a) * 38.0)
		egg_node.add_child(sp)
	egg_node.rotation.y = 0.65
	add_child(egg_node)

	# 5. Goal: Partner 3D Chibi waiting under big tree!
	partner_node = Node3D.new()
	partner_node.position = GOAL_POS
	_spawn_lowpoly_tree(GOAL_POS + Vector3(1.8, 0, -1.5), 1.45, false)

	partner_model = Chibi3D.create(partner_role)
	partner_model.scale = Vector3.ONE * 0.92
	partner_model.rotation.y = -PI * 0.65
	partner_node.add_child(partner_model)

	var p_light := OmniLight3D.new()
	p_light.light_color = Color(1.0, 0.78, 0.88)
	p_light.light_energy = 1.05
	p_light.omni_range = 6.0
	p_light.position = Vector3(0, 1.8, 0)
	partner_node.add_child(p_light)
	add_child(partner_node)


func _build_player_and_camera() -> void:
	player = PlayerController.new()
	player.setup(role)
	player.position = START_POS
	player.moved_step.connect(_on_player_step)
	player.landed.connect(_on_player_landed)
	add_child(player)

	camera = Camera3D.new()
	camera.fov = 45.0
	add_child(camera)
	camera.look_at_from_position(START_POS + Vector3(0, 6.8, 8.2), START_POS + Vector3(0, 1.1, 0), Vector3.UP)


func _build_hud() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	var hud_parts := GameUI.build_level_hud(ui, Color(0.45, 0.95, 0.76), _open_settings)
	hud_label = hud_parts["hud_label"]
	toast_panel = hud_parts["toast_panel"]
	toast_label = hud_parts["toast_label"]

	minimap = MiniMap.new()
	minimap.configure(HALF_W, HALF_D, GOAL_POS)
	minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.offset_left = -168; minimap.offset_top = -168
	minimap.offset_right = -16; minimap.offset_bottom = -16
	hud_parts["root"].add_child(minimap)

	_refresh_hud(false)


func _refresh_hud(animate: bool = true) -> void:
	if hud_label:
		hud_label.text = "第 1 关 · 微光森林    ◆ 音符石阶 %d/2    ◆ 发光蘑菇 %d/4    ◆ 信物 %s" % [
			lit_pads, lit_mushrooms, "已拾取" if keepsake_found else "寻觅中"
		]
		if animate:
			GameUI.pulse_hud(hud_label)


func _show_toast(msg: String, duration: float = 4.2) -> void:
	toast_label.text = msg
	toast_timer = duration
	GameUI.animate_toast_in(toast_panel)


func _on_player_landed(pos: Vector3, impact: float) -> void:
	GameJuice.spawn_splash(self, pos, Color(0.84, 0.94, 0.80), int(5 + 6 * impact), 0.55 * impact, false)


func _on_player_step(pos: Vector3) -> void:
	var puff := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.20
	sm.radial_segments = 6
	puff.mesh = sm
	puff.material_override = _mat(Color(0.92, 0.94, 0.86, 0.6))
	puff.position = pos + Vector3(0, 0.1, 0)
	add_child(puff)
	var tw := create_tween()
	tw.tween_property(puff, "scale", Vector3.ONE * 1.8, 0.35)
	tw.tween_callback(puff.queue_free)


func _spawn_burst(origin: Vector3, col: Color, count: int = 12) -> void:
	GameJuice.spawn_splash(self, origin, col, count, 1.0, true)


func _open_settings() -> void:
	var sui := SettingsUI.open(self, true)
	sui.restart_requested.connect(func(): restart_level.emit())
	sui.back_to_menu_requested.connect(func(): back_to_select.emit())


func _unhandled_input(event: InputEvent) -> void:
	if cleared:
		return
	if event.is_action_pressed("telepathy"):
		_spawn_butterfly()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_open_settings()
		elif event.keycode == KEY_R:
			restart_level.emit()
		elif event.keycode == KEY_M:
			var m := SoundFX.toggle_mute()
			_show_toast("音效与背景音乐已静音" if m else "音效与背景音乐已开启~", 2.2)


func _spawn_butterfly() -> void:
	if butterfly and is_instance_valid(butterfly):
		butterfly.queue_free()
	butterfly = Butterfly3D.create(1.18, 14.0)
	butterfly.position = player.position + Vector3(0, 1.8, 0)
	butterfly_wing_l = null
	butterfly_wing_r = null
	add_child(butterfly)

	# Smart stage-aware butterfly guide: revealed pad -> unlit mushroom -> partner!
	var target := GOAL_POS
	var hint_msg := "微光蝴蝶正朝着TA的方向飞去~"
	var best_d := 9999.0
	var found_stage := false
	for pdata in pad_nodes:
		if pdata["revealed"] and not pdata["lit"]:
			var d := player.position.distance_to(pdata["pos"])
			if d < best_d:
				best_d = d; target = pdata["pos"]; found_stage = true
				hint_msg = "微光蝴蝶正飞向显现的「音符石阶」~"
	if not found_stage and not gate_open:
		for m in mushroom_nodes:
			if not m["lit"] and m["reveal"] in ["pad0", "pad1"]:
				var d := player.position.distance_to(m["pos"])
				if d < best_d:
					best_d = d; target = m["pos"]; found_stage = true
					hint_msg = "微光蝴蝶正飞向未点亮的「发光蘑菇」~"
	if not found_stage and keepsake_revealed and not keepsake_found:
		target = KEEPSAKE_POS
		hint_msg = "微光蝴蝶正飞向闪闪发亮的「专属信物」~"

	var dir := (target - player.position)
	dir.y = 0.0
	butterfly_vel = dir.normalized() * 6.8
	butterfly.look_at(butterfly.position + butterfly_vel, Vector3.UP)
	butterfly_life = 2.8
	_show_toast(hint_msg, 2.8)


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001

	for item in sway_nodes:
		item["node"].rotation.z = sin(t * 2.0 + item["phase"]) * item["amp"]

	for rip in water_ripples:
		var rn: Node3D = rip["node"]
		rn.position.z += 1.4 * delta
		if rn.position.z > HALF_D:
			rn.position.z -= HALF_D * 2.0
		rn.position.x = rip["base_x"] + sin(t * 2.4 + rip["phase"]) * 0.15

	# Smooth 3rd-person camera follow + trauma shake offset
	if player and camera:
		var target_cam := player.position + Vector3(0, 6.8, 8.2)
		camera.position = camera.position.lerp(target_cam, min(1.0, delta * 6.5))
		camera.look_at(player.position + Vector3(0, 1.1, 0), Vector3.UP)
		GameJuice.apply_camera_shake(camera)

	if partner_model:
		partner_model.update_anim(false, false, delta)

	if cleared:
		return

	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0:
			toast_panel.visible = false

	if butterfly and is_instance_valid(butterfly):
		butterfly.position += butterfly_vel * delta
		butterfly.position.y = 1.85 + sin(t * 14.0) * 0.25
		if butterfly_wing_l and butterfly_wing_r:
			var flap := sin(t * 24.0) * 0.72
			butterfly_wing_l.rotation.z = flap
			butterfly_wing_r.rotation.z = -flap
		butterfly_life -= delta
		if butterfly_life <= 0.0:
			butterfly.queue_free()
			butterfly = null

	var ppos := Vector3(player.position.x, 0.0, player.position.z)

	if minimap and player:
		minimap.refresh(player.position, mushroom_nodes, pad_nodes, keepsake_revealed and not keepsake_found, KEEPSAKE_POS, [] if gate_open else [BRIDGE_POS])

	# Mushrooms -> Soft Glow + Hitstop + Trauma Shake + Reveal Hidden Objects!
	for m in mushroom_nodes:
		if not m["lit"] and ppos.distance_to(m["pos"]) < 1.9:
			m["lit"] = true
			lit_mushrooms += 1
			SoundFX.play("mushroom", -6.0)
			GameJuice.hitstop(0.038, 0.10)
			GameJuice.add_trauma(0.24)
			_spawn_burst(m["pos"], Color(0.45, 1.0, 0.82), 14)
			var mmat: StandardMaterial3D = m["mat"]
			mmat.albedo_color = Color(0.45, 0.96, 0.80)
			mmat.emission_enabled = true
			mmat.emission = Color(0.35, 0.95, 0.75)
			mmat.emission_energy_multiplier = 0.65
			create_tween().tween_property(m["light"], "light_energy", 1.15, 0.5)
			_refresh_hud()

			var rev: String = m["reveal"]
			if rev == "keepsake" and not keepsake_revealed:
				keepsake_revealed = true
				keepsake_node.visible = true
				_show_toast("发光蘑菇照亮了草丛！一枚隐藏的「信物」显现出来了~", 4.2)
			elif rev == "pad0" and not pad_nodes[0]["revealed"]:
				pad_nodes[0]["revealed"] = true
				pad_nodes[0]["node"].visible = true
				_show_toast("微光照亮了西北角！第一块隐藏的「音符石阶」显现了！", 4.2)
			elif rev == "pad1" and not pad_nodes[1]["revealed"]:
				pad_nodes[1]["revealed"] = true
				pad_nodes[1]["node"].visible = true
				_show_toast("微光照亮了南岸！第二块隐藏的「音符石阶」显现了！", 4.2)
			else:
				_show_toast("点亮了小溪东岸的发光蘑菇！TA就在前面大树旁等你~", 3.5)

	# Revealed 3D Stone Note Pads
	for pdata in pad_nodes:
		if pdata["revealed"] and not pdata["lit"] and ppos.distance_to(pdata["pos"]) < 1.35:
			pdata["lit"] = true
			lit_pads += 1
			pdata["node"].activate()
			_refresh_hud()
			if lit_pads < 2:
				_show_toast("踩亮了音符石阶 (1/2)！再去另一处点亮发光蘑菇找第 2 块吧~", 4.0)
			else:
				gate_open = true
				SoundFX.play("gate", -5.0)
				GameJuice.hitstop(0.075, 0.06)
				GameJuice.add_trauma(0.48)
				_spawn_burst(BRIDGE_POS, Color(1.0, 0.72, 0.86), 24)
				ObstacleBuilder.unlock(gate_data)
				_show_toast("两块音符石阶共鸣！缠绕的花藤散开，沉入溪底的断桥木板重新升起拼合了！", 4.5)

	# Revealed Keepsake
	if keepsake_revealed and not keepsake_found and ppos.distance_to(KEEPSAKE_POS) < 1.35:
		keepsake_found = true
		SoundFX.play("keepsake", -5.0)
		GameJuice.hitstop(0.055, 0.08)
		GameJuice.add_trauma(0.32)
		_spawn_burst(KEEPSAKE_POS, Color(1.0, 0.68, 0.78) if role == "boy" else Color(1.0, 0.90, 0.35), 18)
		keepsake_node.queue_free()
		_refresh_hud()
		var kmsg := (
			"捡到了「粉色水晶天鹅项链」！这不是她一直戴着的玫瑰金天鹅项链吗？她一定就在前面！"
			if role == "boy"
			else "捡到了「无线耳机小盒」！里面还留着余温，戴透明眼镜的他肯定就在附近！"
		)
		_show_toast(kmsg, 5.0)

	# Hedgehog Easter Egg
	if not egg_visited and ppos.distance_to(EGG_POS) < 1.5:
		egg_visited = true
		SoundFX.play("mushroom", -8.0)
		var emsg := (
			"瞌睡小刺猬揉揉眼睛说：『刚才有个双马尾、戴金丝眼镜的女生路过，还夸我可爱呢~』"
			if role == "boy"
			else "瞌睡小刺猬揉揉眼睛说：『刚才有个戴透明方框眼镜的男生路过，还问我有没有看到他的另一半呢~』"
		)
		_show_toast(emsg, 5.5)

	# Goal Reunion (1.45s celebration pause before Victory Folio!)
	if ppos.distance_to(GOAL_POS) < 1.7:
		cleared = true
		player.can_move = false
		SoundFX.play("victory", -4.0)
		GameJuice.hitstop(0.085, 0.08)
		GameJuice.add_trauma(0.42)
		player.model.trigger_celebrate()
		partner_model.trigger_celebrate()
		_spawn_burst(GOAL_POS, Color(1.0, 0.56, 0.78), 28)
		_show_toast("终于找到你啦！！", 2.5)
		var stats := {
			"level": 1,
			"role": role,
			"mushrooms": lit_mushrooms,
			"keepsake": keepsake_found,
			"egg": egg_visited,
		}
		var tw := create_tween()
		tw.tween_interval(1.45)
		tw.tween_callback(func(): level_cleared.emit(stats))
