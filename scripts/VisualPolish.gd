extends RefCounted
class_name VisualPolish

## Shared procedural shader & non-plastic material factory (shader-visual-polish + godot-shaders).
## Eliminates uniform RGB plastic primitives by wiring world-space fBm noise, roughness breakup,
## warm/cool light gradients, and animated shoreline water optics.

static var _moss_shader: Shader = null
static var _water_shader: Shader = null
static var _mat_cache: Dictionary = {}


static func _get_moss_shader() -> Shader:
	if _moss_shader == null:
		_moss_shader = load("res://assets/shaders/mossy_surface.gdshader") as Shader
	return _moss_shader


static func _get_water_shader() -> Shader:
	if _water_shader == null:
		_water_shader = load("res://assets/shaders/stylized_water.gdshader") as Shader
	return _water_shader


static func make_terrain_mat(
	base_col: Color,
	warm_col: Color,
	cool_col: Color,
	n_scale: float = 0.52,
	r_min: float = 0.72,
	r_max: float = 0.97,
	variation: float = 0.26
) -> Material:
	var key := "terr_%s_%s_%s_%.2f" % [base_col.to_html(), warm_col.to_html(), cool_col.to_html(), n_scale]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var sh := _get_moss_shader()
	if sh == null:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = base_col
		fallback.roughness = 0.92
		fallback.metallic_specular = 0.14
		return fallback
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("base_color", base_col)
	sm.set_shader_parameter("warm_tint", warm_col)
	sm.set_shader_parameter("cool_shadow_tint", cool_col)
	sm.set_shader_parameter("noise_scale", n_scale)
	sm.set_shader_parameter("micro_scale", 13.5)
	sm.set_shader_parameter("color_variation", variation)
	sm.set_shader_parameter("rough_min", r_min)
	sm.set_shader_parameter("rough_max", r_max)
	sm.set_shader_parameter("specular_amt", 0.12)
	_mat_cache[key] = sm
	return sm


static func make_organic_mat(
	base_col: Color,
	n_scale: float = 1.65,
	r_min: float = 0.62,
	r_max: float = 0.92,
	emit_col: Color = Color.BLACK,
	emit_energy: float = 0.0
) -> Material:
	var warm := base_col.lightened(0.18)
	warm.r = minf(1.0, warm.r * 1.06)
	var cool := base_col.darkened(0.28)
	cool.b = minf(1.0, cool.b * 1.12 + 0.03)
	var key := "org_%s_%.2f_%.2f_%s" % [base_col.to_html(), n_scale, emit_energy, emit_col.to_html()]
	if emit_energy <= 0.0 and _mat_cache.has(key):
		return _mat_cache[key]
	var sh := _get_moss_shader()
	if sh == null:
		var fb := StandardMaterial3D.new()
		fb.albedo_color = base_col
		fb.roughness = (r_min + r_max) * 0.5
		fb.metallic_specular = 0.16
		return fb
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("base_color", base_col)
	sm.set_shader_parameter("warm_tint", warm)
	sm.set_shader_parameter("cool_shadow_tint", cool)
	sm.set_shader_parameter("noise_scale", n_scale)
	sm.set_shader_parameter("micro_scale", 18.0)
	sm.set_shader_parameter("color_variation", 0.22)
	sm.set_shader_parameter("rough_min", r_min)
	sm.set_shader_parameter("rough_max", r_max)
	sm.set_shader_parameter("specular_amt", 0.15)
	sm.set_shader_parameter("emission_tint", Vector3(emit_col.r, emit_col.g, emit_col.b))
	sm.set_shader_parameter("emission_energy", emit_energy)
	if emit_energy <= 0.0:
		_mat_cache[key] = sm
	return sm


static func make_water_mat(
	deep_col: Color = Color(0.05, 0.25, 0.40),
	shallow_col: Color = Color(0.14, 0.64, 0.70),
	flow: Vector2 = Vector2(0.0, 1.0),
	speed: float = 0.58
) -> Material:
	var sh := _get_water_shader()
	if sh == null:
		var fb := StandardMaterial3D.new()
		fb.albedo_color = shallow_col
		fb.roughness = 0.12
		return fb
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("deep_color", deep_col)
	sm.set_shader_parameter("shallow_color", shallow_col)
	sm.set_shader_parameter("foam_color", Color(0.88, 0.98, 1.0, 1.0))
	sm.set_shader_parameter("flow_dir", flow)
	sm.set_shader_parameter("flow_speed", speed)
	sm.set_shader_parameter("wave_scale", 1.35)
	return sm
