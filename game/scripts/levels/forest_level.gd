extends Node3D

const MAX_STAGES := 5
const START_POSITION := Vector3(0, 0.08, 21)
const CollectibleScene := preload("res://scenes/objects/collectible.tscn")
const LionEnemyScene := preload("res://scenes/characters/lion_enemy.tscn")
const RealForestWorldScript := preload("res://scripts/levels/real_forest_world.gd")

@export_range(1, 5) var stage_number := 1

@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD

var _pieces_collected := 0
var _elapsed_seconds := 0.0
var _near_goal := false
var _completed := false
var _player_defeated := false
var _lions_remaining := 0
var _rng := RandomNumberGenerator.new()
var _real_world: RealForestWorld
var _spawn_point := START_POSITION
var _goal_point := Vector3(0, 0, -30)
var _adventure_event_completed := false
var _mission_phase := 0
var _required_pieces := 3
var _boss_defeated := false
var _performance_sample_elapsed := 0.0
var _hud_time_accumulator := 0.0

var _ground_material: StandardMaterial3D
var _path_material: StandardMaterial3D
var _wood_material: StandardMaterial3D
var _leaf_material: Material
var _water_material: Material
var _rock_material: StandardMaterial3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.seed = 731905 + stage_number * 97
	_real_world = RealForestWorldScript.new()
	_real_world.name = "RealForestWorld"
	add_child(_real_world)
	_real_world.build_world(stage_number)
	_spawn_point = _real_world.start_position
	_goal_point = _real_world.goal_position
	_required_pieces = _required_item_count()
	_create_interactive_goal()
	_build_stage_event_trigger()
	_spawn_collectibles()
	_spawn_lions()
	player.global_position = _spawn_point
	hud.connect_player(player)
	hud.pause_requested.connect(_pause_game)
	hud.resume_requested.connect(_resume_game)
	hud.retry_requested.connect(_retry_level)
	hud.menu_requested.connect(_return_to_menu)
	hud.next_stage_requested.connect(_load_next_stage)
	player.health_changed.connect(hud.set_health)
	player.shot_fired.connect(hud.flash_crosshair)
	player.died.connect(_on_player_died)
	player.restore_health()
	hud.set_mission_items(_mission_item_name(), 0, _required_pieces)
	hud.set_lions(_lions_remaining)
	hud.set_objective(_initial_objective())
	hud.show_toast(_stage_intro(), 4.5)
	GameState.start_run()


func _build_stage_event_trigger() -> void:
	var trigger := Area3D.new()
	trigger.name = "AdventureEventTrigger"
	trigger.collision_layer = 0
	trigger.collision_mask = 1
	var event_position: Vector3
	match stage_number:
		1:
			event_position = Vector3(_real_world._trail_center_x(12.0), _real_world.terrain_height(0.0, 12.0) + 1.0, 12.0)
		2:
			event_position = Vector3(_real_world._trail_center_x(-4.5), _real_world.terrain_height(0.0, -4.5) + 1.0, -4.5)
		3:
			event_position = Vector3(_real_world._trail_center_x(-22.0), _real_world.terrain_height(0.0, -22.0) + 1.0, -22.0)
		4:
			event_position = Vector3(_real_world._trail_center_x(-17.0), _real_world.terrain_height(0.0, -17.0) + 1.0, -17.0)
		_:
			event_position = Vector3(_real_world._trail_center_x(-9.0), _real_world.terrain_height(0.0, -9.0) + 1.0, -9.0)
	trigger.position = event_position
	var collision_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(8.0, 3.5, 4.2)
	collision_node.shape = shape
	trigger.add_child(collision_node)
	trigger.body_entered.connect(_on_adventure_event_entered)
	add_child(trigger)


func _on_adventure_event_entered(body: Node3D) -> void:
	if _adventure_event_completed or not body.is_in_group("player"):
		return
	_adventure_event_completed = true
	_mission_phase = 1
	match stage_number:
		1:
			hud.show_toast("وجدت آثار القطيع — الأسود تراقبك بين الأشجار", 3.5)
			hud.set_objective("اجمع أجزاء الخريطة وتتبّع الأسود إلى كوخ الحارس")
		2:
			hud.show_toast("عبرت النهر — بدأ كمين الأسود عند الضفة الجنوبية", 3.5)
			hud.set_objective("انجُ من الكمين واجمع مؤن الضفة ثم اصعد برج المراقبة")
		3:
			hud.show_toast("وصلت إلى العرين — الأسد القائد يحرس عمق الكهف", 3.5)
			hud.set_objective("اهزم الأسد القائد واستعد آخر أثر داخل الكهف")
		4:
			hud.show_toast("ظهرت القلعة المهدمة — البوابة تحتاج المفاتيح الأربعة", 3.5)
			hud.set_objective("اجمع مفاتيح القلعة واهزم حرّاسها ثم افتح البوابة")
		_:
			hud.show_toast("بدأ حصار حصن الوادي — القائد الأخير يحتجز المستكشف", 3.5)
			hud.set_objective("اجمع حقائب الإسعاف، حرر المستكشف ثم شغّل جهاز الاتصال")


func _initial_objective() -> String:
	match stage_number:
		1:
			return "اتبع آثار الأسود داخل الغابة"
		2:
			return "اعبر النهر المتحرك عبر الجسر أو المياه"
		3:
			return "تسلل عبر الغابة وابحث عن مدخل العرين"
		4:
			return "اعثر على مفاتيح القلعة المهدمة وافتح بوابتها"
		_:
			return "تقدم إلى حصن الوادي وأنقذ المستكشف من الحصار"


func _process(delta: float) -> void:
	if OS.has_feature("mobile"):
		_performance_sample_elapsed += delta
		if _performance_sample_elapsed >= 5.0:
			_performance_sample_elapsed = 0.0
			print("MOBILE_PERF fps=%d objects=%d draw_calls=%d primitives=%d" % [
				Engine.get_frames_per_second(),
				int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
				int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
				int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			])
	if Input.is_action_just_pressed("pause"):
		if get_tree().paused:
			_resume_game()
		else:
			_pause_game()

	if get_tree().paused or _completed or _player_defeated:
		return
	_elapsed_seconds += delta
	_hud_time_accumulator += delta
	if _hud_time_accumulator >= 0.1:
		_hud_time_accumulator = 0.0
		hud.set_time(_elapsed_seconds)
	if _near_goal and Input.is_action_just_pressed("interact"):
		_try_finish()
	if player.global_position.y < -4.0:
		player.global_position = _spawn_point
		player.velocity = Vector3.ZERO
		hud.show_toast("عدت إلى بداية المسار")


func _create_materials() -> void:
	_ground_material = _pbr_material(
		"res://assets/environments/pbr/Ground037/Ground037_1K-JPG_Color.jpg",
		"res://assets/environments/pbr/Ground037/Ground037_1K-JPG_NormalGL.jpg",
		"res://assets/environments/pbr/Ground037/Ground037_1K-JPG_Roughness.jpg",
		"res://assets/environments/pbr/Ground037/Ground037_1K-JPG_AmbientOcclusion.jpg",
		Color("71856b"), 7.0
	)
	_path_material = _ground_material.duplicate(true)
	_path_material.albedo_color = Color("8b7655")
	_path_material.uv1_scale = Vector3.ONE * 10.0
	_wood_material = _pbr_material(
		"res://assets/environments/pbr/Bark012/Bark012_1K-JPG_Color.jpg",
		"res://assets/environments/pbr/Bark012/Bark012_1K-JPG_NormalGL.jpg",
		"res://assets/environments/pbr/Bark012/Bark012_1K-JPG_Roughness.jpg",
		"res://assets/environments/pbr/Bark012/Bark012_1K-JPG_AmbientOcclusion.jpg",
		Color("6b553e"), 2.4
	)
	_leaf_material = _moving_material("res://assets/environments/foliage_wind.gdshader", "base_color", Color("315f34"), 0.12)
	_water_material = ShaderMaterial.new()
	_water_material.shader = load("res://assets/environments/moving_water.gdshader")
	_water_material.set_shader_parameter("shallow_color", Color(0.08, 0.37, 0.45, 0.76))
	_rock_material = _ground_material.duplicate(true)
	_rock_material.albedo_color = Color("697169")
	_rock_material.uv1_scale = Vector3.ONE * 3.2


func _build_environment() -> void:
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("31586f")
	sky_material.sky_horizon_color = Color("d8d6b5")
	sky_material.ground_bottom_color = Color("0c1b15")
	sky_material.ground_horizon_color = Color("78876c")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.48
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("b8c0a5")
	environment.fog_light_energy = 0.55
	environment.fog_density = 0.0065
	environment.fog_sky_affect = 0.48

	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -34, 0)
	sun.light_color = Color("fff2cf")
	sun.light_energy = 1.52
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 48.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)
	_build_ambient_motion()


func _build_terrain() -> void:
	_add_box("NorthGround", Vector3(46, 1.0, 23), Vector3(0, -0.5, 14.5), _ground_material, true)
	_add_box("SouthGround", Vector3(46, 1.0, 32), Vector3(0, -0.5, -19), _ground_material, true)
	_add_box("RiverBed", Vector3(46, 0.7, 6), Vector3(0, -1.05, 0), _rock_material, true)
	_add_box("Water", Vector3(45.8, 0.12, 5.8), Vector3(0, -0.36, 0), _water_material, false)

	_add_box("NorthPath", Vector3(4.4, 0.035, 21.2), Vector3(0, 0.02, 14.4), _path_material, false)
	_add_box("SouthPath", Vector3(4.4, 0.035, 29.0), Vector3(0, 0.02, -18.4), _path_material, false)
	_add_trail_variation()

	for index in range(9):
		var plank_z := 3.2 - index * 0.8
		_add_box("BridgePlank_%02d" % index, Vector3(4.2, 0.22, 0.72), Vector3(0, 0.05, plank_z), _wood_material, true)
	_add_box("BridgeRailLeft", Vector3(0.16, 0.75, 7.2), Vector3(-2.05, 0.53, 0), _wood_material, true)
	_add_box("BridgeRailRight", Vector3(0.16, 0.75, 7.2), Vector3(2.05, 0.53, 0), _wood_material, true)
	_build_river_detail()

	_add_bounds()


func _add_trail_variation() -> void:
	var damp_material := _ground_material.duplicate(true)
	damp_material.albedo_color = Color("4c4a35")
	damp_material.roughness = 0.78
	var trail_points := [
		Vector3(-0.55, 0.045, 18.0), Vector3(0.7, 0.045, 12.2),
		Vector3(-0.45, 0.045, 7.0), Vector3(0.55, 0.045, -7.5),
		Vector3(-0.75, 0.045, -13.0), Vector3(0.4, 0.045, -19.0),
		Vector3(-0.4, 0.045, -25.2),
	]
	for index in range(trail_points.size()):
		var patch := MeshInstance3D.new()
		patch.name = "TrailDetail_%02d" % index
		patch.position = trail_points[index]
		patch.rotation.y = _rng.randf_range(-PI, PI)
		var mesh := CylinderMesh.new()
		mesh.top_radius = _rng.randf_range(0.65, 1.15)
		mesh.bottom_radius = mesh.top_radius * 1.03
		mesh.height = 0.018
		mesh.radial_segments = 14
		mesh.material = damp_material
		patch.scale.z = _rng.randf_range(0.52, 0.82)
		patch.mesh = mesh
		add_child(patch)

	for index in range(14):
		var side := -1.0 if index % 2 == 0 else 1.0
		var mound := MeshInstance3D.new()
		mound.name = "TerrainMound_%02d" % index
		mound.position = Vector3(side * _rng.randf_range(5.8, 19.5), -0.06, _rng.randf_range(-31.0, 23.0))
		var mound_mesh := SphereMesh.new()
		mound_mesh.radius = 1.0
		mound_mesh.height = 2.0
		mound_mesh.radial_segments = 12
		mound_mesh.rings = 6
		mound_mesh.material = _ground_material
		mound.mesh = mound_mesh
		mound.scale = Vector3(_rng.randf_range(1.4, 3.2), _rng.randf_range(0.28, 0.72), _rng.randf_range(1.3, 2.8))
		add_child(mound)


func _build_river_detail() -> void:
	for index in range(22):
		var side_z := -3.25 if index % 2 == 0 else 3.25
		var rock_position := Vector3(_rng.randf_range(-21.0, 21.0), -0.12, side_z + _rng.randf_range(-0.35, 0.35))
		_add_rock(rock_position, Vector3(_rng.randf_range(0.35, 0.9), _rng.randf_range(0.22, 0.52), _rng.randf_range(0.4, 1.0)))

	var reed_material := _moving_material("res://assets/environments/foliage_wind.gdshader", "base_color", Color("789445"), 0.18)
	var reed_mesh := BoxMesh.new()
	reed_mesh.size = Vector3(0.055, 0.9, 0.045)
	reed_mesh.material = reed_material
	var reed_multi := MultiMesh.new()
	reed_multi.transform_format = MultiMesh.TRANSFORM_3D
	reed_multi.use_custom_data = true
	reed_multi.mesh = reed_mesh
	reed_multi.instance_count = 80
	for index in range(reed_multi.instance_count):
		var bank := -3.05 if index % 2 == 0 else 3.05
		var position := Vector3(_rng.randf_range(-21.0, 21.0), 0.08, bank + _rng.randf_range(-0.38, 0.38))
		if absf(position.x) < 2.8:
			position.x += 3.3 if position.x >= 0.0 else -3.3
		var size_scale := _rng.randf_range(0.55, 1.35)
		reed_multi.set_instance_transform(index, Transform3D(Basis(Vector3.UP, _rng.randf_range(-PI, PI)).scaled(Vector3.ONE * size_scale), position))
		reed_multi.set_instance_custom_data(index, Color(_rng.randf_range(0.82, 1.0), _rng.randf_range(0.92, 1.08), 0.78, 1.0))
	var reeds := MultiMeshInstance3D.new()
	reeds.name = "RiverReeds_MultiMesh"
	reeds.multimesh = reed_multi
	reeds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(reeds)

	var waterfall := MeshInstance3D.new()
	waterfall.name = "MovingWaterfall"
	waterfall.position = Vector3(-20.8, 0.85, 0.0)
	waterfall.rotation.z = PI * 0.5
	var waterfall_mesh := BoxMesh.new()
	waterfall_mesh.size = Vector3(2.8, 0.08, 5.4)
	waterfall_mesh.material = _water_material
	waterfall.mesh = waterfall_mesh
	add_child(waterfall)


func _build_forest() -> void:
	var tree_positions: Array[Vector3] = []
	var tree_heights: Array[float] = []
	var attempts := 0
	while tree_positions.size() < 88 and attempts < 700:
		attempts += 1
		var position := Vector3(_rng.randf_range(-21.0, 21.0), 0.0, _rng.randf_range(-33.0, 25.0))
		if absf(position.x) < _rng.randf_range(4.2, 6.4):
			continue
		if absf(position.z) < 3.8:
			continue
		if position.distance_to(START_POSITION) < 4.0 or position.distance_to(Vector3(0, 0, -30)) < 4.0:
			continue
		tree_positions.append(position)
		tree_heights.append(_rng.randf_range(5.0, 8.8))
	_add_tree_multimeshes(tree_positions, tree_heights)
	_add_leaf_card_multimesh(tree_positions, tree_heights)

	for index in range(18):
		var side := -1.0 if index % 2 == 0 else 1.0
		var rock_position := Vector3(side * _rng.randf_range(5.0, 19.0), 0.2, _rng.randf_range(-31.0, 23.0))
		if absf(rock_position.z) < 3.5:
			rock_position.z += 6.0
		_add_rock(rock_position, Vector3(_rng.randf_range(0.45, 1.15), _rng.randf_range(0.35, 0.82), _rng.randf_range(0.5, 1.2)))

	_add_grass_multimesh()


func _build_landmarks() -> void:
	_add_box("StartPostLeft", Vector3(0.28, 2.4, 0.28), Vector3(-2.1, 1.2, 22.8), _wood_material, true)
	_add_box("StartPostRight", Vector3(0.28, 2.4, 0.28), Vector3(2.1, 1.2, 22.8), _wood_material, true)
	_add_box("StartBeam", Vector3(4.5, 0.28, 0.28), Vector3(0, 2.3, 22.8), _wood_material, true)

	for z_value in [13.0, 6.5, -8.5, -17.0]:
		var side := -1.0 if int(absf(z_value)) % 2 == 0 else 1.0
		_add_box("TrailMarker", Vector3(0.18, 1.3, 0.18), Vector3(side * 2.7, 0.65, z_value), _wood_material, true)

	var log_mesh := CylinderMesh.new()
	log_mesh.top_radius = 0.25
	log_mesh.bottom_radius = 0.31
	log_mesh.height = 3.8
	log_mesh.radial_segments = 10
	log_mesh.material = _wood_material
	var log_body := StaticBody3D.new()
	log_body.name = "FallenLog"
	log_body.position = Vector3(2.8, 0.34, -12.5)
	log_body.rotation.z = PI * 0.5
	var log_visual := MeshInstance3D.new()
	log_visual.mesh = log_mesh
	log_body.add_child(log_visual)
	var log_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.31
	cylinder.height = 3.8
	log_shape.shape = cylinder
	log_body.add_child(log_shape)
	add_child(log_body)

	var glow := _material(Color("e59a31"), 0.35)
	glow.emission_enabled = true
	glow.emission = Color("d66a16")
	glow.emission_energy_multiplier = 2.2
	_add_box("GoalLeft", Vector3(0.45, 3.5, 0.45), Vector3(-2.15, 1.75, -30), glow, true)
	_add_box("GoalRight", Vector3(0.45, 3.5, 0.45), Vector3(2.15, 1.75, -30), glow, true)
	_add_box("GoalTop", Vector3(4.75, 0.45, 0.45), Vector3(0, 3.48, -30), glow, true)

	var goal := Area3D.new()
	goal.name = "GoalArea"
	goal.position = Vector3(0, 1.25, -30)
	goal.collision_layer = 0
	goal.collision_mask = 1
	var goal_collision := CollisionShape3D.new()
	var goal_shape := BoxShape3D.new()
	goal_shape.size = Vector3(3.7, 2.5, 2.4)
	goal_collision.shape = goal_shape
	goal.add_child(goal_collision)
	goal.body_entered.connect(_on_goal_entered)
	goal.body_exited.connect(_on_goal_exited)
	add_child(goal)

	var beacon := OmniLight3D.new()
	beacon.position = Vector3(0, 2.1, -30)
	beacon.light_color = Color("ff9e3e")
	beacon.light_energy = 1.8
	beacon.omni_range = 6.5
	beacon.shadow_enabled = false
	add_child(beacon)
	_build_ranger_cabin()
	if stage_number == 3:
		_build_cave_entrance()


func _spawn_collectibles() -> void:
	var stage_locations := {
		1: [Vector2(-2.4, 15.5), Vector2(2.8, 8.0), Vector2(-12.8, -18.2)],
		2: [Vector2(3.2, 17.0), Vector2(-2.4, 7.0), Vector2(0.6, -1.0), Vector2(10.2, -27.0)],
		3: [Vector2(-3.0, 16.0), Vector2(-5.0, -16.0), Vector2(0.0, -32.0)],
		4: [Vector2(3.0, 15.0), Vector2(-2.0, 5.0), Vector2(6.5, -12.0), Vector2(11.5, -27.0)],
		5: [Vector2(-3.2, 16.0), Vector2(3.0, 8.0), Vector2(-2.0, -1.0), Vector2(-8.0, -15.0), Vector2(-11.0, -27.0)],
	}
	var locations: Array = stage_locations[stage_number]
	for index in range(locations.size()):
		var item := CollectibleScene.instantiate()
		item.name = "CompassPiece_%d" % (index + 1)
		var point: Vector2 = locations[index]
		item.position = Vector3(point.x, _real_world.terrain_height(point.x, point.y) + 0.95, point.y)
		item.collected.connect(_on_piece_collected)
		add_child(item)


func _spawn_lions() -> void:
	var stage_spawns := {
		1: [Vector3(2.8, 0.1, 13.2), Vector3(7.0, 0.1, -11.5)],
		2: [Vector3(7.5, 0.1, 14.0), Vector3(-7.0, 0.1, -5.0), Vector3(7.2, 0.1, -20.0)],
		3: [Vector3(-7.8, 0.1, 14.0), Vector3(7.2, 0.1, 4.0), Vector3(-7.0, 0.1, -11.0), Vector3(0.0, 0.1, -23.0)],
		4: [Vector3(5.5, 0.1, 15.0), Vector3(-6.0, 0.1, 7.0), Vector3(6.5, 0.1, -4.0), Vector3(-7.0, 0.1, -15.0), Vector3(10.0, 0.1, -26.0)],
		5: [Vector3(-5.0, 0.1, 15.0), Vector3(6.0, 0.1, 9.0), Vector3(-6.5, 0.1, 1.5), Vector3(6.0, 0.1, -9.0), Vector3(-7.0, 0.1, -19.0), Vector3(-11.0, 0.1, -27.0)],
	}
	var locations: Array = stage_spawns[stage_number]
	_lions_remaining = locations.size()
	for index in range(locations.size()):
		var lion := LionEnemyScene.instantiate()
		lion.name = "Lion_%d_%d" % [stage_number, index + 1]
		var spawn: Vector3 = locations[index]
		lion.position = Vector3(spawn.x, _real_world.terrain_height(spawn.x, spawn.z) + 0.1, spawn.z)
		lion.died.connect(_on_lion_died)
		lion.attacked_player.connect(_on_lion_attacked)
		add_child(lion)
		var is_boss := stage_number in [3, 5] and index == locations.size() - 1
		lion.set_meta(&"stage_boss", is_boss)
		lion.setup(player, stage_number, is_boss)


func _create_interactive_goal() -> void:
	var goal := Area3D.new()
	goal.name = "GoalArea"
	goal.position = _goal_point + Vector3(0, 1.25, 0)
	goal.collision_layer = 0
	goal.collision_mask = 1
	var goal_collision := CollisionShape3D.new()
	var goal_shape := BoxShape3D.new()
	goal_shape.size = Vector3(4.2, 2.8, 4.2)
	goal_collision.shape = goal_shape
	goal.add_child(goal_collision)
	goal.body_entered.connect(_on_goal_entered)
	goal.body_exited.connect(_on_goal_exited)
	add_child(goal)


func _build_ranger_cabin() -> void:
	var center := Vector3(-14.0, 0.0, -18.0)
	var cabin_wood := _wood_material.duplicate(true)
	cabin_wood.albedo_color = Color("7c674d")
	_add_box("CabinFloor", Vector3(6.2, 0.22, 5.3), center + Vector3(0, 0.11, 0), cabin_wood, true)
	_add_box("CabinBackWall", Vector3(6.2, 2.75, 0.24), center + Vector3(0, 1.48, -2.55), cabin_wood, true)
	_add_box("CabinLeftWall", Vector3(0.24, 2.75, 5.3), center + Vector3(-3.0, 1.48, 0), cabin_wood, true)
	_add_box("CabinRightWall", Vector3(0.24, 2.75, 5.3), center + Vector3(3.0, 1.48, 0), cabin_wood, true)
	_add_box("CabinFrontLeft", Vector3(2.2, 2.75, 0.24), center + Vector3(-2.0, 1.48, 2.55), cabin_wood, true)
	_add_box("CabinFrontRight", Vector3(2.2, 2.75, 0.24), center + Vector3(2.0, 1.48, 2.55), cabin_wood, true)
	_add_box("CabinDoorBeam", Vector3(1.85, 0.4, 0.24), center + Vector3(0, 2.55, 2.55), cabin_wood, true)

	var roof_material := _material(Color("342c26"), 0.9)
	var roof_left := _add_box("CabinRoofLeft", Vector3(3.45, 0.22, 5.9), center + Vector3(-1.45, 3.25, 0), roof_material, true)
	roof_left.rotation.z = deg_to_rad(-21.0)
	var roof_right := _add_box("CabinRoofRight", Vector3(3.45, 0.22, 5.9), center + Vector3(1.45, 3.25, 0), roof_material, true)
	roof_right.rotation.z = deg_to_rad(21.0)

	var lamp := OmniLight3D.new()
	lamp.name = "CabinWarmLight"
	lamp.position = center + Vector3(0.0, 2.05, 0.1)
	lamp.light_color = Color("ffc06a")
	lamp.light_energy = 1.35
	lamp.omni_range = 5.5
	lamp.shadow_enabled = false
	add_child(lamp)


func _build_cave_entrance() -> void:
	var cave_material := _material(Color("252a27"), 1.0)
	_add_box("CaveWallLeft", Vector3(7.0, 5.5, 4.0), Vector3(-5.3, 2.35, -32.3), cave_material, true)
	_add_box("CaveWallRight", Vector3(7.0, 5.5, 4.0), Vector3(5.3, 2.35, -32.3), cave_material, true)
	_add_box("CaveRoof", Vector3(4.0, 2.0, 4.0), Vector3(0, 4.2, -32.3), cave_material, true)


func _add_tree_multimeshes(positions: Array[Vector3], heights: Array[float]) -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.19
	trunk_mesh.bottom_radius = 0.28
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 8
	trunk_mesh.material = _wood_material
	var trunk_multi := MultiMesh.new()
	trunk_multi.transform_format = MultiMesh.TRANSFORM_3D
	trunk_multi.mesh = trunk_mesh
	trunk_multi.instance_count = positions.size()

	# Layered conifer crowns read as real forest silhouettes from the shoulder camera
	# and cost far less than instancing a million-triangle scan on mobile.
	var canopy_mesh := CylinderMesh.new()
	canopy_mesh.top_radius = 0.08
	canopy_mesh.bottom_radius = 1.05
	canopy_mesh.height = 2.7
	canopy_mesh.radial_segments = 12
	canopy_mesh.rings = 3
	canopy_mesh.material = _leaf_material
	var canopy_multi := MultiMesh.new()
	canopy_multi.transform_format = MultiMesh.TRANSFORM_3D
	canopy_multi.use_custom_data = true
	canopy_multi.mesh = canopy_mesh
	canopy_multi.instance_count = positions.size() * 3

	for index in range(positions.size()):
		var height := heights[index]
		var width := _rng.randf_range(0.82, 1.2)
		var angle := _rng.randf_range(-PI, PI)
		var rotation_basis := Basis(Vector3.UP, angle)
		var trunk_basis := rotation_basis.scaled(Vector3(width, height, width))
		trunk_multi.set_instance_transform(index, Transform3D(trunk_basis, positions[index] + Vector3.UP * height * 0.5))
		var crown_scale := Vector3(width * 1.55, height * 0.28, width * 1.55)
		var tint := Color(_rng.randf_range(0.78, 0.98), _rng.randf_range(0.9, 1.12), _rng.randf_range(0.74, 0.94), 1.0)
		var first := index * 3
		canopy_multi.set_instance_transform(first, Transform3D(rotation_basis.scaled(crown_scale), positions[index] + Vector3.UP * (height * 0.84)))
		canopy_multi.set_instance_custom_data(first, tint)
		var side_offset := rotation_basis * Vector3(width * 0.42, 0.0, width * 0.18)
		canopy_multi.set_instance_transform(first + 1, Transform3D(rotation_basis.scaled(crown_scale * Vector3(0.82, 0.78, 0.88)), positions[index] + Vector3.UP * (height * 0.66) + side_offset))
		canopy_multi.set_instance_custom_data(first + 1, tint.darkened(0.06))
		canopy_multi.set_instance_transform(first + 2, Transform3D(rotation_basis.scaled(crown_scale * Vector3(0.64, 0.66, 0.72)), positions[index] + Vector3.UP * (height * 1.03) - side_offset * 0.35))
		canopy_multi.set_instance_custom_data(first + 2, tint.lightened(0.04))

		var collider := StaticBody3D.new()
		collider.name = "TreeCollision_%02d" % index
		collider.position = positions[index] + Vector3.UP * height * 0.5
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.height = height
		shape.radius = 0.29 * width
		collision.shape = shape
		collider.add_child(collision)
		add_child(collider)

	var trunks := MultiMeshInstance3D.new()
	trunks.name = "TreeTrunks_MultiMesh"
	trunks.multimesh = trunk_multi
	trunks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(trunks)
	var canopies := MultiMeshInstance3D.new()
	canopies.name = "TreeCanopies_MultiMesh"
	canopies.multimesh = canopy_multi
	canopies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(canopies)


func _add_grass_multimesh() -> void:
	var grass_material := _moving_material("res://assets/environments/foliage_wind.gdshader", "base_color", Color("4f773d"), 0.13)
	var grass_mesh := BoxMesh.new()
	grass_mesh.size = Vector3(0.035, 0.62, 0.17)
	grass_mesh.material = grass_material
	var grass_multi := MultiMesh.new()
	grass_multi.transform_format = MultiMesh.TRANSFORM_3D
	grass_multi.use_custom_data = true
	grass_multi.mesh = grass_mesh
	grass_multi.instance_count = 320
	for index in range(grass_multi.instance_count):
		var grass_position := Vector3(_rng.randf_range(-21.5, 21.5), 0.27, _rng.randf_range(-33.0, 25.0))
		if absf(grass_position.x) < 3.0 or absf(grass_position.z) < 3.3:
			grass_position.x += 4.0 if grass_position.x >= 0.0 else -4.0
		var scale_value := _rng.randf_range(0.55, 1.35)
		var grass_basis := Basis(Vector3.UP, _rng.randf_range(-PI, PI)).scaled(Vector3(scale_value, scale_value, scale_value))
		grass_multi.set_instance_transform(index, Transform3D(grass_basis, grass_position))
		grass_multi.set_instance_custom_data(index, Color(_rng.randf_range(0.76, 0.94), _rng.randf_range(0.92, 1.1), _rng.randf_range(0.68, 0.86), 1.0))
	var grass := MultiMeshInstance3D.new()
	grass.name = "Grass_MultiMesh"
	grass.multimesh = grass_multi
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass)


func _add_leaf_card_multimesh(positions: Array[Vector3], heights: Array[float]) -> void:
	var leaf_material := StandardMaterial3D.new()
	leaf_material.albedo_color = Color("b7c79a")
	leaf_material.albedo_texture = load("res://assets/environments/pbr/Leaf001/Leaf001.png")
	leaf_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	leaf_material.alpha_scissor_threshold = 0.32
	leaf_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	leaf_material.roughness = 0.92
	leaf_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	var leaf_quad := QuadMesh.new()
	leaf_quad.size = Vector2(0.62, 0.72)
	leaf_quad.material = leaf_material
	var leaves_per_tree := 24
	var leaves := MultiMesh.new()
	leaves.transform_format = MultiMesh.TRANSFORM_3D
	leaves.use_custom_data = true
	leaves.mesh = leaf_quad
	leaves.instance_count = positions.size() * leaves_per_tree
	for tree_index in range(positions.size()):
		var tree_height := heights[tree_index]
		var tree_width := clampf(tree_height * 0.21, 1.0, 1.85)
		for leaf_index in range(leaves_per_tree):
			var index := tree_index * leaves_per_tree + leaf_index
			var normalized_height := _rng.randf_range(0.48, 1.04)
			var crown_profile := sin(clampf((normalized_height - 0.42) / 0.68, 0.0, 1.0) * PI)
			var radius := tree_width * crown_profile * sqrt(_rng.randf())
			var angle := _rng.randf_range(-PI, PI)
			var leaf_position := positions[tree_index] + Vector3(
				cos(angle) * radius,
				tree_height * normalized_height,
				sin(angle) * radius
			)
			var facing := Basis(Vector3.UP, angle + PI * 0.5)
			facing = facing.rotated(facing.x, _rng.randf_range(-0.42, 0.42))
			facing = facing.scaled(Vector3.ONE * _rng.randf_range(0.65, 1.25))
			leaves.set_instance_transform(index, Transform3D(facing, leaf_position))
			leaves.set_instance_custom_data(index, Color(_rng.randf_range(0.72, 1.0), _rng.randf_range(0.84, 1.08), _rng.randf_range(0.68, 0.92), 1.0))
	var leaf_instances := MultiMeshInstance3D.new()
	leaf_instances.name = "LeafCards_MultiMesh"
	leaf_instances.multimesh = leaves
	leaf_instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(leaf_instances)


func _add_rock(position: Vector3, rock_scale: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = position
	body.scale = rock_scale
	body.rotation_degrees.y = _rng.randf_range(0.0, 180.0)
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.68
	mesh.height = 1.15
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = _rock_material
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.62
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _add_bounds() -> void:
	var invisible := StandardMaterial3D.new()
	invisible.albedo_color = Color(0.1, 0.2, 0.1, 0.0)
	_add_box("BoundLeft", Vector3(1, 5, 60), Vector3(-23, 2, -4), invisible, true, false)
	_add_box("BoundRight", Vector3(1, 5, 60), Vector3(23, 2, -4), invisible, true, false)
	_add_box("BoundNorth", Vector3(46, 5, 1), Vector3(0, 2, 26), invisible, true, false)
	_add_box("BoundSouth", Vector3(46, 5, 1), Vector3(0, 2, -35), invisible, true, false)


func _add_box(name_text: String, box_size: Vector3, location: Vector3, material: Material, collision_enabled: bool, visible_mesh: bool = true) -> Node3D:
	var parent: Node3D
	if collision_enabled:
		parent = StaticBody3D.new()
	else:
		parent = Node3D.new()
	parent.name = name_text
	parent.position = location
	if visible_mesh:
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = box_size
		mesh.material = material
		mesh_instance.mesh = mesh
		parent.add_child(mesh_instance)
	if collision_enabled:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box_size
		collision.shape = shape
		parent.add_child(collision)
	add_child(parent)
	return parent


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _pbr_material(albedo_path: String, normal_path: String, roughness_path: String, ao_path: String, tint: Color, uv_scale: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.albedo_texture = load(albedo_path)
	material.normal_enabled = true
	material.normal_texture = load(normal_path)
	material.normal_scale = 0.82
	material.roughness = 0.92
	material.roughness_texture = load(roughness_path)
	material.ao_enabled = true
	material.ao_texture = load(ao_path)
	material.ao_light_affect = 0.72
	material.uv1_scale = Vector3.ONE * uv_scale
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


func _build_ambient_motion() -> void:
	var dust_material := StandardMaterial3D.new()
	dust_material.albedo_color = Color(1.0, 0.78, 0.3, 0.72)
	dust_material.emission_enabled = true
	dust_material.emission = Color(0.55, 0.27, 0.05)
	dust_material.emission_energy_multiplier = 1.8
	dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mote_mesh := SphereMesh.new()
	mote_mesh.radius = 0.018
	mote_mesh.height = 0.036
	mote_mesh.radial_segments = 6
	mote_mesh.rings = 3
	mote_mesh.material = dust_material

	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(18.0, 2.8, 25.0)
	process_material.direction = Vector3(0.25, 0.25, -0.1)
	process_material.spread = 180.0
	process_material.initial_velocity_min = 0.05
	process_material.initial_velocity_max = 0.18
	process_material.gravity = Vector3(0.0, 0.015, 0.0)
	process_material.scale_min = 0.45
	process_material.scale_max = 1.35

	var particles := GPUParticles3D.new()
	particles.name = "ForestMotes"
	particles.position = Vector3(0.0, 2.4, -4.0)
	particles.amount = 42
	particles.lifetime = 7.0
	particles.randomness = 0.85
	particles.fixed_fps = 20
	particles.visibility_aabb = AABB(Vector3(-23, -4, -34), Vector3(46, 9, 62))
	particles.process_material = process_material
	particles.draw_pass_1 = mote_mesh
	add_child(particles)


func _moving_material(shader_path: String, color_parameter: StringName, color: Color, strength: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(shader_path)
	material.set_shader_parameter(color_parameter, color)
	material.set_shader_parameter("wind_strength", strength)
	return material


func _on_piece_collected(_item: Area3D) -> void:
	_pieces_collected += 1
	hud.set_mission_items(_mission_item_name(), _pieces_collected, _required_pieces)
	if _pieces_collected >= _required_pieces:
		hud.set_objective(_next_locked_objective())
		hud.show_toast("اكتملت مجموعة %s — انتقل إلى الهدف التالي" % _mission_item_name(), 3.2)
	else:
		hud.show_toast("وجدت عنصر مهمة — تبقى %d" % (_required_pieces - _pieces_collected))


func _on_goal_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_near_goal = true
	var blocker := _completion_blocker()
	if blocker.is_empty():
		hud.show_toast("اضغط تفاعل لتنفيذ: %s" % _goal_action(), 3.0)
	else:
		hud.show_toast(blocker, 3.0)


func _on_goal_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_near_goal = false


func _try_finish() -> void:
	if _completed:
		return
	var blocker := _completion_blocker()
	if not blocker.is_empty():
		hud.show_toast(blocker)
		return
	_completed = true
	player.set_controls_enabled(false)
	GameState.unlocked_level = maxi(GameState.unlocked_level, mini(MAX_STAGES, stage_number + 1))
	var reward := GameState.grant_stage_reward(stage_number, _stage_reward())
	var elapsed := GameState.finish_run(_elapsed_seconds)
	GameState.save_progress()
	hud.show_success(elapsed, GameState.best_time_seconds, stage_number, reward)


func _on_lion_died(lion: CharacterBody3D) -> void:
	if lion.get_meta(&"stage_boss", false):
		_boss_defeated = true
		hud.show_toast("سقط زعيم المرحلة — فُتح الطريق إلى المعلم الأخير", 3.2)
	_lions_remaining = maxi(0, _lions_remaining - 1)
	hud.set_lions(_lions_remaining)
	if _lions_remaining == 0:
		hud.set_objective(_next_locked_objective())
		if _pieces_collected >= _required_pieces and _adventure_event_completed:
			hud.show_toast("اكتملت المواجهة — اتجه إلى %s" % _destination_name(), 3.0)
		else:
			hud.show_toast("اكتملت المواجهة — تابع أهداف الاستكشاف", 2.4)
	else:
		hud.show_toast("تمت هزيمة أسد — المتبقي %d" % _lions_remaining)


func _on_lion_attacked(damage: int) -> void:
	hud.show_toast("هاجمك الأسد: -%d صحة" % damage, 0.8)


func _on_player_died() -> void:
	if _completed or _player_defeated:
		return
	_player_defeated = true
	hud.show_failure("أسقطتك الأسود في المرحلة %d." % stage_number)


func _completion_blocker() -> String:
	if _pieces_collected < _required_pieces:
		return "الهدف مقفل — اجمع %d من %s" % [_required_pieces - _pieces_collected, _mission_item_name()]
	if not _adventure_event_completed:
		return "الهدف مقفل — أكمل حدث الاستكشاف: %s" % _initial_objective()
	if stage_number in [3, 5] and not _boss_defeated:
		return "الهدف مقفل — اهزم زعيم المرحلة أولًا"
	if _lions_remaining > 0:
		return "الهدف مقفل — بقي %d من حراس القطيع" % _lions_remaining
	return ""


func _next_locked_objective() -> String:
	if _pieces_collected < _required_pieces:
		return "اجمع %s (%d/%d)" % [_mission_item_name(), _pieces_collected, _required_pieces]
	if not _adventure_event_completed:
		return _initial_objective()
	if stage_number in [3, 5] and not _boss_defeated:
		return "اهزم زعيم المرحلة الذي يحرس %s" % _destination_name()
	if _lions_remaining > 0:
		return "اهزم حراس القطيع المتبقين: %d" % _lions_remaining
	return "اتجه إلى %s واضغط تفاعل" % _destination_name()


func _required_item_count() -> int:
	return [3, 4, 3, 4, 5][stage_number - 1]


func _mission_item_name() -> String:
	return ["أجزاء الخريطة", "معدات الجسر", "مصابيح الكهف", "مفاتيح القلعة", "حقائب الإسعاف"][stage_number - 1]


func _destination_name() -> String:
	return ["كوخ الحارس", "برج المراقبة", "قلب الكهف", "بوابة القلعة", "حصن الوادي"][stage_number - 1]


func _goal_action() -> String:
	return ["إرسال إشارة الإنقاذ", "تشغيل منارة البرج", "فتح صندوق الكهف", "فتح بوابة القلعة", "تحرير المستكشف وتشغيل جهاز الاتصال"][stage_number - 1]


func _stage_reward() -> int:
	return [250, 450, 700, 1000, 1500][stage_number - 1]


func _stage_title() -> String:
	match stage_number:
		1:
			return "المرحلة 1 — أثر الأسود"
		2:
			return "المرحلة 2 — كمين النهر"
		3:
			return "المرحلة 3 — عرين الأسد"
		4:
			return "المرحلة 4 — القلعة المهدمة"
		_:
			return "المرحلة 5 — نداء الإنقاذ"


func _stage_intro() -> String:
	match stage_number:
		1:
			return "اجمع القطع وواجه أسدين قبل الوصول إلى النجاة"
		2:
			return "اجمع معدات الجسر، اعبر النهر وشغّل منارة البرج"
		3:
			return "اجمع مصابيح الكهف واهزم الأسد القائد داخل العرين"
		4:
			return "اعثر على مفاتيح القلعة وافتح البوابة المحاصرة"
		_:
			return "أنقذ المستكشف وشغّل الاتصال بعد هزيمة الزعيم الأخير"


func _pause_game() -> void:
	if _completed or _player_defeated:
		return
	get_tree().paused = true
	hud.show_pause(true)
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _resume_game() -> void:
	get_tree().paused = false
	hud.show_pause(false)
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _retry_level() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _load_next_stage() -> void:
	get_tree().paused = false
	GameState.selected_level = mini(MAX_STAGES, stage_number + 1)
	get_tree().change_scene_to_file(GameState.get_level_scene())


func _return_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
