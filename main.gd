extends Node3D
## Quiet Waters: Fishing — игровой цикл: заброс, поклёвка, вываживание, показ улова.

const Data = preload("res://scripts/game_data.gd")
const FishModel = preload("res://scripts/fish_model.gd")
const MU = preload("res://scripts/mesh_util.gd")
const UI = preload("res://scripts/ui_kit.gd")
const SceneryScript = preload("res://scripts/scenery.gd")
const AudioBankScript = preload("res://scripts/audio_bank.gd")
const MenuScript = preload("res://scripts/menu.gd")
const RingGauge = preload("res://scripts/ring_gauge.gd")
const IconButton = preload("res://scripts/icon_button.gd")
const LoadingScreen = preload("res://scripts/loading_screen.gd")

enum FishingState { READY, CHARGING, CASTING, WAITING, BITE, FIGHT, LANDING }

const CAM_POS := Vector3(0.0, 2.25, 5.35)
const CAM_TARGET := Vector3(0.0, 0.25, -22.0)
const GRIP_START := Vector3(0.18, -0.77, -0.96)
const GRIP_END := Vector3(0.42, -0.58, -1.12)
const TIP_DEFAULT := Vector3(1.10, 0.46, -2.10)
const ROD_SEGS := 10
const LINE_SEGS := 14
const REEL_TARGET := Vector3(1.9, -0.05, -1.6)
const HOLD_LOCAL := Vector3(0.0, 0.10, -1.7)
const SAVE_PATH := "user://fishing_progress.cfg"

var rng := RandomNumberGenerator.new()
var state: FishingState = FishingState.READY
var charge_amount := 0.0
var wait_timer := 0.0
var bite_timer := 0.0
var fight_clock := 0.0
var fight_progress := 0.0
var tension := 0.34
var reel_held := false
var fish_id := "perch"
var fish_weight := 0.0
var fish_power := 1.0
var dash_timer := 3.0
var dash_left := 0.0
var zero_progress_time := 0.0
var warn_cooldown := 0.0
var ripple_cooldown := 0.0
var cast_time := 0.0
var cast_from := Vector3.ZERO
var cast_distance := 10.0
var land_time := 0.0
var land_start := Vector3.ZERO
var land_reward := 0
var land_new := false
var land_coin_played := false
var land_sparkled := false
var land_skip := false
var catch_fish: Node3D
var elapsed := 0.0
var toast_timer := 0.0
var float_anchor := Vector3.ZERO
var bobber_pos := Vector3.ZERO
var rod_kick := 0.0
var rod_bend := 0.0
var rod_tip_local := TIP_DEFAULT
var line_sag := 0.3

# прогресс игрока
var coins := 500
var owned_rods: Array[bool] = []
var selected_rod := 1
var selected_lake := 0
var collection: Dictionary = {}
var total_catches := 0
var best_weight := 0.0
var music_volume := 0.55
var sfx_volume := 0.8
var ambient_volume := 0.7

var game_started := false
var is_loading := true
var paused := false

var camera: Camera3D
var world_environment: WorldEnvironment
var sun_light: DirectionalLight3D
var scenery: Node3D
var audio: Node
var bobber: Node3D
var line_root: Node3D
var line_segments: Array[MeshInstance3D] = []
var rod_root: Node3D
var rod_segments: Array[MeshInstance3D] = []
var rod_guides: Array[MeshInstance3D] = []
var reel_arm: Node3D
var arms_root: Node3D
var menu: Control

var ui_layer: CanvasLayer
var ui_root: Control
var exit_button: Button
var pause_button: Button
var lake_panel: Panel
var lake_label: Label
var season_label: Label
var stats_panel: Panel
var stats_label: Label
var coins_label: Label
var hint_panel: Panel
var hint_label: Label
var subhint_label: Label
var toast_panel: Panel
var toast_label: Label
var toast_sub: Label
var gauge: Control
var catch_card: Panel
var catch_name: Label
var catch_info: Label
var catch_rarity: Label
var catch_new: Label
var catch_tween: Tween


func _ready() -> void:
	is_loading = true
	var started := Time.get_ticks_msec()
	if OS.has_feature("mobile"):
		MU.detail = 0.6
	rng.randomize()
	# сначала показываем свою заставку, потом собираем мир по шагам
	var loader := LoadingScreen.new()
	var loader_layer := CanvasLayer.new()
	loader_layer.layer = 60
	loader_layer.add_child(loader)
	add_child(loader_layer)
	loader.set_progress(0.05, "Открываем озёра...")
	await get_tree().process_frame
	owned_rods.resize(Data.RODS.size())
	for i in range(owned_rods.size()):
		owned_rods[i] = int(Data.RODS[i]["price"]) == 0
	_load_progress()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().set_auto_accept_quit(true)
	_build_environment()
	audio = AudioBankScript.new()
	audio.name = "Звук"
	add_child(audio)
	audio.music_volume = music_volume
	audio.sfx_volume = sfx_volume
	audio.ambient_volume = ambient_volume
	loader.set_progress(0.2, "Достаём удочку...")
	await get_tree().process_frame
	_build_rod()
	_build_first_person_arms()
	_build_bobber_and_line()
	_build_ui()
	loader.set_progress(0.4, "Рисуем меню...")
	await get_tree().process_frame
	menu = MenuScript.new()
	menu.name = "Меню"
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 12
	menu_layer.add_child(menu)
	add_child(menu_layer)
	menu.setup(self)
	menu.play_requested.connect(_on_menu_play)
	menu.resume_requested.connect(_resume_from_pause)
	menu.exit_lake_requested.connect(_exit_lake)
	menu.quit_requested.connect(_quit_game)
	get_viewport().size_changed.connect(_layout_ui)
	loader.set_progress(0.65, "Наполняем озеро водой...")
	await get_tree().process_frame
	_select_lake(selected_lake)
	_select_rod(selected_rod, false)
	loader.set_progress(0.9, "Зовём рыбу...")
	await get_tree().process_frame
	_show_menu()
	_layout_ui()
	_update_hud()
	# заставка показывается не меньше полутора секунд, чтобы не мелькать
	var spent := float(Time.get_ticks_msec() - started) / 1000.0
	if spent < 1.6:
		await get_tree().create_timer(1.6 - spent).timeout
	is_loading = false
	loader.finish()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not is_loading:
		_handle_escape()


# ---------------------------------------------------------------- цикл
func _process(delta: float) -> void:
	if is_loading and menu == null:
		return
	elapsed += delta
	if scenery != null:
		scenery.tick(delta)
	if not game_started:
		var drift := Vector3(sin(elapsed * 0.13) * 1.6, sin(elapsed * 0.09) * 0.25, cos(elapsed * 0.07) * 0.6)
		camera.look_at_from_position(CAM_POS + drift, CAM_TARGET + Vector3(sin(elapsed * 0.05) * 3.0, 0.0, 0.0), Vector3.UP)
		_animate_bobber()
		_update_rod(delta)
		_update_line()
		return
	if camera.position != CAM_POS:
		camera.look_at_from_position(CAM_POS, CAM_TARGET, Vector3.UP)
	if toast_timer > 0.0:
		toast_timer = maxf(0.0, toast_timer - delta)
		var a := minf(1.0, toast_timer * 2.0)
		toast_panel.modulate.a = a
		if toast_timer == 0.0:
			toast_panel.visible = false
	if not paused:
		_update_state(delta)
	_animate_bobber()
	_animate_arms()
	_update_rod(delta)
	_update_line()
	_update_hud()


func _update_state(delta: float) -> void:
	match state:
		FishingState.CHARGING:
			charge_amount = minf(1.0, charge_amount + delta * 0.52)
		FishingState.CASTING:
			cast_time += delta
			var u := clampf(cast_time / 0.75, 0.0, 1.0)
			bobber_pos = cast_from.lerp(float_anchor, u) + Vector3(0.0, sin(u * PI) * (1.8 + cast_distance * 0.1), 0.0)
			if u >= 1.0:
				state = FishingState.WAITING
				wait_timer = rng.randf_range(4.5, 8.5)
				bobber_pos = float_anchor
				scenery.splash(float_anchor, 0.9)
				audio.play("splash", 0.8)
				_show_toast("ПОПЛАВОК НА ВОДЕ", "Ждём поклёвку", Color("#f1cf9e"))
		FishingState.WAITING:
			wait_timer -= delta
			ripple_cooldown -= delta
			if ripple_cooldown <= 0.0:
				ripple_cooldown = 1.9
				scenery.add_ripple(float_anchor, 0.35)
			if wait_timer <= 0.0:
				_start_bite()
		FishingState.BITE:
			bite_timer -= delta
			ripple_cooldown -= delta
			if ripple_cooldown <= 0.0:
				ripple_cooldown = 0.35
				scenery.add_ripple(float_anchor, 0.8)
			if bite_timer <= 0.0:
				audio.play("escape", 0.7)
				_show_toast("РЫБА СОШЛА", "Попробуй забросить ещё раз", Color("#efb67f"))
				_reset_line()
		FishingState.FIGHT:
			fight_clock += delta
			_update_fight(delta)
		FishingState.LANDING:
			_update_landing(delta)
		_:
			pass
	rod_kick = lerpf(rod_kick, 0.0, minf(1.0, delta * 5.0))


func _handle_escape() -> void:
	if not game_started:
		if menu != null:
			menu.handle_escape()
		return
	if paused:
		if menu.current_page != "pause":
			menu.handle_escape()
		else:
			_resume_from_pause()
	else:
		_pause_game()


func _unhandled_input(event: InputEvent) -> void:
	if is_loading:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_M:
			_handle_escape()
			get_viewport().set_input_as_handled()
			return
	if not game_started or paused:
		return
	var press_started := false
	var press_ended := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		press_started = event.pressed and not event.is_echo()
		press_ended = not event.pressed
	elif event is InputEventScreenTouch and event.index == 0:
		if _point_over_button(event.position):
			return
		press_started = event.pressed and not event.canceled
		press_ended = not event.pressed or event.canceled
	else:
		return
	if press_started:
		match state:
			FishingState.READY:
				state = FishingState.CHARGING
				charge_amount = 0.06
				audio.play("click", 0.35, 0.8)
			FishingState.BITE:
				_start_fight()
			FishingState.FIGHT:
				reel_held = true
			FishingState.LANDING:
				if land_time > 1.1:
					land_skip = true
			_:
				pass
	elif press_ended:
		if state == FishingState.CHARGING:
			_cast_line()
		reel_held = false


func _point_over_button(pos: Vector2) -> bool:
	for b in [exit_button, pause_button]:
		if b != null and b.visible and b.get_global_rect().has_point(pos):
			return true
	return false


# ---------------------------------------------------------------- сцена
func _build_environment() -> void:
	world_environment = WorldEnvironment.new()
	world_environment.name = "Атмосфера озера"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	(sky.sky_material as ProceduralSkyMaterial).sun_angle_max = 14.0
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.28
	env.glow_bloom = 0.08
	env.fog_enabled = true
	env.fog_density = 0.006
	env.fog_sky_affect = 0.2
	world_environment.environment = env
	add_child(world_environment)

	sun_light = DirectionalLight3D.new()
	sun_light.name = "Свет над озером"
	sun_light.rotation_degrees = Vector3(-39.0, -27.0, 0.0)
	sun_light.light_energy = 1.35
	sun_light.shadow_enabled = not OS.has_feature("mobile")
	add_child(sun_light)

	camera = Camera3D.new()
	camera.name = "Камера рыбака"
	add_child(camera)
	camera.look_at_from_position(CAM_POS, CAM_TARGET, Vector3.UP)
	camera.fov = 64.0
	camera.make_current()


func _select_lake(index: int) -> void:
	selected_lake = clampi(index, 0, Data.LAKES.size() - 1)
	if scenery != null:
		remove_child(scenery)
		scenery.queue_free()
	scenery = SceneryScript.new()
	scenery.name = "Озеро"
	add_child(scenery)
	scenery.build(selected_lake, world_environment.environment, sun_light)
	scenery.thunder.connect(func(): audio.play("thunder", 0.9))
	var lake: Dictionary = Data.LAKES[selected_lake]
	if lake_label != null:
		lake_label.text = String(lake["name"]).to_upper()
		season_label.text = String(lake["season"])
	if audio != null:
		audio.play_music(String(lake["music"]))
		audio.play_ambient(String(lake["ambient"]))
	_reset_line()
	_save_progress()


func _select_rod(index: int, save: bool = true) -> void:
	if index < 0 or index >= Data.RODS.size() or not owned_rods[index]:
		return
	selected_rod = index
	_apply_rod_look()
	if save:
		_save_progress()


# ---------------------------------------------------------------- удочка
func _build_rod() -> void:
	rod_root = Node3D.new()
	rod_root.name = "Удочка в руках рыбака"
	camera.add_child(rod_root)
	var grip_mat := MU.mat(Color("#342f30"), 0.72)
	MU.capsule_between(rod_root, GRIP_START, GRIP_END, 0.05, grip_mat, "Рукоять удочки", 20)
	var metal := MU.mat(Color("#d4b885"), 0.34, 0.7)
	var reel_pos := GRIP_END.lerp(TIP_DEFAULT, 0.1) + Vector3(0.0, -0.09, 0.0)
	var reel_body := MU.cylinder(rod_root, reel_pos, 0.07, 0.05, metal, "Катушка", 28, 1.0)
	reel_body.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	reel_arm = Node3D.new()
	reel_arm.name = "Ручка катушки"
	reel_arm.position = reel_pos + Vector3(0.05, 0.0, 0.0)
	rod_root.add_child(reel_arm)
	MU.capsule_between(reel_arm, Vector3.ZERO, Vector3(0.0, 0.09, 0.0), 0.011, metal, "Плечо ручки", 8)
	MU.sphere(reel_arm, Vector3(0.0, 0.10, 0.0), Vector3(0.025, 0.025, 0.025), grip_mat, "Набалдашник", 12)
	var seg_mat := MU.mat(Color("#503e35"), 0.5, 0.2)
	for i in range(ROD_SEGS):
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.height = 1.0
		cyl.radial_segments = 14
		cyl.rings = 1
		mi.mesh = cyl
		mi.material_override = seg_mat
		mi.name = "Секция удилища"
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rod_root.add_child(mi)
		rod_segments.append(mi)
	var guide_mat := MU.mat(Color("#d4b885"), 0.4, 0.65)
	for i in range(4):
		var g := MU.sphere(rod_root, Vector3.ZERO, Vector3(0.022, 0.022, 0.022), guide_mat, "Кольцо удочки", 10)
		rod_guides.append(g)


func _apply_rod_look() -> void:
	var rod: Dictionary = Data.RODS[selected_rod]
	var color := Color(String(rod["color"]))
	var mat := MU.mat(color, 0.42, 0.22)
	var thick: float = rod["thick"]
	for i in range(ROD_SEGS):
		var mi := rod_segments[i]
		mi.material_override = mat
		var cyl := mi.mesh as CylinderMesh
		var u0 := float(i) / float(ROD_SEGS)
		var u1 := float(i + 1) / float(ROD_SEGS)
		cyl.bottom_radius = lerpf(thick, 0.005, pow(u0, 0.85))
		cyl.top_radius = lerpf(thick, 0.005, pow(u1, 0.85))


func _rod_points(bend: float, length_factor: float, tilt: float = 0.0) -> PackedVector3Array:
	var dir := (TIP_DEFAULT - GRIP_END) * length_factor
	dir = Basis(Vector3.RIGHT, tilt) * dir
	var l := dir.length()
	var pts := PackedVector3Array()
	for i in range(ROD_SEGS + 1):
		var u := float(i) / float(ROD_SEGS)
		pts.append(GRIP_END + dir * u + Vector3(0.0, -1.0, 0.25) * bend * l * 0.30 * u * u)
	return pts


func _update_rod(delta: float) -> void:
	var rod: Dictionary = Data.RODS[selected_rod]
	var target := 0.0
	match state:
		FishingState.FIGHT:
			target = tension * 0.95 + sin(fight_clock * 8.0) * 0.05 * tension
			if reel_held:
				reel_arm.rotation.x += delta * 10.0
		FishingState.BITE:
			target = 0.18 + sin(elapsed * 42.0) * 0.12
		FishingState.WAITING:
			target = 0.06 + sin(elapsed * 1.4) * 0.02
		FishingState.CHARGING:
			target = -charge_amount * 0.35
		_:
			target = 0.04
	rod_bend = lerpf(rod_bend, target, minf(1.0, delta * 10.0))
	var tilt := (charge_amount * 0.32 if state == FishingState.CHARGING else 0.0) + rod_kick
	var pts := _rod_points(rod_bend, float(rod["len"]), tilt)
	for i in range(ROD_SEGS):
		var a := pts[i]
		var b := pts[i + 1]
		var mi := rod_segments[i]
		mi.position = (a + b) * 0.5
		var d := b - a
		mi.quaternion = Quaternion(Vector3.UP, d.normalized())
		mi.scale = Vector3(1.0, d.length(), 1.0)
	var guide_us := [0.25, 0.48, 0.70, 0.89]
	for i in range(4):
		var idx := int(float(guide_us[i]) * float(ROD_SEGS))
		var f := float(guide_us[i]) * float(ROD_SEGS) - float(idx)
		rod_guides[i].position = pts[idx].lerp(pts[mini(idx + 1, ROD_SEGS)], f)
	rod_tip_local = pts[ROD_SEGS]
	rod_root.rotation.z = sin(elapsed * 0.8) * 0.006


func _build_first_person_arms() -> void:
	arms_root = Node3D.new()
	arms_root.name = "Руки рыбака от первого лица"
	camera.add_child(arms_root)
	var jacket := MU.mat(Color("#48584b"), 0.95)
	var cuff := MU.mat(Color("#8c7a5a"), 0.85)
	var skin := MU.mat(Color("#d49a72"), 0.9)
	MU.capsule_between(arms_root, Vector3(-0.95, -1.05, -1.4), Vector3(0.20, -0.72, -1.04), 0.085, jacket, "Левый рукав", 24)
	MU.capsule_between(arms_root, Vector3(1.05, -1.10, -1.45), Vector3(0.64, -0.60, -1.03), 0.085, jacket, "Правый рукав", 24)
	MU.sphere(arms_root, Vector3(0.23, -0.70, -1.06), Vector3(0.075, 0.075, 0.075), cuff, "Манжета левой руки", 20)
	MU.sphere(arms_root, Vector3(0.66, -0.575, -1.04), Vector3(0.072, 0.072, 0.072), cuff, "Манжета правой руки", 20)
	MU.sphere(arms_root, Vector3(0.34, -0.65, -1.10), Vector3(0.085, 0.06, 0.06), skin, "Ладонь на рукояти", 20)
	MU.sphere(arms_root, Vector3(0.68, -0.535, -1.11), Vector3(0.08, 0.058, 0.06), skin, "Ладонь на катушке", 20)
	for finger in range(4):
		var offset := float(finger) * 0.03
		MU.capsule_between(arms_root, Vector3(0.30 + offset, -0.62, -1.13), Vector3(0.37 + offset, -0.66, -1.16), 0.016, skin, "Пальцы на рукояти", 10)
		MU.capsule_between(arms_root, Vector3(0.64 + offset, -0.51, -1.14), Vector3(0.70 + offset, -0.55, -1.16), 0.014, skin, "Пальцы на катушке", 10)
	MU.sphere(arms_root, Vector3(0.28, -0.66, -1.10), Vector3(0.04, 0.032, 0.036), skin, "Большой палец", 12)


func _animate_arms() -> void:
	if arms_root == null:
		return
	var lift := charge_amount * 0.07 if state == FishingState.CHARGING else 0.0
	if state == FishingState.FIGHT:
		lift += sin(fight_clock * 4.2) * 0.035 * (0.4 + tension)
	arms_root.position.y = sin(elapsed * 1.4) * 0.014 + lift
	arms_root.rotation.z = sin(elapsed * 0.8) * 0.008


func _build_bobber_and_line() -> void:
	var bobber_red := MU.mat(Color("#e95a48"), 0.28)
	var bobber_white := MU.mat(Color("#f5e9ce"), 0.34)
	bobber = Node3D.new()
	bobber.name = "Поплавок"
	add_child(bobber)
	MU.sphere(bobber, Vector3(0.0, 0.10, 0.0), Vector3(0.105, 0.16, 0.105), bobber_red, "Красная часть", 24)
	MU.sphere(bobber, Vector3(0.0, -0.055, 0.0), Vector3(0.085, 0.12, 0.085), bobber_white, "Белая часть", 24)
	MU.capsule_between(bobber, Vector3(0.0, 0.22, 0.0), Vector3(0.0, 0.30, 0.0), 0.014, bobber_red, "Антенна поплавка", 8)
	bobber.visible = false
	line_root = Node3D.new()
	line_root.name = "Леска"
	add_child(line_root)
	var line_mat := MU.mat(Color("#efe2bf"), 0.6, 0.0, Color("#ffffff"), 0.15)
	for i in range(LINE_SEGS):
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.0075
		cyl.bottom_radius = 0.0075
		cyl.height = 1.0
		cyl.radial_segments = 6
		cyl.rings = 1
		mi.mesh = cyl
		mi.material_override = line_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		line_root.add_child(mi)
		line_segments.append(mi)
	line_root.visible = false


func _animate_bobber() -> void:
	if not bobber.visible:
		return
	var pos := bobber_pos
	match state:
		FishingState.WAITING:
			pos = float_anchor + Vector3(0.0, sin(elapsed * 2.4) * 0.025, 0.0)
			bobber.rotation.z = sin(elapsed * 2.0) * 0.08
		FishingState.BITE:
			pos = float_anchor + Vector3(sin(elapsed * 30.0) * 0.03, -0.08 - absf(sin(elapsed * 12.0)) * 0.11, 0.0)
			bobber.rotation.z = sin(elapsed * 14.0) * 0.25
		FishingState.FIGHT:
			var swing := (1.0 - fight_progress) * 1.6
			var base := float_anchor.lerp(REEL_TARGET, smoothstep(0.0, 1.0, fight_progress))
			pos = base + Vector3(cos(fight_clock * 1.7) * swing, -0.045 + sin(elapsed * 9.0) * 0.06, sin(fight_clock * 1.3) * swing * 0.5)
			bobber.rotation.z = sin(elapsed * 6.0) * 0.3
		FishingState.CASTING:
			bobber.rotation.z += 0.3
		_:
			pass
	bobber_pos = pos
	bobber.position = pos


func _update_line() -> void:
	if not line_root.visible or not bobber.visible:
		return
	var start := camera.to_global(rod_tip_local)
	var finish := bobber.global_position + Vector3(0.0, 0.11, 0.0)
	var sag := 0.0
	match state:
		FishingState.WAITING, FishingState.BITE:
			sag = 0.35
		FishingState.FIGHT:
			sag = lerpf(0.4, 0.0, clampf(tension * 1.2, 0.0, 1.0))
		FishingState.CASTING:
			sag = 0.1
	sag *= minf(1.5, start.distance_to(finish) * 0.12)
	line_sag = lerpf(line_sag, sag, 0.2)
	var prev := start
	for i in range(LINE_SEGS):
		var u := float(i + 1) / float(LINE_SEGS)
		var p := start.lerp(finish, u) + Vector3(0.0, -line_sag * sin(u * PI), 0.0)
		var d := p - prev
		var mi := line_segments[i]
		mi.position = (prev + p) * 0.5
		if d.length() > 0.0001:
			mi.quaternion = Quaternion(Vector3.UP, d.normalized())
		mi.scale = Vector3(1.0, maxf(0.001, d.length()), 1.0)
		prev = p


# ---------------------------------------------------------------- рыбалка
func _cast_line() -> void:
	var rod: Dictionary = Data.RODS[selected_rod]
	cast_distance = lerpf(7.0, 24.0, charge_amount) * float(rod["cast"])
	var aim := camera.global_position - camera.global_basis.z * cast_distance
	aim.x += rng.randf_range(-0.55, 0.55)
	aim.y = 0.03
	aim.x = clampf(aim.x, -15.0, 15.0)
	aim.z = clampf(aim.z, -21.5, -8.7)
	float_anchor = aim
	cast_from = camera.to_global(rod_tip_local)
	cast_time = 0.0
	bobber_pos = cast_from
	bobber.position = cast_from
	bobber.visible = true
	line_root.visible = true
	charge_amount = 0.0
	rod_kick = -0.42
	state = FishingState.CASTING
	audio.play("cast", 0.9, rng.randf_range(0.95, 1.08))


func _start_bite() -> void:
	state = FishingState.BITE
	bite_timer = 2.9 if OS.has_feature("mobile") else 2.7
	ripple_cooldown = 0.0
	audio.play("bite", 1.0)
	scenery.splash(float_anchor, 0.5)
	_show_toast("ПОПЛАВОК ДЁРНУЛСЯ!", "Подсекай!", Color("#ffd27f"))


func _start_fight() -> void:
	state = FishingState.FIGHT
	reel_held = true
	fight_clock = 0.0
	fight_progress = 0.08
	tension = 0.38
	zero_progress_time = 0.0
	dash_timer = rng.randf_range(2.0, 4.0)
	dash_left = 0.0
	fish_id = Data.pick_species(selected_lake, rng)
	var rod: Dictionary = Data.RODS[selected_rod]
	fish_weight = Data.roll_weight(fish_id, float(rod["max_weight"]), rng)
	var spec: Dictionary = Data.FISH[fish_id]
	fish_power = 0.85 + 0.10 * float(spec["rarity"]) + 0.45 * clampf(fish_weight / maxf(0.5, float(rod["max_weight"])), 0.0, 1.0)
	audio.play("hook", 0.9)
	scenery.splash(float_anchor, 0.9)
	_show_toast("ЕСТЬ!", "Аккуратно вываживай", Color("#8ed7c2"))


func _update_fight(delta: float) -> void:
	var rod: Dictionary = Data.RODS[selected_rod]
	var natural_pull := (sin(fight_clock * 2.1) * 0.055 + sin(fight_clock * 0.73) * 0.035) * fish_power
	dash_timer -= delta
	if dash_timer <= 0.0:
		dash_timer = rng.randf_range(2.6, 5.0)
		dash_left = 0.7
		audio.play_random_pitch("flap", 0.7)
		scenery.splash(bobber_pos, 0.7)
	var dash := 0.0
	if dash_left > 0.0:
		dash_left -= delta
		dash = 0.32 * fish_power
	if reel_held:
		tension += delta * (0.21 * float(rod["stress"]) * fish_power + dash) + natural_pull * delta * 2.0
		if tension < 0.80:
			fight_progress = minf(1.0, fight_progress + delta * float(rod["reel"]) / fish_power)
		else:
			fight_progress = maxf(0.0, fight_progress - delta * 0.13)
	else:
		tension -= delta * 0.27
		tension += natural_pull * delta + dash * delta * 0.5
		fight_progress = maxf(0.0, fight_progress - delta * 0.02 * fish_power)
	tension = clampf(tension, 0.13, 1.0)
	audio.set_reeling(reel_held and tension < 0.9, tension)
	warn_cooldown -= delta
	if tension > 0.8 and warn_cooldown <= 0.0:
		warn_cooldown = 0.45
		audio.play("warn", 0.5)
	ripple_cooldown -= delta
	if ripple_cooldown <= 0.0:
		ripple_cooldown = 0.55
		scenery.add_ripple(bobber_pos, 0.7)
	if tension >= 0.97:
		_show_toast("ЛЕСКА НАТЯНУЛАСЬ!", "Отпусти кнопку на мгновение", Color("#f28b6d"))
		tension = 0.82
		fight_progress = maxf(0.0, fight_progress - 0.12)
	if fight_progress <= 0.0:
		zero_progress_time += delta
		if zero_progress_time > 1.6:
			_fish_escaped()
			return
	else:
		zero_progress_time = 0.0
	if fight_progress >= 1.0:
		_begin_landing()


func _fish_escaped() -> void:
	audio.set_reeling(false)
	audio.play("fail", 0.9)
	_show_toast("РЫБА СОРВАЛАСЬ", "Не спеши и следи за натяжением", Color("#f28b6d"))
	scenery.splash(bobber_pos, 1.0)
	_reset_line()


func _begin_landing() -> void:
	audio.set_reeling(false)
	var spec: Dictionary = Data.FISH[fish_id]
	var rarity: int = spec["rarity"]
	var reward := roundi((45.0 + fish_weight * 38.0) * float(Data.RARITY_REWARD[rarity]))
	land_new = not collection.has(fish_id)
	if land_new:
		reward += 100
	land_reward = reward
	coins += reward
	total_catches += 1
	best_weight = maxf(best_weight, fish_weight)
	var entry: Dictionary = collection.get(fish_id, {"count": 0, "best": 0.0})
	entry["count"] = int(entry["count"]) + 1
	entry["best"] = maxf(float(entry["best"]), fish_weight)
	collection[fish_id] = entry
	_save_progress()
	if menu != null:
		menu.refresh()
	land_start = bobber_pos
	land_time = 0.0
	land_coin_played = false
	land_sparkled = false
	land_skip = false
	state = FishingState.LANDING
	bobber.visible = false
	line_root.visible = false
	scenery.splash(land_start, 1.4)
	audio.play("splash", 1.0)
	catch_fish = FishModel.build(spec)
	add_child(catch_fish)
	catch_fish.position = land_start
	_show_catch_card(spec, rarity)


func _hold_scale(spec: Dictionary) -> float:
	var length: float = spec["len"]
	var visual := clampf(0.95 + 0.6 * clampf(fish_weight / float(spec["max"]), 0.0, 1.0), 0.95, 1.55)
	return visual / maxf(0.35, length)


func _update_landing(delta: float) -> void:
	land_time += delta
	if catch_fish == null:
		state = FishingState.READY
		return
	var spec: Dictionary = Data.FISH[fish_id]
	var s := _hold_scale(spec)
	var hold_world := camera.to_global(HOLD_LOCAL)
	var flight := 0.9
	var hold_end := 3.4
	if land_time < flight:
		var u := land_time / flight
		var e := 1.0 - pow(1.0 - u, 2.0)
		catch_fish.position = land_start.lerp(hold_world, e) + Vector3(0.0, sin(u * PI) * 1.9, 0.0)
		catch_fish.scale = Vector3.ONE * lerpf(0.3, s, e)
		catch_fish.rotation = Vector3(u * TAU * 1.2, -0.45 * u, sin(u * PI * 3.0) * 0.5)
		FishModel.animate(catch_fish, elapsed, 1.0)
	elif land_time < hold_end and not land_skip:
		var k := land_time - flight
		catch_fish.position = hold_world + Vector3(sin(k * 1.3) * 0.03, sin(k * 2.0) * 0.04, 0.0)
		catch_fish.scale = Vector3.ONE * s * (1.0 + sin(k * 3.0) * 0.015)
		catch_fish.rotation = Vector3(0.12, -0.45 + sin(k * 0.9) * 0.3, 0.05 + sin(k * 1.7) * 0.06)
		FishModel.animate(catch_fish, elapsed, maxf(0.0, 1.0 - k * 0.5))
		if not land_sparkled:
			land_sparkled = true
			_spawn_sparkles(hold_world)
			audio.play("new_species" if land_new else "catch", 0.9)
			if land_new:
				audio.duck_music(0.35, 1.5)
		if k > 0.35 and not land_coin_played:
			land_coin_played = true
			audio.play("coin", 0.8)
	else:
		if land_skip and land_time < hold_end:
			land_time = hold_end
			land_skip = false
		var out_t := (land_time - hold_end) / 0.55
		var target := camera.to_global(Vector3(-1.15, -0.9, -1.25))
		var e2 := clampf(out_t, 0.0, 1.0)
		catch_fish.position = hold_world.lerp(target, e2 * e2)
		catch_fish.scale = Vector3.ONE * s * (1.0 - e2)
		if out_t >= 1.0:
			catch_fish.queue_free()
			catch_fish = null
			_hide_catch_card()
			state = FishingState.READY
			charge_amount = 0.0


func _spawn_sparkles(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 46
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 1.1
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3(0.0, -0.8, 0.0)
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	var m := SphereMesh.new()
	m.radius = 0.025
	m.height = 0.05
	m.radial_segments = 8
	m.rings = 4
	var color := Color("#ffe29a")
	if land_new:
		color = Color("#ffd35f")
	m.material = MU.unshaded(color)
	p.mesh = m
	p.position = pos
	p.emitting = true
	add_child(p)
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)


func _reset_line() -> void:
	state = FishingState.READY
	reel_held = false
	charge_amount = 0.0
	if audio != null:
		audio.set_reeling(false)
	if bobber != null:
		bobber.visible = false
	if line_root != null:
		line_root.visible = false
	if catch_fish != null:
		catch_fish.queue_free()
		catch_fish = null
	if catch_card != null:
		catch_card.visible = false


# ---------------------------------------------------------------- меню и пауза
func _on_menu_play(lake_index: int) -> void:
	if lake_index != selected_lake:
		_select_lake(lake_index)
	_start_fishing()


func _start_fishing() -> void:
	game_started = true
	paused = false
	menu.hide_all()
	ui_root.visible = true
	_reset_line()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	camera.look_at_from_position(CAM_POS, CAM_TARGET, Vector3.UP)
	var control_hint := "Зажми экран и отпусти для заброса" if OS.has_feature("android") else "Зажми и отпусти ЛКМ, чтобы забросить"
	_show_toast("УДОЧКА ГОТОВА", control_hint, Color("#f1cf9e"))
	audio.play("open", 0.7)
	_layout_ui()


func _show_menu(page: String = "main") -> void:
	_reset_line()
	game_started = false
	paused = false
	if ui_root != null:
		ui_root.visible = false
	menu.show_page(page)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _pause_game() -> void:
	if state == FishingState.CHARGING:
		state = FishingState.READY
		charge_amount = 0.0
	reel_held = false
	audio.set_reeling(false)
	paused = true
	menu.show_pause()
	audio.play("open", 0.6)


func _resume_from_pause() -> void:
	paused = false
	menu.hide_all()
	audio.play("back", 0.6)


func _exit_lake() -> void:
	audio.play("back", 0.7)
	_show_menu("lakes")


func _quit_game() -> void:
	_save_progress()
	get_tree().quit()


# ---------------------------------------------------------------- магазин
func buy_or_equip_rod(index: int) -> String:
	if owned_rods[index]:
		_select_rod(index)
		audio.play("click", 0.8)
		return "Экипирована: %s" % String(Data.RODS[index]["name"])
	var price := int(Data.RODS[index]["price"])
	if coins < price:
		audio.play("fail", 0.6)
		return "Не хватает %d монет. Поймай рыбу, чтобы заработать." % (price - coins)
	coins -= price
	owned_rods[index] = true
	_select_rod(index)
	audio.play("buy", 1.0)
	_save_progress()
	return "Куплена и экипирована: %s" % String(Data.RODS[index]["name"])


func species_found() -> int:
	return collection.size()


func reset_progress() -> void:
	coins = 500
	for i in range(owned_rods.size()):
		owned_rods[i] = int(Data.RODS[i]["price"]) == 0
	selected_rod = 1
	collection = {}
	total_catches = 0
	best_weight = 0.0
	_apply_rod_look()
	_save_progress()


func set_volume(kind: String, value: float) -> void:
	match kind:
		"music":
			music_volume = value
			audio.set_music_volume(value)
		"sfx":
			sfx_volume = value
			audio.set_sfx_volume(value)
		"ambient":
			ambient_volume = value
			audio.set_ambient_volume(value)
	_save_progress()


func _load_progress() -> void:
	var f := ConfigFile.new()
	if f.load(SAVE_PATH) != OK:
		return
	coins = int(f.get_value("player", "coins", coins))
	var saved_rods: Variant = f.get_value("player", "owned_rods", owned_rods)
	if saved_rods is Array:
		for i in range(mini(saved_rods.size(), owned_rods.size())):
			owned_rods[i] = bool(saved_rods[i])
	selected_rod = clampi(int(f.get_value("player", "selected_rod", selected_rod)), 0, Data.RODS.size() - 1)
	if not owned_rods[selected_rod]:
		selected_rod = 1
	selected_lake = clampi(int(f.get_value("player", "selected_lake", 0)), 0, Data.LAKES.size() - 1)
	total_catches = int(f.get_value("player", "catches", 0))
	best_weight = float(f.get_value("player", "best_weight", 0.0))
	var col: Variant = f.get_value("player", "collection", {})
	if col is Dictionary:
		collection = col
	music_volume = float(f.get_value("settings", "music", music_volume))
	sfx_volume = float(f.get_value("settings", "sfx", sfx_volume))
	ambient_volume = float(f.get_value("settings", "ambient", ambient_volume))


func _save_progress() -> void:
	var f := ConfigFile.new()
	f.set_value("player", "coins", coins)
	f.set_value("player", "owned_rods", owned_rods)
	f.set_value("player", "selected_rod", selected_rod)
	f.set_value("player", "selected_lake", selected_lake)
	f.set_value("player", "catches", total_catches)
	f.set_value("player", "best_weight", best_weight)
	f.set_value("player", "collection", collection)
	f.set_value("settings", "music", music_volume)
	f.set_value("settings", "sfx", sfx_volume)
	f.set_value("settings", "ambient", ambient_volume)
	f.save(SAVE_PATH)


# ---------------------------------------------------------------- интерфейс игры
func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 5
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.name = "Игровой интерфейс"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.visible = false
	ui_layer.add_child(ui_root)

	exit_button = IconButton.new()
	exit_button.name = "Выйти с озера"
	ui_root.add_child(exit_button)
	exit_button.setup("exit", 58.0)
	exit_button.tooltip_text = "Выйти с озера"
	exit_button.pressed.connect(_exit_lake)
	pause_button = IconButton.new()
	pause_button.name = "Пауза"
	ui_root.add_child(pause_button)
	pause_button.setup("pause", 58.0)
	pause_button.tooltip_text = "Пауза"
	pause_button.pressed.connect(_pause_game)

	lake_panel = UI.panel(ui_root, Vector2.ZERO, Vector2(300, 58), Color(0.035, 0.075, 0.09, 0.78), 29)
	lake_label = UI.label(lake_panel, "", Vector2(24, 7), Vector2(260, 24), 16, UI.CREAM)
	season_label = UI.label(lake_panel, "", Vector2(24, 31), Vector2(260, 18), 11, Color("#d49f71"))

	stats_panel = UI.panel(ui_root, Vector2.ZERO, Vector2(310, 58), Color(0.035, 0.075, 0.09, 0.78), 29)
	stats_label = UI.label(stats_panel, "", Vector2(24, 7), Vector2(270, 24), 15, UI.CREAM)
	coins_label = UI.label(stats_panel, "", Vector2(24, 31), Vector2(270, 20), 13, UI.GOLD)

	hint_panel = UI.panel(ui_root, Vector2.ZERO, Vector2(660, 76), Color(0.025, 0.055, 0.07, 0.82), 38)
	hint_label = UI.label(hint_panel, "", Vector2(28, 10), Vector2(604, 30), 17, Color("#f5dfbf"), HORIZONTAL_ALIGNMENT_CENTER)
	subhint_label = UI.label(hint_panel, "", Vector2(28, 42), Vector2(604, 24), 13, Color("#a9c0ba"), HORIZONTAL_ALIGNMENT_CENTER)

	toast_panel = UI.panel(ui_root, Vector2.ZERO, Vector2(560, 92), Color(0.03, 0.06, 0.075, 0.82), 46)
	toast_label = UI.label(toast_panel, "", Vector2(20, 9), Vector2(520, 40), 26, Color("#fff0d6"), HORIZONTAL_ALIGNMENT_CENTER)
	toast_sub = UI.label(toast_panel, "", Vector2(20, 54), Vector2(520, 28), 14, Color("#b7c8c1"), HORIZONTAL_ALIGNMENT_CENTER)
	toast_panel.visible = false

	gauge = RingGauge.new()
	gauge.name = "Кольцо-прицел"
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(gauge)

	catch_card = UI.panel(ui_root, Vector2.ZERO, Vector2(520, 150), Color(0.03, 0.06, 0.075, 0.9), 44, Color("#e4b475"))
	catch_name = UI.label(catch_card, "", Vector2(24, 14), Vector2(472, 44), 32, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	catch_info = UI.label(catch_card, "", Vector2(24, 62), Vector2(472, 28), 18, Color("#d9e2d7"), HORIZONTAL_ALIGNMENT_CENTER)
	catch_rarity = UI.label(catch_card, "", Vector2(24, 96), Vector2(472, 24), 15, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	catch_new = UI.label(catch_card, "", Vector2(24, 120), Vector2(472, 22), 13, Color("#8ed7c2"), HORIZONTAL_ALIGNMENT_CENTER)
	catch_card.visible = false


func _layout_ui() -> void:
	if ui_root == null:
		return
	var vs := get_viewport().get_visible_rect().size
	exit_button.position = Vector2(22, 20)
	pause_button.position = Vector2(88, 20)
	lake_panel.position = Vector2(160, 20)
	stats_panel.position = Vector2(vs.x - 332, 20)
	hint_panel.position = Vector2((vs.x - 660.0) * 0.5, vs.y - 108)
	toast_panel.position = Vector2((vs.x - 560.0) * 0.5, vs.y * 0.17)
	catch_card.position = Vector2((vs.x - 520.0) * 0.5, vs.y - 290.0)
	gauge.position = vs * 0.5


func _show_toast(title: String, subtitle: String, color: Color) -> void:
	toast_label.text = title
	toast_sub.text = subtitle
	toast_label.add_theme_color_override("font_color", color)
	toast_timer = 2.6
	toast_panel.modulate.a = 1.0
	toast_panel.visible = true


func _show_catch_card(spec: Dictionary, rarity: int) -> void:
	var rc := Color(String(Data.RARITY_COLORS[rarity]))
	catch_name.text = String(spec["name"])
	catch_name.add_theme_color_override("font_color", rc.lerp(UI.CREAM, 0.35))
	catch_info.text = "%.1f кг   •   +%d монет" % [fish_weight, land_reward]
	catch_rarity.text = "%s  %s" % [String(Data.RARITY_NAMES[rarity]), "★".repeat(rarity)]
	catch_rarity.add_theme_color_override("font_color", rc)
	catch_new.text = "НОВЫЙ ВИД В КОЛЛЕКЦИИ!  +100 монет" if land_new else "Уже в коллекции: %d шт., рекорд %.1f кг" % [int(collection[fish_id]["count"]), float(collection[fish_id]["best"])]
	catch_new.add_theme_color_override("font_color", Color("#ffd35f") if land_new else Color("#8ea69f"))
	catch_card.visible = true
	catch_card.pivot_offset = catch_card.size * 0.5
	catch_card.scale = Vector2(0.6, 0.6)
	catch_card.modulate.a = 0.0
	if catch_tween != null:
		catch_tween.kill()
	catch_tween = create_tween().set_parallel(true)
	catch_tween.tween_property(catch_card, "scale", Vector2.ONE, 0.45).set_delay(0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	catch_tween.tween_property(catch_card, "modulate:a", 1.0, 0.3).set_delay(0.7)


func _hide_catch_card() -> void:
	if catch_tween != null:
		catch_tween.kill()
	catch_tween = create_tween()
	catch_tween.tween_property(catch_card, "modulate:a", 0.0, 0.25)
	catch_tween.tween_callback(func(): catch_card.visible = false)


func _update_hud() -> void:
	if hint_label == null or not ui_root.visible:
		return
	var on_android := OS.has_feature("android")
	stats_label.text = "%d рыб  •  рекорд %s" % [total_catches, ("%.1f кг" % best_weight) if best_weight > 0.0 else "—"]
	coins_label.text = "МОНЕТЫ  %d   •   ВИДЫ %d/%d" % [coins, species_found(), Data.FISH.size()]
	var ring: Control = gauge
	match state:
		FishingState.CHARGING:
			hint_label.text = "ОТПУСТИ ПАЛЕЦ, ЧТОБЫ ЗАБРОСИТЬ" if on_android else "ОТПУСТИ ЛКМ, ЧТОБЫ ЗАБРОСИТЬ"
			subhint_label.text = "Сила заброса: %d%%" % int(charge_amount * 100.0)
			ring.set("value", charge_amount)
			ring.set("inner_value", -1.0)
			ring.set("color", Color("#e4ad6e"))
		FishingState.CASTING:
			hint_label.text = "ЛЕТИТ ПОПЛАВОК..."
			subhint_label.text = "Леска размотана"
			ring.set("value", 0.0)
			ring.set("inner_value", -1.0)
		FishingState.WAITING:
			hint_label.text = "ПОПЛАВОК НА ВОДЕ"
			subhint_label.text = "Тихо... ждём поклёвку"
			ring.set("value", 0.0)
			ring.set("inner_value", -1.0)
		FishingState.BITE:
			hint_label.text = "ПОКЛЁВКА! КОСНИСЬ ЭКРАНА, ЧТОБЫ ПОДСЕЧЬ" if on_android else "ПОКЛЁВКА! КЛИКНИ ЛКМ, ЧТОБЫ ПОДСЕЧЬ"
			subhint_label.text = "Не медли — рыба уже на крючке"
			ring.set("value", 1.0)
			ring.set("inner_value", -1.0)
			ring.set("color", Color("#ffd27f"))
			ring.set("pulse", absf(sin(elapsed * 14.0)) * 3.0)
		FishingState.FIGHT:
			hint_label.text = "ВЫВАЖИВАНИЕ  •  %d%%" % int(fight_progress * 100.0)
			subhint_label.text = "Держи палец; отпусти при сильном натяжении" if on_android else "Тяни ЛКМ и отпускай, если натяжение выше 75%"
			ring.set("value", tension)
			ring.set("inner_value", fight_progress)
			ring.set("color", Color("#ec795d") if tension > 0.78 else Color("#77c7b3"))
			ring.set("pulse", 0.0)
		FishingState.LANDING:
			hint_label.text = "ОТЛИЧНЫЙ УЛОВ!"
			subhint_label.text = "Нажми, чтобы продолжить" if land_time > 1.1 else ""
			ring.set("value", 0.0)
			ring.set("inner_value", -1.0)
		_:
			hint_label.text = "ЗАЖМИ ЭКРАН — ЗАРЯДИ  •  ОТПУСТИ — ЗАБРОСЬ" if on_android else "ЗАЖМИ ЛКМ — ЗАРЯДИ  •  ОТПУСТИ — ЗАБРОСЬ"
			subhint_label.text = "Чем дольше держишь, тем дальше летит поплавок"
			ring.set("value", 0.0)
			ring.set("inner_value", -1.0)
	ring.queue_redraw()
