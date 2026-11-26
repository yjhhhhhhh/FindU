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
		"swan_necklace":
			_build_swan_necklace()
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
	light.light_color = Color(1.0, 0.74, 0.82) if kind == "swan_necklace" else Color(1.0, 0.90, 0.55)
	light.light_energy = 0.82 if kind == "swan_necklace" else 0.75
	light.omni_range = 3.2
	light.position = Vector3(0, 0.75, 0)
	add_child(light)


func _build_swept_wire(parent: Node3D, pts: Array[Vector3], rads: Array[float], mat: Material, sides: int = 10) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[Array] = []
	for i in range(pts.size()):
		var tang: Vector3
		if i == 0:
			tang = (pts[1] - pts[0]).normalized()
		elif i == pts.size() - 1:
			tang = (pts[i] - pts[i - 1]).normalized()
		else:
			tang = (pts[i + 1] - pts[i - 1]).normalized()
		var nrm := Vector3(0, 0, 1)
		if absf(tang.dot(nrm)) > 0.95:
			nrm = Vector3(1, 0, 0)
		var b1 := tang.cross(nrm).normalized()
		var b2 := tang.cross(b1).normalized()
		var r: float = rads[i]
		var ring: Array[Vector3] = []
		for s in range(sides):
			var a := float(s) / float(sides) * TAU
			ring.append(pts[i] + (b1 * cos(a) + b2 * sin(a)) * r)
		rings.append(ring)

	for i in range(rings.size() - 1):
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


func _catmull_rom_subdivide(pts: Array[Vector3], rads: Array[float], subdiv: int = 4) -> Dictionary:
	var out_pts: Array[Vector3] = []
	var out_rads: Array[float] = []
	var n := pts.size()
	if n < 2:
		return {"pts": pts, "rads": rads}
	for i in range(n - 1):
		var p0: Vector3 = pts[maxi(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(i + 2, n - 1)]
		var r1: float = rads[i]
		var r2: float = rads[i + 1]
		var steps := subdiv if i < n - 2 else subdiv + 1
		for s in range(steps):
			var t := float(s) / float(subdiv)
			var t2 := t * t
			var t3 := t2 * t
			var p := 0.5 * (
				(2.0 * p1)
				+ (-p0 + p2) * t
				+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
			)
			out_pts.append(p)
			out_rads.append(lerpf(r1, r2, t))
	return {"pts": out_pts, "rads": out_rads}


func _sample_curve_by_spacing(pts: Array[Vector3], rads: Array[float], spacing: float, start_pad: float = 0.0, end_pad: float = 0.0) -> Array[Dictionary]:
	var cum: Array[float] = [0.0]
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
	var total: float = cum[cum.size() - 1]
	var usable := maxf(total - start_pad - end_pad, 0.001)
	var count := maxi(int(round(usable / spacing)), 1)
	var samples: Array[Dictionary] = []
	for k in range(count + 1):
		var target_d := start_pad + usable * (float(k) / float(count))
		for i in range(1, pts.size()):
			if cum[i] >= target_d or i == pts.size() - 1:
				var seg_len := maxf(cum[i] - cum[i - 1], 0.0001)
				var u := clampf((target_d - cum[i - 1]) / seg_len, 0.0, 1.0)
				samples.append({
					"pos": pts[i - 1].lerp(pts[i], u),
					"rad": lerpf(rads[i - 1], rads[i], u),
					"u": float(k) / float(count),
				})
				break
	return samples


func _build_swan_necklace() -> void:
	## Rose-gold pavé diamond & faceted peach-pink crystal Swan Necklace pendant!
	var rose_gold := _mat(Color(0.96, 0.72, 0.62), 0.16, 0.88, Color(0.90, 0.62, 0.52), 0.18)
	var pave_diamond := _mat(Color(0.97, 0.96, 0.98), 0.04, 0.32, Color(0.95, 0.96, 1.0), 0.32)
	var pink_crystal := _mat(Color(0.99, 0.54, 0.52), 0.05, 0.16, Color(1.0, 0.48, 0.46), 0.45)
	var pink_highlight := _mat(Color(1.0, 0.76, 0.74), 0.03, 0.10, Color(1.0, 0.68, 0.66), 0.55)

	var pendant := Node3D.new()
	pendant.position = Vector3(0.0, -0.08, 0.0)
	pendant.scale = Vector3(1.16, 1.16, 1.16)
	visual_pivot.add_child(pendant)

	# 1. Silky Catmull-Rom S-curved swan neck, head, breast & sweeping wing outer contour
	var neck_ctrl: Array[Vector3] = [
		Vector3(-0.185, 0.185, 0.0),  # swan head crown
		Vector3(-0.135, 0.240, 0.0),  # upper neck arch
		Vector3(-0.060, 0.238, 0.0),  # top-right neck bend
		Vector3(-0.032, 0.180, 0.0),  # inner S-curve back
		Vector3(-0.080, 0.105, 0.0),  # mid graceful neck
		Vector3(-0.165, 0.025, 0.0),  # lower neck into chest
		Vector3(-0.222, -0.068, 0.0), # plump chest curve
		Vector3(-0.210, -0.155, 0.0), # lower chest bend
		Vector3(-0.125, -0.212, 0.0), # front belly
		Vector3(0.015, -0.218, 0.0),  # flat-curved belly base
		Vector3(0.145, -0.175, 0.0),  # lower wing sweep
		Vector3(0.225, -0.060, 0.0),  # mid outer wing curve
		Vector3(0.268, 0.095, 0.0),   # upper outer wing
		Vector3(0.285, 0.238, 0.0),   # pointed wingtip
	]
	var neck_ctrl_rads: Array[float] = [
		0.039, 0.034, 0.030, 0.027, 0.028, 0.033, 0.041, 0.044, 0.042, 0.038, 0.037, 0.039, 0.040, 0.028
	]
	var smooth_neck := _catmull_rom_subdivide(neck_ctrl, neck_ctrl_rads, 5)
	var neck_pts: Array[Vector3] = smooth_neck["pts"]
	var neck_rads: Array[float] = smooth_neck["rads"]
	_build_swept_wire(pendant, neck_pts, neck_rads, rose_gold, 12)

	# Smooth inner diagonal wing arch framing the centerpiece peach-pink crystal
	var wing_ctrl: Array[Vector3] = [
		Vector3(-0.125, -0.175, 0.0),
		Vector3(-0.055, -0.060, 0.0),
		Vector3(0.045, 0.042, 0.0),
		Vector3(0.165, 0.140, 0.0),
		Vector3(0.282, 0.236, 0.0),
	]
	var wing_ctrl_rads: Array[float] = [0.035, 0.031, 0.029, 0.031, 0.026]
	var smooth_wing := _catmull_rom_subdivide(wing_ctrl, wing_ctrl_rads, 5)
	var wing_pts: Array[Vector3] = smooth_wing["pts"]
	var wing_rads: Array[float] = smooth_wing["rads"]
	_build_swept_wire(pendant, wing_pts, wing_rads, rose_gold, 10)

	# Delicate tapered rose-gold swan beak pointing down-left from the head
	var beak := MeshInstance3D.new()
	var bkm := CylinderMesh.new()
	bkm.top_radius = 0.004
	bkm.bottom_radius = 0.022
	bkm.height = 0.105
	bkm.radial_segments = 10
	beak.mesh = bkm
	beak.material_override = rose_gold
	beak.position = Vector3(-0.228, 0.128, 0.0)
	beak.rotation_degrees = Vector3(0.0, 0.0, 146.0)
	pendant.add_child(beak)

	# 2. Densely packed pavé micro-diamonds evenly spaced by arc-length along both frames!
	var neck_gems := _sample_curve_by_spacing(neck_pts, neck_rads, 0.048, 0.0, 0.015)
	for idx in range(neck_gems.size()):
		var g: Dictionary = neck_gems[idx]
		var gp: Vector3 = g["pos"]
		var gr: float = float(g["rad"])
		var gsz := 0.058 if idx == 0 else clampf(gr * 1.24, 0.038, 0.050)
		for z_s in [-1.0, 1.0]:
			var zs: float = float(z_s)
			_sphere(pendant, gp + Vector3(0.0, 0.0, zs * (gr * 0.96)), Vector3(gsz, gsz, gsz * 0.62), pave_diamond, 8, 4)

	var wing_gems := _sample_curve_by_spacing(wing_pts, wing_rads, 0.048, 0.048, 0.048)
	for g in wing_gems:
		var gp: Vector3 = g["pos"]
		var gr: float = float(g["rad"])
		var gsz := clampf(gr * 1.22, 0.036, 0.045)
		for z_s in [-1.0, 1.0]:
			var zs: float = float(z_s)
			_sphere(pendant, gp + Vector3(0.0, 0.0, zs * (gr * 0.96)), Vector3(gsz, gsz, gsz * 0.62), pave_diamond, 8, 4)

	# Extra pavé diamonds filling the plump swan breast & inner wingtip corner
	for extra_cfg in [
		[Vector3(-0.158, -0.102, 0.0), 0.044],
		[Vector3(-0.145, -0.150, 0.0), 0.044],
		[Vector3(-0.105, -0.142, 0.0), 0.040],
		[Vector3(0.242, 0.165, 0.0), 0.042],
	]:
		var ep: Vector3 = extra_cfg[0]
		var esz: float = float(extra_cfg[1])
		for z_s in [-1.0, 1.0]:
			var zs: float = float(z_s)
			_sphere(pendant, ep + Vector3(0.0, 0.0, zs * 0.035), Vector3(esz, esz, esz * 0.62), pave_diamond, 8, 4)

	# 3. Centerpiece Faceted Peach-Pink Curved Marquise / Almond Crystal inside the open wing!
	var gem_node := Node3D.new()
	gem_node.position = Vector3(0.088, -0.026, 0.0)
	gem_node.rotation_degrees = Vector3(0.0, 0.0, -42.0)
	pendant.add_child(gem_node)

	# Multi-facet brilliant marquise cut (outer girdle + inner raised table for crisp jewelry reflections!)
	var g_outer: Array[Vector3] = [
		Vector3(0.000, 0.195, 0.0),     # upper sharp tip toward wingtip
		Vector3(0.056, 0.095, 0.0),
		Vector3(0.078, -0.015, 0.0),    # fuller right belly matching wing curve
		Vector3(0.056, -0.112, 0.0),
		Vector3(0.000, -0.188, 0.0),    # lower sharp tip toward breast
		Vector3(-0.044, -0.105, 0.0),
		Vector3(-0.058, -0.005, 0.0),   # sleeker left edge hugging inner wing arch
		Vector3(-0.044, 0.098, 0.0),
	]
	var g_table_f: Array[Vector3] = []
	var g_table_b: Array[Vector3] = []
	for v in g_outer:
		g_table_f.append(Vector3(v.x * 0.54, v.y * 0.56, 0.052))
		g_table_b.append(Vector3(v.x * 0.54, v.y * 0.56, -0.052))

	var gst := SurfaceTool.new()
	gst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cf := Vector3(0.004, -0.005, 0.060)
	var cb := Vector3(0.004, -0.005, -0.060)
	var gn := g_outer.size()
	for i in range(gn):
		var ni := (i + 1) % gn
		# Front crown bevel facets + center table facets
		gst.add_vertex(g_outer[i]); gst.add_vertex(g_outer[ni]); gst.add_vertex(g_table_f[ni])
		gst.add_vertex(g_outer[i]); gst.add_vertex(g_table_f[ni]); gst.add_vertex(g_table_f[i])
		gst.add_vertex(cf); gst.add_vertex(g_table_f[i]); gst.add_vertex(g_table_f[ni])
		# Back pavilion bevel facets + back culet
		gst.add_vertex(g_outer[ni]); gst.add_vertex(g_outer[i]); gst.add_vertex(g_table_b[i])
		gst.add_vertex(g_outer[ni]); gst.add_vertex(g_table_b[i]); gst.add_vertex(g_table_b[ni])
		gst.add_vertex(cb); gst.add_vertex(g_table_b[ni]); gst.add_vertex(g_table_b[i])
	gst.generate_normals()
	var gem_mi := MeshInstance3D.new()
	gem_mi.mesh = gst.commit()
	gem_mi.material_override = pink_crystal
	gem_node.add_child(gem_mi)

	# Subtle bright peach-pink internal specular shimmer core on front & back table
	for z_s in [-1.0, 1.0]:
		var zs: float = float(z_s)
		_sphere(gem_node, Vector3(0.005, 0.01, zs * 0.044), Vector3(0.052, 0.14, 0.016), pink_highlight, 6, 4)

	# Delicate V-shaped rose-gold chevron prongs hugging both sharp crystal tips!
	for tip_cfg in [
		[Vector3(0.0, 0.196, 0.0), 180.0],
		[Vector3(0.0, -0.190, 0.0), 0.0],
	]:
		var tpos: Vector3 = tip_cfg[0]
		var trot: float = float(tip_cfg[1])
		var prong := MeshInstance3D.new()
		var prm := CylinderMesh.new()
		prm.top_radius = 0.022; prm.bottom_radius = 0.005; prm.height = 0.052; prm.radial_segments = 6
		prong.mesh = prm; prong.material_override = rose_gold
		prong.position = tpos
		prong.rotation_degrees = Vector3(0.0, 0.0, trot)
		prong.scale = Vector3(1.0, 1.0, 1.45)
		gem_node.add_child(prong)

	# 4. Two Rose-Gold Bail Rings & Graceful Continuous Interlocking Rose-Gold Oval Chain Loop!
	var bail_l := Vector3(-0.135, 0.280, 0.0)
	var bail_r := Vector3(0.285, 0.282, 0.0)
	for bpos in [bail_l, bail_r]:
		var b := MeshInstance3D.new()
		var btm := TorusMesh.new()
		btm.inner_radius = 0.022; btm.outer_radius = 0.036; btm.rings = 14; btm.ring_segments = 6
		b.mesh = btm; b.material_override = rose_gold
		b.position = bpos
		b.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		pendant.add_child(b)

	# Smooth continuous teardrop necklace chain arching organically from left bail to right bail
	var chain_ctrl: Array[Vector3] = [
		bail_l + Vector3(-0.005, 0.028, 0.0),
		Vector3(-0.22, 0.50, 0.0),
		Vector3(-0.29, 0.74, 0.0),
		Vector3(-0.18, 0.94, 0.0),
		Vector3(0.075, 1.02, 0.0),
		Vector3(0.33, 0.94, 0.0),
		Vector3(0.44, 0.74, 0.0),
		Vector3(0.37, 0.50, 0.0),
		bail_r + Vector3(0.005, 0.028, 0.0),
	]
	var chain_rads: Array[float] = [0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01]
	var smooth_chain := _catmull_rom_subdivide(chain_ctrl, chain_rads, 8)
	var c_pts: Array[Vector3] = smooth_chain["pts"]
	var link_samples := _sample_curve_by_spacing(c_pts, smooth_chain["rads"], 0.048, 0.012, 0.012)
	var link_mesh := TorusMesh.new()
	link_mesh.inner_radius = 0.013; link_mesh.outer_radius = 0.022; link_mesh.rings = 10; link_mesh.ring_segments = 5
	for k in range(link_samples.size()):
		var p_curr: Vector3 = link_samples[k]["pos"]
		var p_prev: Vector3 = link_samples[maxi(k - 1, 0)]["pos"]
		var p_next: Vector3 = link_samples[mini(k + 1, link_samples.size() - 1)]["pos"]
		var tang := (p_next - p_prev).normalized()
		var ang_z := atan2(tang.y, tang.x) - PI * 0.5
		var lk := MeshInstance3D.new()
		lk.mesh = link_mesh
		lk.material_override = rose_gold
		lk.position = p_curr
		lk.scale = Vector3(0.72, 1.0, 1.38)
		# Alternating orthogonal interlocking oval links aligned cleanly to chain tangent!
		var basis := Basis(Vector3(0, 0, 1), ang_z) * Basis(Vector3(1, 0, 0), PI * 0.5)
		if k % 2 == 1:
			basis = basis * Basis(Vector3(0, 0, 1), PI * 0.5)
		lk.basis = basis.scaled(Vector3(0.72, 1.0, 1.38))
		pendant.add_child(lk)


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
