extends RefCounted
## Помощники для сборки округлых мешей из примитивов.

## Множитель детализации: на телефонах меньше сегментов, чтобы держать частоту кадров.
static var detail := 1.0


static func _segs(n: int) -> int:
	return maxi(8, int(round(float(n) * detail)))


static func mat(color: Color, roughness: float = 0.85, metallic: float = 0.0, emission: Color = Color.BLACK, emission_strength: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission_strength > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_strength
	return material


static func unshaded(color: Color, additive: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0 or additive:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return material


static func sphere(parent: Node, position: Vector3, dimensions: Vector3, material: Material, node_name: String = "Шар", segs: int = 20) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = _segs(segs)
	mesh.rings = maxi(5, _segs(segs) / 2)
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.scale = dimensions
	instance.name = node_name
	parent.add_child(instance)
	return instance


static func cylinder(parent: Node, position: Vector3, radius: float, height: float, material: Material, node_name: String = "Цилиндр", segs: int = 24, top_ratio: float = 0.88) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * top_ratio
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = _segs(segs)
	mesh.rings = 1
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.name = node_name
	parent.add_child(instance)
	return instance


static func _aim(direction: Vector3) -> Quaternion:
	var d := direction.normalized()
	if d.dot(Vector3.UP) < -0.9999:
		return Quaternion(Vector3.RIGHT, PI)
	return Quaternion(Vector3.UP, d)


static func cylinder_between(parent: Node, from: Vector3, to: Vector3, radius_from: float, radius_to: float, material: Material, node_name: String = "Стержень", segs: int = 16) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius_from
	mesh.top_radius = radius_to
	mesh.height = maxf(0.001, from.distance_to(to))
	mesh.radial_segments = _segs(segs)
	mesh.rings = 1
	instance.mesh = mesh
	instance.material_override = material
	instance.position = (from + to) * 0.5
	instance.quaternion = _aim(to - from)
	instance.name = node_name
	parent.add_child(instance)
	return instance


## Капсула (скруглённые торцы) между двумя точками.
static func capsule_between(parent: Node, from: Vector3, to: Vector3, radius: float, material: Material, node_name: String = "Капсула", segs: int = 16) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(radius * 2.0 + 0.001, from.distance_to(to) + radius * 2.0)
	mesh.radial_segments = _segs(segs)
	mesh.rings = 4
	instance.mesh = mesh
	instance.material_override = material
	instance.position = (from + to) * 0.5
	instance.quaternion = _aim(to - from)
	instance.name = node_name
	parent.add_child(instance)
	return instance


static func torus(parent: Node, position: Vector3, inner: float, outer: float, material: Material, node_name: String = "Кольцо") -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 8
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.name = node_name
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


## Мягкое круглое облачко для пара, тумана и бликов (частицы-билборды).
static func soft_puff(color: Color = Color.WHITE) -> StandardMaterial3D:
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	tex.gradient = g
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = tex
	material.albedo_color = color
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.disable_receive_shadows = true
	return material
