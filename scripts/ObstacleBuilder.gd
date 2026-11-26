extends RefCounted
class_name ObstacleBuilder

## Scene-specific 3D Environmental Obstacles & Unlock Animations:
## Replaces flat cuboid walls with:
##  - Level 1: Broken Cedar Footbridge (sunken planks) + Glowing Blossom Vine Barrier
##  - Level 2 Outer: Rustic Split-Picket Wooden Fence Doors + Thorny Briar Vines
##  - Level 2 Inner: Raised Timber Drawbridge Span + Violet Rune-Vine Tethers
##  - Level 3 East: Cedar Split-Rail Pasture Fence + Lantern Double Timber Ranch Gate
##  - Level 3 West: Stone & Wrought-Iron Park Sanctuary Archway + Crimson Maple Vines


static func _std_mat(col: Color, rough: float = 0.82, metal: float = 0.0, emit_col: Color = Color.BLACK, emit_e: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = 0.42 if metal > 0.3 else 0.15
	if emit_e > 0.0:
		m.emission_enabled = true
		m.emission = emit_col
		m.emission_energy_multiplier = emit_e
	return m


static func _swept_vine(parent: Node3D, points: Array[Vector3], r_start: float, r_end: float, mat: Material, sides: int = 8) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cnt := points.size()
	var tangs: Array[Vector3] = []
	for i in range(cnt):
		if i == 0:
			tangs.append((points[1] - points[0]).normalized())
		elif i == cnt - 1:
			tangs.append((points[i] - points[i - 1]).normalized())
		else:
			tangs.append((points[i + 1] - points[i - 1]).normalized())

	var ref_n := Vector3.FORWARD if absf(tangs[0].dot(Vector3.UP)) > 0.9 else Vector3.UP
	var prev_u := tangs[0].cross(ref_n).normalized()
	var prev_v := prev_u.cross(tangs[0]).normalized()
	var rings: Array[Array] = []

	for i in range(cnt):
		var t := tangs[i]
		var u := prev_u - t * prev_u.dot(t)
		if u.length() < 0.001:
			u = prev_v.cross(t)
		u = u.normalized()
		var v := t.cross(u).normalized()
		prev_u = u
		prev_v = v
		var frac := float(i) / float(maxi(1, cnt - 1))
		var rad := lerpf(r_start, r_end, frac) * (0.85 + 0.25 * sin(frac * PI))
		var ring: Array[Vector3] = []
		for s in range(sides):
			var a := float(s) / float(sides) * TAU
			ring.append(points[i] + (u * cos(a) + v * sin(a)) * rad)
		rings.append(ring)

	for i in range(cnt - 1):
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		for s in range(sides):
			var sn := (s + 1) % sides
			st.add_vertex(r0[s]); st.add_vertex(r1[s]); st.add_vertex(r1[sn])
			st.add_vertex(r0[s]); st.add_vertex(r1[sn]); st.add_vertex(r0[sn])

	st.index()
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, pos: Vector3, sz: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, pos: Vector3, rt: float, rb: float, h: float, mat: Material, seg: int = 8, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = rt
	cm.bottom_radius = rb
	cm.height = h
	cm.radial_segments = seg
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func _sphere(parent: Node3D, pos: Vector3, sc: Vector3, mat: Material, seg: int = 10, rings: int = 6) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = seg
	sm.rings = rings
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = sc
	parent.add_child(mi)
	return mi


static func _add_static_box(parent: Node, pos: Vector3, sz: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.position = pos
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = sz
	cs.shape = bx
	cs.position = Vector3(0, sz.y * 0.5, 0)
	sb.add_child(cs)
	parent.add_child(sb)
	return sb


static func _add_post_lantern(parent: Node3D, pos: Vector3, iron_mat: Material, glow_col: Color) -> void:
	var holder := Node3D.new()
	holder.position = pos
	parent.add_child(holder)
	_box(holder, Vector3(0, 0.03, 0), Vector3(0.28, 0.06, 0.28), iron_mat)
	var glass_mat := _std_mat(glow_col.lightened(0.25), 0.18, 0.0, glow_col, 1.85)
	_box(holder, Vector3(0, 0.19, 0), Vector3(0.19, 0.24, 0.19), glass_mat)
	_cyl(holder, Vector3(0, 0.37, 0), 0.02, 0.18, 0.13, iron_mat, 4, Vector3(0, 45, 0))
	var omni := OmniLight3D.new()
	omni.light_color = glow_col
	omni.light_energy = 0.85
	omni.omni_range = 4.2
	omni.position = Vector3(0, 0.22, 0)
	holder.add_child(omni)


# ---------------------------------------------------------------------------
# 1. LEVEL 1: Broken Cedar Footbridge + Living Blossom Vine Archway
# ---------------------------------------------------------------------------
static func build_level1_broken_bridge_vine(parent: Node, bridge_pos: Vector3) -> Dictionary:
	var root := Node3D.new()
	root.position = bridge_pos
	parent.add_child(root)

	var wood_mat := VisualPolish.make_organic_mat(Color(0.68, 0.46, 0.25), 2.2, 0.76, 0.94)
	var dark_wood := VisualPolish.make_organic_mat(Color(0.42, 0.26, 0.14), 2.4, 0.80, 0.96)
	var vine_mat := VisualPolish.make_organic_mat(Color(0.18, 0.54, 0.26), 2.6, 0.65, 0.90)
	var leaf_mat := _std_mat(Color(0.32, 0.78, 0.42), 0.55, 0.0, Color(0.20, 0.62, 0.32), 0.22)
	var bud_pink := _std_mat(Color(1.0, 0.58, 0.78), 0.30, 0.0, Color(1.0, 0.48, 0.72), 1.15)
	var bud_cyan := _std_mat(Color(0.45, 0.98, 0.84), 0.28, 0.0, Color(0.35, 0.92, 0.78), 1.10)

	# 3 Broken/Sunken Middle Planks resting tilted down in the shallow stream!
	var plank_targets := [
		{"x": -0.8, "y": 0.15, "broken_pos": Vector3(-0.82, -0.06, 0.08), "broken_rot": Vector3(8, 5, -24)},
		{"x": 0.0, "y": 0.17, "broken_pos": Vector3(0.04, -0.12, -0.10), "broken_rot": Vector3(-11, -7, 14)},
		{"x": 0.8, "y": 0.15, "broken_pos": Vector3(0.82, -0.05, 0.06), "broken_rot": Vector3(7, -4, 22)},
	]
	var sunken_planks: Array[Dictionary] = []
	for cfg in plank_targets:
		var p_holder := Node3D.new()
		p_holder.position = cfg["broken_pos"]
		p_holder.rotation_degrees = cfg["broken_rot"]
		root.add_child(p_holder)
		_box(p_holder, Vector3.ZERO, Vector3(0.72, 0.09, 3.8), wood_mat)
		sunken_planks.append({
			"node": p_holder,
			"rest_pos": Vector3(cfg["x"], cfg["y"], 0.0),
		})

	# Intertwined Living Vine Barrier & Rustic Warning Cross-Posts on West Bridgehead
	var vine_barrier := Node3D.new()
	vine_barrier.position = Vector3(-1.18, 0.0, 0.0)
	root.add_child(vine_barrier)

	for sz in [-1.55, 1.55]:
		_cyl(vine_barrier, Vector3(0, 0.68, sz), 0.11, 0.14, 1.36, dark_wood, 7, Vector3(sz * 2.5, 0, 4))

	# 3 Organic Curved 3D Vines weaving across the bridge entrance
	for v_idx in range(3):
		var pts: Array[Vector3] = []
		var base_y := 0.42 + float(v_idx) * 0.34
		for k in range(9):
			var u := float(k) / 8.0
			var zz := lerpf(-1.62, 1.62, u)
			var yy := base_y + sin(u * TAU + float(v_idx) * 1.4) * 0.16
			var xx := cos(u * PI * 2.0 + float(v_idx)) * 0.10
			pts.append(Vector3(xx, yy, zz))
		_swept_vine(vine_barrier, pts, 0.068, 0.048, vine_mat, 8)

		# Glowing flower blossoms & leaves along each vine
		for b_u in [0.22, 0.50, 0.78]:
			var bz := lerpf(-1.5, 1.5, b_u) + float(v_idx - 1) * 0.15
			var by := base_y + sin(b_u * TAU + float(v_idx) * 1.4) * 0.16
			_sphere(vine_barrier, Vector3(0.06, by, bz), Vector3(0.16, 0.16, 0.16), bud_pink if (v_idx + int(b_u * 10)) % 2 == 0 else bud_cyan)
			_sphere(vine_barrier, Vector3(-0.04, by + 0.07, bz + 0.10), Vector3(0.08, 0.18, 0.12), leaf_mat)

	var col := _add_static_box(parent, bridge_pos, Vector3(2.2, 2.5, 3.8))
	return {
		"kind": "level1_bridge",
		"root": root,
		"vine_barrier": vine_barrier,
		"planks": sunken_planks,
		"collider": col,
	}


# ---------------------------------------------------------------------------
# 2. LEVEL 2 OUTER: Thorny Briar Vine & Split-Picket Wooden Fence Gate
# ---------------------------------------------------------------------------
static func build_level2_briar_fence_gate(parent: Node, gate_pos: Vector3) -> Dictionary:
	var root := Node3D.new()
	root.position = gate_pos
	parent.add_child(root)

	var bark_mat := VisualPolish.make_organic_mat(Color(0.38, 0.25, 0.15), 2.4, 0.80, 0.96)
	var picket_mat := VisualPolish.make_organic_mat(Color(0.56, 0.38, 0.22), 2.2, 0.76, 0.94)
	var iron_mat := _std_mat(Color(0.18, 0.21, 0.24), 0.42, 0.65)
	var briar_mat := VisualPolish.make_organic_mat(Color(0.16, 0.46, 0.26), 2.8, 0.68, 0.92)
	var glow_bud := _std_mat(Color(0.55, 1.0, 0.78), 0.25, 0.0, Color(0.42, 0.96, 0.72), 1.35)

	# North & South Heavy Log Gateposts + Firefly Lanterns
	for side_v in [-1.0, 1.0]:
		var side: float = float(side_v)
		var pz: float = side * 2.15
		_cyl(root, Vector3(0, 0.95, pz), 0.18, 0.23, 1.90, bark_mat, 8)
		_add_post_lantern(root, Vector3(0, 1.90, pz), iron_mat, Color(0.62, 1.0, 0.68))

	# Two Hinged Rustic Wooden Picket Fence Doors (swing open along X when unlocked!)
	var doors: Array[Node3D] = []
	for side_v in [-1.0, 1.0]:
		var side: float = float(side_v)
		var hinge := Node3D.new()
		hinge.position = Vector3(0, 0, side * 2.05)
		root.add_child(hinge)
		doors.append(hinge)

		var span_dir: float = -side  # Points inward from hinge (+/-2.05) toward center (0.0)
		for rail_y_v in [0.42, 1.08]:
			var rail_y: float = float(rail_y_v)
			_box(hinge, Vector3(0, rail_y, span_dir * 0.98), Vector3(0.09, 0.11, 1.96), bark_mat)
		# Diagonal timber brace
		_box(hinge, Vector3(0.02, 0.75, span_dir * 0.98), Vector3(0.07, 0.09, 2.05), bark_mat, Vector3(span_dir * 19.0, 0, 0))

		# 5 Tapered Rustic Wooden Pickets per door leaf
		for p_i in range(5):
			var zz: float = span_dir * (0.24 + float(p_i) * 0.39)
			var h_var: float = 1.36 + float(p_i % 2) * 0.12
			_box(hinge, Vector3(0.05, h_var * 0.5 + 0.08, zz), Vector3(0.06, h_var, 0.18), picket_mat)
			# Pointed picket tip
			_cyl(hinge, Vector3(0.05, h_var + 0.16, zz), 0.0, 0.11, 0.18, picket_mat, 4, Vector3(0, 45, 0))

	# Intertwined Thorny Briar Vines binding both picket doors shut at the center
	var vine_seal := Node3D.new()
	root.add_child(vine_seal)
	for v_i in range(3):
		var pts: Array[Vector3] = []
		for k in range(8):
			var u := float(k) / 7.0
			var zz := lerpf(-1.65, 1.65, u)
			var yy := 0.45 + float(v_i) * 0.32 + sin(u * PI * 2.0 + float(v_i)) * 0.18
			var xx := 0.10 + cos(u * TAU + float(v_i)) * 0.06
			pts.append(Vector3(xx, yy, zz))
		_swept_vine(vine_seal, pts, 0.065, 0.045, briar_mat, 7)
	for bz in [-0.75, 0.0, 0.75]:
		_sphere(vine_seal, Vector3(0.14, 0.82 + absf(bz) * 0.12, bz), Vector3(0.17, 0.17, 0.17), glow_bud)

	var col := _add_static_box(parent, gate_pos, Vector3(1.2, 2.5, 4.6))
	return {
		"kind": "double_doors",
		"root": root,
		"door_l": doors[0],
		"door_r": doors[1],
		"open_sign": 1.0,
		"vine_seal": vine_seal,
		"collider": col,
	}


# ---------------------------------------------------------------------------
# 3. LEVEL 2 INNER MOAT: Raised Timber Drawbridge + Violet Rune-Vine Chains
# ---------------------------------------------------------------------------
static func build_level2_moat_drawbridge(parent: Node, bridge_pos: Vector3) -> Dictionary:
	var root := Node3D.new()
	root.position = bridge_pos
	parent.add_child(root)

	var wood_mat := VisualPolish.make_organic_mat(Color(0.68, 0.46, 0.25), 2.2, 0.76, 0.94)
	var post_mat := VisualPolish.make_organic_mat(Color(0.42, 0.26, 0.14), 2.4, 0.80, 0.96)
	var iron_mat := _std_mat(Color(0.20, 0.22, 0.28), 0.38, 0.70)
	var rune_vine := _std_mat(Color(0.68, 0.46, 0.96), 0.30, 0.0, Color(0.58, 0.36, 0.92), 1.25)

	# North-side Winch Bollards holding the raised drawbridge leaf
	for sx in [-1.62, 1.62]:
		_cyl(root, Vector3(sx, 0.72, -1.35), 0.14, 0.17, 1.44, post_mat, 8)
		_cyl(root, Vector3(sx, 1.38, -1.35), 0.18, 0.18, 0.10, iron_mat, 8)

	# Hinged Drawbridge Span (hinged on North abutment z = -1.15, tilted up 68 degrees!)
	var leaf_pivot := Node3D.new()
	leaf_pivot.position = Vector3(0.0, 0.14, -1.12)
	leaf_pivot.rotation_degrees = Vector3(-68.0, 0.0, 0.0)
	root.add_child(leaf_pivot)

	# Longitudinal iron-strapped beams + 3 heavy cedar planks
	for bx in [-1.32, 1.32]:
		_box(leaf_pivot, Vector3(bx, -0.02, 1.12), Vector3(0.18, 0.08, 2.32), post_mat)
	var local_zs := [0.37, 1.12, 1.87]
	var local_ys := [0.01, 0.03, 0.01]
	for i in range(3):
		_box(leaf_pivot, Vector3(0.0, local_ys[i], local_zs[i]), Vector3(3.76, 0.09, 0.68), wood_mat)

	# Glowing Violet Rune-Vine Chains tethering the raised span to the bollards
	var vine_tethers := Node3D.new()
	root.add_child(vine_tethers)
	for sx in [-1.48, 1.48]:
		_swept_vine(
			vine_tethers,
			[
				Vector3(sx, 1.32, -1.32),
				Vector3(sx * 0.96, 1.56, -0.82),
				Vector3(sx * 0.92, 1.88, -0.32),
			],
			0.052, 0.042, rune_vine, 7
		)
	_sphere(vine_tethers, Vector3(0, 1.35, -0.58), Vector3(0.28, 0.28, 0.28), rune_vine)

	var col := _add_static_box(parent, bridge_pos, Vector3(3.8, 2.6, 2.2))
	return {
		"kind": "drawbridge",
		"root": root,
		"leaf_pivot": leaf_pivot,
		"vine_seal": vine_tethers,
		"collider": col,
	}


# ---------------------------------------------------------------------------
# 4. LEVEL 3 GATE 1 (East): Cedar Split-Rail Pasture Fence + Double Ranch Gate
# ---------------------------------------------------------------------------
static func build_level3_ranch_fence_gate(parent: Node, gate_pos: Vector3) -> Dictionary:
	var root := Node3D.new()
	root.position = gate_pos
	parent.add_child(root)

	var cedar := VisualPolish.make_organic_mat(Color(0.62, 0.38, 0.20), 2.2, 0.76, 0.94)
	var dark_log := VisualPolish.make_organic_mat(Color(0.38, 0.22, 0.13), 2.4, 0.80, 0.96)
	var stone_mat := VisualPolish.make_organic_mat(Color(0.42, 0.38, 0.40), 2.2, 0.78, 0.98)
	var iron_mat := _std_mat(Color(0.18, 0.18, 0.22), 0.40, 0.72)
	var maple_glow := _std_mat(Color(1.0, 0.56, 0.20), 0.28, 0.0, Color(1.0, 0.46, 0.14), 1.35)

	# Permanent Left & Right Split-Rail Cedar Fences flanking the 4.7m central road!
	for side_v in [-1.0, 1.0]:
		var side: float = float(side_v)
		var x_inner: float = side * 2.38
		var x_mid: float = side * 4.15
		var x_outer: float = side * 5.85
		for px_v in [x_mid, x_outer]:
			var px: float = float(px_v)
			_cyl(root, Vector3(px, 0.65, 0), 0.12, 0.15, 1.30, dark_log, 7)
		for ry_v in [0.42, 0.86, 1.18]:
			var ry: float = float(ry_v)
			_box(root, Vector3(side * 4.12, ry, 0.04), Vector3(3.55, 0.10, 0.08), cedar, Vector3(0, 0, side * 1.2))
		# Decorative canyon rock at outer joint
		_sphere(root, Vector3(x_outer, 0.32, 0.25), Vector3(1.15, 0.78, 0.95), stone_mat, 6, 4)
		# Permanent collider for the flanking fence wing (leaves clean 4.76m road opening!)
		_add_static_box(parent, gate_pos + Vector3(side * 4.20, 0, 0), Vector3(3.65, 2.5, 1.4))

		# Main Stone-Base Cedar Gate Pillar + Warm Autumn Lantern sitting atop overhead beam
		_box(root, Vector3(x_inner, 0.32, 0), Vector3(0.56, 0.64, 0.56), stone_mat)
		_cyl(root, Vector3(x_inner, 1.48, 0), 0.16, 0.19, 1.85, dark_log, 8)
		_add_post_lantern(root, Vector3(x_inner, 2.74, 0), iron_mat, Color(1.0, 0.68, 0.28))

	# Overhead Torii-inspired Rustic Cedar Arch Lintel
	_box(root, Vector3(0, 2.46, 0), Vector3(5.45, 0.18, 0.26), dark_log)
	_box(root, Vector3(0, 2.64, 0), Vector3(5.85, 0.14, 0.36), cedar)

	# Two Hinged Cross-Braced Timber Ranch Gate Leaves (each 2.25m wide)
	var doors: Array[Node3D] = []
	for side_v in [-1.0, 1.0]:
		var side: float = float(side_v)
		var hinge := Node3D.new()
		hinge.position = Vector3(side * 2.26, 0.0, 0.0)
		root.add_child(hinge)
		doors.append(hinge)
		var dir_in: float = -side
		# Outer frame stiles & rails
		_box(hinge, Vector3(dir_in * 0.08, 0.92, 0), Vector3(0.12, 1.48, 0.10), dark_log)
		_box(hinge, Vector3(dir_in * 2.16, 0.92, 0), Vector3(0.12, 1.48, 0.10), dark_log)
		for ry_v in [0.28, 0.92, 1.56]:
			var ry: float = float(ry_v)
			_box(hinge, Vector3(dir_in * 1.12, ry, 0), Vector3(2.16, 0.11, 0.09), cedar)
		# X-brace slats + vertical pickets
		_box(hinge, Vector3(dir_in * 1.12, 0.92, 0.02), Vector3(2.38, 0.09, 0.06), cedar, Vector3(0, 0, dir_in * 29.0))
		for pk_v in [0.56, 1.12, 1.68]:
			var pk: float = float(pk_v)
			_box(hinge, Vector3(dir_in * pk, 0.92, -0.02), Vector3(0.10, 1.32, 0.05), cedar)

	# Glowing Autumn Maple-Vine Wreath Latch at center (botanical vine ring + maple leaf clusters!)
	var seal := Node3D.new()
	seal.position = Vector3(0, 0.96, 0.08)
	root.add_child(seal)
	var wreath := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.25
	tm.outer_radius = 0.33
	wreath.mesh = tm
	wreath.material_override = dark_log
	wreath.rotation_degrees = Vector3(90, 0, 0)
	seal.add_child(wreath)
	var leaf_red := _std_mat(Color(0.92, 0.30, 0.16), 0.48, 0.0, Color(0.85, 0.24, 0.10), 0.45)
	for li in range(8):
		var a := float(li) / 8.0 * TAU
		_sphere(seal, Vector3(cos(a) * 0.29, sin(a) * 0.29, 0.04), Vector3(0.16, 0.12, 0.10), maple_glow if li % 2 == 0 else leaf_red, 8, 6)

	var col := _add_static_box(parent, gate_pos, Vector3(4.8, 2.5, 1.5))
	return {
		"kind": "double_doors_z",
		"root": root,
		"door_l": doors[0],
		"door_r": doors[1],
		"vine_seal": seal,
		"collider": col,
	}


# ---------------------------------------------------------------------------
# 5. LEVEL 3 GATE 2 (West): Stone & Wrought-Iron Park Archway + Crimson Vines
# ---------------------------------------------------------------------------
static func build_level3_iron_arch_gate(parent: Node, gate_pos: Vector3) -> Dictionary:
	var root := Node3D.new()
	root.position = gate_pos
	parent.add_child(root)

	var stone_mat := VisualPolish.make_organic_mat(Color(0.48, 0.44, 0.46), 2.2, 0.76, 0.96)
	var iron_mat := _std_mat(Color(0.15, 0.16, 0.20), 0.34, 0.78)
	var brass_mat := _std_mat(Color(0.92, 0.74, 0.34), 0.26, 0.82, Color(0.88, 0.66, 0.24), 0.28)
	var crimson_vine := _std_mat(Color(0.92, 0.26, 0.34), 0.35, 0.0, Color(0.88, 0.20, 0.28), 1.15)

	# Flanking Low Stone Plinth + Wrought-Iron Spear Fence Wings
	for side_v in [-1.0, 1.0]:
		var side: float = float(side_v)
		_box(root, Vector3(side * 4.18, 0.24, 0), Vector3(3.55, 0.48, 0.42), stone_mat)
		_box(root, Vector3(side * 4.18, 0.52, 0), Vector3(3.65, 0.08, 0.48), stone_mat)
		_box(root, Vector3(side * 4.18, 1.32, 0), Vector3(3.55, 0.06, 0.06), iron_mat)
		for i in range(8):
			var fx: float = side * (2.62 + float(i) * 0.44)
			_cyl(root, Vector3(fx, 0.96, 0), 0.028, 0.028, 0.92, iron_mat, 6)
			_cyl(root, Vector3(fx, 1.48, 0), 0.0, 0.055, 0.14, brass_mat, 4, Vector3(0, 45, 0))
		_add_static_box(parent, gate_pos + Vector3(side * 4.20, 0, 0), Vector3(3.65, 2.5, 1.4))

		# Carved Stone Park Gate Pillars + Warm Rose-Gold Park Globe Lamps
		var px: float = side * 2.38
		_box(root, Vector3(px, 1.02, 0), Vector3(0.62, 2.04, 0.62), stone_mat)
		_box(root, Vector3(px, 2.10, 0), Vector3(0.74, 0.14, 0.74), stone_mat)
		_sphere(root, Vector3(px, 2.38, 0), Vector3(0.42, 0.42, 0.42), _std_mat(Color(1.0, 0.86, 0.66), 0.15, 0.0, Color(1.0, 0.76, 0.52), 1.75))

	# Curved Wrought-Iron Park Archway overhead
	var arch_pts: Array[Vector3] = []
	for k in range(11):
		var u := float(k) / 10.0
		arch_pts.append(Vector3(lerpf(-2.38, 2.38, u), 2.08 + sin(u * PI) * 0.78, 0.0))
	_swept_vine(root, arch_pts, 0.065, 0.065, iron_mat, 8)

	# Two Hinged Wrought-Iron & Brass Filigree Park Doors
	var doors: Array[Node3D] = []
	for side_v in [-1.0, 1.0]:
		var side: float = float(side_v)
		var hinge := Node3D.new()
		hinge.position = Vector3(side * 2.24, 0.0, 0.0)
		root.add_child(hinge)
		doors.append(hinge)
		var dir_in: float = -side
		_box(hinge, Vector3(dir_in * 1.10, 0.24, 0), Vector3(2.18, 0.07, 0.07), iron_mat)
		_box(hinge, Vector3(dir_in * 1.10, 0.88, 0), Vector3(2.18, 0.06, 0.06), iron_mat)
		_box(hinge, Vector3(dir_in * 1.10, 1.62, 0), Vector3(2.18, 0.07, 0.07), iron_mat)
		for b_i in range(7):
			var bx: float = dir_in * (0.18 + float(b_i) * 0.32)
			var bh: float = 1.48 + (float(b_i) / 6.0) * 0.24
			_cyl(hinge, Vector3(bx, bh * 0.5 + 0.16, 0), 0.026, 0.026, bh, iron_mat, 6)
			_cyl(hinge, Vector3(bx, bh + 0.22, 0), 0.0, 0.052, 0.14, brass_mat, 4, Vector3(0, 45, 0))

	# Intertwined Crimson Maple Vines + Leaf Clusters locking the iron gates
	var seal := Node3D.new()
	root.add_child(seal)
	var vine_wood := VisualPolish.make_organic_mat(Color(0.32, 0.16, 0.14), 2.8, 0.72, 0.92)
	for v_i in range(2):
		var pts: Array[Vector3] = []
		for k in range(8):
			var u := float(k) / 7.0
			pts.append(Vector3(lerpf(-1.62, 1.62, u), 0.62 + float(v_i) * 0.44 + sin(u * TAU + float(v_i)) * 0.18, 0.07))
		_swept_vine(seal, pts, 0.052, 0.038, vine_wood, 7)
		for lu in [0.18, 0.38, 0.62, 0.82]:
			var lx := lerpf(-1.55, 1.55, lu)
			var ly := 0.62 + float(v_i) * 0.44 + sin(lu * TAU + float(v_i)) * 0.18
			_sphere(seal, Vector3(lx, ly + 0.05, 0.10), Vector3(0.20, 0.13, 0.11), crimson_vine, 8, 6)
	_sphere(seal, Vector3(0, 0.95, 0.11), Vector3(0.22, 0.22, 0.14), brass_mat)

	var col := _add_static_box(parent, gate_pos, Vector3(4.8, 2.5, 1.5))
	return {
		"kind": "double_doors_z",
		"root": root,
		"door_l": doors[0],
		"door_r": doors[1],
		"vine_seal": seal,
		"collider": col,
	}


# ---------------------------------------------------------------------------
# Unified Unlock Choreography (Repairs Broken Bridges / Swings Gates Open!)
# ---------------------------------------------------------------------------
static func unlock(gate_data: Dictionary) -> void:
	if gate_data.is_empty():
		return
	var col: StaticBody3D = gate_data.get("collider", null)
	if col and is_instance_valid(col):
		col.queue_free()

	var root: Node3D = gate_data.get("root", null)
	if root == null or not is_instance_valid(root):
		return

	var seal: Node3D = gate_data.get("vine_seal", gate_data.get("vine_barrier", null))
	if seal and is_instance_valid(seal):
		var stw := root.create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		stw.tween_property(seal, "scale", Vector3(1.15, 0.02, 1.15), 0.34)
		stw.parallel().tween_property(seal, "position:y", seal.position.y - 0.55, 0.34)
		stw.tween_callback(seal.queue_free)

	var kind: String = gate_data.get("kind", "")
	if kind == "level1_bridge":
		var planks: Array = gate_data.get("planks", [])
		for i in range(planks.size()):
			var p_info: Dictionary = planks[i]
			var p_node: Node3D = p_info["node"]
			var rest_pos: Vector3 = p_info["rest_pos"]
			if is_instance_valid(p_node):
				var tw := root.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
				tw.tween_interval(float(i) * 0.07)
				tw.tween_property(p_node, "position", rest_pos, 0.46)
				tw.parallel().tween_property(p_node, "rotation_degrees", Vector3.ZERO, 0.46)
	elif kind == "drawbridge":
		var leaf: Node3D = gate_data.get("leaf_pivot", null)
		if leaf and is_instance_valid(leaf):
			var tw := root.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			tw.tween_property(leaf, "rotation_degrees:x", 0.0, 0.55)
	elif kind == "double_doors":
		var dl: Node3D = gate_data.get("door_l", null)
		var dr: Node3D = gate_data.get("door_r", null)
		var tw := root.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		if dl and is_instance_valid(dl):
			tw.parallel().tween_property(dl, "rotation_degrees:y", -104.0, 0.56)
		if dr and is_instance_valid(dr):
			tw.parallel().tween_property(dr, "rotation_degrees:y", 104.0, 0.56)
	elif kind == "double_doors_z":
		var dl2: Node3D = gate_data.get("door_l", null)
		var dr2: Node3D = gate_data.get("door_r", null)
		var tw2 := root.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		if dl2 and is_instance_valid(dl2):
			tw2.parallel().tween_property(dl2, "rotation_degrees:y", 106.0, 0.58)
		if dr2 and is_instance_valid(dr2):
			tw2.parallel().tween_property(dr2, "rotation_degrees:y", -106.0, 0.58)
