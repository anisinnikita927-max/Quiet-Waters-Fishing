extends RefCounted
## Процедурная 3D-модель рыбы: гладкое тело вращения, округлые плавники, глаза.
## Голова смотрит в +X, спина — +Y. Дочерние узлы: Body, Tail (для анимации), Pectoral1/2.

const SEGS_LEN := 30
const SEGS_AROUND := 18


static func _f(spec: Dictionary, key: String, default: Variant) -> Variant:
	return spec[key] if spec.has(key) else default


static func _profile(t: float, spec: Dictionary) -> float:
	var c: float = _f(spec, "c", 0.4)
	var ped: float = _f(spec, "ped", 0.12)
	var snout: float = _f(spec, "snout", 0.0)
	if t < c:
		var k := (c - t) / c
		var f := sqrt(maxf(0.0, 1.0 - pow(k, 2.0 + snout * 0.9)))
		return f
	var k2 := (t - c) / (1.0 - c)
	return ped + (1.0 - ped) * pow(1.0 - k2, 1.45)


static func _spine_z(t: float, spec: Dictionary) -> float:
	var wave: float = _f(spec, "wave", 0.0)
	if wave == 0.0:
		return 0.0
	return wave * float(spec["len"]) * sin(t * TAU * 1.25) * t


static func _hash(a: float, b: float) -> float:
	return fposmod(sin(a * 127.1 + b * 311.7) * 43758.5453, 1.0)


static func _body_color(t: float, ang: float, spec: Dictionary, back: Color, belly: Color, pat_color: Color) -> Color:
	var up := cos(ang)
	var mix_v := smoothstep(-0.30, 0.38, up)
	var col := belly.lerp(back, mix_v)
	var pat: String = _f(spec, "pat", "none")
	var side := 1.0 - absf(up)
	match pat:
		"stripes":
			var s := sin(t * 34.0)
			if s > 0.35 and t > 0.22 and t < 0.86 and up > -0.15:
				col = col.lerp(pat_color, 0.85 * smoothstep(0.35, 0.6, s) * smoothstep(-0.15, 0.25, up))
		"spots":
			var cell_t := floorf(t * 26.0)
			var cell_a := floorf((ang / TAU) * 14.0)
			var h := _hash(cell_t, cell_a)
			var ft := fposmod(t * 26.0, 1.0) - 0.5
			var fa := fposmod((ang / TAU) * 14.0, 1.0) - 0.5
			if h > 0.55 and ft * ft + fa * fa < 0.09 and up > -0.2 and t > 0.16:
				col = col.lerp(pat_color, 0.9)
		"patches":
			var n := sin(t * 9.0 + 1.3) * sin(ang * 3.0 + t * 5.0) + sin(t * 17.0) * 0.4
			if n > 0.45 and up > -0.1:
				col = pat_color
			elif n < -0.9 and up > 0.0:
				col = Color("#2a2a2e")
		"rings":
			var r1 := absf(t - 0.28) < 0.045 or absf(t - 0.62) < 0.04 or (t > 0.9)
			if r1:
				col = pat_color
		"band":
			if absf(up) < 0.28 and t > 0.2 and t < 0.92:
				col = col.lerp(pat_color, 0.85)
		"plates":
			var row := absf(up) < 0.5 or up > 0.5
			if up > 0.35 and fposmod(t * 22.0, 1.0) < 0.5 and t > 0.25:
				col = col.lerp(pat_color, 0.85)
	if t < 0.05:
		col = col.darkened(0.06)
	return col


static func _make_body(spec: Dictionary) -> ArrayMesh:
	var length: float = spec["len"]
	var h: float = float(spec["h"]) * length
	var w: float = h * float(_f(spec, "w", 0.7))
	var back := Color(String(spec["body"]))
	var belly := Color(String(spec["belly"]))
	var pat_col := Color(String(spec["pat_color"]))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var rings: Array = []
	for i in range(SEGS_LEN + 1):
		var t := float(i) / float(SEGS_LEN)
		var f := _profile(t, spec)
		var x := (0.5 - t) * length
		var zc := _spine_z(t, spec)
		var ring: Array = []
		for j in range(SEGS_AROUND):
			var ang := float(j) / float(SEGS_AROUND) * TAU
			var y := h * f * cos(ang)
			# брюшко чуть круглее, спина — плавная дуга
			if y < 0.0:
				y *= 0.92
			var z := w * f * sin(ang) + zc
			ring.append([Vector3(x, y, z), _body_color(t, ang, spec, back, belly, pat_col)])
		rings.append(ring)
	var idx := 0
	var verts: Array = []
	for i in range(SEGS_LEN + 1):
		for j in range(SEGS_AROUND):
			verts.append(rings[i][j])
	for v in verts:
		st.set_color(v[1])
		st.add_vertex(v[0])
	for i in range(SEGS_LEN):
		for j in range(SEGS_AROUND):
			var a := i * SEGS_AROUND + j
			var b := i * SEGS_AROUND + (j + 1) % SEGS_AROUND
			var c := (i + 1) * SEGS_AROUND + j
			var d := (i + 1) * SEGS_AROUND + (j + 1) % SEGS_AROUND
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	idx += 1
	st.generate_normals()
	return st.commit()


static func _flat_mesh(outline: PackedVector2Array, center: Vector2) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3(0, 0, 1))
	for i in range(outline.size() - 1):
		st.add_vertex(Vector3(center.x, center.y, 0.0))
		st.add_vertex(Vector3(outline[i].x, outline[i].y, 0.0))
		st.add_vertex(Vector3(outline[i + 1].x, outline[i + 1].y, 0.0))
	return st.commit()


static func _bezier2(p0: Vector2, c: Vector2, p1: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return p0 * (u * u) + c * (2.0 * u * t) + p1 * (t * t)


static func _tail_outline(spec: Dictionary, base_half: float) -> PackedVector2Array:
	var length: float = spec["len"]
	var tl: float = float(spec["tail"]) * length
	var th: float = float(spec["tail_h"]) * length
	var notch: float = _f(spec, "notch", 0.2)
	var pts := PackedVector2Array()
	var top_base := Vector2(0.0, base_half)
	var top_tip := Vector2(-tl, th)
	var bot_tip := Vector2(-tl, -th)
	var bot_base := Vector2(0.0, -base_half)
	# верхняя кромка — выпуклая дуга к кончику лопасти
	for i in range(11):
		pts.append(_bezier2(top_base, Vector2(-tl * 0.30, th * 1.0), top_tip, float(i) / 10.0))
	# задняя кромка с выемкой (у отрицательных значений — округлый веер)
	for i in range(1, 15):
		pts.append(_bezier2(top_tip, Vector2(-tl * (1.0 - 2.0 * notch), 0.0), bot_tip, float(i) / 14.0))
	for i in range(1, 11):
		pts.append(_bezier2(bot_tip, Vector2(-tl * 0.30, -th * 1.0), bot_base, float(i) / 10.0))
	return pts


static func _fin_outline(spec: Dictionary, range_key: String, top: bool) -> PackedVector2Array:
	var length: float = spec["len"]
	var r: Array = spec[range_key]
	var t0: float = r[0]
	var t1: float = r[1]
	var fh: float = float(r[2]) * length
	var pts := PackedVector2Array()
	var steps := 16
	var sgn := 1.0 if top else -1.0
	for i in range(steps + 1):
		var u := float(i) / float(steps)
		var t := lerpf(t0, t1, u)
		var body_h := float(spec["h"]) * length * _profile(t, spec) * (0.96 if top else 0.9)
		var bump := fh * pow(sin(u * PI), 0.75)
		# слегка скошенный назад плавник
		bump *= 1.0 - 0.25 * u
		pts.append(Vector2((0.5 - t) * length, sgn * (body_h + bump)))
	return pts


static func _fin_mesh(spec: Dictionary, range_key: String, top: bool) -> ArrayMesh:
	var length: float = spec["len"]
	var outline := _fin_outline(spec, range_key, top)
	var r: Array = spec[range_key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3(0, 0, 1))
	var sgn := 1.0 if top else -1.0
	for i in range(outline.size() - 1):
		var a := outline[i]
		var b := outline[i + 1]
		var ta := lerpf(float(r[0]), float(r[1]), float(i) / float(outline.size() - 1))
		var tb := lerpf(float(r[0]), float(r[1]), float(i + 1) / float(outline.size() - 1))
		var inner_a := Vector2(a.x, sgn * float(spec["h"]) * length * _profile(ta, spec) * 0.6)
		var inner_b := Vector2(b.x, sgn * float(spec["h"]) * length * _profile(tb, spec) * 0.6)
		for p in [inner_a, a, b, inner_a, b, inner_b]:
			st.add_vertex(Vector3(p.x, p.y, 0.0))
	return st.commit()


static func _sphere(parent: Node3D, pos: Vector3, scale: Vector3, mat: Material, node_name: String, segs: int = 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = segs
	m.rings = maxi(4, segs / 2)
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale
	mi.name = node_name
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func build(spec: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Рыба"
	var length: float = spec["len"]
	var h: float = float(spec["h"]) * length
	var w: float = h * float(_f(spec, "w", 0.7))

	var body_mat := StandardMaterial3D.new()
	body_mat.vertex_color_use_as_albedo = true
	body_mat.roughness = 0.32
	body_mat.metallic = 0.12
	body_mat.metallic_specular = 0.7
	body_mat.rim_enabled = true
	body_mat.rim = 0.25
	body_mat.rim_tint = 0.6
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _make_body(spec)
	body.material_override = body_mat
	root.add_child(body)

	var fin_col := Color(String(spec["fin"]))
	var fin_mat := StandardMaterial3D.new()
	fin_mat.albedo_color = fin_col
	fin_mat.roughness = 0.55
	fin_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fin_mat.rim_enabled = true
	fin_mat.rim = 0.3

	# хвост — отдельный узел с осью на конце тела
	var tail := Node3D.new()
	tail.name = "Tail"
	var base_half := maxf(0.004, h * _profile(1.0, spec))
	tail.position = Vector3(-length * 0.5 + length * 0.004, 0.0, _spine_z(1.0, spec))
	root.add_child(tail)
	var tail_mi := MeshInstance3D.new()
	tail_mi.mesh = _flat_mesh(_tail_outline(spec, base_half), Vector2(0.0, 0.0))
	tail_mi.material_override = fin_mat
	tail.add_child(tail_mi)

	if spec.has("dors"):
		var dm := MeshInstance3D.new()
		dm.name = "Dorsal"
		dm.mesh = _fin_mesh(spec, "dors", true)
		dm.material_override = fin_mat
		root.add_child(dm)
	if spec.has("anal"):
		var am := MeshInstance3D.new()
		am.name = "Anal"
		am.mesh = _fin_mesh(spec, "anal", false)
		am.material_override = fin_mat
		root.add_child(am)

	# грудные плавники — округлые лепестки
	var pect_len := length * 0.11
	var t_p := 0.30
	var fh := h * _profile(t_p, spec)
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "Pectoral1" if side < 0.0 else "Pectoral2"
		pivot.position = Vector3((0.5 - t_p) * length, -fh * 0.32, side * w * _profile(t_p, spec) * 0.95)
		pivot.rotation.y = side * 0.55
		root.add_child(pivot)
		var pf := _sphere(pivot, Vector3(-pect_len * 0.5, -pect_len * 0.05, 0.0), Vector3(pect_len * 0.5, pect_len * 0.09, pect_len * 0.34), fin_mat, "Плавник")
		pf.rotation.z = -0.2

	# глаза
	var eye_t := 0.075
	var eye_r := clampf(h * 0.24, 0.010, 0.04)
	var eye_pos_x := (0.5 - eye_t) * length
	var eye_y := h * _profile(eye_t, spec) * 0.45
	var eye_z := w * _profile(eye_t, spec) * 0.86
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("#f5f0dc")
	white.roughness = 0.2
	var black := StandardMaterial3D.new()
	black.albedo_color = Color("#101216")
	black.roughness = 0.1
	for side in [-1.0, 1.0]:
		_sphere(root, Vector3(eye_pos_x, eye_y, side * eye_z), Vector3.ONE * eye_r, white, "Глаз", 14)
		_sphere(root, Vector3(eye_pos_x + eye_r * 0.32, eye_y, side * (eye_z + eye_r * 0.5)), Vector3.ONE * eye_r * 0.58, black, "Зрачок", 12)

	# жаберная крышка и рот
	var gill_mat := StandardMaterial3D.new()
	gill_mat.albedo_color = Color(String(spec["belly"])).darkened(0.25)
	gill_mat.roughness = 0.5
	var gill_t := 0.22
	for side in [-1.0, 1.0]:
		var gill := _sphere(root, Vector3((0.5 - gill_t) * length, -h * 0.05, side * w * _profile(gill_t, spec) * 0.86), Vector3(length * 0.03, h * 0.55 * _profile(gill_t, spec) + 0.005, 0.004), gill_mat, "Жабры", 10)
		gill.rotation.y = side * 0.25
	var mouth_mat := StandardMaterial3D.new()
	mouth_mat.albedo_color = Color("#2b1d1d")
	_sphere(root, Vector3(length * 0.5 - 0.004, -h * 0.12, 0.0), Vector3(0.01, maxf(0.004, h * 0.09), maxf(0.006, w * 0.28)), mouth_mat, "Рот", 8)

	# усы (сом, налим, осётр, вьюн)
	if spec.has("barbel"):
		var bar_mat := StandardMaterial3D.new()
		bar_mat.albedo_color = Color(String(spec["body"])).lightened(0.1)
		var blen := length * 0.10 * float(spec["barbel"])
		for side in [-1.0, 1.0]:
			var bb := _sphere(root, Vector3(length * 0.5 - 0.01, -h * 0.28, side * w * 0.5), Vector3(blen * 0.5, 0.006, 0.006), bar_mat, "Ус", 6)
			bb.rotation.y = side * 0.5
			bb.position.x += blen * 0.25
	return root


## Живая анимация: качает хвост и плавники. t — секунды, energy — 0..1.
static func animate(fish: Node3D, t: float, energy: float = 1.0) -> void:
	var tail := fish.get_node_or_null("Tail") as Node3D
	if tail != null:
		tail.rotation.y = sin(t * (7.0 + energy * 9.0)) * (0.22 + 0.35 * energy)
	var p1 := fish.get_node_or_null("Pectoral1") as Node3D
	var p2 := fish.get_node_or_null("Pectoral2") as Node3D
	if p1 != null:
		p1.rotation.y = -0.55 - sin(t * 5.0) * 0.25
	if p2 != null:
		p2.rotation.y = 0.55 + sin(t * 5.0) * 0.25
