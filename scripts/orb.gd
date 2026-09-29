extends Control
## Круглый значок озера: небо, вода, солнце или луна.

var sky_top := Color.DODGER_BLUE
var sky_horizon := Color.WHITE
var water_deep := Color.DARK_CYAN
var water_light := Color.AQUAMARINE
var sun := Color.WHITE
var night := false
var snow := false
var radius := 52.0


func setup(lake: Dictionary, r: float) -> void:
	sky_top = Color(String(lake["sky_top"]))
	sky_horizon = Color(String(lake["sky_horizon"]))
	water_deep = Color(String(lake["water_deep"]))
	water_light = Color(String(lake["water_light"]))
	sun = Color(String(lake["sun"]))
	night = bool(lake.get("night", false))
	snow = String(lake["weather"]) == "snow"
	radius = r
	custom_minimum_size = Vector2(r * 2.0, r * 2.0)
	size = custom_minimum_size
	queue_redraw()


func _circle_points(center: Vector2, a0: float, a1: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n + 1):
		var a := lerpf(a0, a1, float(i) / float(n))
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts


func _draw() -> void:
	var c := Vector2(radius, radius)
	var horizon_y := 0.12
	var ang := asin(horizon_y)
	# небо: верхний сегмент круга
	var top_arc := _circle_points(c, PI + ang, TAU - ang, 40)
	var poly := PackedVector2Array()
	var cols := PackedColorArray()
	for p in top_arc:
		poly.append(p)
		var k := clampf((p.y - (c.y - radius)) / (radius * (1.0 + horizon_y)), 0.0, 1.0)
		cols.append(sky_top.lerp(sky_horizon, k))
	draw_polygon(poly, cols)
	# вода: нижний сегмент
	var bot_arc := _circle_points(c, ang, PI - ang, 40)
	var poly2 := PackedVector2Array()
	var cols2 := PackedColorArray()
	for p in bot_arc:
		poly2.append(p)
		var k2 := clampf((p.y - c.y) / radius, 0.0, 1.0)
		cols2.append(water_light.lerp(water_deep, k2))
	draw_polygon(poly2, cols2)
	# полоска горизонта
	var hx := radius * cos(ang)
	var hy := c.y + radius * sin(ang) * 0.0
	var band := PackedVector2Array([Vector2(c.x - hx, hy - radius * 0.14), Vector2(c.x + hx, hy - radius * 0.14), Vector2(c.x + hx, hy + radius * 0.14), Vector2(c.x - hx, hy + radius * 0.14)])
	draw_colored_polygon(band, sky_horizon.lerp(water_light, 0.5))
	# светило
	if night:
		draw_circle(c + Vector2(-radius * 0.35, -radius * 0.45), radius * 0.16, Color("#f4f0dc"))
		draw_circle(c + Vector2(-radius * 0.3, -radius * 0.5), radius * 0.13, sky_top.lerp(Color.BLACK, 0.2))
		for i in range(6):
			var sp := Vector2(sin(float(i) * 2.3), cos(float(i) * 3.7)) * radius * 0.5
			draw_circle(c + Vector2(sp.x, -absf(sp.y) * 0.9 - radius * 0.1), 1.6, Color(1, 1, 1, 0.9))
	else:
		draw_circle(c + Vector2(-radius * 0.32, -radius * 0.22), radius * 0.2, sun.lerp(Color("#ffb979"), 0.4))
		draw_circle(c + Vector2(-radius * 0.32, -radius * 0.22), radius * 0.3, Color(sun.r, sun.g, sun.b, 0.18))
	# блики на воде
	for i in range(3):
		var y := c.y + radius * (0.32 + 0.2 * float(i))
		var w := radius * (0.55 - 0.12 * float(i))
		draw_line(Vector2(c.x - w, y), Vector2(c.x + w, y), Color(1, 1, 1, 0.22), 2.0, true)
	if snow:
		for i in range(14):
			var sp2 := Vector2(sin(float(i) * 12.9898) * 43.0, cos(float(i) * 78.233) * 43.0)
			var q := c + Vector2(fposmod(sp2.x, radius * 1.6) - radius * 0.8, fposmod(sp2.y, radius * 1.4) - radius * 0.7)
			if q.distance_to(c) < radius * 0.9:
				draw_circle(q, 1.7, Color(1, 1, 1, 0.9))
	draw_arc(c, radius - 1.0, 0.0, TAU, 64, Color(1, 1, 1, 0.28), 2.0, true)
