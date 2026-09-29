extends Control
## Собственная заставка загрузки: круглый логотип, вращающиеся кольца и полоса прогресса.

const UI = preload("res://scripts/ui_kit.gd")
const ROUND_MASK = preload("res://shaders/round_mask.gdshader")
const TIPS := [
	"Держи кнопку дольше — поплавок улетит дальше.",
	"Отпускай кнопку, когда кольцо вокруг прицела краснеет.",
	"У каждого озера своя рыба, музыка и погода.",
	"Редкие рыбы клюют реже, зато приносят больше монет.",
	"Новые удочки продаются в магазине.",
	"В коллекции можно посмотреть каждую пойманную рыбу.",
	"Ночью на озере просыпаются светлячки.",
]

var progress := 0.0
var shown := 0.0
var clock := 0.0
var logo: TextureRect
var title: Label
var subtitle: Label
var status: Label
var tip: Label
var tip_index := 0
var tip_timer := 0.0
var closing := false
var bar_rect := Rect2()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var icon := load("res://assets/app_icon.png") as Texture2D
	logo = TextureRect.new()
	logo.texture = icon
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_SCALE
	logo.size = Vector2(300, 300)
	var sm := ShaderMaterial.new()
	sm.shader = ROUND_MASK
	sm.set_shader_parameter("ring_color", Color(0.96, 0.86, 0.69, 0.9))
	sm.set_shader_parameter("ring_width", 0.02)
	logo.material = sm
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	title = UI.label(self, "QUIET WATERS", Vector2.ZERO, Vector2(900, 80), 64, Color("#fff0d6"), HORIZONTAL_ALIGNMENT_CENTER)
	subtitle = UI.label(self, "ТИХИЕ ВОДЫ  •  РЫБАЛКА", Vector2.ZERO, Vector2(900, 30), 20, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	status = UI.label(self, "Загрузка...", Vector2.ZERO, Vector2(700, 26), 16, Color("#a9c0ba"), HORIZONTAL_ALIGNMENT_CENTER)
	tip = UI.label(self, TIPS[0], Vector2.ZERO, Vector2(900, 26), 15, Color("#819993"), HORIZONTAL_ALIGNMENT_CENTER)
	resized.connect(_layout)
	_layout()


func set_progress(value: float, text: String = "") -> void:
	progress = clampf(value, 0.0, 1.0)
	if text != "":
		status.text = text


func finish() -> void:
	if closing:
		return
	closing = true
	set_progress(1.0, "Готово!")
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(self, "modulate:a", 0.0, 0.55)
	tw.tween_callback(queue_free)


func _layout() -> void:
	var c := size * 0.5
	logo.position = Vector2(c.x - 150.0, c.y - 250.0)
	title.position = Vector2(c.x - 450.0, c.y + 60.0)
	subtitle.position = Vector2(c.x - 450.0, c.y + 148.0)
	status.position = Vector2(c.x - 350.0, c.y + 232.0)
	tip.position = Vector2(c.x - 450.0, size.y - 74.0)
	bar_rect = Rect2(c.x - 260.0, c.y + 272.0, 520.0, 12.0)
	logo.pivot_offset = logo.size * 0.5
	queue_redraw()


func _process(delta: float) -> void:
	clock += delta
	shown = lerpf(shown, progress, minf(1.0, delta * 6.0))
	tip_timer += delta
	if tip_timer > 2.4:
		tip_timer = 0.0
		tip_index = (tip_index + 1) % TIPS.size()
		tip.text = TIPS[tip_index]
	logo.scale = Vector2.ONE * (1.0 + sin(clock * 1.8) * 0.018)
	queue_redraw()


func _draw() -> void:
	var vs := size
	var c := vs * 0.5
	# фон: вертикальный градиент
	var top := Color("#0a1c24")
	var mid := Color("#0e2e3a")
	var bottom := Color("#08181f")
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(vs.x, 0), Vector2(vs.x, vs.y * 0.55), Vector2(0, vs.y * 0.55)])
	draw_polygon(pts, PackedColorArray([top, top, mid, mid]))
	var pts2 := PackedVector2Array([Vector2(0, vs.y * 0.55), Vector2(vs.x, vs.y * 0.55), Vector2(vs.x, vs.y), Vector2(0, vs.y)])
	draw_polygon(pts2, PackedColorArray([mid, mid, bottom, bottom]))
	# тёплое свечение за логотипом
	var lc := c + Vector2(0, -100)
	for i in range(14):
		var r := 420.0 - float(i) * 26.0
		draw_circle(lc, r, Color(0.91, 0.66, 0.43, 0.012 + 0.006 * float(i) * 0.4))
	# расходящиеся круги на воде
	for i in range(3):
		var t := fposmod(clock * 0.35 + float(i) / 3.0, 1.0)
		var rw := 190.0 + t * 330.0
		draw_arc_ellipse(lc + Vector2(0, 205), Vector2(rw, rw * 0.16), Color(0.85, 0.95, 0.95, 0.35 * (1.0 - t)), 2.0)
	# вращающиеся кольца вокруг логотипа
	var ring_r := 172.0
	draw_arc(lc, ring_r, clock * 1.6, clock * 1.6 + PI * 1.15, 48, Color(0.96, 0.78, 0.5, 0.9), 5.0, true)
	draw_arc(lc, ring_r + 16.0, -clock * 1.1 + 1.0, -clock * 1.1 + 1.0 + PI * 0.7, 40, Color(0.6, 0.85, 0.85, 0.65), 3.0, true)
	for i in range(3):
		var a := clock * 2.2 + float(i) * TAU / 3.0
		draw_circle(lc + Vector2(cos(a), sin(a)) * (ring_r + 32.0), 5.0 - float(i), Color(1.0, 0.92, 0.75, 0.9))
	# полоса прогресса
	var back := UI.style(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 6, 0, Vector4(0, 0, 0, 0))
	draw_style_box(back, bar_rect)
	var fill_w := maxf(12.0, bar_rect.size.x * shown)
	var fill := UI.style(Color("#e4b475"), Color(0, 0, 0, 0), 6, 0, Vector4(0, 0, 0, 0))
	draw_style_box(fill, Rect2(bar_rect.position, Vector2(fill_w, bar_rect.size.y)))
	draw_circle(bar_rect.position + Vector2(fill_w, bar_rect.size.y * 0.5), 9.0, Color("#fff0d6"))


func draw_arc_ellipse(center: Vector2, radii: Vector2, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in range(65):
		var a := float(i) / 64.0 * TAU
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_polyline(pts, color, width, true)
