extends Control
class_name MiniMap

var world_half_w: float = 24.0
var world_half_d: float = 16.0
var player_pos := Vector2.ZERO
var goal_pos := Vector2.ZERO
var mushrooms: Array[Dictionary] = []
var pads: Array[Dictionary] = []
var keepsake_pos: Vector2 = Vector2.INF
var gates: Array[Vector2] = []


func _ready() -> void:
	custom_minimum_size = Vector2(152, 152)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(hw: float, hd: float, p_goal: Vector3) -> void:
	world_half_w = hw
	world_half_d = hd
	goal_pos = Vector2(p_goal.x, p_goal.z)


func refresh(p_pos: Vector3, p_mush: Array, p_pads: Array, p_ks_visible: bool, p_ks_pos: Vector3, p_gates: Array) -> void:
	player_pos = Vector2(p_pos.x, p_pos.z)
	mushrooms.clear()
	for m in p_mush:
		var mp: Vector3 = m["pos"]
		mushrooms.append({"pos": Vector2(mp.x, mp.z), "lit": m["lit"]})
	pads.clear()
	for p in p_pads:
		if p["revealed"]:
			var pp: Vector3 = p["pos"]
			pads.append({"pos": Vector2(pp.x, pp.z), "lit": p["lit"]})
	keepsake_pos = Vector2(p_ks_pos.x, p_ks_pos.z) if p_ks_visible else Vector2.INF
	gates.clear()
	for g in p_gates:
		if g != null:
			gates.append(Vector2(g.x, g.z))
	queue_redraw()


func _to_map(v: Vector2) -> Vector2:
	var pad := 16.0
	var inner := size - Vector2(pad * 2.0, pad * 2.0)
	var nx := (v.x + world_half_w) / (world_half_w * 2.0)
	var nz := (v.y + world_half_d) / (world_half_d * 2.0)
	return Vector2(pad + clampf(nx, 0.0, 1.0) * inner.x, pad + clampf(nz, 0.0, 1.0) * inner.y)


func _chamfer_poly(rect: Rect2, cut: float) -> PackedVector2Array:
	var x0 := rect.position.x
	var y0 := rect.position.y
	var x1 := rect.end.x
	var y1 := rect.end.y
	return PackedVector2Array([
		Vector2(x0 + cut, y0),
		Vector2(x1 - cut, y0),
		Vector2(x1, y0 + cut),
		Vector2(x1, y1 - cut),
		Vector2(x1 - cut, y1),
		Vector2(x0 + cut, y1),
		Vector2(x0, y1 - cut),
		Vector2(x0, y0 + cut),
		Vector2(x0 + cut, y0),
	])


func _draw_diamond(center: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -r),
		center + Vector2(r, 0),
		center + Vector2(0, r),
		center + Vector2(-r, 0),
	]), col)


func _draw() -> void:
	# 45-degree Chamfered Tactical Compass Frame (ZERO border-radius!)
	var outer := _chamfer_poly(Rect2(Vector2.ZERO, size), 14.0)
	var inner := _chamfer_poly(Rect2(Vector2(4, 4), size - Vector2(8, 8)), 11.0)

	var fill_pts := outer.slice(0, 8)
	draw_colored_polygon(fill_pts, Color(0.05, 0.10, 0.11, 0.84))
	draw_polyline(outer, Color(0.86, 0.78, 0.50, 0.90), 2.0, true)
	draw_polyline(inner, Color(0.56, 0.76, 0.66, 0.34), 1.0, true)

	# Subtle compass crosshairs & cardinal ticks
	var c := size * 0.5
	draw_line(Vector2(18, c.y), Vector2(size.x - 18, c.y), Color(0.62, 0.78, 0.70, 0.14), 1.0)
	draw_line(Vector2(c.x, 18), Vector2(c.x, size.y - 18), Color(0.62, 0.78, 0.70, 0.14), 1.0)
	draw_line(Vector2(c.x, 5), Vector2(c.x, 11), Color(0.98, 0.88, 0.56, 0.85), 2.0)

	# Closed gates (crimson-amber bar + diamond)
	for g in gates:
		var gp := _to_map(g)
		_draw_diamond(gp, 5.2, Color(0.98, 0.42, 0.32, 0.95))

	# Mushrooms (cyan-emerald diamond when lit, muted plum dot when unlit)
	for m in mushrooms:
		var mp := _to_map(m["pos"])
		if m["lit"]:
			_draw_diamond(mp, 4.4, Color(0.42, 1.0, 0.82))
		else:
			draw_rect(Rect2(mp - Vector2(2.6, 2.6), Vector2(5.2, 5.2)), Color(0.76, 0.58, 0.88, 0.82))

	# Revealed Note Pads (crisp square rune)
	for p in pads:
		var pp := _to_map(p["pos"])
		var col := Color(1.0, 0.88, 0.34) if p["lit"] else Color(0.84, 0.92, 1.0)
		draw_rect(Rect2(pp - Vector2(3.5, 3.5), Vector2(7, 7)), col)

	# Revealed Keepsake / Milk Tea
	if keepsake_pos != Vector2.INF:
		var kp := _to_map(keepsake_pos)
		_draw_diamond(kp, 5.4, Color(1.0, 0.86, 0.28))

	# Partner / Goal (warm rose-gold beacon)
	var goal_p := _to_map(goal_pos)
	_draw_diamond(goal_p, 7.0, Color(1.0, 0.54, 0.72, 0.38))
	_draw_diamond(goal_p, 4.5, Color(1.0, 0.62, 0.78))

	# Player (crisp ivory-gold diamond + cyan rim)
	var pp_map := _to_map(player_pos)
	_draw_diamond(pp_map, 6.4, Color(0.45, 0.92, 0.95, 0.55))
	_draw_diamond(pp_map, 3.8, Color(1.0, 0.98, 0.90))
