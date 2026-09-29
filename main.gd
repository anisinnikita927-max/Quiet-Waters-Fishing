extends Node3D

enum FishingState { READY, CHARGING, WAITING, BITE, FIGHT }

const WATER_SHADER := """
shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec4 deep_tint : source_color = vec4(0.035, 0.20, 0.25, 1.0);
uniform vec4 light_tint : source_color = vec4(0.18, 0.40, 0.41, 1.0);
varying vec3 world_position;

void vertex() {
	vec3 p = VERTEX;
	float swell = sin(p.x * 0.21 + TIME * 0.62) * 0.045;
	swell += cos(p.z * 0.28 + TIME * 0.47) * 0.032;
	swell += sin((p.x + p.z) * 0.12 + TIME * 0.32) * 0.018;
	VERTEX.y += swell;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float long_glint = sin(world_position.x * 0.11 + world_position.z * 0.08 + TIME * 0.15) * 0.5 + 0.5;
	float fine_glint = sin(world_position.x * 0.52 - world_position.z * 0.34 + TIME * 0.72) * 0.5 + 0.5;
	float shimmer = smoothstep(0.38, 0.94, long_glint) * 0.52 + fine_glint * 0.12;
	ALBEDO = mix(deep_tint.rgb, light_tint.rgb, shimmer);
	METALLIC = 0.18;
	ROUGHNESS = 0.22;
	SPECULAR = 0.75;
}
"""

const SPECIES := ["ОКУНЬ", "ЛЕЩ", "ЩУКА", "КАРАСЬ"]
const SPECIES_COLORS := [Color("#e2a15e"), Color("#aabb9b"), Color("#a4c2a8"), Color("#e1c17a")]
const LAKES := [
	{"name": "Лесное озеро", "card": "ЛЕСНОЕ ОЗЕРО\nТёплый закат • щука и окунь\nМузыка: Сосны у воды", "music": "res://audio/forest_lake.wav", "water_deep": "#123e4d", "water_light": "#589a91", "sky_top": "#365b78", "sky_horizon": "#e6a579", "ground_bottom": "#142d38", "ground_horizon": "#88766e", "fog": "#c5947b", "sun": "#ffd3a0", "hill": "#354944", "sand": "#9b8062", "dock": "#8b6041", "dock_light": "#b17a50", "leaf_a": "#425b4b", "leaf_b": "#62724e", "pine_dark": "#263f39", "pine_light": "#34524a", "rock": "#68716a", "seed": 31415, "season": "ЗОЛОТАЯ ОСЕНЬ"},
	{"name": "Горное озеро", "card": "ГОРНОЕ ОЗЕРО\nХрустальный воздух • форель\nМузыка: Эхо вершин", "music": "res://audio/mountain_lake.wav", "water_deep": "#13314d", "water_light": "#4785a2", "sky_top": "#244c73", "sky_horizon": "#a8cbd3", "ground_bottom": "#142936", "ground_horizon": "#647d83", "fog": "#9bbec3", "sun": "#d9efff", "hill": "#4a626b", "sand": "#7d9895", "dock": "#576e78", "dock_light": "#9ab5b6", "leaf_a": "#496954", "leaf_b": "#70856c", "pine_dark": "#234451", "pine_light": "#376778", "rock": "#8da4a7", "seed": 27182, "season": "ГОРНЫЙ РАССВЕТ"},
	{"name": "Тростниковый залив", "card": "ТРОСТНИКОВЫЙ ЗАЛИВ\nТёплый туман • карась и лещ\nМузыка: Тихие камыши", "music": "res://audio/reed_bay.wav", "water_deep": "#254c47", "water_light": "#87ad82", "sky_top": "#526d75", "sky_horizon": "#e5bd8d", "ground_bottom": "#253a35", "ground_horizon": "#958a72", "fog": "#c7ac83", "sun": "#ffe0a0", "hill": "#4b5b42", "sand": "#ad9364", "dock": "#786046", "dock_light": "#ba9760", "leaf_a": "#617546", "leaf_b": "#8a8a4f", "pine_dark": "#34473d", "pine_light": "#53664a", "rock": "#8b8a70", "seed": 16180, "season": "ЛЕТНЯЯ ЗАВОДЬ"}
]
const FISH_BY_LAKE := [["ОКУНЬ", "ЩУКА", "ЛЕЩ"], ["ФОРЕЛЬ", "ХАРИУС", "ГОЛЕЦ"], ["КАРАСЬ", "ЛИНЬ", "ЛЕЩ"]]
const RODS := [
	{"name": "Бамбуковая поплавочная", "description": "Лёгкая и послушная. Хороша для спокойной рыбалки у берега.", "cast": 0.88, "reel": 0.25, "stress": 0.70, "max_weight": 2.8, "color": "#b79a5d", "price": 0},
	{"name": "Универсальный спиннинг", "description": "Надёжный баланс дальнего заброса и уверенной тяги.", "cast": 1.0, "reel": 0.29, "stress": 0.90, "max_weight": 4.5, "color": "#503e35", "price": 0},
	{"name": "Карповое удилище", "description": "Крепкий бланк и мягкая леска для крупной рыбы.", "cast": 1.14, "reel": 0.24, "stress": 0.62, "max_weight": 7.0, "color": "#39494e", "price": 0},
	{"name": "Лайт-спиннинг «Искра»", "description": "Очень лёгкая снасть: быстро выматывает, но любит аккуратную игру.", "cast": 1.03, "reel": 0.36, "stress": 1.05, "max_weight": 3.6, "color": "#53a99e", "price": 420},
	{"name": "Фидер «Тихая заводь»", "description": "Чувствительная вершинка и прочная оснастка для леща и линя.", "cast": 0.98, "reel": 0.30, "stress": 0.76, "max_weight": 5.4, "color": "#87935b", "price": 650},
	{"name": "Морской кастинг «Прибой»", "description": "Длинное мощное удилище для дальнего заброса и сильной рыбы.", "cast": 1.28, "reel": 0.27, "stress": 0.82, "max_weight": 7.8, "color": "#397c9c", "price": 950},
	{"name": "Трофейный карповик «Гигант»", "description": "Тяжёлое удилище с усиленным бланком для настоящих трофеев.", "cast": 1.20, "reel": 0.24, "stress": 0.60, "max_weight": 10.0, "color": "#8d5145", "price": 1400}
]

var rng := RandomNumberGenerator.new()
var state: FishingState = FishingState.READY
var charge_amount := 0.0
var wait_timer := 0.0
var bite_timer := 0.0
var fight_clock := 0.0
var fight_progress := 0.0
var tension := 0.34
var reel_held := false
var fish_species := "ОКУНЬ"
var fish_weight := 0.0
var catches := 0
var best_weight := 0.0
var coins := 500
var owned_rods: Array[bool] = [true, true, true, false, false, false, false]
var elapsed := 0.0
var toast_timer := 0.0
var float_anchor := Vector3.ZERO
var selected_lake := 0
var selected_rod := 1
var game_started := false

var camera: Camera3D
var world_environment: WorldEnvironment
var sun_light: DirectionalLight3D
var map_root: Node3D
var bobber: Node3D
var line_mesh: MeshInstance3D
var rod_visual: MeshInstance3D
var arms_root: Node3D
var rod_tip := Vector3(1.10, 0.46, -2.10)
var music_player: AudioStreamPlayer

var ui_root: Control
var menu_root: Control
var menu_panel: Panel
var lake_buttons: Array[Button] = []
var selected_summary: Label
var music_slider: HSlider
var menu_start_button: Button
var menu_map_tab: Button
var menu_shop_tab: Button
var map_page: Control
var shop_page: Control
var shop_grid: GridContainer
var shop_status_label: Label
var wallet_label: Label
var rod_action_buttons: Array[Button] = []
var rod_price_labels: Array[Label] = []
var hud_lake_label: Label
var hud_season_label: Label
var hint_label: Label
var subhint_label: Label
var stats_label: Label
var toast_label: Label
var charge_bar: ColorRect
var charge_fill: ColorRect
var tension_bar: ColorRect
var tension_fill: ColorRect

func _ready() -> void:
	rng.randomize()
	_load_progress()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	map_root = Node3D.new()
	map_root.name = "Выбранное озеро"
	add_child(map_root)
	_build_environment()
	_build_map_scene()
	_build_rod()
	_build_first_person_arms()
	_build_ui()
	_build_menu()
	_build_music_player()
	_select_lake(0)
	_select_rod(selected_rod)
	_show_menu()
	get_viewport().size_changed.connect(_layout_ui)
	get_viewport().size_changed.connect(_layout_menu)
	_update_hud()

func _process(delta: float) -> void:
	if not game_started:
		return
	elapsed += delta
	if toast_timer > 0.0:
		toast_timer = maxf(0.0, toast_timer - delta)
		toast_label.modulate.a = minf(1.0, toast_timer * 1.6)
		if toast_timer == 0.0:
			toast_label.text = ""

	match state:
		FishingState.CHARGING:
			charge_amount = minf(1.0, charge_amount + delta * 0.52)
			charge_fill.size.x = charge_bar.size.x * charge_amount
		FishingState.WAITING:
			wait_timer -= delta
			if wait_timer <= 0.0:
				_start_bite()
		FishingState.BITE:
			bite_timer -= delta
			if bite_timer <= 0.0:
				_show_toast("РЫБА СОШЛА", "Попробуй забросить ещё раз", Color("#efb67f"))
				_reset_line()
		FishingState.FIGHT:
			fight_clock += delta
			_update_fight(delta)
		_:
			pass

	_animate_bobber()
	_animate_arms()
	_update_line()
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_M:
			if game_started:
				_show_menu()
			return
	if not game_started:
		return
	var press_started := false
	var press_ended := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		press_started = event.pressed and not event.is_echo()
		press_ended = not event.pressed
	elif event is InputEventScreenTouch and event.index == 0:
		press_started = event.pressed and not event.canceled
		press_ended = not event.pressed or event.canceled
	else:
		return
	if press_started:
		match state:
			FishingState.READY:
				state = FishingState.CHARGING
				charge_amount = 0.06
			FishingState.BITE:
				_start_fight()
			FishingState.FIGHT:
				reel_held = true
			_:
				pass
	elif press_ended:
		if state == FishingState.CHARGING:
			_cast_line()
		reel_held = false

func _build_environment() -> void:
	world_environment = WorldEnvironment.new()
	world_environment.name = "Атмосфера озера"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = _lake_color("sky_top")
	sky_mat.sky_horizon_color = _lake_color("sky_horizon")
	sky_mat.ground_bottom_color = _lake_color("ground_bottom")
	sky_mat.ground_horizon_color = _lake_color("ground_horizon")
	sky_mat.sun_angle_max = 14.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.28
	env.glow_bloom = 0.08
	env.fog_enabled = true
	env.fog_light_color = _lake_color("fog")
	env.fog_density = 0.006
	env.fog_sky_affect = 0.2
	world_environment.environment = env
	add_child(world_environment)

	sun_light = DirectionalLight3D.new()
	sun_light.name = "Свет над озером"
	sun_light.rotation_degrees = Vector3(-39.0, -27.0, 0.0)
	sun_light.light_color = _lake_color("sun")
	sun_light.light_energy = 1.35
	sun_light.shadow_enabled = true
	add_child(sun_light)

	camera = Camera3D.new()
	camera.name = "Камера рыбака"
	camera.position = Vector3(0.0, 2.25, 5.35)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.25, -22.0), Vector3.UP)
	camera.fov = 64.0
	add_child(camera)
	camera.make_current()

func _lake_color(key: String) -> Color:
	return Color(String(LAKES[selected_lake][key]))

func _apply_lake_atmosphere() -> void:
	var env := world_environment.environment
	var sky := env.sky
	var sky_mat := sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = _lake_color("sky_top")
	sky_mat.sky_horizon_color = _lake_color("sky_horizon")
	sky_mat.ground_bottom_color = _lake_color("ground_bottom")
	sky_mat.ground_horizon_color = _lake_color("ground_horizon")
	env.fog_light_color = _lake_color("fog")
	sun_light.light_color = _lake_color("sun")

func _build_map_scene() -> void:
	_build_lake()
	_build_shore()
	_build_dock()
	_build_forest()
	if selected_lake == 1:
		_build_mountains()
	elif selected_lake == 2:
		_build_reeds()

func _build_lake() -> void:
	var water_shader := Shader.new()
	water_shader.code = WATER_SHADER
	var water_mat := ShaderMaterial.new()
	water_mat.shader = water_shader
	water_mat.set_shader_parameter("deep_tint", _lake_color("water_deep"))
	water_mat.set_shader_parameter("light_tint", _lake_color("water_light"))
	var plane := PlaneMesh.new()
	plane.size = Vector2(220.0, 64.0)
	plane.subdivide_width = 160
	plane.subdivide_depth = 72
	var water := MeshInstance3D.new()
	water.name = "Озеро — живая вода"
	water.mesh = plane
	water.material_override = water_mat
	water.position = Vector3(0.0, -0.06, 7.0)
	map_root.add_child(water)

	var sun_disk_mat := _mat(Color("#ffd59a"), 0.4, 0.0, Color("#ffb979"), 0.65)
	_make_sphere(map_root, Vector3(-27.0, 10.2, -82.0), Vector3(4.3, 4.3, 0.6), sun_disk_mat, "Солнце на горизонте")

	var cloud_mat := _mat(_lake_color("sky_horizon").lightened(0.08), 0.95)
	for cloud in [Vector3(-18.0, 16.0, -68.0), Vector3(4.0, 19.0, -82.0), Vector3(27.0, 14.0, -76.0)]:
		_make_sphere(map_root, cloud, Vector3(9.0, 0.55, 1.6), cloud_mat, "Облако")
		_make_sphere(map_root, cloud + Vector3(4.0, 0.18, 0.2), Vector3(5.0, 0.42, 1.25), cloud_mat, "Облако")

func _build_shore() -> void:
	var ground_mat := _mat(_lake_color("hill").darkened(0.30), 1.0)
	var hill_mat := _mat(_lake_color("hill"), 1.0)
	var sand_mat := _mat(_lake_color("sand"), 0.95)
	_make_box(map_root, Vector3(240.0, 0.55, 18.0), Vector3(0.0, -0.35, -33.0), ground_mat, "Дальний берег")
	_make_box(map_root, Vector3(240.0, 0.10, 2.8), Vector3(0.0, -0.025, -24.45), sand_mat, "Тонкая полоса берега")
	_make_sphere(map_root, Vector3(-43.0, 2.5, -47.0), Vector3(27.0, 7.0, 8.0), hill_mat, "Холм слева")
	_make_sphere(map_root, Vector3(39.0, 2.0, -50.0), Vector3(31.0, 6.5, 9.0), hill_mat, "Холм справа")

func _build_dock() -> void:
	var wood := _mat(_lake_color("dock"), 0.88)
	var wood_light := _mat(_lake_color("dock_light"), 0.9)
	var wood_dark := _mat(Color("#543d32"), 0.92)
	var plank_count := 15
	for i in range(plank_count):
		var z := 3.45 - float(i) * 0.79
		var material: Material = wood_light if i % 3 == 0 else wood
		_make_box(map_root, Vector3(2.72, 0.18, 0.74), Vector3(0.0, 0.08, z), material, "Доска настила")
	_make_box(map_root, Vector3(0.18, 0.30, 11.9), Vector3(-1.45, 0.0, -2.1), wood_dark, "Левый брус")
	_make_box(map_root, Vector3(0.18, 0.30, 11.9), Vector3(1.45, 0.0, -2.1), wood_dark, "Правый брус")

	var post_mat := _mat(Color("#694a39"), 0.92)
	for z in [1.6, -2.5, -6.6]:
		for x in [-1.48, 1.48]:
			_make_cylinder(map_root, Vector3(x, 0.78, z), 0.23, 1.35, post_mat, "Опора причала")
			_make_sphere(map_root, Vector3(x, 1.48, z), Vector3(0.19, 0.18, 0.19), wood_light, "Шляпка опоры")

	var lamp_glow := _mat(Color("#ffdca3"), 0.35, 0.0, Color("#ffb45e"), 2.2)
	var lamp_frame := _mat(Color("#473c38"), 0.55, 0.45)
	for x in [-1.22, 1.22]:
		var lamp := _make_sphere(map_root, Vector3(x, 0.78, -3.7), Vector3(0.11, 0.18, 0.11), lamp_glow, "Тёплый фонарь")
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_make_box(map_root, Vector3(0.25, 0.035, 0.25), Vector3(x, 0.97, -3.7), lamp_frame, "Крышка фонаря")
		var glow := OmniLight3D.new()
		glow.light_color = Color("#ffbd72")
		glow.light_energy = 0.38
		glow.omni_range = 3.0
		glow.position = Vector3(x, 0.78, -3.7)
		map_root.add_child(glow)

func _build_rod() -> void:
	var grip_mat := _mat(Color("#342f30"), 0.72)
	var rod_mat := _mat(Color("#503e35"), 0.52, 0.2)
	var guide_mat := _mat(Color("#d4b885"), 0.4, 0.65)
	var first_person_rod := Node3D.new()
	first_person_rod.name = "Удочка в руках рыбака"
	camera.add_child(first_person_rod)
	var grip_start := Vector3(0.18, -0.77, -0.96)
	var grip_end := Vector3(0.42, -0.58, -1.12)
	_make_cylinder_between(first_person_rod, grip_start, grip_end, 0.060, 0.044, grip_mat, "Рукоять удочки")
	rod_visual = _make_cylinder_between(first_person_rod, grip_end, rod_tip, 0.038, 0.006, rod_mat, "Удилище")
	for t in [0.25, 0.48, 0.70, 0.89]:
		var p := grip_end.lerp(rod_tip, t)
		_make_sphere(first_person_rod, p, Vector3(0.022, 0.022, 0.022), guide_mat, "Кольцо удочки")

	var bobber_red := _mat(Color("#e95a48"), 0.28)
	var bobber_white := _mat(Color("#f5e9ce"), 0.34)
	bobber = Node3D.new()
	bobber.name = "Поплавок"
	add_child(bobber)
	var top := _make_sphere(bobber, Vector3(0.0, 0.10, 0.0), Vector3(0.105, 0.16, 0.105), bobber_red, "Красная часть")
	var bottom := _make_sphere(bobber, Vector3(0.0, -0.055, 0.0), Vector3(0.085, 0.12, 0.085), bobber_white, "Белая часть")
	_make_cylinder(bobber, Vector3(0.0, 0.245, 0.0), 0.018, 0.12, bobber_red, "Антенна поплавка")
	bobber.visible = false

	line_mesh = MeshInstance3D.new()
	line_mesh.name = "Леска"
	var line_mat := _mat(Color("#e6d3ac"), 0.6)
	var line_cyl := CylinderMesh.new()
	line_cyl.top_radius = 0.008
	line_cyl.bottom_radius = 0.008
	line_cyl.height = 1.0
	line_mesh.mesh = line_cyl
	line_mesh.material_override = line_mat
	line_mesh.visible = false
	add_child(line_mesh)

func _build_first_person_arms() -> void:
	arms_root = Node3D.new()
	arms_root.name = "Руки рыбака от первого лица"
	camera.add_child(arms_root)
	var jacket := _mat(Color("#48584b"), 0.95)
	var cuff := _mat(Color("#d1b486"), 0.8)
	var skin := _mat(Color("#d49a72"), 0.9)
	var nail := _mat(Color("#e4b391"), 0.85)
	_make_cylinder_between(arms_root, Vector3(-1.22, -1.16, -1.52), Vector3(0.20, -0.72, -1.02), 0.22, 0.14, jacket, "Левый рукав")
	_make_cylinder_between(arms_root, Vector3(1.26, -1.20, -1.55), Vector3(0.65, -0.62, -1.02), 0.23, 0.14, jacket, "Правый рукав")
	_make_cylinder_between(arms_root, Vector3(0.12, -0.74, -1.00), Vector3(0.35, -0.62, -1.06), 0.15, 0.12, cuff, "Манжета левой руки")
	_make_cylinder_between(arms_root, Vector3(0.53, -0.61, -1.03), Vector3(0.70, -0.51, -1.06), 0.14, 0.11, cuff, "Манжета правой руки")
	_make_sphere(arms_root, Vector3(0.37, -0.63, -1.10), Vector3(0.13, 0.085, 0.085), skin, "Ладонь на рукояти")
	_make_sphere(arms_root, Vector3(0.69, -0.51, -1.12), Vector3(0.12, 0.080, 0.085), skin, "Ладонь на катушке")
	for finger in range(3):
		var offset := float(finger) * 0.045
		_make_cylinder_between(arms_root, Vector3(0.31 + offset, -0.61, -1.12), Vector3(0.43 + offset, -0.67, -1.16), 0.034, 0.028, nail, "Пальцы на рукояти")
		_make_cylinder_between(arms_root, Vector3(0.63 + offset, -0.50, -1.14), Vector3(0.73 + offset, -0.56, -1.16), 0.030, 0.026, nail, "Пальцы на катушке")
	_make_sphere(arms_root, Vector3(0.27, -0.66, -1.11), Vector3(0.065, 0.050, 0.055), skin, "Большой палец")

func _animate_arms() -> void:
	if arms_root == null:
		return
	var lift := charge_amount * 0.07 if state == FishingState.CHARGING else 0.0
	if state == FishingState.FIGHT:
		lift += sin(fight_clock * 4.2) * 0.035
	arms_root.position.y = sin(elapsed * 1.4) * 0.014 + lift
	arms_root.rotation.z = sin(elapsed * 0.8) * 0.008

func _build_forest() -> void:
	var trunk := _mat(Color(_lake_color("sand")).darkened(0.45), 1.0)
	var pine_dark := _mat(_lake_color("pine_dark"), 1.0)
	var pine_light := _mat(_lake_color("pine_light"), 1.0)
	var leaf_a := _mat(_lake_color("leaf_a"), 1.0)
	var leaf_b := _mat(_lake_color("leaf_b"), 1.0)
	var rock_mat := _mat(_lake_color("rock"), 1.0)
	var positions := [
		Vector2(-41, -31), Vector2(-35, -28), Vector2(-28, -32), Vector2(-22, -29),
		Vector2(-16, -31), Vector2(-10, -29), Vector2(-4, -32), Vector2(3, -30),
		Vector2(9, -32), Vector2(15, -29), Vector2(22, -31), Vector2(29, -28),
		Vector2(36, -32), Vector2(43, -30), Vector2(-50, -36), Vector2(50, -36)
	]
	for i in range(positions.size()):
		var point: Vector2 = positions[i]
		var scale := 0.78 + float((i * 7) % 5) * 0.11
		var pine_ratio := 2 if selected_lake == 1 else 3
		_add_tree(point.x, point.y, scale, trunk, pine_dark if i % pine_ratio == 0 else pine_light, leaf_a if i % 2 == 0 else leaf_b, i % pine_ratio == 0)

	for i in range(20):
		var x := -48.0 + float(i) * 5.0 + rng.randf_range(-1.4, 1.4)
		var z := -37.0 + rng.randf_range(-2.0, 2.0)
		_make_sphere(map_root, Vector3(x, -0.02, z), Vector3(rng.randf_range(0.6, 1.1), rng.randf_range(0.35, 0.7), rng.randf_range(0.45, 0.9)), leaf_a, "Береговой куст")
	for i in range(11):
		var x := -23.0 + float(i) * 4.6
		var z := -25.1 - rng.randf_range(0.0, 0.8)
		_make_sphere(map_root, Vector3(x, 0.12, z), Vector3(rng.randf_range(0.30, 0.62), rng.randf_range(0.18, 0.34), rng.randf_range(0.28, 0.53)), rock_mat, "Камень у воды")

func _add_tree(x: float, z: float, scale: float, trunk_mat: Material, dark_mat: Material, light_mat: Material, pine: bool) -> void:
	var height := 5.2 * scale
	_make_cylinder(map_root, Vector3(x, height * 0.34, z), 0.32 * scale, height * 0.68, trunk_mat, "Ствол")
	if pine:
		for tier in range(3):
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = (1.9 - float(tier) * 0.22) * scale
			cone.height = (2.5 - float(tier) * 0.12) * scale
			cone.radial_segments = 8
			var crown := MeshInstance3D.new()
			crown.mesh = cone
			crown.material_override = dark_mat if tier % 2 == 0 else light_mat
			crown.position = Vector3(x, height * 0.38 + float(tier) * 1.15 * scale + 1.0 * scale, z)
			map_root.add_child(crown)
	else:
		var crown_positions := [Vector3(0.0, 0.0, 0.0), Vector3(-0.72, -0.28, 0.18), Vector3(0.64, -0.2, -0.16)]
		for j in range(crown_positions.size()):
			var p: Vector3 = crown_positions[j]
			var crown_mat: Material = dark_mat if j % 2 == 0 else light_mat
			_make_sphere(map_root, Vector3(x + p.x * scale, height * 0.77 + p.y * scale, z + p.z * scale), Vector3(1.28, 1.38, 1.12) * scale, crown_mat, "Крона дерева")

func _build_mountains() -> void:
	var stone := _mat(_lake_color("hill").darkened(0.20), 1.0)
	var snow := _mat(Color("#dce8e0"), 0.96)
	for peak: Vector3 in [Vector3(-48.0, 9.5, -58.0), Vector3(-21.0, 7.0, -62.0), Vector3(37.0, 10.0, -60.0), Vector3(56.0, 7.5, -55.0)]:
		var height: float = peak.y * 2.0
		var mountain := CylinderMesh.new()
		mountain.top_radius = 0.0
		mountain.bottom_radius = 11.5 + peak.y * 0.42
		mountain.height = height
		mountain.radial_segments = 6
		var mesh := MeshInstance3D.new()
		mesh.name = "Горная вершина"
		mesh.mesh = mountain
		mesh.material_override = stone
		mesh.position = peak
		map_root.add_child(mesh)
		var cap := CylinderMesh.new()
		cap.top_radius = 0.0
		cap.bottom_radius = 5.2
		cap.height = 5.0
		cap.radial_segments = 6
		var cap_mesh := MeshInstance3D.new()
		cap_mesh.mesh = cap
		cap_mesh.material_override = snow
		cap_mesh.position = peak + Vector3(0.0, height * 0.36, 0.0)
		map_root.add_child(cap_mesh)

func _build_reeds() -> void:
	var reed_mat := _mat(_lake_color("leaf_b"), 0.94)
	var seed_mat := _mat(_lake_color("sand").darkened(0.25), 0.92)
	for cluster: Vector2 in [Vector2(-18.0, -23.5), Vector2(-10.0, -24.0), Vector2(9.0, -23.8), Vector2(19.0, -23.4), Vector2(27.0, -24.0)]:
		for i in range(5):
			var x: float = cluster.x + float(i - 2) * 0.28
			var z: float = cluster.y + float((i % 2)) * 0.32
			var height: float = 1.8 + float((i * 7) % 5) * 0.31
			var top := Vector3(x + (float(i % 3) - 1.0) * 0.18, height, z)
			_make_cylinder_between(map_root, Vector3(x, 0.02, z), top, 0.035, 0.018, reed_mat, "Стебель камыша")
			_make_sphere(map_root, top, Vector3(0.07, 0.25, 0.07), seed_mat, "Метёлка камыша")

func _build_ui() -> void:
	ui_root = Control.new()
	ui_root.name = "Игровой интерфейс"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.visible = false
	add_child(_canvas_layer(ui_root))

	var top_left := _panel(ui_root, Vector2.ZERO, Vector2(292, 98), Color(0.035, 0.075, 0.09, 0.78))
	_add_label(top_left, "QUIET WATERS", Vector2(18, 11), Vector2(255, 34), 22, Color("#f4dfbf"))
	hud_lake_label = _add_label(top_left, "", Vector2(20, 51), Vector2(250, 21), 12, Color("#aac0ba"))
	hud_season_label = _add_label(top_left, "", Vector2(20, 72), Vector2(250, 18), 10, Color("#d49f71"))

	var top_right := _panel(ui_root, Vector2.ZERO, Vector2(228, 114), Color(0.035, 0.075, 0.09, 0.78))
	_add_label(top_right, "ВАШ УЛОВ", Vector2(16, 12), Vector2(196, 22), 12, Color("#aac0ba"))
	stats_label = _add_label(top_right, "0 рыб  ·  рекорд —", Vector2(16, 38), Vector2(196, 64), 15, Color("#f4dfbf"))

	var bottom := _panel(ui_root, Vector2.ZERO, Vector2(548, 112), Color(0.025, 0.055, 0.07, 0.84))
	hint_label = _add_label(bottom, "ЗАЖМИ ЛКМ — ЗАРЯДИ • ОТПУСТИ — ЗАБРОСЬ", Vector2(18, 13), Vector2(512, 30), 15, Color("#f5dfbf"))
	subhint_label = _add_label(bottom, "Чем дольше держишь, тем дальше летит поплавок", Vector2(18, 45), Vector2(512, 22), 12, Color("#a9c0ba"))
	charge_bar = _make_bar(bottom, Vector2(18, 79), Vector2(512, 12), Color("#e4ad6e"))
	charge_fill = charge_bar.get_meta("fill") as ColorRect
	tension_bar = _make_bar(bottom, Vector2(18, 79), Vector2(512, 12), Color("#77c7b3"))
	tension_fill = tension_bar.get_meta("fill") as ColorRect
	tension_bar.visible = false
	charge_bar.visible = false

	toast_label = _add_label(ui_root, "", Vector2.ZERO, Vector2(620, 66), 30, Color("#fff0d6"))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_shadow_color", Color(0.04, 0.08, 0.1, 0.9))
	toast_label.add_theme_constant_override("shadow_offset_x", 1)
	toast_label.add_theme_constant_override("shadow_offset_y", 2)

	var reticle := Control.new()
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.name = "Прицел"
	reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(reticle)
	var dot := ColorRect.new()
	dot.color = Color(0.98, 0.9, 0.72, 0.85)
	dot.position = Vector2(-2.0, -2.0)
	dot.size = Vector2(4.0, 4.0)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.add_child(dot)
	_layout_ui()

func _canvas_layer(content: Control, layer_index: int = 5) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = layer_index
	layer.add_child(content)
	return layer

func _make_bar(parent: Control, position: Vector2, size: Vector2, color: Color) -> ColorRect:
	var back := ColorRect.new()
	back.position = position
	back.size = size
	back.color = Color(0.85, 0.92, 0.88, 0.13)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(back)
	var fill := ColorRect.new()
	fill.position = Vector2.ZERO
	fill.size = Vector2(0.0, size.y)
	fill.color = color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(fill)
	back.set_meta("fill", fill)
	return back

func _layout_ui() -> void:
	if ui_root == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var panels := ui_root.get_children()
	if panels.size() < 4:
		return
	var top_left: Control = panels[0]
	var top_right: Control = panels[1]
	var bottom: Control = panels[2]
	top_left.position = Vector2(26, 22)
	top_right.position = Vector2(viewport_size.x - 254, 22)
	bottom.position = Vector2((viewport_size.x - 548) * 0.5, viewport_size.y - 136)
	toast_label.position = Vector2((viewport_size.x - toast_label.size.x) * 0.5, viewport_size.y * 0.20)
	if panels.size() > 4:
		var reticle: Control = panels[4]
		if reticle.get_child_count() > 0:
			reticle.get_child(0).position = viewport_size * 0.5 - Vector2(2.0, 2.0)

func _build_menu() -> void:
	menu_root = Control.new()
	menu_root.name = "Главное меню"
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_canvas_layer(menu_root, 12))
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.035, 0.045, 0.70)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_root.add_child(shade)
	menu_panel = _panel(menu_root, Vector2.ZERO, Vector2(1320, 820), Color(0.035, 0.075, 0.09, 0.97))
	var panel_style := menu_panel.get_theme_stylebox("panel") as StyleBoxFlat
	panel_style.bg_color = Color(0.035, 0.075, 0.09, 0.98)
	panel_style.border_color = Color(0.77, 0.68, 0.51, 0.45)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(22)

	_add_label(menu_panel, "QUIET WATERS", Vector2(58, 26), Vector2(700, 53), 40, Color("#f4dfbf"))
	_add_label(menu_panel, "ВЫБЕРИ ОЗЕРО ИЛИ ЗАГЛЯНИ В МАГАЗИН", Vector2(62, 79), Vector2(800, 26), 15, Color("#a9c0ba"))
	wallet_label = _add_label(menu_panel, "МОНЕТЫ  •  %d" % coins, Vector2(975, 45), Vector2(285, 32), 17, Color("#e4b475"))
	menu_map_tab = _menu_choice_button(menu_panel, "ОЗЁРА", Vector2(62, 117), Vector2(190, 44), 15)
	menu_shop_tab = _menu_choice_button(menu_panel, "МАГАЗИН", Vector2(264, 117), Vector2(190, 44), 15)
	menu_map_tab.pressed.connect(_set_menu_tab.bind("map"))
	menu_shop_tab.pressed.connect(_set_menu_tab.bind("shop"))

	map_page = Control.new()
	map_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_panel.add_child(map_page)
	_add_label(map_page, "ВЫБЕРИ МЕСТО, ГДЕ СЕГОДНЯ КЛЮНЕТ", Vector2(62, 171), Vector2(850, 24), 16, Color("#e4b475"))
	var card_width := 376.0
	var card_gap := 22.0
	for i in range(LAKES.size()):
		var button := _menu_choice_button(map_page, String(LAKES[i]["card"]), Vector2(62.0 + float(i) * (card_width + card_gap), 207), Vector2(card_width, 190), 19)
		button.pressed.connect(_on_lake_button.bind(i))
		lake_buttons.append(button)
	selected_summary = _add_label(map_page, "", Vector2(62, 423), Vector2(810, 30), 15, Color("#d9e2d7"))
	_add_label(map_page, "НА КАЖДОМ ОЗЕРЕ СВОЯ МУЗЫКА", Vector2(62, 480), Vector2(370, 24), 12, Color("#aac0ba"))
	music_slider = HSlider.new()
	music_slider.position = Vector2(62, 511)
	music_slider.size = Vector2(260, 24)
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.01
	music_slider.value = 0.55
	music_slider.value_changed.connect(_on_music_volume_changed)
	map_page.add_child(music_slider)
	_add_label(map_page, "Перед рыбалкой снасти можно сменить в магазине", Vector2(62, 582), Vector2(620, 25), 13, Color("#819993"))
	menu_start_button = _menu_choice_button(map_page, "НАЧАТЬ РЫБАЛКУ   →", Vector2(870, 632), Vector2(388, 86), 22)
	menu_start_button.pressed.connect(_start_fishing)

	shop_page = Control.new()
	shop_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_page.visible = false
	menu_panel.add_child(shop_page)
	_add_label(shop_page, "СНАСТИ ДЛЯ ЛЮБОГО ОЗЕРА", Vector2(62, 171), Vector2(700, 24), 16, Color("#e4b475"))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(62, 202)
	scroll.size = Vector2(1196, 506)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shop_page.add_child(scroll)
	shop_grid = GridContainer.new()
	shop_grid.columns = 2
	shop_grid.add_theme_constant_override("h_separation", 16)
	shop_grid.add_theme_constant_override("v_separation", 14)
	shop_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(shop_grid)
	for i in range(RODS.size()):
		shop_grid.add_child(_create_shop_card(i))
	shop_status_label = _add_label(shop_page, "", Vector2(62, 721), Vector2(1196, 26), 13, Color("#d9e2d7"))
	_update_shop_cards()
	_update_menu_cards()
	_set_menu_tab("map")
	_layout_menu()

func _create_shop_card(index: int) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(586, 210)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.055, 0.105, 0.12, 0.96)
	card_style.border_color = Color(0.56, 0.68, 0.65, 0.46)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(15)
	card.add_theme_stylebox_override("panel", card_style)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var preview := SubViewportContainer.new()
	preview.custom_minimum_size = Vector2(164, 176)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.stretch = true
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(preview)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(164, 176)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview.add_child(viewport)
	_build_rod_preview(viewport, index)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)
	var name_label := Label.new()
	name_label.text = String(RODS[index]["name"])
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color("#f4dfbf"))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(name_label)
	var desc_label := Label.new()
	desc_label.text = String(RODS[index]["description"])
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color("#b7c8c1"))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size.y = 38
	info.add_child(desc_label)
	var stats_label := Label.new()
	stats_label.text = "Заброс %d%%  •  Тяга %d%%\nТрофей до %.1f кг" % [int(float(RODS[index]["cast"]) * 100.0), int(float(RODS[index]["reel"]) * 100.0), float(RODS[index]["max_weight"])]
	stats_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_color_override("font_color", Color("#e4b475"))
	info.add_child(stats_label)
	var price_label := Label.new()
	price_label.add_theme_font_size_override("font_size", 11)
	price_label.add_theme_color_override("font_color", Color("#a9c0ba"))
	price_label.custom_minimum_size.y = 17
	info.add_child(price_label)
	var action := Button.new()
	action.custom_minimum_size = Vector2(0, 36)
	action.add_theme_font_size_override("font_size", 13)
	action.add_theme_color_override("font_color", Color("#f4dfbf"))
	action.add_theme_stylebox_override("normal", _menu_button_style(false))
	action.add_theme_stylebox_override("hover", _menu_button_style(false, true))
	action.add_theme_stylebox_override("pressed", _menu_button_style(true))
	action.pressed.connect(_on_rod_action.bind(index))
	info.add_child(action)
	rod_action_buttons.append(action)
	rod_price_labels.append(price_label)
	return card

func _build_rod_preview(viewport: SubViewport, index: int) -> void:
	viewport.own_world_3d = true
	var root := Node3D.new()
	root.name = "3D-превью удочки"
	viewport.add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#1d3035")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b8c9be")
	env.ambient_light_energy = 0.8
	var world := WorldEnvironment.new()
	world.environment = env
	root.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-34.0, -24.0, 0.0)
	light.light_color = Color("#ffe0b3")
	light.light_energy = 1.7
	root.add_child(light)
	var camera_preview := Camera3D.new()
	camera_preview.position = Vector3(0.25, 0.2, 4.4)
	camera_preview.look_at_from_position(camera_preview.position, Vector3.ZERO, Vector3.UP)
	camera_preview.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera_preview.size = 2.85
	root.add_child(camera_preview)
	camera_preview.make_current()
	var body_color := Color(String(RODS[index]["color"]))
	var body := _mat(body_color, 0.38, 0.28)
	var grip := _mat(Color("#363536"), 0.9)
	var metal := _mat(Color("#d9bf8c"), 0.34, 0.72)
	var spool_mat := _mat(body_color.lightened(0.27), 0.38, 0.45)
	var thicknesses := [0.040, 0.047, 0.060, 0.032, 0.052, 0.068, 0.078]
	var thickness: float = thicknesses[index]
	_make_cylinder_between(root, Vector3(-0.94, -0.70, 0.0), Vector3(0.88, 0.66, 0.0), thickness, 0.004, body, "Бланк удилища")
	_make_cylinder_between(root, Vector3(-0.94, -0.70, 0.0), Vector3(-0.38, -0.30, 0.0), thickness * 1.85, thickness * 1.3, grip, "Рукоять")
	for t in [0.26, 0.45, 0.62, 0.77, 0.89]:
		var point := Vector3(-0.94, -0.70, 0.0).lerp(Vector3(0.88, 0.66, 0.0), t)
		_make_sphere(root, point, Vector3(0.045, 0.045, 0.045), metal, "Кольцо бланка")
	var reel := MeshInstance3D.new()
	var spool := CylinderMesh.new()
	spool.top_radius = 0.17 if index >= 5 else 0.13
	spool.bottom_radius = spool.top_radius
	spool.height = 0.12
	spool.radial_segments = 16
	reel.mesh = spool
	reel.material_override = spool_mat
	reel.position = Vector3(-0.20, -0.08, 0.12)
	reel.quaternion = Quaternion(Vector3.UP, Vector3.FORWARD)
	root.add_child(reel)
	_make_cylinder_between(root, Vector3(-0.20, -0.08, 0.0), Vector3(-0.20, -0.08, 0.13), 0.07, 0.07, metal, "Катушка ось")
	_make_cylinder_between(root, Vector3(-0.20, -0.08, 0.16), Vector3(-0.38, -0.20, 0.16), 0.022, 0.022, metal, "Ручка катушки")
	_make_sphere(root, Vector3(-0.39, -0.21, 0.16), Vector3(0.055, 0.055, 0.055), grip, "Ручка катушки")

func _menu_choice_button(parent: Control, text: String, position: Vector2, size: Vector2, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.position = position
	button.size = size
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color("#e9e4d7"))
	button.add_theme_color_override("font_hover_color", Color("#fff2d7"))
	button.add_theme_color_override("font_pressed_color", Color("#fff2d7"))
	button.add_theme_stylebox_override("normal", _menu_button_style(false))
	button.add_theme_stylebox_override("hover", _menu_button_style(false, true))
	button.add_theme_stylebox_override("pressed", _menu_button_style(true))
	button.add_theme_stylebox_override("focus", _menu_button_style(true))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(button)
	return button

func _menu_button_style(selected: bool, hovered: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.14, 0.15, 0.96) if selected else Color(0.055, 0.105, 0.12, 0.92)
	if hovered:
		style.bg_color = Color(0.10, 0.17, 0.17, 0.98)
	style.border_color = Color("#e4b475") if selected else Color(0.56, 0.68, 0.65, 0.46)
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(16)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	return style

func _on_lake_button(index: int) -> void:
	_select_lake(index)

func _set_menu_tab(tab_name: String) -> void:
	var show_shop := tab_name == "shop"
	map_page.visible = not show_shop
	shop_page.visible = show_shop
	menu_map_tab.add_theme_stylebox_override("normal", _menu_button_style(not show_shop))
	menu_map_tab.add_theme_stylebox_override("pressed", _menu_button_style(not show_shop))
	menu_shop_tab.add_theme_stylebox_override("normal", _menu_button_style(show_shop))
	menu_shop_tab.add_theme_stylebox_override("pressed", _menu_button_style(show_shop))
	if show_shop:
		_update_shop_cards()

func _select_lake(index: int) -> void:
	selected_lake = clampi(index, 0, LAKES.size() - 1)
	rng.seed = int(LAKES[selected_lake]["seed"])
	for child in map_root.get_children():
		map_root.remove_child(child)
		child.queue_free()
	_apply_lake_atmosphere()
	_build_map_scene()
	hud_lake_label.text = String(LAKES[selected_lake]["name"]).to_upper()
	hud_season_label.text = "СЕЗОН  •  " + String(LAKES[selected_lake]["season"])
	if music_player != null:
		music_player.stop()
		var stream := load(String(LAKES[selected_lake]["music"])) as AudioStreamWAV
		if stream != null:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = stream.data.size() >> 1
			music_player.stream = stream
			music_player.play()
	_update_menu_cards()

func _select_rod(index: int) -> void:
	if index < 0 or index >= RODS.size() or not owned_rods[index]:
		return
	selected_rod = clampi(index, 0, RODS.size() - 1)
	if rod_visual != null:
		rod_visual.material_override = _mat(Color(String(RODS[selected_rod]["color"])), 0.52, 0.2)
	_update_menu_cards()
	_update_shop_cards()
	_save_progress()

func _update_menu_cards() -> void:
	for i in range(lake_buttons.size()):
		lake_buttons[i].add_theme_stylebox_override("normal", _menu_button_style(i == selected_lake))
		lake_buttons[i].add_theme_stylebox_override("pressed", _menu_button_style(i == selected_lake))
	if selected_summary != null:
		selected_summary.text = "ОЗЕРО: %s     •     УДОЧКА: %s" % [String(LAKES[selected_lake]["name"]).to_upper(), String(RODS[selected_rod]["name"]).to_upper()]
	_refresh_wallet()

func _on_rod_action(index: int) -> void:
	if owned_rods[index]:
		_select_rod(index)
		shop_status_label.text = "Экипирована: %s" % String(RODS[index]["name"])
		return
	var price := int(RODS[index]["price"])
	if coins < price:
		shop_status_label.text = "Не хватает %d монет. Поймай рыбу, чтобы заработать." % (price - coins)
		return
	coins -= price
	owned_rods[index] = true
	_select_rod(index)
	shop_status_label.text = "Куплена и экипирована: %s" % String(RODS[index]["name"])
	_save_progress()
	_update_shop_cards()

func _update_shop_cards() -> void:
	if rod_action_buttons.is_empty():
		return
	for i in range(rod_action_buttons.size()):
		var button := rod_action_buttons[i]
		if owned_rods[i]:
			button.text = "ЭКИПИРОВАНА" if i == selected_rod else "ЭКИПИРОВАТЬ"
			button.disabled = false
			rod_price_labels[i].text = "ДОСТУПНА" if int(RODS[i]["price"]) == 0 else "В КОЛЛЕКЦИИ"
			button.add_theme_color_override("font_color", Color("#f4dfbf"))
		else:
			var price := int(RODS[i]["price"])
			button.text = "КУПИТЬ  •  %d МОНЕТ" % price
			button.disabled = coins < price
			rod_price_labels[i].text = "ЦЕНА  •  %d МОНЕТ" % price
			button.add_theme_color_override("font_color", Color("#879993") if button.disabled else Color("#f4dfbf"))
	_refresh_wallet()

func _refresh_wallet() -> void:
	if wallet_label != null:
		wallet_label.text = "МОНЕТЫ  •  %d" % coins

func _load_progress() -> void:
	var save_file := ConfigFile.new()
	if save_file.load("user://fishing_progress.cfg") != OK:
		return
	coins = int(save_file.get_value("player", "coins", coins))
	var saved_rods: Variant = save_file.get_value("player", "owned_rods", owned_rods)
	if saved_rods is Array:
		for i in range(mini(saved_rods.size(), owned_rods.size())):
			owned_rods[i] = bool(saved_rods[i])
	selected_rod = clampi(int(save_file.get_value("player", "selected_rod", selected_rod)), 0, RODS.size() - 1)
	if not owned_rods[selected_rod]:
		selected_rod = 1

func _save_progress() -> void:
	var save_file := ConfigFile.new()
	save_file.set_value("player", "coins", coins)
	save_file.set_value("player", "owned_rods", owned_rods)
	save_file.set_value("player", "selected_rod", selected_rod)
	save_file.save("user://fishing_progress.cfg")

func _build_music_player() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "Музыка выбранной карты"
	music_player.volume_db = linear_to_db(0.55)
	add_child(music_player)

func _on_music_volume_changed(value: float) -> void:
	if music_player != null:
		music_player.volume_db = linear_to_db(maxf(value, 0.001))

func _start_fishing() -> void:
	game_started = true
	menu_root.visible = false
	ui_root.visible = true
	state = FishingState.READY
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var control_hint := "Зажми экран и отпусти для заброса" if OS.has_feature("android") else "Зажми и отпусти ЛКМ, чтобы забросить"
	_show_toast("УДОЧКА ГОТОВА", control_hint, Color("#f1cf9e"))

func _show_menu() -> void:
	if bobber != null and bobber.visible:
		_reset_line()
	game_started = false
	if ui_root != null:
		ui_root.visible = false
	if menu_root != null:
		menu_root.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_update_menu_cards()

func _layout_menu() -> void:
	if menu_panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	menu_panel.position = (viewport_size - menu_panel.size) * 0.5

func _update_hud() -> void:
	if hint_label == null:
		return
	var on_android := OS.has_feature("android")
	stats_label.text = "%d рыб  ·  рекорд %s\n%d монет" % [catches, ("%.1f кг" % best_weight) if best_weight > 0.0 else "—", coins]
	charge_bar.visible = state == FishingState.CHARGING
	tension_bar.visible = state == FishingState.FIGHT
	if state == FishingState.CHARGING:
		hint_label.text = "ОТПУСТИ ПАЛЕЦ, ЧТОБЫ ЗАБРОСИТЬ" if on_android else "ОТПУСТИ ЛКМ, ЧТОБЫ ЗАБРОСИТЬ"
		subhint_label.text = "Сила заброса: %d%%" % int(charge_amount * 100.0)
		charge_fill.size.x = charge_bar.size.x * charge_amount
	elif state == FishingState.WAITING:
		hint_label.text = "ПОПЛАВОК НА ВОДЕ"
		subhint_label.text = "Тихо... ждём поклёвку"
	elif state == FishingState.BITE:
		hint_label.text = "ПОКЛЁВКА! КОСНИСЬ ЭКРАНА, ЧТОБЫ ПОДСЕЧЬ" if on_android else "ПОКЛЁВКА! КЛИКНИ ЛКМ, ЧТОБЫ ПОДСЕЧЬ"
		subhint_label.text = "Не медли — рыба уже на крючке"
	elif state == FishingState.FIGHT:
		hint_label.text = "ВЫВАЖИВАНИЕ  ·  %d%%" % int(fight_progress * 100.0)
		subhint_label.text = "Держи палец; отпусти при сильном натяжении" if on_android else "Тяни ЛКМ и отпускай, если натяжение выше 75%"
		tension_fill.size.x = tension_bar.size.x * tension
		if tension > 0.78:
			tension_fill.color = Color("#ec795d")
		else:
			tension_fill.color = Color("#77c7b3")
	else:
		hint_label.text = "ЗАЖМИ ЭКРАН — ЗАРЯДИ • ОТПУСТИ — ЗАБРОСЬ" if on_android else "ЗАЖМИ ЛКМ — ЗАРЯДИ • ОТПУСТИ — ЗАБРОСЬ"
		subhint_label.text = "Чем дольше держишь, тем дальше летит поплавок"

func _cast_line() -> void:
	var distance := lerpf(7.0, 24.0, charge_amount) * float(RODS[selected_rod]["cast"])
	var aim := camera.global_position - camera.global_basis.z * distance
	aim.x += rng.randf_range(-0.55, 0.55)
	aim.y = 0.03
	aim.x = clampf(aim.x, -15.0, 15.0)
	aim.z = clampf(aim.z, -21.5, -8.7)
	float_anchor = aim
	bobber.position = float_anchor
	bobber.visible = true
	line_mesh.visible = true
	charge_amount = 0.0
	state = FishingState.WAITING
	wait_timer = rng.randf_range(5.0, 9.0)
	_show_toast("ЗАБРОС!", "Ждём поклёвку", Color("#f1cf9e"))

func _start_bite() -> void:
	state = FishingState.BITE
	bite_timer = 2.7
	_show_toast("ПОПЛАВОК ДЁРНУЛСЯ!", "Нажми ЛКМ, чтобы подсечь", Color("#ffd27f"))

func _start_fight() -> void:
	state = FishingState.FIGHT
	reel_held = true
	fight_clock = 0.0
	fight_progress = 0.08
	tension = 0.38
	var lake_species: Array = FISH_BY_LAKE[selected_lake]
	fish_species = String(lake_species[rng.randi_range(0, lake_species.size() - 1)])
	_show_toast("ЕСТЬ!", "Аккуратно вываживай", Color("#8ed7c2"))

func _update_fight(delta: float) -> void:
	var rod: Dictionary = RODS[selected_rod]
	var natural_pull := sin(fight_clock * 2.1) * 0.055 + sin(fight_clock * 0.73) * 0.035
	if reel_held:
		tension += delta * 0.21 * float(rod["stress"]) + natural_pull * delta * 2.0
		if tension < 0.80:
			fight_progress = minf(1.0, fight_progress + delta * float(rod["reel"]))
		else:
			fight_progress = maxf(0.0, fight_progress - delta * 0.13)
	else:
		tension -= delta * 0.27
		tension += natural_pull * delta
	tension = clampf(tension, 0.13, 1.0)
	if tension >= 0.97:
		_show_toast("ЛЕСКА НАТЯНУЛАСЬ!", "Отпусти кнопку на мгновение", Color("#f28b6d"))
		tension = 0.82
		fight_progress = maxf(0.0, fight_progress - 0.12)
	if fight_progress >= 1.0:
		_land_fish()

func _land_fish() -> void:
	fish_weight = rng.randf_range(0.45, float(RODS[selected_rod]["max_weight"]))
	catches += 1
	best_weight = maxf(best_weight, fish_weight)
	var reward := roundi(45.0 + fish_weight * 38.0)
	coins += reward
	_save_progress()
	_update_shop_cards()
	var index := SPECIES.find(fish_species)
	var tint: Color = SPECIES_COLORS[index] if index >= 0 else Color("#f2d4a7")
	_show_toast("ПОЙМАНА %s · %.1f КГ" % [fish_species, fish_weight], "+%d монет  •  всего: %d" % [reward, coins], tint)
	_reset_line()

func _reset_line() -> void:
	state = FishingState.READY
	reel_held = false
	charge_amount = 0.0
	bobber.visible = false
	line_mesh.visible = false

func _animate_bobber() -> void:
	if not bobber.visible:
		return
	var bob := sin(elapsed * 2.4) * 0.025
	if state == FishingState.BITE:
		bob = -0.08 - absf(sin(elapsed * 12.0)) * 0.11
	elif state == FishingState.FIGHT:
		bob = -0.045 + sin(elapsed * 9.0) * 0.075
	bobber.position = float_anchor + Vector3(0.0, bob, 0.0)
	bobber.rotation.z = sin(elapsed * 2.0) * 0.08

func _update_line() -> void:
	if line_mesh == null or not line_mesh.visible or not bobber.visible:
		return
	var start := camera.to_global(rod_tip)
	var finish := bobber.global_position + Vector3(0.0, 0.11, 0.0)
	var axis := finish - start
	line_mesh.position = (start + finish) * 0.5
	line_mesh.scale = Vector3.ONE
	line_mesh.quaternion = Quaternion(Vector3.UP, axis.normalized())
	var cylinder := line_mesh.mesh as CylinderMesh
	cylinder.height = axis.length()

func _show_toast(title: String, subtitle: String, color: Color) -> void:
	toast_label.text = title + "\n" + subtitle
	toast_label.add_theme_color_override("font_color", color)
	toast_timer = 2.6
	toast_label.modulate.a = 1.0

func _panel(parent: Control, position: Vector2, size: Vector2, color: Color) -> Panel:
	var panel := Panel.new()
	panel.position = position
	panel.size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.72, 0.79, 0.73, 0.24)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _add_label(parent: Control, text: String, position: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _mat(color: Color, roughness: float = 0.85, metallic: float = 0.0, emission: Color = Color.BLACK, emission_strength: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission_strength > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_strength
	return material

func _make_box(parent: Node3D, size: Vector3, position: Vector3, material: Material, node_name: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.name = node_name
	parent.add_child(instance)
	return instance

func _make_sphere(parent: Node3D, position: Vector3, dimensions: Vector3, material: Material, node_name: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.scale = dimensions
	instance.name = node_name
	parent.add_child(instance)
	return instance

func _make_cylinder(parent: Node3D, position: Vector3, radius: float, height: float, material: Material, node_name: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.88
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.name = node_name
	parent.add_child(instance)
	return instance

func _make_cylinder_between(parent: Node3D, from: Vector3, to: Vector3, radius_from: float, radius_to: float, material: Material, node_name: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius_from
	mesh.top_radius = radius_to
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 8
	instance.mesh = mesh
	instance.material_override = material
	instance.position = (from + to) * 0.5
	instance.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	instance.name = node_name
	parent.add_child(instance)
	return instance
