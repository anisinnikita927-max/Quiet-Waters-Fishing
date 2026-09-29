extends Control
## Круглый индикатор: дуга заполнения вокруг прицела.

var value := 0.0
var inner_value := -1.0
var color := Color("#e4ad6e")
var back_color := Color(1, 1, 1, 0.14)
var thickness := 7.0
var radius := 46.0
var pulse := 0.0


func _draw() -> void:
	var c := Vector2.ZERO
	draw_arc(c, radius, 0.0, TAU, 72, back_color, thickness, true)
	if value > 0.005:
		draw_arc(c, radius, -PI * 0.5, -PI * 0.5 + TAU * clampf(value, 0.0, 1.0), 72, color, thickness, true)
		# круглая «головка» на конце дуги
		var a := -PI * 0.5 + TAU * clampf(value, 0.0, 1.0)
		draw_circle(Vector2(cos(a), sin(a)) * radius, thickness * 0.75 + pulse, color.lightened(0.25))
	if inner_value >= 0.0:
		var r2 := radius - thickness - 5.0
		draw_arc(c, r2, 0.0, TAU, 60, Color(1, 1, 1, 0.08), 3.0, true)
		draw_arc(c, r2, -PI * 0.5, -PI * 0.5 + TAU * clampf(inner_value, 0.0, 1.0), 60, Color("#f4dfbf"), 3.0, true)
	draw_circle(c, 3.0, Color(0.98, 0.9, 0.72, 0.9))
