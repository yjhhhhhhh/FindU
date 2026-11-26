extends Node3D
class_name Level5Scene

signal level_cleared(stats: Dictionary)
signal back_to_select
signal restart_level

## Level 5: 微光拼豆屋（手作重逢）
## Full 5-stage cozy 3D craft story:
##   1. "intro"    : Protagonist looks around shop & twilight street, realizes TA is missing, decides to craft TA's pixel charm!
##   2. "craft"    : 19x19 high-craft Perler bead head portrait (8 colors, UNSHADED uniform floor guide, smooth hold-left-drag Bresenham swipe!)
##                   interleaved with 4-5 mental arithmetic popups (wrong/timeout shakes pegboard & pops 5-8 beads, never Game Over!)
##   3. "iron"     : Parchment paper + 3D mini craft iron + warm steam fusing all beads smoothly
##   4. "showcase" : Close-up glowing 3D showcase of the fused 19x19 Perler charm (auto-rotating + left-drag 360 spin!)
##   5. "reunion"  : Brass wind chime rings, glass shop door opens, TA walks in for 4-tier attitude gift reunion!

const GRID_N := 19
const CELL_SZ := 0.106
const BOARD_ORIGIN := Vector3(-0.46, 0.04, 0.08)
const QUIZ_DURATION := 5.0

const GIRL_STRINGS := [
	".....1111.1111.....",
	"...1122221222211...",
	"..122233222332221..",
	".12232222122223221.",
	".12222224442222221.",
	".12222444444422221.",
	".12224555455542221.",
	".12254615556145221.",
	"1422541154511452241",
	".12245554445554221.",
	".12247744444774221.",
	".12214444744441221.",
	"1282114444444112821",
	"1222211444441122221",
	"123221.11111.122321",
	"122221.......122221",
	".12221.......12221.",
	"..121.........121..",
	"...1...........1...",
]

const BOY_STRINGS := [
	"...................",
	".....111111111.....",
	"...1122222222211...",
	"..122332222233221..",
	".12222222222222221.",
	"1222222222222222221",
	".12222222222222221.",
	".12242244244224221.",
	".12455554445555421.",
	"1425461455546145241",
	"1485411454541145841",
	".14455554445555441.",
	".11447744444774411.",
	"..144444878444441..",
	"...1444444444441...",
	"....11444444411....",
	"......1111111......",
	"...................",
	"...................",
]

var role: String = "boy"
var partner_role: String = "girl"

# Phases: "intro" -> "craft" -> "iron" -> "showcase" -> "reunion" -> "done"
var phase: String = "intro"
var intro_t: float = 0.0
var intro_stage: int = 0
var elapsed_time: float = 0.0
var finish_time: float = 0.0
var cleared: bool = false

# Target pattern & 8-color palette
var palette: Array[Dictionary] = []
var target_grid: Array[Array] = []
var placed_grid: Array[Array] = []
var bead_nodes: Array[Array] = []
var guide_labels: Array[Array] = []
var heat_grid: Array[Array] = []
var total_beads: int = 0
var placed_count: int = 0
var selected_color: int = 1
var place_combo: int = 0
var combo_decay: float = 0.0
var last_drag_rc: Vector2i = Vector2i(-1, -1)
var wrong_hint_cd: float = 0.0

# Mental Math Quiz state
var quiz_active: bool = false
var quiz_timer: float = 0.0
var quiz_correct_idx: int = 0
var quiz_right: int = 0
var quiz_wrong: int = 0
var beads_since_quiz: int = 0
var time_since_quiz: float = 0.0
var board_shake_t: float = 0.0

# Ironing state
var iron_progress: float = 0.0
var iron_pos: Vector2 = Vector2.ZERO
var iron_pressing: bool = false
var steam_cd: float = 0.0
var steam_sfx_cd: float = 0.0
var iron_done_triggered: bool = false

# Showcase state
var showcase_t: float = 0.0
var showcase_root: Node3D
var showcase_charm: Node3D
var showcase_sparkles: Array[Dictionary] = []
var showcase_dragging: bool = false
var showcase_rot_y: float = 0.0
var showcase_rot_x: float = 0.08
var showcase_last_mouse: Vector2 = Vector2.ZERO
var showcase_ui: Control

# Reunion state
var reunion_t: float = 0.0
var reunion_stage: int = 0
var finale_tier: int = 1
var finale_mood_name: String = ""
var finale_mood_quote: String = ""

# 3D Scene Nodes
var camera: Camera3D
var board_root: Node3D
var beads_holder: Node3D
var hover_ring: MeshInstance3D
var tray_slots: Array[Dictionary] = []
var shared_bead_mesh: ArrayMesh
var shared_fused_mesh: ArrayMesh
var bead_mats: Dictionary = {}
var guide_unshaded_mats: Dictionary = {}
var guide_dim_mats: Dictionary = {}
var guide_meshes: Array[Array] = []

var parchment_mesh: MeshInstance3D
var parchment_mat: StandardMaterial3D
var iron_root: Node3D
var iron_led_mat: StandardMaterial3D
var steam_puffs: Array[Dictionary] = []

var shop_door_pivot: Node3D
var chime_pivot: Node3D
var player_model: Chibi3D
var partner_model: Chibi3D
var held_charm: Node3D
var emotion_badge: Node3D

# HUD & Quiz UI
var ui_layer: CanvasLayer
var hud_label: Label
var hint_label: Label
var toast_panel: Control
var toast_label: Label
var toast_timer: float = 0.0
var palette_bar: HBoxContainer
var palette_btns: Array[Button] = []
var iron_bar_wrap: Control
var iron_bar_fill: ColorRect
var iron_bar_lbl: Label

var quiz_overlay: Control
var quiz_eq_lbl: Label
var quiz_timer_fill: ColorRect
var quiz_timer_lbl: Label
var quiz_opt_btns: Array[Button] = []


func init_role(p_role: String) -> void:
	role = p_role
	partner_role = "girl" if role == "boy" else "boy"


func _mat(col: Color, rough: float = 0.78, emit_col: Color = Color.BLACK, emit_e: float = 0.0, alpha: float = 1.0, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.roughness = rough
	m.metallic = metallic
	m.metallic_specular = 0.22 if rough > 0.4 else 0.52
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit_e > 0.0:
		m.emission_enabled = true
		m.emission = emit_col
		m.emission_energy_multiplier = emit_e
	return m


func _make_unshaded_guide_mat(col: Color, dim_factor: float = 1.0) -> StandardMaterial3D:
	## 100% lighting-independent & shadow-free flat swatch so identical color IDs look pixel-identical everywhere on the pegboard!
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var bg := Color(0.94, 0.92, 0.87)
	var final_c := bg.lerp(col, dim_factor)
	m.albedo_color = Color(final_c.r, final_c.g, final_c.b, 1.0)
	return m


func _ready() -> void:
	_init_pattern_and_palette()
	shared_bead_mesh = _make_bead_mesh(0.047, 0.019, 0.056)
	shared_fused_mesh = _make_fused_bead_mesh(0.052, 0.011, 0.044)
	for idx in range(palette.size()):
		var p: Dictionary = palette[idx]
		var col: Color = p["color"]
		var cid: int = int(p["id"])
		bead_mats[cid] = _mat(col, 0.26, col, 0.07)
		guide_unshaded_mats[cid] = _make_unshaded_guide_mat(col, 0.92)
		guide_dim_mats[cid] = _make_unshaded_guide_mat(col, 0.40)

	_setup_env_and_camera()
	_build_workshop_room()
	_build_pegboard_and_tray()
	_build_iron_and_parchment()
	_build_characters()
	_build_hud_and_quiz_ui()

	_select_color(1, true)
	# Hide craft palette during opening story cutscene
	palette_bar.visible = false
	_refresh_hud()
	_show_toast("刚走出山谷来到街角……咦？一转眼 TA 怎么不见了？（按 Space / Enter 可跳过开场）", 3.0)


func _init_pattern_and_palette() -> void:
	var src_rows: Array = []
	if partner_role == "girl":
		palette = [
			{"id": 1, "name": "深墨轮廓", "color": Color(0.15, 0.11, 0.12)},
			{"id": 2, "name": "深棕长发", "color": Color(0.31, 0.22, 0.19)},
			{"id": 3, "name": "发丝高光", "color": Color(0.50, 0.37, 0.31)},
			{"id": 4, "name": "暖杏肤色", "color": Color(0.99, 0.86, 0.76)},
			{"id": 5, "name": "金丝镜框", "color": Color(0.84, 0.64, 0.23)},
			{"id": 6, "name": "亮白高光", "color": Color(0.99, 0.99, 1.00)},
			{"id": 7, "name": "柔粉腮红", "color": Color(0.97, 0.59, 0.65)},
			{"id": 8, "name": "天蓝发绳", "color": Color(0.46, 0.76, 0.96)},
		]
		src_rows = GIRL_STRINGS
	else:
		palette = [
			{"id": 1, "name": "深墨轮廓", "color": Color(0.15, 0.12, 0.13)},
			{"id": 2, "name": "蓬松短发", "color": Color(0.27, 0.20, 0.17)},
			{"id": 3, "name": "发丝高光", "color": Color(0.44, 0.35, 0.29)},
			{"id": 4, "name": "暖杏肤色", "color": Color(0.99, 0.86, 0.76)},
			{"id": 5, "name": "透明灰框", "color": Color(0.72, 0.77, 0.84)},
			{"id": 6, "name": "亮白高光", "color": Color(0.99, 0.99, 1.00)},
			{"id": 7, "name": "柔粉腮红", "color": Color(0.96, 0.59, 0.63)},
			{"id": 8, "name": "暖棕浅影", "color": Color(0.88, 0.67, 0.56)},
		]
		src_rows = BOY_STRINGS

	total_beads = 0
	target_grid.clear()
	placed_grid.clear()
	bead_nodes.clear()
	guide_labels.clear()
	guide_meshes.clear()
	heat_grid.clear()

	for r in range(GRID_N):
		var row_str: String = str(src_rows[r])
		var tr: Array = []
		var pr: Array = []
		var br: Array = []
		var lr: Array = []
		var mr: Array = []
		var hr: Array = []
		for c in range(GRID_N):
			var ch := row_str.substr(c, 1)
			var val := 0 if ch == "." else int(ch)
			tr.append(val)
			pr.append(0)
			br.append(null)
			lr.append(null)
			mr.append(null)
			hr.append(0.0)
			if val > 0:
				total_beads += 1
		target_grid.append(tr)
		placed_grid.append(pr)
		bead_nodes.append(br)
		guide_labels.append(lr)
		guide_meshes.append(mr)
		heat_grid.append(hr)


func _make_bead_mesh(ro: float, ri: float, h: float) -> ArrayMesh:
	## Authentic 3D hollow cylindrical Perler bead catching warm desk-lamp highlights!
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 14
	for s in range(segs):
		var a0 := float(s) / float(segs) * TAU
		var a1 := float(s + 1) / float(segs) * TAU
		var c0 := cos(a0); var s0 := sin(a0)
		var c1 := cos(a1); var s1 := sin(a1)
		var ob0 := Vector3(c0 * ro, 0.0, s0 * ro)
		var ob1 := Vector3(c1 * ro, 0.0, s1 * ro)
		var ot0 := Vector3(c0 * ro, h, s0 * ro)
		var ot1 := Vector3(c1 * ro, h, s1 * ro)
		var ib0 := Vector3(c0 * ri, 0.0, s0 * ri)
		var ib1 := Vector3(c1 * ri, 0.0, s1 * ri)
		var it0 := Vector3(c0 * ri, h, s0 * ri)
		var it1 := Vector3(c1 * ri, h, s1 * ri)
		st.add_vertex(ob0); st.add_vertex(ob1); st.add_vertex(ot1)
		st.add_vertex(ob0); st.add_vertex(ot1); st.add_vertex(ot0)
		st.add_vertex(ib0); st.add_vertex(it1); st.add_vertex(ib1)
		st.add_vertex(ib0); st.add_vertex(it0); st.add_vertex(it1)
		st.add_vertex(ot0); st.add_vertex(ot1); st.add_vertex(it1)
		st.add_vertex(ot0); st.add_vertex(it1); st.add_vertex(it0)
		st.add_vertex(ib0); st.add_vertex(ib1); st.add_vertex(ob1)
		st.add_vertex(ib0); st.add_vertex(ob1); st.add_vertex(ob0)
	st.index()
	st.generate_normals()
	return st.commit()


func _make_fused_bead_mesh(ro: float, ri: float, h: float) -> ArrayMesh:
	## Plump iron-fused squircle Perler bead for the gorgeous finished charm showcase!
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 16
	for s in range(segs):
		var a0 := float(s) / float(segs) * TAU
		var a1 := float(s + 1) / float(segs) * TAU
		var p0 := _squircle_pt(a0, ro)
		var p1 := _squircle_pt(a1, ro)
		var i0 := Vector2(cos(a0) * ri, sin(a0) * ri)
		var i1 := Vector2(cos(a1) * ri, sin(a1) * ri)
		var ob0 := Vector3(p0.x, 0.0, p0.y)
		var ob1 := Vector3(p1.x, 0.0, p1.y)
		var ot0 := Vector3(p0.x, h, p0.y)
		var ot1 := Vector3(p1.x, h, p1.y)
		var ib0 := Vector3(i0.x, 0.0, i0.y)
		var ib1 := Vector3(i1.x, 0.0, i1.y)
		var it0 := Vector3(i0.x, h, i0.y)
		var it1 := Vector3(i1.x, h, i1.y)
		st.add_vertex(ob0); st.add_vertex(ob1); st.add_vertex(ot1)
		st.add_vertex(ob0); st.add_vertex(ot1); st.add_vertex(ot0)
		st.add_vertex(ib0); st.add_vertex(it1); st.add_vertex(ib1)
		st.add_vertex(ib0); st.add_vertex(it0); st.add_vertex(it1)
		st.add_vertex(ot0); st.add_vertex(ot1); st.add_vertex(it1)
		st.add_vertex(ot0); st.add_vertex(it1); st.add_vertex(it0)
		st.add_vertex(ib0); st.add_vertex(ib1); st.add_vertex(ob1)
		st.add_vertex(ib0); st.add_vertex(ob1); st.add_vertex(ob0)
	st.index()
	st.generate_normals()
	return st.commit()


func _squircle_pt(ang: float, r: float) -> Vector2:
	var cs := cos(ang)
	var sn := sin(ang)
	var sx := signf(cs) * pow(absf(cs), 0.58) * r
	var sy := signf(sn) * pow(absf(sn), 0.58) * r
	return Vector2(sx, sy)


func _setup_env_and_camera() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var smat := ProceduralSkyMaterial.new()
	smat.sky_top_color = Color(0.11, 0.17, 0.34)
	smat.sky_horizon_color = Color(0.58, 0.42, 0.48)
	smat.ground_bottom_color = Color(0.10, 0.12, 0.20)
	smat.ground_horizon_color = Color(0.32, 0.26, 0.34)
	sky.sky_material = smat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.56, 0.50, 0.48)
	env.ambient_light_energy = 0.64
	we.environment = env
	add_child(we)

	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.89, 0.72)
	key.light_energy = 0.85
	key.shadow_enabled = true
	key.rotation_degrees = Vector3(-56, -24, 0)
	add_child(key)

	var cool_win := DirectionalLight3D.new()
	cool_win.light_color = Color(0.45, 0.64, 0.96)
	cool_win.light_energy = 0.34
	cool_win.rotation_degrees = Vector3(-22, 165, 0)
	add_child(cool_win)

	var desk_light := OmniLight3D.new()
	desk_light.light_color = Color(1.0, 0.85, 0.58)
	desk_light.light_energy = 1.65
	desk_light.omni_range = 6.8
	desk_light.position = Vector3(-1.75, 1.50, -0.35)
	add_child(desk_light)

	camera = Camera3D.new()
	camera.fov = 44.0
	add_child(camera)
	camera.current = true
	camera.look_at_from_position(Vector3(3.15, 0.85, 2.35), Vector3(1.15, -0.35, -1.2), Vector3.UP)


func _build_workshop_room() -> void:
	var oak_mat := VisualPolish.make_organic_mat(Color(0.56, 0.37, 0.21), 1.4, 0.64, 0.88)
	var dark_wood := VisualPolish.make_organic_mat(Color(0.32, 0.21, 0.13), 1.6, 0.74, 0.94)
	var cream_wall := VisualPolish.make_organic_mat(Color(0.88, 0.80, 0.68), 0.9, 0.82, 0.96)
	var floor_mat := VisualPolish.make_terrain_mat(
		Color(0.38, 0.26, 0.17), Color(0.48, 0.34, 0.22), Color(0.24, 0.18, 0.14), 0.9
	)
	var brass_mat := _mat(Color(0.90, 0.72, 0.30), 0.26, Color(0.85, 0.66, 0.24), 0.12, 1.0, 0.72)
	var glass_mat := _mat(Color(0.76, 0.90, 0.98), 0.10, Color.BLACK, 0.0, 0.22)

	# 1. Long warm oak crafting workbench (top surface y = 0.0)
	var desk := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(4.8, 0.18, 2.6)
	desk.mesh = dm
	desk.material_override = oak_mat
	desk.position = Vector3(0.0, -0.09, 0.05)
	add_child(desk)

	for lx in [-2.15, 2.15]:
		for lz in [-1.0, 1.1]:
			var leg := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.16, 1.25, 0.16)
			leg.mesh = lm
			leg.material_override = dark_wood
			leg.position = Vector3(float(lx), -0.78, float(lz))
			add_child(leg)

	# 2. Floor & Walls
	var floor_b := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(13.0, 0.2, 11.0)
	floor_b.mesh = fm
	floor_b.material_override = floor_mat
	floor_b.position = Vector3(0.6, -1.50, -0.5)
	add_child(floor_b)

	for wx in [-4.8, 5.8]:
		var wall := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.3, 5.6, 11.0)
		wall.mesh = wm
		wall.material_override = cream_wall
		wall.position = Vector3(float(wx), 1.3, -0.5)
		add_child(wall)

	var wall_l := MeshInstance3D.new()
	var wlm := BoxMesh.new()
	wlm.size = Vector3(5.6, 1.35, 0.3)
	wall_l.mesh = wlm
	wall_l.material_override = cream_wall
	wall_l.position = Vector3(-1.9, -0.82, -4.1)
	add_child(wall_l)

	var lintel := MeshInstance3D.new()
	var ltm := BoxMesh.new()
	ltm.size = Vector3(11.0, 1.4, 0.35)
	lintel.mesh = ltm
	lintel.material_override = dark_wood
	lintel.position = Vector3(0.5, 3.35, -4.1)
	add_child(lintel)

	var mid_pillar := MeshInstance3D.new()
	var mpm := BoxMesh.new()
	mpm.size = Vector3(0.36, 4.4, 0.36)
	mid_pillar.mesh = mpm
	mid_pillar.material_override = dark_wood
	mid_pillar.position = Vector3(1.1, 0.75, -4.1)
	add_child(mid_pillar)

	var right_pillar := MeshInstance3D.new()
	var rpm := BoxMesh.new()
	rpm.size = Vector3(2.2, 4.4, 0.34)
	right_pillar.mesh = rpm
	right_pillar.material_override = cream_wall
	right_pillar.position = Vector3(4.65, 0.75, -4.1)
	add_child(right_pillar)

	var win_glass := MeshInstance3D.new()
	var wgm := BoxMesh.new()
	wgm.size = Vector3(5.6, 2.8, 0.06)
	win_glass.mesh = wgm
	win_glass.material_override = glass_mat
	win_glass.position = Vector3(-1.85, 1.25, -4.1)
	add_child(win_glass)

	# Evening street outside
	var street := MeshInstance3D.new()
	var stm := BoxMesh.new()
	stm.size = Vector3(24.0, 0.2, 10.0)
	street.mesh = stm
	street.material_override = VisualPolish.make_terrain_mat(
		Color(0.20, 0.22, 0.30), Color(0.36, 0.30, 0.34), Color(0.12, 0.14, 0.22), 0.75
	)
	street.position = Vector3(0.0, -1.55, -8.5)
	add_child(street)

	for slx in [-3.4, 1.6, 6.2]:
		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.07; pm.bottom_radius = 0.10; pm.height = 3.8
		pole.mesh = pm
		pole.material_override = _mat(Color(0.16, 0.18, 0.24), 0.65)
		pole.position = Vector3(float(slx), 0.4, -7.2)
		add_child(pole)
		var orb := MeshInstance3D.new()
		var om := SphereMesh.new()
		om.radius = 0.26; om.height = 0.52
		orb.mesh = om
		orb.material_override = _mat(Color(1.0, 0.86, 0.50), 0.15, Color(1.0, 0.82, 0.42), 2.1)
		orb.position = Vector3(float(slx), 2.4, -7.2)
		add_child(orb)

	# 3. Hinged Glass Shop Door + Brass Wind Chime Bell
	shop_door_pivot = Node3D.new()
	shop_door_pivot.position = Vector3(1.32, -1.40, -4.05)
	add_child(shop_door_pivot)

	var dfl := BoxMesh.new(); dfl.size = Vector3(0.16, 3.8, 0.14)
	for dx in [0.08, 2.08]:
		var df := MeshInstance3D.new()
		df.mesh = dfl; df.material_override = dark_wood
		df.position = Vector3(float(dx), 1.9, 0.0)
		shop_door_pivot.add_child(df)

	var d_top := MeshInstance3D.new()
	var dtm := BoxMesh.new(); dtm.size = Vector3(2.16, 0.22, 0.14)
	d_top.mesh = dtm; d_top.material_override = dark_wood
	d_top.position = Vector3(1.08, 3.72, 0.0)
	shop_door_pivot.add_child(d_top)

	var d_bot := MeshInstance3D.new()
	var dbm := BoxMesh.new(); dbm.size = Vector3(2.16, 0.92, 0.14)
	d_bot.mesh = dbm; d_bot.material_override = dark_wood
	d_bot.position = Vector3(1.08, 0.46, 0.0)
	shop_door_pivot.add_child(d_bot)

	var d_glass := MeshInstance3D.new()
	var dgm := BoxMesh.new(); dgm.size = Vector3(1.86, 2.75, 0.05)
	d_glass.mesh = dgm; d_glass.material_override = glass_mat
	d_glass.position = Vector3(1.08, 2.25, 0.0)
	shop_door_pivot.add_child(d_glass)

	var d_handle := MeshInstance3D.new()
	var dhm := CylinderMesh.new(); dhm.top_radius = 0.035; dhm.bottom_radius = 0.035; dhm.height = 0.46
	d_handle.mesh = dhm; d_handle.material_override = brass_mat
	d_handle.position = Vector3(1.90, 1.55, 0.12)
	shop_door_pivot.add_child(d_handle)

	chime_pivot = Node3D.new()
	chime_pivot.position = Vector3(2.35, 2.55, -3.72)
	add_child(chime_pivot)
	var bell := MeshInstance3D.new()
	var blm := CylinderMesh.new(); blm.top_radius = 0.06; blm.bottom_radius = 0.14; blm.height = 0.24
	bell.mesh = blm; bell.material_override = brass_mat
	bell.position = Vector3(0.0, -0.18, 0.0)
	chime_pivot.add_child(bell)

	# 4. Warm Brass Desk Lamp on Left Edge
	var lamp := Node3D.new()
	lamp.position = Vector3(-2.02, 0.0, -0.62)
	lamp.rotation_degrees = Vector3(0.0, -28.0, 0.0)
	add_child(lamp)
	var lbase := MeshInstance3D.new()
	var lbm := CylinderMesh.new(); lbm.top_radius = 0.16; lbm.bottom_radius = 0.22; lbm.height = 0.08
	lbase.mesh = lbm; lbase.material_override = brass_mat
	lbase.position = Vector3(0.0, 0.04, 0.0)
	lamp.add_child(lbase)
	var larm := MeshInstance3D.new()
	var lam := CylinderMesh.new(); lam.top_radius = 0.028; lam.bottom_radius = 0.034; lam.height = 0.95
	larm.mesh = lam; larm.material_override = brass_mat
	larm.position = Vector3(0.08, 0.50, 0.0); larm.rotation_degrees = Vector3(0.0, 0.0, -14.0)
	lamp.add_child(larm)
	var shade := MeshInstance3D.new()
	var shm := CylinderMesh.new(); shm.top_radius = 0.11; shm.bottom_radius = 0.28; shm.height = 0.26
	shade.mesh = shm; shade.material_override = _mat(Color(0.18, 0.40, 0.32), 0.45)
	shade.position = Vector3(0.26, 0.94, 0.0); shade.rotation_degrees = Vector3(0.0, 0.0, -34.0)
	lamp.add_child(shade)
	var bulb := MeshInstance3D.new()
	var bbm := SphereMesh.new(); bbm.radius = 0.09; bbm.height = 0.18
	bulb.mesh = bbm; bulb.material_override = _mat(Color(1.0, 0.94, 0.72), 0.1, Color(1.0, 0.88, 0.55), 2.4)
	bulb.position = Vector3(0.32, 0.86, 0.0)
	lamp.add_child(bulb)

	# 5. Decorative Craft Wall Shelf & Bead Jars on Right Wall
	var shelf := MeshInstance3D.new()
	var sfm := BoxMesh.new(); sfm.size = Vector3(0.45, 0.10, 3.8)
	shelf.mesh = sfm; shelf.material_override = oak_mat
	shelf.position = Vector3(5.35, 1.35, -0.6)
	add_child(shelf)
	var jar_cols := [Color(1.0, 0.52, 0.65), Color(0.46, 0.82, 1.0), Color(1.0, 0.86, 0.36), Color(0.48, 0.88, 0.56)]
	for ji in range(jar_cols.size()):
		var jar := MeshInstance3D.new()
		var jrm := CylinderMesh.new(); jrm.top_radius = 0.14; jrm.bottom_radius = 0.14; jrm.height = 0.34
		jar.mesh = jrm
		jar.material_override = _mat(jar_cols[ji], 0.22, jar_cols[ji], 0.25, 0.88)
		jar.position = Vector3(5.32, 1.57, -1.75 + float(ji) * 0.72)
		add_child(jar)


func _build_pegboard_and_tray() -> void:
	# 1. 19x19 High-Craft Pegboard with UNSHADED Uniform Color Blueprint Squares (ZERO shadow color drift!)
	board_root = Node3D.new()
	board_root.position = BOARD_ORIGIN
	add_child(board_root)

	var board_w := float(GRID_N) * CELL_SZ + 0.12
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(board_w, 0.044, board_w)
	base.mesh = bm
	# Unshaded warm parchment-ivory pegboard surface so every single cell has crystal-clear uniform contrast!
	var board_surf := StandardMaterial3D.new()
	board_surf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	board_surf.albedo_color = Color(0.93, 0.91, 0.87)
	base.material_override = board_surf
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	board_root.add_child(base)

	var rim_mat := _mat(Color(0.36, 0.25, 0.16), 0.78)
	for side_v in [-1.0, 1.0]:
		var sv: float = float(side_v)
		var r_h := MeshInstance3D.new()
		var rhm := BoxMesh.new(); rhm.size = Vector3(board_w + 0.08, 0.06, 0.05)
		r_h.mesh = rhm; r_h.material_override = rim_mat
		r_h.position = Vector3(0.0, 0.006, sv * (board_w * 0.5 + 0.02))
		board_root.add_child(r_h)
		var r_v := MeshInstance3D.new()
		var rvm := BoxMesh.new(); rvm.size = Vector3(0.05, 0.06, board_w + 0.08)
		r_v.mesh = rvm; r_v.material_override = rim_mat
		r_v.position = Vector3(sv * (board_w * 0.5 + 0.02), 0.006, 0.0)
		board_root.add_child(r_v)

	var peg_mat := _mat(Color(0.84, 0.86, 0.90), 0.30)
	var peg_mesh := CylinderMesh.new()
	peg_mesh.top_radius = 0.011
	peg_mesh.bottom_radius = 0.013
	peg_mesh.height = 0.036
	peg_mesh.radial_segments = 6

	var guide_sq := BoxMesh.new()
	guide_sq.size = Vector3(CELL_SZ * 0.88, 0.004, CELL_SZ * 0.88)

	var half_i := float(GRID_N - 1) * 0.5
	for r in range(GRID_N):
		for c in range(GRID_N):
			var cx := (float(c) - half_i) * CELL_SZ
			var cz := (float(r) - half_i) * CELL_SZ
			var peg := MeshInstance3D.new()
			peg.mesh = peg_mesh
			peg.material_override = peg_mat
			peg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			peg.position = Vector3(cx, 0.038, cz)
			board_root.add_child(peg)

			var tgt: int = int(target_grid[r][c])
			if tgt > 0:
				var gsq := MeshInstance3D.new()
				gsq.mesh = guide_sq
				gsq.material_override = guide_unshaded_mats[tgt]
				gsq.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				gsq.position = Vector3(cx, 0.024, cz)
				board_root.add_child(gsq)
				guide_meshes[r][c] = gsq

				# Crisp tiny number offset from center peg pin; hides automatically once bead is placed!
				var num_lbl := Label3D.new()
				num_lbl.text = str(tgt)
				num_lbl.pixel_size = 0.0022
				num_lbl.font_size = 24
				num_lbl.shaded = false
				num_lbl.modulate = Color(1.0, 0.99, 0.96, 0.96)
				num_lbl.outline_modulate = Color(0.05, 0.05, 0.08, 0.98)
				num_lbl.outline_size = 7
				num_lbl.position = Vector3(cx + 0.024, 0.029, cz + 0.024)
				num_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
				board_root.add_child(num_lbl)
				guide_labels[r][c] = num_lbl

	beads_holder = Node3D.new()
	board_root.add_child(beads_holder)

	hover_ring = MeshInstance3D.new()
	var htm := TorusMesh.new()
	htm.inner_radius = 0.046
	htm.outer_radius = 0.060
	htm.rings = 18
	htm.ring_segments = 6
	hover_ring.mesh = htm
	hover_ring.material_override = _mat(Color(1.0, 0.92, 0.45), 0.15, Color(1.0, 0.90, 0.42), 1.85, 0.92)
	hover_ring.visible = false
	board_root.add_child(hover_ring)

	# 2. Physical 3D 8-Compartment Wooden Perler Bead Tray (2 columns x 4 rows on right of desk!)
	var tray_root := Node3D.new()
	tray_root.position = Vector3(1.26, 0.04, 0.08)
	add_child(tray_root)

	var tray_mat := VisualPolish.make_organic_mat(Color(0.45, 0.30, 0.18), 1.8, 0.72, 0.92)
	var tray_base := MeshInstance3D.new()
	var tbm := BoxMesh.new()
	tbm.size = Vector3(0.96, 0.06, 2.08)
	tray_base.mesh = tbm
	tray_base.material_override = tray_mat
	tray_root.add_child(tray_base)

	var rng := RandomNumberGenerator.new()
	rng.seed = 51519
	for i in range(palette.size()):
		var p: Dictionary = palette[i]
		var col: Color = p["color"]
		var col_idx: int = int(p["id"])
		var tc := i % 2
		var tr := i / 2
		var sx := -0.22 + float(tc) * 0.44
		var sz := -0.72 + float(tr) * 0.48
		var slot := Node3D.new()
		slot.position = Vector3(sx, 0.04, sz)
		tray_root.add_child(slot)

		var dish := MeshInstance3D.new()
		var dsm := BoxMesh.new(); dsm.size = Vector3(0.38, 0.03, 0.40)
		dish.mesh = dsm; dish.material_override = _mat(Color(0.24, 0.17, 0.12), 0.82)
		slot.add_child(dish)

		var bmat: Material = bead_mats[col_idx]
		for k in range(10):
			var mb := MeshInstance3D.new()
			mb.mesh = shared_bead_mesh
			mb.material_override = bmat
			mb.scale = Vector3.ONE * 1.12
			mb.position = Vector3(rng.randf_range(-0.12, 0.12), 0.02 + float(k % 2) * 0.022, rng.randf_range(-0.12, 0.12))
			mb.rotation_degrees = Vector3(rng.randf_range(-25, 25), rng.randf_range(0, 360), rng.randf_range(-25, 25))
			slot.add_child(mb)

		var sel_bar := MeshInstance3D.new()
		var sbm := BoxMesh.new(); sbm.size = Vector3(0.38, 0.04, 0.04)
		sel_bar.mesh = sbm
		sel_bar.material_override = _mat(Color(1.0, 0.90, 0.45), 0.2, Color(1.0, 0.88, 0.42), 1.8)
		sel_bar.position = Vector3(0.0, 0.035, 0.21)
		sel_bar.visible = false
		slot.add_child(sel_bar)

		var num_t := Label3D.new()
		num_t.text = str(col_idx)
		num_t.pixel_size = 0.0038
		num_t.font_size = 26
		num_t.shaded = false
		num_t.modulate = Color(1.0, 0.94, 0.72)
		num_t.outline_modulate = Color(0.04, 0.05, 0.07)
		num_t.outline_size = 6
		num_t.position = Vector3(-0.13, 0.06, -0.13)
		num_t.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		slot.add_child(num_t)

		tray_slots.append({
			"id": col_idx, "node": slot, "bar": sel_bar,
			"pos": tray_root.position + Vector3(sx, 0.04, sz), "color": col
		})


func _build_iron_and_parchment() -> void:
	parchment_mesh = MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(2.20, 0.012, 2.20)
	parchment_mesh.mesh = pm
	parchment_mat = _mat(Color(0.99, 0.97, 0.90), 0.72, Color(1.0, 0.96, 0.86), 0.12, 0.56)
	parchment_mesh.material_override = parchment_mat
	parchment_mesh.position = BOARD_ORIGIN + Vector3(0.0, 0.45, 0.0)
	parchment_mesh.visible = false
	add_child(parchment_mesh)

	iron_root = Node3D.new()
	iron_root.position = BOARD_ORIGIN + Vector3(0.0, 0.65, 0.0)
	iron_root.visible = false
	add_child(iron_root)

	var sole_mat := _mat(Color(0.84, 0.86, 0.90), 0.18, Color(1.0, 0.65, 0.30), 0.12, 1.0, 0.75)
	var body_mat := _mat(Color(0.98, 0.94, 0.86), 0.42)
	var mint_mat := _mat(Color(0.42, 0.78, 0.72), 0.48)
	iron_led_mat = _mat(Color(1.0, 0.42, 0.24), 0.2, Color(1.0, 0.46, 0.22), 1.8)

	var sole := MeshInstance3D.new()
	var sm := CylinderMesh.new(); sm.top_radius = 0.24; sm.bottom_radius = 0.28; sm.height = 0.05; sm.radial_segments = 14
	sole.mesh = sm; sole.material_override = sole_mat
	sole.scale = Vector3(0.95, 1.0, 1.45); sole.position = Vector3(0.0, 0.025, 0.0)
	iron_root.add_child(sole)

	var body := MeshInstance3D.new()
	var bm := SphereMesh.new(); bm.radius = 0.23; bm.height = 0.27
	body.mesh = bm; body.material_override = body_mat
	body.scale = Vector3(0.92, 0.85, 1.38); body.position = Vector3(0.0, 0.14, 0.02)
	iron_root.add_child(body)

	var handle := MeshInstance3D.new()
	var hm := TorusMesh.new(); hm.inner_radius = 0.11; hm.outer_radius = 0.16; hm.rings = 16; hm.ring_segments = 8
	handle.mesh = hm; handle.material_override = mint_mat
	handle.position = Vector3(0.0, 0.26, 0.04); handle.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	handle.scale = Vector3(1.25, 0.92, 0.62)
	iron_root.add_child(handle)

	var led := MeshInstance3D.new()
	var lm := SphereMesh.new(); lm.radius = 0.036; lm.height = 0.072
	led.mesh = lm; led.material_override = iron_led_mat
	led.position = Vector3(0.0, 0.22, -0.18)
	iron_root.add_child(led)


func _build_characters() -> void:
	# Protagonist visible in the shop right from the opening intro cutscene!
	player_model = Chibi3D.create(role)
	player_model.position = Vector3(1.85, -1.40, -1.85)
	player_model.rotation_degrees = Vector3(0.0, 175.0, 0.0)
	player_model.visible = true
	add_child(player_model)

	# Partner starts out of sight around the street corner until the wind chime reunion!
	partner_model = Chibi3D.create(partner_role)
	partner_model.position = Vector3(2.35, -1.40, -6.40)
	partner_model.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	partner_model.visible = false
	add_child(partner_model)


func _build_hud_and_quiz_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 1
	add_child(ui_layer)

	var hud := GameUI.build_level_hud(ui_layer, Color(0.98, 0.84, 0.48), _open_settings)
	hud_label = hud["hud_label"]
	hint_label = hud["hint_label"]
	toast_panel = hud["toast_panel"]
	toast_label = hud["toast_label"]
	hint_label.text = "长按左键滑动连拼  ·  1~8 或点豆盒切色（自动高亮当前色号）  ·  算术题按 1~4 快答  ·  ESC 设置"

	# Bottom-center 8-Color Architectural Palette Blade Strip (leaves all 19 pegboard rows 100% clear!)
	palette_bar = HBoxContainer.new()
	palette_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	palette_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	palette_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	palette_bar.offset_left = -545
	palette_bar.offset_right = 545
	palette_bar.offset_top = -132
	palette_bar.offset_bottom = -88
	palette_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	palette_bar.add_theme_constant_override("separation", 6)
	hud["root"].add_child(palette_bar)

	palette_btns.clear()
	for idx in range(palette.size()):
		var p: Dictionary = palette[idx]
		var cid: int = int(p["id"])
		var btn := GameUI.make_blade_button("   [%d] %s" % [cid, str(p["name"])], false, Vector2(126, 38), 13)
		var sw := ColorRect.new()
		sw.color = p["color"]
		sw.position = Vector2(9, 10)
		sw.size = Vector2(14, 18)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(sw)
		var sw_b := ColorRect.new()
		sw_b.color = Color(1.0, 1.0, 1.0, 0.35)
		sw_b.position = Vector2(9, 10)
		sw_b.size = Vector2(14, 1)
		sw_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(sw_b)
		btn.pressed.connect(func(): _select_color(cid, false))
		palette_bar.add_child(btn)
		palette_btns.append(btn)

	# Ironing Progress Bar
	iron_bar_wrap = Control.new()
	iron_bar_wrap.set_anchors_preset(Control.PRESET_CENTER_TOP)
	iron_bar_wrap.offset_left = -210
	iron_bar_wrap.offset_right = 210
	iron_bar_wrap.offset_top = 82
	iron_bar_wrap.offset_bottom = 136
	iron_bar_wrap.visible = false
	iron_bar_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud["root"].add_child(iron_bar_wrap)

	iron_bar_lbl = Label.new()
	iron_bar_lbl.text = "按住左键来回匀速熨烫定型 · 0%"
	iron_bar_lbl.size = Vector2(420, 26)
	iron_bar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUI.style_floating_label(iron_bar_lbl, 16, Color(1.0, 0.92, 0.62), 5)
	iron_bar_wrap.add_child(iron_bar_lbl)

	var track := ColorRect.new()
	track.color = Color(0.06, 0.10, 0.12, 0.85)
	track.position = Vector2(20, 32)
	track.size = Vector2(380, 12)
	iron_bar_wrap.add_child(track)

	iron_bar_fill = ColorRect.new()
	iron_bar_fill.color = Color(1.0, 0.78, 0.34, 0.98)
	iron_bar_fill.position = Vector2(22, 34)
	iron_bar_fill.size = Vector2(0, 8)
	iron_bar_wrap.add_child(iron_bar_fill)

	# Finished Perler Charm Showcase Overlay (floating title + continue blade button!)
	showcase_ui = Control.new()
	showcase_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	showcase_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	showcase_ui.visible = false
	hud["root"].add_child(showcase_ui)

	var sc_title := Label.new()
	var tgt_nm := "女生" if partner_role == "girl" else "男生"
	sc_title.text = "专属 19×19 %s像素拼豆挂件 · 烫制完成！" % tgt_nm
	sc_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sc_title.offset_left = -360
	sc_title.offset_right = 360
	sc_title.offset_top = 86
	sc_title.offset_bottom = 128
	sc_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUI.style_floating_label(sc_title, 26, Color(1.0, 0.94, 0.74), 6)
	showcase_ui.add_child(sc_title)

	var sc_sub := Label.new()
	sc_sub.text = "按住鼠标左键可 360° 旋转细赏你的手作作品"
	sc_sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sc_sub.offset_left = -260
	sc_sub.offset_right = 260
	sc_sub.offset_top = 128
	sc_sub.offset_bottom = 158
	sc_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUI.style_floating_label(sc_sub, 14, Color(0.84, 0.92, 0.94), 4)
	showcase_ui.add_child(sc_sub)

	var sc_btn := GameUI.make_blade_button("捧好挂件，等待 TA 推门而来  [Space]", true, Vector2(360, 46), 17)
	sc_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	sc_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sc_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sc_btn.offset_left = -180
	sc_btn.offset_right = 180
	sc_btn.offset_top = -148
	sc_btn.offset_bottom = -102
	sc_btn.pressed.connect(_start_reunion_from_showcase)
	showcase_ui.add_child(sc_btn)

	# Mental Math Quiz Overlay (Chamfered Slate & Brass Panel)
	quiz_overlay = Control.new()
	quiz_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	quiz_overlay.visible = false
	hud["root"].add_child(quiz_overlay)

	var q_dim := ColorRect.new()
	q_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	q_dim.color = Color(0.03, 0.05, 0.08, 0.52)
	quiz_overlay.add_child(q_dim)

	var q_center := CenterContainer.new()
	q_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	quiz_overlay.add_child(q_center)

	var q_card := PanelContainer.new()
	q_card.custom_minimum_size = Vector2(470, 285)
	q_card.add_theme_stylebox_override("panel", GameUI.make_chamfer_panel_style(
		Color(0.07, 0.11, 0.14, 0.97), Color(0.96, 0.82, 0.44, 0.96), 14, 24
	))
	q_center.add_child(q_card)

	var qvb := VBoxContainer.new()
	qvb.alignment = BoxContainer.ALIGNMENT_CENTER
	qvb.add_theme_constant_override("separation", 12)
	q_card.add_child(qvb)

	var q_hdr := Label.new()
	q_hdr.text = "脑海突然闪过一道算术题！"
	q_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUI.style_floating_label(q_hdr, 16, Color(1.0, 0.86, 0.48), 4)
	qvb.add_child(q_hdr)

	quiz_eq_lbl = Label.new()
	quiz_eq_lbl.text = "7 × 8 = ?"
	quiz_eq_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUI.style_floating_label(quiz_eq_lbl, 36, Color(1.0, 0.98, 0.92), 5)
	qvb.add_child(quiz_eq_lbl)

	var qt_wrap := Control.new()
	qt_wrap.custom_minimum_size = Vector2(390, 22)
	qt_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	qvb.add_child(qt_wrap)

	var qt_bg := ColorRect.new()
	qt_bg.color = Color(0.14, 0.18, 0.22, 0.95)
	qt_bg.position = Vector2(0, 6)
	qt_bg.size = Vector2(320, 10)
	qt_wrap.add_child(qt_bg)

	quiz_timer_fill = ColorRect.new()
	quiz_timer_fill.color = Color(0.98, 0.80, 0.34, 1.0)
	quiz_timer_fill.position = Vector2(0, 6)
	quiz_timer_fill.size = Vector2(320, 10)
	qt_wrap.add_child(quiz_timer_fill)

	quiz_timer_lbl = Label.new()
	quiz_timer_lbl.position = Vector2(330, 0)
	GameUI.style_floating_label(quiz_timer_lbl, 14, Color(1.0, 0.92, 0.72), 3)
	qt_wrap.add_child(quiz_timer_lbl)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	qvb.add_child(grid)

	quiz_opt_btns.clear()
	for i in range(4):
		var ob := GameUI.make_blade_button("[%d] 0" % (i + 1), false, Vector2(184, 44), 18)
		var opt_idx := i
		ob.pressed.connect(func(): _answer_quiz(opt_idx))
		grid.add_child(ob)
		quiz_opt_btns.append(ob)


func _select_color(cid: int, silent: bool = false) -> void:
	selected_color = clampi(cid, 1, palette.size())
	for i in range(palette_btns.size()):
		var btn := palette_btns[i]
		var is_sel := (i + 1 == selected_color)
		btn.modulate = Color(1.08, 1.04, 0.94) if is_sel else Color(0.76, 0.78, 0.80)
		var border_col := Color(1.0, 0.90, 0.50, 1.0) if is_sel else Color(0.60, 0.58, 0.46, 0.78)
		var bg_col := Color(0.14, 0.32, 0.28, 0.96) if is_sel else Color(0.07, 0.14, 0.15, 0.90)
		btn.add_theme_stylebox_override("normal", GameUI.make_chamfer_stylebox(
			bg_col, border_col, Color(border_col.r, border_col.g, border_col.b, 0.25), 7, 3 if is_sel else 0, border_col, 12, 6
		))
	for ts in tray_slots:
		(ts["bar"] as Node3D).visible = (int(ts["id"]) == selected_color)

	# Uniformly highlight all guide cells matching selected_color & softly dim others (100% consistent unshaded color!)
	for r in range(GRID_N):
		for c in range(GRID_N):
			var gm: MeshInstance3D = guide_meshes[r][c]
			if gm != null:
				var tgt: int = int(target_grid[r][c])
				gm.material_override = guide_unshaded_mats[tgt] if tgt == selected_color else guide_dim_mats[tgt]
			var gl: Label3D = guide_labels[r][c]
			if gl != null and int(placed_grid[r][c]) == 0:
				var tgt_l: int = int(target_grid[r][c])
				gl.modulate.a = 1.0 if tgt_l == selected_color else 0.38

	if not silent:
		SoundFX.play("ui_hover", -15.0, 0.90 + float(selected_color) * 0.035)


func _refresh_hud() -> void:
	if hud_label == null:
		return
	var stage_txt := "寻觅开场"
	if phase == "craft":
		stage_txt = "拼豆进度 %d/%d" % [placed_count, total_beads]
	elif phase == "iron":
		stage_txt = "熨烫定型 %d%%" % int(iron_progress * 100.0)
	elif phase == "showcase":
		stage_txt = "成品特写展示"
	elif phase == "reunion" or phase == "done":
		stage_txt = "风铃推门 · 手作重逢"
	hud_label.text = "第 5 关 · 微光拼豆屋   |   %s   |   用时 %.1fs   |   算术 %d对/%d错" % [
		stage_txt, elapsed_time, quiz_right, quiz_wrong
	]


func _show_toast(msg: String, dur: float = 3.5) -> void:
	if toast_label == null or toast_panel == null:
		return
	toast_label.text = msg
	toast_timer = dur
	GameUI.animate_toast_in(toast_panel)


func _open_settings() -> void:
	if cleared or get_tree().paused:
		return
	var sui := SettingsUI.open(self, true)
	sui.back_to_menu_requested.connect(func(): back_to_select.emit())
	sui.restart_requested.connect(func(): restart_level.emit())


func _enter_craft_phase() -> void:
	if phase != "intro":
		return
	phase = "craft"
	player_model.visible = false
	palette_bar.visible = true
	last_drag_rc = Vector2i(-1, -1)
	camera.look_at_from_position(Vector3(0.08, 3.40, 2.08), Vector3(0.08, 0.02, 0.24), Vector3.UP)
	var tgt_name := "女生" if partner_role == "girl" else "男生"
	_show_toast("开始拼制【%s 19×19 像素头像】！长按鼠标左键可连续滑动铺豆，按 1~8 切色~" % tgt_name, 4.5)


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_open_settings()
			return
		if event.keycode == KEY_M:
			SoundFX.toggle_mute()
			return
		if phase == "intro" and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
			_enter_craft_phase()
			return
		if phase == "showcase" and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
			_start_reunion_from_showcase()
			return
		if quiz_active:
			if event.keycode >= KEY_1 and event.keycode <= KEY_4:
				_answer_quiz(event.keycode - KEY_1)
			elif event.keycode >= KEY_KP_1 and event.keycode <= KEY_KP_4:
				_answer_quiz(event.keycode - KEY_KP_1)
			return
		if phase == "craft":
			if event.keycode >= KEY_1 and event.keycode <= KEY_8:
				_select_color(event.keycode - KEY_1 + 1, false)
			elif event.keycode >= KEY_KP_1 and event.keycode <= KEY_KP_8:
				_select_color(event.keycode - KEY_KP_1 + 1, false)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if phase == "craft" and not quiz_active:
			if event.pressed:
				last_drag_rc = Vector2i(-1, -1)
				_handle_craft_click(event.position, false)
			else:
				last_drag_rc = Vector2i(-1, -1)
		elif phase == "iron":
			iron_pressing = event.pressed
		elif phase == "showcase":
			showcase_dragging = event.pressed
			showcase_last_mouse = event.position
	elif event is InputEventMouseMotion and phase == "showcase" and showcase_dragging:
		var rel: Vector2 = event.position - showcase_last_mouse
		showcase_last_mouse = event.position
		showcase_rot_y += rel.x * 0.012
		showcase_rot_x = clampf(showcase_rot_x + rel.y * 0.008, -0.55, 0.55)


func _ray_plane_hit(screen_pos: Vector2, plane_y: float) -> Variant:
	if camera == null:
		return null
	var orig := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	return Plane(Vector3.UP, plane_y).intersects_ray(orig, dir)


func _world_to_rc(hp: Vector3) -> Vector2i:
	var half_i := float(GRID_N - 1) * 0.5
	var c := roundi((hp.x - BOARD_ORIGIN.x) / CELL_SZ + half_i)
	var r := roundi((hp.z - BOARD_ORIGIN.z) / CELL_SZ + half_i)
	return Vector2i(r, c)


func _handle_craft_click(screen_pos: Vector2, is_drag: bool) -> void:
	var hit: Variant = _ray_plane_hit(screen_pos, 0.065)
	if hit == null:
		return
	var hp: Vector3 = hit

	if not is_drag:
		for ts in tray_slots:
			var tp: Vector3 = ts["pos"]
			if absf(hp.x - tp.x) < 0.21 and absf(hp.z - tp.z) < 0.22:
				_select_color(int(ts["id"]), false)
				return

	var rc := _world_to_rc(hp)
	if rc.x < 0 or rc.x >= GRID_N or rc.y < 0 or rc.y >= GRID_N:
		return
	_try_place_bead(rc.x, rc.y, is_drag)
	last_drag_rc = rc


func _sweep_place_line(from_rc: Vector2i, to_rc: Vector2i) -> void:
	## Bresenham grid line sweep: guarantees ZERO skipped beads when sliding mouse rapidly across rows!
	var r0 := from_rc.x
	var c0 := from_rc.y
	var r1 := to_rc.x
	var c1 := to_rc.y
	var dr := absi(r1 - r0)
	var dc := absi(c1 - c0)
	var sr := 1 if r0 < r1 else -1
	var sc := 1 if c0 < c1 else -1
	var err := dr - dc
	while true:
		if r0 >= 0 and r0 < GRID_N and c0 >= 0 and c0 < GRID_N:
			_try_place_bead(r0, c0, true)
			if phase != "craft" or quiz_active:
				return
		if r0 == r1 and c0 == c1:
			break
		var e2 := 2 * err
		if e2 > -dc:
			err -= dc
			r0 += sr
		if e2 < dr:
			err += dr
			c0 += sc


func _try_place_bead(r: int, c: int, is_drag: bool) -> void:
	var need: int = int(target_grid[r][c])
	if need <= 0 or int(placed_grid[r][c]) > 0:
		return
	if selected_color != need:
		if not is_drag and wrong_hint_cd <= 0.0:
			wrong_hint_cd = 0.65
			var pname: String = str(palette[need - 1]["name"])
			SoundFX.play("ui_hover", -13.0, 0.78)
			_show_toast("这一格需要 [%d号 · %s] 豆子，按 %d 键切色即可长按滑动铺豆~" % [need, pname, need], 2.2)
		return

	placed_grid[r][c] = need
	placed_count += 1
	beads_since_quiz += 1
	place_combo = mini(18, place_combo + 1)
	combo_decay = 1.2

	var gl: Label3D = guide_labels[r][c]
	if gl != null:
		gl.visible = false

	var b := MeshInstance3D.new()
	b.mesh = shared_bead_mesh
	b.material_override = bead_mats[need]
	var half_i := float(GRID_N - 1) * 0.5
	var cx := (float(c) - half_i) * CELL_SZ
	var cz := (float(r) - half_i) * CELL_SZ
	b.position = Vector3(cx, 0.026, cz)
	b.scale = Vector3(0.25, 0.25, 0.25)
	beads_holder.add_child(b)
	bead_nodes[r][c] = b

	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(b, "scale", Vector3.ONE, 0.14)

	var pitch := clampf(0.92 + float(place_combo) * 0.022 + randf_range(-0.02, 0.02), 0.88, 1.38)
	SoundFX.play("bead_place", -6.0, pitch)
	GameUI.pulse_hud(hud_label)

	if placed_count >= total_beads:
		_enter_iron_phase()
	elif beads_since_quiz >= 52 and placed_count <= total_beads - 12:
		_trigger_quiz()


func _trigger_quiz() -> void:
	if quiz_active or phase != "craft" or placed_count >= total_beads:
		return
	quiz_active = true
	last_drag_rc = Vector2i(-1, -1)
	beads_since_quiz = 0
	time_since_quiz = 0.0
	quiz_timer = QUIZ_DURATION

	var op := randi() % 4
	var a := 0
	var b := 0
	var ans := 0
	var eq := ""
	if op == 0:
		a = randi_range(12, 46); b = randi_range(9, 38); ans = a + b; eq = "%d + %d = ?" % [a, b]
	elif op == 1:
		a = randi_range(24, 68); b = randi_range(7, a - 6); ans = a - b; eq = "%d - %d = ?" % [a, b]
	elif op == 2:
		a = randi_range(3, 9); b = randi_range(4, 9); ans = a * b; eq = "%d × %d = ?" % [a, b]
	else:
		b = randi_range(2, 9); ans = randi_range(3, 9); a = b * ans; eq = "%d ÷ %d = ?" % [a, b]

	var opts: Array[int] = [ans]
	var offsets := [-10, -4, -3, -2, -1, 1, 2, 3, 4, 10]
	offsets.shuffle()
	for off in offsets:
		if opts.size() >= 4:
			break
		var cand: int = ans + int(off)
		if cand > 0 and not opts.has(cand):
			opts.append(cand)
	opts.shuffle()
	quiz_correct_idx = opts.find(ans)

	quiz_eq_lbl.text = eq
	for i in range(4):
		quiz_opt_btns[i].text = "[%d]  %d" % [i + 1, opts[i]]

	quiz_overlay.visible = true
	SoundFX.play("quiz_pop", -5.0)


func _answer_quiz(choice_idx: int) -> void:
	if not quiz_active:
		return
	quiz_active = false
	quiz_overlay.visible = false
	if choice_idx == quiz_correct_idx:
		quiz_right += 1
		SoundFX.play("quiz_ok", -4.5)
		GameJuice.spawn_splash(self, BOARD_ORIGIN + Vector3(0.0, 0.22, 0.0), Color(1.0, 0.90, 0.48), 10, 0.65, false)
		_show_toast("答对啦！思路清晰，继续滑动铺豆~", 2.0)
	else:
		_apply_quiz_shake_penalty("算错啦！手一抖把拼豆板震歪了，震飞了几颗豆子！")


func _apply_quiz_shake_penalty(msg: String) -> void:
	quiz_wrong += 1
	place_combo = 0
	board_shake_t = 0.56
	SoundFX.play("bead_scatter", -3.5)
	GameJuice.hitstop(0.055, 0.08)
	GameJuice.add_trauma(0.50)

	var filled: Array[Vector2i] = []
	for r in range(GRID_N):
		for c in range(GRID_N):
			if int(placed_grid[r][c]) > 0:
				filled.append(Vector2i(r, c))
	filled.shuffle()
	var max_remove := maxi(0, filled.size() - 4)
	var remove_n := mini(max_remove, randi_range(5, 8))
	for i in range(remove_n):
		var rc := filled[i]
		var cid: int = int(placed_grid[rc.x][rc.y])
		var col: Color = palette[cid - 1]["color"]
		placed_grid[rc.x][rc.y] = 0
		placed_count = maxi(0, placed_count - 1)
		var gl: Label3D = guide_labels[rc.x][rc.y]
		if gl != null:
			gl.visible = true
		var bn: MeshInstance3D = bead_nodes[rc.x][rc.y]
		if bn and is_instance_valid(bn):
			var wpos := bn.global_position
			bn.queue_free()
			GameJuice.spawn_splash(self, wpos, col, 3, 0.62, false)
		bead_nodes[rc.x][rc.y] = null
	_show_toast(msg, 3.2)


func _enter_iron_phase() -> void:
	phase = "iron"
	quiz_active = false
	quiz_overlay.visible = false
	last_drag_rc = Vector2i(-1, -1)
	hover_ring.visible = false
	palette_bar.visible = false
	iron_bar_wrap.visible = true
	iron_progress = 0.0
	iron_done_triggered = false

	parchment_mesh.visible = true
	parchment_mesh.position = BOARD_ORIGIN + Vector3(0.0, 0.55, 0.0)
	parchment_mat.albedo_color.a = 0.58
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(parchment_mesh, "position:y", BOARD_ORIGIN.y + 0.105, 0.45)

	iron_root.visible = true
	iron_pos = Vector2(BOARD_ORIGIN.x, BOARD_ORIGIN.z)
	iron_root.position = Vector3(iron_pos.x, 0.24, iron_pos.y)
	SoundFX.play("keepsake", -5.0)
	hint_label.text = "按住鼠标左键（或按住 WASD / Space）移动小熨斗在拼豆板上均匀来回熨烫定型！"
	_show_toast("全部豆子拼完啦！盖上隔热纸，按住左键用小熨斗均匀熨烫定型吧~", 4.0)


func _build_fused_charm_node(charm_scale: float) -> Node3D:
	## Builds the glossy iron-fused 19x19 Perler charm with golden keyring loop & subtle backing!
	var root_c := Node3D.new()
	var half_i := float(GRID_N - 1) * 0.5
	for r in range(GRID_N):
		for c in range(GRID_N):
			var cid: int = int(target_grid[r][c])
			if cid <= 0:
				continue
			var mb := MeshInstance3D.new()
			mb.mesh = shared_fused_mesh
			mb.material_override = bead_mats[cid]
			mb.scale = Vector3.ONE * charm_scale
			mb.position = Vector3(
				(float(c) - half_i) * CELL_SZ * charm_scale,
				(half_i - float(r)) * CELL_SZ * charm_scale,
				0.0
			)
			mb.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			root_c.add_child(mb)

	# Gleaming upright golden keyring loop attached cleanly to top crown of the charm!
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.08 * charm_scale
	tm.outer_radius = 0.115 * charm_scale
	ring.mesh = tm
	ring.material_override = _mat(Color(1.0, 0.85, 0.34), 0.20, Color(1.0, 0.82, 0.30), 0.55, 1.0, 0.78)
	ring.position = Vector3(0.0, (half_i + 1.0) * CELL_SZ * charm_scale, 0.02 * charm_scale)
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	root_c.add_child(ring)
	return root_c


func _enter_showcase_phase() -> void:
	if iron_done_triggered:
		return
	iron_done_triggered = true
	finish_time = elapsed_time
	iron_bar_wrap.visible = false
	iron_root.visible = false

	# Peel parchment paper off cleanly
	var ptw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	ptw.tween_property(parchment_mesh, "position:y", BOARD_ORIGIN.y + 0.88, 0.50)
	ptw.parallel().tween_property(parchment_mat, "albedo_color:a", 0.0, 0.50)
	ptw.tween_callback(func(): parchment_mesh.visible = false)

	# Fuse beads on board visually & pop golden sparkles
	for r in range(GRID_N):
		for c in range(GRID_N):
			var bn: MeshInstance3D = bead_nodes[r][c]
			if bn and is_instance_valid(bn):
				bn.mesh = shared_fused_mesh
				bn.scale = Vector3.ONE
	GameJuice.spawn_splash(self, BOARD_ORIGIN + Vector3(0.0, 0.16, 0.0), Color(1.0, 0.90, 0.52), 22, 1.0, true)
	SoundFX.play("keepsake", -3.5, 1.08)

	# Build glowing 3D Showcase Stage floating smoothly above the workbench!
	phase = "showcase"
	showcase_t = 0.0
	showcase_rot_y = 0.0
	showcase_rot_x = 0.06
	showcase_dragging = false

	showcase_root = Node3D.new()
	showcase_root.position = Vector3(0.0, 1.42, 0.0)
	add_child(showcase_root)

	showcase_charm = _build_fused_charm_node(0.52)
	showcase_charm.scale = Vector3.ONE * 0.12
	showcase_root.add_child(showcase_charm)
	var stw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	stw.tween_property(showcase_charm, "scale", Vector3.ONE, 0.55)

	# Warm rim spotlight & orbiting sparkle stars around the finished charm!
	var sp_light := OmniLight3D.new()
	sp_light.light_color = Color(1.0, 0.92, 0.72)
	sp_light.light_energy = 1.45
	sp_light.omni_range = 4.2
	sp_light.position = Vector3(0.55, 0.65, 1.15)
	showcase_root.add_child(sp_light)

	showcase_sparkles.clear()
	var sp_mat := _mat(Color(1.0, 0.92, 0.45), 0.18, Color(1.0, 0.90, 0.40), 1.8)
	for i in range(8):
		var stn := Node3D.new()
		for ax in [Vector3(0.11, 0.025, 0.025), Vector3(0.025, 0.11, 0.025), Vector3(0.025, 0.025, 0.11)]:
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new(); bm.size = ax
			b.mesh = bm; b.material_override = sp_mat
			stn.add_child(b)
		showcase_root.add_child(stn)
		showcase_sparkles.append({"node": stn, "ang": float(i) / 8.0 * TAU, "rad": 0.92 + float(i % 2) * 0.22, "y": randf_range(-0.45, 0.55)})

	showcase_ui.visible = true
	hint_label.text = "按住左键 360° 欣赏你的手作像素拼豆成品  ·  点击下方按钮或按 Space 迎接 TA 进门"
	_show_toast("哇！亲手烫好的像素拼豆挂件闪闪发光，真精致呀！", 3.6)


func _start_reunion_from_showcase() -> void:
	if phase != "showcase":
		return
	showcase_ui.visible = false
	if showcase_root and is_instance_valid(showcase_root):
		showcase_root.queue_free()
		showcase_root = null

	# Attach miniature finished charm into protagonist's hands!
	held_charm = _build_fused_charm_node(0.24)
	held_charm.position = Vector3(0.0, 0.86, 0.44)
	player_model.add_child(held_charm)

	phase = "reunion"
	reunion_t = 0.0
	reunion_stage = 0
	player_model.visible = true
	player_model.position = Vector3(2.95, -1.40, 0.55)
	player_model.rotation_degrees = Vector3(0.0, 175.0, 0.0)
	partner_model.visible = true
	partner_model.position = Vector3(2.35, -1.40, -5.65)
	partner_model.rotation_degrees = Vector3(0.0, 0.0, 0.0)

	# 4-tier attitude rating (calibrated generously for 19x19 swipe-craft + ironing!)
	var mood_score := finish_time + float(quiz_wrong) * 7.0
	if mood_score <= 95.0:
		finale_tier = 1
		finale_mood_name = "惊喜心动 · 星星眼"
		finale_mood_quote = "哇！我刚推开门就赶上热乎乎出炉！你手也太巧了吧，这个像素头像超像我、超精致，我要天天挂包上！"
	elif mood_score <= 135.0:
		finale_tier = 2
		finale_mood_name = "温柔开心 · 微笑"
		finale_mood_quote = "原来你躲在这里偷偷给我做礼物呀~ 这个温热的拼豆头像好可爱，谢谢你亲手做给我！"
	elif mood_score <= 175.0:
		finale_tier = 3
		finale_mood_name = "小傲娇 · 轻哼吐槽"
		finale_mood_quote = "哼，我都在外面逛完一圈找你啦，你居然还在跟小豆子较劲！……不过看在拼得这么精致的份上，勉强收下吧~"
	else:
		finale_tier = 4
		finale_mood_name = "气鼓鼓 · 搞笑治愈"
		finale_mood_quote = "天都快黑了！刚才是不是算术题答错手抖震翻好几次啦？……噗嗤，看你满头大汗还认真烫得这么好看，原谅你啦！"

	SoundFX.play("door_chime", -3.0)
	var dtw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	dtw.tween_property(shop_door_pivot, "rotation_degrees:y", -82.0, 0.85)
	_show_toast("叮咚~ 刚捧好挂件，店门风铃响起，TA 顺着暖光推门走进来啦！", 3.2)


func _make_3d_heart_badge(col: Color, scale_f: float = 1.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	for i in range(28):
		var a := float(i) / 28.0 * TAU
		var hx := 16.0 * pow(sin(a), 3.0) * 0.017 * scale_f
		var hy := (13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a)) * 0.017 * scale_f
		pts.append(Vector3(hx, hy, 0.0))
	var cf := Vector3(0.0, 0.03 * scale_f, 0.095 * scale_f)
	var cb := Vector3(0.0, 0.03 * scale_f, -0.095 * scale_f)
	for i in range(pts.size()):
		var n := (i + 1) % pts.size()
		st.add_vertex(cf); st.add_vertex(pts[i]); st.add_vertex(pts[n])
		st.add_vertex(cb); st.add_vertex(pts[n]); st.add_vertex(pts[i])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat(col, 0.22, col, 1.25)
	return mi


func _spawn_emotion_badge(tier: int) -> void:
	if emotion_badge and is_instance_valid(emotion_badge):
		emotion_badge.queue_free()
	emotion_badge = Node3D.new()
	emotion_badge.position = partner_model.position + Vector3(0.0, 2.35, 0.0)
	add_child(emotion_badge)

	if tier == 1:
		emotion_badge.add_child(_make_3d_heart_badge(Color(1.0, 0.34, 0.56), 1.35))
		var sm := _mat(Color(1.0, 0.92, 0.36), 0.18, Color(1.0, 0.90, 0.32), 1.6)
		for spos in [Vector3(0.40, 0.22, 0.05), Vector3(-0.38, -0.14, -0.04)]:
			var stn := Node3D.new()
			stn.position = spos
			for ax in [Vector3(0.22, 0.05, 0.05), Vector3(0.05, 0.22, 0.05)]:
				var b := MeshInstance3D.new()
				var bm := BoxMesh.new(); bm.size = ax
				b.mesh = bm; b.material_override = sm
				stn.add_child(b)
			emotion_badge.add_child(stn)
	elif tier == 2:
		emotion_badge.add_child(_make_3d_heart_badge(Color(1.0, 0.62, 0.74), 1.08))
	elif tier == 3:
		var cm := _mat(Color(0.76, 0.80, 0.90), 0.72, Color(0.55, 0.62, 0.78), 0.32)
		for puff in [
			[Vector3(0.0, 0.10, 0.0), Vector3(0.40, 0.30, 0.28)],
			[Vector3(-0.22, 0.02, 0.0), Vector3(0.30, 0.24, 0.24)],
			[Vector3(0.22, 0.02, 0.0), Vector3(0.30, 0.24, 0.24)],
		]:
			var sp := MeshInstance3D.new()
			var sm := SphereMesh.new(); sm.radius = 0.5; sm.height = 1.0
			sp.mesh = sm; sp.material_override = cm
			sp.position = puff[0]; sp.scale = puff[1]
			emotion_badge.add_child(sp)
		var dm := _mat(Color(0.38, 0.88, 1.0), 0.14, Color(0.32, 0.82, 1.0), 1.05)
		var dr := MeshInstance3D.new()
		var drm := SphereMesh.new(); drm.radius = 0.09; drm.height = 0.22
		dr.mesh = drm; dr.material_override = dm
		dr.position = Vector3(0.0, -0.22, 0.0)
		emotion_badge.add_child(dr)
	else:
		var am := _mat(Color(1.0, 0.36, 0.16), 0.24, Color(1.0, 0.30, 0.12), 1.65)
		for quad in [[1.0, 1.0], [-1.0, 1.0], [1.0, -1.0], [-1.0, -1.0]]:
			var sx: float = float(quad[0]); var sy: float = float(quad[1])
			var hb := MeshInstance3D.new()
			var hbm := BoxMesh.new(); hbm.size = Vector3(0.22, 0.09, 0.10)
			hb.mesh = hbm; hb.material_override = am
			hb.position = Vector3(sx * 0.18, sy * 0.10, 0.0)
			emotion_badge.add_child(hb)
			var vb := MeshInstance3D.new()
			var vbm := BoxMesh.new(); vbm.size = Vector3(0.09, 0.22, 0.10)
			vb.mesh = vbm; vb.material_override = am
			vb.position = Vector3(sx * 0.10, sy * 0.18, 0.0)
			emotion_badge.add_child(vb)

	if is_inside_tree():
		emotion_badge.scale = Vector3.ONE * 0.1
		var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(emotion_badge, "scale", Vector3.ONE, 0.28)


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	var t := Time.get_ticks_msec() * 0.001

	if toast_timer > 0.0:
		toast_timer -= dt
		if toast_timer <= 0.0 and toast_panel:
			toast_panel.visible = false
	if wrong_hint_cd > 0.0:
		wrong_hint_cd = maxf(0.0, wrong_hint_cd - dt)
	if combo_decay > 0.0:
		combo_decay -= dt
		if combo_decay <= 0.0:
			place_combo = 0

	if board_shake_t > 0.0:
		board_shake_t = maxf(0.0, board_shake_t - dt)
		var amp := (board_shake_t / 0.56) * 0.14
		board_root.position = BOARD_ORIGIN + Vector3(sin(t * 52.0) * amp, 0.0, cos(t * 44.0) * amp * 0.5)
		board_root.rotation_degrees.z = sin(t * 48.0) * amp * 28.0
	else:
		board_root.position = BOARD_ORIGIN
		board_root.rotation_degrees.z = 0.0

	for i in range(steam_puffs.size() - 1, -1, -1):
		var sp: Dictionary = steam_puffs[i]
		var sn: MeshInstance3D = sp["node"]
		sp["age"] = float(sp["age"]) + dt
		var u: float = float(sp["age"]) / float(sp["life"])
		if u >= 1.0 or not is_instance_valid(sn):
			if is_instance_valid(sn):
				sn.queue_free()
			steam_puffs.remove_at(i)
			continue
		sn.position += Vector3(float(sp["vx"]), 0.65, float(sp["vz"])) * dt
		sn.scale = Vector3.ONE * lerpf(0.55, 1.85, u)
		(sp["mat"] as StandardMaterial3D).albedo_color.a = (1.0 - u) * 0.52

	if phase == "intro":
		_update_intro(dt, t)
	elif phase == "craft":
		_update_craft(dt, t)
	elif phase == "iron":
		_update_iron(dt, t)
	elif phase == "showcase":
		_update_showcase(dt, t)
	elif phase == "reunion":
		_update_reunion(dt, t)

	GameJuice.apply_camera_shake(camera, 0.16, 0.12)
	_refresh_hud()


func _update_intro(dt: float, t: float) -> void:
	intro_t += dt
	if intro_t < 2.15:
		# Stage 1: Protagonist looks around shop & empty twilight window realizing TA is gone!
		player_model.position = Vector3(1.85, -1.40, -2.05)
		player_model.rotation_degrees = Vector3(0.0, 180.0 + sin(t * 2.8) * 38.0, 0.0)
		player_model.head_target_yaw = sin(t * 3.4) * 0.55
		player_model.update_anim(false, false, dt)
		var cam_p := Vector3(3.15 - intro_t * 0.22, 0.72, 1.85)
		camera.look_at_from_position(cam_p, Vector3(1.15, -0.15, -1.65), Vector3.UP)
	elif intro_t < 5.05:
		# Stage 2: Protagonist walks cleanly AROUND the right side of the oak desk (zero desk clipping!)
		if intro_stage == 0:
			intro_stage = 1
			SoundFX.play("mushroom", -6.0, 1.12)
			var tgt_nm := "女生" if partner_role == "girl" else "男生"
			_show_toast("听说微光拼豆屋很灵验——亲手拼出代表 TA 的【%s头像】挂件，TA 就会顺着暖光找来！快坐下开工吧~" % tgt_nm, 3.4)
		var u := clampf((intro_t - 2.15) / 2.25, 0.0, 1.0)
		var prev_pos := player_model.position
		var p0 := Vector3(1.85, -1.40, -2.05)
		var p1 := Vector3(2.98, -1.40, -1.48)
		var p2 := Vector3(2.98, -1.40, 1.78)
		var p3 := Vector3(0.00, -1.40, 1.78)
		var next_pos := p3
		if u < 0.25:
			next_pos = p0.lerp(p1, u / 0.25)
		elif u < 0.65:
			next_pos = p1.lerp(p2, (u - 0.25) / 0.40)
		else:
			next_pos = p2.lerp(p3, (u - 0.65) / 0.35)
		player_model.position = next_pos
		var step_v := next_pos - prev_pos
		if u < 0.98 and Vector2(step_v.x, step_v.z).length() > 0.001:
			var walk_yaw := atan2(step_v.x, step_v.z)
			player_model.rotation.y = lerp_angle(player_model.rotation.y, walk_yaw, minf(1.0, dt * 12.0))
		else:
			# Turn cleanly to face the workbench (-Z) once seated at the crafting side!
			player_model.rotation.y = lerp_angle(player_model.rotation.y, PI, minf(1.0, dt * 10.0))
		player_model.head_target_yaw = 0.0
		player_model.update_anim(u < 0.96, false, dt)

		var cam_u := clampf((intro_t - 2.75) / 2.25, 0.0, 1.0)
		var cam_s := Vector3(2.68, 0.72, 1.85)
		var cam_e := Vector3(0.08, 3.40, 2.08)
		var look_s := Vector3(1.15, -0.15, -1.65)
		var look_e := Vector3(0.08, 0.02, 0.24)
		var ease_u := cam_u * cam_u * (3.0 - 2.0 * cam_u)
		camera.look_at_from_position(cam_s.lerp(cam_e, ease_u), look_s.lerp(look_e, ease_u), Vector3.UP)
	else:
		_enter_craft_phase()


func _update_craft(dt: float, _t: float) -> void:
	elapsed_time += dt

	if quiz_active:
		quiz_timer = maxf(0.0, quiz_timer - dt)
		var frac := clampf(quiz_timer / QUIZ_DURATION, 0.0, 1.0)
		quiz_timer_fill.size.x = 320.0 * frac
		quiz_timer_fill.color = Color(0.98, 0.80, 0.34).lerp(Color(1.0, 0.32, 0.28), 1.0 - frac)
		quiz_timer_lbl.text = "%.1fs" % quiz_timer
		if quiz_timer <= 0.0:
			quiz_active = false
			quiz_overlay.visible = false
			_apply_quiz_shake_penalty("超时啦！走神手一滑震翻了拼豆板，几颗豆子飞出去啦！")
		return

	time_since_quiz += dt
	if time_since_quiz >= 22.0 and placed_count >= 12 and placed_count <= total_beads - 12:
		_trigger_quiz()
		return

	# Smooth hold-left-mouse continuous Bresenham swipe painting!
	var mpos := get_viewport().get_mouse_position()
	var left_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not left_down:
		last_drag_rc = Vector2i(-1, -1)

	var hit: Variant = _ray_plane_hit(mpos, 0.065)
	if hit != null:
		var hp: Vector3 = hit
		var rc := _world_to_rc(hp)
		var half_i := float(GRID_N - 1) * 0.5
		if rc.x >= 0 and rc.x < GRID_N and rc.y >= 0 and rc.y < GRID_N:
			if int(target_grid[rc.x][rc.y]) > 0 and int(placed_grid[rc.x][rc.y]) == 0:
				hover_ring.visible = true
				hover_ring.position = Vector3((float(rc.y) - half_i) * CELL_SZ, 0.048, (float(rc.x) - half_i) * CELL_SZ)
			else:
				hover_ring.visible = false

			if left_down:
				# Ignore clicks down in the HUD palette strip region
				var vp_h := get_viewport().get_visible_rect().size.y
				if mpos.y < vp_h - 134.0:
					if last_drag_rc.x >= 0:
						_sweep_place_line(last_drag_rc, rc)
					else:
						_try_place_bead(rc.x, rc.y, true)
					last_drag_rc = rc
		else:
			hover_ring.visible = false
			if not left_down:
				last_drag_rc = Vector2i(-1, -1)
	else:
		hover_ring.visible = false

	var target_cam := Vector3(0.08, 3.40, 2.08)
	camera.position = camera.position.lerp(target_cam, minf(1.0, dt * 6.0))
	camera.look_at(Vector3(0.08, 0.02, 0.24), Vector3.UP)


func _update_iron(dt: float, t: float) -> void:
	elapsed_time += dt
	camera.position = camera.position.lerp(Vector3(-0.40, 2.42, 1.52), minf(1.0, dt * 5.0))
	camera.look_at(BOARD_ORIGIN + Vector3(0.0, 0.05, 0.0), Vector3.UP)

	var kb_dir := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	var active_press := iron_pressing or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("jump") or kb_dir.length() > 0.1
	if kb_dir.length() > 0.1:
		iron_pos += kb_dir.normalized() * 1.9 * dt
	else:
		var hit: Variant = _ray_plane_hit(get_viewport().get_mouse_position(), 0.14)
		if hit != null:
			var hp: Vector3 = hit
			iron_pos = iron_pos.lerp(Vector2(hp.x, hp.z), minf(1.0, dt * 16.0))

	iron_pos.x = clampf(iron_pos.x, BOARD_ORIGIN.x - 0.96, BOARD_ORIGIN.x + 0.96)
	iron_pos.y = clampf(iron_pos.y, BOARD_ORIGIN.z - 0.96, BOARD_ORIGIN.z + 0.96)

	var press_y := BOARD_ORIGIN.y + (0.115 if active_press else 0.26)
	iron_root.position = Vector3(iron_pos.x, lerpf(iron_root.position.y, press_y, minf(1.0, dt * 14.0)), iron_pos.y)
	iron_root.rotation_degrees = Vector3(sin(t * 7.0) * 2.5 if active_press else 0.0, 14.0, cos(t * 6.0) * 2.5 if active_press else 0.0)

	if active_press:
		var half_i := float(GRID_N - 1) * 0.5
		var heated_sum := 0.0
		var any_under := false
		for r in range(GRID_N):
			for c in range(GRID_N):
				if int(target_grid[r][c]) <= 0:
					continue
				var bx := BOARD_ORIGIN.x + (float(c) - half_i) * CELL_SZ
				var bz := BOARD_ORIGIN.z + (float(r) - half_i) * CELL_SZ
				var d := Vector2(bx - iron_pos.x, bz - iron_pos.y).length()
				if d < 0.62:
					any_under = true
					heat_grid[r][c] = minf(1.0, float(heat_grid[r][c]) + dt * (1.35 - d * 1.1))
					var bn: MeshInstance3D = bead_nodes[r][c]
					if bn and is_instance_valid(bn):
						var ht: float = float(heat_grid[r][c])
						bn.scale = Vector3(lerpf(1.0, 1.10, ht), lerpf(1.0, 0.78, ht), lerpf(1.0, 1.10, ht))
				heated_sum += float(heat_grid[r][c])

		var grid_frac := heated_sum / float(maxi(1, total_beads))
		iron_progress = clampf(maxf(grid_frac, iron_progress + (0.20 if any_under else 0.09) * dt), 0.0, 1.0)

		steam_cd -= dt
		if steam_cd <= 0.0:
			steam_cd = 0.075
			_spawn_steam_puff(iron_root.position + Vector3(randf_range(-0.18, 0.18), 0.06, randf_range(-0.18, 0.18)))
		steam_sfx_cd -= dt
		if steam_sfx_cd <= 0.0:
			steam_sfx_cd = 0.34
			SoundFX.play("iron_steam", -11.0)

	iron_bar_fill.size.x = 376.0 * iron_progress
	iron_bar_lbl.text = "按住左键来回匀速熨烫定型 · %d%%" % int(iron_progress * 100.0)

	if iron_progress >= 1.0:
		_enter_showcase_phase()


func _update_showcase(dt: float, t: float) -> void:
	showcase_t += dt
	if not showcase_dragging:
		showcase_rot_y += dt * 0.55
	if showcase_charm and is_instance_valid(showcase_charm):
		showcase_charm.rotation.y = showcase_rot_y
		showcase_charm.rotation.x = showcase_rot_x
		showcase_charm.position.y = sin(t * 2.4) * 0.045

	for sp in showcase_sparkles:
		var sn: Node3D = sp["node"]
		if is_instance_valid(sn):
			var a: float = float(sp["ang"]) + t * 0.85
			var rad: float = float(sp["rad"])
			sn.position = Vector3(cos(a) * rad, float(sp["y"]) + sin(t * 2.6 + a) * 0.10, sin(a) * rad * 0.45)
			sn.rotation.y += dt * 3.0
			sn.scale = Vector3.ONE * (0.75 + 0.35 * sin(t * 4.5 + a * 2.0))

	# Dramatic warm close-up pedestal showcase camera (framed cleanly between top title and bottom button!)
	var cam_tgt := Vector3(0.0, 1.48, 2.95)
	camera.position = camera.position.lerp(cam_tgt, minf(1.0, dt * 4.5))
	camera.look_at(Vector3(0.0, 1.40, 0.0), Vector3.UP)


func _spawn_steam_puff(pos: Vector3) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.085; sm.height = 0.16; sm.radial_segments = 8; sm.rings = 5
	m.mesh = sm
	var mat := _mat(Color(0.98, 0.99, 1.0), 0.9, Color(0.95, 0.97, 1.0), 0.25, 0.52)
	m.material_override = mat
	m.position = pos
	add_child(m)
	steam_puffs.append({
		"node": m, "mat": mat, "age": 0.0, "life": randf_range(0.55, 0.90),
		"vx": randf_range(-0.18, 0.18), "vz": randf_range(-0.18, 0.18),
	})


func _update_reunion(dt: float, t: float) -> void:
	reunion_t += dt
	if chime_pivot:
		chime_pivot.rotation_degrees.z = sin(reunion_t * 10.0) * exp(-reunion_t * 0.9) * 26.0

	var p_meet := Vector3(2.85, -1.40, -1.35)
	var ta_meet := Vector3(3.85, -1.40, -2.05)

	var ta_dist := partner_model.position.distance_to(ta_meet)
	if ta_dist > 0.12:
		var dir := (ta_meet - partner_model.position).normalized()
		partner_model.position += dir * minf(ta_dist, 3.2 * dt)
		partner_model.rotation.y = lerp_angle(partner_model.rotation.y, atan2(dir.x, dir.z), minf(1.0, dt * 8.0))
		partner_model.update_anim(true, false, dt)
	else:
		var look_p := (player_model.position - partner_model.position).normalized()
		partner_model.rotation.y = lerp_angle(partner_model.rotation.y, atan2(look_p.x, look_p.z), minf(1.0, dt * 8.0))
		partner_model.update_anim(false, false, dt)

	var p_dist := player_model.position.distance_to(p_meet)
	if p_dist > 0.12:
		var dir := (p_meet - player_model.position).normalized()
		player_model.position += dir * minf(p_dist, 2.8 * dt)
		player_model.rotation.y = lerp_angle(player_model.rotation.y, atan2(dir.x, dir.z), minf(1.0, dt * 8.0))
		player_model.update_anim(true, false, dt)
	else:
		var look_ta := (partner_model.position - player_model.position).normalized()
		player_model.rotation.y = lerp_angle(player_model.rotation.y, atan2(look_ta.x, look_ta.z), minf(1.0, dt * 8.0))
		player_model.update_anim(false, false, dt)

	if held_charm and is_instance_valid(held_charm):
		held_charm.position.y = 0.88 + sin(t * 4.2) * 0.04

	if ta_dist <= 0.25 and p_dist <= 0.25 and reunion_stage == 0:
		reunion_stage = 1
		_spawn_emotion_badge(finale_tier)
		if finale_tier == 4:
			partner_model.trigger_angry()
			SoundFX.play("angry", -5.0)
		elif finale_tier == 1:
			partner_model.trigger_celebrate()
			SoundFX.play("keepsake", -4.5)
		else:
			SoundFX.play("keepsake", -5.5)
		_show_toast("【%s】%s" % [finale_mood_name, finale_mood_quote], 4.6)

	if reunion_stage == 1 and reunion_t > 3.2:
		reunion_stage = 2
		partner_model.trigger_celebrate()
		player_model.trigger_celebrate()
		if finale_tier >= 3:
			_spawn_emotion_badge(1)
		GameJuice.spawn_splash(self, (player_model.position + partner_model.position) * 0.5 + Vector3(0, 1.1, 0), Color(1.0, 0.72, 0.84), 20, 0.95, false)

	if emotion_badge and is_instance_valid(emotion_badge):
		emotion_badge.position = partner_model.position + Vector3(0.0, 2.35 + sin(t * 5.0) * 0.10, 0.0)
		emotion_badge.rotation.y += dt * 2.0

	var mid := (player_model.position + partner_model.position) * 0.5
	var cam_tgt := Vector3(2.55, 0.55, 1.48)
	camera.position = camera.position.lerp(cam_tgt, minf(1.0, dt * 3.2))
	camera.look_at(mid + Vector3(0.0, 0.90, 0.0), Vector3.UP)

	if reunion_t >= 5.2 and not cleared:
		cleared = true
		phase = "done"
		SoundFX.play("victory")
		level_cleared.emit({
			"level": 5,
			"role": role,
			"time": finish_time,
			"quiz_right": quiz_right,
			"quiz_wrong": quiz_wrong,
			"mood_tier": finale_tier,
			"mood_name": finale_mood_name,
			"mood_quote": finale_mood_quote,
		})
