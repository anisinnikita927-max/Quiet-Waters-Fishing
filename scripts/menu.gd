extends Control
## Главное меню, выбор озера, магазин, коллекция рыб, настройки и пауза.

const Data = preload("res://scripts/game_data.gd")
const FishModel = preload("res://scripts/fish_model.gd")
const MU = preload("res://scripts/mesh_util.gd")
const UI = preload("res://scripts/ui_kit.gd")
const Orb = preload("res://scripts/orb.gd")
const IconButton = preload("res://scripts/icon_button.gd")
const ROUND_MASK = preload("res://shaders/round_mask.gdshader")

signal play_requested(lake_index: int)
signal resume_requested
signal exit_lake_requested
signal quit_requested

const DESIGN := Vector2(1600, 900)

var game: Node3D
var shade: ColorRect
var content: Control
var pages: Dictionary = {}
var current_page := ""
var origin := "menu"   # откуда открыта страница: menu или pause
var page_tween: Tween

var wallet_labels: Array[Label] = []
var lake_cards: Array[Button] = []
var lake_info_label: Label
var main_info: Control
var main_orb: Control
var main_lake_label: Label
var main_stats_label: Label
var shop_status: Label
var rod_buttons: Array[Button] = []
var rod_price_labels: Array[Label] = []
var stage_vp: SubViewport
var stage_world: World3D
var rod_viewports: Array[SubViewport] = []
var fish_viewports: Dictionary = {}
var fish_nodes: Dictionary = {}
var fish_state: Dictionary = {}
var fish_cards: Dictionary = {}
var collection_header: Label
var species_order: Array = []
var pause_root: Control
var reset_button: Button
var reset_armed := 0.0
var slider_labels: Dictionary = {}


func setup(main_game: Node3D) -> void:
	game = main_game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for lake in Data.LAKES:
		for id in lake["fish"]:
			if not species_order.has(id):
				species_order.append(id)
	shade = ColorRect.new()
	shade.color = Color(0.01, 0.03, 0.04, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	content = Control.new()
	content.size = DESIGN
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	_build_stage()
	_build_main_page()
	_build_lakes_page()
	_build_shop_page()
	_build_collection_page()
	_build_settings_page()
	_build_pause()
	get_viewport().size_changed.connect(_layout)
	_layout()
	visible = false


func _process(delta: float) -> void:
	if reset_armed > 0.0:
		reset_armed -= delta
		if reset_armed <= 0.0 and reset_button != null:
			reset_button.text = "СБРОСИТЬ ПРОГРЕСС"


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	content.position = ((vs - DESIGN) * 0.5).floor()
	if pause_root != null:
		pause_root.position = ((vs - DESIGN) * 0.5).floor()


# ---------------------------------------------------------------- общие помощники
func _sfx(name: String, volume: float = 1.0) -> void:
	if game != null and game.audio != null:
		game.audio.play(name, volume)


func _btn(parent: Control, text: String, pos: Vector2, size: Vector2, font_size: int, kind: String, callback: Callable) -> Button:
	var b := UI.button(parent, text, pos, size, font_size, kind)
	b.mouse_entered.connect(func(): _sfx("hover", 0.5))
	b.pressed.connect(func():
		_sfx("click", 0.8)
		callback.call())
	return b


func _icon_btn(parent: Control, kind: String, pos: Vector2, diameter: float, callback: Callable) -> Button:
	var b := IconButton.new()
	parent.add_child(b)
	b.setup(kind, diameter)
	b.position = pos
	b.mouse_entered.connect(func(): _sfx("hover", 0.5))
	b.pressed.connect(func():
		_sfx("back", 0.7)
		callback.call())
	return b


func _page_frame(name: String, title: String, subtitle: String = "") -> Control:
	var page := Control.new()
	page.name = name
	page.size = DESIGN
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.visible = false
	content.add_child(page)
	pages[name] = page
	UI.panel(page, Vector2(90, 50), Vector2(1420, 800), UI.PANEL, 48)
	_icon_btn(page, "back", Vector2(128, 84), 60.0, _go_back)
	UI.label(page, title, Vector2(208, 82), Vector2(760, 50), 36, UI.CREAM)
	if subtitle != "":
		UI.label(page, subtitle, Vector2(210, 128), Vector2(900, 26), 15, UI.MUTED)
	var wallet := UI.panel(page, Vector2(1190, 88), Vector2(290, 54), Color(0.09, 0.16, 0.18, 0.95), 27)
	var wl := UI.label(wallet, "", Vector2(0, 12), Vector2(290, 30), 18, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	wallet_labels.append(wl)
	return page


func _go_back() -> void:
	if origin == "pause":
		show_pause()
	else:
		show_page("main")


func handle_escape() -> void:
	if pause_root.visible:
		game._resume_from_pause()
	elif current_page != "main":
		_go_back()


func _fade_in(node: Control) -> void:
	if page_tween != null:
		page_tween.kill()
	node.modulate.a = 0.0
	node.position.y = 14.0
	page_tween = create_tween().set_parallel(true)
	page_tween.tween_property(node, "modulate:a", 1.0, 0.28)
	page_tween.tween_property(node, "position:y", 0.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func show_page(name: String) -> void:
	visible = true
	if pause_root != null:
		pause_root.visible = false
	shade.visible = true
	for k in pages:
		pages[k].visible = false
	current_page = name
	origin = "menu"
	if name == "main":
		shade.color = Color(0.01, 0.03, 0.04, 0.32)
	else:
		shade.color = Color(0.01, 0.03, 0.04, 0.62)
	var page: Control = pages[name]
	page.visible = true
	_fade_in(page)
	refresh()
	match name:
		"shop":
			for vp in rod_viewports:
				vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		"collection":
			_refresh_collection()


func show_pause() -> void:
	visible = true
	for k in pages:
		pages[k].visible = false
	current_page = "pause"
	origin = "pause"
	shade.visible = true
	shade.color = Color(0.01, 0.03, 0.04, 0.6)
	pause_root.visible = true
	_fade_in(pause_root)
	refresh()


func hide_all() -> void:
	visible = false
	pause_root.visible = false
	for k in pages:
		pages[k].visible = false


func refresh() -> void:
	if game == null:
		return
	for l in wallet_labels:
		l.text = "МОНЕТЫ  •  %d" % game.coins
	if main_lake_label != null:
		var lake: Dictionary = Data.LAKES[game.selected_lake]
		main_lake_label.text = String(lake["name"]).to_upper()
		(main_orb as Orb).setup(lake, 72.0)
		main_stats_label.text = "Удочка: %s\nМонеты: %d\nВидов рыб: %d из %d\nПоймано рыб: %d" % [String(Data.RODS[game.selected_rod]["name"]), game.coins, game.species_found(), Data.FISH.size(), game.total_catches]
	for i in range(lake_cards.size()):
		lake_cards[i].add_theme_stylebox_override("normal", UI.card_style(i == game.selected_lake))
		lake_cards[i].add_theme_stylebox_override("hover", UI.card_style(i == game.selected_lake, true))
		lake_cards[i].add_theme_stylebox_override("pressed", UI.card_style(true))
		var info: Label = lake_cards[i].get_meta("fish_label")
		var found := 0
		for id in Data.LAKES[i]["fish"]:
			if game.collection.has(id):
				found += 1
		info.text = "Виды рыб: %d/%d" % [found, Data.LAKES[i]["fish"].size()]
	if lake_info_label != null:
		lake_info_label.text = "Озеро: %s     •     Удочка: %s" % [String(Data.LAKES[game.selected_lake]["name"]), String(Data.RODS[game.selected_rod]["name"])]
	_update_shop()
	if collection_header != null:
		collection_header.text = "Собрано %d из %d видов" % [game.species_found(), Data.FISH.size()]


# ---------------------------------------------------------------- превью в кругах
func _build_stage() -> void:
	stage_world = World3D.new()
	stage_vp = SubViewport.new()
	stage_vp.name = "Сцена превью"
	stage_vp.size = Vector2i(64, 64)
	stage_vp.own_world_3d = false
	stage_vp.world_3d = stage_world
	stage_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(stage_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#20383d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c4d3c8")
	env.ambient_light_energy = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	stage_vp.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-34.0, -24.0, 0.0)
	light.light_color = Color("#ffe6c0")
	light.light_energy = 1.55
	stage_vp.add_child(light)


func _round_preview(parent: Control, pos: Vector2, diameter: float, stage_index: int, ortho_size: float, ring: Color = Color(0, 0, 0, 0)) -> SubViewport:
	var container := SubViewportContainer.new()
	container.position = pos
	container.size = Vector2(diameter, diameter)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = ROUND_MASK
	sm.set_shader_parameter("ring_color", ring)
	container.material = sm
	parent.add_child(container)
	var vp := SubViewport.new()
	vp.size = Vector2i(int(diameter), int(diameter))
	vp.own_world_3d = false
	vp.world_3d = stage_world
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	container.add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = ortho_size
	cam.position = Vector3(float(stage_index) * 8.0 + 0.2, 0.15, 6.0)
	cam.look_at_from_position(cam.position, Vector3(float(stage_index) * 8.0, 0.0, 0.0), Vector3.UP)
	vp.add_child(cam)
	cam.current = true
	return vp


# ---------------------------------------------------------------- главная страница
func _build_main_page() -> void:
	var page := Control.new()
	page.name = "main"
	page.size = DESIGN
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.visible = false
	content.add_child(page)
	pages["main"] = page
	UI.label(page, "QUIET WATERS", Vector2(104, 92), Vector2(900, 100), 86, Color("#fff0d6"))
	UI.label(page, "ТИХИЕ ВОДЫ  •  РЫБАЛКА ОТ ПЕРВОГО ЛИЦА", Vector2(110, 196), Vector2(900, 30), 20, UI.GOLD)
	var y := 292.0
	_btn(page, "ИГРАТЬ", Vector2(110, y), Vector2(440, 72), 26, "primary", func(): play_requested.emit(game.selected_lake))
	_btn(page, "ОЗЁРА", Vector2(110, y + 90), Vector2(440, 64), 21, "normal", func(): show_page("lakes"))
	_btn(page, "МАГАЗИН УДОЧЕК", Vector2(110, y + 170), Vector2(440, 64), 21, "normal", func(): show_page("shop"))
	_btn(page, "КОЛЛЕКЦИЯ РЫБ", Vector2(110, y + 250), Vector2(440, 64), 21, "normal", func(): show_page("collection"))
	_btn(page, "НАСТРОЙКИ", Vector2(110, y + 330), Vector2(440, 64), 21, "normal", func(): show_page("settings"))
	_btn(page, "ВЫХОД", Vector2(110, y + 410), Vector2(440, 64), 21, "danger", func(): quit_requested.emit())
	main_info = UI.panel(page, Vector2(1010, 150), Vector2(470, 380), Color(0.035, 0.075, 0.09, 0.82), 48)
	main_orb = Orb.new()
	main_info.add_child(main_orb)
	main_orb.position = Vector2(165, 26)
	(main_orb as Orb).setup(Data.LAKES[0], 72.0)
	main_lake_label = UI.label(main_info, "", Vector2(20, 184), Vector2(430, 32), 24, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	main_stats_label = UI.label(main_info, "", Vector2(44, 232), Vector2(390, 130), 16, Color("#c9d8d1"))
	UI.label(page, "Зажми ЛКМ и отпусти — заброс. Поклёвка — кликни. Тяни рыбу, следи за натяжением.", Vector2(110, 830), Vector2(1200, 28), 15, UI.DIM)


# ---------------------------------------------------------------- озёра
func _build_lakes_page() -> void:
	var page := _page_frame("lakes", "ВЫБЕРИ ОЗЕРО", "Каждое озеро — своя погода, музыка и рыба")
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(132, 178)
	scroll.size = Vector2(1336, 546)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(grid)
	for i in range(Data.LAKES.size()):
		var lake: Dictionary = Data.LAKES[i]
		var card := Button.new()
		card.custom_minimum_size = Vector2(424, 168)
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.add_theme_stylebox_override("normal", UI.card_style(false))
		card.add_theme_stylebox_override("hover", UI.card_style(false, true))
		card.add_theme_stylebox_override("pressed", UI.card_style(true))
		grid.add_child(card)
		var orb := Orb.new()
		card.add_child(orb)
		orb.position = Vector2(18, 26)
		orb.setup(lake, 58.0)
		orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.label(card, String(lake["name"]).to_upper(), Vector2(150, 16), Vector2(266, 28), 18, UI.CREAM)
		UI.label(card, String(lake["desc"]), Vector2(150, 48), Vector2(266, 62), 12, Color("#b7c8c1"))
		UI.label(card, "Музыка: %s" % String(lake["music_name"]), Vector2(150, 116), Vector2(266, 18), 11, UI.GOLD)
		var fl := UI.label(card, "", Vector2(150, 138), Vector2(266, 18), 11, UI.MUTED)
		card.set_meta("fish_label", fl)
		card.mouse_entered.connect(func(): _sfx("hover", 0.5))
		card.pressed.connect(func():
			_sfx("click", 0.8)
			game._select_lake(i)
			refresh())
		lake_cards.append(card)
	lake_info_label = UI.label(page, "", Vector2(140, 758), Vector2(820, 30), 16, Color("#d9e2d7"))
	_btn(page, "НА РЫБАЛКУ  →", Vector2(1090, 742), Vector2(380, 70), 24, "primary", func(): play_requested.emit(game.selected_lake))


# ---------------------------------------------------------------- магазин
func _build_shop_page() -> void:
	var page := _page_frame("shop", "МАГАЗИН УДОЧЕК", "Дальность заброса, скорость вываживания и вес трофея")
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(132, 178)
	scroll.size = Vector2(1336, 570)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(grid)
	for i in range(Data.RODS.size()):
		grid.add_child(_create_shop_card(i))
	shop_status = UI.label(page, "", Vector2(140, 758), Vector2(1200, 30), 16, Color("#d9e2d7"))


func _create_shop_card(index: int) -> Panel:
	var rod: Dictionary = Data.RODS[index]
	var card := Panel.new()
	card.custom_minimum_size = Vector2(650, 204)
	card.add_theme_stylebox_override("panel", UI.card_style(false))
	var vp := _round_preview(card, Vector2(20, 20), 164.0, index, 2.3)
	rod_viewports.append(vp)
	_build_rod_preview(index)
	UI.label(card, String(rod["name"]), Vector2(206, 16), Vector2(420, 26), 19, UI.CREAM)
	UI.label(card, String(rod["description"]), Vector2(206, 46), Vector2(420, 44), 12, Color("#b7c8c1"))
	UI.label(card, "Заброс %d%%   •   Тяга %d%%   •   Трофей до %.1f кг" % [int(float(rod["cast"]) * 100.0), int(float(rod["reel"]) * 100.0), float(rod["max_weight"])], Vector2(206, 96), Vector2(430, 20), 12, UI.GOLD)
	var price := UI.label(card, "", Vector2(206, 118), Vector2(300, 18), 12, UI.MUTED)
	rod_price_labels.append(price)
	var b := UI.button(card, "", Vector2(206, 146), Vector2(300, 42), 15, "normal")
	b.mouse_entered.connect(func(): _sfx("hover", 0.5))
	b.pressed.connect(func():
		shop_status.text = game.buy_or_equip_rod(index)
		refresh())
	rod_buttons.append(b)
	return card


func _build_rod_preview(index: int) -> void:
	var rod: Dictionary = Data.RODS[index]
	var root := Node3D.new()
	root.name = "Удочка %d" % index
	root.position = Vector3(float(index) * 8.0, 0.0, 0.0)
	stage_vp.add_child(root)
	var body_color := Color(String(rod["color"]))
	var body := MU.mat(body_color, 0.38, 0.28)
	var grip := MU.mat(Color("#363536"), 0.9)
	var metal := MU.mat(Color("#d9bf8c"), 0.34, 0.72)
	var spool_mat := MU.mat(body_color.lightened(0.27), 0.38, 0.45)
	var thick: float = rod["thick"] * 1.7
	var length_f: float = rod["len"]
	var a := Vector3(-0.94, -0.70, 0.0)
	var tip := a + (Vector3(0.88, 0.66, 0.0) - a) * length_f
	var prev := a
	for i in range(1, 9):
		var u := float(i) / 8.0
		var p := a + (tip - a) * u + Vector3(0.0, -0.12, 0.0) * u * u
		MU.cylinder_between(root, prev, p, lerpf(thick, 0.005, pow(float(i - 1) / 8.0, 0.85)), lerpf(thick, 0.005, pow(u, 0.85)), body, "Бланк удилища", 14)
		prev = p
	MU.capsule_between(root, a, a.lerp(tip, 0.3), thick * 1.7, grip, "Рукоять", 16)
	for t in [0.36, 0.52, 0.66, 0.79, 0.9]:
		var pt := a.lerp(tip, float(t)) + Vector3(0.0, -0.12 * float(t) * float(t), 0.0)
		MU.sphere(root, pt, Vector3.ONE * 0.04, metal, "Кольцо бланка", 10)
	var reel_r := 0.17 if index >= 5 else 0.13
	var reel := MU.cylinder(root, Vector3(-0.42, -0.30, 0.13), reel_r, 0.12, spool_mat, "Катушка", 28, 1.0)
	reel.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	MU.cylinder_between(root, Vector3(-0.42, -0.30, 0.0), Vector3(-0.42, -0.30, 0.16), 0.05, 0.05, metal, "Ось", 12)
	MU.capsule_between(root, Vector3(-0.42, -0.30, 0.21), Vector3(-0.62, -0.42, 0.21), 0.018, metal, "Ручка катушки", 8)
	MU.sphere(root, Vector3(-0.63, -0.43, 0.21), Vector3.ONE * 0.05, grip, "Набалдашник", 12)
	root.rotation_degrees = Vector3(0.0, -18.0, 4.0)


func _update_shop() -> void:
	if rod_buttons.is_empty():
		return
	for i in range(rod_buttons.size()):
		var button := rod_buttons[i]
		var price := int(Data.RODS[i]["price"])
		if game.owned_rods[i]:
			button.text = "ЭКИПИРОВАНА" if i == game.selected_rod else "ЭКИПИРОВАТЬ"
			button.disabled = i == game.selected_rod
			rod_price_labels[i].text = "ДОСТУПНА" if price == 0 else "В КОЛЛЕКЦИИ"
		else:
			button.text = "КУПИТЬ  •  %d МОНЕТ" % price
			button.disabled = game.coins < price
			rod_price_labels[i].text = "ЦЕНА  •  %d МОНЕТ" % price


# ---------------------------------------------------------------- коллекция
func _build_collection_page() -> void:
	var page := _page_frame("collection", "КОЛЛЕКЦИЯ РЫБ", "")
	collection_header = UI.label(page, "", Vector2(210, 128), Vector2(900, 26), 16, UI.GOLD)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(132, 178)
	scroll.size = Vector2(1336, 640)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)
	for i in range(species_order.size()):
		var id: String = species_order[i]
		var card := Panel.new()
		card.custom_minimum_size = Vector2(314, 300)
		card.add_theme_stylebox_override("panel", UI.card_style(false))
		grid.add_child(card)
		var vp := _round_preview(card, Vector2(64, 14), 186.0, 100 + i, 2.0, Color(1, 1, 1, 0.0))
		fish_viewports[id] = vp
		var name_label := UI.label(card, "", Vector2(12, 206), Vector2(290, 28), 19, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
		var info_label := UI.label(card, "", Vector2(14, 234), Vector2(286, 60), 12, Color("#b7c8c1"), HORIZONTAL_ALIGNMENT_CENTER)
		fish_cards[id] = {"card": card, "name": name_label, "info": info_label}


func _lake_of_species(id: String) -> String:
	for lake in Data.LAKES:
		if lake["fish"].has(id):
			return String(lake["name"])
	return ""


func _make_silhouette(node: Node) -> void:
	var dark := MU.unshaded(Color("#0b171a"))
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	for child in node.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).material_override = dark


func _refresh_collection() -> void:
	for i in range(species_order.size()):
		var id: String = species_order[i]
		var spec: Dictionary = Data.FISH[id]
		var caught: bool = game.collection.has(id)
		var ui: Dictionary = fish_cards[id]
		var st: String = fish_state.get(id, "")
		var want := "seen" if caught else "hidden"
		if st != want:
			if fish_nodes.has(id):
				(fish_nodes[id] as Node).queue_free()
			var f := FishModel.build(spec)
			f.scale = Vector3.ONE * (1.55 / maxf(float(spec["len"]), 0.3))
			f.position = Vector3(float(100 + i) * 8.0, 0.0, 0.0)
			f.rotation_degrees = Vector3(14.0, -28.0, 0.0)
			stage_vp.add_child(f)
			if not caught:
				_make_silhouette(f)
			fish_nodes[id] = f
			fish_state[id] = want
		(fish_viewports[id] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
		var rc := Color(String(Data.RARITY_COLORS[int(spec["rarity"])]))
		var card: Panel = ui["card"]
		card.add_theme_stylebox_override("panel", UI.style(UI.CARD, rc if caught else UI.BORDER, 30, 2 if caught else 1, Vector4(0, 0, 0, 0)))
		var nl: Label = ui["name"]
		var il: Label = ui["info"]
		if caught:
			var entry: Dictionary = game.collection[id]
			nl.text = String(spec["name"])
			nl.add_theme_color_override("font_color", rc.lerp(UI.CREAM, 0.4))
			il.text = "%s  %s\nПоймано: %d  •  рекорд %.1f кг\n%s" % [String(Data.RARITY_NAMES[int(spec["rarity"])]), "★".repeat(int(spec["rarity"])), int(entry["count"]), float(entry["best"]), String(spec["note"])]
		else:
			nl.text = "???"
			nl.add_theme_color_override("font_color", UI.DIM)
			il.text = "Водится: %s\n%s" % [_lake_of_species(id), String(Data.RARITY_NAMES[int(spec["rarity"])])]


# ---------------------------------------------------------------- настройки
func _build_settings_page() -> void:
	var page := _page_frame("settings", "НАСТРОЙКИ", "Громкость и прогресс")
	var y := 210.0
	for entry in [["music", "МУЗЫКА"], ["sfx", "ЗВУКИ"], ["ambient", "АТМОСФЕРА ОЗЕРА"]]:
		var kind: String = entry[0]
		UI.label(page, String(entry[1]), Vector2(180, y), Vector2(360, 30), 20, UI.CREAM)
		var slider := HSlider.new()
		slider.position = Vector2(560, y + 2)
		slider.size = Vector2(620, 28)
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = {"music": game.music_volume, "sfx": game.sfx_volume, "ambient": game.ambient_volume}[kind]
		slider.focus_mode = Control.FOCUS_NONE
		_style_slider(slider)
		page.add_child(slider)
		var pct := UI.label(page, "", Vector2(1210, y), Vector2(120, 30), 20, UI.GOLD)
		slider_labels[kind] = pct
		pct.text = "%d%%" % int(slider.value * 100.0)
		slider.value_changed.connect(func(v: float):
			pct.text = "%d%%" % int(v * 100.0)
			game.set_volume(kind, v))
		slider.drag_ended.connect(func(_changed: bool): _sfx("click", 0.8))
		y += 84.0
	if not OS.has_feature("mobile"):
		var fs := CheckButton.new()
		fs.text = "  ПОЛНОЭКРАННЫЙ РЕЖИМ"
		fs.position = Vector2(176, y + 4)
		fs.focus_mode = Control.FOCUS_NONE
		fs.add_theme_font_size_override("font_size", 20)
		fs.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		fs.toggled.connect(func(on: bool):
			_sfx("click", 0.8)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
		page.add_child(fs)
		y += 84.0
	reset_button = _btn(page, "СБРОСИТЬ ПРОГРЕСС", Vector2(180, y + 20), Vector2(420, 62), 19, "danger", _on_reset_pressed)
	UI.label(page, "Удаляет монеты, купленные удочки и коллекцию рыб.", Vector2(624, y + 36), Vector2(700, 28), 14, UI.DIM)
	UI.label(page, "Quiet Waters: Fishing  •  Godot 4  •  музыка и звуки созданы процедурно", Vector2(180, 764), Vector2(1200, 26), 14, UI.DIM)


func _style_slider(slider: HSlider) -> void:
	var track := UI.style(Color(1, 1, 1, 0.14), Color(0, 0, 0, 0), 10, 0, Vector4(0, 0, 0, 0))
	track.content_margin_top = 5.0
	track.content_margin_bottom = 5.0
	var fill := UI.style(UI.GOLD, Color(0, 0, 0, 0), 10, 0, Vector4(0, 0, 0, 0))
	fill.content_margin_top = 5.0
	fill.content_margin_bottom = 5.0
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := GradientTexture2D.new()
	knob.width = 34
	knob.height = 34
	knob.fill = GradientTexture2D.FILL_RADIAL
	knob.fill_from = Vector2(0.5, 0.5)
	knob.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.colors = PackedColorArray([Color("#fff0d6"), Color("#fff0d6"), Color(1, 1, 1, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.94, 1.0])
	knob.gradient = g
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", knob)


func _on_reset_pressed() -> void:
	if reset_armed > 0.0:
		reset_armed = 0.0
		reset_button.text = "СБРОСИТЬ ПРОГРЕСС"
		game.reset_progress()
		for id in fish_state.keys():
			fish_state[id] = ""
		refresh()
	else:
		reset_armed = 3.0
		reset_button.text = "ТОЧНО СБРОСИТЬ? НАЖМИ ЕЩЁ РАЗ"


# ---------------------------------------------------------------- пауза
func _build_pause() -> void:
	pause_root = Control.new()
	pause_root.name = "Пауза"
	pause_root.size = DESIGN
	pause_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_root.visible = false
	add_child(pause_root)
	UI.panel(pause_root, Vector2(540, 140), Vector2(520, 600), UI.PANEL, 56)
	UI.label(pause_root, "ПАУЗА", Vector2(540, 172), Vector2(520, 60), 44, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	var y := 270.0
	_btn(pause_root, "ПРОДОЛЖИТЬ", Vector2(600, y), Vector2(400, 66), 22, "primary", func(): resume_requested.emit())
	_btn(pause_root, "КОЛЛЕКЦИЯ РЫБ", Vector2(600, y + 84), Vector2(400, 60), 19, "normal", func(): _open_from_pause("collection"))
	_btn(pause_root, "НАСТРОЙКИ", Vector2(600, y + 158), Vector2(400, 60), 19, "normal", func(): _open_from_pause("settings"))
	_btn(pause_root, "ВЫЙТИ С ОЗЕРА", Vector2(600, y + 232), Vector2(400, 60), 19, "normal", func(): exit_lake_requested.emit())
	_btn(pause_root, "ВЫЙТИ ИЗ ИГРЫ", Vector2(600, y + 306), Vector2(400, 60), 19, "danger", func(): quit_requested.emit())


func _open_from_pause(name: String) -> void:
	show_page(name)
	origin = "pause"
