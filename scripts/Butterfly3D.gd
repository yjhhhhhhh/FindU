extends Node3D
class_name Butterfly3D

var wing_l: Node3D
var wing_r: Node3D
var body_pivot: Node3D
var flap_speed: float = 11.5
var t_acc: float = 0.0
var bob_amp: float = 0.06


static func create(scale_val: float = 1.0, p_flap_speed: float = 11.5) -> Butterfly3D:
	var b := Butterfly3D.new()
	b.scale = Vector3.ONE * scale_val
	b.flap_speed = p_flap_speed
	b._build()
	return b


func _mat(col: Color, rough: float = 0.35, emit_col: Color = Color.BLACK, emit_e: float = 0.0, alpha: float = 1.0, double_sided: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.roughness = rough
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emit_e > 0.0:
		m.emission_enabled = true
		m.emission = emit_col
		m.emission_energy_multiplier = emit_e
	return m


func _make_wing_polygon(pts: Array[Vector3]) -> ArrayMesh:
	# Fan-triangulated organic 3D wing mesh with gentle curvature
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3.ZERO
	for p in pts:
		center += p
	center /= float(pts.size())
	center.y += 0.025  # Gentle graceful upward camber
	for i in range(pts.size()):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % pts.size()]
		st.add_vertex(center)
		st.add_vertex(a)
		st.add_vertex(b)
	st.generate_normals()
	return st.commit()


func _build_one_wing(side: float, fore_mat: Material, hind_mat: Material, inner_mat: Material, dot_mat: Material, trim_mat: Material) -> Node3D:
	var pivot := Node3D.new()

	# Sculpted scalloped Forewing (sweeps gracefully outward & forward along +Z)
	var fore_pts: Array[Vector3] = [
		Vector3(side * 0.02, 0.00, 0.08),
		Vector3(side * 0.14, 0.02, 0.24),
		Vector3(side * 0.30, 0.04, 0.35),
		Vector3(side * 0.46, 0.05, 0.34),
		Vector3(side * 0.54, 0.04, 0.24),
		Vector3(side * 0.52, 0.02, 0.12),
		Vector3(side * 0.42, 0.01, 0.02),
		Vector3(side * 0.26, 0.00, -0.04),
		Vector3(side * 0.04, 0.00, -0.02),
	]
	var fore := MeshInstance3D.new()
	fore.mesh = _make_wing_polygon(fore_pts)
	fore.material_override = fore_mat
	pivot.add_child(fore)

	# Luminous inner teardrop gradient patch on forewing (top & underside)
	var inner_pts: Array[Vector3] = [
		Vector3(side * 0.09, 0.015, 0.07),
		Vector3(side * 0.20, 0.032, 0.21),
		Vector3(side * 0.34, 0.042, 0.24),
		Vector3(side * 0.40, 0.035, 0.15),
		Vector3(side * 0.32, 0.020, 0.05),
		Vector3(side * 0.17, 0.012, 0.01),
	]
	var inner := MeshInstance3D.new()
	inner.mesh = _make_wing_polygon(inner_pts)
	inner.material_override = inner_mat
	pivot.add_child(inner)

	# Delicate dark plum wingtip trim
	var trim_pts: Array[Vector3] = [
		Vector3(side * 0.38, 0.042, 0.32),
		Vector3(side * 0.47, 0.048, 0.33),
		Vector3(side * 0.53, 0.040, 0.24),
		Vector3(side * 0.51, 0.024, 0.15),
		Vector3(side * 0.44, 0.030, 0.22),
	]
	var trim := MeshInstance3D.new()
	trim.mesh = _make_wing_polygon(trim_pts)
	trim.material_override = trim_mat
	pivot.add_child(trim)

	# Sculpted rounded Hindwing with gentle swallowtail curve (sweeps backward along -Z)
	var hind_pts: Array[Vector3] = [
		Vector3(side * 0.03, -0.005, 0.01),
		Vector3(side * 0.24, 0.000, 0.00),
		Vector3(side * 0.36, 0.005, -0.09),
		Vector3(side * 0.35, 0.002, -0.21),
		Vector3(side * 0.25, -0.005, -0.32),
		Vector3(side * 0.15, -0.008, -0.36),
		Vector3(side * 0.08, -0.008, -0.26),
		Vector3(side * 0.03, -0.006, -0.12),
	]
	var hind := MeshInstance3D.new()
	hind.mesh = _make_wing_polygon(hind_pts)
	hind.material_override = hind_mat
	pivot.add_child(hind)

	# Cute pearl-white accent spots on wings
	for spot_cfg in [
		[Vector3(side * 0.44, 0.044, 0.24), Vector3(0.055, 0.018, 0.045)],
		[Vector3(side * 0.45, 0.032, 0.14), Vector3(0.038, 0.016, 0.034)],
		[Vector3(side * 0.22, 0.012, -0.18), Vector3(0.068, 0.016, 0.075)],
	]:
		var sp := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5; sm.height = 1.0; sm.radial_segments = 10; sm.rings = 6
		sp.mesh = sm
		sp.material_override = dot_mat
		sp.position = spot_cfg[0]
		sp.scale = spot_cfg[1]
		pivot.add_child(sp)

	return pivot


func _build() -> void:
	body_pivot = Node3D.new()
	body_pivot.rotation.y = PI  # Align head toward -Z so Godot look_at() flies head-first!
	add_child(body_pivot)

	var body_mat := _mat(Color(0.30, 0.20, 0.30), 0.55)
	var eye_mat := _mat(Color(0.08, 0.06, 0.08), 0.15)
	var ant_tip_mat := _mat(Color(1.0, 0.88, 0.50), 0.25, Color(1.0, 0.82, 0.40), 0.9)

	var fore_mat := _mat(Color(1.0, 0.54, 0.78), 0.30, Color(1.0, 0.46, 0.74), 0.55, 0.95, true)
	var inner_mat := _mat(Color(1.0, 0.88, 0.72), 0.28, Color(1.0, 0.80, 0.62), 0.65, 0.94, true)
	var hind_mat := _mat(Color(1.0, 0.72, 0.56), 0.32, Color(1.0, 0.64, 0.46), 0.50, 0.95, true)
	var dot_mat := _mat(Color(1.0, 0.98, 0.94), 0.20, Color(1.0, 0.95, 0.86), 0.80)
	var trim_mat := _mat(Color(0.42, 0.18, 0.34), 0.45, Color.BLACK, 0.0, 0.88, true)

	# Cute head (+Z forward)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.062; hm.height = 0.115; hm.radial_segments = 12; hm.rings = 8
	head.mesh = hm
	head.material_override = body_mat
	head.position = Vector3(0, 0.015, 0.145)
	body_pivot.add_child(head)

	for sx in [-0.036, 0.036]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.020; em.height = 0.040; em.radial_segments = 8; em.rings = 6
		eye.mesh = em
		eye.material_override = eye_mat
		eye.position = Vector3(sx, 0.025, 0.185)
		body_pivot.add_child(eye)

	# Plump thorax + tapered slender abdomen
	var thorax := MeshInstance3D.new()
	var thm := SphereMesh.new()
	thm.radius = 0.065; thm.height = 0.11; thm.radial_segments = 12; thm.rings = 8
	thorax.mesh = thm
	thorax.material_override = body_mat
	thorax.scale = Vector3(1.0, 0.95, 1.55)
	thorax.position = Vector3(0, 0.0, 0.04)
	body_pivot.add_child(thorax)

	for seg in [
		[Vector3(0, -0.008, -0.06), Vector3(0.095, 0.088, 0.13)],
		[Vector3(0, -0.015, -0.14), Vector3(0.072, 0.068, 0.12)],
		[Vector3(0, -0.020, -0.21), Vector3(0.048, 0.045, 0.10)],
	]:
		var ab := MeshInstance3D.new()
		var am := SphereMesh.new()
		am.radius = 0.5; am.height = 1.0; am.radial_segments = 10; am.rings = 6
		ab.mesh = am
		ab.material_override = body_mat
		ab.position = seg[0]
		ab.scale = seg[1]
		body_pivot.add_child(ab)

	# Two gracefully curved antennae with glowing golden tips
	for side in [-1.0, 1.0]:
		var ant := Node3D.new()
		ant.position = Vector3(side * 0.026, 0.055, 0.175)
		ant.rotation_degrees = Vector3(26, side * 24, -side * 16)
		body_pivot.add_child(ant)

		var stem := MeshInstance3D.new()
		var stm := CylinderMesh.new()
		stm.top_radius = 0.007; stm.bottom_radius = 0.010; stm.height = 0.18; stm.radial_segments = 6
		stem.mesh = stm
		stem.material_override = body_mat
		stem.position = Vector3(0, 0.085, 0.02)
		stem.rotation_degrees = Vector3(24, 0, 0)
		ant.add_child(stem)

		var tip := MeshInstance3D.new()
		var tpm := SphereMesh.new()
		tpm.radius = 0.019; tpm.height = 0.038; tpm.radial_segments = 8; tpm.rings = 6
		tip.mesh = tpm
		tip.material_override = ant_tip_mat
		tip.position = Vector3(0, 0.17, 0.06)
		ant.add_child(tip)

	# Left & Right organic sculpted wings
	wing_l = _build_one_wing(-1.0, fore_mat, hind_mat, inner_mat, dot_mat, trim_mat)
	wing_l.position = Vector3(-0.025, 0.02, 0.03)
	body_pivot.add_child(wing_l)

	wing_r = _build_one_wing(1.0, fore_mat, hind_mat, inner_mat, dot_mat, trim_mat)
	wing_r.position = Vector3(0.025, 0.02, 0.03)
	body_pivot.add_child(wing_r)


func _process(delta: float) -> void:
	t_acc += delta
	var s := sin(t_acc * flap_speed)
	# Graceful butterfly flutter: wide spread wings with gentle upward & downward sweep!
	var angle := 0.12 + s * 0.52
	if wing_l and wing_r:
		wing_l.rotation.z = -angle
		wing_r.rotation.z = angle
	if body_pivot:
		body_pivot.position.y = -s * bob_amp
		body_pivot.rotation.x = 0.08 + s * 0.05
