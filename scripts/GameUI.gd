extends RefCounted
class_name GameUI

## Anti-Slop Game HUD & Architectural Chamfered UI Builder (anti-slop-game-ui + game-ui-ux).
## Zero border-radius rounded cards or translucent purple-blue boxes anywhere:
## - In-game HUD & narrative subtitles use borderless floating outlined typography over directional edge vignettes.
## - Interactive buttons & modal plates use 45-degree chamfered weathered slate/foliage textures with
##   double-hairline brass filigree, corner L-brackets, stable hitboxes, and snappy asymmetric press juice.

static var _style_cache: Dictionary = {}


static func _pcg_noise(x: int, y: int) -> float:
	var n: int = (x * 73856093) ^ (y * 19349663) ^ 0x5bd1e995
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xFFFF) / 65535.0


static func make_chamfer_stylebox(
	bg: Color,
	outer_border: Color,
	inner_border: Color,
	chamfer: int = 10,
	left_accent_w: int = 0,
	accent_col: Color = Color(0.98, 0.86, 0.52, 1.0),
	pad_h: int = 16,
	pad_v: int = 10
) -> StyleBoxTexture:
	var key := "%s_%s_%s_%d_%d_%s_%d_%d" % [
		bg.to_html(), outer_border.to_html(), inner_border.to_html(),
		chamfer, left_accent_w, accent_col.to_html(), pad_h, pad_v
	]
	if _style_cache.has(key):
		return _style_cache[key]

	var sz := 96
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var c_cut := maxi(2, chamfer)

	for y in range(sz):
		for x in range(sz):
			var dx := mini(x, sz - 1 - x)
			var dy := mini(y, sz - 1 - y)
			# 45-degree Manhattan chamfer mask on all 4 corners (zero circular rounding!)
			var manhattan := dx + dy
			if manhattan < c_cut:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			var edge_dist := mini(mini(dx, dy), manhattan - c_cut)
			if edge_dist <= 1:
				img.set_pixel(x, y, outer_border)
			elif left_accent_w > 0 and x >= 2 and x < 2 + left_accent_w and manhattan >= c_cut + 2:
				img.set_pixel(x, y, accent_col)
			elif edge_dist == 4:
				img.set_pixel(x, y, inner_border)
			elif (x < c_cut + 7 or x >= sz - c_cut - 7) and (y < c_cut + 7 or y >= sz - c_cut - 7) and edge_dist == 2:
				# Crisp corner reinforcement bracket tick
				img.set_pixel(x, y, accent_col)
			else:
				# Weathered slate/botanical micro-grain + subtle edge vignette (anti-plastic!)
				var grain := (_pcg_noise(x, y) - 0.5) * 0.055
				var edge_shade := clampf(float(edge_dist) / 18.0, 0.0, 1.0)
				var lum := 0.88 + 0.14 * edge_shade + grain
				var v_grad := 1.05 - 0.10 * (float(y) / float(sz))
				var px_col := Color(
					clampf(bg.r * lum * v_grad, 0.0, 1.0),
					clampf(bg.g * lum * v_grad, 0.0, 1.0),
					clampf(bg.b * lum * v_grad, 0.0, 1.0),
					bg.a
				)
				img.set_pixel(x, y, px_col)

	var tex := ImageTexture.create_from_image(img)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	var m := c_cut + 8
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	sb.content_margin_left = pad_h + left_accent_w
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	_style_cache[key] = sb
	return sb


static func make_chamfer_panel_style(
	bg: Color = Color(0.07, 0.13, 0.14, 0.95),
	border: Color = Color(0.86, 0.76, 0.48, 0.94),
	chamfer: int = 14,
	pad: int = 24
) -> StyleBoxTexture:
	var inner := Color(border.r, border.g, border.b, 0.28)
	return make_chamfer_stylebox(bg, border, inner, chamfer, 0, border.lightened(0.15), pad, pad)


static func make_blade_button(
	txt: String,
	is_primary: bool = false,
	min_size: Vector2 = Vector2(268, 48),
	font_sz: int = 20
) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = min_size
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", Color(0.98, 0.95, 0.87))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.99, 0.92))
	btn.add_theme_color_override("font_focus_color", Color(1.0, 0.97, 0.86))
	btn.add_theme_color_override("font_pressed_color", Color(0.94, 0.88, 0.72))
	btn.add_theme_color_override("font_outline_color", Color(0.03, 0.07, 0.08, 0.92))
	btn.add_theme_constant_override("outline_size", 3)

	var normal_sb: StyleBoxTexture
	var hover_sb: StyleBoxTexture
	var press_sb: StyleBoxTexture
	var focus_sb: StyleBoxTexture

	if is_primary:
		normal_sb = make_chamfer_stylebox(
			Color(0.09, 0.36, 0.28, 0.96),
			Color(0.96, 0.84, 0.48, 0.98),
			Color(0.96, 0.84, 0.48, 0.35),
			9, 4, Color(1.0, 0.90, 0.56, 1.0), 18, 9
		)
		hover_sb = make_chamfer_stylebox(
			Color(0.13, 0.46, 0.35, 0.99),
			Color(1.0, 0.93, 0.66, 1.0),
			Color(1.0, 0.93, 0.66, 0.52),
			9, 6, Color(1.0, 0.95, 0.72, 1.0), 18, 9
		)
		press_sb = make_chamfer_stylebox(
			Color(0.06, 0.26, 0.20, 0.99),
			Color(0.90, 0.76, 0.42, 1.0),
			Color(0.90, 0.76, 0.42, 0.30),
			9, 4, Color(0.94, 0.82, 0.48, 1.0), 18, 9
		)
	else:
		normal_sb = make_chamfer_stylebox(
			Color(0.07, 0.15, 0.16, 0.90),
			Color(0.68, 0.66, 0.50, 0.84),
			Color(0.68, 0.66, 0.50, 0.22),
			8, 3, Color(0.84, 0.76, 0.50, 0.85), 16, 8
		)
		hover_sb = make_chamfer_stylebox(
			Color(0.11, 0.24, 0.24, 0.96),
			Color(0.98, 0.88, 0.58, 0.98),
			Color(0.98, 0.88, 0.58, 0.42),
			8, 5, Color(1.0, 0.92, 0.64, 1.0), 16, 8
		)
		press_sb = make_chamfer_stylebox(
			Color(0.05, 0.11, 0.12, 0.98),
			Color(0.84, 0.74, 0.46, 0.96),
			Color(0.84, 0.74, 0.46, 0.25),
			8, 3, Color(0.88, 0.78, 0.48, 0.95), 16, 8
		)

	focus_sb = make_chamfer_stylebox(
		Color(0.0, 0.0, 0.0, 0.0),
		Color(1.0, 0.92, 0.60, 0.95),
		Color(1.0, 0.92, 0.60, 0.35),
		8, 0, Color(1.0, 0.92, 0.60, 1.0), 16, 8
	)

	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", press_sb)
	btn.add_theme_stylebox_override("focus", focus_sb)

	wire_button_juice(btn)
	return btn


static func wire_button_juice(btn: Button) -> void:
	# Asymmetric press-and-release spring scale around button center (never shifts hitbox!)
	btn.mouse_entered.connect(func():
		SoundFX.play("ui_hover", -17.0, randf_range(0.95, 1.06))
	)
	btn.button_down.connect(func():
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(btn, "scale", Vector2(0.965, 0.945), 0.06)
	)
	btn.button_up.connect(func():
		btn.pivot_offset = btn.size * 0.5
		SoundFX.play("ui_click", -11.0, randf_range(0.93, 1.08))
		var tw := btn.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.16)
	)


static func style_floating_label(
	lbl: Label,
	font_sz: int,
	col: Color = Color(0.98, 0.96, 0.90),
	outline_sz: int = 5
) -> void:
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.06, 0.08, 0.96))
	lbl.add_theme_constant_override("outline_size", outline_sz)
	lbl.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.06, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 3)


static func build_edge_vignette(from_uv: Vector2, to_uv: Vector2, col: Color, size_v: Vector2) -> TextureRect:
	var grad := Gradient.new()
	grad.set_color(0, col)
	grad.set_color(1, Color(col.r, col.g, col.b, 0.0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = from_uv
	gtex.fill_to = to_uv
	gtex.width = 128
	gtex.height = 64
	var tr := TextureRect.new()
	tr.texture = gtex
	tr.custom_minimum_size = size_v
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func build_level_hud(
	ui_layer: CanvasLayer,
	accent_col: Color,
	on_settings: Callable
) -> Dictionary:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)

	# 1. Top-Left Single-Edge Directional Vignette Mask (NO rounded box!)
	var top_vig := build_edge_vignette(
		Vector2(0.0, 0.0), Vector2(0.85, 0.95),
		Color(0.03, 0.07, 0.09, 0.72), Vector2(640, 88)
	)
	top_vig.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_vig.offset_right = 640
	top_vig.offset_bottom = 88
	root.add_child(top_vig)

	# Crisp architectural hairline accent bar + diamond pip under floating HUD text
	var hud_wrap := Control.new()
	hud_wrap.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud_wrap.offset_left = 24
	hud_wrap.offset_top = 18
	hud_wrap.offset_right = 680
	hud_wrap.offset_bottom = 68
	hud_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud_wrap)

	var pip := Polygon2D.new()
	pip.polygon = PackedVector2Array([Vector2(0, -5), Vector2(5, 0), Vector2(0, 5), Vector2(-5, 0)])
	pip.color = accent_col
	pip.position = Vector2(5, 14)
	hud_wrap.add_child(pip)

	var rule := ColorRect.new()
	rule.color = Color(accent_col.r, accent_col.g, accent_col.b, 0.62)
	rule.position = Vector2(0, 31)
	rule.size = Vector2(460, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_wrap.add_child(rule)

	var rule_sub := ColorRect.new()
	rule_sub.color = Color(accent_col.r, accent_col.g, accent_col.b, 0.22)
	rule_sub.position = Vector2(0, 35)
	rule_sub.size = Vector2(290, 1)
	rule_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_wrap.add_child(rule_sub)

	var hud_label := Label.new()
	hud_label.position = Vector2(16, 1)
	style_floating_label(hud_label, 16, Color(0.99, 0.97, 0.91), 5)
	hud_wrap.add_child(hud_label)

	var hint_lbl := Label.new()
	hint_lbl.text = "WASD 奔跑  ·  Space 跳跃  ·  E/H 灵蝶指路  ·  ESC 设置"
	hint_lbl.position = Vector2(2, 41)
	style_floating_label(hint_lbl, 12, Color(0.80, 0.88, 0.86, 0.90), 4)
	hud_wrap.add_child(hint_lbl)

	# 2. Top-Right Sharp Chamfered Tactical Button (zero border-radius!)
	var set_btn := make_blade_button("⚙ 设置 [ESC]", false, Vector2(124, 38), 14)
	set_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	set_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	set_btn.offset_right = -20
	set_btn.offset_top = 16
	set_btn.pressed.connect(on_settings)
	root.add_child(set_btn)

	# 3. Bottom Narrative Subtitle Veil (Borderless Letterbox Gradient + Brass Filigree Line)
	var toast_holder := Control.new()
	toast_holder.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_holder.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast_holder.offset_left = -410
	toast_holder.offset_right = 410
	toast_holder.offset_top = -108
	toast_holder.offset_bottom = -14
	toast_holder.custom_minimum_size = Vector2(820, 94)
	toast_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_holder)

	var bot_vig := build_edge_vignette(
		Vector2(0.5, 1.0), Vector2(0.5, 0.0),
		Color(0.02, 0.05, 0.07, 0.82), Vector2(820, 94)
	)
	bot_vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	toast_holder.add_child(bot_vig)

	var t_line_l := ColorRect.new()
	t_line_l.color = Color(0.96, 0.84, 0.52, 0.68)
	t_line_l.position = Vector2(120, 12)
	t_line_l.size = Vector2(256, 1)
	t_line_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_holder.add_child(t_line_l)

	var t_line_r := ColorRect.new()
	t_line_r.color = Color(0.96, 0.84, 0.52, 0.68)
	t_line_r.position = Vector2(444, 12)
	t_line_r.size = Vector2(256, 1)
	t_line_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_holder.add_child(t_line_r)

	var t_gem := Polygon2D.new()
	t_gem.polygon = PackedVector2Array([Vector2(0, -4), Vector2(6, 0), Vector2(0, 4), Vector2(-6, 0)])
	t_gem.color = Color(0.99, 0.88, 0.56, 0.95)
	t_gem.position = Vector2(410, 12)
	toast_holder.add_child(t_gem)

	var toast_label := Label.new()
	toast_label.position = Vector2(50, 22)
	toast_label.size = Vector2(720, 64)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	style_floating_label(toast_label, 18, Color(1.0, 0.97, 0.90), 6)
	toast_holder.add_child(toast_label)

	return {
		"root": root,
		"hud_wrap": hud_wrap,
		"hud_label": hud_label,
		"hint_label": hint_lbl,
		"toast_panel": toast_holder,
		"toast_label": toast_label,
	}


static func pulse_hud(hud_label: Label) -> void:
	if hud_label == null or not is_instance_valid(hud_label):
		return
	hud_label.pivot_offset = Vector2(0, hud_label.size.y * 0.5)
	hud_label.scale = Vector2(1.07, 1.12)
	var tw := hud_label.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(hud_label, "scale", Vector2.ONE, 0.22)


static func animate_toast_in(toast_holder: Control) -> void:
	if toast_holder == null or not is_instance_valid(toast_holder):
		return
	toast_holder.visible = true
	toast_holder.modulate.a = 0.25
	toast_holder.pivot_offset = toast_holder.size * 0.5
	toast_holder.scale = Vector2(0.97, 0.94)
	var tw := toast_holder.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(toast_holder, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(toast_holder, "scale", Vector2.ONE, 0.18)
