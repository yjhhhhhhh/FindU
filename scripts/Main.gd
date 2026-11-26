extends Node

const SAVE_PATH := "user://save_progress.cfg"

var select_layer: CanvasLayer
var modal_layer: CanvasLayer
var victory_layer: CanvasLayer
var current_level: Node = null

var chosen_level: int = 1
var chosen_role: String = "boy"
var cleared_levels: Dictionary = {}

var role_btn: Button
var level_btn: Button
var sound_pill_btn: Button

var menu_couple: Array[Chibi3D] = []
var menu_fireflies: Array[Dictionary] = []
var menu_hearts_3d: Array[Dictionary] = []
var menu_sway_trees: Array[Dictionary] = []
var preview_models: Array[Chibi3D] = []
var rising_hearts: Array[Dictionary] = []


func _ready() -> void:
	var app_theme := Theme.new()
	app_theme.default_font = load("res://assets/fonts/SourceHanSerifCN-Medium.otf")
	get_tree().root.theme = app_theme
	add_child(SoundFX.new())
	add_child(GameJuice.new())
	SettingsUI.load_saved_keybinds()
	_load_progress()
	_show_select_screen()


func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		for i in [1, 2, 3, 4, 5]:
			cleared_levels[i] = cfg.get_value("progress", "level_%d" % i, false)
		chosen_role = str(cfg.get_value("progress", "role", "boy"))


func _save_progress(lvl_num: int) -> void:
	if lvl_num > 0:
		cleared_levels[lvl_num] = true
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	for i in [1, 2, 3, 4, 5]:
		cfg.set_value("progress", "level_%d" % i, cleared_levels.get(i, false))
	cfg.set_value("progress", "role", chosen_role)
	cfg.save(SAVE_PATH)


func _unhandled_input(event: InputEvent) -> void:
	if current_level == null and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			SoundFX.toggle_mute()
			_refresh_sound_pill()
		elif event.keycode == KEY_ESCAPE and modal_layer and is_instance_valid(modal_layer):
			_close_modal()


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001

	for i in range(menu_couple.size()):
		var m := menu_couple[i]
		if is_instance_valid(m):
			m.update_anim(false, false, delta)

	for item in menu_sway_trees:
		var n: Node3D = item["node"]
		if is_instance_valid(n):
			n.rotation.z = sin(t * 1.4 + item["phase"]) * item["amp"]

	for ff in menu_fireflies:
		var n: Node3D = ff["node"]
		if is_instance_valid(n):
			var base: Vector3 = ff["base"]
			var ph: float = ff["phase"]
			n.position = base + Vector3(sin(t * 1.2 + ph) * 0.35, sin(t * 1.9 + ph) * 0.25, cos(t * 1.0 + ph) * 0.30)

	for h3 in menu_hearts_3d:
		var hn: Node3D = h3["node"]
		if is_instance_valid(hn):
			var ph: float = h3["phase"]
			var cycle := fmod(t * 0.32 + ph, 1.0)
			var base: Vector3 = h3["base"]
			hn.position = base + Vector3(sin(t * 2.0 + ph * 4.0) * 0.16, cycle * 1.35, 0.0)
			var sc: float = sin(cycle * PI) * float(h3["scale"])
			hn.scale = Vector3.ONE * maxf(0.01, sc)

	for i in range(preview_models.size()):
		var m := preview_models[i]
		if is_instance_valid(m):
			m.update_anim(false, false, delta)
			m.rotation.y = sin(t * 1.1 + float(i) * 1.5) * 0.28

	for h in rising_hearts:
		var hn2: Polygon2D = h["node"]
		if is_instance_valid(hn2):
			hn2.position.y -= h["speed"] * delta
			hn2.position.x = h["base_x"] + sin(t * 2.2 + h["phase"]) * 12.0
			if hn2.position.y < -20.0:
				hn2.position.y = 320.0
			var life_t := clampf((320.0 - hn2.position.y) / 340.0, 0.0, 1.0)
			hn2.modulate.a = sin(life_t * PI) * 0.92


func _mat3d(col: Color, rough: float = 0.85, emit_col: Color = Color.BLACK, emit_e: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.roughness = rough
	m.metallic_specular = 0.14 if rough > 0.45 else 0.38
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit_e > 0.0:
		m.emission_enabled = true
		m.emission = emit_col
		m.emission_energy_multiplier = emit_e
	return m


func _make_3d_heart_mesh(col: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	for i in range(20):
		var a := float(i) / 20.0 * TAU
		var hx := 16.0 * pow(sin(a), 3.0) * 0.012
		var hy := (13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a)) * 0.012
		pts.append(Vector3(hx, hy, 0.0))
	var cf := Vector3(0, 0.02, 0.055)
	var cb := Vector3(0, 0.02, -0.055)
	for i in range(pts.size()):
		var n := (i + 1) % pts.size()
		st.add_vertex(cf); st.add_vertex(pts[i]); st.add_vertex(pts[n])
		st.add_vertex(cb); st.add_vertex(pts[n]); st.add_vertex(pts[i])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat3d(col, 0.25, col, 1.15)
	return mi


func _build_menu_diorama_stage() -> SubViewportContainer:
	var svc := SubViewportContainer.new()
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vp := SubViewport.new()
	vp.size = Vector2i(1152, 720)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(vp)

	# Dreamy Twilight Emerald-Teal Forest Sky & Soft Mist (Plan B atmosphere!)
	var env := Environment.new()
	var sky := Sky.new()
	var smat := ProceduralSkyMaterial.new()
	smat.sky_top_color = Color(0.06, 0.17, 0.22)
	smat.sky_horizon_color = Color(0.18, 0.42, 0.44)
	smat.ground_bottom_color = Color(0.06, 0.14, 0.14)
	smat.ground_horizon_color = Color(0.14, 0.30, 0.30)
	sky.sky_material = smat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.46, 0.48)
	env.ambient_light_energy = 0.65
	env.fog_enabled = true
	env.fog_light_color = Color(0.15, 0.36, 0.38)
	env.fog_density = 0.032

	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.88, 0.68)
	sun.light_energy = 0.74
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-42, -32, 0)
	vp.add_child(sun)

	# Cool twilight moon-rim fill opposing warm key light (shader-visual-polish cold/warm contrast!)
	var moon_rim := DirectionalLight3D.new()
	moon_rim.light_color = Color(0.36, 0.62, 0.90)
	moon_rim.light_energy = 0.30
	moon_rim.rotation_degrees = Vector3(-28, 148, 0)
	vp.add_child(moon_rim)

	# Camera frames the arched bridge, waving couple, hedgehog & cozy lantern bench cleanly!
	var cam := Camera3D.new()
	cam.fov = 36.5
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(-0.45, 3.95, 10.4), Vector3(-0.55, 1.32, 0.35), Vector3.UP)

	# Lush twilight emerald forest floor with multi-octave fBm moss & roughness breakup
	var floor_m := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(36.0, 0.6, 30.0)
	floor_m.mesh = fm
	floor_m.material_override = VisualPolish.make_terrain_mat(
		Color(0.16, 0.35, 0.22), Color(0.33, 0.50, 0.26), Color(0.07, 0.17, 0.20), 0.58
	)
	floor_m.position = Vector3(0, -0.32, 0)
	vp.add_child(floor_m)

	# Glowing Turquoise Forest Brook with animated caustic ripples & shoreline foam!
	var brook := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.25, 0.05, 18.0)
	brook.mesh = bm
	brook.material_override = VisualPolish.make_water_mat(
		Color(0.05, 0.25, 0.38), Color(0.15, 0.66, 0.72), Vector2(0.0, 1.0), 0.52
	)
	brook.position = Vector3(0.05, 0.01, 1.3)
	brook.rotation_degrees = Vector3(0, 34, 0)
	vp.add_child(brook)

	var brook_light := OmniLight3D.new()
	brook_light.light_color = Color(0.28, 0.88, 0.92)
	brook_light.light_energy = 0.85
	brook_light.omni_range = 5.5
	brook_light.position = Vector3(0.35, 0.55, 1.6)
	vp.add_child(brook_light)

	# Warm winding tan forest path with procedural pebble/soil grain
	var path_mat := VisualPolish.make_organic_mat(Color(0.56, 0.44, 0.31), 1.85, 0.78, 0.98)
	for pcfg in [
		[Vector3(-2.6, 0.02, -0.5), Vector3(1.8, 0.05, 1.6), 12.0],
		[Vector3(3.3, 0.02, 1.5), Vector3(2.2, 0.05, 1.8), -22.0],
		[Vector3(4.1, 0.02, 3.3), Vector3(1.8, 0.05, 2.2), 18.0],
		[Vector3(2.4, 0.02, 4.6), Vector3(2.4, 0.05, 1.6), -30.0],
	]:
		var p := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.85; pm.bottom_radius = 0.95; pm.height = 0.06; pm.radial_segments = 10
		p.mesh = pm
		p.material_override = path_mat
		p.position = pcfg[0]
		p.scale = pcfg[1]
		p.rotation_degrees = Vector3(0, pcfg[2], 0)
		vp.add_child(p)

	# Arched Wooden Footbridge centered right over the glowing brook!
	var bridge := Node3D.new()
	bridge.position = Vector3(1.05, 0.0, 0.35)
	bridge.rotation_degrees = Vector3(0, -14, 0)
	vp.add_child(bridge)

	var cedar := _mat3d(Color(0.72, 0.48, 0.27), 0.85)
	var dark_wood := _mat3d(Color(0.46, 0.28, 0.15), 0.88)

	for i in range(9):
		var u := float(i) / 8.0
		var x := lerpf(-1.95, 1.95, u)
		var arch_y := 0.16 + sin(u * PI) * 0.46
		var tilt := cos(u * PI) * 18.0
		var pl := MeshInstance3D.new()
		var plm := BoxMesh.new()
		plm.size = Vector3(0.44, 0.11, 1.85)
		pl.mesh = plm
		pl.material_override = cedar
		pl.position = Vector3(x, arch_y, 0)
		pl.rotation_degrees = Vector3(0, 0, tilt)
		bridge.add_child(pl)

	for pz in [-0.88, 0.88]:
		for i in range(4):
			var u := float(i) / 3.0
			var px := lerpf(-1.75, 1.75, u)
			var py := 0.16 + sin(u * PI) * 0.46
			var post := MeshInstance3D.new()
			var psm := BoxMesh.new()
			psm.size = Vector3(0.16, 0.72, 0.16)
			post.mesh = psm
			post.material_override = dark_wood
			post.position = Vector3(px, py + 0.34, pz)
			bridge.add_child(post)
		for i in range(6):
			var u0 := float(i) / 6.0
			var u1 := float(i + 1) / 6.0
			var um := (u0 + u1) * 0.5
			var rx := lerpf(-1.75, 1.75, um)
			var ry := 0.16 + sin(um * PI) * 0.46 + 0.62
			var rtilt := cos(um * PI) * 18.0
			var rail := MeshInstance3D.new()
			var rlm := BoxMesh.new()
			rlm.size = Vector3(0.64, 0.10, 0.11)
			rail.mesh = rlm
			rail.material_override = cedar
			rail.position = Vector3(rx, ry, pz)
			rail.rotation_degrees = Vector3(0, 0, rtilt)
			bridge.add_child(rail)

	# Boy & Girl standing warmly together on the arched bridge waving (Plan B: Boy shows green dual-leaf pin!)
	var boy_m := Chibi3D.create("boy")
	boy_m.position = Vector3(-0.55, 0.65, 0.05)
	boy_m.rotation_degrees = Vector3(0, 10, 0)
	boy_m.scale = Vector3.ONE * 0.96
	boy_m.set_waving(-1)
	bridge.add_child(boy_m)
	menu_couple.append(boy_m)

	var girl_m := Chibi3D.create("girl")
	girl_m.position = Vector3(0.55, 0.65, 0.05)
	girl_m.rotation_degrees = Vector3(0, -10, 0)
	girl_m.scale = Vector3.ONE * 0.96
	girl_m.set_waving(1)
	bridge.add_child(girl_m)
	menu_couple.append(girl_m)

	var couple_light := OmniLight3D.new()
	couple_light.light_color = Color(1.0, 0.92, 0.80)
	couple_light.light_energy = 0.55
	couple_light.omni_range = 5.5
	couple_light.position = Vector3(0.0, 2.3, 2.3)
	bridge.add_child(couple_light)

	# Rising glowing golden hearts above the couple
	for i in range(4):
		var h := _make_3d_heart_mesh(Color(1.0, 0.84, 0.44) if i % 2 == 0 else Color(1.0, 0.68, 0.78))
		var hb := Vector3(1.1 + float(i - 1.5) * 0.52, 2.55, 0.25)
		h.position = hb
		vp.add_child(h)
		menu_hearts_3d.append({"node": h, "base": hb, "phase": float(i) * 0.27, "scale": 0.65 + float(i % 2) * 0.22})

	# Glowing Purple Spotted Mushrooms (left of bridge & foreground right)
	for mcfg in [
		[Vector3(-0.75, 0.0, -0.85), 1.05],
		[Vector3(-1.35, 0.0, -0.10), 0.58],
		[Vector3(2.85, 0.0, 2.45), 0.62],
	]:
		_spawn_diorama_mushroom(vp, mcfg[0], mcfg[1])

	# Cute Sculpted 3D Sleeping Hedgehog nestled on the right mossy bank + Graceful Butterfly3D!
	_spawn_diorama_hedgehog(vp, Vector3(2.20, 0.0, 2.95))
	var bf := Butterfly3D.create(0.72, 9.5)
	bf.position = Vector3(1.55, 0.64, 2.75)
	bf.rotation_degrees = Vector3(14, 52, 0)
	vp.add_child(bf)

	# Cozy Wooden Park Bench + Warm Glowing Forest Lantern on right!
	_spawn_diorama_bench_and_lantern(vp, Vector3(3.80, 0.0, 1.35))

	# River stones & cute colorful wildflowers
	var stone_mat := _mat3d(Color(0.42, 0.46, 0.52), 0.92)
	for spos in [Vector3(-1.15, 0.08, 2.45), Vector3(-0.55, 0.06, 2.15), Vector3(-0.95, 0.06, 3.85)]:
		var st := MeshInstance3D.new()
		var stm := SphereMesh.new()
		stm.radius = 0.28; stm.height = 0.28; stm.radial_segments = 6; stm.rings = 3
		st.mesh = stm
		st.material_override = stone_mat
		st.position = spos
		st.scale = Vector3(1.2, 0.72, 1.0)
		vp.add_child(st)

	var flower_cols := [Color(1.0, 0.86, 0.35), Color(0.84, 0.55, 1.0), Color(1.0, 0.55, 0.74)]
	for i in range(16):
		var fpos: Vector3 = [
			Vector3(-1.9, 0.10, 1.3), Vector3(-1.6, 0.12, 1.5), Vector3(-2.1, 0.10, 1.65),
			Vector3(1.8, 0.12, 2.55), Vector3(2.15, 0.10, 2.85), Vector3(1.55, 0.10, 3.15),
			Vector3(0.45, 0.08, 3.75), Vector3(1.35, 0.08, 3.55), Vector3(-2.5, 0.10, 0.9),
			Vector3(-1.4, 0.12, 1.15), Vector3(2.0, 0.10, 2.15), Vector3(2.65, 0.10, 2.65),
			Vector3(-0.2, 0.08, 3.95), Vector3(0.85, 0.08, 3.95), Vector3(-1.8, 0.10, 2.0),
			Vector3(2.3, 0.10, 3.1),
		][i]
		var fl := MeshInstance3D.new()
		var flm := SphereMesh.new()
		flm.radius = 0.10; flm.height = 0.12; flm.radial_segments = 6; flm.rings = 3
		fl.mesh = flm
		fl.material_override = _mat3d(flower_cols[i % 3], 0.45, flower_cols[i % 3], 0.25)
		fl.position = fpos
		vp.add_child(fl)

	# Low-poly Pine & Round Forest Trees (framing left behind menu + autumn gold trees on right!)
	for tcfg in [
		[Vector3(-3.8, 0, 1.2), 1.35, "pine", Color(0.16, 0.42, 0.24)],
		[Vector3(-2.4, 0, -2.5), 1.45, "pine", Color(0.15, 0.38, 0.23)],
		[Vector3(-4.8, 0, -1.8), 1.55, "pine", Color(0.12, 0.32, 0.21)],
		[Vector3(-0.6, 0, -4.4), 1.60, "round", Color(0.18, 0.46, 0.28)],
		[Vector3(3.8, 0, -2.8), 1.48, "round", Color(0.76, 0.52, 0.18)],
		[Vector3(5.2, 0, -1.0), 1.35, "pine", Color(0.16, 0.42, 0.25)],
		[Vector3(2.2, 0, -4.6), 1.30, "pine", Color(0.15, 0.38, 0.26)],
		[Vector3(-5.6, 0, 2.8), 1.25, "pine", Color(0.12, 0.30, 0.20)],
	]:
		_spawn_diorama_tree(vp, tcfg[0], tcfg[1], tcfg[2], tcfg[3])

	# Floating golden fireflies across the twilight forest!
	var rng := RandomNumberGenerator.new()
	rng.seed = 202607
	var ff_mat := _mat3d(Color(1.0, 0.90, 0.45), 0.2, Color(1.0, 0.86, 0.38), 1.8)
	for i in range(28):
		var ff := MeshInstance3D.new()
		var ffm := SphereMesh.new()
		ffm.radius = 0.045; ffm.height = 0.09
		ff.mesh = ffm
		ff.material_override = ff_mat
		var b := Vector3(rng.randf_range(-4.5, 4.8), rng.randf_range(0.45, 3.2), rng.randf_range(-2.5, 4.2))
		ff.position = b
		vp.add_child(ff)
		menu_fireflies.append({"node": ff, "base": b, "phase": rng.randf_range(0, TAU)})

	return svc


func _spawn_diorama_tree(parent: Node, pos: Vector3, sc: float, style: String, leaf_col: Color) -> void:
	var tree := Node3D.new()
	tree.position = pos
	tree.scale = Vector3.ONE * sc
	parent.add_child(tree)

	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.20; tm.bottom_radius = 0.32; tm.height = 1.6; tm.radial_segments = 6
	trunk.mesh = tm
	trunk.material_override = _mat3d(Color(0.38, 0.24, 0.15))
	trunk.position = Vector3(0, 0.8, 0)
	tree.add_child(trunk)

	var canopy := Node3D.new()
	canopy.position = Vector3(0, 1.5, 0)
	tree.add_child(canopy)

	if style == "pine":
		for i in range(3):
			var c := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = 1.28 - float(i) * 0.28
			cm.height = 1.45
			cm.radial_segments = 7
			c.mesh = cm
			c.material_override = _mat3d(leaf_col.lightened(float(i) * 0.08))
			c.position = Vector3(0, 0.45 + float(i) * 0.82, 0)
			canopy.add_child(c)
	else:
		for off in [Vector3(0, 0.85, 0), Vector3(-0.55, 0.45, 0.2), Vector3(0.55, 0.55, -0.15)]:
			var cr := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.92; sm.height = 1.65; sm.radial_segments = 7; sm.rings = 4
			cr.mesh = sm
			cr.material_override = _mat3d(leaf_col)
			cr.position = off
			canopy.add_child(cr)

	menu_sway_trees.append({"node": canopy, "phase": pos.x * 0.5 + pos.z * 0.3, "amp": 0.028})


func _spawn_diorama_mushroom(parent: Node, pos: Vector3, sc: float) -> void:
	var m := Node3D.new()
	m.position = pos
	m.scale = Vector3.ONE * sc
	parent.add_child(m)

	var stem := MeshInstance3D.new()
	var stm := CylinderMesh.new()
	stm.top_radius = 0.14; stm.bottom_radius = 0.20; stm.height = 0.50; stm.radial_segments = 8
	stem.mesh = stm
	stem.material_override = _mat3d(Color(1.0, 0.92, 0.72), 0.5, Color(1.0, 0.86, 0.55), 0.45)
	stem.position = Vector3(0, 0.25, 0)
	m.add_child(stem)

	var cap := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.52; cm.height = 0.55; cm.radial_segments = 10; cm.rings = 5
	cap.mesh = cm
	cap.material_override = _mat3d(Color(0.56, 0.28, 0.74), 0.45, Color(0.48, 0.24, 0.68), 0.38)
	cap.position = Vector3(0, 0.56, 0)
	m.add_child(cap)

	var spot_mat := _mat3d(Color(1.0, 0.94, 0.72), 0.3, Color(1.0, 0.88, 0.58), 0.7)
	for sp in [Vector3(-0.22, 0.68, 0.26), Vector3(0.20, 0.72, 0.22), Vector3(0.0, 0.78, -0.18)]:
		var d := MeshInstance3D.new()
		var dm := SphereMesh.new()
		dm.radius = 0.085; dm.height = 0.08; dm.radial_segments = 8; dm.rings = 4
		d.mesh = dm
		d.material_override = spot_mat
		d.position = sp
		m.add_child(d)

	var gl := OmniLight3D.new()
	gl.light_color = Color(1.0, 0.78, 0.58)
	gl.light_energy = 0.85 * sc
	gl.omni_range = 3.2
	gl.position = Vector3(0, 0.45, 0.2)
	m.add_child(gl)


func _spawn_diorama_hedgehog(parent: Node, pos: Vector3) -> void:
	var hh := Node3D.new()
	hh.position = pos
	hh.rotation_degrees = Vector3(0, -125, 0)
	hh.scale = Vector3.ONE * 0.85
	parent.add_child(hh)

	var quill_mat := _mat3d(Color(0.44, 0.28, 0.16), 0.90)
	var face_mat := _mat3d(Color(0.94, 0.84, 0.70), 0.82)
	var nose_mat := _mat3d(Color(0.10, 0.08, 0.08), 0.25)

	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.38; bm.height = 0.50; bm.radial_segments = 14; bm.rings = 8
	body.mesh = bm
	body.material_override = quill_mat
	body.scale = Vector3(0.95, 0.85, 1.25)
	body.position = Vector3(0, 0.22, -0.04)
	hh.add_child(body)

	var face := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.23; fm.height = 0.32; fm.radial_segments = 12; fm.rings = 8
	face.mesh = fm
	face.material_override = face_mat
	face.scale = Vector3(0.92, 0.84, 1.22)
	face.position = Vector3(0, 0.17, 0.34)
	hh.add_child(face)

	var nose := MeshInstance3D.new()
	var nm := SphereMesh.new()
	nm.radius = 0.055; nm.height = 0.10
	nose.mesh = nm
	nose.material_override = nose_mat
	nose.position = Vector3(0, 0.16, 0.56)
	hh.add_child(nose)

	for sx in [-0.10, 0.10]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.032; em.height = 0.06
		eye.mesh = em
		eye.material_override = nose_mat
		eye.position = Vector3(sx, 0.22, 0.48)
		hh.add_child(eye)

	for sp_cfg in [
		[Vector3(0, 0.44, -0.05), Vector3(-25, 0, 0)],
		[Vector3(-0.18, 0.40, -0.10), Vector3(-20, 0, 26)],
		[Vector3(0.18, 0.40, -0.10), Vector3(-20, 0, -26)],
		[Vector3(0, 0.38, -0.28), Vector3(-48, 0, 0)],
		[Vector3(-0.22, 0.34, -0.25), Vector3(-35, 0, 38)],
		[Vector3(0.22, 0.34, -0.25), Vector3(-35, 0, -38)],
	]:
		var sp := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.0; sm.bottom_radius = 0.055; sm.height = 0.20; sm.radial_segments = 5
		sp.mesh = sm
		sp.material_override = quill_mat
		sp.position = sp_cfg[0]
		sp.rotation_degrees = sp_cfg[1]
		hh.add_child(sp)


func _spawn_diorama_bench_and_lantern(parent: Node, pos: Vector3) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation_degrees = Vector3(0, -34, 0)
	parent.add_child(g)

	var wood := _mat3d(Color(0.58, 0.36, 0.20), 0.86)
	var iron := _mat3d(Color(0.18, 0.20, 0.24), 0.45)

	var seat := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(1.8, 0.10, 0.62)
	seat.mesh = sm; seat.material_override = wood; seat.position = Vector3(0, 0.38, 0)
	g.add_child(seat)

	var back := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.8, 0.45, 0.09)
	back.mesh = bm; back.material_override = wood; back.position = Vector3(0, 0.65, -0.26); back.rotation_degrees = Vector3(-10, 0, 0)
	g.add_child(back)

	for sx in [-0.78, 0.78]:
		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.12, 0.38, 0.56)
		leg.mesh = lm; leg.material_override = iron; leg.position = Vector3(sx, 0.19, 0)
		g.add_child(leg)

	# Glowing warm forest lantern beside the bench!
	var lan := Node3D.new()
	lan.position = Vector3(-1.25, 0.0, 0.22)
	g.add_child(lan)
	var lbase := MeshInstance3D.new()
	var lbm := BoxMesh.new()
	lbm.size = Vector3(0.32, 0.08, 0.32)
	lbase.mesh = lbm; lbase.material_override = iron; lbase.position = Vector3(0, 0.04, 0)
	lan.add_child(lbase)
	var lglass := MeshInstance3D.new()
	var lgm := BoxMesh.new()
	lgm.size = Vector3(0.24, 0.34, 0.24)
	lglass.mesh = lgm
	lglass.material_override = _mat3d(Color(1.0, 0.88, 0.48), 0.15, Color(1.0, 0.78, 0.32), 2.2)
	lglass.position = Vector3(0, 0.25, 0)
	lan.add_child(lglass)
	var lcap := MeshInstance3D.new()
	var lcm := CylinderMesh.new()
	lcm.top_radius = 0.02; lcm.bottom_radius = 0.22; lcm.height = 0.16; lcm.radial_segments = 4
	lcap.mesh = lcm; lcap.material_override = iron; lcap.position = Vector3(0, 0.50, 0); lcap.rotation_degrees = Vector3(0, 45, 0)
	lan.add_child(lcap)

	var llight := OmniLight3D.new()
	llight.light_color = Color(1.0, 0.78, 0.36)
	llight.light_energy = 1.9
	llight.omni_range = 5.5
	llight.position = Vector3(0, 0.40, 0)
	lan.add_child(llight)


func _make_3d_preview_viewport(w: int, h: int, cam_pos: Vector3, look_target: Vector3) -> Dictionary:
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(w, h)
	svc.stretch = true

	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(vp)

	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.88)
	env.ambient_light_energy = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.96, 0.90)
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-40, -30, 0)
	vp.add_child(sun)

	var cam := Camera3D.new()
	cam.fov = 38.0
	vp.add_child(cam)
	cam.look_at_from_position(cam_pos, look_target, Vector3.UP)

	return {"container": svc, "viewport": vp}


func _make_menu_button(txt: String, is_primary: bool = false) -> Button:
	return GameUI.make_blade_button(txt, is_primary, Vector2(272, 48), 20)


func _show_select_screen() -> void:
	_clear_all()

	select_layer = CanvasLayer.new()
	add_child(select_layer)

	# 1. Full-screen Live 3D Twilight Forest Diorama
	select_layer.add_child(_build_menu_diorama_stage())

	# 2. Single-Edge Directional Dark-Pine Vignette Mask (NO rounded box!)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.07, 0.09, 0.84))
	grad.set_color(1, Color(0.02, 0.07, 0.09, 0.0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0.0, 0.5)
	gtex.fill_to = Vector2(0.54, 0.5)
	var vig := TextureRect.new()
	vig.texture = gtex
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	select_layer.add_child(vig)

	# 3. Left-Aligned Architectural Menu Stack ("Find U" + Chamfered Blade Buttons)
	var left_box := VBoxContainer.new()
	left_box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	left_box.offset_left = 68
	left_box.offset_right = 410
	left_box.offset_top = -238
	left_box.offset_bottom = 248
	left_box.alignment = BoxContainer.ALIGNMENT_CENTER
	left_box.add_theme_constant_override("separation", 16)
	select_layer.add_child(left_box)

	var logo_wrap := Control.new()
	logo_wrap.custom_minimum_size = Vector2(310, 112)
	left_box.add_child(logo_wrap)

	var title_lbl := Label.new()
	title_lbl.text = "Find U"
	title_lbl.position = Vector2(6, 0)
	title_lbl.add_theme_font_size_override("font_size", 76)
	title_lbl.add_theme_color_override("font_color", Color(0.99, 0.94, 0.78))
	title_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.07, 0.96))
	title_lbl.add_theme_constant_override("outline_size", 6)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.02, 0.06, 0.07, 0.88))
	title_lbl.add_theme_constant_override("shadow_offset_x", 3)
	title_lbl.add_theme_constant_override("shadow_offset_y", 5)
	logo_wrap.add_child(title_lbl)

	var logo_heart := Polygon2D.new()
	logo_heart.polygon = _heart_pts(10.5)
	logo_heart.color = Color(0.99, 0.88, 0.56)
	logo_heart.position = Vector2(258, 22)
	logo_wrap.add_child(logo_heart)

	# Crisp double-hairline botanical brass rule under logo
	var logo_rule := ColorRect.new()
	logo_rule.color = Color(0.96, 0.84, 0.50, 0.72)
	logo_rule.position = Vector2(8, 96)
	logo_rule.size = Vector2(264, 2)
	logo_wrap.add_child(logo_rule)

	var logo_sub := Label.new()
	logo_sub.text = "寻找另一半  ·  微光森林物语"
	logo_sub.position = Vector2(10, 102)
	GameUI.style_floating_label(logo_sub, 13, Color(0.84, 0.90, 0.86, 0.92), 4)
	logo_wrap.add_child(logo_sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	left_box.add_child(spacer)

	var btn_col := VBoxContainer.new()
	btn_col.add_theme_constant_override("separation", 12)
	left_box.add_child(btn_col)

	var start_btn := _make_menu_button("开始冒险", true)
	start_btn.pressed.connect(func(): _start_level(chosen_role, chosen_level))
	btn_col.add_child(start_btn)

	level_btn = _make_menu_button("选择关卡  ·  第 %d 关" % chosen_level)
	level_btn.pressed.connect(_open_level_modal)
	btn_col.add_child(level_btn)

	role_btn = _make_menu_button("切换角色  ·  %s" % ("男生" if chosen_role == "boy" else "女生"))
	role_btn.pressed.connect(_open_role_modal)
	btn_col.add_child(role_btn)

	var settings_btn := _make_menu_button("游戏设置")
	settings_btn.pressed.connect(func():
		var sui := SettingsUI.open(self, false)
		sui.closed.connect(func():
			_refresh_sound_pill()
			if is_instance_valid(settings_btn):
				settings_btn.grab_focus()
		)
	)
	btn_col.add_child(settings_btn)

	var quit_btn := _make_menu_button("退出游戏")
	quit_btn.pressed.connect(func(): get_tree().quit())
	btn_col.add_child(quit_btn)

	# 4. Bottom-Right Sharp Chamfered Audio Blade (ZERO rounded pill!)
	sound_pill_btn = GameUI.make_blade_button("", false, Vector2(154, 34), 13)
	sound_pill_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	sound_pill_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	sound_pill_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sound_pill_btn.offset_right = -22
	sound_pill_btn.offset_bottom = -18
	sound_pill_btn.pressed.connect(func():
		SoundFX.toggle_mute()
		_refresh_sound_pill()
	)
	select_layer.add_child(sound_pill_btn)
	_refresh_sound_pill()
	start_btn.grab_focus()


func _refresh_sound_pill() -> void:
	if sound_pill_btn and is_instance_valid(sound_pill_btn):
		var m: bool = SoundFX.instance.muted if SoundFX.instance else false
		sound_pill_btn.text = ("已静音 [M]  |  v2.0" if m else "声音开 [M]  |  v2.0")


func _close_modal() -> void:
	preview_models.clear()
	if modal_layer and is_instance_valid(modal_layer):
		modal_layer.queue_free()
		modal_layer = null


func _open_level_modal() -> void:
	_close_modal()
	modal_layer = CanvasLayer.new()
	modal_layer.layer = 30
	add_child(modal_layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.06, 0.08, 0.78)
	modal_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(620, 565)
	card.add_theme_stylebox_override("panel", GameUI.make_chamfer_panel_style(
		Color(0.06, 0.12, 0.14, 0.97), Color(0.88, 0.78, 0.50, 0.95), 14, 22
	))
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)

	var hdr := Label.new()
	hdr.text = "选择章节关卡"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUI.style_floating_label(hdr, 26, Color(0.99, 0.94, 0.78), 4)
	vb.add_child(hdr)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(0.88, 0.78, 0.50, 0.42)
	vb.add_child(rule)

	var levels := [
		{"id": 1, "name": "第 1 关：微光蘑菇森林", "desc": "点亮发光蘑菇与音符石阶，拾取信物并跨过小溪重逢"},
		{"id": 2, "name": "第 2 关：萤火环林（小跳蛙）", "desc": "由外圈绕进森林中心，吓跑胆小鬼最怕的小跳蛙"},
		{"id": 3, "name": "第 3 关：炽热秋枫林（长凳奶茶）", "desc": "躲避火焰寻找珍珠奶茶，在长凳上悄悄挪过去哄TA开心"},
		{"id": 4, "name": "第 4 关：云巅飞瀑（大鹈鹕大追击）", "desc": "离开森林纵身跃下悬崖瀑布，赶在TA气鼓鼓前追上大鹈鹕"},
		{"id": 5, "name": "第 5 关：微光拼豆屋（手作重逢）", "desc": "在温暖手作小店拼出TA的像素头像，顶住算术突袭熨烫赠礼"},
	]

	var first_focus: Button = null
	for lv in levels:
		var lid: int = lv["id"]
		var is_cur := (lid == chosen_level)
		var star := "   ◆ 已通关" if cleared_levels.get(lid, false) else ""
		var row_btn := GameUI.make_blade_button(
			"%s%s\n%s" % [lv["name"], star, lv["desc"]],
			is_cur, Vector2(540, 66), 15
		)
		row_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row_btn.pressed.connect(func():
			chosen_level = lid
			if level_btn and is_instance_valid(level_btn):
				level_btn.text = "选择关卡  ·  第 %d 关" % chosen_level
			_close_modal()
			_start_level(chosen_role, chosen_level)
		)
		vb.add_child(row_btn)
		if is_cur or first_focus == null:
			first_focus = row_btn

	var close_btn := _make_menu_button("返回主菜单")
	close_btn.custom_minimum_size = Vector2(180, 42)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func():
		_close_modal()
		if level_btn and is_instance_valid(level_btn):
			level_btn.grab_focus()
	)
	vb.add_child(close_btn)
	if first_focus:
		first_focus.grab_focus()


func _open_role_modal() -> void:
	_close_modal()
	modal_layer = CanvasLayer.new()
	modal_layer.layer = 30
	add_child(modal_layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.06, 0.08, 0.78)
	modal_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(center)

	# Single Chamfered Stage Folio — NO nested inner cards! (impeccable craft-floor)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(690, 475)
	card.add_theme_stylebox_override("panel", GameUI.make_chamfer_panel_style(
		Color(0.06, 0.12, 0.14, 0.97), Color(0.88, 0.78, 0.50, 0.95), 14, 26
	))
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	card.add_child(vb)

	var hdr := Label.new()
	hdr.text = "选择出发角色"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUI.style_floating_label(hdr, 27, Color(0.99, 0.94, 0.78), 4)
	vb.add_child(hdr)

	var top_rule := ColorRect.new()
	top_rule.custom_minimum_size = Vector2(0, 1)
	top_rule.color = Color(0.88, 0.78, 0.50, 0.42)
	vb.add_child(top_rule)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)
	vb.add_child(hbox)

	var boy_col := _make_role_stage("boy", "扮演男生", "寻觅目标：女生", "蓬松短发 · 透明方框眼镜 · 双叶卫衣", Color(0.56, 0.86, 1.0))
	hbox.add_child(boy_col["root"])

	# Architectural vertical brass divider instead of nested card boxes
	var v_div := ColorRect.new()
	v_div.custom_minimum_size = Vector2(1, 290)
	v_div.color = Color(0.88, 0.78, 0.50, 0.34)
	hbox.add_child(v_div)

	var girl_col := _make_role_stage("girl", "扮演女生", "寻觅目标：男生", "低双马尾 · 金丝眼镜 · 蓝白连帽外套", Color(1.0, 0.72, 0.84))
	hbox.add_child(girl_col["root"])

	var close_btn := _make_menu_button("返回主菜单")
	close_btn.custom_minimum_size = Vector2(180, 42)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func():
		_close_modal()
		if role_btn and is_instance_valid(role_btn):
			role_btn.grab_focus()
	)
	vb.add_child(close_btn)

	if chosen_role == "boy":
		boy_col["btn"].grab_focus()
	else:
		girl_col["btn"].grab_focus()


func _make_role_stage(role: String, title_txt: String, target_txt: String, desc_txt: String, accent: Color) -> Dictionary:
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(285, 315)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	var is_cur := (role == chosen_role)

	var p3d := _make_3d_preview_viewport(210, 195, Vector3(0, 1.35, 3.6), Vector3(0, 1.05, 0))
	p3d["container"].size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var model := Chibi3D.create(role)
	p3d["viewport"].add_child(model)
	preview_models.append(model)
	vb.add_child(p3d["container"])

	var btn := GameUI.make_blade_button(title_txt + ("  ◆ 当前" if is_cur else ""), is_cur, Vector2(228, 42), 18)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func():
		chosen_role = role
		_save_progress(0)
		if role_btn and is_instance_valid(role_btn):
			role_btn.text = "切换角色  ·  %s" % ("男生" if chosen_role == "boy" else "女生")
		_close_modal()
		if role_btn and is_instance_valid(role_btn):
			role_btn.grab_focus()
	)
	vb.add_child(btn)

	var tgt := Label.new()
	tgt.text = target_txt
	tgt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUI.style_floating_label(tgt, 15, accent, 3)
	vb.add_child(tgt)

	var desc := Label.new()
	desc.text = desc_txt
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUI.style_floating_label(desc, 12, Color(0.84, 0.88, 0.88), 3)
	vb.add_child(desc)

	return {"root": vb, "btn": btn}


func _start_level(role: String, lvl_num: int) -> void:
	_clear_all()
	chosen_role = role
	chosen_level = lvl_num
	if lvl_num == 1:
		current_level = Level1Scene.new()
	elif lvl_num == 2:
		current_level = Level2Scene.new()
	elif lvl_num == 3:
		current_level = Level3Scene.new()
	elif lvl_num == 4:
		current_level = Level4Scene.new()
	else:
		current_level = Level5Scene.new()
	current_level.init_role(role)
	current_level.level_cleared.connect(_on_level_cleared)
	current_level.back_to_select.connect(_show_select_screen)
	current_level.restart_level.connect(func(): _start_level(role, lvl_num))
	add_child(current_level)


func _heart_pts(sz: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(24):
		var a := float(i) / 24.0 * TAU
		var hx := 16.0 * pow(sin(a), 3.0)
		var hy := -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))
		pts.append(Vector2(hx, hy) * (sz / 16.0))
	return pts


func _on_level_cleared(stats: Dictionary) -> void:
	preview_models.clear()
	rising_hearts.clear()
	var lvl_num: int = stats.get("level", 1)
	_save_progress(lvl_num)

	victory_layer = CanvasLayer.new()
	victory_layer.layer = 100
	add_child(victory_layer)

	# Hide any in-level HUD CanvasLayers so nothing can block or overlap the victory screen
	if current_level and is_instance_valid(current_level):
		for child in current_level.get_children():
			if child is CanvasLayer:
				child.visible = false

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.06, 0.10, 0.14, 0.82)
	victory_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	victory_layer.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(690, 565)
	card.add_theme_stylebox_override("panel", GameUI.make_chamfer_panel_style(
		Color(0.06, 0.13, 0.15, 0.98), Color(0.98, 0.86, 0.54, 0.96), 16, 26
	))
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 12)
	card.add_child(vb)

	var title := Label.new()
	if lvl_num == 5:
		title.text = "第 5 关达成  ·  手作重逢"
	elif lvl_num == 4:
		title.text = "第 4 关达成  ·  碧潭重逢"
	else:
		title.text = "第 %d 关达成  ·  林间重逢" % lvl_num
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUI.style_floating_label(title, 32, Color(1.0, 0.94, 0.80), 5)
	vb.add_child(title)

	var stage := Control.new()
	stage.custom_minimum_size = Vector2(460, 310)
	stage.clip_contents = true
	vb.add_child(stage)

	var hearts_holder := Control.new()
	hearts_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(hearts_holder)

	var rng := RandomNumberGenerator.new()
	rng.seed = 5201314
	var heart_colors := [
		Color(1.0, 0.42, 0.62),
		Color(1.0, 0.58, 0.76),
		Color(1.0, 0.84, 0.48),
		Color(1.0, 0.72, 0.84),
	]
	for i in range(18):
		var h := Polygon2D.new()
		h.polygon = _heart_pts(rng.randf_range(11.0, 24.0))
		h.color = heart_colors[i % heart_colors.size()]
		var bx := rng.randf_range(35.0, 425.0)
		var by := rng.randf_range(10.0, 310.0)
		h.position = Vector2(bx, by)
		hearts_holder.add_child(h)
		rising_hearts.append({
			"node": h,
			"base_x": bx,
			"speed": rng.randf_range(36.0, 74.0),
			"phase": rng.randf_range(0.0, TAU),
		})

	var v3d := _make_3d_preview_viewport(460, 310, Vector3(0, 1.40, 4.9), Vector3(0, 1.05, 0))
	v3d["container"].set_anchors_preset(Control.PRESET_FULL_RECT)

	var boy_m := Chibi3D.create("boy")
	boy_m.position = Vector3(-0.60, 0, 0)
	boy_m.rotation.y = 0.22
	v3d["viewport"].add_child(boy_m)
	preview_models.append(boy_m)

	var girl_m := Chibi3D.create("girl")
	girl_m.position = Vector3(0.60, 0, 0)
	girl_m.rotation.y = -0.22
	v3d["viewport"].add_child(girl_m)
	preview_models.append(girl_m)

	stage.add_child(v3d["container"])

	var line := Label.new()
	if lvl_num == 5:
		line.text = str(stats.get("mood_quote", "推开风铃门收下亲手烫好的像素拼豆，温暖的微光洒满整间小店！"))
	elif lvl_num == 4:
		line.text = str(stats.get("mood_quote", "穿过云巅飞瀑，终于在山脚碧潭再次牵住你的手啦！"))
	elif lvl_num == 3:
		line.text = "喝到热乎乎的珍珠奶茶，TA 终于破涕为笑原谅你啦！快一起走出森林吧！"
	elif lvl_num == 2:
		line.text = "小跳蛙全部被赶跑啦！有你在身边，黑漆漆的森林一点也不怕了~"
	else:
		line.text = (
			"终于找到你啦！这片森林的雾好大，还好有发光蘑菇指引我。"
			if stats["role"] == "boy"
			else "终于找到你啦！森林里的花花草草都在帮我指路呢。"
		)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", 18)
	line.add_theme_color_override("font_color", Color(1.0, 0.97, 0.92))
	vb.add_child(line)

	var stat_lbl := Label.new()
	if lvl_num == 5:
		stat_lbl.text = "总用时 %.1f 秒   |   算术答对 %d 题 / 震板 %d 次   |   TA 态度：%s" % [
			float(stats.get("time", 0.0)),
			int(stats.get("quiz_right", 0)),
			int(stats.get("quiz_wrong", 0)),
			str(stats.get("mood_name", "惊喜心动"))
		]
	elif lvl_num == 4:
		stat_lbl.text = "下落用时 %.1f 秒   |   碰撞障碍 %d 次   |   加速水环 %d 个   |   TA 心情：%s" % [
			float(stats.get("time", 0.0)),
			int(stats.get("hits", 0)),
			int(stats.get("rings", 0)),
			str(stats.get("mood_name", "超开心"))
		]
	elif lvl_num == 3:
		stat_lbl.text = "点亮蘑菇 %d/4   |   珍珠奶茶：已送达   |   被烤黑次数：%d 次" % [
			stats["mushrooms"],
			stats.get("burns", 0)
		]
	elif lvl_num == 2:
		stat_lbl.text = "点亮蘑菇 %d/5   |   赶跑小跳蛙 %d/6   |   专属信物：%s" % [
			stats["mushrooms"],
			stats.get("frogs", 6),
			"已拾取" if stats["keepsake"] else "未拾取"
		]
	else:
		stat_lbl.text = "点亮蘑菇 %d/4   |   专属信物：%s   |   小刺猬彩蛋：%s" % [
			stats["mushrooms"],
			"已拾取" if stats["keepsake"] else "未拾取",
			"已触发" if stats.get("egg", false) else "未触发"
		]
	stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_lbl.add_theme_font_size_override("font_size", 15)
	stat_lbl.add_theme_color_override("font_color", Color(0.80, 0.88, 0.90))
	vb.add_child(stat_lbl)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 20)
	vb.add_child(btns)

	var focus_target: Button = null
	if lvl_num < 5:
		var next_btn := _make_menu_button("前往第 %d 关" % (lvl_num + 1), true)
		next_btn.custom_minimum_size = Vector2(184, 46)
		next_btn.add_theme_font_size_override("font_size", 18)
		next_btn.pressed.connect(func(): _start_level(stats["role"], lvl_num + 1))
		btns.add_child(next_btn)
		focus_target = next_btn

	var replay_btn := _make_menu_button("返回主菜单", lvl_num >= 5)
	replay_btn.custom_minimum_size = Vector2(164, 46)
	replay_btn.add_theme_font_size_override("font_size", 18)
	replay_btn.pressed.connect(_show_select_screen)
	btns.add_child(replay_btn)
	if focus_target == null:
		focus_target = replay_btn

	var quit_btn := _make_menu_button("退出游戏")
	quit_btn.custom_minimum_size = Vector2(144, 46)
	quit_btn.add_theme_font_size_override("font_size", 18)
	quit_btn.pressed.connect(func(): get_tree().quit())
	btns.add_child(quit_btn)
	focus_target.grab_focus()


func _clear_all() -> void:
	_close_modal()
	menu_couple.clear()
	menu_fireflies.clear()
	menu_hearts_3d.clear()
	menu_sway_trees.clear()
	preview_models.clear()
	rising_hearts.clear()
	if select_layer and is_instance_valid(select_layer):
		select_layer.queue_free()
		select_layer = null
	if victory_layer and is_instance_valid(victory_layer):
		victory_layer.queue_free()
		victory_layer = null
	if current_level and is_instance_valid(current_level):
		current_level.queue_free()
		current_level = null
