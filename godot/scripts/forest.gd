extends Node3D

const EXTENT := 72
const WATER_LEVEL := -0.30
const STEP := 0.75
const MEADOWS := [
	Vector2(-3.0, -1.8),
	Vector2(-9.0, -14.0),
	Vector2(-6.0, 12.0),
	Vector2(-14.0, 26.0),
	Vector2(-25.0, -8.0),
	Vector2(-27.0, 10.0),
	Vector2(-25.0, 28.0),
	Vector2(-38.0, 18.0),
]

var rng := RandomNumberGenerator.new()
var bird_flock: Array[MeshInstance3D] = []
var bird_phases: Array[float] = []
var bird_time := 0.0


static func river_center(z: float) -> float:
	return 7.5 + 2.3 * sin(z * 0.105) + 0.85 * sin(z * 0.23)


static func ground_height(x: float, z: float) -> float:
	var bank := absf(x - river_center(z))
	var hills := 0.24 + 0.32 * sin(x * 0.22 + z * 0.18) + 0.23 * cos(z * 0.32)
	hills += 0.11 * sin(x * 0.86 + z * 0.69) + 0.07 * cos(x * 1.71 - z * 1.24)
	hills += smoothstep(9.0, 40.0, bank) * (4.8 + 3.1 * sin(z * 0.057 + x * 0.13))
	return lerpf(-0.93, hills, smoothstep(1.05, 3.05, bank))


static func is_meadow(point: Vector2) -> bool:
	for meadow in MEADOWS:
		if point.distance_to(meadow) < 5.4:
			return true
	return false


func _ready() -> void:
	rng.seed = 25117
	_build_terrain()
	_build_stream()
	_build_trees()
	_build_understory()
	_build_grazing_patches()
	_build_birds()


func _process(delta: float) -> void:
	bird_time += delta

	for index in bird_flock.size():
		var bird := bird_flock[index]
		var phase := bird_phases[index] + bird_time * 0.19
		var radius := 7.0 + float(index % 3) * 1.35

		bird.position = Vector3(
			-2.5 + cos(phase) * radius,
			7.6 + sin(bird_time * 1.9 + bird_phases[index]) * 0.45,
			-4.0 + sin(phase) * radius * 0.46
		)
		bird.rotation = Vector3(
			0.0,
			-phase - PI * 0.5,
			sin(bird_time * 7.5 + bird_phases[index]) * 0.28
		)


func set_season_tint(tint: Color) -> void:
	for label in [&"Terrain", &"Stream"]:
		var surface := get_node_or_null(NodePath(label)) as MeshInstance3D
		if not surface:
			continue

		var material := surface.material_override as ShaderMaterial
		if material:
			material.set_shader_parameter(&"season_tint", tint)

func _build_terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cells := int(2.0 * EXTENT / STEP)
	var heights := PackedFloat32Array()
	for j in range(cells + 1):
		for i in range(cells + 1):
			heights.append(ground_height(i * STEP - EXTENT, j * STEP - EXTENT))
	var stride := cells + 1
	for j in range(cells):
		var z := j * STEP - EXTENT
		for i in range(cells):
			var x := i * STEP - EXTENT
			var index := j * stride + i
			var a := Vector3(x, heights[index], z)
			var b := Vector3(x + STEP, heights[index + 1], z)
			var c := Vector3(x, heights[index + stride], z + STEP)
			var d := Vector3(x + STEP, heights[index + stride + 1], z + STEP)
			for vertex in [a, b, c, b, d, c]:
				surface.add_vertex(vertex)
	surface.index()
	surface.generate_normals()
	_add_surface("Terrain", surface, preload("res://materials/ground.gdshader"))


func _build_stream() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(EXTENT * 4):
		var z := i * 0.5 - EXTENT
		var next_z := z + 0.5
		var x := river_center(z)
		var next_x := river_center(next_z)
		var a := Vector3(x - 2.9, WATER_LEVEL, z)
		var b := Vector3(x + 2.9, WATER_LEVEL, z)
		var c := Vector3(next_x - 2.9, WATER_LEVEL, next_z)
		var d := Vector3(next_x + 2.9, WATER_LEVEL, next_z)
		for vertex in [a, b, c, b, d, c]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(vertex)
	var stream := _add_surface("Stream", surface, preload("res://materials/stream.gdshader"))
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_surface(label: String, surface: SurfaceTool, shader: Shader) -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = shader
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = surface.commit()
	instance.material_override = material
	add_child(instance)
	return instance


func _build_trees() -> void:
	var trunks := CylinderMesh.new()
	trunks.bottom_radius = 0.23
	trunks.top_radius = 0.046
	trunks.height = 1.0
	trunks.radial_segments = 8
	var foliage := _fir_canopy()
	var bark := ShaderMaterial.new()
	bark.shader = preload("res://materials/bark.gdshader")
	var needles := ShaderMaterial.new()
	needles.shader = preload("res://materials/fir.gdshader")
	var trunk_transforms: Array[Transform3D] = []
	var crown_transforms: Array[Transform3D] = []
	var trunk_colors: Array[Color] = []
	var crown_colors: Array[Color] = []
	# Jitter a grid to keep neighboring trunks apart while leaving the meadow open.
	for row in range(-19, 20):
		for column in range(-19, 20):
			var x := column * 3.55 + rng.randf_range(-1.35, 1.35)
			var z := row * 3.55 + rng.randf_range(-1.35, 1.35)
			if absf(x - river_center(z)) < 3.1 or Vector2(x, z).length() < 5.7:
				continue
			if is_meadow(Vector2(x, z)):
				continue
			if rng.randf() < 0.22:
				continue
			var height := rng.randf_range(4.6, 13.0)
			var width := height * rng.randf_range(0.12, 0.20)
			var tree_basis := Basis(Vector3.UP, rng.randf_range(0, TAU))
			var base := Vector3(x, ground_height(x, z) - 0.10, z)
			trunk_transforms.append(Transform3D(tree_basis.scaled(Vector3(width, height * 0.88, width)),
				base + Vector3.UP * height * 0.44))
			crown_transforms.append(Transform3D(tree_basis.scaled(Vector3(width, height, width)), base))
			trunk_colors.append(Color.WHITE * rng.randf_range(0.64, 1.09))
			crown_colors.append(Color.from_hsv(rng.randf_range(0.14, 0.29),
				rng.randf_range(0.08, 0.22), rng.randf_range(0.67, 1.0)))
	_batch("Bark", trunks, bark, trunk_transforms, trunk_colors)
	_batch("FirCrowns", foliage, needles, crown_transforms, crown_colors)


func _fir_canopy() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Overlapping whorls with individually drooping branch tips.
	for tier in range(9):
		var base_y := 0.26 + tier * 0.076
		var radius := pow(1.0 - tier / 10.0, 0.92)
		var phase := rng.randf_range(0.0, TAU)
		for branch in range(9):
			var angle := phase + TAU * branch / 9.0
			var direction := Vector3(cos(angle), 0.0, sin(angle))
			var side := direction.cross(Vector3.UP)
			var root := Vector3.UP * (base_y + 0.17)
			var tip := direction * radius * rng.randf_range(0.84, 1.13) + Vector3.UP * base_y
			var ridge := root.lerp(tip, 0.47) + Vector3.UP * 0.025
			for spray in range(3):
				var middle := root.lerp(tip, 0.31 + spray * 0.21)
				var spread := radius * (0.33 - spray * 0.065)
				var left := middle - side * spread - Vector3.UP * 0.043 + direction * spread * 0.41
				var right := middle + side * spread - Vector3.UP * 0.043 + direction * spread * 0.32
				var tone := rng.randf_range(0.64, 1.12)
				_triangle(surface, root, left, ridge, Color.WHITE * tone)
				_triangle(surface, ridge, left, tip, Color.WHITE * tone * 0.84)
				_triangle(surface, root, ridge, right, Color.WHITE * tone)
				_triangle(surface, ridge, tip, right, Color.WHITE * tone * 0.90)
	surface.generate_normals()
	return surface.commit()


func _build_understory() -> void:
	var rock := SphereMesh.new()
	rock.radial_segments = 7
	rock.rings = 4
	var rock_transforms: Array[Transform3D] = []
	var rock_colors: Array[Color] = []
	for i in range(460):
		var z := rng.randf_range(-60, 60)
		var x := river_center(z) + rng.randf_range(1.15, 4.5) * (-1.0 if i % 2 == 0 else 1.0)
		var size := rng.randf_range(0.12, 0.65)
		if i % 23 == 0:
			size *= 2.0
		var rock_scale := Vector3(size * 1.6, size * 0.78, size * 1.13)
		var rock_basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		rock_transforms.append(Transform3D(rock_basis.scaled(rock_scale), Vector3(x, ground_height(x, z) + size * 0.04, z)))
		rock_colors.append(Color.WHITE * rng.randf_range(0.57, 1.10))
	_batch("CreekStones", rock, _material(Color("#8d8675")), rock_transforms, rock_colors)

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in range(9):
		var angle := rng.randf_range(0.0, TAU)
		var direction := Vector3(cos(angle), 0, sin(angle))
		var side := direction.cross(Vector3.UP) * rng.randf_range(0.019, 0.049)
		var base := direction * rng.randf_range(0.025, 0.23)
		var height := rng.randf_range(0.12, 0.47)
		var bend := base + Vector3.UP * height * 0.61 + direction * 0.04
		var tip := base + Vector3.UP * height + direction * rng.randf_range(0.09, 0.26)
		_triangle(surface, base - side, base + side, bend + side * 0.65, Color("#a6ab6e"))
		_triangle(surface, base - side, bend + side * 0.65, bend - side * 0.65, Color("#a6ab6e"))
		_triangle(surface, bend - side * 0.65, bend + side * 0.65, tip, Color("#dde1a0"))
	surface.generate_normals()
	var grass_transforms: Array[Transform3D] = []
	var grass_colors: Array[Color] = []
	for patch in range(1750):
		var center := Vector2(rng.randf_range(-29, 36), rng.randf_range(-46, 32))
		for tuft in range(7):
			var point := center + Vector2(rng.randfn(0.0, 0.9), rng.randfn(0.0, 0.9))
			var y := ground_height(point.x, point.y)
			if y < WATER_LEVEL + 0.10:
				continue
			var size := rng.randf_range(0.38, 1.32)
			var grass_basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * size)
			grass_transforms.append(Transform3D(grass_basis, Vector3(point.x, y - 0.055, point.y)))
			grass_colors.append(Color.from_hsv(rng.randf_range(0.13, 0.25), 0.26, rng.randf_range(0.56, 1.0)))
	var grass := _batch("Grasses", surface.commit(), _grass_material(), grass_transforms, grass_colors)
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_grazing_patches() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for blade in range(11):
		var angle := TAU * blade / 11.0
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var side := direction.cross(Vector3.UP) * 0.035
		var base := direction * 0.06
		var bend := base + Vector3.UP * 0.15 + direction * 0.04
		var tip := base + Vector3.UP * 0.32 + direction * 0.08

		_triangle(
			surface,
			base - side,
			base + side,
			bend + side * 0.5,
			Color("#8eaa4f")
		)
		_triangle(
			surface,
			base - side,
			bend + side * 0.5,
			bend - side * 0.5,
			Color("#8eaa4f")
		)
		_triangle(
			surface,
			bend - side * 0.5,
			bend + side * 0.5,
			tip,
			Color("#c4cf70")
		)

	surface.generate_normals()

	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []

	for center in MEADOWS:
		for tuft in range(65):
			var angle := rng.randf_range(0.0, TAU)
			var radius := sqrt(rng.randf()) * 1.35
			var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
			var size := rng.randf_range(0.40, 0.65)
			var deer_basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
			deer_basis = deer_basis.scaled(Vector3.ONE * size)

			transforms.append(
				Transform3D(
					deer_basis,
					Vector3(
						point.x,
						ground_height(point.x, point.y) - 0.05,
						point.y
					)
				)
			)
			colors.append(
				Color.from_hsv(
					rng.randf_range(0.16, 0.24),
					rng.randf_range(0.34, 0.52),
					rng.randf_range(0.68, 1.0)
				)
			)

	var grass := _batch(
		"GrazingPatches",
		surface.commit(),
		_grass_material(),
		transforms,
		colors
	)
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_birds() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wing_color := Color("#2f3b34")

	_triangle(
		surface,
		Vector3(-0.25, 0.0, 0.0),
		Vector3(0.0, 0.08, 0.0),
		Vector3(-0.03, -0.035, 0.0),
		wing_color
	)
	_triangle(
		surface,
		Vector3(0.0, 0.08, 0.0),
		Vector3(0.25, 0.0, 0.0),
		Vector3(0.03, -0.035, 0.0),
		wing_color
	)

	var material := _material(wing_color, true)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for index in range(7):
		var bird := MeshInstance3D.new()
		bird.name = "DistantBird%02d" % index
		bird.mesh = surface.commit()
		bird.material_override = material
		bird.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bird)
		bird_flock.append(bird)
		bird_phases.append(float(index) * 0.74)

func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	surface.set_color(color)
	surface.set_uv(Vector2.ZERO)
	surface.add_vertex(a)
	surface.set_uv(Vector2.RIGHT)
	surface.add_vertex(b)
	surface.set_uv(Vector2.DOWN)
	surface.add_vertex(c)

func _grass_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://materials/grass.gdshader")
	return material

func _material(color: Color, double_sided := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.94
	material.vertex_color_use_as_albedo = true
	if double_sided:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _batch(label: String, mesh: Mesh, material: Material, transforms: Array[Transform3D],
		colors: Array[Color]) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_color(i, colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = multimesh
	instance.material_override = material
	add_child(instance)
	return instance
