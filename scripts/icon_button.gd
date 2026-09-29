extends Button
## Круглая кнопка-иконка, значок рисуется линиями (без шрифта).

var icon_kind := "exit"
var base_color := Color(0.05, 0.1, 0.12, 0.82)
var glyph_color := Color("#f4dfbf")


func setup(kind: String, diameter: float) -> void:
	icon_kind = kind
	custom_minimum_size = Vector2(diameter, diameter)
	size = Vector2(diameter, diameter)
	focus_mode = Control.FOCUS_NONE
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var r := int(diameter * 0.5)
	for state in ["normal", "hover", "pressed"]:
		var bg := base_color
		if state == "hover":
			bg = Color(0.14, 0.24, 0.25, 0.95)
		elif state == "pressed":
			bg = Color(0.03, 0.06, 0.07, 0.95)
		var s := StyleBoxFlat.new()
		s.bg_color = bg
		s.border_color = Color(0.9, 0.8, 0.6, 0.55) if state == "hover" else Color(0.72, 0.79, 0.73, 0.35)
		s.set_border_width_all(2)
		s.set_corner_radius_all(r)
		s.anti_aliasing = true
		add_theme_stylebox_override(state, s)
	add_theme_stylebox_override("focus", get_theme_stylebox("normal"))
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var u := minf(size.x, size.y) * 0.5
	var col := glyph_color
	if is_hovered():
		col = col.lightened(0.15)
	var w := maxf(2.5, u * 0.11)
	match icon_kind:
		"exit":
			# стрелка «выход» из скруглённой двери
			draw_arc(c + Vector2(u * 0.08, 0), u * 0.46, deg_to_rad(-70), deg_to_rad(70), 16, col, w, true)
			draw_line(c + Vector2(-u * 0.5, 0), c + Vector2(u * 0.12, 0), col, w, true)
			draw_line(c + Vector2(-u * 0.5, 0), c + Vector2(-u * 0.26, -u * 0.22), col, w, true)
			draw_line(c + Vector2(-u * 0.5, 0), c + Vector2(-u * 0.26, u * 0.22), col, w, true)
		"pause":
			draw_line(c + Vector2(-u * 0.2, -u * 0.34), c + Vector2(-u * 0.2, u * 0.34), col, w * 1.5, true)
			draw_line(c + Vector2(u * 0.2, -u * 0.34), c + Vector2(u * 0.2, u * 0.34), col, w * 1.5, true)
			draw_circle(c + Vector2(-u * 0.2, -u * 0.34), w * 0.75, col)
			draw_circle(c + Vector2(-u * 0.2, u * 0.34), w * 0.75, col)
			draw_circle(c + Vector2(u * 0.2, -u * 0.34), w * 0.75, col)
			draw_circle(c + Vector2(u * 0.2, u * 0.34), w * 0.75, col)
		"back":
			draw_line(c + Vector2(u * 0.36, 0), c + Vector2(-u * 0.36, 0), col, w, true)
			draw_line(c + Vector2(-u * 0.36, 0), c + Vector2(-u * 0.04, -u * 0.32), col, w, true)
			draw_line(c + Vector2(-u * 0.36, 0), c + Vector2(-u * 0.04, u * 0.32), col, w, true)
		"fish":
			draw_arc(c + Vector2(u * 0.06, 0), u * 0.32, 0.0, TAU, 24, col, w, true)
			draw_line(c + Vector2(-u * 0.26, 0), c + Vector2(-u * 0.55, -u * 0.26), col, w, true)
			draw_line(c + Vector2(-u * 0.26, 0), c + Vector2(-u * 0.55, u * 0.26), col, w, true)
			draw_line(c + Vector2(-u * 0.55, -u * 0.26), c + Vector2(-u * 0.55, u * 0.26), col, w, true)
			draw_circle(c + Vector2(u * 0.2, -u * 0.06), w * 0.7, col)
