extends Node3D
class_name Chibi3D

## Studio-proportioned 3D Q-Chibi Character Builder (Boy & Girl).
## Upgrades over v1:
##  - Continuous smooth lofted A-line/bell garments (ZERO stove-pipe cylinder seams!)
##  - Vertex-color gradient open-front plush zip hoodie on Girl (sky-blue -> warm cream) + pinstriped shirt & V-cord star necklace
##  - Cozy sloped raglan/puff sleeves (~19 deg natural flare, zero 90-degree plumbing-pipe elbows!)
##  - Harmonious 2.3-head chibi neck/head ratio, tapered chinos / cuffed shorts, flat-soled chunky sneakers
##  - Fluffy multi-tuft layered hair, temple side-locks, and sculpted swept-tube eyeglasses with temple arms

var role: String = "boy"
var body_pivot: Node3D
var head_node: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var twin_l: Node3D
var twin_r: Node3D
var walk_time: float = 0.0
var attack_time: float = 0.0
var is_sitting: bool = false
var is_charred: bool = false
var saved_colors: Array[Dictionary] = []
var head_target_yaw: float = 0.0
var angry_time: float = 0.0
var celebrate_time: float = 0.0
var wave_side: int = 0
var held_milktea: Node3D = null
var is_falling_pose: bool = false
var fall_dive_amount: float = 0.0
var fall_bank_amount: float = 0.0
var stun_time: float = 0.0
var is_pelican_trapped: bool = false


func set_falling_pose(enabled: bool, dive: float = 0.0, bank: float = 0.0) -> void:
	is_falling_pose = enabled
	fall_dive_amount = clampf(dive, -1.0, 1.0)
	fall_bank_amount = clampf(bank, -1.0, 1.0)
	if not enabled and body_pivot:
		body_pivot.rotation = Vector3.ZERO
		body_pivot.position.y = 0.0


func trigger_stun(dur: float = 0.55) -> void:
	stun_time = maxf(stun_time, dur)


func set_pelican_trapped(trapped: bool) -> void:
	is_pelican_trapped = trapped


func set_waving(side: int) -> void:
	wave_side = side


func trigger_attack() -> void:
	attack_time = 0.26


func trigger_angry() -> void:
	angry_time = 0.48


func trigger_celebrate() -> void:
	celebrate_time = 1.6


func set_holding_milktea(holding: bool) -> void:
	if holding:
		if held_milktea == null and arm_r != null:
			var cup := Keepsake3D.create("milk_tea")
			cup.set_process(false)
			cup.scale = Vector3.ONE * 0.62
			cup.position = Vector3(0.16, -0.34, 0.20)
			cup.rotation.x = 0.62
			arm_r.add_child(cup)
			held_milktea = cup
	else:
		if held_milktea and is_instance_valid(held_milktea):
			held_milktea.queue_free()
			held_milktea = null


func set_sitting(sit: bool) -> void:
	is_sitting = sit
	if sit:
		leg_l.rotation.x = -1.38
		leg_r.rotation.x = -1.38
		body_pivot.position.y = -0.30
	else:
		leg_l.rotation.x = 0.0
		leg_r.rotation.x = 0.0
		body_pivot.position.y = 0.0


func set_charred(charred: bool) -> void:
	if is_charred == charred:
		return
	is_charred = charred
	if saved_colors.is_empty():
		_collect_materials(body_pivot)
	for item in saved_colors:
		var m: StandardMaterial3D = item["mat"]
		if charred:
			m.albedo_color = Color(0.08, 0.07, 0.08, item["alpha"])
		else:
			m.albedo_color = item["orig"]


func _collect_materials(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child
			if mi.material_override is StandardMaterial3D:
				var mat: StandardMaterial3D = mi.material_override
				saved_colors.append({"mat": mat, "orig": mat.albedo_color, "alpha": mat.albedo_color.a})
		_collect_materials(child)


static func create(p_role: String) -> Chibi3D:
	var c := Chibi3D.new()
	c.role = p_role
	c._build()
	return c


func _mat(col: Color, rough: float = 0.84, metallic: float = 0.0, alpha: float = 1.0, use_vcol: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.roughness = rough
	m.metallic = metallic
	m.vertex_color_use_as_albedo = use_vcol
	if use_vcol:
		m.vertex_color_is_srgb = true
	m.metallic_specular = 0.44 if rough < 0.30 else 0.14
	if rough >= 0.62 and alpha >= 1.0:
		m.rim_enabled = true
		m.rim = 0.14
		m.rim_tint = 0.35
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _sphere(parent: Node3D, pos: Vector3, scale_v: Vector3, mat: Material, seg: int = 18, rings: int = 12, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
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
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _box(parent: Node3D, pos: Vector3, size_v: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size_v
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, pos: Vector3, r_top: float, r_bot: float, h: float, mat: Material, scale_v: Vector3 = Vector3.ONE, seg: int = 18, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = seg
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale_v
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _loft_oval(
	parent: Node3D,
	slices: Array,
	mat: Material,
	sides: int = 24,
	cap_bottom: bool = true,
	cap_top: bool = true
) -> MeshInstance3D:
	## Smooth closed-loop oval loft mesh: each slice is [y, rx, rz, z_off, Color]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[Array] = []
	var cols: Array[Color] = []

	for sl in slices:
		var yy: float = sl[0]
		var rx: float = sl[1]
		var rz: float = sl[2]
		var z_off: float = sl[3] if sl.size() > 3 else 0.0
		var c: Color = sl[4] if sl.size() > 4 else Color.WHITE
		cols.append(c)
		var ring: Array[Vector3] = []
		for s in range(sides):
			var a := float(s) / float(sides) * TAU
			ring.append(Vector3(cos(a) * rx, yy, sin(a) * rz + z_off))
		rings.append(ring)

	for i in range(rings.size() - 1):
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		var c0 := cols[i]
		var c1 := cols[i + 1]
		for s in range(sides):
			var sn := (s + 1) % sides
			# Outward CCW winding when viewed from outside (+Y up, a from +X toward +Z)
			st.set_color(c0); st.add_vertex(r0[s])
			st.set_color(c0); st.add_vertex(r0[sn])
			st.set_color(c1); st.add_vertex(r1[sn])

			st.set_color(c0); st.add_vertex(r0[s])
			st.set_color(c1); st.add_vertex(r1[sn])
			st.set_color(c1); st.add_vertex(r1[s])

	if cap_bottom and rings.size() >= 2:
		var rb: Array = rings[0]
		var cb := Vector3(0.0, slices[0][0], slices[0][3] if slices[0].size() > 3 else 0.0)
		for s in range(sides):
			var sn := (s + 1) % sides
			st.set_color(cols[0]); st.add_vertex(cb)
			st.set_color(cols[0]); st.add_vertex(rb[sn])
			st.set_color(cols[0]); st.add_vertex(rb[s])

	if cap_top and rings.size() >= 2:
		var rt: Array = rings[rings.size() - 1]
		var last_sl: Array = slices[slices.size() - 1]
		var ct := Vector3(0.0, last_sl[0], last_sl[3] if last_sl.size() > 3 else 0.0)
		var ctop := cols[cols.size() - 1]
		for s in range(sides):
			var sn := (s + 1) % sides
			st.set_color(ctop); st.add_vertex(ct)
			st.set_color(ctop); st.add_vertex(rt[s])
			st.set_color(ctop); st.add_vertex(rt[sn])

	st.index()
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _build_open_hoodie_shell(parent: Node3D, slices: Array, mat: Material, arc_segs: int = 22) -> MeshInstance3D:
	## Sculpted open-front zip hoodie shell: wraps smoothly from right front lapel around back to left front lapel,
	## with thickness so the open front edges look plush and tailored rather than paper-thin!
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# In Godot (+X right, +Z front), front center is angle PI/2.
	# Leave a neat open V/front gap around PI/2: span from a_start = PI*0.63 around back to a_end = PI*2.37
	var a0 := PI * 0.62
	var a1 := PI * 2.38
	var outer_rows: Array[Array] = []
	var inner_rows: Array[Array] = []
	var cols: Array[Color] = []

	for sl in slices:
		var yy: float = sl[0]
		var rx: float = sl[1]
		var rz: float = sl[2]
		var c: Color = sl[3]
		var gap_narrow: float = sl[4] if sl.size() > 4 else 0.0
		cols.append(c)
		var o_row: Array[Vector3] = []
		var i_row: Array[Vector3] = []
		var cur_a0 := a0 - gap_narrow
		var cur_a1 := a1 + gap_narrow
		for s in range(arc_segs + 1):
			var u := float(s) / float(arc_segs)
			var a := lerpf(cur_a0, cur_a1, u)
			o_row.append(Vector3(cos(a) * rx, yy, sin(a) * rz))
			i_row.append(Vector3(cos(a) * maxf(0.05, rx - 0.032), yy, sin(a) * maxf(0.05, rz - 0.032)))
		outer_rows.append(o_row)
		inner_rows.append(i_row)

	var n_sl := slices.size()
	for i in range(n_sl - 1):
		var c0 := cols[i]
		var c1 := cols[i + 1]
		for s in range(arc_segs):
			var oa: Vector3 = outer_rows[i][s]
			var ob: Vector3 = outer_rows[i][s + 1]
			var oc: Vector3 = outer_rows[i + 1][s + 1]
			var od: Vector3 = outer_rows[i + 1][s]
			st.set_color(c0); st.add_vertex(oa)
			st.set_color(c0); st.add_vertex(ob)
			st.set_color(c1); st.add_vertex(oc)
			st.set_color(c0); st.add_vertex(oa)
			st.set_color(c1); st.add_vertex(oc)
			st.set_color(c1); st.add_vertex(od)

			var ia: Vector3 = inner_rows[i][s]
			var ib: Vector3 = inner_rows[i][s + 1]
			var ic: Vector3 = inner_rows[i + 1][s + 1]
			var id_v: Vector3 = inner_rows[i + 1][s]
			st.set_color(c0); st.add_vertex(ia)
			st.set_color(c1); st.add_vertex(ic)
			st.set_color(c0); st.add_vertex(ib)
			st.set_color(c0); st.add_vertex(ia)
			st.set_color(c1); st.add_vertex(id_v)
			st.set_color(c1); st.add_vertex(ic)

		# Stitch front left & front right plush lapel edges
		for end_idx in [0, arc_segs]:
			var eo0: Vector3 = outer_rows[i][end_idx]
			var ei0: Vector3 = inner_rows[i][end_idx]
			var eo1: Vector3 = outer_rows[i + 1][end_idx]
			var ei1: Vector3 = inner_rows[i + 1][end_idx]
			if end_idx == 0:
				st.set_color(c0); st.add_vertex(ei0); st.set_color(c0); st.add_vertex(eo0); st.set_color(c1); st.add_vertex(eo1)
				st.set_color(c0); st.add_vertex(ei0); st.set_color(c1); st.add_vertex(eo1); st.set_color(c1); st.add_vertex(ei1)
			else:
				st.set_color(c0); st.add_vertex(eo0); st.set_color(c0); st.add_vertex(ei0); st.set_color(c1); st.add_vertex(ei1)
				st.set_color(c0); st.add_vertex(eo0); st.set_color(c1); st.add_vertex(ei1); st.set_color(c1); st.add_vertex(eo1)

	# Bottom & top rim stitch
	for s in range(arc_segs):
		st.set_color(cols[0]); st.add_vertex(inner_rows[0][s])
		st.set_color(cols[0]); st.add_vertex(outer_rows[0][s + 1])
		st.set_color(cols[0]); st.add_vertex(outer_rows[0][s])
		st.set_color(cols[0]); st.add_vertex(inner_rows[0][s])
		st.set_color(cols[0]); st.add_vertex(inner_rows[0][s + 1])
		st.set_color(cols[0]); st.add_vertex(outer_rows[0][s + 1])

		var top_i := n_sl - 1
		st.set_color(cols[top_i]); st.add_vertex(outer_rows[top_i][s])
		st.set_color(cols[top_i]); st.add_vertex(outer_rows[top_i][s + 1])
		st.set_color(cols[top_i]); st.add_vertex(inner_rows[top_i][s + 1])
		st.set_color(cols[top_i]); st.add_vertex(outer_rows[top_i][s])
		st.set_color(cols[top_i]); st.add_vertex(inner_rows[top_i][s + 1])
		st.set_color(cols[top_i]); st.add_vertex(inner_rows[top_i][s])

	st.index()
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _swept_tube(
	parent: Node3D,
	points: Array[Vector3],
	radii: Array[float],
	mat: Material,
	sides: int = 16,
	cap_ends: bool = true,
	colors: Array[Color] = []
) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var tangs: Array[Vector3] = []
	for i in range(points.size()):
		if i == 0:
			tangs.append((points[1] - points[0]).normalized())
		elif i == points.size() - 1:
			tangs.append((points[i] - points[i - 1]).normalized())
		else:
			tangs.append((points[i + 1] - points[i - 1]).normalized())

	var ref_n := Vector3.FORWARD if abs(tangs[0].dot(Vector3.UP)) > 0.9 else Vector3.UP
	var prev_u := tangs[0].cross(ref_n).normalized()
	var prev_v := prev_u.cross(tangs[0]).normalized()

	var rings: Array[Array] = []
	var ring_cols: Array[Color] = []
	for i in range(points.size()):
		var t := tangs[i]
		var u := (prev_u - t * prev_u.dot(t))
		if u.length() < 0.001:
			u = prev_v.cross(t)
		u = u.normalized()
		var v := t.cross(u).normalized()
		prev_u = u
		prev_v = v

		var r := radii[i]
		ring_cols.append(colors[i] if i < colors.size() else Color.WHITE)
		var ring: Array[Vector3] = []
		for s in range(sides):
			var a := float(s) / float(sides) * TAU
			ring.append(points[i] + (u * cos(a) + v * sin(a)) * r)
		rings.append(ring)

	for i in range(rings.size() - 1):
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		var c0 := ring_cols[i]
		var c1 := ring_cols[i + 1]
		for s in range(sides):
			var sn := (s + 1) % sides
			st.set_color(c0); st.add_vertex(r0[s])
			st.set_color(c1); st.add_vertex(r1[s])
			st.set_color(c1); st.add_vertex(r1[sn])

			st.set_color(c0); st.add_vertex(r0[s])
			st.set_color(c1); st.add_vertex(r1[sn])
			st.set_color(c0); st.add_vertex(r0[sn])

	if cap_ends and rings.size() >= 2:
		var p_start: Vector3 = points[0]
		var r_start: Array = rings[0]
		for s in range(sides):
			var sn := (s + 1) % sides
			st.set_color(ring_cols[0]); st.add_vertex(p_start)
			st.set_color(ring_cols[0]); st.add_vertex(r_start[sn])
			st.set_color(ring_cols[0]); st.add_vertex(r_start[s])
		var p_end: Vector3 = points[points.size() - 1]
		var r_end: Array = rings[rings.size() - 1]
		var ce := ring_cols[ring_cols.size() - 1]
		for s in range(sides):
			var sn := (s + 1) % sides
			st.set_color(ce); st.add_vertex(p_end)
			st.set_color(ce); st.add_vertex(r_end[s])
			st.set_color(ce); st.add_vertex(r_end[sn])

	st.index()
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _build_star_mesh(parent: Node3D, pos: Vector3, outer_r: float, inner_r: float, depth: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center_f := Vector3(0, 0, depth * 0.5)
	var center_b := Vector3(0, 0, -depth * 0.5)
	var ring: Array[Vector3] = []
	for i in range(10):
		var a := PI * 0.5 + float(i) * PI / 5.0
		var r := outer_r if i % 2 == 0 else inner_r
		ring.append(Vector3(cos(a) * r, sin(a) * r, 0))
	for i in range(10):
		var n := (i + 1) % 10
		st.add_vertex(center_f); st.add_vertex(ring[i]); st.add_vertex(ring[n])
		st.add_vertex(center_b); st.add_vertex(ring[n]); st.add_vertex(ring[i])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _build_chest_leaf_emblem(parent: Node3D, pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees = Vector3(6, 16, -28)
	parent.add_child(holder)

	var leaf_mat := _mat(Color(0.34, 0.78, 0.40), 0.58)
	var stem_mat := _mat(Color(0.18, 0.44, 0.22), 0.72)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p_base := Vector3(0, -0.058, 0.0)
	var p_l := Vector3(-0.048, 0.0, 0.010)
	var p_r := Vector3(0.048, 0.0, 0.010)
	var p_mid := Vector3(0, 0.006, 0.026)
	var p_tip := Vector3(0, 0.078, 0.005)
	st.add_vertex(p_base); st.add_vertex(p_mid); st.add_vertex(p_l)
	st.add_vertex(p_base); st.add_vertex(p_r); st.add_vertex(p_mid)
	st.add_vertex(p_l); st.add_vertex(p_mid); st.add_vertex(p_tip)
	st.add_vertex(p_mid); st.add_vertex(p_r); st.add_vertex(p_tip)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = leaf_mat
	holder.add_child(mi)
	_cyl(holder, Vector3(0, -0.072, 0.004), 0.008, 0.010, 0.042, stem_mat, Vector3.ONE, 6)


func _build_chunky_sneaker(parent: Node3D, is_boy: bool, upper_mat: Material, trim_mat: Material, sole_mat: Material, lace_mat: Material) -> void:
	## Flat-bottomed grounded chibi sneaker sitting flush at leg-local y = -0.50 (world y = 0.0)!
	# 1. Flat-soled rubber outsole (y = -0.50 to -0.455)
	_loft_oval(parent, [
		[-0.500, 0.095, 0.148, 0.036],
		[-0.488, 0.104, 0.158, 0.038],
		[-0.455, 0.102, 0.155, 0.036],
	], sole_mat, 20, true, true)

	# 2. Sculpted sneaker upper vamp & heel counter
	_loft_oval(parent, [
		[-0.458, 0.098, 0.148, 0.034],
		[-0.415, 0.094, 0.136, 0.028],
		[-0.378, 0.076, 0.098, 0.008],
	], upper_mat, 20, false, true)

	# 3. Toe cap: Girl has crisp white canvas-sneaker rubber toe cap; Boy has tonal dark-moss toe bumper!
	_sphere(parent, Vector3(0, -0.440, 0.126), Vector3(0.172, 0.088, 0.125), trim_mat, 16, 10)

	# 4. Padded tongue & 2 neat shoelace bars
	_sphere(parent, Vector3(0, -0.376, 0.052), Vector3(0.105, 0.055, 0.085), trim_mat if not is_boy else upper_mat, 12, 8, Vector3(-22, 0, 0))
	for lz in [0.068, 0.098]:
		_box(parent, Vector3(0, -0.392 - (lz - 0.068) * 0.45, lz), Vector3(0.088, 0.016, 0.020), lace_mat, Vector3(24, 0, 0))


func _build_twintail(parent: Node3D, side: float, hair_mat: Material, tie_mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(side * 0.34, -0.10, -0.12)
	parent.add_child(pivot)

	# Cute double-bead pastel hair tie
	_sphere(pivot, Vector3(side * 0.045, -0.01, 0.01), Vector3(0.105, 0.095, 0.105), tie_mat, 14, 10)
	_sphere(pivot, Vector3(side * 0.085, 0.015, 0.03), Vector3(0.075, 0.075, 0.075), tie_mat, 12, 8)

	# Graceful S-curved plush twin-tail with soft outward curl at tip
	var pts: Array[Vector3] = []
	var rads: Array[float] = []
	var steps := 12
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var px := side * (0.04 + 0.14 * sin(t * 2.1) + 0.04 * pow(t, 2.2))
		var py := -0.01 - t * 0.44
		var pz := -0.01 - 0.05 * sin(t * PI) + 0.04 * pow(t, 2.0)
		pts.append(Vector3(px, py, pz))
		var r := 0.048 + 0.086 * sin(pow(t, 0.68) * PI)
		rads.append(maxf(0.014, r))
	_swept_tube(pivot, pts, rads, hair_mat, 16, true)
	return pivot


func _build_sculpted_glasses(parent: Node3D, is_boy: bool) -> void:
	var frame_mat: StandardMaterial3D
	var rim_r: float
	if is_boy:
		# Translucent crystal-grey rounded-square frames (boy_chibi.png)
		frame_mat = _mat(Color(0.86, 0.91, 0.96), 0.14, 0.08, 0.78)
		rim_r = 0.0145
	else:
		# Delicate champagne-gold octagonal wire frames (girl_chibi.png)
		frame_mat = _mat(Color(0.88, 0.71, 0.34), 0.22, 0.78)
		rim_r = 0.0115

	for sx_v in [-0.172, 0.172]:
		var sx: float = float(sx_v)
		var side: float = signf(sx)
		var loop_pts: Array[Vector3] = []
		var loop_rads: Array[float] = []
		var segs := 16 if is_boy else 8
		for i in range(segs + 1):
			var a := (float(i) / float(segs)) * TAU + (PI / 8.0 if not is_boy else 0.0)
			var ca := cos(a)
			var sa := sin(a)
			var rx := 0.118
			var ry := 0.092
			var px: float
			var py: float
			if is_boy:
				# Superellipse (rounded square n=3.2)
				px = sx + signf(ca) * pow(absf(ca), 0.58) * rx
				py = 0.012 + signf(sa) * pow(absf(sa), 0.58) * ry
			else:
				# Crisp octagon
				px = sx + ca * rx * 1.06
				py = 0.012 + sa * ry * 1.08
			# Subtle wrap following head curvature
			var pz := 0.446 - absf(px) * 0.065
			loop_pts.append(Vector3(px, py, pz))
			loop_rads.append(rim_r)
		_swept_tube(parent, loop_pts, loop_rads, frame_mat, 10, false)

		# Temple arms reaching cleanly back from outer frame edge to above the ear!
		var outer_x: float = sx + side * 0.116
		var temple_pts: Array[Vector3] = [
			Vector3(outer_x, 0.025, 0.425),
			Vector3(side * 0.36, 0.022, 0.28),
			Vector3(side * 0.435, 0.010, 0.05),
			Vector3(side * 0.430, -0.035, -0.04),
		]
		_swept_tube(parent, temple_pts, [rim_r, rim_r * 0.9, rim_r * 0.85, rim_r * 0.8], frame_mat, 8, true)

	# Arched nose bridge
	_swept_tube(
		parent,
		[Vector3(-0.058, 0.032, 0.444), Vector3(0.0, 0.044, 0.452), Vector3(0.058, 0.032, 0.444)],
		[rim_r, rim_r, rim_r],
		frame_mat, 8, false
	)


func _build_chibi_head_mesh(parent: Node3D, mat: Material, segs: int = 32, rings: int = 24) -> MeshInstance3D:
	## Single continuous sculpted Q-chibi head mesh (smooth baby cheeks & soft chin, ZERO intersecting-sphere double-chin seam!)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var grid: Array[Array] = []
	for r in range(rings + 1):
		var v := float(r) / float(rings)
		var theta := lerpf(-PI * 0.5, PI * 0.5, v)
		var ny := sin(theta)
		var cos_t := cos(theta)
		# Smooth Gaussian baby-cheek fullness around lower face (C-infinity continuous -> zero ridge)
		var cheek := exp(-pow((ny + 0.18) / 0.42, 2.0))
		var row: Array[Vector3] = []
		for s in range(segs + 1):
			var u := float(s) / float(segs)
			var phi := u * TAU
			var nx := cos_t * cos(phi)
			var nz := cos_t * sin(phi)
			var rx := 0.432 + 0.024 * cheek
			var ry := 0.392
			var rz := 0.410 + 0.010 * cheek * maxf(0.0, nz)
			# Slight dainty chin taper at very bottom so jawline feels clean and cute
			if ny < -0.55:
				var chin_t := clampf((-ny - 0.55) / 0.45, 0.0, 1.0)
				rx *= (1.0 - 0.04 * chin_t * chin_t)
				rz *= (1.0 - 0.03 * chin_t * chin_t)
			row.append(Vector3(nx * rx, ny * ry, nz * rz))
		grid.append(row)

	for r in range(rings):
		for s in range(segs):
			var p00: Vector3 = grid[r][s]
			var p10: Vector3 = grid[r][s + 1]
			var p11: Vector3 = grid[r + 1][s + 1]
			var p01: Vector3 = grid[r + 1][s]
			if r > 0:
				st.add_vertex(p00)
				st.add_vertex(p10)
				st.add_vertex(p11)
			if r < rings - 1:
				st.add_vertex(p00)
				st.add_vertex(p11)
				st.add_vertex(p01)

	st.index()
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _build() -> void:
	body_pivot = Node3D.new()
	add_child(body_pivot)

	var skin := _mat(Color(0.98, 0.81, 0.70), 0.72)
	var hair := _mat(Color(0.17, 0.14, 0.13), 0.78)
	var eye_mat := _mat(Color(0.10, 0.08, 0.10), 0.08)
	var blush := _mat(Color(0.98, 0.56, 0.62), 0.82)
	var mouth_mat := _mat(Color(0.68, 0.30, 0.33), 0.65)
	var white_mat := _mat(Color(0.94, 0.95, 0.97), 0.80)

	# --- 1. COZY TUCKED CHIBI NECK ---
	_loft_oval(body_pivot, [
		[1.08, 0.105, 0.098, 0.0],
		[1.18, 0.088, 0.085, 0.0],
		[1.26, 0.092, 0.088, 0.0],
	], skin, 16, false, false)

	# --- 2. SCULPTED LEGS, TROUSERS/SOCKS & FLAT-SOLED CHUNKY SNEAKERS ---
	var pant_mat := _mat(Color(0.50, 0.45, 0.31), 0.88)      # Warm khaki-olive chinos (boy_chibi.png)
	var pant_cuff := _mat(Color(0.41, 0.37, 0.25), 0.90)
	var shorts_mat := _mat(Color(0.45, 0.48, 0.54), 0.86)    # Tailored slate-grey shorts (girl_chibi.png)
	var sock_mat := _mat(Color(0.97, 0.97, 0.99), 0.82)

	var boy_shoe := _mat(Color(0.27, 0.41, 0.30), 0.80)      # Matte forest-olive sneakers
	var boy_trim := _mat(Color(0.21, 0.33, 0.24), 0.82)
	var boy_sole := _mat(Color(0.16, 0.18, 0.17), 0.90)
	var girl_shoe := _mat(Color(0.40, 0.57, 0.76), 0.76)     # Slate-blue canvas sneakers
	var girl_sole := _mat(Color(0.96, 0.96, 0.98), 0.80)

	for side_idx in range(2):
		var sx := -0.128 if side_idx == 0 else 0.128
		var leg := Node3D.new()
		leg.position = Vector3(sx, 0.50, 0.0)
		body_pivot.add_child(leg)
		if side_idx == 0:
			leg_l = leg
		else:
			leg_r = leg

		if role == "boy":
			# Tapered relaxed chinos with subtle knee fullness & ankle cuff fold
			_loft_oval(leg, [
				[0.04, 0.118, 0.114, 0.0],
				[-0.12, 0.116, 0.112, 0.008],
				[-0.26, 0.108, 0.106, 0.006],
				[-0.34, 0.098, 0.098, 0.004],
			], pant_mat, 18, true, true)
			# Rolled chino cuff resting neatly over sneaker tongue
			_loft_oval(leg, [
				[-0.372, 0.104, 0.104, 0.006],
				[-0.330, 0.106, 0.106, 0.006],
			], pant_cuff, 18, true, true)
			_build_chunky_sneaker(leg, true, boy_shoe, boy_trim, boy_sole, boy_sole)
		else:
			# Tailored shorts leg cuff overlapping hip yoke seamlessly (zero horizontal gap!)
			_loft_oval(leg, [
				[0.07, 0.124, 0.120, 0.0],
				[-0.085, 0.130, 0.124, 0.004],
				[-0.115, 0.126, 0.120, 0.004],
			], shorts_mat, 18, true, true)
			# Smooth softly-tapered chibi leg
			_loft_oval(leg, [
				[-0.09, 0.082, 0.082, 0.004],
				[-0.20, 0.076, 0.076, 0.004],
				[-0.30, 0.068, 0.068, 0.004],
				[-0.38, 0.066, 0.066, 0.004],
			], skin, 16, false, false)
			# Crisp ribbed white crew sock with subtle slate-blue top stripe
			_loft_oval(leg, [
				[-0.385, 0.074, 0.074, 0.005],
				[-0.280, 0.076, 0.076, 0.005],
			], sock_mat, 16, true, true)
			_loft_oval(leg, [
				[-0.295, 0.077, 0.077, 0.005],
				[-0.282, 0.077, 0.077, 0.005],
			], girl_shoe, 16, false, false)
			_build_chunky_sneaker(leg, false, girl_shoe, white_mat, girl_sole, white_mat)

	# --- 3. COHESIVE SCULPTED TORSO & GARMENTS ---
	if role == "boy":
		var shirt := _mat(Color(0.21, 0.22, 0.25), 0.88)
		var rib := _mat(Color(0.15, 0.16, 0.19), 0.90)

		# Hip/pelvis bridge so legs never show a gap during stride
		_loft_oval(body_pivot, [
			[0.45, 0.235, 0.165, 0.0],
			[0.54, 0.255, 0.180, 0.0],
		], pant_mat, 20, true, true)

		# Ribbed sweatshirt waistband hem (slight gather)
		_loft_oval(body_pivot, [
			[0.50, 0.268, 0.192, 0.004],
			[0.56, 0.286, 0.206, 0.005],
		], rib, 24, true, false)

		# Seamless lofted cozy oversized crewneck sweatshirt (soft A-line drape -> sloped shoulders!)
		_loft_oval(body_pivot, [
			[0.555, 0.292, 0.212, 0.006],
			[0.650, 0.306, 0.224, 0.010],
			[0.800, 0.294, 0.214, 0.008],
			[0.950, 0.262, 0.192, 0.004],
			[1.065, 0.208, 0.158, 0.000],
			[1.125, 0.138, 0.118, 0.000],
		], shirt, 26, false, true)

		# Snug ribbed crewneck collar ring
		_loft_oval(body_pivot, [
			[1.110, 0.146, 0.126, 0.002],
			[1.155, 0.122, 0.110, 0.002],
		], rib, 22, false, true)

		# Cute sculpted tilted green leaf embroidery on left chest!
		_build_chest_leaf_emblem(body_pivot, Vector3(0.125, 0.94, 0.205))
	else:
		# Tailored shorts hip yoke overlapping legs cleanly (slim & neat, zero seam!)
		_loft_oval(body_pivot, [
			[0.42, 0.244, 0.172, 0.0],
			[0.56, 0.256, 0.182, 0.0],
		], shorts_mat, 22, true, true)

		# Inner crisp white collared blouse + vertical pinstripes + tiny buttons
		_loft_oval(body_pivot, [
			[0.53, 0.248, 0.176, 0.004],
			[0.78, 0.246, 0.178, 0.006],
			[1.02, 0.205, 0.150, 0.002],
			[1.12, 0.128, 0.112, 0.000],
		], white_mat, 22, false, true)

		var stripe_mat := _mat(Color(0.56, 0.60, 0.68), 0.85)
		for sx_st in [-0.075, -0.038, 0.038, 0.075]:
			_box(body_pivot, Vector3(sx_st, 0.80, 0.178), Vector3(0.008, 0.44, 0.012), stripe_mat, Vector3(-4, 0, 0))
		var btn_mat := _mat(Color(0.26, 0.28, 0.34), 0.55)
		for by in [0.96, 0.83, 0.70]:
			_sphere(body_pivot, Vector3(0.0, by, 0.186), Vector3(0.026, 0.026, 0.020), btn_mat, 10, 6)

		# Folded pointed white blouse collar flaps
		for side in [-1.0, 1.0]:
			_box(body_pivot, Vector3(side * 0.058, 1.095, 0.128), Vector3(0.088, 0.068, 0.026), white_mat, Vector3(18, -side * 18, side * 26))

		# V-cord necklace + gleaming 3D golden 5-pointed star pendant!
		var cord_mat := _mat(Color(0.24, 0.18, 0.16), 0.85)
		var gold_star := _mat(Color(0.98, 0.80, 0.28), 0.24, 0.62)
		_swept_tube(
			body_pivot,
			[Vector3(-0.062, 1.08, 0.135), Vector3(0.0, 0.93, 0.194), Vector3(0.062, 1.08, 0.135)],
			[0.008, 0.008, 0.008],
			cord_mat, 8, false
		)
		_build_star_mesh(body_pivot, Vector3(0.0, 0.915, 0.202), 0.056, 0.025, 0.024, gold_star)

		# Open-Front Plush Gradient Zip Hoodie (sRGB pastel sky-blue -> warm butter-cream!)
		var grad_hoodie_mat := _mat(Color.WHITE, 0.88, 0.0, 1.0, true)
		var c_blue := Color(0.48, 0.74, 0.94)
		var c_mid := Color(0.72, 0.85, 0.90)
		var c_cream := Color(0.95, 0.88, 0.72)
		var c_cream_rib := Color(0.88, 0.80, 0.64)

		_build_open_hoodie_shell(body_pivot, [
			[0.505, 0.288, 0.210, c_cream_rib, -0.04],
			[0.560, 0.312, 0.228, c_cream, -0.02],
			[0.680, 0.318, 0.232, c_cream, 0.00],
			[0.800, 0.302, 0.218, c_mid, 0.02],
			[0.940, 0.268, 0.194, c_blue, 0.05],
			[1.060, 0.212, 0.158, c_blue, 0.10],
			[1.125, 0.145, 0.122, c_blue, 0.14],
		], grad_hoodie_mat, 24)

		# Cozy plush back hood & front drawstring cords (girl_chibi.png)
		var hood_blue := _mat(c_blue, 0.88)
		_sphere(body_pivot, Vector3(0, 1.07, -0.155), Vector3(0.38, 0.20, 0.22), hood_blue, 16, 10, Vector3(-14, 0, 0))
		for side in [-1.0, 1.0]:
			_swept_tube(
				body_pivot,
				[
					Vector3(side * 0.095, 1.07, 0.148),
					Vector3(side * 0.108, 0.94, 0.196),
					Vector3(side * 0.112, 0.81, 0.208),
				],
				[0.011, 0.011, 0.012],
				white_mat, 8, true
			)

	# --- 4. NATURAL SLOPED PUFF SLEEVES & PROPORTIONED CHIBI HANDS ---
	var boy_sleeve := _mat(Color(0.21, 0.22, 0.25), 0.88)
	var boy_cuff := _mat(Color(0.15, 0.16, 0.19), 0.90)
	var girl_sleeve_grad := _mat(Color.WHITE, 0.88, 0.0, 1.0, true)
	var girl_shoulder_blue := _mat(Color(0.48, 0.74, 0.94), 0.88)
	var girl_cuff := _mat(Color(0.90, 0.82, 0.66), 0.90)

	for side_idx in range(2):
		var side := -1.0 if side_idx == 0 else 1.0
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.202, 1.028, 0.0)
		body_pivot.add_child(arm)
		if side_idx == 0:
			arm_l = arm
		else:
			arm_r = arm

		# Seamless rounded shoulder cap blending sleeve smoothly into sloped torso!
		_sphere(arm, Vector3(side * 0.012, 0.0, 0.0), Vector3(0.158, 0.158, 0.154), boy_sleeve if role == "boy" else girl_shoulder_blue, 14, 10)

		# Natural ~21-degree A-line outward slope + cozy lower-forearm puff + slight forward poise
		var arm_pts: Array[Vector3] = []
		var arm_rads: Array[float] = []
		var arm_cols: Array[Color] = []
		var seg_n := 9
		for i in range(seg_n + 1):
			var t := float(i) / float(seg_n)
			var ax := side * (0.015 + 0.140 * pow(t, 0.92))
			var ay := -0.355 * t
			var az := 0.032 * sin(t * PI * 0.85) + 0.018 * t
			arm_pts.append(Vector3(ax, ay, az))
			var r_prof := 0.074 + 0.030 * sin(pow(t, 0.75) * PI * 0.94)
			arm_rads.append(r_prof)
			if role == "girl":
				var g_t := clampf((t - 0.34) / 0.46, 0.0, 1.0)
				arm_cols.append(Color(0.48, 0.74, 0.94).lerp(Color(0.95, 0.88, 0.72), g_t))
			else:
				arm_cols.append(Color.WHITE)

		_swept_tube(
			arm, arm_pts, arm_rads,
			boy_sleeve if role == "boy" else girl_sleeve_grad,
			16, true, arm_cols
		)

		var wrist: Vector3 = arm_pts[seg_n]
		var wrist_dir := (arm_pts[seg_n] - arm_pts[seg_n - 1]).normalized()
		var cuff_pos := wrist + wrist_dir * 0.022
		_cyl(
			arm, cuff_pos, 0.076, 0.070, 0.048,
			boy_cuff if role == "boy" else girl_cuff,
			Vector3.ONE, 16, Vector3(-6, 0, side * 21.0)
		)

		# Delicate chibi mitten hand + thumb (proportioned cleanly, slightly tucked inward)
		var hand_pos := wrist + wrist_dir * 0.072 + Vector3(-side * 0.008, 0, 0.008)
		_sphere(arm, hand_pos, Vector3(0.112, 0.122, 0.098), skin, 14, 10, Vector3(-8, 0, side * 14.0))
		_sphere(arm, hand_pos + Vector3(-side * 0.046, 0.015, 0.034), Vector3(0.048, 0.062, 0.046), skin, 10, 8)

	# --- 5. HARMONIOUS CHIBI HEAD (y = 1.485), LAYERED FLUFFY HAIR & EYEWEAR ---
	head_node = Node3D.new()
	head_node.position = Vector3(0, 1.485, 0.01)
	body_pivot.add_child(head_node)

	# Single continuous sculpted chibi head (smooth mochi cheeks, zero double-chin crease!)
	_build_chibi_head_mesh(head_node, skin, 32, 24)
	_sphere(head_node, Vector3(-0.435, -0.04, -0.01), Vector3(0.125, 0.165, 0.110), skin)
	_sphere(head_node, Vector3(0.435, -0.04, -0.01), Vector3(0.125, 0.165, 0.110), skin)

	# Expressive glossy eyes with dual catchlights + rosy blush + warm smile
	for side in [-1.0, 1.0]:
		var ex: float = side * 0.165
		_sphere(head_node, Vector3(ex, 0.012, 0.388), Vector3(0.098, 0.128, 0.050), eye_mat)
		_sphere(head_node, Vector3(ex + 0.020, 0.043, 0.410), Vector3(0.032, 0.036, 0.018), white_mat)
		_sphere(head_node, Vector3(ex - 0.018, -0.022, 0.408), Vector3(0.016, 0.018, 0.014), white_mat)
		_sphere(head_node, Vector3(side * 0.256, -0.088, 0.352), Vector3(0.118, 0.056, 0.028), blush)

	_swept_tube(
		head_node,
		[Vector3(-0.074, -0.136, 0.385), Vector3(0.0, -0.162, 0.395), Vector3(0.074, -0.136, 0.385)],
		[0.012, 0.014, 0.012],
		mouth_mat, 10, true
	)

	# Plush layered cranium hair cap + warm crown sheen
	_sphere(head_node, Vector3(0, 0.115, -0.045), Vector3(0.955, 0.86, 0.92), hair, 22, 16)
	_sphere(head_node, Vector3(0, 0.02, -0.10), Vector3(0.92, 0.78, 0.84), hair, 18, 12)

	if role == "boy":
		# Tousled crown volume + cute subtle top cowlick tufts (boy_chibi.png)
		_swept_tube(
			head_node,
			[Vector3(-0.04, 0.48, -0.02), Vector3(0.02, 0.545, 0.02), Vector3(0.10, 0.56, 0.04)],
			[0.065, 0.048, 0.012],
			hair, 10, true
		)
		_swept_tube(
			head_node,
			[Vector3(-0.06, 0.47, -0.06), Vector3(-0.14, 0.525, -0.04), Vector3(-0.20, 0.52, -0.02)],
			[0.055, 0.038, 0.010],
			hair, 10, true
		)

		# Asymmetric layered wispy bangs + side temple tufts framing the glasses!
		for bang_cfg in [
			[-0.28, 0.11, -0.05, 0.092],
			[-0.14, 0.13, 0.03, 0.098],
			[0.01, 0.12, -0.02, 0.102],
			[0.15, 0.13, 0.04, 0.096],
			[0.28, 0.11, -0.04, 0.090],
		]:
			var bx: float = bang_cfg[0]
			var tip_y: float = bang_cfg[1]
			var sweep_x: float = bang_cfg[2]
			var r_base: float = bang_cfg[3]
			_swept_tube(
				head_node,
				[
					Vector3(bx * 0.76, 0.37, 0.17),
					Vector3(bx * 0.92 + sweep_x * 0.3, 0.29, 0.31),
					Vector3(bx + sweep_x * 0.7, 0.20, 0.385),
					Vector3(bx + sweep_x, tip_y, 0.402),
				],
				[r_base, r_base * 0.92, r_base * 0.58, 0.012],
				hair, 12, true
			)

		# Sideburns / temple tufts in front of ears
		for side in [-1.0, 1.0]:
			_swept_tube(
				head_node,
				[
					Vector3(side * 0.36, 0.22, 0.18),
					Vector3(side * 0.425, 0.09, 0.15),
					Vector3(side * 0.435, -0.03, 0.12),
				],
				[0.075, 0.058, 0.014],
				hair, 10, true
			)
			# Expressive arched eyebrows
			_swept_tube(
				head_node,
				[
					Vector3(side * 0.10, 0.132, 0.405),
					Vector3(side * 0.17, 0.146, 0.408),
					Vector3(side * 0.24, 0.130, 0.392),
				],
				[0.015, 0.018, 0.013],
				hair, 8, true
			)

		_build_sculpted_glasses(head_node, true)
	else:
		# Center-parted airy curtain bangs + soft cheek-framing side-locks (girl_chibi.png)
		for side in [-1.0, 1.0]:
			var s_f: float = float(side)
			var fb_pts: Array[Vector3] = []
			var fb_rads: Array[float] = []
			for i in range(9):
				var t := float(i) / 8.0
				var px: float = s_f * (0.025 + 0.385 * sin(t * 1.48))
				var py: float = 0.39 - t * 0.46
				var pz: float = 0.25 + 0.125 * sin(t * PI * 0.92) - t * 0.07
				fb_pts.append(Vector3(px, py, pz))
				fb_rads.append(0.068 + 0.056 * sin(t * PI * 0.88))
			_swept_tube(head_node, fb_pts, fb_rads, hair, 14, true)

			# Delicate cheek-framing side-lock (鬓角) sweeping softly past ear & cheek
			_swept_tube(
				head_node,
				[
					Vector3(s_f * 0.36, 0.10, 0.22),
					Vector3(s_f * 0.405, -0.05, 0.22),
					Vector3(s_f * 0.385, -0.20, 0.20),
					Vector3(s_f * 0.345, -0.29, 0.18),
				],
				[0.064, 0.056, 0.036, 0.010],
				hair, 12, true
			)

			# Delicate arched eyebrows
			_swept_tube(
				head_node,
				[
					Vector3(s_f * 0.105, 0.132, 0.402),
					Vector3(s_f * 0.172, 0.145, 0.405),
					Vector3(s_f * 0.238, 0.128, 0.390),
				],
				[0.011, 0.013, 0.010],
				hair, 8, true
			)

		var tie_mat := _mat(Color(0.66, 0.84, 0.97), 0.72)
		twin_l = _build_twintail(head_node, -1.0, hair, tie_mat)
		twin_r = _build_twintail(head_node, 1.0, hair, tie_mat)
		_build_sculpted_glasses(head_node, false)


func update_anim(is_walking: bool, is_airborne: bool, delta: float) -> void:
	if is_pelican_trapped:
		walk_time += delta * 15.0
		arm_l.rotation.x = -2.55 + sin(walk_time) * 0.45
		arm_l.rotation.z = -0.35 + cos(walk_time * 1.3) * 0.25
		arm_r.rotation.x = -2.65 - sin(walk_time) * 0.55
		arm_r.rotation.z = 0.45 + sin(walk_time * 1.4) * 0.30
		head_node.rotation.y = sin(walk_time * 0.65) * 0.32
		head_node.rotation.z = sin(walk_time * 0.9) * 0.14
		if twin_l and twin_r:
			twin_l.rotation.z = 0.35 + sin(walk_time * 1.1) * 0.24
			twin_r.rotation.z = -0.35 - sin(walk_time * 1.1) * 0.24
		return

	if is_falling_pose:
		walk_time += delta * 13.5
		if stun_time > 0.0:
			stun_time = maxf(0.0, stun_time - delta)
			# Dizzy flat starfish cartwheel on the rushing water!
			body_pivot.rotation.z += delta * 15.5
			body_pivot.rotation.x = sin(walk_time * 1.5) * 0.24
			body_pivot.rotation.y = cos(walk_time * 1.3) * 0.28
			arm_l.rotation.x = -2.2 + sin(walk_time * 2.2) * 0.65
			arm_r.rotation.x = -2.2 - sin(walk_time * 2.2) * 0.65
			arm_l.rotation.z = -1.05
			arm_r.rotation.z = 1.05
			leg_l.rotation.x = sin(walk_time * 2.0) * 0.55
			leg_r.rotation.x = -sin(walk_time * 2.0) * 0.55
		else:
			# Belly-down prone water-slide pose (head forward down waterfall, belly on water, back toward camera!)
			var dive_t := (fall_dive_amount + 1.0) * 0.5
			# Slight chest-up arch when braking, flat aerodynamic tuck when diving
			var target_arch := lerpf(-0.22, 0.14, dive_t)
			# Bank roll around lengthwise body axis (+Y) & gentle nose steer around dorsal axis (+Z)
			var target_bank_y := -fall_bank_amount * 0.42
			var target_steer_z := -fall_bank_amount * 0.24
			body_pivot.rotation.x = lerpf(body_pivot.rotation.x, target_arch, minf(1.0, delta * 10.0))
			body_pivot.rotation.y = lerp_angle(body_pivot.rotation.y, target_bank_y, minf(1.0, delta * 10.0))
			body_pivot.rotation.z = lerp_angle(body_pivot.rotation.z, target_steer_z, minf(1.0, delta * 10.0))
			# Prone Superman/penguin arms: stretched forward-out when gliding/braking, swept sleekly back when diving!
			var arm_spread := lerpf(1.15, 0.24, dive_t)
			var arm_pitch := lerpf(-2.45, 0.35, dive_t)
			arm_l.rotation.x = lerpf(arm_l.rotation.x, arm_pitch + sin(walk_time) * 0.12, minf(1.0, delta * 12.0))
			arm_r.rotation.x = lerpf(arm_r.rotation.x, arm_pitch - sin(walk_time) * 0.12, minf(1.0, delta * 12.0))
			arm_l.rotation.z = lerpf(arm_l.rotation.z, -arm_spread, minf(1.0, delta * 12.0))
			arm_r.rotation.z = lerpf(arm_r.rotation.z, arm_spread, minf(1.0, delta * 12.0))
			# Playful flutter-kicking legs trailing behind in the waterfall!
			var kick_amp := lerpf(0.28, 0.16, dive_t)
			leg_l.rotation.x = -0.15 + sin(walk_time * 1.4) * kick_amp
			leg_r.rotation.x = -0.15 - sin(walk_time * 1.4) * kick_amp
			# Lift head backward (-X) so character looks forward down the waterfall toward the Pelican!
			head_node.rotation.x = lerpf(head_node.rotation.x, lerpf(-0.72, -0.48, dive_t), minf(1.0, delta * 10.0))
			head_node.rotation.y = lerp_angle(head_node.rotation.y, fall_bank_amount * 0.22, minf(1.0, delta * 8.0))
			head_node.rotation.z = 0.0
		if twin_l and twin_r:
			# Hair twintails stream back along the water rushing past!
			twin_l.rotation.z = 0.48 + sin(walk_time * 1.4) * 0.16
			twin_r.rotation.z = -0.48 - sin(walk_time * 1.4) * 0.16
		return

	# Reset head X pitch when returning to normal standing/walking animations
	if head_node:
		head_node.rotation.x = move_toward(head_node.rotation.x, 0.0, delta * 10.0)

	if celebrate_time > 0.0:
		celebrate_time = maxf(0.0, celebrate_time - delta)
		walk_time += delta * 12.0
		var hop := absf(sin(walk_time))
		body_pivot.position.y = (-0.30 if is_sitting else 0.0) + hop * 0.22
		arm_l.rotation.x = -2.35 + sin(walk_time) * 0.32
		arm_r.rotation.x = -2.35 - sin(walk_time) * 0.32
		arm_l.rotation.z = -0.18
		arm_r.rotation.z = 0.18
		head_node.rotation.y = lerp_angle(head_node.rotation.y, head_target_yaw, min(1.0, delta * 10.0))
		return

	if is_sitting:
		walk_time += delta * 2.2
		leg_l.rotation.x = -1.38
		leg_r.rotation.x = -1.38
		if angry_time > 0.0:
			angry_time = maxf(0.0, angry_time - delta)
			var ang_p := 1.0 - (angry_time / 0.48)
			var hop := absf(sin(ang_p * TAU))
			body_pivot.position.y = -0.30 + hop * 0.24
			arm_l.rotation.x = -0.75 + sin(ang_p * 18.0) * 0.45
			arm_r.rotation.x = -0.75 - sin(ang_p * 18.0) * 0.45
			head_node.rotation.z = sin(ang_p * 24.0) * 0.14
		else:
			arm_l.rotation.x = -0.22 + sin(walk_time) * 0.04
			arm_r.rotation.x = -0.62 if held_milktea != null else (-0.22 - sin(walk_time) * 0.04)
			body_pivot.position.y = -0.30
			head_node.rotation.z = move_toward(head_node.rotation.z, 0.0, delta * 8.0)
		head_node.rotation.y = lerp_angle(head_node.rotation.y, head_target_yaw, min(1.0, delta * 10.0))
		return

	if attack_time > 0.0:
		attack_time = maxf(0.0, attack_time - delta)
		var atk_t := 1.0 - (attack_time / 0.26)
		var swing := sin(atk_t * PI)
		arm_r.rotation.x = -1.85 * swing
		arm_l.rotation.x = 0.45 * swing
		body_pivot.rotation.x = 0.16 * swing
		return
	body_pivot.rotation.x = move_toward(body_pivot.rotation.x, 0.0, delta * 10.0)

	if is_airborne:
		leg_l.rotation.x = 0.52
		leg_r.rotation.x = -0.42
		arm_l.rotation.x = -0.88
		arm_r.rotation.x = -0.88
		arm_l.rotation.z = -0.22
		arm_r.rotation.z = 0.22
		body_pivot.position.y = 0.0
		return

	if is_walking:
		walk_time += delta * 11.5
		var s := sin(walk_time)
		leg_l.rotation.x = s * 0.64
		leg_r.rotation.x = -s * 0.64
		arm_l.rotation.x = -s * 0.54
		arm_r.rotation.x = -0.62 if held_milktea != null else (s * 0.54)
		arm_l.rotation.z = move_toward(arm_l.rotation.z, 0.0, delta * 8.0)
		arm_r.rotation.z = move_toward(arm_r.rotation.z, 0.0, delta * 8.0)
		body_pivot.position.y = abs(cos(walk_time)) * 0.08
		head_node.rotation.z = sin(walk_time) * 0.038
		if twin_l and twin_r:
			twin_l.rotation.z = 0.06 + sin(walk_time) * 0.14
			twin_r.rotation.z = -0.06 - sin(walk_time) * 0.14
	else:
		walk_time += delta * 2.5
		leg_l.rotation.x = move_toward(leg_l.rotation.x, 0.0, delta * 8.0)
		leg_r.rotation.x = move_toward(leg_r.rotation.x, 0.0, delta * 8.0)
		if wave_side == -1:
			arm_l.rotation.x = -2.42
			arm_l.rotation.z = -0.28 + sin(walk_time * 2.6) * 0.30
			arm_r.rotation.x = move_toward(arm_r.rotation.x, 0.0, delta * 8.0)
			arm_r.rotation.z = move_toward(arm_r.rotation.z, 0.0, delta * 8.0)
		elif wave_side == 1:
			arm_r.rotation.x = -2.42
			arm_r.rotation.z = 0.28 + sin(walk_time * 2.6) * 0.30
			arm_l.rotation.x = move_toward(arm_l.rotation.x, 0.0, delta * 8.0)
			arm_l.rotation.z = move_toward(arm_l.rotation.z, 0.0, delta * 8.0)
		else:
			arm_l.rotation.x = move_toward(arm_l.rotation.x, 0.0, delta * 8.0)
			arm_r.rotation.x = -0.62 if held_milktea != null else move_toward(arm_r.rotation.x, 0.0, delta * 8.0)
			arm_l.rotation.z = move_toward(arm_l.rotation.z, 0.0, delta * 8.0)
			arm_r.rotation.z = move_toward(arm_r.rotation.z, 0.0, delta * 8.0)
		body_pivot.position.y = sin(walk_time) * 0.025
		head_node.rotation.z = 0.0
		if twin_l and twin_r:
			twin_l.rotation.z = 0.04 + sin(walk_time) * 0.04
			twin_r.rotation.z = -0.04 - sin(walk_time) * 0.04
