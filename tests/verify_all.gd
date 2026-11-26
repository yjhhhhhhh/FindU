extends SceneTree

var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	var shaders := [
		"res://assets/shaders/mossy_surface.gdshader",
		"res://assets/shaders/stylized_water.gdshader",
	]
	for sp in shaders:
		print("Compiling shader: ", sp)
		var sh := load(sp) as Shader
		if sh == null:
			push_error("FAILED TO LOAD SHADER: " + sp)
			quit(1)
			return true
		var uniforms := sh.get_shader_uniform_list()
		print("  -> OK, uniforms count = ", uniforms.size())

	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	var main_inst := main_scene.instantiate()
	root.add_child(main_inst)
	print("Main scene instantiated OK")

	for lvl_idx in [1, 2, 3, 4, 5]:
		main_inst._start_level("boy", lvl_idx)
		print("Level ", lvl_idx, " instantiated OK")

	var sui := SettingsUI.open(main_inst, false)
	print("SettingsUI instantiated OK")
	sui._close_self()

	GameJuice.add_trauma(0.5)
	GameJuice.hitstop(0.02, 0.08)
	if Engine.time_scale >= 0.2:
		push_error("Hitstop failed to lower Engine.time_scale")
		quit(1)
		return true
	Engine.time_scale = 1.0
	print("ALL GODOT HEADLESS CHECKS PASSED")
	quit(0)
	return true
