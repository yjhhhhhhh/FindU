extends Node3D
class_name Level2Scene

signal level_cleared(stats: Dictionary)
signal back_to_select
signal restart_level

# Concentric Spiral Forest: Player starts on Outer Ring -> winds into Middle Ring -> crosses Bridge into Center Frog Sanctuary!
const HALF_W := 28.0
const HALF_D := 28.0

const START_POS := Vector3(-16.5, 0.0, 18.5)
const GOAL_POS := Vector3(0.0, 0.0, 0.0)
const OUTER_GATE_POS := Vector3(16.8, 0.0, 0.0)
const BRIDGE_POS := Vector3(0.0, 0.0, 9.5)

const MUSHROOM_CONFIGS := [
	{"pos": Vector3(-21.5, 0.0, 3.0), "reveal": "keepsake"},
	{"pos": Vector3(-14.5, 0.0, -16.5), "reveal": "pad0"},
	{"pos": Vector3(14.0, 0.0, 17.0), "reveal": "pad1"},
	{"pos": Vector3(0.0, 0.0, -13.2), "reveal": "pad2"},
	{"pos": Vector3(0.0, 0.0, 5.2), "reveal": "goal_path"},
]

const KEEPSAKE_POS := Vector3(-20.2, 0.0, -4.5)
const PAD_POSITIONS := [
	Vector3(-5.0, 0.0, -21.0),   # Outer North (revealed by Mushroom 2)
	Vector3(19.5, 0.0, 10.5),    # Outer East-South (revealed by Mushroom 3)
	Vector3(-13.2, 0.0, -1.5),   # Middle Ring West (revealed by Mushroom 4)
]

const FROG_OFFSETS := [
	Vector3(-3.0, 0.0, 2.2),
	Vector3(-3.8, 0.0, -0.8),
	Vector3(-1.4, 0.0, 3.6),
	Vector3(2.4, 0.0, 2.8),
	Vector3(3.5, 0.0, -1.4),
	Vector3(0.4, 0.0, -3.4),
]

var role: String = "boy"
var partner_role: String = "girl"

var player: PlayerController
var camera: Camera3D

var sway_nodes: Array[Dictionary] = []
var water_ripples: Array[Dictionary] = []
var fireflies: Array[Dictionary] = []
var mushroom_nodes: Array[Dictionary] = []
var pad_nodes: Array[Dictionary] = []
var frogs: Array[Frog3D] = []

var lit_mushrooms: int = 0
var outer_pads_lit: int = 0
var middle_pad_lit: int = 0
var frogs_scared: int = 0
var total_frogs: int = 6

var gate1_data: Dictionary = {}
var gate1_open: bool = false

var gate2_data: Dictionary = {}
var gate2_open: bool = false

var keepsake_node: Node3D
var keepsake_revealed: bool = false
var keepsake_found: bool = false

var partner_node: Node3D
var partner_model: Chibi3D = null
var partner_warned: bool = false
var frogs_cleared_announced: bool = false
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


func init_role(p_role: String) -> void:
	role = p_role
	partner_role = "girl" if role == "boy" else "boy"


func _ready() -> void:
	_build_sky_and_lighting()
	_build_spiral_terrain()
	_build_circular_moat_and_bridge()
	_build_outer_ring_hedge_and_obstacles()
	_build_interactives()
	_build_frogs()
	_build_player_and_camera()
	_build_hud()

	_show_toast("第2关·萤火环林！你现在在森林最外围，TA正被困在正中心！一路绕向中心去救TA吧~", 6.5)


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
	sky_mat.sky_top_color = Color(0.08, 0.18, 0.34)
	sky_mat.sky_horizon_color = Color(0.22, 0.38, 0.50)
	sky_mat.ground_bottom_color = Color(0.06, 0.14, 0.14)
	sky_mat.ground_horizon_color = Color(0.16, 0.32, 0.25)
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.32, 0.44)
	env.ambient_light_energy = 0.44
	env.fog_enabled = true
	env.fog_light_color = Color(0.14, 0.28, 0.36)
	env.fog_density = 0.012

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.98, 0.86, 0.68)
	sun.light_energy = 0.62
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-52, -32, 0)
	add_child(sun)

	var cool_rim := DirectionalLight3D.new()
	cool_rim.light_color = Color(0.36, 0.66, 0.92)
	cool_rim.light_energy = 0.28
	cool_rim.rotation_degrees = Vector3(-28, 148, 0)
	add_child(cool_rim)


func _build_spiral_terrain() -> void:
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
		Color(0.16, 0.39, 0.24), Color(0.32, 0.52, 0.27), Color(0.07, 0.18, 0.22), 0.46
	)
	grass_mesh.position = Vector3(0, -0.25, 0)
	ground_body.add_child(grass_mesh)

	var dirt_mesh := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(HALF_W * 2.0 - 0.1, 1.8, HALF_D * 2.0 - 0.1)
	dirt_mesh.mesh = dm
	dirt_mesh.material_override = VisualPolish.make_organic_mat(Color(0.36, 0.25, 0.17), 1.2, 0.80, 0.98)
	dirt_mesh.position = Vector3(0, -1.4, 0)
	ground_body.add_child(dirt_mesh)
	add_child(ground_body)

	# Spiral dirt footpath segments winding from Outer Ring -> Middle Ring -> Center!
	var path_mat := VisualPolish.make_organic_mat(Color(0.62, 0.50, 0.34), 1.9, 0.78, 0.97)
	var spiral_pts: Array[Vector3] = []
	# Outer ring arc (from SW clockwise through W -> N -> E -> SE)
	for i in range(20):
		var ang := deg_to_rad(135.0 + float(i) * 14.5)
		spiral_pts.append(Vector3(cos(ang) * 21.0, 0.0, sin(ang) * 21.0))
	# Entry through East Outer Gate into Middle Ring
	spiral_pts.append(Vector3(19.5, 0, 6.0))
	spiral_pts.append(OUTER_GATE_POS)
	# Middle ring arc (from East counter-clockwise through N -> W -> S Bridge)
	for i in range(16):
		var ang := deg_to_rad(0.0 - float(i) * 17.5)
		spiral_pts.append(Vector3(cos(ang) * 13.4, 0.0, sin(ang) * 13.4))
	spiral_pts.append(BRIDGE_POS)
	spiral_pts.append(Vector3(0.0, 0.0, 5.2))
	spiral_pts.append(GOAL_POS)

	for i in range(spiral_pts.size() - 1):
		var a: Vector3 = spiral_pts[i]
		var b: Vector3 = spiral_pts[i + 1]
		var seg := a.lerp(b, 0.5)
		var dist := a.distance_to(b)
		var p_mesh := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 1.05
		pm.bottom_radius = 1.15
		pm.height = 0.05
		pm.radial_segments = 8
		p_mesh.mesh = pm
		p_mesh.material_override = path_mat
		p_mesh.position = Vector3(seg.x, 0.02, seg.z)
		p_mesh.scale = Vector3(1.0, 1.0, max(1.0, dist * 0.50))
		add_child(p_mesh)
		if b.distance_to(seg) > 0.05:
			p_mesh.look_at(Vector3(b.x, 0.02, b.z), Vector3.UP)

	# Drifting 3D Fireflies
	var rng := RandomNumberGenerator.new()
	rng.seed = 20262
	var ff_mat := _mat(Color(0.82, 1.0, 0.45), 0.2, Color(0.75, 1.0, 0.38), 1.5)
	for i in range(36):
		var ff := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = 0.09
		fm.height = 0.18
		ff.mesh = fm
		ff.material_override = ff_mat
		var base := Vector3(rng.randf_range(-HALF_W + 3, HALF_W - 3), rng.randf_range(0.8, 2.6), rng.randf_range(-HALF_D + 3, HALF_D - 3))
		ff.position = base
		add_child(ff)
		fireflies.append({"node": ff, "base": base, "phase": rng.randf_range(0, TAU)})


func _build_circular_moat_and_bridge() -> void:
	# Circular stream moat at radius 9.5m with animated shader water & shoreline foam!
	var water_mat := VisualPolish.make_water_mat(
		Color(0.05, 0.24, 0.40), Color(0.14, 0.62, 0.72), Vector2(0.0, 1.0), 0.52
	)
	var rip_mat := _mat(Color(0.76, 0.94, 1.0), 0.1, Color(0.55, 0.88, 1.0), 0.4)
	var moat_r := 9.5
	var segs := 28

	for i in range(segs):
		var a0 := float(i) / float(segs) * TAU
		var a1 := float(i + 1) / float(segs) * TAU
		var amid := (a0 + a1) * 0.5
		var pos := Vector3(cos(amid) * moat_r, 0.015, sin(amid) * moat_r)
		var seg_len := 2.0 * moat_r * sin(PI / float(segs)) + 0.45

		var w := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(2.8, 0.04, seg_len)
		w.mesh = wm
		w.material_override = water_mat
		w.position = pos
		w.rotation.y = -amid
		add_child(w)

		# Leave clean opening at South bridge (amid around +PI/2 -> abs(pos.x) < 2.2 and pos.z > 6.0)
		var in_bridge_gap := pos.z > 6.0 and absf(pos.x) < 2.2
		if i % 2 == 0 and not in_bridge_gap:
			var r := MeshInstance3D.new()
			var rm := BoxMesh.new()
			rm.size = Vector3(0.22, 0.016, 0.85)
			r.mesh = rm
			r.material_override = rip_mat
			var rpos := Vector3(pos.x, 0.042, pos.z)
			r.position = rpos
			r.rotation.y = -amid
			add_child(r)
			water_ripples.append({"node": r, "base_pos": rpos, "phase": float(i) * 0.6})

		if not in_bridge_gap:
			var body := StaticBody3D.new()
			body.position = Vector3(pos.x, 1.0, pos.z)
			body.rotation.y = -amid
			var col := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(2.6, 2.5, seg_len)
			col.shape = box
			body.add_child(col)
			add_child(body)

	# Arched South Bridge clearly ABOVE the moat water with smooth sloped ramps!
	var bridge := Node3D.new()
	bridge.position = BRIDGE_POS
	add_child(bridge)
	var wood_mat := _mat(Color(0.68, 0.46, 0.25), 0.88)
	var post_mat := _mat(Color(0.44, 0.28, 0.15), 0.90)

	var deck_body := StaticBody3D.new()
	var d_col := CollisionShape3D.new()
	var d_box := BoxShape3D.new()
	d_box.size = Vector3(3.8, 0.14, 3.6)
	d_col.shape = d_box
	d_col.position = Vector3(0, 0.08, 0)
	deck_body.add_child(d_col)
	for side in [-1.0, 1.0]:
		var r_col := CollisionShape3D.new()
		var r_box := BoxShape3D.new()
		r_box.size = Vector3(3.8, 0.14, 1.1)
		r_col.shape = r_box
		r_col.position = Vector3(0, 0.01, side * 2.15)
		r_col.rotation_degrees = Vector3(side * 9.0, 0, 0)
		deck_body.add_child(r_col)
	bridge.add_child(deck_body)

	for bx in [-1.35, 1.35]:
		var beam := MeshInstance3D.new()
		var bmm := BoxMesh.new()
		bmm.size = Vector3(0.22, 0.08, 4.1)
		beam.mesh = bmm
		beam.material_override = post_mat
		beam.position = Vector3(bx, 0.08, 0)
		bridge.add_child(beam)

	# Outer abutment planks; center span starts tilted up as a raised drawbridge!
	for pz_end in [-1.5, 1.5]:
		var plank := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(3.8, 0.09, 0.68)
		plank.mesh = pm
		plank.material_override = wood_mat
		plank.position = Vector3(0, 0.11, float(pz_end))
		bridge.add_child(plank)

	for px in [-1.8, 1.8]:
		for pz in [-1.6, 1.6]:
			var post := MeshInstance3D.new()
			var psm := BoxMesh.new()
			psm.size = Vector3(0.24, 0.92, 0.24)
			post.mesh = psm
			post.material_override = post_mat
			post.position = Vector3(px, 0.56, pz)
			bridge.add_child(post)
		var rail := MeshInstance3D.new()
		var rlm := BoxMesh.new()
		rlm.size = Vector3(0.14, 0.12, 3.4)
		rail.mesh = rlm
		rail.material_override = wood_mat
		rail.position = Vector3(px, 0.86, 0)
		bridge.add_child(rail)

	gate2_data = ObstacleBuilder.build_level2_moat_drawbridge(self, BRIDGE_POS)


func _build_outer_ring_hedge_and_obstacles() -> void:
	# Outer world boundaries
	_add_3d_box_collider(Vector3(0, 1.5, -HALF_D - 0.5), Vector3(HALF_W * 2.0, 4.0, 1.0))
	_add_3d_box_collider(Vector3(0, 1.5, HALF_D + 0.5), Vector3(HALF_W * 2.0, 4.0, 1.0))
	_add_3d_box_collider(Vector3(-HALF_W - 0.5, 1.5, 0), Vector3(1.0, 4.0, HALF_D * 2.0))
	_add_3d_box_collider(Vector3(HALF_W + 0.5, 1.5, 0), Vector3(1.0, 4.0, HALF_D * 2.0))

	# Ring of trees & bushes at r = 16.8 separating Outer Ring from Middle Ring!
	# Only 1 opening at East (OUTER_GATE_POS = (16.8, 0, 0)) gated by Vine Gate 1!
	var barrier_r := 16.8
	var count := 28
	for i in range(count):
		var a := float(i) / float(count) * TAU
		var pos := Vector3(cos(a) * barrier_r, 0.0, sin(a) * barrier_r)
		# Leave East opening (pos.x > 13.0 and abs(pos.z) < 2.2)
		if pos.x > 13.0 and absf(pos.z) < 2.4:
			continue
		if i % 2 == 0:
			_spawn_lowpoly_tree(pos, 1.22, i % 4 == 0)
		else:
			_spawn_lowpoly_bush(pos, 1.35)
		# Dense hedge collider segment between trees so player must wind into East gate
		var body := StaticBody3D.new()
		body.position = Vector3(pos.x, 1.2, pos.z)
		body.rotation.y = -a
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.2, 2.5, 3.8)
		col.shape = box
		body.add_child(col)
		add_child(body)

	# Thorny Briar & Split-Picket Fence Gate at East Outer-to-Middle entrance (16.8, 0, 0)
	gate1_data = ObstacleBuilder.build_level2_briar_fence_gate(self, OUTER_GATE_POS)

	# Scenic outer corner trees & rocks (keeping outer ring corridor wide and clear!)
	for pos in [
		Vector3(-25.5, 0, -25.0), Vector3(25.5, 0, -25.0),
		Vector3(-25.5, 0, 25.0), Vector3(25.5, 0, 25.0),
		Vector3(-25.5, 0, -10.0), Vector3(25.5, 0, -12.0),
		Vector3(0.0, 0, -25.5), Vector3(0.0, 0, 25.5),
	]:
		_spawn_lowpoly_tree(pos, 1.35, int(absf(pos.x)) % 2 == 0)

	for rpos in [
		Vector3(-24.0, 0, 12.0), Vector3(-12.0, 0, -24.0),
		Vector3(12.0, 0, -23.5), Vector3(23.5, 0, 15.0),
		Vector3(12.0, 0, 12.0), Vector3(-11.5, 0, 11.5),
	]:
		_spawn_lowpoly_rock(rpos, 1.05)


func _spawn_lowpoly_tree(pos: Vector3, sc: float, is_pine: bool) -> void:
	var tree := Node3D.new()
	tree.position = pos
	var asym := 0.94 + 0.12 * absf(sin(pos.x * 1.4 + pos.z * 0.8))
	tree.scale = Vector3(sc * asym, sc * (2.0 - asym), sc)
	tree.rotation.y = fmod(absf(pos.x * 2.1 + pos.z * 3.7), TAU)

	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.28
	tm.bottom_radius = 0.42
	tm.height = 1.9
	tm.radial_segments = 6
	trunk.mesh = tm
	trunk.material_override = VisualPolish.make_organic_mat(Color(0.44, 0.28, 0.18), 2.4, 0.78, 0.96)
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
				Color(0.14, 0.46, 0.26) if i == 0 else Color(0.20, 0.58, 0.34), 1.5, 0.68, 0.92
			)
			cone.position = Vector3(0, 0.7 + i * 1.0, 0)
			canopy.add_child(cone)
	else:
		var crown := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.35
		sm.height = 2.1
		sm.radial_segments = 7
		sm.rings = 4
		crown.mesh = sm
		crown.material_override = VisualPolish.make_organic_mat(Color(0.20, 0.56, 0.32), 1.4, 0.66, 0.92)
		crown.position = Vector3(0, 0.85, 0)
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
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.85
	sm.height = 1.15
	sm.radial_segments = 7
	sm.rings = 4
	m.mesh = sm
	m.material_override = VisualPolish.make_organic_mat(Color(0.22, 0.58, 0.32), 1.8, 0.66, 0.92)
	m.position = Vector3(0, 0.45, 0)
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
	rock.scale = Vector3(sc * 1.12, sc * 0.85, sc * 0.96)
	rock.rotation.y = pos.x * 2.1 - pos.z * 1.3
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.85
	sm.height = 1.05
	sm.radial_segments = 5
	sm.rings = 3
	m.mesh = sm
	m.material_override = VisualPolish.make_organic_mat(Color(0.46, 0.51, 0.58), 2.2, 0.76, 0.98)
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
		light.light_color = Color(0.45, 1.0, 0.82)
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

	var freqs := [523.25, 659.25, 783.99]  # C5, E5, G5
	for i in range(PAD_POSITIONS.size()):
		var pad := NotePad3D.create(PAD_POSITIONS[i], freqs[i])
		pad.visible = false
		add_child(pad)
		pad_nodes.append({"node": pad, "pos": PAD_POSITIONS[i], "revealed": false, "lit": false})

	# Sculpted 3D Keepsake: Strawberry Hairpin (for Boy) or Clear Glasses Case (for Girl)!
	var kind := "strawberry_clip" if role == "boy" else "glasses_case"
	keepsake_node = Keepsake3D.create(kind)
	keepsake_node.position = KEEPSAKE_POS
	keepsake_node.visible = false
	add_child(keepsake_node)

	# Center Sanctuary Partner!
	partner_node = Node3D.new()
	partner_node.position = GOAL_POS
	_spawn_lowpoly_tree(GOAL_POS + Vector3(0.0, 0, -4.6), 1.45, false)

	partner_model = Chibi3D.create(partner_role)
	partner_model.scale = Vector3.ONE * 0.92
	partner_node.add_child(partner_model)

	var p_light := OmniLight3D.new()
	p_light.light_color = Color(1.0, 0.78, 0.88)
	p_light.light_energy = 1.05
	p_light.omni_range = 7.0
	p_light.position = Vector3(0, 1.8, 0)
	partner_node.add_child(p_light)
	add_child(partner_node)


func _build_frogs() -> void:
	for i in range(FROG_OFFSETS.size()):
		var fpos: Vector3 = GOAL_POS + FROG_OFFSETS[i]
		var frog := Frog3D.create(fpos, float(i) * 0.9)
		add_child(frog)
		frogs.append(frog)


func _build_player_and_camera() -> void:
	player = PlayerController.new()
	player.setup(role)
	player.position = START_POS
	player.moved_step.connect(_on_player_step)
	player.landed.connect(_on_player_landed)
	player.attacked.connect(_on_player_attacked)
	add_child(player)

	camera = Camera3D.new()
	camera.fov = 45.0
	add_child(camera)
	camera.look_at_from_position(START_POS + Vector3(0, 6.8, 8.2), START_POS + Vector3(0, 1.1, 0), Vector3.UP)


func _build_hud() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	var hud_parts := GameUI.build_level_hud(ui, Color(0.62, 0.96, 0.56), _open_settings)
	hud_parts["hint_label"].text = "WASD 奔跑  ·  Space 跳跃  ·  J/左键 赶蛙  ·  E/H 灵蝶  ·  ESC 设置"
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
		hud_label.text = "第 2 关 · 萤火环林    ◆ 石阶 %d/3    ◆ 蘑菇 %d/5    ◆ 跳蛙 %d/%d    ◆ 信物 %s" % [
			outer_pads_lit + middle_pad_lit, lit_mushrooms, frogs_scared, total_frogs,
			"已拾取" if keepsake_found else "寻觅中"
		]
		if animate:
			GameUI.pulse_hud(hud_label)


func _show_toast(msg: String, duration: float = 4.2) -> void:
	toast_label.text = msg
	toast_timer = duration
	GameUI.animate_toast_in(toast_panel)


func _on_player_landed(pos: Vector3, impact: float) -> void:
	GameJuice.spawn_splash(self, pos, Color(0.82, 0.94, 0.78), int(5 + 6 * impact), 0.55 * impact, false)


func _on_player_step(pos: Vector3) -> void:
	var puff := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.15
	sm.height = 0.18
	puff.mesh = sm
	puff.material_override = _mat(Color(0.86, 0.92, 0.82, 0.55))
	puff.position = pos + Vector3(0, 0.1, 0)
	add_child(puff)
	var tw := create_tween()
	tw.tween_property(puff, "scale", Vector3.ONE * 1.8, 0.35)
	tw.tween_callback(puff.queue_free)


func _spawn_burst(origin: Vector3, col: Color, count: int = 12) -> void:
	GameJuice.spawn_splash(self, origin, col, count, 1.0, true)


func _on_player_attacked(pos: Vector3, fwd: Vector3) -> void:
	var arc := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.65
	tm.outer_radius = 1.15
	tm.rings = 14
	tm.ring_segments = 8
	arc.mesh = tm
	arc.material_override = _mat(Color(1.0, 0.92, 0.52), 0.3, Color(1.0, 0.86, 0.35), 1.1, 0.85)
	arc.position = pos + fwd * 1.05 + Vector3(0, 0.75, 0)
	arc.scale = Vector3(0.7, 0.35, 0.7)
	add_child(arc)
	var tw := create_tween()
	tw.tween_property(arc, "scale", Vector3(1.5, 0.35, 1.5), 0.22)
	tw.parallel().tween_property(arc.material_override, "albedo_color:a", 0.0, 0.22)
	tw.tween_callback(arc.queue_free)

	var hit_center := pos + fwd * 1.1
	var hit_any := false
	for frog in frogs:
		if is_instance_valid(frog) and not frog.fleeing:
			var d1 := Vector2(frog.position.x - hit_center.x, frog.position.z - hit_center.z).length()
			var d2 := Vector2(frog.position.x - pos.x, frog.position.z - pos.z).length()
			if d1 < 2.8 or d2 < 2.3:
				_spawn_burst(frog.position, Color(1.0, 0.94, 0.42), 10)
				frog.scare_away(pos)
				frogs_scared += 1
				hit_any = true

	if hit_any:
		GameJuice.hitstop(0.055, 0.05)
		GameJuice.add_trauma(0.38)
		_refresh_hud()
		if frogs_scared < total_frogs:
			_show_toast("呱！吓跑了一只小跳蛙！(%d/%d)" % [frogs_scared, total_frogs], 2.4)
		elif not frogs_cleared_announced:
			frogs_cleared_announced = true
			SoundFX.play("keepsake", -5.0)
			_show_toast("太厉害啦！！中心的小跳蛙全都被吓跑了！快走到TA身边重逢吧~", 5.0)


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

	# Smart stage-aware butterfly guide for Level 2 Spiral Forest!
	var target := GOAL_POS
	var hint_msg := "微光蝴蝶正朝着森林中心的TA飞去~"
	var best_d := 9999.0
	var found_stage := false
	for pdata in pad_nodes:
		if pdata["revealed"] and not pdata["lit"]:
			var d := player.position.distance_to(pdata["pos"])
			if d < best_d:
				best_d = d; target = pdata["pos"]; found_stage = true
				hint_msg = "微光蝴蝶正飞向显现的「音符石阶」~"
	if not found_stage and not gate1_open:
		for m in mushroom_nodes:
			if not m["lit"] and m["reveal"] in ["pad0", "pad1"]:
				var d := player.position.distance_to(m["pos"])
				if d < best_d:
					best_d = d; target = m["pos"]; found_stage = true
					hint_msg = "微光蝴蝶正飞向外环未点亮的「发光蘑菇」~"
	elif not found_stage and gate1_open and not gate2_open:
		for m in mushroom_nodes:
			if not m["lit"] and m["reveal"] == "pad2":
				target = m["pos"]; found_stage = true
				hint_msg = "微光蝴蝶正飞向中圈的「发光蘑菇」~"
	if not found_stage and keepsake_revealed and not keepsake_found:
		target = KEEPSAKE_POS
		hint_msg = "微光蝴蝶正飞向外环的「专属信物」~"

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
		var bp: Vector3 = rip["base_pos"]
		rn.position = bp + Vector3(sin(t * 2.4 + rip["phase"]) * 0.14, 0, cos(t * 2.0 + rip["phase"]) * 0.14)

	for ff in fireflies:
		var fn: Node3D = ff["node"]
		var b: Vector3 = ff["base"]
		var ph: float = ff["phase"]
		fn.position = b + Vector3(sin(t * 1.1 + ph) * 0.6, sin(t * 1.8 + ph) * 0.35, cos(t * 0.9 + ph) * 0.6)

	for i in range(frogs.size() - 1, -1, -1):
		var f := frogs[i]
		if is_instance_valid(f):
			if not f.update_frog(delta):
				f.queue_free()
				frogs.remove_at(i)

	if partner_model:
		partner_model.update_anim(false, false, delta)
		if frogs_scared < total_frogs:
			partner_model.rotation.z = sin(t * 32.0) * 0.055
		else:
			partner_model.rotation.z = move_toward(partner_model.rotation.z, 0.0, delta * 5.0)

	if player and camera:
		var target_cam := player.position + Vector3(0, 6.8, 8.2)
		camera.position = camera.position.lerp(target_cam, min(1.0, delta * 6.5))
		camera.look_at(player.position + Vector3(0, 1.1, 0), Vector3.UP)
		GameJuice.apply_camera_shake(camera)

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
		var closed_gates: Array = []
		if not gate1_open:
			closed_gates.append(OUTER_GATE_POS)
		if not gate2_open:
			closed_gates.append(BRIDGE_POS)
		minimap.refresh(player.position, mushroom_nodes, pad_nodes, keepsake_revealed and not keepsake_found, KEEPSAKE_POS, closed_gates)

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
				_show_toast("发光蘑菇照亮外环林间！前面出现了一枚闪闪发亮的「信物」~", 4.0)
			elif rev == "pad0":
				pad_nodes[0]["revealed"] = true
				pad_nodes[0]["node"].visible = true
				_show_toast("微光照亮外环北侧！第 1 块「音符石阶」显现了！", 4.0)
			elif rev == "pad1":
				pad_nodes[1]["revealed"] = true
				pad_nodes[1]["node"].visible = true
				_show_toast("微光照亮外环东南！第 2 块「音符石阶」显现了！", 4.0)
			elif rev == "pad2":
				pad_nodes[2]["revealed"] = true
				pad_nodes[2]["node"].visible = true
				_show_toast("中圈的微光照出了第 3 块「音符石阶」！去中圈西侧踩亮它就能打开中心木桥！", 4.5)
			else:
				_show_toast("终于到达中心空地附近！咦，怎么有好多青蛙叫声？", 3.8)

	for idx in range(pad_nodes.size()):
		var pdata: Dictionary = pad_nodes[idx]
		if pdata["revealed"] and not pdata["lit"] and ppos.distance_to(pdata["pos"]) < 1.35:
			pdata["lit"] = true
			pdata["node"].activate()

			if idx < 2:
				outer_pads_lit += 1
				if outer_pads_lit == 2 and not gate1_open:
					gate1_open = true
					SoundFX.play("gate", -5.0)
					GameJuice.hitstop(0.075, 0.06)
					GameJuice.add_trauma(0.48)
					_spawn_burst(OUTER_GATE_POS, Color(0.65, 1.0, 0.75), 22)
					ObstacleBuilder.unlock(gate1_data)
					_show_toast("外环两块石阶共鸣！东侧荆棘藤蔓退去，木栅栏双门敞开了，继续往里绕行吧~", 4.8)
				else:
					_show_toast("踩亮了外环石阶 (%d/2)！沿着外圈继续寻找下一朵发光蘑菇~" % outer_pads_lit, 4.0)
			else:
				middle_pad_lit += 1
				if not gate2_open:
					gate2_open = true
					SoundFX.play("gate", -5.0)
					GameJuice.hitstop(0.075, 0.06)
					GameJuice.add_trauma(0.48)
					_spawn_burst(BRIDGE_POS, Color(0.82, 0.65, 1.0), 22)
					ObstacleBuilder.unlock(gate2_data)
					_show_toast("中圈石阶共鸣！护城河吊桥的紫晶藤锁解开，木吊桥平稳落下了！", 4.5)
			_refresh_hud()

	if keepsake_revealed and not keepsake_found and ppos.distance_to(KEEPSAKE_POS) < 1.45:
		keepsake_found = true
		SoundFX.play("keepsake", -5.0)
		_spawn_burst(KEEPSAKE_POS, Color(1.0, 0.76, 0.84), 14)
		keepsake_node.queue_free()
		_refresh_hud()
		var kmsg := (
			"捡到了「草莓发卡」！她平时最喜欢戴的草莓发卡掉在这里，而且她最怕青蛙……快往中心赶去！"
			if role == "boy"
			else "捡到了「透明眼镜盒」！里面还有他留下的小纸条，得快点绕到森林中心找他！"
		)
		_show_toast(kmsg, 5.0)

	var dist_goal := ppos.distance_to(GOAL_POS)
	if dist_goal < 6.4 and not partner_warned and frogs_scared < total_frogs:
		partner_warned = true
		_show_toast("TA吓得浑身发抖：『呜哇！我最怕小跳蛙了！快按【J】或【鼠标左键】帮我把周围 6 只小跳蛙全赶跑！』", 6.0)
	elif dist_goal < 2.2 and frogs_scared < total_frogs and toast_timer <= 0.4:
		_show_toast("还有 %d 只小跳蛙在周围蹦哒！先按【J】或【鼠标左键】把它们全打跑吧~" % (total_frogs - frogs_scared), 3.0)

	if dist_goal < 2.2 and frogs_scared >= total_frogs:
		cleared = true
		player.can_move = false
		SoundFX.play("victory", -4.0)
		player.model.trigger_celebrate()
		partner_model.trigger_celebrate()
		_spawn_burst(GOAL_POS, Color(1.0, 0.56, 0.78), 22)
		_show_toast("小跳蛙全赶跑啦，太棒了！！", 2.5)
		var stats := {
			"level": 2,
			"role": role,
			"mushrooms": lit_mushrooms,
			"keepsake": keepsake_found,
			"frogs": frogs_scared,
		}
		var tw := create_tween()
		tw.tween_interval(1.45)
		tw.tween_callback(func(): level_cleared.emit(stats))
