extends Node3D
## Живое озеро: круглые холмы, причал из брёвен, деревья, вода с рябью и погода.

const MU = preload("res://scripts/mesh_util.gd")
const Data = preload("res://scripts/game_data.gd")
const FishModel = preload("res://scripts/fish_model.gd")
const WATER_SHADER = preload("res://shaders/water.gdshader")
const AURORA_SHADER = preload("res://shaders/aurora.gdshader")
const MOUNTAIN_SHADER = preload("res://shaders/mountain.gdshader")

signal thunder

var lake: Dictionary = {}
var lake_index := 0
var rng := RandomNumberGenerator.new()
var clock := 0.0

var env: Environment
var sun_light: DirectionalLight3D
var water_mat: ShaderMaterial
var ripples := PackedVector4Array()
var drops := PackedVector4Array()
var ripple_cursor := 0
var drop_cursor := 0
var drop_rate := 0.0
var drop_accum := 0.0

var sway_nodes: Array = []   # {node, phase, amp, speed}
var cloud_nodes: Array = []
var bird_nodes: Array = []
var bobbers: Array = []      # {node, y, phase, spin}
var lamp_lights: Array = []
var star_layers: Array = []
var aurora_quads: Array = []
var weather_nodes: Array = []

var jump_timer := 6.0
var thunder_timer := 12.0
var flash := 0.0
var base_sun_energy := 1.35
var base_ambient := 0.55
var pending_thunder := -1.0


func build(index: int, environment: Environment, sun: DirectionalLight3D) -> void:
	lake_index = index
	lake = Data.LAKES[index]
	env = environment
	sun_light = sun
	rng.seed = int(lake["seed"])
	clock = 0.0
	ripples.resize(8)
	drops.resize(24)
	for i in range(8):
		ripples[i] = Vector4(0, 0, -100, 0)
	for i in range(24):
		drops[i] = Vector4(0, 0, -100, 0)
	_apply_atmosphere()
	_build_water()
	_build_sky()
	_build_shore()
	_build_dock()
	match String(lake["scenery"]):
		"winter":
			_build_forest(true)
			_build_ice()
		"mountain":
			_build_forest(false)
			_build_mountains()
		"reed":
			_build_forest(false)
			_build_reeds(6)
		"swamp":
			_build_forest(false)
			_build_reeds(9)
			_build_lilies()
			_build_swamp_trees()
		"hot":
			_build_forest(true, true)
			_build_terraces()
		"tropical":
			_build_palms()
			_build_islands()
		"autumn":
			_build_forest(false)
		_:
			_build_forest(false)
	_build_weather()
	if bool(lake.get("birds", false)):
		_build_birds()
	_push_ripples()


func _c(key: String) -> Color:
	return Color(String(lake[key]))


func _apply_atmosphere() -> void:
	var sky := env.sky
	var sky_mat := sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = _c("sky_top")
	sky_mat.sky_horizon_color = _c("sky_horizon")
	sky_mat.ground_bottom_color = _c("ground_bottom")
	sky_mat.ground_horizon_color = _c("ground_horizon")
	env.fog_light_color = _c("fog")
	env.fog_density = float(lake.get("fog_density", 0.006))
	base_sun_energy = float(lake.get("sun_energy", 1.35))
	base_ambient = float(lake.get("ambient_energy", 0.55))
	env.ambient_light_energy = base_ambient
	sun_light.light_color = _c("sun")
	sun_light.light_energy = base_sun_energy
	sun_light.rotation_degrees = Vector3(-39.0, -27.0, 0.0)
	env.glow_intensity = 0.55 if bool(lake.get("night", false)) else 0.28
	env.glow_bloom = 0.16 if bool(lake.get("night", false)) else 0.08


func _build_water() -> void:
	water_mat = ShaderMaterial.new()
	water_mat.shader = WATER_SHADER
	water_mat.set_shader_parameter("deep_tint", _c("water_deep"))
	water_mat.set_shader_parameter("light_tint", _c("water_light"))
	water_mat.set_shader_parameter("sky_tint", _c("sky_horizon").lerp(_c("sky_top"), 0.35))
	water_mat.set_shader_parameter("glint_tint", _c("sun"))
	var glint := 0.9
	if bool(lake.get("night", false)):
		glint = 0.55
	elif String(lake["weather"]) == "rain":
		glint = 0.15
	water_mat.set_shader_parameter("glint_power", glint)
	water_mat.set_shader_parameter("wave_amp", 1.7 if String(lake["weather"]) == "rain" else 1.0)
	water_mat.set_shader_parameter("drop_count", 24 if String(lake["weather"]) == "rain" else 0)
	var plane := PlaneMesh.new()
	plane.size = Vector2(240.0, 64.0)
	plane.subdivide_width = 110 if OS.has_feature("mobile") else 170
	plane.subdivide_depth = 48 if OS.has_feature("mobile") else 72
	var water := MeshInstance3D.new()
	water.name = "Озеро — живая вода"
	water.mesh = plane
	water.material_override = water_mat
	water.position = Vector3(0.0, -0.06, 7.0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _build_sky() -> void:
	var night := bool(lake.get("night", false))
	var weather := String(lake["weather"])
	if not night and weather != "rain":
		var sun_mat := MU.mat(Color("#ffd59a"), 0.4, 0.0, _c("sun").lerp(Color("#ffb979"), 0.5), 0.9)
		MU.sphere(self, Vector3(-27.0, 10.2, -82.0), Vector3(4.3, 4.3, 4.3), sun_mat, "Солнце", 32)
		var halo := MU.unshaded(Color(1.0, 0.85, 0.6, 0.12), true)
		MU.sphere(self, Vector3(-27.0, 10.2, -82.5), Vector3(9.5, 9.5, 2.0), halo, "Ореол солнца", 32)
	if night:
		if bool(lake.get("moon", false)):
			var moon_mat := MU.mat(Color("#f2eedc"), 0.6, 0.0, Color("#e8e4c8"), 1.1)
			MU.sphere(self, Vector3(-30.0, 26.0, -88.0), Vector3(3.4, 3.4, 3.4), moon_mat, "Луна", 32)
			var moon_halo := MU.unshaded(Color(0.75, 0.85, 1.0, 0.10), true)
			MU.sphere(self, Vector3(-30.0, 26.0, -89.0), Vector3(8.0, 8.0, 2.0), moon_halo, "Сияние луны", 32)
		_build_stars()
	if bool(lake.get("aurora", false)):
		_build_aurora()
	var cloud_color := _c("sky_horizon").lerp(Color.WHITE, 0.35)
	var cloud_count := 4
	if weather == "rain":
		cloud_color = Color("#5a6873")
		cloud_count = 9
	elif night:
		cloud_color = _c("sky_horizon").darkened(0.25)
		cloud_count = 3
	var cloud_mat := MU.mat(cloud_color, 0.95)
	for i in range(cloud_count):
		var group := Node3D.new()
		group.name = "Облако"
		var base := Vector3(rng.randf_range(-70.0, 70.0), rng.randf_range(15.0, 26.0), rng.randf_range(-92.0, -60.0))
		group.position = base
		add_child(group)
		for j in range(4):
			var s := rng.randf_range(3.0, 6.5)
			MU.sphere(group, Vector3(float(j) * 3.2 - 5.0, rng.randf_range(-0.4, 0.6), rng.randf_range(-0.8, 0.8)), Vector3(s, s * 0.42, s * 0.62), cloud_mat, "Пушистая часть", 16)
		cloud_nodes.append({"node": group, "speed": rng.randf_range(0.25, 0.7) * (2.5 if weather == "rain" else 1.0)})


func _build_stars() -> void:
	for layer in range(2):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var star_mesh := SphereMesh.new()
		var star := star_mesh
		star.radius = 0.3
		star.height = 0.6
		star.radial_segments = 6
		star.rings = 3
		var star_mat := MU.unshaded(Color("#ffffff"))
		star_mat.disable_fog = true
		star.material = star_mat
		mm.mesh = star
		mm.instance_count = 170
		for i in range(170):
			var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.14, 1.0), rng.randf_range(-1.0, 0.25)).normalized()
			var s := rng.randf_range(0.5, 1.4)
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), dir * 170.0))
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.name = "Звёзды"
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)
		star_layers.append({"mat": star_mat, "phase": float(layer) * PI})


func _build_aurora() -> void:
	for i in range(3):
		var quad := QuadMesh.new()
		quad.size = Vector2(320.0, 64.0)
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		var sm := ShaderMaterial.new()
		sm.shader = AURORA_SHADER
		sm.set_shader_parameter("speed", 0.8 + 0.25 * float(i))
		sm.set_shader_parameter("offset", float(i) * 3.7)
		sm.set_shader_parameter("color_a", Vector3(0.1, 1.0, 0.55) if i != 1 else Vector3(0.2, 0.8, 1.0))
		sm.set_shader_parameter("color_b", Vector3(0.65, 0.25, 0.95))
		mi.material_override = sm
		mi.position = Vector3(-30.0 + float(i) * 34.0, 50.0 + float(i) * 3.0, -120.0 + float(i) * 6.0)
		mi.rotation_degrees = Vector3(-8.0, float(i - 1) * 12.0, float(i - 1) * 5.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "Северное сияние"
		add_child(mi)
		aurora_quads.append(mi)


func _build_shore() -> void:
	var hill_col := _c("hill")
	var ground_mat := MU.mat(hill_col.darkened(0.25), 1.0)
	var hill_mat := MU.mat(hill_col, 1.0)
	var sand_mat := MU.mat(_c("sand"), 0.95)
	var snowy := String(lake["scenery"]) == "winter"
	# дальний берег — цепочка округлых холмов
	for i in range(-9, 10):
		var x := float(i) * 8.5 + rng.randf_range(-1.5, 1.5)
		var sx := rng.randf_range(6.5, 9.5)
		var sz := rng.randf_range(5.0, 8.0)
		var sy := rng.randf_range(1.0, 1.9)
		MU.sphere(self, Vector3(x, -0.55, -30.0 + rng.randf_range(-2.0, 2.5)), Vector3(sx, sy, sz), ground_mat if i % 2 == 0 else hill_mat, "Округлый берег", 24)
	# прибрежные песчаные горки
	for i in range(-6, 7):
		var x := float(i) * 6.2 + rng.randf_range(-1.2, 1.2)
		MU.sphere(self, Vector3(x, -0.12, -24.3 + rng.randf_range(-0.4, 0.4)), Vector3(rng.randf_range(3.0, 4.6), 0.34, rng.randf_range(1.2, 2.0)), sand_mat, "Песчаная отмель", 20)
	# большие холмы позади
	MU.sphere(self, Vector3(-43.0, 1.5, -49.0), Vector3(29.0, 8.5, 12.0), hill_mat, "Холм слева", 32)
	MU.sphere(self, Vector3(39.0, 1.2, -52.0), Vector3(32.0, 8.0, 12.0), hill_mat, "Холм справа", 32)
	MU.sphere(self, Vector3(0.0, -1.2, -68.0), Vector3(70.0, 10.0, 14.0), ground_mat, "Дальний холм", 32)
	# бухта: округлые берега по бокам
	MU.sphere(self, Vector3(-46.0, -1.3, -8.0), Vector3(21.0, 2.2, 22.0), ground_mat, "Левая бухта", 32)
	MU.sphere(self, Vector3(-40.0, -0.6, 4.0), Vector3(11.0, 1.4, 9.0), sand_mat, "Левый пляж", 28)
	MU.sphere(self, Vector3(46.0, -1.3, -6.0), Vector3(21.0, 2.2, 22.0), ground_mat, "Правая бухта", 32)
	MU.sphere(self, Vector3(41.0, -0.6, 5.0), Vector3(10.0, 1.3, 9.0), sand_mat, "Правый пляж", 28)
	if snowy:
		var snow_mat := MU.mat(Color("#f4f9fc"), 0.9)
		for i in range(-5, 6):
			MU.sphere(self, Vector3(float(i) * 9.0, 0.32, -26.2), Vector3(rng.randf_range(3.8, 5.6), 0.5, 1.9), snow_mat, "Сугроб", 20)


func _build_dock() -> void:
	var wood := MU.mat(_c("dock"), 0.88)
	var wood_light := MU.mat(_c("dock_light"), 0.9)
	var wood_dark := MU.mat(Color("#543d32"), 0.92)
	var snowy := String(lake["scenery"]) == "winter"
	var snow_mat := MU.mat(Color("#f4f9fc"), 0.9)
	var count := 30
	for i in range(count):
		var z := 3.55 - float(i) * 0.40
		var m: Material = wood_light if i % 3 == 0 else wood
		MU.capsule_between(self, Vector3(-1.2, 0.09, z), Vector3(1.2, 0.09, z), 0.17, m, "Круглая доска")
		if snowy and i % 2 == 0:
			MU.sphere(self, Vector3(rng.randf_range(-0.9, 0.9), 0.26, z), Vector3(rng.randf_range(0.45, 0.9), 0.07, 0.15), snow_mat, "Снег на доске", 12)
	MU.capsule_between(self, Vector3(-1.45, -0.02, 3.5), Vector3(-1.45, -0.02, -8.3), 0.14, wood_dark, "Левый брус")
	MU.capsule_between(self, Vector3(1.45, -0.02, 3.5), Vector3(1.45, -0.02, -8.3), 0.14, wood_dark, "Правый брус")
	var post_mat := MU.mat(Color("#694a39"), 0.92)
	for z in [1.6, -2.5, -6.6]:
		for x in [-1.48, 1.48]:
			MU.cylinder(self, Vector3(x, 0.78, z), 0.23, 1.35, post_mat, "Опора причала", 24, 0.94)
			MU.sphere(self, Vector3(x, 1.46, z), Vector3(0.24, 0.16, 0.24), snow_mat if snowy else wood_light, "Шляпка опоры", 20)
	var lamp_glow := MU.mat(Color("#ffdca3"), 0.35, 0.0, Color("#ffb45e"), 2.6 if bool(lake.get("night", false)) else 2.0)
	var lamp_frame := MU.mat(Color("#473c38"), 0.55, 0.45)
	for x in [-1.22, 1.22]:
		var lamp := MU.sphere(self, Vector3(x, 0.78, -3.7), Vector3(0.14, 0.2, 0.14), lamp_glow, "Тёплый фонарь", 20)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		MU.sphere(self, Vector3(x, 1.0, -3.7), Vector3(0.19, 0.06, 0.19), lamp_frame, "Крышка фонаря", 16)
		var glow := OmniLight3D.new()
		glow.light_color = Color("#ffbd72")
		glow.light_energy = 0.8 if bool(lake.get("night", false)) else 0.38
		glow.omni_range = 4.5 if bool(lake.get("night", false)) else 3.0
		glow.position = Vector3(x, 0.78, -3.7)
		add_child(glow)
		lamp_lights.append({"light": glow, "base": glow.light_energy, "phase": rng.randf() * TAU})
	# спасательный круг на опоре — круглая деталь
	var ring_mat := MU.mat(Color("#d9483b"), 0.5)
	var ring := MU.torus(self, Vector3(1.62, 1.0, -6.6), 0.07, 0.26, ring_mat, "Спасательный круг")
	ring.rotation_degrees = Vector3(0.0, 0.0, 90.0)


# --- Растительность -----------------------------------------------------
func _tree_positions() -> Array:
	var pts: Array = []
	for i in range(-8, 9):
		pts.append(Vector2(float(i) * 5.4 + rng.randf_range(-1.6, 1.6), -31.0 + rng.randf_range(-3.0, 3.0)))
	for i in range(-3, 4):
		var back := Vector2(float(i) * 7.0 + rng.randf_range(-1.5, 1.5), -38.0 + rng.randf_range(-2.0, 2.0))
		if not OS.has_feature("mobile") or i % 2 == 0:
			pts.append(back)
	pts.append(Vector2(-50.0, -14.0))
	pts.append(Vector2(-44.0, -20.0))
	pts.append(Vector2(50.0, -12.0))
	pts.append(Vector2(45.0, -19.0))
	pts.append(Vector2(-36.0, -4.0))
	pts.append(Vector2(38.0, -2.0))
	return pts


func _build_forest(snowy: bool, sparse: bool = false) -> void:
	var trunk := MU.mat(_c("sand").darkened(0.45), 1.0)
	var pine_dark := MU.mat(_c("pine_dark"), 1.0)
	var pine_light := MU.mat(_c("pine_light"), 1.0)
	var leaf_a := MU.mat(_c("leaf_a"), 1.0)
	var leaf_b := MU.mat(_c("leaf_b"), 1.0)
	var rock_mat := MU.mat(_c("rock"), 1.0)
	var snow_mat := MU.mat(Color("#f6fafc"), 0.9)
	var positions := _tree_positions()
	var scenery := String(lake["scenery"])
	var pine_ratio := 1 if snowy else (2 if scenery == "mountain" else 3)
	if scenery == "autumn":
		pine_ratio = 5
	for i in range(positions.size()):
		if sparse and i % 3 == 0:
			continue
		var p: Vector2 = positions[i]
		var s := 0.78 + float((i * 7) % 5) * 0.11
		var y := 0.25
		if i % pine_ratio == 0:
			_add_pine(Vector3(p.x, y, p.y), s, trunk, pine_dark if i % 2 == 0 else pine_light, snow_mat if snowy else null)
		else:
			_add_round_tree(Vector3(p.x, y, p.y), s, trunk, leaf_a if i % 2 == 0 else leaf_b, leaf_b if i % 2 == 0 else leaf_a)
	for i in range(22):
		var x := -52.0 + float(i) * 4.8 + rng.randf_range(-1.4, 1.4)
		var z := -37.0 + rng.randf_range(-2.0, 2.0)
		MU.sphere(self, Vector3(x, 0.05, z), Vector3(rng.randf_range(0.7, 1.3), rng.randf_range(0.45, 0.8), rng.randf_range(0.6, 1.0)), snow_mat if snowy and i % 2 == 0 else leaf_a, "Береговой куст", 16)
	for i in range(13):
		var x := -26.0 + float(i) * 4.4 + rng.randf_range(-0.8, 0.8)
		var z := -24.7 - rng.randf_range(0.0, 0.8)
		var r := MU.sphere(self, Vector3(x, 0.1, z), Vector3(rng.randf_range(0.34, 0.75), rng.randf_range(0.2, 0.42), rng.randf_range(0.3, 0.6)), rock_mat, "Камень у воды", 16)
		if snowy:
			MU.sphere(self, r.position + Vector3(0.0, r.scale.y * 0.65, 0.0), Vector3(r.scale.x * 0.85, r.scale.y * 0.4, r.scale.z * 0.85), snow_mat, "Снег на камне", 12)


func _add_pine(pos: Vector3, s: float, trunk_mat: Material, crown_mat: Material, snow: Material) -> void:
	var root := Node3D.new()
	root.name = "Ель"
	root.position = pos
	add_child(root)
	var height := 5.2 * s
	MU.cylinder(root, Vector3(0, height * 0.3, 0), 0.30 * s, height * 0.6, trunk_mat, "Ствол", 16)
	for tier in range(4):
		var r := (1.85 - float(tier) * 0.36) * s
		var y := height * 0.30 + float(tier) * 1.05 * s + 0.8 * s
		MU.sphere(root, Vector3(0, y, 0), Vector3(r, r * 0.78, r), crown_mat, "Ярус ели", 20)
		if snow != null:
			MU.sphere(root, Vector3(0, y + r * 0.34, 0), Vector3(r * 0.82, r * 0.42, r * 0.82), snow, "Снег на ели", 16)
	sway_nodes.append({"node": root, "phase": rng.randf() * TAU, "amp": 0.012, "speed": 0.8})


func _add_round_tree(pos: Vector3, s: float, trunk_mat: Material, mat_a: Material, mat_b: Material) -> void:
	var root := Node3D.new()
	root.name = "Дерево"
	root.position = pos
	add_child(root)
	var height := 5.0 * s
	MU.cylinder(root, Vector3(0, height * 0.32, 0), 0.30 * s, height * 0.64, trunk_mat, "Ствол", 16)
	var crowns := [Vector3(0, 0, 0), Vector3(-0.85, -0.3, 0.2), Vector3(0.8, -0.25, -0.2), Vector3(0.1, 0.7, 0.1)]
	for j in range(crowns.size()):
		var p: Vector3 = crowns[j]
		MU.sphere(root, Vector3(p.x * s, height * 0.78 + p.y * s, p.z * s), Vector3(1.3, 1.25, 1.2) * s * (0.85 if j == 3 else 1.0), mat_a if j % 2 == 0 else mat_b, "Крона", 20)
	sway_nodes.append({"node": root, "phase": rng.randf() * TAU, "amp": 0.018, "speed": 0.9})


func _build_mountains() -> void:
	var sm := ShaderMaterial.new()
	sm.shader = MOUNTAIN_SHADER
	sm.set_shader_parameter("stone", _c("hill").darkened(0.12))
	sm.set_shader_parameter("snow", Color("#e8f1ec"))
	for peak in [Vector3(-48.0, 0.0, -58.0), Vector3(-19.0, 0.0, -66.0), Vector3(20.0, 0.0, -68.0), Vector3(48.0, 0.0, -56.0), Vector3(0.0, 0.0, -84.0)]:
		var r := rng.randf_range(15.0, 22.0)
		var h := rng.randf_range(15.0, 24.0)
		var mountain := MU.sphere(self, Vector3(peak.x, 0.0, peak.z), Vector3(r, h, r), sm, "Округлая вершина", 40)
		mountain.mesh.set("rings", 24)


func _build_reeds(clusters: int) -> void:
	var reed_mat := MU.mat(_c("leaf_b"), 0.94)
	var seed_mat := MU.mat(_c("sand").darkened(0.35), 0.92)
	for k in range(clusters):
		var cx := rng.randf_range(-27.0, 27.0)
		var cz := rng.randf_range(-24.5, -22.0)
		var group := Node3D.new()
		group.position = Vector3(cx, 0.0, cz)
		group.name = "Заросли камыша"
		add_child(group)
		for i in range(7):
			var x := float(i - 3) * 0.26
			var z := float(i % 2) * 0.32
			var height := 1.8 + float((i * 7) % 5) * 0.31
			var top := Vector3(x + (float(i % 3) - 1.0) * 0.18, height, z)
			MU.capsule_between(group, Vector3(x, 0.05, z), top, 0.03, reed_mat, "Стебель камыша", 8)
			MU.sphere(group, top + Vector3(0, 0.14, 0), Vector3(0.075, 0.26, 0.075), seed_mat, "Метёлка камыша", 10)
		sway_nodes.append({"node": group, "phase": rng.randf() * TAU, "amp": 0.05, "speed": 1.2})


func _build_lilies() -> void:
	var pad_mat := MU.mat(Color("#4d8a3a"), 0.7)
	var pad_dark := MU.mat(Color("#3a7030"), 0.7)
	var pink := MU.mat(Color("#f2a0c0"), 0.5, 0.0, Color("#f7b0cc"), 0.3)
	var white := MU.mat(Color("#fbf3e6"), 0.5)
	for i in range(70):
		var x := rng.randf_range(-34.0, 34.0)
		var z := rng.randf_range(-24.0, 4.0)
		if absf(x) < 2.6 and z > -9.5:
			continue
		var r := rng.randf_range(0.35, 0.85)
		var pad := MU.cylinder(self, Vector3(x, 0.0, z), r, 0.035, pad_mat if i % 2 == 0 else pad_dark, "Кувшинка", 24, 1.0)
		if rng.randf() < 0.28:
			for k in range(5):
				var a := float(k) / 5.0 * TAU
				var petal := MU.sphere(pad, Vector3(cos(a) * 0.1, 0.1, sin(a) * 0.1), Vector3(0.05, 0.13, 0.05), pink if i % 3 else white, "Лепесток", 8)
				petal.rotation = Vector3(sin(a) * 0.6, 0.0, -cos(a) * 0.6)
		bobbers.append({"node": pad, "y": -0.01, "phase": rng.randf() * TAU, "spin": rng.randf_range(-0.05, 0.05), "amp": 0.012})


func _build_swamp_trees() -> void:
	var trunk := MU.mat(Color("#3f3a2a"), 1.0)
	var moss := MU.mat(Color("#4f6a34"), 1.0)
	var vine := MU.mat(Color("#5f7f3a"), 1.0)
	for x in [-30.0, -22.0, -12.0, 12.0, 21.0, 31.0]:
		var root := Node3D.new()
		root.position = Vector3(x + rng.randf_range(-2.0, 2.0), 0.0, -26.0 + rng.randf_range(-3.0, 1.0))
		root.name = "Болотная ива"
		add_child(root)
		MU.capsule_between(root, Vector3(0, 0.0, 0), Vector3(rng.randf_range(-0.5, 0.5), 3.4, 0), 0.34, trunk, "Ствол ивы", 12)
		for k in range(3):
			MU.sphere(root, Vector3(rng.randf_range(-1.0, 1.0), 3.9 + rng.randf_range(-0.3, 0.4), rng.randf_range(-0.8, 0.8)), Vector3(1.8, 1.05, 1.6), moss, "Крона ивы", 18)
		for k in range(9):
			var a := float(k) / 9.0 * TAU
			MU.capsule_between(root, Vector3(cos(a) * 1.4, 3.7, sin(a) * 1.2), Vector3(cos(a) * 1.55, 1.6 + rng.randf() * 0.7, sin(a) * 1.3), 0.03, vine, "Плети ивы", 6)
		sway_nodes.append({"node": root, "phase": rng.randf() * TAU, "amp": 0.02, "speed": 0.7})


func _build_ice() -> void:
	var ice_mat := MU.mat(Color("#dff0f7"), 0.25, 0.1, Color("#9fd4e8"), 0.25)
	var snow_mat := MU.mat(Color("#f8fcff"), 0.85)
	var spots: Array = []
	for i in range(14):
		var side := -1.0 if i % 2 == 0 else 1.0
		spots.append(Vector3(side * rng.randf_range(15.0, 34.0), 0.0, rng.randf_range(-22.0, -3.0)))
	for i in range(6):
		spots.append(Vector3(rng.randf_range(-12.0, 12.0), 0.0, rng.randf_range(-24.0, -22.5)))
	for spot in spots:
		var r := rng.randf_range(0.9, 2.6)
		var floe := MU.cylinder(self, Vector3(spot.x, -0.02, spot.z), r, 0.16, ice_mat, "Льдина", 32, 0.97)
		MU.sphere(floe, Vector3(0.0, 0.7, 0.0), Vector3(0.82, 0.55, 0.82), snow_mat, "Снег на льдине", 20)
		bobbers.append({"node": floe, "y": -0.02, "phase": rng.randf() * TAU, "spin": rng.randf_range(-0.06, 0.06), "amp": 0.02})


func _build_terraces() -> void:
	var travertine := MU.mat(Color("#e6d8c2"), 0.85)
	var pool := MU.mat(_c("water_light"), 0.15, 0.0, _c("water_light"), 0.35)
	for pos in [Vector3(-14.0, 0.0, -25.0), Vector3(0.0, 0.0, -27.5), Vector3(17.0, 0.0, -25.5), Vector3(-30.0, 0.0, -18.0), Vector3(31.0, 0.0, -17.0)]:
		var root := Node3D.new()
		root.position = pos
		root.name = "Каменная терраса"
		add_child(root)
		for tier in range(4):
			var r := 4.6 - float(tier) * 0.95
			MU.cylinder(root, Vector3(0.0, 0.2 + float(tier) * 0.42, 0.0), r, 0.42, travertine, "Ступень террасы", 40, 0.96)
			MU.cylinder(root, Vector3(0.0, 0.42 + float(tier) * 0.42, 0.0), r * 0.86, 0.04, pool, "Горячая чаша", 40, 1.0)
		for k in range(6):
			var a := float(k) / 6.0 * TAU
			MU.sphere(root, Vector3(cos(a) * 4.9, 0.18, sin(a) * 4.9), Vector3(0.55, 0.36, 0.55), MU.mat(_c("rock"), 1.0), "Камень", 14)


func _build_palms() -> void:
	var trunk := MU.mat(Color("#8a6a45"), 0.95)
	var leaf_a := MU.mat(_c("leaf_a"), 0.85)
	var leaf_b := MU.mat(_c("leaf_b"), 0.85)
	var nut := MU.mat(Color("#5a3b22"), 0.7)
	var spots := [Vector2(-34.0, -8.0), Vector2(-28.0, -22.0), Vector2(-17.0, -26.0), Vector2(-6.0, -28.0), Vector2(8.0, -27.0), Vector2(19.0, -25.0), Vector2(30.0, -21.0), Vector2(36.0, -6.0), Vector2(-40.0, 2.0), Vector2(40.0, 3.0), Vector2(-22.0, -30.0), Vector2(24.0, -31.0)]
	for i in range(spots.size()):
		var p: Vector2 = spots[i]
		var s := rng.randf_range(0.85, 1.3)
		var root := Node3D.new()
		root.position = Vector3(p.x, 0.2, p.y)
		root.name = "Пальма"
		add_child(root)
		var lean := rng.randf_range(-1.6, 1.6)
		var prev := Vector3.ZERO
		var top := Vector3.ZERO
		for k in range(1, 7):
			var u := float(k) / 6.0
			var cur := Vector3(lean * u * u * s, 5.6 * u * s, 0.0)
			MU.capsule_between(root, prev, cur, (0.30 - 0.14 * u) * s, trunk, "Сегмент ствола", 12)
			prev = cur
			top = cur
		for k in range(9):
			var a := float(k) / 9.0 * TAU
			var dir := Vector3(cos(a), 0.0, sin(a))
			var leaf := MU.sphere(root, top + dir * 1.55 * s + Vector3(0.0, -0.25 * s, 0.0), Vector3(1.9 * s, 0.09 * s, 0.42 * s), leaf_a if k % 2 == 0 else leaf_b, "Пальмовый лист", 12)
			leaf.rotation.y = -a
			leaf.rotation.z = -0.35
			leaf.rotate_object_local(Vector3(0, 0, 1), 0.0)
		for k in range(3):
			var a2 := float(k) / 3.0 * TAU
			MU.sphere(root, top + Vector3(cos(a2) * 0.28, -0.35, sin(a2) * 0.28), Vector3(0.2, 0.22, 0.2) * s, nut, "Кокос", 12)
		sway_nodes.append({"node": root, "phase": rng.randf() * TAU, "amp": 0.02, "speed": 0.9})


func _build_islands() -> void:
	var sand := MU.mat(_c("sand"), 0.95)
	var green := MU.mat(_c("hill"), 1.0)
	for pos in [Vector3(-22.0, 0.0, -14.0), Vector3(25.0, 0.0, -16.0), Vector3(-6.0, 0.0, -26.0)]:
		var r := rng.randf_range(2.6, 4.0)
		MU.sphere(self, Vector3(pos.x, -0.5, pos.z), Vector3(r, 0.9, r * 0.8), sand, "Песчаный островок", 28)
		MU.sphere(self, Vector3(pos.x + 0.3, 0.05, pos.z), Vector3(r * 0.42, 0.42, r * 0.36), green, "Трава на островке", 20)


func _build_birds() -> void:
	var gulls := String(lake["scenery"]) == "tropical"
	var body_col := Color("#f6f4ee") if gulls else Color("#2d3238")
	var body_mat := MU.mat(body_col, 0.8)
	var count := 4 if gulls else 3
	for i in range(count):
		var bird := Node3D.new()
		bird.name = "Птица"
		add_child(bird)
		MU.sphere(bird, Vector3.ZERO, Vector3(0.42, 0.13, 0.13), body_mat, "Тело птицы", 10)
		MU.sphere(bird, Vector3(0.36, 0.03, 0.0), Vector3(0.11, 0.1, 0.1), body_mat, "Голова птицы", 10)
		var lw := Node3D.new()
		lw.name = "ЛевоеКрыло"
		bird.add_child(lw)
		MU.sphere(lw, Vector3(0.0, 0.0, -0.55), Vector3(0.16, 0.035, 0.6), body_mat, "Крыло", 10)
		var rw := Node3D.new()
		rw.name = "ПравоеКрыло"
		bird.add_child(rw)
		MU.sphere(rw, Vector3(0.0, 0.0, 0.55), Vector3(0.16, 0.035, 0.6), body_mat, "Крыло", 10)
		bird_nodes.append({"node": bird, "phase": float(i) * TAU / float(count), "radius": rng.randf_range(16.0, 30.0), "height": rng.randf_range(15.0, 26.0), "speed": rng.randf_range(0.10, 0.2) * (1.0 if i % 2 == 0 else -1.0), "cz": -48.0})


# --- Погода -------------------------------------------------------------
func _particles(node_name: String, amount: int, life: float, box: Vector3, pos: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = node_name
	if OS.has_feature("mobile"):
		amount = int(float(amount) * 0.5)
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.position = pos
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	weather_nodes.append(p)
	return p


func _build_weather() -> void:
	var weather := String(lake["weather"])
	match weather:
		"snow":
			var p := _particles("Снегопад", 1900, 11.0, Vector3(30.0, 0.2, 22.0), Vector3(0.0, 14.0, -8.0))
			var m := SphereMesh.new()
			m.radius = 0.035
			m.height = 0.07
			m.radial_segments = 6
			m.rings = 3
			m.material = MU.unshaded(Color(1, 1, 1, 0.92))
			p.mesh = m
			p.direction = Vector3(0.25, -1.0, 0.0)
			p.spread = 28.0
			p.gravity = Vector3(0.4, -0.9, 0.15)
			p.initial_velocity_min = 0.3
			p.initial_velocity_max = 1.0
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.9
			p.angular_velocity_min = -30.0
			p.angular_velocity_max = 30.0
			p.damping_min = 0.4
			p.damping_max = 1.0
			# лёгкое покачивание
			p.tangential_accel_min = -0.4
			p.tangential_accel_max = 0.4
		"rain":
			drop_rate = 34.0
			var p := _particles("Дождь", 1700, 0.8, Vector3(26.0, 0.2, 22.0), Vector3(0.0, 15.0, -8.0))
			var m := CapsuleMesh.new()
			m.radius = 0.014
			m.height = 0.7
			m.radial_segments = 6
			m.rings = 2
			m.material = MU.unshaded(Color(0.78, 0.86, 0.95, 0.34))
			p.mesh = m
			p.direction = Vector3(0.12, -1.0, 0.0)
			p.spread = 3.0
			p.gravity = Vector3(1.0, -22.0, 0.0)
			p.initial_velocity_min = 16.0
			p.initial_velocity_max = 21.0
		"leaves":
			var p := _particles("Листопад", 170, 9.0, Vector3(34.0, 0.2, 24.0), Vector3(0.0, 11.0, -8.0))
			var m := SphereMesh.new()
			m.radius = 0.1
			m.height = 0.2
			m.radial_segments = 8
			m.rings = 4
			var lm := MU.mat(Color.WHITE, 0.8)
			lm.vertex_color_use_as_albedo = true
			m.material = lm
			p.mesh = m
			var ramp := Gradient.new()
			ramp.colors = PackedColorArray([Color("#d24a26"), Color("#e8a12e"), Color("#b8331f"), Color("#f0c14a")])
			ramp.offsets = PackedFloat32Array([0.0, 0.35, 0.65, 1.0])
			p.color_initial_ramp = ramp
			p.direction = Vector3(0.6, -1.0, 0.0)
			p.spread = 40.0
			p.gravity = Vector3(0.7, -0.6, 0.0)
			p.initial_velocity_min = 0.2
			p.initial_velocity_max = 1.2
			p.scale_amount_min = 0.7
			p.scale_amount_max = 1.6
			p.angular_velocity_min = -160.0
			p.angular_velocity_max = 160.0
			p.damping_min = 0.6
			p.damping_max = 1.4
			p.orbit_velocity_min = -0.05
			p.orbit_velocity_max = 0.05
		"fireflies":
			var p := _particles("Светлячки", 46, 7.0, Vector3(30.0, 1.6, 9.0), Vector3(0.0, 1.9, -12.0))
			var m := SphereMesh.new()
			m.radius = 0.05
			m.height = 0.1
			m.radial_segments = 8
			m.rings = 4
			var fm := MU.mat(Color("#f4ff9a"), 0.4, 0.0, Color("#e4ff6a"), 5.0)
			fm.emission_enabled = true
			m.material = fm
			p.mesh = m
			p.direction = Vector3(0.0, 1.0, 0.0)
			p.spread = 180.0
			p.gravity = Vector3.ZERO
			p.initial_velocity_min = 0.1
			p.initial_velocity_max = 0.5
			p.damping_min = 0.1
			p.damping_max = 0.3
			p.orbit_velocity_min = -0.1
			p.orbit_velocity_max = 0.1
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.2
			var curve := Curve.new()
			curve.add_point(Vector2(0.0, 0.0))
			curve.add_point(Vector2(0.25, 1.0))
			curve.add_point(Vector2(0.5, 0.35))
			curve.add_point(Vector2(0.75, 1.0))
			curve.add_point(Vector2(1.0, 0.0))
			p.scale_amount_curve = curve
		"steam":
			for pos in [Vector3(-14.0, 0.9, -25.0), Vector3(0.0, 0.9, -27.5), Vector3(17.0, 0.9, -25.5), Vector3(-30.0, 0.9, -18.0), Vector3(31.0, 0.9, -17.0), Vector3(-9.0, 0.1, -16.0), Vector3(10.0, 0.1, -14.0)]:
				var p := _particles("Пар", 18, 6.5, Vector3(2.0, 0.1, 1.8), pos)
				var m := QuadMesh.new()
				m.size = Vector2(2.6, 2.6)
				m.material = MU.soft_puff(Color(1, 1, 1, 1))
				p.mesh = m
				p.direction = Vector3(0.2, 1.0, 0.0)
				p.spread = 14.0
				p.gravity = Vector3(0.12, 0.35, 0.0)
				p.initial_velocity_min = 0.2
				p.initial_velocity_max = 0.5
				p.scale_amount_min = 0.9
				p.scale_amount_max = 1.8
				var grow := Curve.new()
				grow.add_point(Vector2(0.0, 0.35))
				grow.add_point(Vector2(1.0, 1.6))
				p.scale_amount_curve = grow
				var fade := Gradient.new()
				fade.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.42), Color(1, 1, 1, 0.0)])
				fade.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
				p.color_ramp = fade
	if bool(lake.get("night", false)) and weather == "snow":
		pass


func _push_ripples() -> void:
	if water_mat != null:
		water_mat.set_shader_parameter("ripples", ripples)
		water_mat.set_shader_parameter("drops", drops)


func add_ripple(pos: Vector3, amp: float = 1.0) -> void:
	ripples[ripple_cursor] = Vector4(pos.x, pos.z, clock, amp)
	ripple_cursor = (ripple_cursor + 1) % ripples.size()
	_push_ripples()


func splash(pos: Vector3, size: float = 1.0) -> void:
	add_ripple(pos, 1.2 * size)
	var p := CPUParticles3D.new()
	p.name = "Брызги"
	p.amount = int(28.0 * size) + 8
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.9
	p.direction = Vector3.UP
	p.spread = 38.0
	p.gravity = Vector3(0.0, -9.8, 0.0)
	p.initial_velocity_min = 1.6 * size
	p.initial_velocity_max = 3.6 * size
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	var m := SphereMesh.new()
	m.radius = 0.035
	m.height = 0.07
	m.radial_segments = 6
	m.rings = 3
	m.material = MU.unshaded(Color(0.92, 0.97, 1.0, 0.85))
	p.mesh = m
	p.position = pos
	p.emitting = true
	add_child(p)
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)


# --- Обновление ---------------------------------------------------------
func tick(delta: float) -> void:
	clock += delta
	if water_mat != null:
		water_mat.set_shader_parameter("clock", clock)
	for s in sway_nodes:
		var n: Node3D = s["node"]
		if float(s["amp"]) > 0.0:
			var ph := float(s["phase"]) + clock * float(s["speed"])
			n.rotation.z = sin(ph) * float(s["amp"])
			n.rotation.x = cos(ph * 0.8) * float(s["amp"]) * 0.6
	for c in cloud_nodes:
		var n: Node3D = c["node"]
		n.position.x += float(c["speed"]) * delta
		if n.position.x > 90.0:
			n.position.x = -90.0
	for b in bird_nodes:
		var ang := float(b["phase"]) + clock * float(b["speed"])
		var n: Node3D = b["node"]
		var r := float(b["radius"])
		n.position = Vector3(cos(ang) * r, float(b["height"]) + sin(clock * 0.7 + float(b["phase"])) * 1.2, float(b["cz"]) + sin(ang) * r * 0.45)
		var tangent := Vector3(-sin(ang) * float(signf(float(b["speed"]))), 0.0, cos(ang) * 0.45 * float(signf(float(b["speed"]))))
		n.rotation.y = atan2(-tangent.z, tangent.x)
		var flap := sin(clock * 6.5 + float(b["phase"]) * 3.0) * 0.6
		(n.get_node("ЛевоеКрыло") as Node3D).rotation.x = flap
		(n.get_node("ПравоеКрыло") as Node3D).rotation.x = -flap
	for bob in bobbers:
		var n: Node3D = bob["node"]
		n.position.y = float(bob["y"]) + sin(clock * 0.9 + float(bob["phase"])) * float(bob["amp"])
		n.rotation.y += float(bob["spin"]) * delta
	for l in lamp_lights:
		var light: OmniLight3D = l["light"]
		light.light_energy = float(l["base"]) * (0.85 + 0.15 * sin(clock * 9.0 + float(l["phase"])) * sin(clock * 3.3))
	for layer in star_layers:
		var sm: StandardMaterial3D = layer["mat"]
		var v := 0.7 + 0.3 * sin(clock * 1.6 + float(layer["phase"]))
		sm.albedo_color = Color(v, v, v, 1.0)
	# капли дождя на воде
	if drop_rate > 0.0:
		drop_accum += delta * drop_rate
		while drop_accum >= 1.0:
			drop_accum -= 1.0
			drops[drop_cursor] = Vector4(rng.randf_range(-16.0, 16.0), rng.randf_range(-22.0, 4.0), clock, rng.randf_range(0.5, 1.0))
			drop_cursor = (drop_cursor + 1) % drops.size()
		_push_ripples()
	# рыба, выпрыгивающая вдали
	jump_timer -= delta
	if jump_timer <= 0.0:
		jump_timer = rng.randf_range(6.0, 15.0)
		_spawn_jump()
	# гроза
	if bool(lake.get("thunder", false)):
		thunder_timer -= delta
		if thunder_timer <= 0.0:
			thunder_timer = rng.randf_range(9.0, 22.0)
			flash = 1.0
			pending_thunder = rng.randf_range(0.6, 1.8)
		if pending_thunder > 0.0:
			pending_thunder -= delta
			if pending_thunder <= 0.0:
				thunder.emit()
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 2.4)
		var k := flash * (0.5 + 0.5 * sin(clock * 55.0))
		env.ambient_light_energy = base_ambient + k * 2.6
		sun_light.light_energy = base_sun_energy + k * 1.6
	elif bool(lake.get("thunder", false)):
		env.ambient_light_energy = base_ambient
		sun_light.light_energy = base_sun_energy


func _spawn_jump() -> void:
	var ids := Data.lake_fish(lake_index)
	var spec: Dictionary = Data.FISH[String(ids[rng.randi_range(0, ids.size() - 1)])]
	var fish := FishModel.build(spec)
	fish.scale = Vector3.ONE * (0.75 / maxf(0.4, float(spec["len"])) + 0.5)
	var start := Vector3(rng.randf_range(-13.0, 13.0), -0.1, rng.randf_range(-19.0, -9.0))
	fish.position = start
	add_child(fish)
	splash(start, 0.6)
	var dir := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-0.5, 0.5)).normalized() * 2.4
	var end := start + dir
	end.y = -0.1
	fish.rotation.y = atan2(-dir.z, dir.x) + PI
	var tw := create_tween()
	tw.tween_method(func(u: float):
		fish.position = start.lerp(end, u) + Vector3(0.0, sin(u * PI) * 1.4, 0.0)
		fish.rotation.z = lerpf(0.9, -0.9, u)
		FishModel.animate(fish, u * 6.0, 1.0), 0.0, 1.0, 0.85)
	tw.tween_callback(func():
		splash(end, 0.7)
		fish.queue_free())
