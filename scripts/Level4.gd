extends Node3D
class_name Level4Scene

signal level_cleared(stats: Dictionary)
signal back_to_select
signal restart_level

## Level 4: 云巅飞瀑（离开森林 · 大鹈鹕大追击）
## Steep 80-degree 3D waterfall speed-descent chase with a procedural 3D Giant Pelican.
## Never fails / zero Game Over: obstacles only slow you down, affecting TA's 4-tier arrival mood!

const TOTAL_DROP := 620.0
const HALF_W := 6.3
const SLOPE_SIN := 0.90630779  # sin(65 deg) - steep thrilling waterfall with wide forward sightline!
const SLOPE_COS := 0.42261826  # cos(65 deg)
const SLOPE_TILT_DEG := -25.0

const BASE_SPEED := 11.8
const DIVE_SPEED := 16.4
const BRAKE_SPEED := 7.4
const PELICAN_LAND_TIME := 38.5

var role: String = "boy"
var partner_role: String = "girl"

# Phases: "intro" -> "chase" -> "finale" -> "done"
var phase: String = "intro"
var intro_timer: float = 0.0
var intro_snatched: bool = false
var intro_partner: Chibi3D = null
var elapsed_time: float = 0.0
var finish_time: float = 0.0
var finale_timer: float = 0.0
var cleared: bool = false

# Player waterfall state
var player_root: Node3D
var player_model: Chibi3D
var px: float = 0.0
var vx: float = 0.0
var ps: float = 0.0
var vs: float = BASE_SPEED
var lift: float = 0.45
var v_lift: float = 0.0
var jump_cd: float = 0.0
var jump_buffer: float = 0.0
var invuln_timer: float = 0.0
var boost_timer: float = 0.0
var hit_count: int = 0
var rings_collected: int = 0
var drip_timer: float = 0.0
var telepathy_cd: float = 0.0
var telepathy_flash: float = 0.0
var telepathy_orbs: Array[Dictionary] = []

# Giant Pelican & Partner
var pelican_root: Node3D
var pelican_wing_l: Node3D
var pelican_wing_r: Node3D
var pelican_pouch: Node3D
var pelican_partner: Chibi3D
var pelican_s: float = 16.0
var pelican_landed: bool = false
var pelican_spit_done: bool = false
var pelican_flyaway_t: float = 0.0

var shore_partner: Chibi3D
var shore_partner_pos: Vector3 = Vector3.ZERO
var shore_boulder_pos: Vector3 = Vector3.ZERO
var emotion_badge: Node3D = null
var finale_tier: int = 1
var finale_mood_name: String = ""
var finale_mood_quote: String = ""
var finale_stage_shown: int = 0

# World & Dynamic Elements
var world_env: WorldEnvironment
var sun_light: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var camera: Camera3D

var obstacles: Array[Dictionary] = []
var boost_rings: Array[Dictionary] = []
var foam_streaks: Array[Dictionary] = []
var spray_drops: Array[Dictionary] = []

# HUD
var ui_layer: CanvasLayer
var hud_label: Label
var hint_label: Label
var toast_panel: Control
var toast_label: Label
var toast_timer: float = 0.0
var mood_banner_lbl: Label
var ruler_ctrl: Control


func init_role(p_role: String) -> void:
	role = p_role
	partner_role = "girl" if role == "boy" else "boy"


func _exit_tree() -> void:
	SoundFX.stop_waterfall_ambient()


func _slope_pos(x: float, s: float, lift_h: float = 0.0) -> Vector3:
	var y := (TOTAL_DROP - s) * SLOPE_SIN + lift_h * SLOPE_COS
	var z := s * SLOPE_COS + lift_h * SLOPE_SIN
	return Vector3(x, y, z)


func _mat(col: Color, rough: float = 0.82, emit_col: Color = Color.BLACK, emit_e: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.roughness = rough
	m.metallic_specular = 0.16 if rough > 0.4 else 0.45
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit_e > 0.0:
		m.emission_enabled = true
		m.emission = emit_col
		m.emission_energy_multiplier = emit_e
	return m


func _ready() -> void:
	_setup_env_and_camera()
	_build_cliff_and_waterfall()
	_build_lagoon_and_shore()
	_populate_course()
	_build_pelican()
	_build_player_and_shore_partner()
	_build_hud()
	SoundFX.start_waterfall_ambient()
	SoundFX.set_waterfall_intensity(0.28)
	_show_toast("终于走出密林来到云巅崖口！咦，天上怎么飞来一个大黑影……（按 Space/Enter 可跳过）", 2.4)


func _setup_env_and_camera() -> void:
	world_env = WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.11, 0.28, 0.42)
	sky_mat.sky_horizon_color = Color(0.45, 0.72, 0.78)
	sky_mat.ground_bottom_color = Color(0.12, 0.24, 0.28)
	sky_mat.ground_horizon_color = Color(0.34, 0.56, 0.62)
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.56, 0.72, 0.80)
	env.ambient_light_energy = 0.78
	env.fog_enabled = true
	env.fog_light_color = Color(0.54, 0.78, 0.86)
	env.fog_density = 0.0055
	world_env.environment = env
	add_child(world_env)

	sun_light = DirectionalLight3D.new()
	sun_light.light_color = Color(1.0, 0.93, 0.78)
	sun_light.light_energy = 1.12
	sun_light.shadow_enabled = true
	sun_light.rotation_degrees = Vector3(-42, 34, 0)
	add_child(sun_light)

	var cool_fill := DirectionalLight3D.new()
	cool_fill.light_color = Color(0.42, 0.76, 0.98)
	cool_fill.light_energy = 0.36
	cool_fill.rotation_degrees = Vector3(-18, -142, 0)
	add_child(cool_fill)

	camera = Camera3D.new()
	camera.fov = 58.0
	camera.far = 420.0
	add_child(camera)
	camera.current = true


func _build_cliff_and_waterfall() -> void:
	var cliff_mat := VisualPolish.make_terrain_mat(
		Color(0.20, 0.24, 0.26), Color(0.24, 0.40, 0.24), Color(0.08, 0.13, 0.18), 0.36
	)
	var moss_top_mat := VisualPolish.make_terrain_mat(
		Color(0.20, 0.44, 0.24), Color(0.42, 0.58, 0.28), Color(0.09, 0.22, 0.20), 0.48
	)

	# 1. Cliff-top forest ledge (s = 0, y ~ 610.6)
	var top_y := TOTAL_DROP * SLOPE_SIN
	var ledge := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(44.0, 6.0, 22.0)
	ledge.mesh = lm
	ledge.material_override = moss_top_mat
	ledge.position = Vector3(0.0, top_y - 3.0, -10.5)
	add_child(ledge)

	# Cliff-top forest trees framing the exit from the woods
	for tx in [-12.0, -8.5, -5.2, 5.5, 9.0, 12.5]:
		_spawn_pine(Vector3(float(tx), top_y, randf_range(-8.5, -3.5)), randf_range(1.15, 1.55))

	# 2. Steep 80-degree waterfall water curtain (6 long segments for clean tiling)
	var wf_mat := VisualPolish.make_water_mat(
		Color(0.06, 0.36, 0.56), Color(0.22, 0.78, 0.88), Vector2(0.0, -1.0), 2.55
	)
	var seg_len := TOTAL_DROP / 6.0
	for i in range(6):
		var s_mid := (float(i) + 0.5) * seg_len
		var water_plane := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(HALF_W * 2.0 + 1.8, seg_len + 1.5, 1.2)
		water_plane.mesh = bm
		water_plane.material_override = wf_mat
		water_plane.position = _slope_pos(0.0, s_mid, -0.75)
		water_plane.rotation_degrees = Vector3(SLOPE_TILT_DEG, 0.0, 0.0)
		add_child(water_plane)

		# Back wet rock cliff behind the water curtain
		var backing := MeshInstance3D.new()
		var bkm := BoxMesh.new()
		bkm.size = Vector3(HALF_W * 2.0 + 18.0, seg_len + 2.0, 8.0)
		backing.mesh = bkm
		backing.material_override = cliff_mat
		backing.position = _slope_pos(0.0, s_mid, -5.4)
		backing.rotation_degrees = Vector3(SLOPE_TILT_DEG, 0.0, 0.0)
		add_child(backing)

	# 3. Flanking rocky cliff walls, overhanging pines & mossy crags
	var rng := RandomNumberGenerator.new()
	rng.seed = 40401
	for i in range(44):
		var s_pos := float(i) * (TOTAL_DROP / 44.0) + rng.randf_range(-4.0, 4.0)
		for side_v in [-1.0, 1.0]:
			var side: float = float(side_v)
			var wall := MeshInstance3D.new()
			var wm := BoxMesh.new()
			var bw := rng.randf_range(5.5, 9.5)
			var bh := rng.randf_range(16.0, 24.0)
			var bd := rng.randf_range(6.0, 11.0)
			wm.size = Vector3(bw, bh, bd)
			wall.mesh = wm
			wall.material_override = cliff_mat
			wall.position = _slope_pos(side * (HALF_W + 2.2 + bw * 0.42), s_pos, rng.randf_range(0.5, 3.2))
			wall.rotation_degrees = Vector3(SLOPE_TILT_DEG + rng.randf_range(-6, 6), rng.randf_range(-12, 12), rng.randf_range(-5, 5))
			add_child(wall)

			# Zone 1: clinging forest pines & vines on upper cliff walls
			if s_pos < 220.0 and i % 2 == 0:
				var tree_p := _slope_pos(side * (HALF_W + 2.6 + rng.randf_range(0.0, 2.8)), s_pos, 4.0)
				_spawn_pine(tree_p, rng.randf_range(0.85, 1.35))

	# 4. Zone 2: Volumetric Cloud Mist Band (s ~ 195..225) & Dual 3D Rainbow Arches!
	var cloud_mat := _mat(Color(0.96, 0.99, 1.0), 0.95, Color(0.82, 0.92, 1.0), 0.28, 0.36)
	for i in range(16):
		var cs := 192.0 + float(i) * 1.9 + rng.randf_range(-3.0, 3.0)
		var cx := rng.randf_range(-11.5, 11.5)
		var cl := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(2.6, 4.4)
		sm.height = sm.radius * 1.15
		sm.radial_segments = 12
		sm.rings = 8
		cl.mesh = sm
		cl.material_override = cloud_mat
		cl.position = _slope_pos(cx, cs, rng.randf_range(2.2, 6.5))
		add_child(cl)

	_build_rainbow_arch(285.0, 12.5)
	_build_rainbow_arch(410.0, 14.0)

	# 5. Fast-scrolling white foam streak ribbons along the waterfall
	var foam_mat := _mat(Color(0.92, 0.99, 1.0), 0.35, Color(0.82, 0.96, 1.0), 0.55, 0.62)
	for i in range(24):
		var f := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(rng.randf_range(0.18, 0.42), rng.randf_range(4.5, 9.5), 0.08)
		f.mesh = fm
		f.material_override = foam_mat
		var s0 := rng.randf_range(0.0, TOTAL_DROP)
		var x0 := rng.randf_range(-HALF_W + 0.5, HALF_W - 0.5)
		f.position = _slope_pos(x0, s0, 0.05)
		f.rotation_degrees = Vector3(SLOPE_TILT_DEG, 0.0, 0.0)
		add_child(f)
		foam_streaks.append({"node": f, "x": x0, "s": s0, "spd": rng.randf_range(22.0, 34.0)})

	# 6. Dynamic rushing spray droplets around player
	var drop_mat := _mat(Color(0.88, 0.98, 1.0), 0.25, Color(0.72, 0.95, 1.0), 0.65, 0.72)
	for i in range(28):
		var d := MeshInstance3D.new()
		var dm := SphereMesh.new()
		dm.radius = rng.randf_range(0.06, 0.12)
		dm.height = dm.radius * 2.6
		dm.radial_segments = 6
		dm.rings = 4
		d.mesh = dm
		d.material_override = drop_mat
		add_child(d)
		spray_drops.append({
			"node": d,
			"ox": rng.randf_range(-6.5, 6.5),
			"os": rng.randf_range(-12.0, 26.0),
			"ol": rng.randf_range(0.4, 4.5),
			"spd": rng.randf_range(16.0, 28.0),
		})


func _build_rainbow_arch(s_center: float, radius: float) -> void:
	## Single continuous 60-segment smooth vertex-colored prismatic rainbow ribbon (zero boxy stair-steps!)
	var arch_root := Node3D.new()
	arch_root.position = _slope_pos(0.0, s_center, 0.9)
	arch_root.rotation_degrees = Vector3(SLOPE_TILT_DEG + 90.0, 0.0, 0.0)
	add_child(arch_root)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 9 radial stops: feathered outer transparent edge -> 7 luminous spectrum bands -> feathered inner edge
	var band_cols: Array[Color] = [
		Color(1.0, 0.28, 0.34, 0.00),
		Color(1.0, 0.30, 0.34, 0.52),
		Color(1.0, 0.62, 0.22, 0.56),
		Color(1.0, 0.92, 0.30, 0.58),
		Color(0.34, 0.92, 0.52, 0.56),
		Color(0.28, 0.84, 1.00, 0.54),
		Color(0.38, 0.54, 1.00, 0.50),
		Color(0.72, 0.44, 1.00, 0.46),
		Color(0.72, 0.44, 1.00, 0.00),
	]
	var band_w := 2.9
	var ang_segs := 60
	var r_steps := band_cols.size()

	var grid: Array[Array] = []
	var col_grid: Array[Array] = []
	for k in range(ang_segs + 1):
		var u := float(k) / float(ang_segs)
		var ang := lerpf(0.05 * PI, 0.95 * PI, u)
		# Soft fade at the two ground-entering ends of the rainbow arc
		var end_fade := sin(u * PI)
		end_fade = clampf(pow(end_fade, 0.45), 0.0, 1.0)
		var row_v: Array[Vector3] = []
		var row_c: Array[Color] = []
		for ri in range(r_steps):
			var rv := float(ri) / float(r_steps - 1)
			var r := radius - rv * band_w
			row_v.append(Vector3(cos(ang) * r, sin(ang) * r * 0.68, 0.0))
			var bc: Color = band_cols[ri]
			row_c.append(Color(bc.r, bc.g, bc.b, bc.a * end_fade))
		grid.append(row_v)
		col_grid.append(row_c)

	for k in range(ang_segs):
		for ri in range(r_steps - 1):
			var p00: Vector3 = grid[k][ri]
			var p10: Vector3 = grid[k + 1][ri]
			var p11: Vector3 = grid[k + 1][ri + 1]
			var p01: Vector3 = grid[k][ri + 1]
			var c00: Color = col_grid[k][ri]
			var c10: Color = col_grid[k + 1][ri]
			var c11: Color = col_grid[k + 1][ri + 1]
			var c01: Color = col_grid[k][ri + 1]
			st.set_color(c00); st.add_vertex(p00)
			st.set_color(c10); st.add_vertex(p10)
			st.set_color(c11); st.add_vertex(p11)
			st.set_color(c00); st.add_vertex(p00)
			st.set_color(c11); st.add_vertex(p11)
			st.set_color(c01); st.add_vertex(p01)

	st.index()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	arch_root.add_child(mi)


func _build_lagoon_and_shore() -> void:
	var base_z := TOTAL_DROP * SLOPE_COS
	# Deep sunlit emerald lagoon
	var lagoon := MeshInstance3D.new()
	var lgm := BoxMesh.new()
	lgm.size = Vector3(68.0, 0.8, 42.0)
	lagoon.mesh = lgm
	lagoon.material_override = VisualPolish.make_water_mat(
		Color(0.04, 0.34, 0.44), Color(0.18, 0.78, 0.76), Vector2(0.0, 1.0), 0.75
	)
	lagoon.position = Vector3(0.0, -0.4, base_z + 10.0)
	add_child(lagoon)

	# Plunge pool mist foam ring at waterfall foot
	var foot_foam := MeshInstance3D.new()
	var ffm := CylinderMesh.new()
	ffm.top_radius = 9.2
	ffm.bottom_radius = 10.5
	ffm.height = 0.22
	ffm.radial_segments = 24
	foot_foam.mesh = ffm
	foot_foam.material_override = _mat(Color(0.92, 0.99, 1.0), 0.35, Color(0.84, 0.97, 1.0), 0.48, 0.74)
	foot_foam.position = Vector3(0.0, 0.06, base_z + 1.5)
	add_child(foot_foam)

	# Sunlit valley pebble & grass shore ahead of the lagoon!
	var beach_mat := VisualPolish.make_terrain_mat(
		Color(0.74, 0.68, 0.50), Color(0.86, 0.78, 0.56), Color(0.52, 0.50, 0.42), 0.85
	)
	var meadow_mat := VisualPolish.make_terrain_mat(
		Color(0.24, 0.54, 0.28), Color(0.46, 0.68, 0.30), Color(0.14, 0.34, 0.26), 0.52
	)
	var shore := MeshInstance3D.new()
	var shm := CylinderMesh.new()
	shm.top_radius = 18.0
	shm.bottom_radius = 20.5
	shm.height = 1.6
	shm.radial_segments = 28
	shore.mesh = shm
	shore.material_override = beach_mat
	shore.position = Vector3(0.0, -0.45, base_z + 25.0)
	add_child(shore)

	var meadow := MeshInstance3D.new()
	var mdm := BoxMesh.new()
	mdm.size = Vector3(84.0, 1.4, 48.0)
	meadow.mesh = mdm
	meadow.material_override = meadow_mat
	meadow.position = Vector3(0.0, -0.55, base_z + 46.0)
	add_child(meadow)

	# Shore sitting boulder (for Tier 4 sulking TA!) & decorative pebbles
	shore_partner_pos = Vector3(0.0, 0.35, base_z + 17.5)
	shore_boulder_pos = Vector3(1.85, 0.35, base_z + 18.2)
	var rock_mat := VisualPolish.make_organic_mat(Color(0.54, 0.56, 0.58), 1.4, 0.72, 0.95)
	var sit_rock := MeshInstance3D.new()
	var srm := SphereMesh.new()
	srm.radius = 0.82
	srm.height = 0.92
	srm.radial_segments = 12
	srm.rings = 8
	sit_rock.mesh = srm
	sit_rock.material_override = rock_mat
	sit_rock.position = shore_boulder_pos + Vector3(0.0, 0.22, 0.0)
	sit_rock.scale = Vector3(1.15, 0.72, 1.0)
	add_child(sit_rock)

	# Valley pines & bright wildflowers framing the finish cove
	for tx in [-14.0, -10.5, -7.8, 8.2, 11.4, 15.0]:
		_spawn_pine(Vector3(float(tx), 0.15, base_z + 23.0 + absf(float(tx)) * 0.45), randf_range(1.1, 1.6))


func _spawn_pine(pos: Vector3, sc: float) -> void:
	var t := Node3D.new()
	t.position = pos
	t.scale = Vector3.ONE * sc
	add_child(t)
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.18
	tm.bottom_radius = 0.30
	tm.height = 1.6
	tm.radial_segments = 6
	trunk.mesh = tm
	trunk.material_override = _mat(Color(0.36, 0.24, 0.15), 0.92)
	trunk.position = Vector3(0, 0.8, 0)
	t.add_child(trunk)
	for k in range(3):
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 1.35 - float(k) * 0.30
		cm.height = 1.5
		cm.radial_segments = 7
		c.mesh = cm
		c.material_override = _mat(Color(0.14 + float(k) * 0.04, 0.42 + float(k) * 0.06, 0.24), 0.86)
		c.position = Vector3(0, 1.55 + float(k) * 0.90, 0)
		t.add_child(c)


func _populate_course() -> void:
	## Deterministic curated + varied obstacle & boost ring layout across all 3 waterfall zones!
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260404
	var rock_mat := VisualPolish.make_organic_mat(Color(0.28, 0.32, 0.35), 1.4, 0.55, 0.88)
	var log_mat := VisualPolish.make_organic_mat(Color(0.46, 0.30, 0.16), 1.6, 0.78, 0.95)
	var vine_mat := _mat(Color(0.18, 0.52, 0.24), 0.82)
	var swirl_mat := _mat(Color(0.68, 0.96, 1.0), 0.20, Color(0.35, 0.86, 1.0), 0.85, 0.72)

	var s_cursor := 34.0
	var idx := 0
	while s_cursor < TOTAL_DROP - 38.0:
		var zone := 1 if s_cursor < 200.0 else (2 if s_cursor < 440.0 else 3)
		var step := 22.0 if zone == 1 else (16.5 if zone == 2 else 14.8)

		# Place a glowing Boost Water Ring every 3rd segment in a rewarding line!
		if idx % 3 == 1:
			var rx := rng.randf_range(-4.2, 4.2)
			_spawn_boost_ring(rx, s_cursor + step * 0.48)

		var roll := rng.randf()
		if zone == 1:
			if roll < 0.62:
				_spawn_rock(rng.randf_range(-4.8, 4.8), s_cursor, rng.randf_range(1.05, 1.45), rock_mat)
			else:
				_spawn_log(rng.randf_range(-2.6, 2.6), s_cursor, rng.randf_range(3.6, 4.8), log_mat, vine_mat)
		else:
			if roll < 0.34:
				# Paired rocks with a weave gap
				var cx := rng.randf_range(-4.8, 0.8)
				_spawn_rock(cx, s_cursor, rng.randf_range(1.0, 1.35), rock_mat)
				if cx + 4.4 <= 5.2:
					_spawn_rock(cx + 4.4, s_cursor + 2.5, rng.randf_range(0.95, 1.25), rock_mat)
			elif roll < 0.58:
				_spawn_log(rng.randf_range(-2.4, 2.4), s_cursor, rng.randf_range(4.2, 5.6), log_mat, vine_mat)
			elif roll < 0.78:
				_spawn_whirlpool(rng.randf_range(-4.4, 4.4), s_cursor, swirl_mat)
			else:
				_spawn_waterbird(s_cursor, 1.0 if idx % 2 == 0 else -1.0, rng.randf_range(3.4, 5.2))

		s_cursor += step
		idx += 1


func _spawn_rock(x: float, s: float, rad: float, mat: Material) -> void:
	var n := Node3D.new()
	n.position = _slope_pos(x, s, 0.35)
	add_child(n)
	var main := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = rad
	sm.height = rad * 1.45
	sm.radial_segments = 10
	sm.rings = 6
	main.mesh = sm
	main.material_override = mat
	main.scale = Vector3(1.12, 0.92, 0.88)
	n.add_child(main)

	var sub := MeshInstance3D.new()
	var sm2 := SphereMesh.new()
	sm2.radius = rad * 0.62
	sm2.height = rad * 1.0
	sm2.radial_segments = 8
	sm2.rings = 5
	sub.mesh = sm2
	sub.material_override = mat
	sub.position = Vector3(rad * 0.62, -rad * 0.22, 0.25)
	n.add_child(sub)

	var hl := _make_highlight_ring(rad * 1.15)
	n.add_child(hl)
	obstacles.append({
		"type": "rock", "node": n, "x": x, "s": s,
		"half_w": rad * 0.95, "half_s": rad * 0.85, "jumpable": false,
		"hl": hl, "hit_cd": 0.0,
	})


func _spawn_log(x: float, s: float, width: float, log_mat: Material, vine_mat: Material) -> void:
	var n := Node3D.new()
	n.position = _slope_pos(x, s, 0.52)
	add_child(n)
	var cyl := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.42
	cm.bottom_radius = 0.48
	cm.height = width
	cm.radial_segments = 10
	cyl.mesh = cm
	cyl.material_override = log_mat
	cyl.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	n.add_child(cyl)

	# Hanging moss vines draped from the driftwood log
	for vx_i in range(-2, 3):
		var v := MeshInstance3D.new()
		var vm := BoxMesh.new()
		vm.size = Vector3(0.14, 0.95 + float(abs(vx_i) % 2) * 0.35, 0.12)
		v.mesh = vm
		v.material_override = vine_mat
		v.position = Vector3(float(vx_i) * (width * 0.18), -0.58, 0.22)
		n.add_child(v)

	var hl := _make_highlight_ring(width * 0.42)
	n.add_child(hl)
	obstacles.append({
		"type": "log", "node": n, "x": x, "s": s,
		"half_w": width * 0.52, "half_s": 0.90, "jumpable": true,
		"hl": hl, "hit_cd": 0.0,
	})


func _spawn_whirlpool(x: float, s: float, mat: Material) -> void:
	var n := Node3D.new()
	n.position = _slope_pos(x, s, 0.28)
	n.rotation_degrees = Vector3(-10.0, 0.0, 0.0)
	add_child(n)
	var spin := Node3D.new()
	n.add_child(spin)
	for r_i in range(2):
		var t := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.72 + float(r_i) * 0.55
		tm.outer_radius = 0.98 + float(r_i) * 0.58
		tm.rings = 18
		tm.ring_segments = 8
		t.mesh = tm
		t.material_override = mat
		t.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		spin.add_child(t)

	var hl := _make_highlight_ring(1.6)
	n.add_child(hl)
	obstacles.append({
		"type": "whirlpool", "node": n, "spin": spin, "x": x, "s": s,
		"half_w": 1.65, "half_s": 1.65, "jumpable": true,
		"hl": hl, "hit_cd": 0.0,
	})


func _spawn_waterbird(s: float, dir: float, speed: float) -> void:
	var n := Node3D.new()
	var start_x := -dir * (HALF_W + 1.2)
	n.position = _slope_pos(start_x, s, 1.05)
	add_child(n)
	var white_m := _mat(Color(0.96, 0.98, 1.0), 0.65)
	var beak_m := _mat(Color(0.98, 0.62, 0.16), 0.55)
	var tip_m := _mat(Color(0.18, 0.22, 0.28), 0.72)

	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.36
	bm.height = 0.92
	body.mesh = bm
	body.material_override = white_m
	body.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	n.add_child(body)

	var beak := MeshInstance3D.new()
	var bkm := CylinderMesh.new()
	bkm.top_radius = 0.01
	bkm.bottom_radius = 0.11
	bkm.height = 0.42
	beak.mesh = bkm
	beak.material_override = beak_m
	beak.position = Vector3(dir * 0.55, 0.04, 0.0)
	beak.rotation_degrees = Vector3(0.0, 0.0, -dir * 90.0)
	n.add_child(beak)

	var wl := Node3D.new()
	var wr := Node3D.new()
	n.add_child(wl)
	n.add_child(wr)
	for side_v in [-1.0, 1.0]:
		var sv: float = float(side_v)
		var wp := wl if sv < 0.0 else wr
		var w := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.42, 0.07, 1.15)
		w.mesh = wm
		w.material_override = white_m
		w.position = Vector3(0.0, 0.05, sv * 0.58)
		wp.add_child(w)
		var wt := MeshInstance3D.new()
		var wtm := BoxMesh.new()
		wtm.size = Vector3(0.32, 0.06, 0.36)
		wt.mesh = wtm
		wt.material_override = tip_m
		wt.position = Vector3(0.0, 0.05, sv * 1.18)
		wp.add_child(wt)

	# Edge feather warning glow
	var warn_orb := MeshInstance3D.new()
	var wom := SphereMesh.new()
	wom.radius = 0.24
	wom.height = 0.48
	warn_orb.mesh = wom
	warn_orb.material_override = _mat(Color(1.0, 0.92, 0.55), 0.3, Color(1.0, 0.85, 0.35), 1.4, 0.78)
	warn_orb.position = Vector3(0.0, 0.48, 0.0)
	n.add_child(warn_orb)

	var hl := _make_highlight_ring(1.05)
	n.add_child(hl)
	obstacles.append({
		"type": "bird", "node": n, "wl": wl, "wr": wr, "warn": warn_orb,
		"x": start_x, "s": s, "dir": dir, "spd": speed, "warned": false,
		"half_w": 0.95, "half_s": 1.05, "jumpable": false,
		"hl": hl, "hit_cd": 0.0,
	})


func _spawn_boost_ring(x: float, s: float) -> void:
	var n := Node3D.new()
	n.position = _slope_pos(x, s, 0.95)
	n.rotation_degrees = Vector3(-10.0, 0.0, 0.0)
	add_child(n)
	var torus := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.15
	tm.outer_radius = 1.42
	tm.rings = 24
	tm.ring_segments = 10
	torus.mesh = tm
	var rmat := _mat(Color(0.45, 0.98, 1.0), 0.16, Color(0.36, 0.94, 1.0), 1.55, 0.88)
	torus.material_override = rmat
	n.add_child(torus)

	var inner := MeshInstance3D.new()
	var im := TorusMesh.new()
	im.inner_radius = 0.86
	im.outer_radius = 0.96
	im.rings = 18
	im.ring_segments = 8
	inner.mesh = im
	inner.material_override = _mat(Color(1.0, 0.92, 0.48), 0.20, Color(1.0, 0.88, 0.36), 1.45, 0.85)
	n.add_child(inner)

	boost_rings.append({
		"node": n, "x": x, "s": s, "taken": false, "mat": rmat,
	})


func _make_highlight_ring(rad: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = maxf(0.4, rad - 0.14)
	tm.outer_radius = rad + 0.06
	tm.rings = 18
	tm.ring_segments = 6
	m.mesh = tm
	m.material_override = _mat(Color(0.42, 0.96, 1.0), 0.2, Color(0.42, 0.96, 1.0), 2.2, 0.82)
	m.rotation_degrees = Vector3(80.0, 0.0, 0.0)
	m.visible = false
	return m


func _build_sculpted_upper_beak(parent: Node3D) -> MeshInstance3D:
	## Plump, friendly cartoon pelican upper mandible: broad rounded dome tapering cleanly at the hooked tip!
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var len_segs := 16
	var rad_segs := 18
	var rings: Array[Array] = []
	var cols: Array[Color] = []

	for i in range(len_segs + 1):
		var u := float(i) / float(len_segs)
		var z := lerpf(1.38, 3.28, u)
		# Keep bill generously broad along the shaft, tapering smoothly near the rounded hooked tip!
		var rx := lerpf(0.42, 0.055, pow(u, 1.85))
		var arch_h := lerpf(0.28, 0.085, pow(u, 1.35))
		var flat_bot := lerpf(-0.05, -0.02, u)
		# Gentle upward clearance over the open pouch + cute soft downward hook at the tip
		var y_base := 1.20 + 0.06 * sin(u * PI) - 0.24 * pow(maxf(0.0, (u - 0.74) / 0.26), 2.0)
		var c := Color(0.99, 0.74, 0.24).lerp(Color(0.96, 0.48, 0.14), pow(u, 1.35))
		cols.append(c)

		var ring: Array[Vector3] = []
		for s in range(rad_segs):
			var a := float(s) / float(rad_segs) * TAU
			var cs := cos(a)
			var sn := sin(a)
			var px := cs * rx
			var py := y_base + (sn * arch_h if sn >= 0.0 else sn * absf(flat_bot))
			ring.append(Vector3(px, py, z))
		rings.append(ring)

	for i in range(len_segs):
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		var c0 := cols[i]
		var c1 := cols[i + 1]
		for s in range(rad_segs):
			var sn := (s + 1) % rad_segs
			st.set_color(c0); st.add_vertex(r0[s])
			st.set_color(c1); st.add_vertex(r1[s])
			st.set_color(c1); st.add_vertex(r1[sn])
			st.set_color(c0); st.add_vertex(r0[s])
			st.set_color(c1); st.add_vertex(r1[sn])
			st.set_color(c0); st.add_vertex(r0[sn])

	var tip_c := Vector3(0.0, 0.92, 3.31)
	var last_r: Array = rings[len_segs]
	for s in range(rad_segs):
		var sn := (s + 1) % rad_segs
		st.set_color(cols[len_segs]); st.add_vertex(last_r[s])
		st.set_color(cols[len_segs]); st.add_vertex(tip_c)
		st.set_color(cols[len_segs]); st.add_vertex(last_r[sn])

	st.index()
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.46
	mat.metallic_specular = 0.26
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _build_sculpted_pouch(parent: Node3D) -> MeshInstance3D:
	## Organic hammock-curved lower pelican jaw & plump gular throat pouch matching the broad upper bill!
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var len_segs := 16
	var rad_segs := 18
	var rings: Array[Array] = []
	var cols: Array[Array] = []

	for i in range(len_segs + 1):
		var u := float(i) / float(len_segs)
		var z := lerpf(-0.14, 1.78, u)
		var rx := lerpf(0.41, 0.055, pow(u, 1.85))
		var pouch_drop := 0.08 + 0.78 * pow(sin(u * PI), 0.72)
		var rim_y := 0.05 - 0.12 * pow(u, 1.5)
		var ring: Array[Vector3] = []
		var rcols: Array[Color] = []
		for s in range(rad_segs):
			var a := float(s) / float(rad_segs) * TAU
			var cs := cos(a)
			var sn := sin(a)
			var px := cs * rx * (1.0 + 0.20 * maxf(0.0, -sn) * sin(u * PI))
			var py := rim_y + (sn * 0.045 if sn >= 0.0 else sn * pouch_drop)
			ring.append(Vector3(px, py, z))
			var belly_k := clampf(-sn, 0.0, 1.0)
			rcols.append(Color(0.98, 0.64, 0.18).lerp(Color(1.0, 0.87, 0.46), pow(belly_k, 0.65)))
		rings.append(ring)
		cols.append(rcols)

	for i in range(len_segs):
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		var c0: Array = cols[i]
		var c1: Array = cols[i + 1]
		for s in range(rad_segs):
			var sn := (s + 1) % rad_segs
			st.set_color(c0[s]); st.add_vertex(r0[s])
			st.set_color(c1[s]); st.add_vertex(r1[s])
			st.set_color(c1[sn]); st.add_vertex(r1[sn])
			st.set_color(c0[s]); st.add_vertex(r0[s])
			st.set_color(c1[sn]); st.add_vertex(r1[sn])
			st.set_color(c0[sn]); st.add_vertex(r0[sn])

	st.index()
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.56
	mat.metallic_specular = 0.18
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _build_pelican() -> void:
	## Procedural 3D Giant Pelican: sculpted curved neck, organic tapered orange bill & bulging yellow pouch,
	## sleek curved white wings with black tips, carrying the waving Chibi3D partner!
	pelican_root = Node3D.new()
	pelican_root.position = _slope_pos(0.0, 12.0, 4.5)
	add_child(pelican_root)

	var white_f := _mat(Color(0.97, 0.98, 0.99), 0.74)
	var cream_f := _mat(Color(0.94, 0.92, 0.86), 0.80)
	var black_tip := _mat(Color(0.14, 0.16, 0.21), 0.76)
	var orange_foot := _mat(Color(0.96, 0.56, 0.14), 0.52)
	var eye_m := _mat(Color(0.08, 0.08, 0.10), 0.08)
	var eye_ring := _mat(Color(0.98, 0.86, 0.42), 0.58)

	# Plump rounded pelican torso
	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 1.04
	bm.height = 2.60
	bm.radial_segments = 20
	bm.rings = 14
	body.mesh = bm
	body.material_override = white_f
	body.rotation_degrees = Vector3(84.0, 0.0, 0.0)
	body.scale = Vector3(0.92, 1.0, 0.84)
	pelican_root.add_child(body)

	# Soft fanned rounded tail feathers (3 overlapping feathered lobes instead of flat box!)
	for ti in range(-1, 2):
		var tail := MeshInstance3D.new()
		var tm := SphereMesh.new()
		tm.radius = 0.42
		tm.height = 1.25
		tm.radial_segments = 10
		tm.rings = 6
		tail.mesh = tm
		tail.material_override = cream_f if ti == 0 else white_f
		tail.position = Vector3(float(ti) * 0.34, 0.14, -1.48)
		tail.rotation_degrees = Vector3(80.0, float(ti) * 18.0, 0.0)
		tail.scale = Vector3(0.85, 1.0, 0.24)
		pelican_root.add_child(tail)

	# Smooth curved S-neck blending chest into head (overlapping sculpted spheres along curve)
	for ncfg in [
		[Vector3(0.0, 0.28, 0.88), Vector3(0.62, 0.62, 0.64)],
		[Vector3(0.0, 0.58, 1.06), Vector3(0.50, 0.54, 0.52)],
		[Vector3(0.0, 0.88, 1.24), Vector3(0.45, 0.50, 0.48)],
	]:
		var ns := MeshInstance3D.new()
		var nsm := SphereMesh.new()
		nsm.radius = 0.5
		nsm.height = 1.0
		nsm.radial_segments = 14
		nsm.rings = 10
		ns.mesh = nsm
		ns.material_override = white_f
		ns.position = ncfg[0]
		ns.scale = ncfg[1] * 1.42
		pelican_root.add_child(ns)

	# Rounded head & soft swept back crest
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.48
	hm.height = 0.94
	hm.radial_segments = 18
	hm.rings = 12
	head.mesh = hm
	head.material_override = white_f
	head.position = Vector3(0.0, 1.15, 1.38)
	head.scale = Vector3(0.95, 0.96, 1.08)
	pelican_root.add_child(head)

	for ci in range(2):
		var crest := MeshInstance3D.new()
		var crm := SphereMesh.new()
		crm.radius = 0.20 - float(ci) * 0.04
		crm.height = 0.56 - float(ci) * 0.10
		crest.mesh = crm
		crest.material_override = cream_f
		crest.position = Vector3(0.0, 1.46 - float(ci) * 0.10, 1.02 - float(ci) * 0.14)
		crest.rotation_degrees = Vector3(-48.0 - float(ci) * 12.0, 0.0, 0.0)
		pelican_root.add_child(crest)

	# Expressive eyes with warm golden eye-ring & white catchlight
	for side_v in [-1.0, 1.0]:
		var sv: float = float(side_v)
		var ring := MeshInstance3D.new()
		var rm := SphereMesh.new()
		rm.radius = 0.14
		rm.height = 0.28
		ring.mesh = rm
		ring.material_override = eye_ring
		ring.position = Vector3(sv * 0.37, 1.24, 1.56)
		ring.scale = Vector3(0.55, 1.0, 1.0)
		pelican_root.add_child(ring)

		var ey := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.095
		em.height = 0.19
		ey.mesh = em
		ey.material_override = eye_m
		ey.position = Vector3(sv * 0.41, 1.25, 1.59)
		pelican_root.add_child(ey)

	# Sculpted organic upper beak + hinged bulging lower throat pouch!
	_build_sculpted_upper_beak(pelican_root)

	pelican_pouch = Node3D.new()
	pelican_pouch.position = Vector3(0.0, 1.04, 1.52)
	pelican_root.add_child(pelican_pouch)
	_build_sculpted_pouch(pelican_pouch)

	# Trapped partner Chibi3D nestled snugly inside the open pouch UNDER the upper beak (zero clipping!)
	# Hidden initially until the pelican swoops down and snatches TA off the cliff top!
	pelican_partner = Chibi3D.create(partner_role)
	pelican_partner.scale = Vector3.ONE * 0.44
	pelican_partner.position = Vector3(0.0, -0.42, 0.84)
	pelican_partner.rotation_degrees = Vector3(14.0, 180.0, 0.0)
	pelican_partner.set_pelican_trapped(true)
	pelican_partner.visible = false
	pelican_pouch.add_child(pelican_partner)

	# Broad rounded airfoil wings (white inner + dark feathered tips, zero flat planks!)
	pelican_wing_l = Node3D.new()
	pelican_wing_l.position = Vector3(-0.82, 0.34, 0.10)
	pelican_root.add_child(pelican_wing_l)
	pelican_wing_r = Node3D.new()
	pelican_wing_r.position = Vector3(0.82, 0.34, 0.10)
	pelican_root.add_child(pelican_wing_r)

	for side_v in [-1.0, 1.0]:
		var sv: float = float(side_v)
		var wp := pelican_wing_l if sv < 0.0 else pelican_wing_r
		var w_in := MeshInstance3D.new()
		var wim := SphereMesh.new()
		wim.radius = 1.25
		wim.height = 1.35
		wim.radial_segments = 14
		wim.rings = 8
		w_in.mesh = wim
		w_in.material_override = white_f
		w_in.position = Vector3(sv * 1.12, 0.0, 0.02)
		w_in.scale = Vector3(1.05, 0.14, 0.62)
		wp.add_child(w_in)

		var w_tip := MeshInstance3D.new()
		var wtm := SphereMesh.new()
		wtm.radius = 0.82
		wtm.height = 0.95
		wtm.radial_segments = 12
		wtm.rings = 6
		w_tip.mesh = wtm
		w_tip.material_override = black_tip
		w_tip.position = Vector3(sv * 2.48, -0.04, -0.14)
		w_tip.rotation_degrees = Vector3(0.0, -sv * 14.0, -sv * 6.0)
		w_tip.scale = Vector3(1.12, 0.11, 0.48)
		wp.add_child(w_tip)

	# Tucked rounded orange webbed feet
	for side_v in [-1.0, 1.0]:
		var sv: float = float(side_v)
		var foot := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = 0.24
		fm.height = 0.52
		foot.mesh = fm
		foot.material_override = orange_foot
		foot.position = Vector3(sv * 0.36, -0.76, -0.92)
		foot.rotation_degrees = Vector3(82.0, 0.0, 0.0)
		foot.scale = Vector3(0.82, 1.0, 0.28)
		pelican_root.add_child(foot)


func _build_player_and_shore_partner() -> void:
	var top_y := TOTAL_DROP * SLOPE_SIN
	player_root = Node3D.new()
	player_root.position = Vector3(1.15, top_y, -2.6)
	player_root.rotation_degrees = Vector3(0.0, -24.0, 0.0)
	add_child(player_root)
	player_model = Chibi3D.create(role)
	player_root.add_child(player_model)

	# Partner standing peacefully on the cliff-top meadow before the pelican snatches them!
	intro_partner = Chibi3D.create(partner_role)
	intro_partner.position = Vector3(-1.15, top_y, -2.3)
	intro_partner.rotation_degrees = Vector3(0.0, 26.0, 0.0)
	intro_partner.set_waving(1)
	add_child(intro_partner)

	shore_partner = Chibi3D.create(partner_role)
	shore_partner.position = shore_partner_pos
	shore_partner.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	shore_partner.visible = false
	add_child(shore_partner)


func _build_hud() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 1
	add_child(ui_layer)

	var hud := GameUI.build_level_hud(ui_layer, Color(0.46, 0.90, 0.98), _open_settings)
	hud_label = hud["hud_label"]
	hint_label = hud["hint_label"]
	toast_panel = hud["toast_panel"]
	toast_label = hud["toast_label"]
	hint_label.text = "A/D 左右闪避  ·  S 加速俯冲  ·  W 缓降微调  ·  Space 踏水跃起  ·  E/H 心灵感应  ·  ESC 设置"

	# Top-center floating TA live mood indicator (cleanly below top HUD bar, zero overlap!)
	mood_banner_lbl = Label.new()
	mood_banner_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	mood_banner_lbl.offset_left = -280
	mood_banner_lbl.offset_right = 280
	mood_banner_lbl.offset_top = 86
	mood_banner_lbl.offset_bottom = 122
	mood_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUI.style_floating_label(mood_banner_lbl, 18, Color(1.0, 0.92, 0.62), 5)
	hud["root"].add_child(mood_banner_lbl)

	# Right-side Vertical Waterfall Altitude Progress Ruler (architectural hairline, zero card!)
	ruler_ctrl = Control.new()
	ruler_ctrl.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	ruler_ctrl.offset_left = -94
	ruler_ctrl.offset_right = -18
	ruler_ctrl.offset_top = -170
	ruler_ctrl.offset_bottom = 170
	ruler_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ruler_ctrl.draw.connect(_draw_waterfall_ruler)
	hud["root"].add_child(ruler_ctrl)
	_refresh_hud()


func _draw_waterfall_ruler() -> void:
	if ruler_ctrl == null:
		return
	var h := ruler_ctrl.size.y
	var cx := 42.0
	var top_y := 18.0
	var bot_y := h - 18.0
	var span := bot_y - top_y

	# Main vertical brass/aqua hairline
	ruler_ctrl.draw_line(Vector2(cx, top_y), Vector2(cx, bot_y), Color(0.75, 0.92, 0.98, 0.55), 2.0)
	ruler_ctrl.draw_line(Vector2(cx + 4.0, top_y), Vector2(cx + 4.0, bot_y), Color(0.96, 0.86, 0.54, 0.25), 1.0)

	# Zone tick marks (Cliff / Clouds / Valley / Lagoon)
	for frac in [0.0, 0.32, 0.71, 1.0]:
		var ty := top_y + span * float(frac)
		ruler_ctrl.draw_line(Vector2(cx - 8.0, ty), Vector2(cx + 8.0, ty), Color(0.95, 0.92, 0.78, 0.75), 1.5)

	# Pelican / TA diamond marker (warm golden-orange)
	var pel_frac := clampf(pelican_s / TOTAL_DROP, 0.0, 1.0)
	var pel_y := top_y + span * pel_frac
	var pel_poly := PackedVector2Array([
		Vector2(cx, pel_y - 7.0), Vector2(cx + 7.0, pel_y),
		Vector2(cx, pel_y + 7.0), Vector2(cx - 7.0, pel_y),
	])
	ruler_ctrl.draw_colored_polygon(pel_poly, Color(1.0, 0.72, 0.26, 0.96))

	# Player diamond marker (bright cyan-white)
	var p_frac := clampf(ps / TOTAL_DROP, 0.0, 1.0)
	var py := top_y + span * p_frac
	var p_poly := PackedVector2Array([
		Vector2(cx, py - 8.0), Vector2(cx + 8.0, py),
		Vector2(cx, py + 8.0), Vector2(cx - 8.0, py),
	])
	ruler_ctrl.draw_colored_polygon(p_poly, Color(0.38, 0.96, 1.0, 1.0))
	ruler_ctrl.draw_polyline(PackedVector2Array([
		Vector2(cx, py - 8.0), Vector2(cx + 8.0, py),
		Vector2(cx, py + 8.0), Vector2(cx - 8.0, py), Vector2(cx, py - 8.0),
	]), Color(0.03, 0.08, 0.12, 0.95), 1.5)

	var font := ruler_ctrl.get_theme_default_font()
	if font:
		ruler_ctrl.draw_string(font, Vector2(2, top_y + 4), "崖顶", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.86, 0.94, 0.96, 0.88))
		ruler_ctrl.draw_string(font, Vector2(2, top_y + span * 0.32 + 4), "云雾", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.86, 0.94, 0.96, 0.80))
		ruler_ctrl.draw_string(font, Vector2(2, bot_y + 4), "碧潭", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.54, 0.96, 0.88, 0.92))


func _refresh_hud() -> void:
	if hud_label == null:
		return
	var zone_name := "翠林崖口" if ps < 200.0 else ("云雾飞瀑" if ps < 440.0 else "山脚碧潭")
	var rem := maxi(0, int(TOTAL_DROP - ps))
	hud_label.text = "第 4 关 · %s   |   用时 %.1fs   |   距碧潭 %dm   |   碰撞 %d" % [
		zone_name, elapsed_time, rem, hit_count
	]
	if mood_banner_lbl:
		if phase == "intro":
			if not intro_snatched:
				mood_banner_lbl.text = "崖顶微风正好……咦？头顶飞来一只巨大的鹈鹕！"
				mood_banner_lbl.add_theme_color_override("font_color", Color(0.92, 0.98, 0.88))
			else:
				mood_banner_lbl.text = "大鹈鹕把 TA 叼走啦！快跳崖追击！"
				mood_banner_lbl.add_theme_color_override("font_color", Color(1.0, 0.80, 0.44))
		elif not pelican_spit_done:
			if elapsed_time < PELICAN_LAND_TIME - 7.5:
				mood_banner_lbl.text = "TA 在鹈鹕大嘴里朝你挥手求救！"
				mood_banner_lbl.add_theme_color_override("font_color", Color(0.88, 0.97, 1.0))
			else:
				mood_banner_lbl.text = "大鹈鹕快降落山脚碧潭了，快加速俯冲！"
				mood_banner_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.46))
		else:
			var wait_t := elapsed_time - PELICAN_LAND_TIME
			if wait_t < 7.5:
				mood_banner_lbl.text = "鹈鹕把 TA 吐到岸边了！TA 正拍着羽毛等你~"
				mood_banner_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.56))
			elif wait_t < 16.0:
				mood_banner_lbl.text = "TA 开始叉腰跺脚等你啦！快点冲下去！"
				mood_banner_lbl.add_theme_color_override("font_color", Color(1.0, 0.64, 0.40))
			else:
				mood_banner_lbl.text = "TA 气鼓鼓坐在石头上生闷气啦！"
				mood_banner_lbl.add_theme_color_override("font_color", Color(1.0, 0.46, 0.46))


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
	sui.back_to_menu_requested.connect(func():
		SoundFX.stop_waterfall_ambient()
		back_to_select.emit()
	)
	sui.restart_requested.connect(func():
		SoundFX.stop_waterfall_ambient()
		restart_level.emit()
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_open_settings()
			return
		if phase == "intro" and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
			_begin_chase()
			return
		if event.keycode == KEY_M:
			SoundFX.toggle_mute()
			return
	if phase == "chase":
		if event.is_action_pressed("jump"):
			jump_buffer = 0.15
		elif event.is_action_pressed("telepathy"):
			_trigger_telepathy()


func _begin_chase() -> void:
	if phase != "intro":
		return
	phase = "chase"
	intro_snatched = true
	if intro_partner and is_instance_valid(intro_partner):
		intro_partner.visible = false
	if pelican_partner:
		pelican_partner.visible = true
	if pelican_pouch:
		pelican_pouch.rotation_degrees.x = 24.0
	pelican_s = maxf(pelican_s, 22.0)
	ps = 4.0
	px = 0.0
	vx = 0.0
	vs = BASE_SPEED
	lift = 1.65
	v_lift = 3.2
	player_model.set_waving(0)
	player_model.set_falling_pose(true, 0.0, 0.0)
	# Snap camera cleanly into chase position so it never clips through the cliff lip!
	camera.position = _slope_pos(0.0, 0.0, 8.2)
	camera.look_at(_slope_pos(0.0, 16.0, 1.5), Vector3.UP)
	SoundFX.play("jump", -5.0)
	SoundFX.play("wind_whoosh", -6.0)
	_show_toast("纵身跃入云巅飞瀑！A/D 左右闪避 · S 加速俯冲 · Space 踏水跃过横木！", 4.2)


func _trigger_telepathy() -> void:
	if telepathy_cd > 0.0:
		return
	telepathy_cd = 2.8
	telepathy_flash = 2.2
	SoundFX.play("mushroom", -6.0, 1.18)
	# Spawn glowing guiding orbs streaming down toward the Pelican / TA
	var orb_mat := _mat(Color(0.45, 0.96, 1.0), 0.18, Color(0.45, 0.96, 1.0), 1.9, 0.90)
	for i in range(6):
		var o := MeshInstance3D.new()
		var om := SphereMesh.new()
		om.radius = 0.20
		om.height = 0.40
		o.mesh = om
		o.material_override = orb_mat
		var o_s := ps + 2.0 + float(i) * 1.4
		o.position = _slope_pos(px, o_s, lift + 0.6)
		add_child(o)
		telepathy_orbs.append({"node": o, "s": o_s, "x": px, "life": 1.6 - float(i) * 0.12})
	_show_toast("心灵感应脉冲！水雾中的前方障碍与 TA 的方向已点亮！", 2.0)


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	var t := Time.get_ticks_msec() * 0.001

	if toast_timer > 0.0:
		toast_timer -= dt
		if toast_timer <= 0.0 and toast_panel:
			toast_panel.visible = false

	# Animate waterfall foam streaks
	for fs in foam_streaks:
		var fn: Node3D = fs["node"]
		fs["s"] = float(fs["s"]) + float(fs["spd"]) * dt
		if float(fs["s"]) > TOTAL_DROP:
			fs["s"] = fmod(float(fs["s"]), TOTAL_DROP)
		fn.position = _slope_pos(float(fs["x"]), float(fs["s"]), 0.08)

	# Animate pelican wings & trapped TA
	if pelican_wing_l and pelican_wing_r:
		var flap := sin(t * 6.2) * 0.56
		pelican_wing_l.rotation.z = flap
		pelican_wing_r.rotation.z = -flap
	if pelican_partner and pelican_partner.visible:
		pelican_partner.update_anim(false, false, dt)

	if phase == "intro":
		_update_intro(dt, t)
	elif phase == "chase":
		_update_chase(dt, t)
	elif phase == "finale":
		_update_finale(dt, t)

	if ruler_ctrl:
		ruler_ctrl.queue_redraw()
	_refresh_hud()


func _update_intro(dt: float, t: float) -> void:
	intro_timer += dt
	var top_y := TOTAL_DROP * SLOPE_SIN
	var ta_ground := Vector3(-1.15, top_y, -2.3)

	if intro_partner and intro_partner.visible:
		intro_partner.update_anim(false, false, dt)

	if intro_timer < 1.35:
		# Stage 1: Peaceful cliff-top moment; Pelican dives in from the clouds!
		var u := intro_timer / 1.35
		pelican_root.position = Vector3(
			lerpf(-6.5, -2.2, u),
			top_y + lerpf(11.5, 4.2, pow(u, 0.8)),
			lerpf(-10.5, -5.2, u)
		)
		pelican_root.rotation_degrees = Vector3(lerpf(36.0, 26.0, u), lerpf(16.0, 8.0, u), lerpf(14.0, 4.0, u))
		pelican_pouch.rotation_degrees.x = lerpf(0.0, 18.0, u)
		player_root.position = Vector3(1.15, top_y, -2.6)
		player_root.rotation_degrees = Vector3(0.0, -24.0, 0.0)
		player_model.set_waving(-1)
		player_model.update_anim(false, false, dt)
		# Cinematic 3/4 side angle clearly showing player, TA on the grass, and Pelican diving in profile!
		var cam_p := Vector3(5.6, top_y + 3.1, -6.2)
		camera.look_at_from_position(cam_p, Vector3(-0.3, top_y + 1.25, -2.3), Vector3.UP)
	elif intro_timer < 2.55:
		# Stage 2: Pelican swoops right onto the ground, opens giant beak & SNATCHES TA!
		var u := (intro_timer - 1.35) / 1.20
		if u < 0.65:
			var p := u / 0.65
			pelican_root.position = Vector3(
				lerpf(-2.2, ta_ground.x, p),
				top_y + lerpf(4.2, 0.85, p),
				lerpf(-5.2, ta_ground.z - 1.6, p)
			)
			pelican_root.rotation_degrees = Vector3(lerpf(26.0, 8.0, p), 4.0, 0.0)
			pelican_pouch.rotation_degrees.x = lerpf(18.0, 48.0, p)
		else:
			if not intro_snatched:
				intro_snatched = true
				if intro_partner:
					intro_partner.visible = false
				pelican_partner.visible = true
				SoundFX.play("pelican_call", -3.5, 0.94)
				GameJuice.add_trauma(0.34)
				GameJuice.spawn_splash(self, ta_ground + Vector3(0.0, 0.8, 0.0), Color(1.0, 0.96, 0.86), 16, 0.95, false)
				_show_toast("哇啊！！大鹈鹕一口把 TA 叼进大嘴里啦！TA 正在拼命朝你挥手求救！", 3.2)
			var p := (u - 0.65) / 0.35
			pelican_root.position = Vector3(
				lerpf(ta_ground.x, -0.4, p),
				top_y + lerpf(0.85, 3.2, p),
				lerpf(ta_ground.z - 1.6, 2.2, p)
			)
			pelican_root.rotation_degrees = Vector3(lerpf(8.0, -10.0, p), 0.0, sin(p * PI) * -8.0)
			pelican_pouch.rotation_degrees.x = lerpf(48.0, 24.0, p)

		player_model.set_waving(0)
		player_root.rotation_degrees = Vector3(0.0, lerpf(-24.0, 12.0, u), 0.0)
		player_model.update_anim(false, intro_snatched, dt)
		var cam_p := Vector3(lerpf(5.6, 1.8, u), top_y + lerpf(3.1, 4.0, u), lerpf(-6.2, -7.6, u))
		camera.look_at_from_position(cam_p, pelican_root.position.lerp(ta_ground + Vector3(0, 1.0, 0), 0.45), Vector3.UP)
	elif intro_timer < 3.85:
		# Stage 3: Pelican carries waving TA over the waterfall edge; player sprints to cliff lip!
		var u := (intro_timer - 2.55) / 1.30
		pelican_s = lerpf(2.0, 14.0, u)
		pelican_root.position = _slope_pos(sin(t * 2.0) * 1.4, pelican_s, 4.4)
		pelican_root.rotation_degrees = Vector3(54.0, 0.0, -sin(t * 2.0) * 10.0)
		player_root.position = Vector3(lerpf(1.15, 0.0, u), top_y, lerpf(-2.6, -0.4, u))
		player_root.rotation_degrees = Vector3(0.0, 0.0, 0.0)
		player_model.update_anim(true, false, dt)
		var cam_p := Vector3(0.0, top_y + 4.4, lerpf(-7.8, -5.8, u))
		camera.look_at_from_position(cam_p, pelican_root.position.lerp(player_root.position, 0.55), Vector3.UP)
	elif intro_timer < 4.95:
		# Stage 4: Player leaps boldly off the cliff into the rushing waterfall!
		var u := (intro_timer - 3.85) / 1.10
		pelican_s = lerpf(14.0, 24.0, u)
		pelican_root.position = _slope_pos(sin(t * 1.8) * 1.8, pelican_s, 4.4)
		pelican_root.rotation_degrees = Vector3(60.0, 0.0, 0.0)
		var jump_arc := sin(u * PI) * 2.5
		player_root.position = Vector3(0.0, top_y + jump_arc - u * u * 4.5, lerpf(-0.4, 2.8, u))
		player_model.update_anim(false, true, dt)
		var cam_p := Vector3(0.0, top_y + 4.4 - u * 1.6, lerpf(-5.8, -2.5, u))
		camera.look_at_from_position(cam_p, pelican_root.position.lerp(player_root.position, 0.6), Vector3.UP)
	else:
		_begin_chase()
		return

	GameJuice.apply_camera_shake(camera)


func _update_chase(dt: float, t: float) -> void:
	elapsed_time += dt
	if jump_cd > 0.0:
		jump_cd = maxf(0.0, jump_cd - dt)
	if jump_buffer > 0.0:
		jump_buffer = maxf(0.0, jump_buffer - dt)
	if invuln_timer > 0.0:
		invuln_timer = maxf(0.0, invuln_timer - dt)
		player_model.visible = (int(invuln_timer * 24.0) % 2 == 0)
	else:
		player_model.visible = true
	if boost_timer > 0.0:
		boost_timer = maxf(0.0, boost_timer - dt)
	if telepathy_cd > 0.0:
		telepathy_cd = maxf(0.0, telepathy_cd - dt)
	if telepathy_flash > 0.0:
		telepathy_flash = maxf(0.0, telepathy_flash - dt)

	# 1. Input: lateral dodge (camera looks toward +Z, so screen-right is -X, screen-left is +X!)
	var ix := -Input.get_axis("move_left", "move_right")
	var dive_in := Input.get_axis("move_up", "move_down") # +1 = S/Down dive, -1 = W/Up brake

	var target_vx := ix * 9.6
	var lat_accel := 38.0 if absf(ix) > 0.05 else 26.0
	if signf(ix) != 0.0 and signf(vx) != 0.0 and signf(ix) != signf(vx):
		lat_accel *= 1.55
	vx = move_toward(vx, target_vx, lat_accel * dt)
	px = clampf(px + vx * dt, -HALF_W + 0.45, HALF_W - 0.45)

	var target_vs := BASE_SPEED
	if dive_in > 0.1:
		target_vs = lerpf(BASE_SPEED, DIVE_SPEED, dive_in)
	elif dive_in < -0.1:
		target_vs = lerpf(BASE_SPEED, BRAKE_SPEED, -dive_in)
	if boost_timer > 0.0:
		target_vs += 5.4
	var vs_rate := 11.5 if target_vs > vs else 10.5
	vs = move_toward(vs, target_vs, vs_rate * dt)
	ps += vs * dt

	# 2. Water-skip jump with input buffer & asymmetric gravity
	if jump_buffer > 0.0 and jump_cd <= 0.0 and lift <= 0.52:
		jump_buffer = 0.0
		jump_cd = 0.85
		v_lift = 10.6
		SoundFX.play("jump", -5.5)
		GameJuice.spawn_splash(self, _slope_pos(px, ps, 0.2), Color(0.72, 0.96, 1.0), 10, 0.75, false)

	var grav := 23.0 if v_lift > 0.0 else 38.0
	v_lift -= grav * dt
	lift += v_lift * dt
	if lift < 0.45:
		lift = 0.45
		v_lift = 0.0

	# 3. Position & animate player belly-down prone sliding head-first along the 65-deg waterfall slope!
	player_root.position = _slope_pos(px, ps, lift)
	player_root.rotation_degrees = Vector3(148.0, 0.0, 0.0)
	player_model.set_falling_pose(true, dive_in, clampf(vx / 9.0, -1.0, 1.0))
	player_model.update_anim(false, lift > 0.75, dt)

	# 4. Dynamic Sky & Lighting transition across the 3 zones (forest cliff -> sunlit valley!)
	var prog := clampf(ps / TOTAL_DROP, 0.0, 1.0)
	sky_mat.sky_top_color = Color(0.11, 0.28, 0.42).lerp(Color(0.20, 0.56, 0.88), prog)
	sky_mat.sky_horizon_color = Color(0.45, 0.72, 0.78).lerp(Color(0.78, 0.92, 0.98), prog)
	sun_light.light_energy = lerpf(1.05, 1.38, prog)
	world_env.environment.fog_density = lerpf(0.0055, 0.0022, prog)
	SoundFX.set_waterfall_intensity(clampf((vs - 6.0) / 14.0, 0.15, 1.0))

	# 5. Update Giant Pelican flight & spit-out at shore!
	_update_pelican_chase(dt, t)

	# 6. Update Obstacles, Boost Rings, Spray Drops & Telepathy Orbs
	_update_obstacles_and_rings(dt, t)
	_update_spray_and_orbs(dt)

	# 7. Dynamic Chase Camera (frames player in lower third, Pelican & obstacles clearly ahead!)
	var target_fov := 58.0 + clampf((vs - BASE_SPEED) * 1.45, -5.0, 15.0)
	camera.fov = lerpf(camera.fov, target_fov, minf(1.0, dt * 6.0))
	var cam_p := _slope_pos(px * 0.58, maxf(0.0, ps - 7.8), lift + 6.4)
	var look_p := _slope_pos(px * 0.78, minf(TOTAL_DROP, ps + 13.5), 1.4)
	camera.position = camera.position.lerp(cam_p, minf(1.0, dt * 9.5))
	camera.look_at(look_p, Vector3.UP)
	GameJuice.apply_camera_shake(camera, 0.28, 0.20)

	# 8. Check Splashdown at Mountain Foot Lagoon!
	if ps >= TOTAL_DROP:
		_enter_finale()


func _update_pelican_chase(dt: float, t: float) -> void:
	if not pelican_spit_done:
		var target_pel_s := lerpf(24.0, TOTAL_DROP, clampf(elapsed_time / PELICAN_LAND_TIME, 0.0, 1.0))
		pelican_s = move_toward(pelican_s, target_pel_s, 28.0 * dt)
		if pelican_s < TOTAL_DROP - 2.0:
			var sway_x := sin(t * 1.35) * 3.1
			pelican_root.position = _slope_pos(sway_x, pelican_s, 4.4 + sin(t * 2.5) * 0.65)
			pelican_root.rotation_degrees = Vector3(62.0, sin(t * 1.35) * 16.0, -cos(t * 1.35) * 12.0)
		else:
			# Pelican arrives at beach, opens beak & spits TA out!
			pelican_spit_done = true
			pelican_landed = true
			pelican_partner.visible = false
			shore_partner.visible = true
			shore_partner.position = shore_partner_pos
			pelican_pouch.rotation_degrees.x = 46.0
			SoundFX.play("pelican_call", -4.0, 1.08)
			GameJuice.spawn_splash(self, shore_partner_pos + Vector3(0, 0.5, 0), Color(1.0, 0.95, 0.82), 14, 0.9, false)
			_show_toast("大鹈鹕降落在岸边，「噗」地把 TA 吐了出来！快冲下去汇合！", 3.5)
	else:
		# Pelican flaps off triumphantly into the valley sky
		pelican_flyaway_t += dt
		var base_z := TOTAL_DROP * SLOPE_COS
		pelican_root.position = Vector3(
			pelican_flyaway_t * 6.5,
			2.6 + pelican_flyaway_t * 4.2,
			base_z + 18.0 + pelican_flyaway_t * 5.5
		)
		pelican_root.rotation_degrees = Vector3(-18.0, 42.0, -14.0)
		pelican_pouch.rotation_degrees.x = move_toward(pelican_pouch.rotation_degrees.x, 0.0, dt * 60.0)
		if shore_partner and shore_partner.visible:
			shore_partner.update_anim(false, false, dt)


func _update_obstacles_and_rings(dt: float, t: float) -> void:
	# Boost Rings
	for br in boost_rings:
		if br["taken"]:
			continue
		var bn: Node3D = br["node"]
		bn.rotation.z += dt * 2.4
		var ds := absf(float(br["s"]) - ps)
		var dx := absf(float(br["x"]) - px)
		if ds < 1.9 and dx < 1.65:
			br["taken"] = true
			rings_collected += 1
			boost_timer = 1.85
			vs = maxf(vs + 4.5, DIVE_SPEED + 2.5)
			SoundFX.play("water_ring", -4.5)
			GameJuice.spawn_splash(self, bn.position, Color(0.45, 0.96, 1.0), 16, 1.15, true)
			bn.visible = false
			GameUI.pulse_hud(hud_label)

	# Obstacles
	for ob in obstacles:
		if float(ob["hit_cd"]) > 0.0:
			ob["hit_cd"] = maxf(0.0, float(ob["hit_cd"]) - dt)
		var otype: String = ob["type"]
		var os: float = float(ob["s"])

		# Telepathy highlight pulse for upcoming obstacles
		var hl: MeshInstance3D = ob["hl"]
		if hl:
			hl.visible = (telepathy_flash > 0.0 and os > ps - 2.0 and os < ps + 92.0)

		if otype == "whirlpool":
			var sp: Node3D = ob["spin"]
			sp.rotation.z += dt * 4.8
		elif otype == "bird":
			# Start crossing when player gets within 55m
			if os - ps < 58.0 and os - ps > -15.0:
				if not bool(ob["warned"]):
					ob["warned"] = true
					SoundFX.play("warn", -12.0, 1.25)
				var bx: float = float(ob["x"]) + float(ob["dir"]) * float(ob["spd"]) * dt
				if bx > HALF_W + 1.8:
					ob["dir"] = -1.0
				elif bx < -HALF_W - 1.8:
					ob["dir"] = 1.0
				ob["x"] = bx
				var bn: Node3D = ob["node"]
				bn.position = _slope_pos(bx, os, 1.05 + sin(t * 7.0) * 0.25)
				var flap := sin(t * 14.0) * 0.65
				(ob["wl"] as Node3D).rotation.x = flap
				(ob["wr"] as Node3D).rotation.x = -flap

		# Collision check (never kills — only slows down + comical spin + 0.75s invuln!)
		if invuln_timer <= 0.0 and float(ob["hit_cd"]) <= 0.0:
			var ds := absf(os - ps)
			var dx := absf(float(ob["x"]) - px)
			if ds < float(ob["half_s"]) + 0.65 and dx < float(ob["half_w"]) + 0.45:
				# Jumpable obstacles (logs & whirlpools) cleared cleanly when hopping!
				if bool(ob["jumpable"]) and lift >= 1.15:
					continue
				ob["hit_cd"] = 1.2
				invuln_timer = 0.75
				boost_timer = 0.0
				hit_count += 1
				var push_dir := 1.0 if px >= float(ob["x"]) else -1.0
				vx = push_dir * 7.8
				if otype == "whirlpool":
					vs = maxf(3.8, vs * 0.48)
					v_lift = 6.2
				else:
					vs = 3.0
				player_model.trigger_stun(0.55)
				SoundFX.play("waterfall_hit", -4.5)
				GameJuice.hitstop(0.052, 0.08)
				GameJuice.add_trauma(0.46)
				GameJuice.spawn_splash(self, player_root.position, Color(0.82, 0.96, 1.0), 16, 1.05, true)


func _update_spray_and_orbs(dt: float) -> void:
	for sd in spray_drops:
		var dn: Node3D = sd["node"]
		sd["os"] = float(sd["os"]) - (float(sd["spd"]) + vs * 0.45) * dt
		if float(sd["os"]) < -12.0:
			sd["os"] = randf_range(16.0, 28.0)
			sd["ox"] = randf_range(-6.5, 6.5)
		dn.position = _slope_pos(float(sd["ox"]), clampf(ps + float(sd["os"]), 0.0, TOTAL_DROP), float(sd["ol"]))

	for i in range(telepathy_orbs.size() - 1, -1, -1):
		var od: Dictionary = telepathy_orbs[i]
		od["life"] = float(od["life"]) - dt
		var onode: Node3D = od["node"]
		if float(od["life"]) <= 0.0 or not is_instance_valid(onode):
			if is_instance_valid(onode):
				onode.queue_free()
			telepathy_orbs.remove_at(i)
			continue
		od["s"] = minf(TOTAL_DROP, float(od["s"]) + 42.0 * dt)
		var target_x := 0.0 if pelican_spit_done else pelican_root.position.x
		od["x"] = lerpf(float(od["x"]), target_x, minf(1.0, dt * 3.5))
		onode.position = _slope_pos(float(od["x"]), float(od["s"]), 2.2)


func _enter_finale() -> void:
	phase = "finale"
	finish_time = elapsed_time
	finale_timer = 0.0
	finale_stage_shown = 0
	invuln_timer = 0.0
	player_model.visible = true
	player_model.set_falling_pose(false)
	SoundFX.stop_waterfall_ambient()
	SoundFX.play("big_splash", -3.0)
	GameJuice.add_trauma(0.58)

	# Ensure pelican has spit TA out even on ultra-fast Tier 1 runs!
	if not pelican_spit_done:
		pelican_spit_done = true
		pelican_landed = true
		pelican_partner.visible = false
		shore_partner.visible = true
		shore_partner.position = shore_partner_pos
		pelican_pouch.rotation_degrees.x = 46.0
		SoundFX.play("pelican_call", -5.0, 1.05)

	var base_z := TOTAL_DROP * SLOPE_COS
	player_root.position = Vector3(px * 0.35, 0.15, base_z + 3.0)
	player_root.rotation = Vector3.ZERO
	GameJuice.spawn_splash(self, player_root.position + Vector3(0, 0.3, 0), Color(0.62, 0.96, 1.0), 28, 1.55, true)

	# Determine 4-Tier Partner Emotion Rating (faster pelican + collision impact so hitting lots of rocks lowers tier!)
	var score_time := finish_time + float(hit_count) * 1.35
	if finish_time <= 40.5 and hit_count <= 2:
		finale_tier = 1
		finale_mood_name = "超开心 · 星星眼"
		finale_mood_quote = "哇！你几乎和大鹈鹕同时落地，像超人一样飞下来接住我，太帅啦！"
	elif score_time <= 48.5:
		finale_tier = 2
		finale_mood_name = "小嘟嘴 · 嘴硬心软"
		finale_mood_quote = "哼，差点就被大鹈鹕当点心了，慢了半拍哦……不过看你浑身湿漉漉赶来，原谅你啦~"
	elif score_time <= 57.5:
		finale_tier = 3
		finale_mood_name = "叉腰生气 · 递毛巾原谅"
		finale_mood_quote = "我都从鹈鹕嘴里爬出来好久了！你怎么一路撞石头变成落汤鸡才到！快拿毛巾擦擦啦~"
	else:
		finale_tier = 4
		finale_mood_name = "气鼓鼓大爆发 · 搞笑治愈"
		finale_mood_quote = "气死我啦本来不想理你的……噗嗤！你顶着一头水草赔笑的样子也太滑稽了，算啦原谅你！"

	# Place TA according to tier (Tier 4 sits sulking on shore boulder!)
	if finale_tier == 4:
		shore_partner.position = shore_boulder_pos + Vector3(0.0, 0.62, 0.0)
		shore_partner.rotation_degrees = Vector3(0.0, 55.0, 0.0)
		shore_partner.set_sitting(true)
		shore_partner.trigger_angry()
	elif finale_tier == 3:
		shore_partner.position = shore_partner_pos
		shore_partner.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		shore_partner.trigger_angry()
	elif finale_tier == 2:
		shore_partner.position = shore_partner_pos
		shore_partner.rotation_degrees = Vector3(0.0, 155.0, 0.0)
	else:
		shore_partner.position = shore_partner_pos
		shore_partner.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		shore_partner.trigger_celebrate()

	_spawn_emotion_badge(finale_tier)
	_show_toast("扑通——！落入山脚碧潭，快冲上岸找 TA！", 2.0)


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


func _make_sparkle_star(col: Color, r: float) -> Node3D:
	var n := Node3D.new()
	var sm := _mat(col, 0.18, col, 1.55)
	for axis in [Vector3(r * 2.0, r * 0.46, r * 0.46), Vector3(r * 0.46, r * 2.0, r * 0.46), Vector3(r * 0.46, r * 0.46, r * 2.0)]:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = axis
		b.mesh = bm
		b.material_override = sm
		n.add_child(b)
	return n


func _spawn_emotion_badge(tier: int) -> void:
	if emotion_badge and is_instance_valid(emotion_badge):
		emotion_badge.queue_free()
	emotion_badge = Node3D.new()
	emotion_badge.position = shore_partner.position + Vector3(0.0, 2.38, 0.0)
	add_child(emotion_badge)

	if tier == 1:
		# Tier 1 (超开心·星星眼): Plump glowing 3D Rose-Pink Heart + 2 sparkling golden stars!
		var heart := _make_3d_heart_badge(Color(1.0, 0.34, 0.56), 1.35)
		emotion_badge.add_child(heart)
		var star1 := _make_sparkle_star(Color(1.0, 0.90, 0.36), 0.13)
		star1.position = Vector3(0.42, 0.24, 0.06)
		emotion_badge.add_child(star1)
		var star2 := _make_sparkle_star(Color(1.0, 0.94, 0.56), 0.09)
		star2.position = Vector3(-0.40, -0.14, -0.05)
		emotion_badge.add_child(star2)
	elif tier == 2:
		# Tier 2 (小嘟嘴·嘴硬心软): Cute puffy little grumpy raincloud + glossy cyan teardrop!
		var cloud_m := _mat(Color(0.76, 0.80, 0.90), 0.72, Color(0.55, 0.62, 0.78), 0.32)
		for puff in [
			[Vector3(0.0, 0.10, 0.0), Vector3(0.42, 0.32, 0.30)],
			[Vector3(-0.24, 0.02, 0.02), Vector3(0.32, 0.26, 0.26)],
			[Vector3(0.24, 0.02, -0.02), Vector3(0.32, 0.26, 0.26)],
			[Vector3(-0.10, 0.18, 0.0), Vector3(0.28, 0.24, 0.24)],
			[Vector3(0.12, 0.16, 0.0), Vector3(0.26, 0.22, 0.24)],
		]:
			var sp := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.5
			sm.height = 1.0
			sp.mesh = sm
			sp.material_override = cloud_m
			sp.position = puff[0]
			sp.scale = puff[1]
			emotion_badge.add_child(sp)
		# Glossy cyan sweat/tear drop hanging below the cute cloud
		var drop_m := _mat(Color(0.38, 0.88, 1.0), 0.14, Color(0.32, 0.82, 1.0), 1.05)
		var drop_b := MeshInstance3D.new()
		var dbm := SphereMesh.new()
		dbm.radius = 0.10
		dbm.height = 0.20
		drop_b.mesh = dbm
		drop_b.material_override = drop_m
		drop_b.position = Vector3(0.0, -0.26, 0.0)
		emotion_badge.add_child(drop_b)
		var drop_t := MeshInstance3D.new()
		var dtm := CylinderMesh.new()
		dtm.top_radius = 0.005
		dtm.bottom_radius = 0.095
		dtm.height = 0.18
		drop_t.mesh = dtm
		drop_t.material_override = drop_m
		drop_t.position = Vector3(0.0, -0.14, 0.0)
		emotion_badge.add_child(drop_t)
	elif tier == 3:
		# Tier 3 (叉腰生气): Classic 3D Anime Anger Vein Symbol (💢 — 4 crisp outward L-brackets!)
		var am := _mat(Color(1.0, 0.42, 0.16), 0.24, Color(1.0, 0.36, 0.12), 1.55)
		for quad in [
			[1.0, 1.0],
			[-1.0, 1.0],
			[1.0, -1.0],
			[-1.0, -1.0],
		]:
			var sx: float = float(quad[0])
			var sy: float = float(quad[1])
			# Horizontal arm of each outward corner bracket
			var h_bar := MeshInstance3D.new()
			var hbm := BoxMesh.new()
			hbm.size = Vector3(0.22, 0.09, 0.10)
			h_bar.mesh = hbm
			h_bar.material_override = am
			h_bar.position = Vector3(sx * 0.18, sy * 0.10, 0.0)
			emotion_badge.add_child(h_bar)
			# Vertical arm of each outward corner bracket
			var v_bar := MeshInstance3D.new()
			var vbm := BoxMesh.new()
			vbm.size = Vector3(0.09, 0.22, 0.10)
			v_bar.mesh = vbm
			v_bar.material_override = am
			v_bar.position = Vector3(sx * 0.10, sy * 0.18, 0.0)
			emotion_badge.add_child(v_bar)
	else:
		# Tier 4 (气鼓鼓大爆发): Blazing 3-Layer 3D Cartoon Anger Flame (🔥 crimson outer -> orange mid -> yellow core!)
		var red_m := _mat(Color(0.96, 0.16, 0.12), 0.30, Color(0.95, 0.16, 0.10), 1.45)
		var org_m := _mat(Color(1.0, 0.48, 0.10), 0.25, Color(1.0, 0.46, 0.08), 1.55)
		var yel_m := _mat(Color(1.0, 0.88, 0.26), 0.20, Color(1.0, 0.84, 0.22), 1.75)
		# Smooth rounded crimson flame base + curving outer tongues
		var base_b := MeshInstance3D.new()
		var bsm := SphereMesh.new()
		bsm.radius = 0.28
		bsm.height = 0.50
		base_b.mesh = bsm
		base_b.material_override = red_m
		base_b.position = Vector3(0.0, -0.08, 0.0)
		emotion_badge.add_child(base_b)
		for fcfg in [
			[Vector3(0.0, 0.24, 0.0), 0.23, 0.64, red_m, Vector3(0, 0, -6)],
			[Vector3(-0.14, 0.12, 0.03), 0.15, 0.44, red_m, Vector3(0, 0, 22)],
			[Vector3(0.15, 0.14, -0.02), 0.14, 0.46, red_m, Vector3(0, 0, -24)],
			[Vector3(0.0, 0.10, 0.10), 0.17, 0.44, org_m, Vector3(4, 0, 6)],
			[Vector3(-0.08, 0.02, 0.11), 0.11, 0.30, org_m, Vector3(4, 0, 18)],
			[Vector3(0.0, -0.04, 0.15), 0.11, 0.28, yel_m, Vector3(4, 0, 0)],
		]:
			var fl := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.008
			cm.bottom_radius = float(fcfg[1])
			cm.height = float(fcfg[2])
			cm.radial_segments = 12
			fl.mesh = cm
			fl.material_override = fcfg[3]
			fl.position = fcfg[0]
			fl.rotation_degrees = fcfg[4]
			emotion_badge.add_child(fl)
		var core_s := MeshInstance3D.new()
		var csm := SphereMesh.new()
		csm.radius = 0.12
		csm.height = 0.22
		core_s.mesh = csm
		core_s.material_override = yel_m
		core_s.position = Vector3(0.0, -0.12, 0.15)
		emotion_badge.add_child(core_s)

	# Snappy spring pop-in animation
	if is_inside_tree():
		emotion_badge.scale = Vector3.ONE * 0.1
		var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(emotion_badge, "scale", Vector3.ONE, 0.28)


func _update_finale(dt: float, t: float) -> void:
	finale_timer += dt
	# Keep pelican flying away into the sunset
	_update_pelican_chase(dt, t)

	var meet_target := shore_partner.position + Vector3(-1.35, 0.0, -0.55)
	if finale_tier == 4:
		meet_target = shore_boulder_pos + Vector3(-1.45, 0.0, -0.65)

	# Player runs from lagoon onto shore to meet TA + drips water!
	var dist := player_root.position.distance_to(meet_target)
	if dist > 0.22:
		var dir := (meet_target - player_root.position).normalized()
		player_root.position += dir * minf(dist, 9.2 * dt)
		player_root.position.y = lerpf(player_root.position.y, 0.35, minf(1.0, dt * 4.5))
		player_root.rotation.y = atan2(dir.x, dir.z)
		player_model.update_anim(true, false, dt)
	else:
		var look_dir := (shore_partner.position - player_root.position).normalized()
		player_root.rotation.y = lerp_angle(player_root.rotation.y, atan2(look_dir.x, look_dir.z), minf(1.0, dt * 8.0))
		if finale_stage_shown == 0:
			finale_stage_shown = 1
			if finale_tier >= 3:
				SoundFX.play("angry", -5.0)
			else:
				SoundFX.play("keepsake", -5.0)
			_show_toast("【%s】%s" % [finale_mood_name, finale_mood_quote], 4.2)
		if finale_timer > 2.4 and finale_stage_shown == 1:
			finale_stage_shown = 2
			shore_partner.set_sitting(false)
			shore_partner.position.y = 0.35
			shore_partner.rotation.y = atan2(-look_dir.x, -look_dir.z)
			shore_partner.trigger_celebrate()
			player_model.trigger_celebrate()
			# When TA forgives you, morph angry/cloud badge into a blooming 3D Heart!
			if finale_tier >= 2:
				_spawn_emotion_badge(1)
			GameJuice.spawn_splash(self, (player_root.position + shore_partner.position) * 0.5 + Vector3(0, 1.0, 0), Color(1.0, 0.72, 0.84), 18, 1.0, false)
		player_model.update_anim(false, false, dt)

	# Brief dripping water droplets off wet player
	drip_timer += dt
	if drip_timer > 0.16 and finale_timer < 3.2:
		drip_timer = 0.0
		GameJuice.spawn_splash(self, player_root.position + Vector3(0, 0.55, 0), Color(0.68, 0.94, 1.0), 3, 0.35, false)

	shore_partner.update_anim(false, false, dt)
	if emotion_badge and is_instance_valid(emotion_badge):
		emotion_badge.position = shore_partner.position + Vector3(0.0, 2.38 + sin(t * 5.2) * 0.12, 0.0)
		emotion_badge.rotation.y += dt * 1.9
		if finale_tier == 4 and finale_stage_shown < 2:
			# Lively flickering blaze pulse for Tier 4 anger flame!
			var flk := 1.0 + 0.10 * sin(t * 18.0)
			emotion_badge.scale = Vector3(1.0 / sqrt(flk), flk, 1.0 / sqrt(flk))

	# Warm reunion camera framing both characters on the sunlit beach
	var mid := (player_root.position + shore_partner.position) * 0.5
	var cam_target := mid + Vector3(0.0, 2.8, -6.8)
	camera.fov = lerpf(camera.fov, 46.0, minf(1.0, dt * 4.0))
	camera.position = camera.position.lerp(cam_target, minf(1.0, dt * 4.0))
	camera.look_at(mid + Vector3(0.0, 1.05, 0.0), Vector3.UP)
	GameJuice.apply_camera_shake(camera)

	if finale_timer >= 4.4 and not cleared:
		cleared = true
		phase = "done"
		SoundFX.play("victory")
		level_cleared.emit({
			"level": 4,
			"role": role,
			"time": finish_time,
			"hits": hit_count,
			"rings": rings_collected,
			"mood_tier": finale_tier,
			"mood_name": finale_mood_name,
			"mood_quote": finale_mood_quote,
		})
