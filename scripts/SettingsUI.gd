extends CanvasLayer
class_name SettingsUI

const CONFIG_PATH := "user://save_progress.cfg"

const ACTIONS := [
	{"id": "move_up", "label": "向上移动", "default_key": KEY_W, "extra_key": KEY_UP},
	{"id": "move_down", "label": "向下移动", "default_key": KEY_S, "extra_key": KEY_DOWN},
	{"id": "move_left", "label": "向左移动", "default_key": KEY_A, "extra_key": KEY_LEFT},
	{"id": "move_right", "label": "向右移动", "default_key": KEY_D, "extra_key": KEY_RIGHT},
	{"id": "jump", "label": "跳跃", "default_key": KEY_SPACE, "extra_key": KEY_NONE},
	{"id": "telepathy", "label": "灵蝶指路", "default_key": KEY_E, "extra_key": KEY_H},
	{"id": "attack", "label": "赶跑小跳蛙", "default_key": KEY_J, "extra_key": KEY_NONE, "mouse_left": true},
]

signal closed
signal restart_requested
signal back_to_menu_requested

var in_level: bool = false
var waiting_action: String = ""
var key_buttons: Dictionary = {}
var bgm_val_lbl: Label
var sfx_val_lbl: Label
var mute_btn: Button


static func load_saved_keybinds() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	for act in ACTIONS:
		var id: String = act["id"]
		if cfg.has_section_key("keys", id):
			var kcode: int = int(cfg.get_value("keys", id, act["default_key"]))
			_apply_action_key(act, kcode)


static func _apply_action_key(act: Dictionary, primary_key: int) -> void:
	var id: String = act["id"]
	if not InputMap.has_action(id):
		return
	InputMap.action_erase_events(id)
	var ev := InputEventKey.new()
	ev.physical_keycode = primary_key
	ev.keycode = primary_key
	InputMap.action_add_event(id, ev)

	var extra_k: int = act.get("extra_key", KEY_NONE)
	if extra_k != KEY_NONE and extra_k != primary_key:
		var ev2 := InputEventKey.new()
		ev2.physical_keycode = extra_k
		ev2.keycode = extra_k
		InputMap.action_add_event(id, ev2)

	if act.get("mouse_left", false):
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(id, mb)


static func _get_primary_key_name(act_id: String, fallback_key: int) -> String:
	var events := InputMap.action_get_events(act_id)
	for ev in events:
		if ev is InputEventKey:
			var k: int = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
			if k != KEY_NONE:
				return OS.get_keycode_string(k)
	return OS.get_keycode_string(fallback_key)


static func open(parent: Node, p_in_level: bool = false) -> SettingsUI:
	var ui := SettingsUI.new()
	ui.layer = 60
	ui.in_level = p_in_level
	parent.add_child(ui)
	return ui


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	if in_level:
		get_tree().paused = true
	_build_ui()


func _exit_tree() -> void:
	if in_level and get_tree():
		get_tree().paused = false


func _close_self() -> void:
	if in_level and get_tree():
		get_tree().paused = false
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if waiting_action != "":
		if event is InputEventKey and event.pressed and not event.echo:
			var k: int = event.physical_keycode if event.physical_keycode != KEY_NONE else ev_key_fallback(event)
			if k == KEY_ESCAPE:
				_cancel_rebind()
			else:
				_commit_rebind(waiting_action, k)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close_self()


func ev_key_fallback(ev: InputEventKey) -> int:
	return ev.keycode


func _style_flat_slider(sl: HSlider) -> void:
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color(0.05, 0.09, 0.10, 0.95)
	rail.border_color = Color(0.62, 0.68, 0.56, 0.65)
	rail.set_border_width_all(1)
	rail.content_margin_top = 4
	rail.content_margin_bottom = 4

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.86, 0.76, 0.44, 0.92)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4

	sl.add_theme_stylebox_override("slider", rail)
	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill)


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.06, 0.08, 0.78)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# 45-degree Chamfered Double-Line Weathered Slate Folio (ZERO border-radius!)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(640, 530)
	card.add_theme_stylebox_override("panel", GameUI.make_chamfer_panel_style(
		Color(0.06, 0.12, 0.13, 0.97),
		Color(0.88, 0.78, 0.50, 0.95),
		14, 26
	))
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 13)
	card.add_child(vb)

	var title := Label.new()
	title.text = "游戏设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUI.style_floating_label(title, 27, Color(0.99, 0.94, 0.80), 4)
	vb.add_child(title)

	var top_rule := ColorRect.new()
	top_rule.custom_minimum_size = Vector2(0, 1)
	top_rule.color = Color(0.88, 0.78, 0.50, 0.45)
	vb.add_child(top_rule)

	var audio_hdr := Label.new()
	audio_hdr.text = "◆ 声效与音量"
	GameUI.style_floating_label(audio_hdr, 16, Color(0.76, 0.92, 0.80), 3)
	vb.add_child(audio_hdr)

	var bgm_init: float = SoundFX.instance.bgm_volume if SoundFX.instance else 0.75
	var sfx_init: float = SoundFX.instance.sfx_volume if SoundFX.instance else 0.75
	var mute_init: bool = SoundFX.instance.muted if SoundFX.instance else false

	# BGM slider row
	var bgm_row := HBoxContainer.new()
	bgm_row.add_theme_constant_override("separation", 14)
	vb.add_child(bgm_row)
	var bgm_lbl := Label.new()
	bgm_lbl.text = "背景音乐"
	bgm_lbl.custom_minimum_size = Vector2(100, 0)
	GameUI.style_floating_label(bgm_lbl, 15, Color(0.95, 0.94, 0.88), 3)
	bgm_row.add_child(bgm_lbl)

	var bgm_slider := HSlider.new()
	bgm_slider.min_value = 0.0
	bgm_slider.max_value = 100.0
	bgm_slider.step = 1.0
	bgm_slider.value = roundf(bgm_init * 100.0)
	bgm_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bgm_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_flat_slider(bgm_slider)
	bgm_row.add_child(bgm_slider)

	bgm_val_lbl = Label.new()
	bgm_val_lbl.text = "%d%%" % int(bgm_slider.value)
	bgm_val_lbl.custom_minimum_size = Vector2(52, 0)
	bgm_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	GameUI.style_floating_label(bgm_val_lbl, 15, Color(0.98, 0.90, 0.64), 3)
	bgm_row.add_child(bgm_val_lbl)

	bgm_slider.value_changed.connect(func(v: float):
		bgm_val_lbl.text = "%d%%" % int(v)
		SoundFX.set_bgm_volume(v / 100.0)
	)

	# SFX slider row
	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 14)
	vb.add_child(sfx_row)
	var sfx_lbl := Label.new()
	sfx_lbl.text = "互动音效"
	sfx_lbl.custom_minimum_size = Vector2(100, 0)
	GameUI.style_floating_label(sfx_lbl, 15, Color(0.95, 0.94, 0.88), 3)
	sfx_row.add_child(sfx_lbl)

	var sfx_slider := HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 100.0
	sfx_slider.step = 1.0
	sfx_slider.value = roundf(sfx_init * 100.0)
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_flat_slider(sfx_slider)
	sfx_row.add_child(sfx_slider)

	sfx_val_lbl = Label.new()
	sfx_val_lbl.text = "%d%%" % int(sfx_slider.value)
	sfx_val_lbl.custom_minimum_size = Vector2(52, 0)
	sfx_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	GameUI.style_floating_label(sfx_val_lbl, 15, Color(0.98, 0.90, 0.64), 3)
	sfx_row.add_child(sfx_val_lbl)

	sfx_slider.value_changed.connect(func(v: float):
		sfx_val_lbl.text = "%d%%" % int(v)
		SoundFX.set_sfx_volume(v / 100.0)
	)
	sfx_slider.drag_ended.connect(func(_changed: bool):
		SoundFX.play("mushroom", -9.0)
	)

	# Mute chamfered blade toggle
	var mute_row := HBoxContainer.new()
	mute_row.add_theme_constant_override("separation", 14)
	vb.add_child(mute_row)
	var mute_lbl := Label.new()
	mute_lbl.text = "全局静音"
	mute_lbl.custom_minimum_size = Vector2(100, 0)
	GameUI.style_floating_label(mute_lbl, 15, Color(0.95, 0.94, 0.88), 3)
	mute_row.add_child(mute_lbl)

	mute_btn = GameUI.make_blade_button("状态：已静音 [点击开启]" if mute_init else "状态：声音开启 [点击静音]", not mute_init, Vector2(215, 34), 13)
	mute_btn.pressed.connect(func():
		var m := SoundFX.toggle_mute()
		mute_btn.text = "状态：已静音 [点击开启]" if m else "状态：声音开启 [点击静音]"
	)
	mute_row.add_child(mute_btn)

	var mid_rule := ColorRect.new()
	mid_rule.custom_minimum_size = Vector2(0, 1)
	mid_rule.color = Color(0.88, 0.78, 0.50, 0.35)
	vb.add_child(mid_rule)

	var key_hdr_row := HBoxContainer.new()
	vb.add_child(key_hdr_row)
	var key_hdr := Label.new()
	key_hdr.text = "◆ 按键映射（点击键帽改键 · 方向键/鼠标左键常驻）"
	key_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUI.style_floating_label(key_hdr, 15, Color(0.76, 0.92, 0.80), 3)
	key_hdr_row.add_child(key_hdr)

	var reset_btn := GameUI.make_blade_button("恢复默认", false, Vector2(106, 32), 13)
	reset_btn.pressed.connect(_reset_default_keys)
	key_hdr_row.add_child(reset_btn)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)

	for act in ACTIONS:
		var cell := HBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 10)
		grid.add_child(cell)

		var lbl := Label.new()
		lbl.text = act["label"]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		GameUI.style_floating_label(lbl, 14, Color(0.94, 0.93, 0.88), 3)
		cell.add_child(lbl)

		var kbtn := GameUI.make_blade_button(_get_primary_key_name(act["id"], act["default_key"]), false, Vector2(118, 32), 13)
		var aid: String = act["id"]
		kbtn.pressed.connect(func(): _begin_rebind(aid))
		cell.add_child(kbtn)
		key_buttons[aid] = kbtn

	var bot_rule := ColorRect.new()
	bot_rule.custom_minimum_size = Vector2(0, 1)
	bot_rule.color = Color(0.88, 0.78, 0.50, 0.35)
	vb.add_child(bot_rule)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 16)
	vb.add_child(btns)

	var close_btn := GameUI.make_blade_button("继续冒险" if in_level else "完成设置", true, Vector2(148, 42), 17)
	close_btn.pressed.connect(_close_self)
	btns.add_child(close_btn)

	if in_level:
		var restart_btn := GameUI.make_blade_button("重玩本关", false, Vector2(144, 42), 17)
		restart_btn.pressed.connect(func():
			if get_tree():
				get_tree().paused = false
			restart_requested.emit()
			queue_free()
		)
		btns.add_child(restart_btn)

		var menu_btn := GameUI.make_blade_button("返回主菜单", false, Vector2(148, 42), 17)
		menu_btn.pressed.connect(func():
			if get_tree():
				get_tree().paused = false
			back_to_menu_requested.emit()
			queue_free()
		)
		btns.add_child(menu_btn)

	close_btn.grab_focus()


func _begin_rebind(act_id: String) -> void:
	if waiting_action != "":
		_cancel_rebind()
	waiting_action = act_id
	if key_buttons.has(act_id):
		key_buttons[act_id].text = "[按新键...]"


func _cancel_rebind() -> void:
	var old_id := waiting_action
	waiting_action = ""
	for act in ACTIONS:
		if act["id"] == old_id and key_buttons.has(old_id):
			key_buttons[old_id].text = _get_primary_key_name(old_id, act["default_key"])


func _commit_rebind(act_id: String, keycode: int) -> void:
	waiting_action = ""
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	for act in ACTIONS:
		if act["id"] == act_id:
			_apply_action_key(act, keycode)
			cfg.set_value("keys", act_id, keycode)
			cfg.save(CONFIG_PATH)
			if key_buttons.has(act_id):
				key_buttons[act_id].text = OS.get_keycode_string(keycode)
			break


func _reset_default_keys() -> void:
	waiting_action = ""
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	for act in ACTIONS:
		var aid: String = act["id"]
		var dk: int = act["default_key"]
		_apply_action_key(act, dk)
		cfg.set_value("keys", aid, dk)
		if key_buttons.has(aid):
			key_buttons[aid].text = OS.get_keycode_string(dk)
	cfg.save(CONFIG_PATH)
