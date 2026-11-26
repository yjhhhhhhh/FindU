extends Node3D
class_name Level3Scene

signal level_cleared(stats: Dictionary)
signal back_to_select
signal restart_level

# S-Curve Autumn Maple Canyon: NW Start -> North Trail -> East Gate -> Central Flame Valley -> West Gate -> South Trail -> SE Park Bench!
const HALF_W := 28.0
const HALF_D := 20.0

const START_POS := Vector3(-23.0, 0.0, -13.5)
const GATE1_POS := Vector3(22.0, 0.0, -6.5)
const GATE2_POS := Vector3(-22.0, 0.0, 6.5)
const BENCH_POS := Vector3(17.5, 0.0, 13.0)

const MUSHROOM_CONFIGS := [
	{"pos": Vector3(-8.0, 0.0, -13.5), "reveal": "pad0"},
	{"pos": Vector3(10.0, 0.0, 0.0), "reveal": "milktea"},
	{"pos": Vector3(-11.0, 0.0, 0.8), "reveal": "pad1"},
	{"pos": Vector3(-4.0, 0.0, 13.0), "reveal": "bench_hint"},
]

const PAD_POSITIONS := [
	Vector3(6.5, 0.0, -13.5),
	Vector3(-18.5, 0.0, 1.0),
]
const MILKTEA_POS := Vector3(1.5, 0.0, -1.2)

const FLAME_POSITIONS := [
	Vector3(14.5, 0.0, -2.5),
	Vector3(6.0, 0.0, 2.8),
	Vector3(-1.5, 0.0, -3.2),
	Vector3(-6.5, 0.0, 3.0),
	Vector3(-14.5, 0.0, -2.8),
	Vector3(6.5, 0.0, 11.0),
	Vector3(11.5, 0.0, 15.8),
]

var role: String = "boy"
var partner_role: String = "girl"

var player: PlayerController
var camera: Camera3D

var sway_nodes: Array[Dictionary] = []
var flames: Array[Dictionary] = []
var embers: Array[Dictionary] = []
var mushroom_nodes: Array[Dictionary] = []
var pad_nodes: Array[Dictionary] = []

var lit_mushrooms: int = 0
var pads_lit: int = 0
var milk_tea_found: bool = false
var burn_count: int = 0
var char_timer: float = 0.0
var burn_cooldown: float = 0.0

var gate1_data: Dictionary = {}
var gate1_open: bool = false

var gate2_data: Dictionary = {}
var gate2_open: bool = false

var milk_tea_node: Node3D
var milk_tea_revealed: bool = false

var partner_model: Chibi3D = null
var bench_warn_no_tea: bool = false
var cleared: bool = false

# Bench Coaxing Mini-Game State
var bench_mode: bool = false
var player_seat_x: float = -2.0
var player_target_x: float = -2.0
var partner_seat_x: float = 0.0
var partner_target_x: float = 0.0
var angry_scoot_t: float = 0.0
var look_state: String = "AWAY"  # AWAY, WARN, WATCH
var look_timer: float = 2.2
var catch_cooldown: float = 0.0
var alert_indicator: Node3D = null
var alert_mat: StandardMaterial3D = null
var bench_status_lbl: Label

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


func init_role(p_role: String) -> void:
	role = p_role
	partner_role = "girl" if role == "boy" else "boy"


func _ready() -> void:
	_build_sky_and_lighting()
	_build_autumn_canyon_terrain()
	_build_ridge_barriers_and_gates()
	_build_flames()
	_build_interactives()
	_build_bench_and_partner()
	_build_player_and_camera()
	_build_hud()

	_show_toast("第3关·炽热秋枫林！你惹TA生气啦！快绕过火焰先找到「珍珠奶茶」，再去长凳哄TA开心~", 6.5)


func _mat(col: Color, roughness: float = 0.85, emission: Color = Color.BLACK, emit_energy: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.roughness = roughness
	m.metallic_specular = 0.14 if roughness > 0.45 else 0.36
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emit_energy
	return m


func _build_sky_and_lighting() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.18, 0.12, 0.24)
	sky_mat.sky_horizon_color = Color(0.64, 0.32, 0.22)
	sky_mat.ground_bottom_color = Color(0.12, 0.09, 0.08)
	sky_mat.ground_horizon_color = Color(0.32, 0.20, 0.13)
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.26, 0.30)
	env.ambient_light_energy = 0.46
	env.fog_enabled = true
	env.fog_light_color = Color(0.38, 0.22, 0.22)
	env.fog_density = 0.011

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.78, 0.56)
	sun.light_energy = 0.66
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, -35, 0)
	add_child(sun)

	var cool_rim := DirectionalLight3D.new()
	cool_rim.light_color = Color(0.40, 0.56, 0.88)
	cool_rim.light_energy = 0.26
	cool_rim.rotation_degrees = Vector3(-30, 145, 0)
	add_child(cool_rim)


func _build_autumn_canyon_terrain() -> void:
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
		Color(0.36, 0.28, 0.16), Color(0.56, 0.38, 0.18), Color(0.16, 0.14, 0.18), 0.48
	)
	grass_mesh.position = Vector3(0, -0.25, 0)
	ground_body.add_child(grass_mesh)

	var dirt_mesh := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(HALF_W * 2.0 - 0.1, 1.8, HALF_D * 2.0 - 0.1)
	dirt_mesh.mesh = dm
	dirt_mesh.material_override = VisualPolish.make_organic_mat(Color(0.30, 0.19, 0.14), 1.2, 0.80, 0.98)
	dirt_mesh.position = Vector3(0, -1.4, 0)
	ground_body.add_child(dirt_mesh)
	add_child(ground_body)

	# S-Curve Autumn Canyon Dirt Path
	var s_pts := [
		START_POS, Vector3(-8.0, 0, -13.5), Vector3(6.5, 0, -13.5), Vector3(22.0, 0, -13.0),
		GATE1_POS, Vector3(21.0, 0, -1.0), Vector3(10.0, 0, 0.0), Vector3(1.5, 0, -1.2),
		Vector3(-11.0, 0, 0.8), Vector3(-18.5, 0, 1.0), Vector3(-22.0, 0, 2.0),
		GATE2_POS, Vector3(-21.5, 0, 13.0), Vector3(-4.0, 0, 13.0), BENCH_POS + Vector3(-2.5, 0, 0)
	]
	var path_mat := VisualPolish.make_organic_mat(Color(0.64, 0.48, 0.32), 1.9, 0.78, 0.97)
	for i in range(s_pts.size() - 1):
		var a: Vector3 = s_pts[i]
		var b: Vector3 = s_pts[i + 1]
		var seg := a.lerp(b, 0.5)
		var dist := a.distance_to(b)
		var p_mesh := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 1.15
		pm.bottom_radius = 1.25
		pm.height = 0.05
		pm.radial_segments = 8
		p_mesh.mesh = pm
		p_mesh.material_override = path_mat
		p_mesh.position = Vector3(seg.x, 0.02, seg.z)
		p_mesh.scale = Vector3(1.0, 1.0, max(1.0, dist * 0.48))
		add_child(p_mesh)
		if b.distance_to(seg) > 0.05:
			p_mesh.look_at(Vector3(b.x, 0.02, b.z), Vector3.UP)

	# Floating warm autumn embers
	var rng := RandomNumberGenerator.new()
	rng.seed = 3333
	var em_mat := _mat(Color(1.0, 0.58, 0.22), 0.2, Color(1.0, 0.48, 0.16), 1.4)
	for i in range(32):
		var em := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.075
		sm.height = 0.15
		em.mesh = sm
		em.material_override = em_mat
		var base := Vector3(rng.randf_range(-HALF_W + 2, HALF_W - 2), rng.randf_range(0.6, 2.8), rng.randf_range(-HALF_D + 2, HALF_D - 2))
		em.position = base
		add_child(em)
		embers.append({"node": em, "base": base, "phase": rng.randf_range(0, TAU)})


func _build_ridge_barriers_and_gates() -> void:
	_add_3d_box_collider(Vector3(0, 1.5, -HALF_D - 0.5), Vector3(HALF_W * 2.0, 4.0, 1.0))
	_add_3d_box_collider(Vector3(0, 1.5, HALF_D + 0.5), Vector3(HALF_W * 2.0, 4.0, 1.0))
	_add_3d_box_collider(Vector3(-HALF_W - 0.5, 1.5, 0), Vector3(1.0, 4.0, HALF_D * 2.0))
	_add_3d_box_collider(Vector3(HALF_W + 0.5, 1.5, 0), Vector3(1.0, 4.0, HALF_D * 2.0))

	# North Canyon Ridge Wall (Z = -6.5, X from -28 to +16 -> gap on East at X=22!)
	_add_3d_box_collider(Vector3(-6.0, 1.25, -6.5), Vector3(44.0, 2.5, 2.2))
	for x in range(-25, 17, 4):
		_spawn_autumn_tree(Vector3(float(x), 0.0, -6.5), 1.15 + fmod(absf(float(x)), 3.0) * 0.1, int(absf(float(x))) % 8 == 0)

	# South Canyon Ridge Wall (Z = +6.5, X from -16 to +28 -> gap on West at X=-22!)
	_add_3d_box_collider(Vector3(6.0, 1.25, 6.5), Vector3(44.0, 2.5, 2.2))
	for x in range(-15, 27, 4):
		_spawn_autumn_tree(Vector3(float(x), 0.0, 6.5), 1.15 + fmod(absf(float(x)), 3.0) * 0.1, int(absf(float(x))) % 8 == 0)

	# East Passage (22, 0, -6.5): Cedar Split-Rail Pasture Fence + Double Timber Ranch Gate!
	gate1_data = ObstacleBuilder.build_level3_ranch_fence_gate(self, GATE1_POS)

	# West Passage (-22, 0, 6.5): Stone & Wrought-Iron Park Sanctuary Archway + Crimson Vines!
	gate2_data = ObstacleBuilder.build_level3_iron_arch_gate(self, GATE2_POS)

	# Scenic Autumn Trees & Rocks
	for tp in [
		Vector3(-25.5, 0, -17.5), Vector3(-15.0, 0, -17.5), Vector3(0.0, 0, -17.5),
		Vector3(16.0, 0, -17.5), Vector3(25.5, 0, -16.5), Vector3(-25.5, 0, 17.5),
		Vector3(-12.0, 0, 17.5), Vector3(2.0, 0, 17.5), Vector3(25.5, 0, 17.5),
	]:
		_spawn_autumn_tree(tp, 1.35, true)

	for rp in [
		Vector3(-15.0, 0, -11.5), Vector3(14.5, 0, -12.0), Vector3(19.0, 0, 2.5),
		Vector3(-14.0, 0, 11.5), Vector3(2.0, 0, 10.5),
	]:
		_spawn_rock(rp, 1.05)


func _spawn_autumn_tree(pos: Vector3, sc: float, is_maple: bool) -> void:
	var tree := Node3D.new()
	tree.position = pos
	var asym := 0.93 + 0.14 * absf(sin(pos.x * 1.3 + pos.z * 0.9))
	tree.scale = Vector3(sc * asym, sc * (2.0 - asym), sc)
	tree.rotation.y = fmod(absf(pos.x * 1.9 + pos.z * 3.1), TAU)

	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.28
	tm.bottom_radius = 0.42
	tm.height = 1.9
	tm.radial_segments = 6
	trunk.mesh = tm
	trunk.material_override = VisualPolish.make_organic_mat(Color(0.40, 0.25, 0.17), 2.4, 0.78, 0.96)
	trunk.position = Vector3(0, 0.95, 0)
	tree.add_child(trunk)

	var canopy := Node3D.new()
	canopy.position = Vector3(0, 1.8, 0)
	tree.add_child(canopy)

	var leaf_col := Color(0.84, 0.32, 0.17) if is_maple else Color(0.82, 0.54, 0.19)
	for lobe in [
		[Vector3(0, 0.85, 0), Vector3(1.0, 1.0, 1.0)],
		[Vector3(-0.46, 0.55, 0.20), Vector3(0.66, 0.62, 0.66)],
		[Vector3(0.44, 0.60, -0.18), Vector3(0.62, 0.58, 0.64)],
	]:
		var crown := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.32
		sm.height = 2.05
		sm.radial_segments = 7
		sm.rings = 4
		crown.mesh = sm
		crown.material_override = VisualPolish.make_organic_mat(leaf_col, 1.5, 0.66, 0.92)
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


func _spawn_rock(pos: Vector3, sc: float) -> void:
	var rock := Node3D.new()
	rock.position = pos
	rock.scale = Vector3(sc * 1.12, sc * 0.85, sc * 0.96)
	rock.rotation.y = pos.x * 2.1 - pos.z * 1.3
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.85
	sm.height = 1.05
	sm.radial_segments = 5
	sm.rings = 3
	m.mesh = sm
	m.material_override = VisualPolish.make_organic_mat(Color(0.44, 0.40, 0.42), 2.2, 0.76, 0.98)
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


func _build_flames() -> void:
	var outer_mat := _mat(Color(1.0, 0.34, 0.10), 0.3, Color(1.0, 0.30, 0.06), 1.35, 0.90)
	var mid_mat := _mat(Color(1.0, 0.56, 0.14), 0.25, Color(1.0, 0.50, 0.10), 1.50, 0.92)
	var core_mat := _mat(Color(1.0, 0.90, 0.28), 0.2, Color(1.0, 0.86, 0.22), 1.85)
	var stone_mat := _mat(Color(0.28, 0.24, 0.26), 0.95)
	var log_mat := _mat(Color(0.26, 0.16, 0.12), 0.95)

	for fp in FLAME_POSITIONS:
		var f := Node3D.new()
		f.position = fp

		var base := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.72
		bm.bottom_radius = 0.85
		bm.height = 0.18
		bm.radial_segments = 8
		base.mesh = bm
		base.material_override = stone_mat
		base.position = Vector3(0, 0.09, 0)
		f.add_child(base)

		# Crossed charred firewood logs
		for ang in [25.0, -35.0]:
			var lg := MeshInstance3D.new()
			var lm := CylinderMesh.new()
			lm.top_radius = 0.09
			lm.bottom_radius = 0.10
			lm.height = 1.05
			lm.radial_segments = 6
			lg.mesh = lm
			lg.material_override = log_mat
			lg.position = Vector3(0, 0.18, 0)
			lg.rotation_degrees = Vector3(82, ang, 0)
			f.add_child(lg)

		# 3 dancing asymmetrical flame tongues
		var flame_pivot := Node3D.new()
		flame_pivot.position = Vector3(0, 0.20, 0)
		f.add_child(flame_pivot)

		for tongue in [
			[Vector3(0, 0.68, 0), 0.36, 1.30, Vector3.ZERO, outer_mat],
			[Vector3(-0.22, 0.48, 0.08), 0.24, 0.92, Vector3(0, 0, 16), mid_mat],
			[Vector3(0.20, 0.45, -0.06), 0.22, 0.86, Vector3(0, 0, -18), mid_mat],
			[Vector3(0, 0.40, 0.02), 0.20, 0.78, Vector3.ZERO, core_mat],
		]:
			var t_m := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = tongue[1]
			cm.height = tongue[2]
			cm.radial_segments = 7
			t_m.mesh = cm
			t_m.material_override = tongue[4]
			t_m.position = tongue[0]
			t_m.rotation_degrees = tongue[3]
			flame_pivot.add_child(t_m)

		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.52, 0.20)
		light.light_energy = 1.15
		light.omni_range = 4.6
		light.position = Vector3(0, 1.0, 0)
		f.add_child(light)

		add_child(f)
		flames.append({"pos": fp, "pivot": flame_pivot, "phase": fp.x * 0.5 + fp.z * 0.3})

		var body := StaticBody3D.new()
		body.position = fp
		var col := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.62
		cyl.height = 1.6
		col.shape = cyl
		col.position = Vector3(0, 0.8, 0)
		body.add_child(col)
		add_child(body)


func _build_interactives() -> void:
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
		var cap_mat := _mat(Color(0.68, 0.46, 0.84))
		cap.material_override = cap_mat
		cap.position = Vector3(0, 0.72, 0)
		m.add_child(cap)

		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.78, 0.48)
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

	var freqs := [523.25, 659.25]
	for i in range(PAD_POSITIONS.size()):
		var pad := NotePad3D.create(PAD_POSITIONS[i], freqs[i])
		pad.visible = false
		add_child(pad)
		pad_nodes.append({"node": pad, "pos": PAD_POSITIONS[i], "revealed": false, "lit": false})

	milk_tea_node = Keepsake3D.create("milk_tea")
	milk_tea_node.position = MILKTEA_POS
	milk_tea_node.visible = false
	add_child(milk_tea_node)


func _build_bench_and_partner() -> void:
	var bench := Node3D.new()
	bench.position = BENCH_POS
	add_child(bench)

	var wood_mat := _mat(Color(0.66, 0.44, 0.24), 0.85)
	var iron_mat := _mat(Color(0.22, 0.24, 0.28), 0.45)

	# 3D Park Bench Seat (width = 5.4m along X: [-2.7, +2.7]), Backrest, Armrests & Legs
	var seat := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(5.4, 0.14, 1.05)
	seat.mesh = sm
	seat.material_override = wood_mat
	seat.position = Vector3(0, 0.50, 0)
	bench.add_child(seat)

	var back := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(5.4, 0.65, 0.12)
	back.mesh = bm
	back.material_override = wood_mat
	back.position = Vector3(0, 0.92, -0.46)
	back.rotation_degrees = Vector3(-10, 0, 0)
	bench.add_child(back)

	for sx in [-2.62, 2.62]:
		var arm := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(0.14, 0.34, 0.95)
		arm.mesh = am
		arm.material_override = iron_mat
		arm.position = Vector3(sx, 0.68, 0)
		bench.add_child(arm)

		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.18, 0.50, 0.88)
		leg.mesh = lm
		leg.material_override = iron_mat
		leg.position = Vector3(sx * 0.92, 0.25, 0)
		bench.add_child(leg)

	# Bench collider
	_add_3d_box_collider(BENCH_POS + Vector3(0, 0.55, 0), Vector3(5.5, 1.1, 1.15))

	# Partner sitting at the center of the bench!
	partner_model = Chibi3D.create(partner_role)
	partner_model.scale = Vector3.ONE * 0.92
	partner_model.set_sitting(true)
	partner_model.position = BENCH_POS + Vector3(0, 0.56, 0.08)
	add_child(partner_model)

	# Alert indicator above partner's head (hidden until bench mini-game warning/watch!)
	alert_indicator = Node3D.new()
	alert_indicator.position = Vector3(0, 2.38, 0)
	alert_indicator.visible = false
	partner_model.add_child(alert_indicator)

	alert_mat = _mat(Color(1.0, 0.85, 0.20), 0.2, Color(1.0, 0.80, 0.15), 1.4)
	var bar_m := MeshInstance3D.new()
	var barm := BoxMesh.new()
	barm.size = Vector3(0.14, 0.42, 0.14)
	bar_m.mesh = barm
	bar_m.material_override = alert_mat
	bar_m.position = Vector3(0, 0.18, 0)
	alert_indicator.add_child(bar_m)

	var dot_m := MeshInstance3D.new()
	var dotm := SphereMesh.new()
	dotm.radius = 0.09
	dotm.height = 0.18
	dot_m.mesh = dotm
	dot_m.material_override = alert_mat
	dot_m.position = Vector3(0, -0.14, 0)
	alert_indicator.add_child(dot_m)

	var p_light := OmniLight3D.new()
	p_light.light_color = Color(1.0, 0.80, 0.72)
	p_light.light_energy = 1.1
	p_light.omni_range = 6.5
	p_light.position = BENCH_POS + Vector3(0, 2.2, 0.5)
	add_child(p_light)


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

	var hud_parts := GameUI.build_level_hud(ui, Color(1.0, 0.72, 0.38), _open_settings)
	hud_label = hud_parts["hud_label"]
	toast_panel = hud_parts["toast_panel"]
	toast_label = hud_parts["toast_label"]
	var root_ctrl: Control = hud_parts["root"]

	# Bench status banner (borderless floating outlined game text, only shown in bench mini-game)
	bench_status_lbl = Label.new()
	bench_status_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bench_status_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bench_status_lbl.offset_left = -360
	bench_status_lbl.offset_right = 360
	bench_status_lbl.offset_top = 72
	bench_status_lbl.custom_minimum_size = Vector2(720, 38)
	bench_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUI.style_floating_label(bench_status_lbl, 22, Color(0.65, 1.0, 0.72), 6)
	bench_status_lbl.visible = false
	root_ctrl.add_child(bench_status_lbl)

	minimap = MiniMap.new()
	minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	minimap.grow_vertical = Control.GROW_DIRECTION_BEGIN
	minimap.offset_left = -168
	minimap.offset_top = -168
	minimap.offset_right = -16
	minimap.offset_bottom = -16
	minimap.configure(HALF_W, HALF_D, BENCH_POS)
	root_ctrl.add_child(minimap)

	_refresh_hud(false)


func _refresh_hud(animate: bool = true) -> void:
	if hud_label:
		hud_label.text = "第 3 关 · 炽热秋枫林    ◆ 石阶 %d/2    ◆ 蘑菇 %d/4    ◆ 珍珠奶茶 %s" % [
			pads_lit, lit_mushrooms, "已端稳" if milk_tea_found else "寻觅中"
		]
		if animate:
			GameUI.pulse_hud(hud_label)


func _show_toast(msg: String, duration: float = 4.2) -> void:
	toast_label.text = msg
	toast_timer = duration
	GameUI.animate_toast_in(toast_panel)


func _on_player_landed(pos: Vector3, impact: float) -> void:
	GameJuice.spawn_splash(self, pos, Color(0.94, 0.76, 0.56), int(5 + 6 * impact), 0.55 * impact, false)


func _on_player_step(pos: Vector3) -> void:
	var puff := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.15
	sm.height = 0.18
	puff.mesh = sm
	var pcol := Color(0.16, 0.15, 0.16, 0.72) if char_timer > 0.0 else Color(0.92, 0.86, 0.76, 0.55)
	puff.material_override = _mat(pcol)
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
	if event.is_action_pressed("telepathy") and not bench_mode:
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

	var target: Vector3 = BENCH_POS
	var hint_msg: String = "蝴蝶正朝着东南角长凳旁的TA飞去~"
	if not gate1_open:
		if pad_nodes[0]["revealed"] and not pad_nodes[0]["lit"]:
			target = pad_nodes[0]["pos"]
			hint_msg = "蝴蝶正朝着北岸的「音符石阶」飞去~"
		else:
			target = mushroom_nodes[0]["pos"]
			hint_msg = "蝴蝶正朝着北岸的发光蘑菇飞去~"
	elif not milk_tea_found:
		if milk_tea_revealed:
			target = MILKTEA_POS
			hint_msg = "蝴蝶正朝着火焰谷的「珍珠奶茶」飞去~"
		else:
			target = mushroom_nodes[1]["pos"]
			hint_msg = "蝴蝶正朝着火焰谷的发光蘑菇飞去~"
	elif not gate2_open:
		if pad_nodes[1]["revealed"] and not pad_nodes[1]["lit"]:
			target = pad_nodes[1]["pos"]
			hint_msg = "蝴蝶正朝着西侧的「音符石阶」飞去~"
		else:
			target = mushroom_nodes[2]["pos"]
			hint_msg = "蝴蝶正朝着火焰谷西侧的发光蘑菇飞去~"

	var dir := (target - player.position)
	dir.y = 0.0
	if dir.length() < 0.05:
		dir = Vector3.FORWARD
	butterfly_vel = dir.normalized() * 6.8
	butterfly.look_at(butterfly.position + butterfly_vel, Vector3.UP)
	butterfly_life = 2.8
	_show_toast(hint_msg, 2.8)


func _start_bench_minigame() -> void:
	bench_mode = true
	player.set_seated_mode(true)
	player.model.rotation.y = 0.0
	if minimap:
		minimap.visible = false

	# Sit at the side the player approached from
	player_seat_x = -2.05 if player.position.x < BENCH_POS.x else 2.05
	player_target_x = player_seat_x
	partner_seat_x = 0.0
	partner_target_x = 0.0
	angry_scoot_t = 0.0
	player.position = BENCH_POS + Vector3(player_seat_x, 0.56, 0.08)

	# Partner turns head to the OPPOSITE side!
	look_state = "AWAY"
	look_timer = 2.4
	_update_partner_head_target()
	bench_status_lbl.visible = true
	_show_toast("你悄悄坐在长凳一端！按【A / D】慢慢挪过去，注意看头顶预警，TA回头时千万别动！", 6.5)


func _update_partner_head_target() -> void:
	if not partner_model:
		return
	var dir_to_player := signf(player_seat_x - partner_seat_x)
	if dir_to_player == 0.0:
		dir_to_player = -1.0
	if look_state == "WATCH":
		# Turns head directly back toward the player!
		partner_model.head_target_yaw = dir_to_player * 0.72
	else:
		# Turns head away to the opposite side!
		partner_model.head_target_yaw = -dir_to_player * 0.92


func _update_bench_minigame(delta: float) -> void:
	if catch_cooldown > 0.0:
		catch_cooldown -= delta

	# State machine for Partner turning head back to check!
	look_timer -= delta
	if look_state == "AWAY":
		alert_indicator.visible = false
		bench_status_lbl.text = "【安全】TA正扭头生闷气中 —— 按 A / D 悄悄挪过去！"
		bench_status_lbl.add_theme_color_override("font_color", Color(0.65, 1.0, 0.72))
		if look_timer <= 0.0:
			look_state = "WARN"
			look_timer = 0.75
			alert_indicator.visible = true
			alert_mat.albedo_color = Color(1.0, 0.85, 0.20)
			alert_mat.emission = Color(1.0, 0.80, 0.15)
			SoundFX.play("warn")
	elif look_state == "WARN":
		alert_indicator.visible = true
		bench_status_lbl.text = "【注意！】TA好像要回头了，快停下来！！"
		bench_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.32))
		if look_timer <= 0.0:
			look_state = "WATCH"
			look_timer = randf_range(1.25, 1.65)
			_update_partner_head_target()
			alert_mat.albedo_color = Color(1.0, 0.25, 0.25)
			alert_mat.emission = Color(1.0, 0.20, 0.20)
	elif look_state == "WATCH":
		alert_indicator.visible = true
		bench_status_lbl.text = "【别动！】TA正在回头盯着你！！"
		bench_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42))
		if look_timer <= 0.0:
			look_state = "AWAY"
			look_timer = randf_range(1.9, 2.7)
			_update_partner_head_target()

	# Player scooting along the bench
	var move_x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	if angry_scoot_t > 0.0:
		angry_scoot_t = maxf(0.0, angry_scoot_t - delta)
		# Rapidly scoot partner & nudged player smoothly toward targets (no teleporting!)
		partner_seat_x = move_toward(partner_seat_x, partner_target_x, 2.8 * delta)
		player_seat_x = move_toward(player_seat_x, player_target_x, 2.4 * delta)
	elif absf(move_x) > 0.1:
		if look_state == "WATCH" and catch_cooldown <= 0.0:
			# Caught moving! Partner gets angry, shakes head & arms, and rapidly scoots away!
			catch_cooldown = 1.25
			angry_scoot_t = 0.48
			var away_dir := signf(partner_seat_x - player_seat_x)
			if away_dir == 0.0:
				away_dir = 1.0
			partner_target_x = clampf(partner_seat_x + away_dir * 0.85, -2.15, 2.15)
			player_target_x = player_seat_x
			if absf(partner_target_x - player_seat_x) < 1.15:
				player_target_x = clampf(player_seat_x - away_dir * 0.60, -2.2, 2.2)

			# Turn partner head back away in a huff & play angry animation + anger puffs!
			look_state = "AWAY"
			look_timer = 1.75
			_update_partner_head_target()
			partner_model.trigger_angry()
			SoundFX.play("angry")
			GameJuice.hitstop(0.065, 0.06)
			GameJuice.add_trauma(0.42)
			_spawn_anger_puffs(BENCH_POS + Vector3(partner_seat_x, 2.1, 0.1))
			_show_toast("被发现了！！TA气鼓鼓地迅速往另一边挪远了一截！", 2.8)
		else:
			player_seat_x = clampf(player_seat_x + move_x * 1.25 * delta, -2.2, 2.2)
			player_target_x = player_seat_x

	player.position = BENCH_POS + Vector3(player_seat_x, 0.56, 0.08)
	partner_model.position = BENCH_POS + Vector3(partner_seat_x, 0.56, 0.08)

	# Close-up cozy bench camera + trauma shake
	var cam_target := BENCH_POS + Vector3(0, 2.5, 5.4)
	camera.position = camera.position.lerp(cam_target, min(1.0, delta * 5.0))
	camera.look_at(BENCH_POS + Vector3(0, 1.35, 0), Vector3.UP)
	GameJuice.apply_camera_shake(camera)

	# Touching partner & gifting the Milk Tea!
	if angry_scoot_t <= 0.0 and absf(player_seat_x - partner_seat_x) < 0.72:
		cleared = true
		alert_indicator.visible = false
		bench_status_lbl.visible = false
		partner_model.head_target_yaw = 0.0
		player.model.set_holding_milktea(false)
		player.model.trigger_celebrate()
		partner_model.trigger_celebrate()
		# Place the gifted 3D Milk Tea right between them!
		var gift := Keepsake3D.create("milk_tea")
		gift.position = BENCH_POS + Vector3((player_seat_x + partner_seat_x) * 0.5, 0.55, 0.55)
		gift.scale = Vector3.ONE * 0.75
		add_child(gift)
		_spawn_burst(BENCH_POS + Vector3((player_seat_x + partner_seat_x) * 0.5, 1.4, 0.2), Color(1.0, 0.65, 0.85), 18)
		SoundFX.play("victory")
		_show_toast("TA接过热乎乎的珍珠奶茶，终于破涕为笑啦！", 2.0)
		var tw := create_tween()
		tw.tween_interval(1.45)
		tw.tween_callback(func():
			level_cleared.emit({
				"level": 3,
				"role": role,
				"mushrooms": lit_mushrooms,
				"keepsake": true,
				"burns": burn_count,
			})
		)


func _spawn_anger_puffs(origin: Vector3) -> void:
	for i in range(5):
		var puff := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.12
		sm.height = 0.24
		puff.mesh = sm
		puff.material_override = _mat(Color(1.0, 0.34, 0.28), 0.3, Color(1.0, 0.25, 0.20), 1.2, 0.90)
		puff.position = origin + Vector3(randf_range(-0.35, 0.35), randf_range(0.0, 0.35), 0.1)
		add_child(puff)
		var tw := create_tween()
		tw.tween_property(puff, "position", puff.position + Vector3(randf_range(-0.4, 0.4), 0.55, 0.0), 0.45)
		tw.parallel().tween_property(puff, "scale", Vector3.ONE * 0.2, 0.45)
		tw.tween_callback(puff.queue_free)


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001

	for item in sway_nodes:
		item["node"].rotation.z = sin(t * 2.0 + item["phase"]) * item["amp"]

	for fl in flames:
		var fp: Node3D = fl["pivot"]
		var ph: float = fl["phase"]
		fp.scale = Vector3(1.0 + sin(t * 9.0 + ph) * 0.08, 1.0 + sin(t * 12.0 + ph) * 0.16, 1.0 + cos(t * 8.0 + ph) * 0.08)
		fp.rotation.z = sin(t * 6.5 + ph) * 0.06

	for em in embers:
		var en: Node3D = em["node"]
		var b: Vector3 = em["base"]
		var ph: float = em["phase"]
		en.position = b + Vector3(sin(t * 1.4 + ph) * 0.5, fmod(t * 0.8 + ph, 1.6), cos(t * 1.2 + ph) * 0.5)

	if partner_model:
		partner_model.update_anim(false, false, delta)

	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0:
			toast_panel.visible = false

	if cleared:
		return

	# Charred soot-black recovery timer (runs even while seated on bench!)
	if burn_cooldown > 0.0:
		burn_cooldown -= delta
	if char_timer > 0.0:
		char_timer -= delta
		if char_timer <= 0.0:
			player.model.set_charred(false)
			_show_toast("身上的黑灰拍干净了，以后小心躲开火焰呀！", 2.8)

	if bench_mode:
		_update_bench_minigame(delta)
		return

	if player and camera:
		var target_cam := player.position + Vector3(0, 6.8, 8.2)
		camera.position = camera.position.lerp(target_cam, min(1.0, delta * 6.5))
		camera.look_at(player.position + Vector3(0, 1.1, 0), Vector3.UP)
		GameJuice.apply_camera_shake(camera)

	if minimap:
		var active_gates: Array = []
		if not gate1_open:
			active_gates.append(GATE1_POS)
		if not gate2_open:
			active_gates.append(GATE2_POS)
		minimap.refresh(player.position, mushroom_nodes, pad_nodes, milk_tea_revealed and not milk_tea_found, MILKTEA_POS, active_gates)

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

	# Check Flame Collision -> Char Player Black!
	for fl in flames:
		if burn_cooldown <= 0.0 and ppos.distance_to(fl["pos"]) < 1.15:
			burn_cooldown = 1.2
			char_timer = 3.5
			burn_count += 1
			player.model.set_charred(true)
			player.trigger_squash(Vector3(1.24, 0.78, 1.24))
			SoundFX.play("sizzle")
			GameJuice.hitstop(0.068, 0.05)
			GameJuice.add_trauma(0.46)
			_spawn_burst(player.position + Vector3(0, 0.4, 0), Color(0.95, 0.44, 0.16), 16)
			_show_toast("哎呀！踩到生气小火苗被烤成小黑炭啦！（3.5秒后恢复）", 3.5)

	# Mushrooms
	for m in mushroom_nodes:
		if not m["lit"] and ppos.distance_to(m["pos"]) < 1.9:
			m["lit"] = true
			lit_mushrooms += 1
			var mmat: StandardMaterial3D = m["mat"]
			mmat.albedo_color = Color(1.0, 0.80, 0.42)
			mmat.emission_enabled = true
			mmat.emission = Color(1.0, 0.72, 0.35)
			mmat.emission_energy_multiplier = 0.65
			create_tween().tween_property(m["light"], "light_energy", 1.15, 0.5)
			SoundFX.play("mushroom")
			_spawn_burst(m["pos"], Color(1.0, 0.80, 0.42), 10)
			_refresh_hud()

			var rev: String = m["reveal"]
			if rev == "pad0":
				pad_nodes[0]["revealed"] = true
				pad_nodes[0]["node"].visible = true
				_show_toast("秋枫微光照亮北岸！第 1 块「音符石阶」显现了！", 4.0)
			elif rev == "milktea" and not milk_tea_revealed:
				milk_tea_revealed = true
				milk_tea_node.visible = true
				_show_toast("火焰谷中间闪烁着一杯热乎乎的「珍珠奶茶」！快躲开火苗去拿吧~", 4.5)
			elif rev == "pad1":
				pad_nodes[1]["revealed"] = true
				pad_nodes[1]["node"].visible = true
				_show_toast("微光照亮火焰谷西口！第 2 块「音符石阶」显现了！", 4.0)
			else:
				_show_toast("TA就坐在东南方的长凳上生闷气，快去哄TA吧~", 3.8)

	# Note Pads
	for idx in range(pad_nodes.size()):
		var pdata: Dictionary = pad_nodes[idx]
		if pdata["revealed"] and not pdata["lit"] and ppos.distance_to(pdata["pos"]) < 1.35:
			pdata["lit"] = true
			pads_lit += 1
			pdata["node"].activate()
			_refresh_hud()
			if idx == 0 and not gate1_open:
				gate1_open = true
				SoundFX.play("gate")
				GameJuice.hitstop(0.075, 0.06)
				GameJuice.add_trauma(0.48)
				ObstacleBuilder.unlock(gate1_data)
				_spawn_burst(GATE1_POS, Color(1.0, 0.65, 0.36), 22)
				_show_toast("音符响起！东侧牧木栅栏的双扇木门敞开了，快进火焰谷找奶茶吧！", 4.5)
			elif idx == 1 and not gate2_open:
				gate2_open = true
				SoundFX.play("gate")
				GameJuice.hitstop(0.075, 0.06)
				GameJuice.add_trauma(0.48)
				ObstacleBuilder.unlock(gate2_data)
				_spawn_burst(GATE2_POS, Color(1.0, 0.52, 0.58), 22)
				_show_toast("音符响起！西侧红枫藤蔓消散，雕花铁艺公园拱门向你敞开了！", 4.5)

	# Milk Tea pickup
	if milk_tea_revealed and not milk_tea_found and ppos.distance_to(MILKTEA_POS) < 1.45:
		milk_tea_found = true
		milk_tea_node.queue_free()
		player.model.set_holding_milktea(true)
		SoundFX.play("keepsake")
		_spawn_burst(MILKTEA_POS, Color(1.0, 0.86, 0.50), 14)
		_refresh_hud()
		_show_toast("拿到「全糖去冰珍珠奶茶」啦！快端着奶茶去东南角长凳找生气的TA吧~", 5.0)

	# Reaching Park Bench
	if ppos.distance_to(BENCH_POS) < 3.6:
		if not milk_tea_found:
			if not bench_warn_no_tea:
				bench_warn_no_tea = true
				_show_toast("TA扭过头哼了一声：『两手空空就想来哄我？先把中部火焰谷的珍珠奶茶拿来再说！』", 5.5)
		else:
			_start_bench_minigame()
