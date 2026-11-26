extends Node3D
class_name Keepsake3D

var visual_pivot: Node3D
var t_acc: float = 0.0


static func create(kind: String) -> Keepsake3D:
	var k := Keepsake3D.new()
	k._build(kind)
	return k


func _mat(col: Color, rough: float = 0.45, metal: float = 0.0, emit_col: Color = Color.BLACK, emit_e: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.roughness = rough
	m.metallic = metal
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit_e > 0.0:
		m.emission_enabled = true
		m.emission = emit_col
		m.emission_energy_multiplier = emit_e
	return m


func _sphere(parent: Node3D, pos: Vector3, scale_v: Vector3, mat: Material, seg: int = 14, rings: int = 10) -> MeshInstance3D:
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


func _build(kind: String) -> void:
	visual_pivot = Node3D.new()
	visual_pivot.position = Vector3(0, 0.72, 0)
	add_child(visual_pivot)

	match kind:
		"star_pendant":
			_build_star_pendant()
		"strawberry_clip":
			_build_strawberry_clip()
		"earbuds_case":
			_build_earbuds_case()
		"milk_tea":
			_build_milk_tea()
		_:
			_build_glasses_case()

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.90, 0.55)
	light.light_energy = 0.75
	light.omni_range = 3.2
	light.position = Vector3(0, 0.75, 0)
	add_child(light)


func _build_star_pendant() -> void:
	var gold := _mat(Color(1.0, 0.84, 0.24), 0.22, 0.70, Color(1.0, 0.80, 0.20), 0.55)
	var cord := _mat(Color(0.24, 0.18, 0.16), 0.85)

	# 3D Extruded 5-Pointed Star
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cf := Vector3(0, 0, 0.09)
	var cb := Vector3(0, 0, -0.09)
	var ring: Array[Vector3] = []
	for i in range(10):
		var a := PI * 0.5 + float(i) * PI / 5.0
		var r := 0.36 if i % 2 == 0 else 0.16
		ring.append(Vector3(cos(a) * r, sin(a) * r, 0))
	for i in range(10):
		var n := (i + 1) % 10
		st.add_vertex(cf); st.add_vertex(ring[i]); st.add_vertex(ring[n])
		st.add_vertex(cb); st.add_vertex(ring[n]); st.add_vertex(ring[i])
	st.generate_normals()
	var star := MeshInstance3D.new()
	star.mesh = st.commit()
	star.material_override = gold
	visual_pivot.add_child(star)

	# Gold top jump ring + necklace cord loop
	var bail := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.045
	tm.outer_radius = 0.075
	bail.mesh = tm
	bail.material_override = gold
	bail.position = Vector3(0, 0.35, 0)
	bail.rotation_degrees = Vector3(90, 0, 0)
	visual_pivot.add_child(bail)

	var neck_loop := MeshInstance3D.new()
	var lm := TorusMesh.new()
	lm.inner_radius = 0.18
	lm.outer_radius = 0.205
	neck_loop.mesh = lm
	neck_loop.material_override = cord
	neck_loop.position = Vector3(0, 0.56, 0)
	neck_loop.rotation_degrees = Vector3(90, 0, 0)
	neck_loop.scale = Vector3(0.85, 1.0, 1.25)
	visual_pivot.add_child(neck_loop)


func _build_strawberry_clip() -> void:
	var berry_red := _mat(Color(0.96, 0.17, 0.27), 0.20, 0.05, Color(0.92, 0.14, 0.22), 0.20)
	var leaf_green := _mat(Color(0.24, 0.76, 0.32), 0.42, 0.0, Color(0.18, 0.58, 0.24), 0.12)
	var seed_gold := _mat(Color(1.0, 0.91, 0.48), 0.28, 0.0, Color(1.0, 0.86, 0.36), 0.35)
	var clip_pink := _mat(Color(1.0, 0.78, 0.86), 0.20, 0.22, Color(1.0, 0.74, 0.82), 0.14)
	var pearl_mat := _mat(Color(1.0, 0.98, 0.96), 0.12, 0.15, Color(1.0, 0.96, 0.90), 0.22)
	var metal := _mat(Color(0.90, 0.90, 0.94), 0.16, 0.88)
	var flower_center := _mat(Color(1.0, 0.84, 0.22), 0.30, 0.0, Color(1.0, 0.80, 0.18), 0.35)

	var group := Node3D.new()
	group.rotation_degrees = Vector3(0, 0, -14)
	visual_pivot.add_child(group)

	# 1. Rounded glossy pastel-pink BB Hairclip bar (curved pill silhouette + metal clasp)
	var bar_seg := MeshInstance3D.new()
	var bcm := CapsuleMesh.new()
	bcm.radius = 0.068
	bcm.height = 0.86
	bcm.radial_segments = 14
	bcm.rings = 6
	bar_seg.mesh = bcm
	bar_seg.material_override = clip_pink
	bar_seg.rotation_degrees = Vector3(0, 0, 90)
	bar_seg.scale = Vector3(1.0, 1.0, 0.45)
	bar_seg.position = Vector3(0.08, -0.02, -0.10)
	group.add_child(bar_seg)

	# Underside sleek metallic clip bar + tiny hinge
	var clasp := MeshInstance3D.new()
	var clm := CapsuleMesh.new()
	clm.radius = 0.032
	clm.height = 0.78
	clm.radial_segments = 10
	clasp.mesh = clm
	clasp.material_override = metal
	clasp.rotation_degrees = Vector3(0, 0, 90)
	clasp.scale = Vector3(1.0, 1.0, 0.45)
	clasp.position = Vector3(0.08, -0.02, -0.145)
	group.add_child(clasp)

	# 3 cute lustrous mini pearls decorating the right side of the hairpin bar!
	for px in [0.23, 0.33, 0.42]:
		var sz := 0.080 if px < 0.36 else 0.064
		_sphere(group, Vector3(px, -0.015, -0.055), Vector3(sz, sz, sz), pearl_mat, 12, 8)

	# 2. Smooth Lathe-Sculpted Heart-Tapered 3D Strawberry perched cleanly IN FRONT of the clip!
	var berry_holder := Node3D.new()
	berry_holder.position = Vector3(-0.15, 0.02, 0.085)
	berry_holder.rotation_degrees = Vector3(0, 0, 10)
	group.add_child(berry_holder)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 16
	var segs := 22
	var berry_h := 0.44
	var ring_verts: Array = []

	for r_idx in range(rings + 1):
		var v := float(r_idx) / float(rings)  # 0.0 = rounded bottom tip, 1.0 = top calyx center
		var y := -berry_h * 0.52 + v * berry_h
		var rad := _strawberry_radius(v)
		var row: Array[Vector3] = []
		for s_idx in range(segs):
			var ang := float(s_idx) / float(segs) * TAU
			row.append(Vector3(cos(ang) * rad, y, sin(ang) * rad * 0.86))
		ring_verts.append(row)

	for r_idx in range(rings):
		var row0: Array = ring_verts[r_idx]
		var row1: Array = ring_verts[r_idx + 1]
		for s_idx in range(segs):
			var ns := (s_idx + 1) % segs
			var a: Vector3 = row0[s_idx]
			var b: Vector3 = row0[ns]
			var c: Vector3 = row1[ns]
			var d: Vector3 = row1[s_idx]
			# Outward-facing CCW winding!
			st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
			st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)

	st.generate_normals()
	var berry_mesh := MeshInstance3D.new()
	berry_mesh.mesh = st.commit()
	berry_mesh.material_override = berry_red
	berry_holder.add_child(berry_mesh)

	# 3. 20 Golden Teardrop Strawberry Seeds hugging the exact surface (front & back!)
	for row_cfg in [
		[0.24, 5, 0.15],
		[0.48, 7, 0.45],
		[0.70, 8, 0.22],
	]:
		var vv: float = row_cfg[0]
		var cnt: int = row_cfg[1]
		var off: float = row_cfg[2]
		var yy := -berry_h * 0.52 + vv * berry_h
		var rr := _strawberry_radius(vv) + 0.005
		for i in range(cnt):
			var ang := float(i) / float(cnt) * TAU + off
			var spos := Vector3(cos(ang) * rr, yy, sin(ang) * rr * 0.86)
			var sd := _sphere(berry_holder, spos, Vector3(0.022, 0.036, 0.018), seed_gold, 8, 6)
			sd.rotation.y = -ang + PI * 0.5

	# 4. Sculpted 6-Leaf Curved Emerald Calyx Crown + Curved Stem
	for i in range(6):
		var ang := float(i) / 6.0 * TAU + 0.15
		var leaf := _make_curved_leaf_mesh()
		var lm := MeshInstance3D.new()
		lm.mesh = leaf
		lm.material_override = leaf_green
		lm.position = Vector3(0, berry_h * 0.46, 0)
		lm.rotation = Vector3(0.0, ang, 0.0)
		berry_holder.add_child(lm)

	var stem := MeshInstance3D.new()
	var stm := CylinderMesh.new()
	stm.top_radius = 0.018; stm.bottom_radius = 0.026; stm.height = 0.11; stm.radial_segments = 8
	stem.mesh = stm
	stem.material_override = leaf_green
	stem.position = Vector3(0.015, berry_h * 0.56, 0)
	stem.rotation_degrees = Vector3(0, 0, -16)
	berry_holder.add_child(stem)

	# 5. Tiny White 5-Petal Strawberry Blossom tucked beside the berry on the clip!
	var blossom := Node3D.new()
	blossom.position = Vector3(0.11, 0.06, -0.02)
	blossom.rotation_degrees = Vector3(8, -10, 0)
	group.add_child(blossom)
	for i in range(5):
		var a := float(i) / 5.0 * TAU
		_sphere(blossom, Vector3(cos(a) * 0.052, sin(a) * 0.052, 0.0), Vector3(0.070, 0.070, 0.036), pearl_mat, 10, 6)
	_sphere(blossom, Vector3(0, 0, 0.018), Vector3(0.050, 0.050, 0.040), flower_center, 10, 6)


func _strawberry_radius(v: float) -> float:
	# Smooth cute cartoon strawberry silhouette: rounded bottom tip -> plump cheeks -> broad rounded shoulder!
	var vs: Array[float] = [0.00, 0.07, 0.22, 0.45, 0.68, 0.84, 0.94, 1.00]
	var rs: Array[float] = [0.002, 0.080, 0.138, 0.195, 0.224, 0.205, 0.132, 0.002]
	if v <= 0.0:
		return 0.002
	if v >= 1.0:
		return 0.002
	for i in range(vs.size() - 1):
		if v >= vs[i] and v <= vs[i + 1]:
			var u := (v - vs[i]) / (vs[i + 1] - vs[i])
			var smooth_u := 0.5 - 0.5 * cos(u * PI)
			return lerpf(rs[i], rs[i + 1], smooth_u)
	return 0.002


func _make_curved_leaf_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p0 := Vector3(0.0, 0.025, 0.0)
	var p1l := Vector3(0.09, 0.040, -0.048)
	var p1r := Vector3(0.09, 0.040, 0.048)
	var p1c := Vector3(0.09, 0.055, 0.0)
	var tip := Vector3(0.21, -0.018, 0.0)

	# Two arched facets creating a sculpted 3D curved leaf with central rib!
	st.add_vertex(p0); st.add_vertex(p1c); st.add_vertex(p1l)
	st.add_vertex(p0); st.add_vertex(p1r); st.add_vertex(p1c)
	st.add_vertex(p1l); st.add_vertex(p1c); st.add_vertex(tip)
	st.add_vertex(p1c); st.add_vertex(p1r); st.add_vertex(tip)
	# Underside
	st.add_vertex(p0); st.add_vertex(p1l); st.add_vertex(p1c)
	st.add_vertex(p0); st.add_vertex(p1c); st.add_vertex(p1r)
	st.add_vertex(p1l); st.add_vertex(tip); st.add_vertex(p1c)
	st.add_vertex(p1c); st.add_vertex(tip); st.add_vertex(p1r)

	st.generate_normals()
	return st.commit()


func _build_earbuds_case() -> void:
	var shell := _mat(Color(0.95, 0.96, 0.98), 0.22, 0.05, Color(0.9, 0.92, 0.98), 0.18)
	var seam := _mat(Color(0.65, 0.68, 0.75), 0.5)
	var led := _mat(Color(0.28, 0.98, 0.48), 0.2, 0.0, Color(0.25, 1.0, 0.45), 1.4)

	_sphere(visual_pivot, Vector3.ZERO, Vector3(0.46, 0.50, 0.26), shell, 18, 12)
	# Curved oval lid seam hugging the pill body cleanly
	_sphere(visual_pivot, Vector3(0, 0.07, 0), Vector3(0.452, 0.032, 0.258), seam, 18, 8)
	_sphere(visual_pivot, Vector3(0, -0.01, 0.13), Vector3(0.045, 0.045, 0.025), led, 10, 6)


func _build_glasses_case() -> void:
	var case_mat := _mat(Color(0.70, 0.88, 0.98), 0.22, 0.1, Color(0.6, 0.85, 1.0), 0.22, 0.88)
	var rim := _mat(Color(0.42, 0.52, 0.65), 0.4, 0.4)
	var icon_g := _mat(Color(0.96, 0.98, 1.0), 0.2)

	_sphere(visual_pivot, Vector3.ZERO, Vector3(0.68, 0.28, 0.34), case_mat, 18, 12)
	_sphere(visual_pivot, Vector3.ZERO, Vector3(0.688, 0.035, 0.348), rim, 18, 8)
	# Mini glasses emblem on top of the case
	for sx in [-0.08, 0.08]:
		_box(visual_pivot, Vector3(sx, 0.14, 0.0), Vector3(0.11, 0.02, 0.08), icon_g)
	_box(visual_pivot, Vector3(0, 0.14, 0.0), Vector3(0.06, 0.02, 0.02), icon_g)


func _build_milk_tea() -> void:
	var cup_clear := _mat(Color(0.95, 0.96, 0.98), 0.15, 0.05, Color.BLACK, 0.0, 0.48)
	var tea := _mat(Color(0.86, 0.68, 0.46), 0.45, 0.0, Color(0.85, 0.66, 0.40), 0.22)
	var lid := _mat(Color(1.0, 0.88, 0.92), 0.30)
	var straw := _mat(Color(0.98, 0.42, 0.56), 0.35)
	var boba := _mat(Color(0.14, 0.10, 0.10), 0.25)

	# Creamy milk tea liquid core
	var liquid := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.21
	lm.bottom_radius = 0.15
	lm.height = 0.44
	lm.radial_segments = 16
	liquid.mesh = lm
	liquid.material_override = tea
	liquid.position = Vector3(0, -0.02, 0)
	visual_pivot.add_child(liquid)

	# Tapioca boba pearls at the bottom of the cup!
	for i in range(6):
		var a := float(i) / 6.0 * TAU
		_sphere(visual_pivot, Vector3(cos(a) * 0.09, -0.19, sin(a) * 0.09), Vector3(0.07, 0.07, 0.07), boba, 10, 6)

	# Outer clear cup sleeve
	var cup := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.23
	cm.bottom_radius = 0.165
	cm.height = 0.50
	cm.radial_segments = 18
	cup.mesh = cm
	cup.material_override = cup_clear
	cup.position = Vector3(0, 0.0, 0)
	visual_pivot.add_child(cup)

	# Domed lid + rim
	_sphere(visual_pivot, Vector3(0, 0.24, 0), Vector3(0.45, 0.16, 0.45), lid, 16, 8)

	# Thick angled boba straw!
	var st_m := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.032
	sm.bottom_radius = 0.032
	sm.height = 0.42
	sm.radial_segments = 10
	st_m.mesh = sm
	st_m.material_override = straw
	st_m.position = Vector3(0.05, 0.34, 0)
	st_m.rotation_degrees = Vector3(0, 0, -14)
	visual_pivot.add_child(st_m)


func _process(delta: float) -> void:
	t_acc += delta
	if visual_pivot:
		visual_pivot.rotation.y += delta * 1.9
		visual_pivot.position.y = 0.68 + sin(t_acc * 3.0) * 0.11
