extends RefCounted
## Общие стили интерфейса: всё скруглённое, капсулы и круги.

const GOLD := Color("#e4b475")
const CREAM := Color("#f4dfbf")
const MUTED := Color("#a9c0ba")
const DIM := Color("#819993")
const PANEL := Color(0.035, 0.075, 0.09, 0.94)
const CARD := Color(0.06, 0.11, 0.13, 0.96)
const BORDER := Color(0.62, 0.74, 0.7, 0.34)


static func style(bg: Color, border: Color = BORDER, radius: int = 28, border_w: int = 1, pad: Vector4 = Vector4(18, 12, 18, 12)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	s.anti_aliasing = true
	s.anti_aliasing_size = 1.2
	return s


static func panel(parent: Control, pos: Vector2, size: Vector2, bg: Color = PANEL, radius: int = 32, border: Color = BORDER) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", style(bg, border, radius, 1, Vector4(0, 0, 0, 0)))
	parent.add_child(p)
	return p


static func label(parent: Control, text: String, pos: Vector2, size: Vector2, font_size: int = 16, color: Color = CREAM, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = align as HorizontalAlignment
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.custom_minimum_size = Vector2(size.x, 0.0)
	l.position = pos
	l.size = size
	l.text = text
	parent.add_child(l)
	return l


## kind: "normal" | "primary" | "ghost" | "danger"
static func button(parent: Control, text: String, pos: Vector2, size: Vector2, font_size: int = 18, kind: String = "normal") -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	var radius := int(minf(size.x, size.y) * 0.5)
	var bg := Color(0.09, 0.16, 0.18, 0.96)
	var bg_hover := Color(0.13, 0.23, 0.24, 1.0)
	var bg_press := Color(0.07, 0.12, 0.14, 1.0)
	var border := BORDER
	var fg := Color("#efe6d2")
	match kind:
		"primary":
			bg = Color("#d9a15c")
			bg_hover = Color("#efb673")
			bg_press = Color("#c08847")
			border = Color("#f6d7a3")
			fg = Color("#2a1b0d")
		"ghost":
			bg = Color(0.09, 0.16, 0.18, 0.55)
			bg_hover = Color(0.14, 0.24, 0.25, 0.9)
		"danger":
			bg = Color("#7a3a34")
			bg_hover = Color("#95463e")
			bg_press = Color("#5f2c27")
			border = Color("#d98b7d")
	b.add_theme_stylebox_override("normal", style(bg, border, radius, 2 if kind == "primary" else 1))
	b.add_theme_stylebox_override("hover", style(bg_hover, border.lightened(0.15), radius, 2))
	b.add_theme_stylebox_override("pressed", style(bg_press, border, radius, 2))
	b.add_theme_stylebox_override("disabled", style(Color(0.08, 0.12, 0.13, 0.7), Color(0.4, 0.5, 0.5, 0.25), radius, 1))
	b.add_theme_stylebox_override("focus", style(bg_hover, GOLD, radius, 2))
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg.lightened(0.1))
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", Color("#6f817c"))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(b)
	return b


static func card_style(selected: bool, hovered: bool = false) -> StyleBoxFlat:
	var bg := CARD
	if hovered:
		bg = bg.lightened(0.05)
	return style(bg, GOLD if selected else BORDER, 30, 3 if selected else 1, Vector4(0, 0, 0, 0))
