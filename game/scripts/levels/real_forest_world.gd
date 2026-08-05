extends Node3D
class_name RealForestWorld

const TERRAIN_MIN_X := -25.0
const TERRAIN_MAX_X := 25.0
const TERRAIN_MIN_Z := -37.0
const TERRAIN_MAX_Z := 29.0

var stage_number := 1
var start_position := Vector3.ZERO
var goal_position := Vector3.ZERO

var _rng := RandomNumberGenerator.new()
var _ground_material: StandardMaterial3D
var _trail_material: StandardMaterial3D
var _bark_material: StandardMaterial3D
var _rock_material: StandardMaterial3D
var _leaf_material: StandardMaterial3D
var _water_material: ShaderMaterial
var _navigation_region: NavigationRegion3D
var _performance_mode := false


func build_world(requested_stage: int) -> void:
	stage_number = clampi(requested_stage, 1, 5)
	_performance_mode = OS.has_feature("mobile") or GameState.quality_level == 0
	_rng.seed = 40733 + stage_number * 9127
	_create_materials()
	_build_lighting()
	_build_heightfield()
	_build_organic_trail()
	_build_river()
	_build_bridge()
	_build_layered_forest()
	_build_undergrowth()
	_build_natural_boundaries()
	_build_stage_landmark()
	_build_air_particles()
	_build_stage_weather()
	start_position = Vector3(0.0, terrain_height(0.0, 22.5) + 0.08, 22.5)
	_prepare_navigation()


func _prepare_navigation() -> void:
	# The baked mesh follows the actual terrain and all static obstacles.
	add_to_group(&"forest_navigation_source")
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.cell_size = 0.25
	navigation_mesh.cell_height = 0.25
	navigation_mesh.agent_height = 1.25
	navigation_mesh.agent_radius = 0.75
	navigation_mesh.agent_max_climb = 0.5
	navigation_mesh.agent_max_slope = 47.0
	navigation_mesh.region_min_size = 1.0
	navigation_mesh.edge_max_length = 4.0
	navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navigation_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	navigation_mesh.geometry_source_group_name = &"forest_navigation_source"
	_navigation_region = NavigationRegion3D.new()
	_navigation_region.name = "ForestNavigationRegion"
	_navigation_region.navigation_mesh = navigation_mesh
	_navigation_region.use_edge_connections = true
	add_child(_navigation_region)
	_navigation_region.bake_finished.connect(_on_navigation_bake_finished)
	_navigation_region.bake_navigation_mesh.call_deferred(true)


func _on_navigation_bake_finished() -> void:
	_navigation_region.set_meta(&"navigation_ready", true)


func terrain_height(x: float, z: float) -> float:
	var broad := sin(x * 0.17 + stage_number * 0.41) * 0.46
	broad += cos(z * 0.125 - stage_number * 0.3) * 0.38
	broad += sin((x + z) * 0.24) * 0.18
	broad += cos((x - z) * 0.095) * 0.24
	var path_center := _trail_center_x(z)
	var path_blend := 1.0 - smoothstep(1.9, 4.6, absf(x - path_center))
	var trail_height := sin(z * 0.09 + stage_number) * 0.11
	broad = lerpf(broad, trail_height, path_blend * 0.72)
	var river_center := _river_center_z(x)
	var river_blend := 1.0 - smoothstep(2.25, 4.15, absf(z - river_center))
	broad = lerpf(broad, -1.12 + sin(x * 0.22) * 0.09, river_blend)
	return broad


func _trail_center_x(z: float) -> float:
	return sin(z * 0.105 + stage_number * 0.58) * 1.45 + sin(z * 0.035) * 0.65


func _river_center_z(x: float) -> float:
	return sin(x * 0.135 + stage_number * 0.45) * 0.72


func _create_materials() -> void:
	_ground_material = _environment_material(
		"res://assets/environments/pbr/Ground037/Ground037_1K-JPG_Color.jpg",
		"res://assets/environments/pbr/Ground037/Ground037_1K-JPG_NormalGL.jpg",
		"res://assets/environments/pbr/Ground037/Ground037_1K-JPG_Roughness.jpg",
		"res://assets/environments/pbr/Ground037/Ground037_1K-JPG_AmbientOcclusion.jpg",
		Color("39483b"), Vector3(8.0, 8.0, 8.0)
	)
	_trail_material = _environment_material(
		"res://assets/environments/pbr/Ground086/Ground086_1K-JPG_Color.jpg",
		"res://assets/environments/pbr/Ground086/Ground086_1K-JPG_NormalGL.jpg",
		"res://assets/environments/pbr/Ground086/Ground086_1K-JPG_Roughness.jpg",
		"res://assets/environments/pbr/Ground086/Ground086_1K-JPG_AmbientOcclusion.jpg",
		Color("8a6042"), Vector3(4.5, 4.5, 4.5)
	)
	_bark_material = _environment_material(
		"res://assets/environments/pbr/Bark012/Bark012_1K-JPG_Color.jpg",
		"res://assets/environments/pbr/Bark012/Bark012_1K-JPG_NormalGL.jpg",
		"res://assets/environments/pbr/Bark012/Bark012_1K-JPG_Roughness.jpg",
		"res://assets/environments/pbr/Bark012/Bark012_1K-JPG_AmbientOcclusion.jpg",
		Color("594938"), Vector3(3.2, 3.2, 3.2)
	)
	_rock_material = _ground_material.duplicate(true)
	_rock_material.albedo_color = Color("555c55")
	_rock_material.uv1_scale = Vector3(3.4, 3.4, 3.4)
	_leaf_material = StandardMaterial3D.new()
	_leaf_material.albedo_color = Color("8ea676")
	_leaf_material.albedo_texture = load("res://assets/environments/pbr/Leaf001/Leaf001.png")
	_leaf_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_leaf_material.alpha_scissor_threshold = 0.34
	_leaf_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_leaf_material.roughness = 0.92
	_leaf_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if _performance_mode:
		_ground_material.normal_enabled = false
		_ground_material.ao_enabled = false
		_ground_material.roughness_texture = null
		_ground_material.uv1_triplanar = false
		_trail_material.normal_enabled = false
		_trail_material.ao_enabled = false
		_trail_material.roughness_texture = null
		_trail_material.uv1_triplanar = false
		_bark_material.normal_enabled = false
		_bark_material.ao_enabled = false
		_bark_material.roughness_texture = null
		_bark_material.uv1_triplanar = false
		_rock_material.normal_enabled = false
		_rock_material.ao_enabled = false
		_rock_material.roughness_texture = null
		_rock_material.uv1_triplanar = false
		_leaf_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_leaf_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	_water_material = ShaderMaterial.new()
	_water_material.shader = load("res://assets/environments/moving_water.gdshader")
	_water_material.set_shader_parameter("shallow_color", Color(0.045, 0.24, 0.28, 0.8))


func _build_lighting() -> void:
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("183544")
	sky_material.sky_horizon_color = Color("899b86")
	sky_material.ground_bottom_color = Color("07110d")
	sky_material.ground_horizon_color = Color("536454")
	sky_material.sun_angle_max = 11.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color("aab6a5")
	environment.ambient_light_energy = 0.38
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("9da99a")
	environment.fog_light_energy = 0.4
	environment.fog_density = 0.0045
	environment.fog_height = 1.5
	environment.fog_height_density = 0.18
	environment.fog_sky_affect = 0.58
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.02
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 0.94
	if _performance_mode:
		environment.fog_enabled = false
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	match stage_number:
		2:
			sky_material.sky_top_color = Color("1b3642")
			sky_material.sky_horizon_color = Color("789097")
			environment.ambient_light_color = Color("b5c7ca")
			environment.ambient_light_energy = 0.42
			environment.fog_light_color = Color("aebfc2")
			environment.fog_density = 0.0075
			environment.adjustment_saturation = 0.78
		3:
			sky_material.sky_top_color = Color("081522")
			sky_material.sky_horizon_color = Color("48545a")
			environment.ambient_light_color = Color("8192a0")
			environment.ambient_light_energy = 0.29
			environment.fog_light_color = Color("617078")
			environment.fog_density = 0.009
			environment.adjustment_brightness = 0.9
			environment.adjustment_contrast = 1.16
			environment.adjustment_saturation = 0.72
		4:
			sky_material.sky_top_color = Color("38271f")
			sky_material.sky_horizon_color = Color("b27b54")
			environment.ambient_light_color = Color("d3aa83")
			environment.ambient_light_energy = 0.34
			environment.fog_light_color = Color("a97a5d")
			environment.fog_density = 0.006
			environment.adjustment_saturation = 0.82
		5:
			sky_material.sky_top_color = Color("101a2b")
			sky_material.sky_horizon_color = Color("52657a")
			environment.ambient_light_color = Color("93a6bb")
			environment.ambient_light_energy = 0.3
			environment.fog_light_color = Color("687b8e")
			environment.fog_density = 0.0105
			environment.adjustment_brightness = 0.88
			environment.adjustment_contrast = 1.18
			environment.adjustment_saturation = 0.8
	var world := WorldEnvironment.new()
	world.name = "NaturalWorldEnvironment"
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "LateAfternoonSun"
	sun.rotation_degrees = Vector3(-43.0, -28.0, 0.0)
	sun.light_color = Color("ffe8bd")
	sun.light_energy = 1.18
	if stage_number == 2:
		sun.light_color = Color("d9e4e5")
		sun.light_energy = 0.92
	elif stage_number == 3:
		sun.light_color = Color("b8c5d0")
		sun.light_energy = 0.68
	elif stage_number == 4:
		sun.light_color = Color("ffbf84")
		sun.light_energy = 1.05
	elif stage_number == 5:
		sun.light_color = Color("bdabd9")
		sun.light_energy = 0.62
	sun.shadow_enabled = not _performance_mode
	sun.directional_shadow_max_distance = 24.0 if _performance_mode else 42.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if _performance_mode else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "CoolForestFill"
	fill.rotation_degrees = Vector3(-52.0, 148.0, 0.0)
	fill.light_color = Color("c2d4da")
	fill.light_energy = 0.28
	fill.shadow_enabled = false
	add_child(fill)


func _build_heightfield() -> void:
	var mesh := ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x_steps := 50
	var z_steps := 66
	var x_step := (TERRAIN_MAX_X - TERRAIN_MIN_X) / float(x_steps)
	var z_step := (TERRAIN_MAX_Z - TERRAIN_MIN_Z) / float(z_steps)
	for z_index in range(z_steps):
		for x_index in range(x_steps):
			var x0 := TERRAIN_MIN_X + x_index * x_step
			var x1 := x0 + x_step
			var z0 := TERRAIN_MIN_Z + z_index * z_step
			var z1 := z0 + z_step
			_add_terrain_triangle(surface, Vector3(x0, terrain_height(x0, z0), z0), Vector3(x1, terrain_height(x1, z0), z0), Vector3(x0, terrain_height(x0, z1), z1))
			_add_terrain_triangle(surface, Vector3(x1, terrain_height(x1, z0), z0), Vector3(x1, terrain_height(x1, z1), z1), Vector3(x0, terrain_height(x0, z1), z1))
	surface.generate_tangents()
	surface.set_material(_ground_material)
	surface.commit(mesh)
	var body := StaticBody3D.new()
	body.name = "SculptedForestTerrain"
	var terrain_mesh := MeshInstance3D.new()
	terrain_mesh.mesh = mesh
	terrain_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if _performance_mode else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(terrain_mesh)
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)
	add_child(body)


func _add_terrain_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := Plane(a, b, c).normal
	for vertex in [a, b, c]:
		surface.set_normal(normal)
		surface.set_uv(Vector2((vertex.x - TERRAIN_MIN_X) * 0.08, (vertex.z - TERRAIN_MIN_Z) * 0.08))
		surface.add_vertex(vertex)


func _build_organic_trail() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections := 72
	for index in range(sections):
		var z0 := TERRAIN_MAX_Z - index * (TERRAIN_MAX_Z - TERRAIN_MIN_Z) / sections
		var z1 := TERRAIN_MAX_Z - (index + 1) * (TERRAIN_MAX_Z - TERRAIN_MIN_Z) / sections
		var center0 := _trail_center_x(z0)
		var center1 := _trail_center_x(z1)
		var width0 := 1.72 + sin(index * 0.71) * 0.2
		var width1 := 1.72 + sin((index + 1) * 0.71) * 0.2
		var points := [
			Vector3(center0 - width0, terrain_height(center0 - width0, z0) + 0.075, z0),
			Vector3(center0 + width0, terrain_height(center0 + width0, z0) + 0.075, z0),
			Vector3(center1 - width1, terrain_height(center1 - width1, z1) + 0.075, z1),
			Vector3(center1 + width1, terrain_height(center1 + width1, z1) + 0.075, z1),
		]
		_add_flat_triangle(surface, points[0], points[1], points[2], Vector2(0, index), Vector2(1, index), Vector2(0, index + 1))
		_add_flat_triangle(surface, points[1], points[3], points[2], Vector2(1, index), Vector2(1, index + 1), Vector2(0, index + 1))
	var mesh := surface.commit()
	mesh.surface_set_material(0, _trail_material)
	var trail := MeshInstance3D.new()
	trail.name = "OrganicForestTrail"
	trail.mesh = mesh
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail)


func _add_flat_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
	var normal := Plane(a, b, c).normal
	for pair in [[a, uv_a], [b, uv_b], [c, uv_c]]:
		surface.set_normal(normal)
		surface.set_uv(pair[1])
		surface.add_vertex(pair[0])


func _build_river() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections := 64
	for index in range(sections):
		var x0 := TERRAIN_MIN_X + index * (TERRAIN_MAX_X - TERRAIN_MIN_X) / sections
		var x1 := TERRAIN_MIN_X + (index + 1) * (TERRAIN_MAX_X - TERRAIN_MIN_X) / sections
		var center0 := _river_center_z(x0)
		var center1 := _river_center_z(x1)
		var width0 := 2.28 + sin(index * 0.48) * 0.18
		var width1 := 2.28 + sin((index + 1) * 0.48) * 0.18
		var y := -0.43
		_add_flat_triangle(surface, Vector3(x0, y, center0 - width0), Vector3(x1, y, center1 - width1), Vector3(x0, y, center0 + width0), Vector2(index, 0), Vector2(index + 1, 0), Vector2(index, 1))
		_add_flat_triangle(surface, Vector3(x1, y, center1 - width1), Vector3(x1, y, center1 + width1), Vector3(x0, y, center0 + width0), Vector2(index + 1, 0), Vector2(index + 1, 1), Vector2(index, 1))
	var water_mesh := surface.commit()
	water_mesh.surface_set_material(0, _water_material)
	var river := MeshInstance3D.new()
	river.name = "FlowingRiver"
	river.mesh = water_mesh
	river.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(river)
	_build_water_volume()

	for side in [-1.0, 1.0]:
		for index in range(4 if _performance_mode else 18):
			var x: float = _rng.randf_range(TERRAIN_MIN_X + 1.0, TERRAIN_MAX_X - 1.0)
			var z: float = _river_center_z(x) + float(side) * _rng.randf_range(2.45, 3.25)
			_add_irregular_rock(Vector3(x, terrain_height(x, z) + 0.12, z), Vector3(_rng.randf_range(0.42, 1.1), _rng.randf_range(0.3, 0.72), _rng.randf_range(0.5, 1.25)), false)

	var waterfall := MeshInstance3D.new()
	waterfall.name = "DistantWaterfall"
	waterfall.position = Vector3(TERRAIN_MIN_X + 0.35, 0.45, _river_center_z(TERRAIN_MIN_X))
	waterfall.rotation.z = PI * 0.5
	var fall_mesh := QuadMesh.new()
	fall_mesh.size = Vector2(3.0, 4.6)
	fall_mesh.material = _water_material
	waterfall.mesh = fall_mesh
	add_child(waterfall)


func _build_water_volume() -> void:
	var water_area := Area3D.new()
	water_area.name = "EnterableRiverWater"
	water_area.collision_layer = 0
	water_area.collision_mask = 1
	water_area.monitoring = true
	for index in range(18):
		var x := lerpf(TERRAIN_MIN_X + 1.4, TERRAIN_MAX_X - 1.4, index / 17.0)
		var shape_node := CollisionShape3D.new()
		shape_node.position = Vector3(x, -0.36, _river_center_z(x))
		var water_shape := BoxShape3D.new()
		water_shape.size = Vector3(3.25, 1.55, 4.65)
		shape_node.shape = water_shape
		water_area.add_child(shape_node)
	water_area.body_entered.connect(func(body: Node3D):
		if body.has_method("set_in_water"):
			body.call("set_in_water", true)
	)
	water_area.body_exited.connect(func(body: Node3D):
		if body.has_method("set_in_water"):
			body.call("set_in_water", false)
	)
	add_child(water_area)


func _build_bridge() -> void:
	var bridge_x := _trail_center_x(0.0)
	var center_z := _river_center_z(bridge_x)
	for index in range(10):
		var plank_z := center_z - 2.75 + index * 0.61
		var plank := _add_box("BridgePlank_%02d" % index, Vector3(3.45, 0.16, 0.53), Vector3(bridge_x + sin(index * 1.4) * 0.06, 0.02, plank_z), _bark_material, true)
		plank.rotation.y = sin(index * 0.8) * 0.025
	for side in [-1.0, 1.0]:
		for post_index in range(4):
			var post_z := center_z - 2.55 + post_index * 1.7
			_add_cylinder("BridgePost", Vector3(bridge_x + side * 1.75, 0.62, post_z), 0.085, 1.45, _bark_material, true)


func _build_layered_forest() -> void:
	var positions: Array[Vector3] = []
	var heights: Array[float] = []
	# A hand-composed corridor guarantees that the player is framed by mature trees
	# instead of spawning in a broad procedural clearing.
	var corridor_rows := [-35.0, -29.0, -23.0, -17.0, -11.0, 9.0, 15.0, 21.0, 27.0, 33.0]
	for z in corridor_rows:
		for side in [-1.0, 1.0]:
			var x: float = _trail_center_x(float(z)) + float(side) * _rng.randf_range(2.75, 4.35)
			if absf(z - _river_center_z(x)) < 3.8:
				continue
			positions.append(Vector3(x, terrain_height(x, z), z))
			heights.append(_rng.randf_range(10.2, 14.0))
	var attempts := 0
	var tree_target := 58 if _performance_mode else 142
	while positions.size() < tree_target and attempts < 2500:
		attempts += 1
		var x: float = _rng.randf_range(TERRAIN_MIN_X + 1.0, TERRAIN_MAX_X - 1.0)
		var z: float = _rng.randf_range(TERRAIN_MIN_Z + 1.0, TERRAIN_MAX_Z - 1.0)
		var path_distance := absf(x - _trail_center_x(z))
		if path_distance < _rng.randf_range(1.95, 3.15):
			continue
		if absf(z - _river_center_z(x)) < 3.6:
			continue
		if Vector2(x, z).distance_to(Vector2(0, 22.5)) < 2.5:
			continue
		positions.append(Vector3(x, terrain_height(x, z), z))
		heights.append(_rng.randf_range(8.6, 13.2))
	_add_real_tree_multimeshes(positions, heights)
	if not _performance_mode:
		_add_hero_firs()
		_add_photogrammetry_saplings()


func _add_hero_firs() -> void:
	var positions: Array[Vector3] = []
	var heights: Array[float] = []
	var corridor_rows := [-28.0, -13.0, 13.0, 28.0] if _performance_mode else [-33.0, -26.0, -19.0, -12.0, 8.5, 14.5, 34.0]
	for z_value in corridor_rows:
		var z := float(z_value)
		for side_value in [-1.0, 1.0]:
			var side := float(side_value)
			var x: float = _trail_center_x(z) + side * _rng.randf_range(4.7, 6.2)
			if absf(z - _river_center_z(x)) < 3.8:
				continue
			positions.append(Vector3(x, terrain_height(x, z), z))
			heights.append(_rng.randf_range(7.5, 10.5))
	_add_photogrammetry_tree_multimeshes(
		positions,
		heights,
		"res://assets/models/trees/polyhaven_fir_sapling_medium_cc0/fir_sapling_medium_mobile.glb",
		"HeroFir"
	)


func _add_real_tree_multimeshes(positions: Array[Vector3], heights: Array[float]) -> void:
	if _performance_mode:
		_add_tree_trunks_and_branches(positions, heights)
		_add_tree_leaf_cards(positions, heights)
		return
	var packed := load("res://assets/models/trees/real_conifer_cc0/tree.glb") as PackedScene
	if not packed:
		_add_tree_trunks_and_branches(positions, heights)
		_add_tree_leaf_cards(positions, heights)
		return
	var prototype := packed.instantiate()
	var trunk_source := prototype.get_node_or_null("tree") as MeshInstance3D
	var leaf_source := prototype.get_node_or_null("tree/leaves") as MeshInstance3D
	if not trunk_source or not leaf_source:
		prototype.free()
		_add_tree_trunks_and_branches(positions, heights)
		_add_tree_leaf_cards(positions, heights)
		return
	var wind_material := ShaderMaterial.new()
	wind_material.shader = load("res://assets/characters/real_tree_wind.gdshader")
	wind_material.set_shader_parameter("leaf_texture", load("res://assets/models/trees/real_conifer_cc0/leaves.png"))
	var leaf_mesh := leaf_source.mesh.duplicate(true) as Mesh
	for surface in range(leaf_mesh.get_surface_count()):
		leaf_mesh.surface_set_material(surface, wind_material)
	var trunk_multi := MultiMesh.new()
	trunk_multi.transform_format = MultiMesh.TRANSFORM_3D
	trunk_multi.mesh = trunk_source.mesh
	trunk_multi.instance_count = positions.size()
	var leaf_multi := MultiMesh.new()
	leaf_multi.transform_format = MultiMesh.TRANSFORM_3D
	leaf_multi.mesh = leaf_mesh
	leaf_multi.instance_count = positions.size()
	var source_leaf_transform := trunk_source.transform * leaf_source.transform
	var source_height := maxf(1.0, trunk_source.mesh.get_aabb().size.y)
	for index in range(positions.size()):
		var scale_value := heights[index] / source_height
		var non_uniform := Vector3(scale_value * _rng.randf_range(0.9, 1.14), scale_value, scale_value * _rng.randf_range(0.9, 1.14))
		var tree_transform := Transform3D(Basis(Vector3.UP, _rng.randf_range(-PI, PI)).scaled(non_uniform), positions[index] + Vector3.UP * 0.12)
		trunk_multi.set_instance_transform(index, tree_transform * trunk_source.transform)
		leaf_multi.set_instance_transform(index, tree_transform * source_leaf_transform)
		var collider := StaticBody3D.new()
		collider.name = "ConiferCollision_%03d" % index
		collider.position = positions[index] + Vector3.UP * heights[index] * 0.5
		var shape_node := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.height = heights[index]
		shape.radius = clampf(heights[index] * 0.035, 0.28, 0.48)
		shape_node.shape = shape
		collider.add_child(shape_node)
		add_child(collider)
	var trunks := MultiMeshInstance3D.new()
	trunks.name = "NaturalTreeTrunks"
	trunks.multimesh = trunk_multi
	trunks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(trunks)
	var leaves := MultiMeshInstance3D.new()
	leaves.name = "NaturalTreeCanopies"
	leaves.multimesh = leaf_multi
	leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if _performance_mode else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(leaves)
	prototype.free()


func _add_photogrammetry_saplings() -> void:
	var positions: Array[Vector3] = []
	var heights: Array[float] = []
	var attempts := 0
	var sapling_target := 8 if _performance_mode else 20
	while positions.size() < sapling_target and attempts < 700:
		attempts += 1
		var z: float = _rng.randf_range(TERRAIN_MIN_Z + 2.0, TERRAIN_MAX_Z - 2.0)
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var x: float = _trail_center_x(z) + side * _rng.randf_range(5.2, 10.5)
		if x < TERRAIN_MIN_X + 1.0 or x > TERRAIN_MAX_X - 1.0:
			continue
		if absf(z - _river_center_z(x)) < 3.0:
			continue
		positions.append(Vector3(x, terrain_height(x, z), z))
		heights.append(_rng.randf_range(2.4, 4.4))
	_add_photogrammetry_tree_multimeshes(positions, heights)


func _add_photogrammetry_tree_multimeshes(
	positions: Array[Vector3],
	heights: Array[float],
	packed_path := "res://assets/models/trees/polyhaven_pine_sapling_cc0/pine_sapling_mobile.glb",
	node_prefix := "PhotogrammetrySapling",
	add_colliders := true
) -> void:
	var packed := load(packed_path) as PackedScene
	if not packed:
		_add_tree_trunks_and_branches(positions, heights)
		_add_tree_leaf_cards(positions, heights)
		return
	var prototype := packed.instantiate()
	var sources: Array[MeshInstance3D] = []
	for child in prototype.get_children():
		if child is MeshInstance3D and child.mesh:
			sources.append(child)
	if sources.is_empty():
		prototype.free()
		_add_tree_trunks_and_branches(positions, heights)
		_add_tree_leaf_cards(positions, heights)
		return
	for variant_index in range(sources.size()):
		var source := sources[variant_index]
		var variant_indices: Array[int] = []
		for tree_index in range(positions.size()):
			if tree_index % sources.size() == variant_index:
				variant_indices.append(tree_index)
		var mobile_mesh := source.mesh.duplicate(true) as Mesh
		_apply_photogrammetry_wind(mobile_mesh)
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		multi.mesh = mobile_mesh
		multi.instance_count = variant_indices.size()
		var source_height := maxf(0.2, source.mesh.get_aabb().size.y)
		for local_index in range(variant_indices.size()):
			var tree_index := variant_indices[local_index]
			var scale_value := heights[tree_index] / source_height
			var non_uniform := Vector3(scale_value * _rng.randf_range(0.88, 1.1), scale_value, scale_value * _rng.randf_range(0.88, 1.1))
			var tree_transform := Transform3D(Basis(Vector3.UP, _rng.randf_range(-PI, PI)).scaled(non_uniform), positions[tree_index])
			multi.set_instance_transform(local_index, tree_transform * source.transform)
			multi.set_instance_custom_data(local_index, Color(_rng.randf(), _rng.randf_range(0.88, 1.0), 0.0, 1.0))
		var trees := MultiMeshInstance3D.new()
		trees.name = "%s_%d" % [node_prefix, variant_index + 1]
		trees.multimesh = multi
		trees.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if _performance_mode else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(trees)

	if add_colliders:
		for index in range(positions.size()):
			var collider := StaticBody3D.new()
			collider.name = "%sCollision_%03d" % [node_prefix, index]
			collider.position = positions[index] + Vector3.UP * heights[index] * 0.5
			var shape_node := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.height = heights[index]
			shape.radius = clampf(heights[index] * 0.035, 0.25, 0.44)
			shape_node.shape = shape
			collider.add_child(shape_node)
			add_child(collider)
	prototype.free()


func _apply_photogrammetry_wind(mesh: Mesh) -> void:
	for surface in range(mesh.get_surface_count()):
		var original := mesh.surface_get_material(surface) as StandardMaterial3D
		if not original or not original.albedo_texture:
			continue
		var material_name := original.resource_name.to_lower()
		if not ("twig" in material_name or "fern" in material_name or "leaf" in material_name):
			continue
		var wind := ShaderMaterial.new()
		wind.shader = load("res://assets/environments/photogrammetry_tree_wind.gdshader")
		wind.set_shader_parameter("albedo_texture", original.albedo_texture)
		wind.set_shader_parameter("albedo_tint", original.albedo_color)
		wind.set_shader_parameter("height_reference", maxf(mesh.get_aabb().size.y, 0.12))
		wind.set_shader_parameter("wind_strength", 0.055 if "fern" in material_name else 0.032)
		if original.normal_enabled and original.normal_texture:
			wind.set_shader_parameter("normal_texture", original.normal_texture)
			wind.set_shader_parameter("use_normal", true)
		wind.set_shader_parameter("roughness", original.roughness)
		mesh.surface_set_material(surface, wind)


func _add_tree_trunks_and_branches(positions: Array[Vector3], heights: Array[float]) -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.33
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 8 if _performance_mode else 12
	trunk_mesh.material = _bark_material
	var trunk_multi := MultiMesh.new()
	trunk_multi.transform_format = MultiMesh.TRANSFORM_3D
	trunk_multi.mesh = trunk_mesh
	trunk_multi.instance_count = positions.size()

	var branch_mesh := CylinderMesh.new()
	branch_mesh.top_radius = 0.035
	branch_mesh.bottom_radius = 0.095
	branch_mesh.height = 1.0
	branch_mesh.radial_segments = 5 if _performance_mode else 7
	branch_mesh.material = _bark_material
	var branches_per_tree := 5 if _performance_mode else 9
	var branch_multi := MultiMesh.new()
	branch_multi.transform_format = MultiMesh.TRANSFORM_3D
	branch_multi.mesh = branch_mesh
	branch_multi.instance_count = positions.size() * branches_per_tree

	for tree_index in range(positions.size()):
		var height := heights[tree_index]
		var width := _rng.randf_range(0.86, 1.25)
		var trunk_basis := Basis(Vector3.UP, _rng.randf_range(-PI, PI)).scaled(Vector3(width, height, width))
		trunk_multi.set_instance_transform(tree_index, Transform3D(trunk_basis, positions[tree_index] + Vector3.UP * height * 0.5))
		for branch_index in range(branches_per_tree):
			var index := tree_index * branches_per_tree + branch_index
			var branch_y := height * lerpf(0.42, 0.88, branch_index / float(branches_per_tree - 1))
			var angle := branch_index * TAU / branches_per_tree + _rng.randf_range(-0.34, 0.34)
			var length := _rng.randf_range(1.25, 2.65) * (1.1 - branch_index * 0.045) * width
			var direction := Vector3(cos(angle), _rng.randf_range(0.15, 0.38), sin(angle)).normalized()
			var origin := positions[tree_index] + Vector3(0, branch_y, 0)
			var midpoint := origin + direction * length * 0.5
			var basis := _basis_along_y(direction).scaled(Vector3(width, length, width))
			branch_multi.set_instance_transform(index, Transform3D(basis, midpoint))

		if _performance_mode and absf(positions[tree_index].x - _trail_center_x(positions[tree_index].z)) > 5.2:
			continue
		var collider := StaticBody3D.new()
		collider.name = "NaturalTreeCollision_%03d" % tree_index
		collider.position = positions[tree_index] + Vector3.UP * height * 0.5
		var shape_node := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.height = height
		shape.radius = 0.32 * width
		shape_node.shape = shape
		collider.add_child(shape_node)
		add_child(collider)

	var trunks := MultiMeshInstance3D.new()
	trunks.name = "NaturalTreeTrunks"
	trunks.multimesh = trunk_multi
	trunks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if _performance_mode else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(trunks)
	var branches := MultiMeshInstance3D.new()
	branches.name = "NaturalTreeBranches"
	branches.multimesh = branch_multi
	branches.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if _performance_mode else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(branches)


func _add_tree_leaf_cards(positions: Array[Vector3], heights: Array[float]) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.25, 1.18) if _performance_mode else Vector2(0.75, 0.82)
	quad.material = _leaf_material
	var leaves_per_tree := 18 if _performance_mode else 48
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = quad
	multi.instance_count = positions.size() * leaves_per_tree
	for tree_index in range(positions.size()):
		var height := heights[tree_index]
		var crown_width := height * _rng.randf_range(0.19, 0.25)
		for leaf_index in range(leaves_per_tree):
			var index := tree_index * leaves_per_tree + leaf_index
			var y_ratio := _rng.randf_range(0.44, 1.02)
			var crown_curve := sin(clampf((y_ratio - 0.38) / 0.7, 0.0, 1.0) * PI)
			var radius := crown_width * crown_curve * sqrt(_rng.randf())
			var angle := _rng.randf_range(-PI, PI)
			var point := positions[tree_index] + Vector3(cos(angle) * radius, height * y_ratio, sin(angle) * radius)
			var basis := Basis(Vector3.UP, angle + PI * 0.5)
			basis = basis.rotated(basis.x.normalized(), _rng.randf_range(-0.5, 0.5))
			basis = basis.scaled(Vector3.ONE * _rng.randf_range(0.62, 1.18))
			multi.set_instance_transform(index, Transform3D(basis, point))
	var leaves := MultiMeshInstance3D.new()
	leaves.name = "PhotographicLeafCanopies"
	leaves.multimesh = multi
	leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(leaves)


func _build_undergrowth() -> void:
	_add_forest_ferns()
	var grass_material := StandardMaterial3D.new()
	grass_material.albedo_color = Color("6d825d")
	grass_material.albedo_texture = load("res://assets/environments/pbr/Leaf001/Leaf001.png")
	grass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	grass_material.alpha_scissor_threshold = 0.34
	grass_material.roughness = 0.95
	grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if _performance_mode:
		grass_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	var blade := QuadMesh.new()
	blade.size = Vector2(0.42, 0.52)
	blade.material = grass_material
	var grass := MultiMesh.new()
	grass.transform_format = MultiMesh.TRANSFORM_3D
	grass.mesh = blade
	grass.instance_count = 240 if _performance_mode else 920
	for index in range(grass.instance_count):
		var x: float = _rng.randf_range(TERRAIN_MIN_X + 1.0, TERRAIN_MAX_X - 1.0)
		var z: float = _rng.randf_range(TERRAIN_MIN_Z + 1.0, TERRAIN_MAX_Z - 1.0)
		if absf(x - _trail_center_x(z)) < 2.0 or absf(z - _river_center_z(x)) < 2.6:
			x += 3.0 if x < 0.0 else -3.0
		var scale_value := _rng.randf_range(0.45, 1.45)
		var basis := Basis(Vector3.UP, _rng.randf_range(-PI, PI)).scaled(Vector3.ONE * scale_value)
		grass.set_instance_transform(index, Transform3D(basis, Vector3(x, terrain_height(x, z) + 0.22 * scale_value, z)))
	var grass_instance := MultiMeshInstance3D.new()
	grass_instance.name = "ForestFloorPlants"
	grass_instance.multimesh = grass
	grass_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass_instance)

	for index in range(8 if _performance_mode else 34):
		var side := -1.0 if index % 2 == 0 else 1.0
		var z: float = _rng.randf_range(TERRAIN_MIN_Z + 2.0, TERRAIN_MAX_Z - 2.0)
		var x: float = _trail_center_x(z) + float(side) * _rng.randf_range(4.2, 12.0)
		_add_irregular_rock(Vector3(x, terrain_height(x, z) + 0.16, z), Vector3(_rng.randf_range(0.4, 1.45), _rng.randf_range(0.32, 0.92), _rng.randf_range(0.5, 1.5)), true)


func _add_forest_ferns() -> void:
	var positions: Array[Vector3] = []
	var heights: Array[float] = []
	var attempts := 0
	var fern_target := 40 if _performance_mode else 180
	while positions.size() < fern_target and attempts < 1600:
		attempts += 1
		var z: float = _rng.randf_range(TERRAIN_MIN_Z + 1.0, TERRAIN_MAX_Z - 1.0)
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var x: float = _trail_center_x(z) + side * _rng.randf_range(2.25, 10.5)
		if x < TERRAIN_MIN_X + 1.0 or x > TERRAIN_MAX_X - 1.0:
			continue
		if absf(z - _river_center_z(x)) < 2.8:
			continue
		positions.append(Vector3(x, terrain_height(x, z) + 0.02, z))
		heights.append(_rng.randf_range(0.62, 1.15))
	if _performance_mode:
		_add_mobile_fern_cards(positions, heights)
		return
	_add_photogrammetry_tree_multimeshes(
		positions,
		heights,
		"res://assets/models/plants/polyhaven_fern_02_cc0/fern_02_1k.gltf",
		"ForestFern",
		false
	)


func _add_mobile_fern_cards(positions: Array[Vector3], heights: Array[float]) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("799468")
	material.albedo_texture = load("res://assets/environments/pbr/Leaf001/Leaf001.png")
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.38
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	material.roughness = 0.95
	var quad := QuadMesh.new()
	quad.size = Vector2(0.95, 0.8)
	quad.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = quad
	multi.instance_count = positions.size() * 3
	for plant_index in range(positions.size()):
		for card_index in range(3):
			var index := plant_index * 3 + card_index
			var angle := card_index * PI / 3.0 + _rng.randf_range(-0.12, 0.12)
			var scale_value := heights[plant_index]
			var basis := Basis(Vector3.UP, angle).scaled(Vector3(scale_value, scale_value, scale_value))
			multi.set_instance_transform(index, Transform3D(basis, positions[plant_index] + Vector3.UP * 0.34 * scale_value))
	var ferns := MultiMeshInstance3D.new()
	ferns.name = "ForestFernMobile"
	ferns.multimesh = multi
	ferns.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ferns)


func _build_natural_boundaries() -> void:
	if _performance_mode:
		_add_invisible_boundary("BoundaryWest", Vector3(1.2, 5.0, 68.0), Vector3(-25.0, 1.5, -4.0))
		_add_invisible_boundary("BoundaryEast", Vector3(1.2, 5.0, 68.0), Vector3(25.0, 1.5, -4.0))
		_add_invisible_boundary("BoundaryNorth", Vector3(50.0, 5.0, 1.2), Vector3(0.0, 1.5, -37.0))
		_add_invisible_boundary("BoundarySouth", Vector3(50.0, 5.0, 1.2), Vector3(0.0, 1.5, 29.0))
		return
	for z in range(-35, 29, 4):
		for x in [-24.4, 24.4]:
			_add_irregular_rock(Vector3(x, terrain_height(x, z) + 0.8, z), Vector3(2.2, 2.0, 2.6), true)
	for x in range(-23, 24, 4):
		for z in [-36.0, 28.0]:
			_add_irregular_rock(Vector3(x, terrain_height(x, z) + 0.8, z), Vector3(2.3, 2.0, 2.2), true)


func _add_invisible_boundary(name_text: String, size: Vector3, position: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = name_text
	body.position = position
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	add_child(body)


func _build_stage_landmark() -> void:
	match stage_number:
		1:
			goal_position = Vector3(-13.4, terrain_height(-13.4, -18.5), -18.5)
			_build_ranger_cabin(goal_position)
		2:
			goal_position = Vector3(10.5, terrain_height(10.5, -29.0), -29.0)
			_build_lookout(goal_position)
		3:
			var cave_entrance := Vector3(0.0, terrain_height(0.0, -30.0), -30.0)
			_build_cave(cave_entrance)
			goal_position = Vector3(0.0, terrain_height(0.0, -34.4), -34.4)
		4:
			goal_position = Vector3(11.5, terrain_height(11.5, -27.0), -27.0)
			_build_ruined_fortress(goal_position)
		_:
			goal_position = Vector3(-11.0, terrain_height(-11.0, -27.5), -27.5)
			_build_rescue_outpost(goal_position)
	_build_objective_beacon(goal_position)


func _build_ranger_cabin(center: Vector3) -> void:
	_add_box("CabinFloor", Vector3(5.8, 0.2, 4.8), center + Vector3(0, 0.18, 0), _bark_material, true)
	for plank_index in range(7):
		var x := -2.55 + plank_index * 0.85
		_add_box("CabinBackPlank", Vector3(0.76, 2.65, 0.18), center + Vector3(x, 1.48, -2.28), _bark_material, true)
	for side in [-1.0, 1.0]:
		_add_box("CabinSide", Vector3(0.2, 2.7, 4.7), center + Vector3(side * 2.78, 1.5, 0), _bark_material, true)
		_add_box("CabinFront", Vector3(1.8, 2.7, 0.2), center + Vector3(side * 1.85, 1.5, 2.28), _bark_material, true)
	var roof_material := _rock_material.duplicate(true)
	roof_material.albedo_color = Color("342e27")
	for side in [-1.0, 1.0]:
		var roof := _add_box("CabinRoof", Vector3(3.25, 0.18, 5.4), center + Vector3(side * 1.35, 3.18, 0), roof_material, true)
		roof.rotation.z = deg_to_rad(side * 24.0)
	var light := OmniLight3D.new()
	light.position = center + Vector3(0, 2.0, 0.5)
	light.light_color = Color("ffc06e")
	light.light_energy = 1.25
	light.omni_range = 5.0
	add_child(light)


func _build_lookout(center: Vector3) -> void:
	for side_x in [-1.0, 1.0]:
		for side_z in [-1.0, 1.0]:
			_add_cylinder("LookoutPost", center + Vector3(side_x * 1.65, 1.7, side_z * 1.4), 0.16, 3.5, _bark_material, true)
	_add_box("LookoutDeck", Vector3(4.2, 0.22, 3.7), center + Vector3(0, 3.35, 0), _bark_material, true)
	for stair_index in range(7):
		_add_box("LookoutStep", Vector3(1.25, 0.16, 0.42), center + Vector3(0, 0.42 + stair_index * 0.43, 2.35 - stair_index * 0.38), _bark_material, true)


func _build_cave(center: Vector3) -> void:
	for ring_index in range(14):
		var angle := lerpf(0.08, PI - 0.08, ring_index / 13.0)
		var rock_position := center + Vector3(cos(angle) * 4.0, sin(angle) * 3.6 + 0.1, 0)
		_add_irregular_rock(rock_position, Vector3(_rng.randf_range(1.3, 2.1), _rng.randf_range(1.0, 1.7), _rng.randf_range(1.5, 2.2)), true)
	for depth_index in range(5):
		for side in [-1.0, 1.0]:
			_add_irregular_rock(center + Vector3(side * 3.8, 1.4, -depth_index * 2.4), Vector3(1.8, 2.2, 2.0), true)
	var cave_dark := _rock_material.duplicate(true)
	cave_dark.albedo_color = Color("171b18")
	_add_box("CaveDarkness", Vector3(6.2, 5.0, 0.25), center + Vector3(0, 2.1, -5.15), cave_dark, false)
	for light_index in range(3):
		var cave_light := OmniLight3D.new()
		cave_light.name = "CaveEmber_%d" % light_index
		cave_light.position = center + Vector3(-1.8 + light_index * 1.8, 0.75, -1.2 - light_index * 1.15)
		cave_light.light_color = Color("ff884c")
		cave_light.light_energy = 0.7
		cave_light.omni_range = 3.2
		cave_light.shadow_enabled = false
		add_child(cave_light)


func _build_ruined_fortress(center: Vector3) -> void:
	var stone := _rock_material.duplicate(true)
	stone.albedo_color = Color("62574d")
	_add_box("FortressFloor", Vector3(12.0, 0.28, 10.0), center + Vector3(0, 0.08, 0), stone, true)
	_add_box("FortressBackWall", Vector3(12.0, 4.2, 0.75), center + Vector3(0, 2.1, -4.6), stone, true)
	for side in [-1.0, 1.0]:
		_add_box("FortressSideWall", Vector3(0.75, 4.2, 9.8), center + Vector3(side * 5.65, 2.1, 0), stone, true)
		_add_box("FortressGateTower", Vector3(2.25, 5.8, 2.25), center + Vector3(side * 3.55, 2.9, 4.25), stone, true)
		for tooth in range(3):
			_add_box("FortressBattlement", Vector3(0.75, 0.75, 0.9), center + Vector3(side * (4.9 - tooth * 1.35), 4.65, -4.55), stone, true)
	_add_box("FortressGateBeam", Vector3(4.8, 0.7, 0.8), center + Vector3(0, 4.55, 4.25), _bark_material, true)
	var treasure := _add_box("FortressTreasure", Vector3(1.7, 0.85, 1.05), center + Vector3(0, 0.62, -2.7), _bark_material, true)
	treasure.rotation.y = 0.08


func _build_rescue_outpost(center: Vector3) -> void:
	var outpost_stone := _rock_material.duplicate(true)
	outpost_stone.albedo_color = Color("505961")
	for step_index in range(5):
		_add_box("RescueOutpostStep", Vector3(9.0 - step_index * 0.65, 0.28, 1.05), center + Vector3(0, step_index * 0.26, 4.2 - step_index * 0.72), outpost_stone, true)
	_add_box("RescueOutpostPlatform", Vector3(10.0, 0.42, 8.0), center + Vector3(0, 1.18, -0.4), outpost_stone, true)
	for side in [-1.0, 1.0]:
		for depth in [-2.3, 0.0, 2.3]:
			_add_cylinder("RescueOutpostPost", center + Vector3(side * 3.8, 3.2, depth - 0.4), 0.34, 4.1, outpost_stone, true)
	_add_box("RescueOutpostRoof", Vector3(9.4, 0.55, 6.8), center + Vector3(0, 5.25, -0.4), outpost_stone, true)
	# The glowing cage marks the trapped explorer; interaction becomes available
	# only after all mission locks and the final alpha lion are cleared.
	for side in [-1.0, 1.0]:
		_add_cylinder("RescueCageBar", center + Vector3(side * 0.8, 2.15, -1.4), 0.08, 2.1, _bark_material, false)
		_add_cylinder("RescueCageBar", center + Vector3(side * 0.28, 2.15, -1.4), 0.08, 2.1, _bark_material, false)
	var rescue_light := OmniLight3D.new()
	rescue_light.name = "RescueSignal"
	rescue_light.position = center + Vector3(0, 2.2, -1.2)
	rescue_light.light_color = Color("ffd18a")
	rescue_light.light_energy = 1.65
	rescue_light.omni_range = 5.4
	rescue_light.shadow_enabled = false
	add_child(rescue_light)


func _build_objective_beacon(center: Vector3) -> void:
	var light := OmniLight3D.new()
	light.name = "ObjectiveWarmLight"
	light.position = center + Vector3(0, 1.65, 0)
	light.light_color = Color("ffb247")
	light.light_energy = 1.05
	light.omni_range = 4.2
	light.shadow_enabled = false
	add_child(light)


func _build_air_particles() -> void:
	var mote_material := StandardMaterial3D.new()
	mote_material.albedo_color = Color(1.0, 0.72, 0.28, 0.62)
	mote_material.emission_enabled = true
	mote_material.emission = Color("ad672a")
	mote_material.emission_energy_multiplier = 1.2
	mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mote := SphereMesh.new()
	mote.radius = 0.013
	mote.height = 0.026
	mote.radial_segments = 5
	mote.rings = 3
	mote.material = mote_material
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(20, 2.8, 29)
	process.direction = Vector3(0.25, 0.12, -0.08)
	process.spread = 180.0
	process.initial_velocity_min = 0.03
	process.initial_velocity_max = 0.16
	process.gravity = Vector3(0, 0.012, 0)
	var particles := GPUParticles3D.new()
	particles.name = "FloatingForestDust"
	particles.position = Vector3(0, 2.2, -4)
	particles.amount = 28 if _performance_mode else 58
	particles.lifetime = 8.0
	particles.randomness = 0.9
	particles.fixed_fps = 18
	particles.visibility_aabb = AABB(Vector3(-26, -4, -38), Vector3(52, 10, 68))
	particles.process_material = process
	particles.draw_pass_1 = mote
	add_child(particles)


func _build_stage_weather() -> void:
	if stage_number != 2:
		return
	var rain_material := StandardMaterial3D.new()
	rain_material.albedo_color = Color(0.68, 0.83, 0.9, 0.42)
	rain_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var drop := QuadMesh.new()
	drop.size = Vector2(0.015, 0.52)
	drop.material = rain_material
	var rain_process := ParticleProcessMaterial.new()
	rain_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain_process.emission_box_extents = Vector3(24.0, 0.4, 32.0)
	rain_process.direction = Vector3(0.08, -1.0, 0.03)
	rain_process.spread = 5.0
	rain_process.initial_velocity_min = 10.0
	rain_process.initial_velocity_max = 15.0
	rain_process.gravity = Vector3(0.0, -2.2, 0.0)
	var rain := GPUParticles3D.new()
	rain.name = "RiverStormRain"
	rain.position = Vector3(0.0, 9.0, -3.0)
	rain.amount = 180 if _performance_mode else 520
	rain.lifetime = 1.45
	rain.randomness = 0.42
	rain.fixed_fps = 24
	rain.visibility_aabb = AABB(Vector3(-27, -12, -38), Vector3(54, 24, 72))
	rain.process_material = rain_process
	rain.draw_pass_1 = drop
	add_child(rain)


func _add_irregular_rock(position: Vector3, rock_scale: Vector3, collision_enabled: bool) -> void:
	var parent: Node3D = StaticBody3D.new() if collision_enabled else Node3D.new()
	parent.position = position
	parent.rotation_degrees = Vector3(_rng.randf_range(-12, 12), _rng.randf_range(0, 180), _rng.randf_range(-9, 9))
	parent.scale = rock_scale
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.72
	mesh.height = 1.08
	mesh.radial_segments = 9
	mesh.rings = 5
	mesh.material = _rock_material
	mesh_instance.mesh = mesh
	parent.add_child(mesh_instance)
	if collision_enabled:
		var shape_node := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.62
		shape_node.shape = shape
		parent.add_child(shape_node)
	add_child(parent)


func _add_box(name_text: String, size: Vector3, position: Vector3, material: Material, collision_enabled: bool) -> Node3D:
	var parent: Node3D = StaticBody3D.new() if collision_enabled else Node3D.new()
	parent.name = name_text
	parent.position = position
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	parent.add_child(mesh_instance)
	if collision_enabled:
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		parent.add_child(shape_node)
	add_child(parent)
	return parent


func _add_cylinder(name_text: String, position: Vector3, radius: float, height: float, material: Material, collision_enabled: bool) -> Node3D:
	var parent: Node3D = StaticBody3D.new() if collision_enabled else Node3D.new()
	parent.name = name_text
	parent.position = position
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.82
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.material = material
	mesh_instance.mesh = mesh
	parent.add_child(mesh_instance)
	if collision_enabled:
		var shape_node := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		shape_node.shape = shape
		parent.add_child(shape_node)
	add_child(parent)
	return parent


func _basis_along_y(direction: Vector3) -> Basis:
	var y_axis := direction.normalized()
	var x_axis := y_axis.cross(Vector3.FORWARD)
	if x_axis.length_squared() < 0.001:
		x_axis = y_axis.cross(Vector3.RIGHT)
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


func _pbr_material(albedo_path: String, normal_path: String, roughness_path: String, ao_path: String, tint: Color, uv_scale: Vector3) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.albedo_texture = load(albedo_path)
	material.normal_enabled = true
	material.normal_texture = load(normal_path)
	material.normal_scale = 0.78
	material.roughness = 0.92
	material.roughness_texture = load(roughness_path)
	material.ao_enabled = true
	material.ao_texture = load(ao_path)
	material.ao_light_affect = 0.7
	material.uv1_scale = uv_scale
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


func _environment_material(albedo_path: String, normal_path: String, roughness_path: String, ao_path: String, tint: Color, uv_scale: Vector3) -> StandardMaterial3D:
	if not _performance_mode:
		return _pbr_material(albedo_path, normal_path, roughness_path, ao_path, tint, uv_scale)
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.albedo_texture = load(albedo_path)
	material.roughness = 0.92
	material.uv1_scale = uv_scale
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return material
