extends CharacterBody3D

signal camera_moved(yaw: float, pitch: float)
signal health_changed(current: int, maximum: int)
signal died
signal shot_fired(hit_enemy: bool)
signal ammo_changed(current: int, reserve: int, magazine: int)
signal reload_started(duration: float)
signal water_state_changed(in_water: bool)
signal aim_state_changed(active: bool, target_locked: bool)

@export var walk_speed := 4.2
@export var run_speed := 7.2
@export var acceleration := 18.0
@export var deceleration := 24.0
@export var jump_velocity := 8.2
@export var turn_speed := 10.0
@export var coyote_time := 0.13
@export var jump_buffer_time := 0.14
@export var max_health := 100
@export var weapon_damage := 34
@export var magazine_size := 18
@export var reserve_ammo := 72
@export var reload_duration := 1.45
@export var camera_pitch_min := -34.0
@export var camera_pitch_max := 14.0
@export var camera_distance := 4.05
@export var aim_camera_distance := 0.08
@export var shoulder_offset := 0.52
@export var scope_fov := 24.0
@export var aim_assist_degrees := 11.5

@onready var visual: Node3D = $Visual
@onready var human_model: Node3D = $Visual/HumanModel
@onready var left_arm: Node3D = $Visual/LeftArm
@onready var right_arm: Node3D = $Visual/RightArm
@onready var left_leg: Node3D = $Visual/LeftLeg
@onready var right_leg: Node3D = $Visual/RightLeg
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var weapon: Node3D = $Visual/Weapon
@onready var muzzle_flash: OmniLight3D = $Visual/Weapon/MuzzleFlash

var _target_camera_yaw := 0.0
var _target_camera_pitch := deg_to_rad(-10.0)
var _current_camera_yaw := 0.0
var _current_camera_pitch := deg_to_rad(-10.0)
var _motion_clock := 0.0
var _visual_base_y := 0.0
var _controls_enabled := true
var _health := 100
var _shot_cooldown := 0.0
var _damage_cooldown := 0.0
var _coyote_remaining := 0.0
var _jump_buffer_remaining := 0.0
var _ammo := 18
var _reserve := 72
var _reload_remaining := 0.0
var _animation_player: AnimationPlayer
var _animation_tree: AnimationTree
var _character_skeleton: Skeleton3D
var _weapon_rest_rotation := Vector3.ZERO
var _in_water := false
var _water_splash: GPUParticles3D
var _aiming_last := false
var _aim_locked_last := false
var _aim_assist_refresh := 0.0
var _current_aim_target: Node3D


func _ready() -> void:
	add_to_group("player")
	_visual_base_y = visual.position.y
	_ammo = magazine_size
	_reserve = reserve_ammo
	_setup_character_rig()
	_build_water_splash()
	_current_camera_yaw = _target_camera_yaw
	_current_camera_pitch = _target_camera_pitch
	camera_pivot.rotation.y = _current_camera_yaw
	spring_arm.rotation.x = _current_camera_pitch
	spring_arm.spring_length = camera_distance
	camera.position = Vector3(shoulder_offset, 0.08, 0.0)
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_health = max_health
	health_changed.emit(_health, max_health)
	ammo_changed.emit(_ammo, _reserve, magazine_size)


func _process(delta: float) -> void:
	_update_camera(delta)
	_update_aim(delta)


func _physics_process(delta: float) -> void:
	_shot_cooldown = maxf(0.0, _shot_cooldown - delta)
	_damage_cooldown = maxf(0.0, _damage_cooldown - delta)
	if _reload_remaining > 0.0:
		_reload_remaining = maxf(0.0, _reload_remaining - delta)
		if _reload_remaining <= 0.0:
			_finish_reload()
	_jump_buffer_remaining = maxf(0.0, _jump_buffer_remaining - delta)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_remaining = jump_buffer_time
	if is_on_floor():
		_coyote_remaining = coyote_time
	else:
		_coyote_remaining = maxf(0.0, _coyote_remaining - delta)
	if not _controls_enabled:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		_animate_body(delta, 0.0, false)
		return
	if Input.is_action_just_pressed("fire"):
		_shoot()
	if Input.is_action_just_pressed("reload"):
		_start_reload()

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var input_strength := clampf(input_vector.length(), 0.0, 1.0)
	var camera_basis := Basis(Vector3.UP, _current_camera_yaw)
	var direction := camera_basis * Vector3(input_vector.x, 0.0, input_vector.y)
	if direction.length_squared() > 0.001:
		direction = direction.normalized()

	var target_speed := _speed_for_input(input_strength, Input.is_action_pressed("sprint"))
	if _in_water:
		target_speed *= 0.56
	var running := target_speed > walk_speed * 1.08
	var target_velocity := direction * target_speed
	var rate := acceleration if direction.length_squared() > 0.001 else deceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)

	if not is_on_floor():
		velocity += get_gravity() * delta * (0.38 if _in_water else 1.0)
	if _jump_buffer_remaining > 0.0 and _coyote_remaining > 0.0:
		velocity.y = jump_velocity * (0.68 if _in_water else 1.0)
		_jump_buffer_remaining = 0.0
		_coyote_remaining = 0.0

	if Input.is_action_pressed("aim"):
		visual.rotation.y = lerp_angle(visual.rotation.y, _current_camera_yaw, minf(1.0, turn_speed * 0.72 * delta))
	elif direction.length_squared() > 0.001:
		var target_angle := atan2(-direction.x, -direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_angle, minf(1.0, turn_speed * delta))

	move_and_slide()
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if _water_splash:
		_water_splash.emitting = _in_water and horizontal_speed > 0.45
	_animate_body(delta, horizontal_speed / run_speed, running)


func set_in_water(in_water: bool) -> void:
	if _in_water == in_water:
		return
	_in_water = in_water
	water_state_changed.emit(_in_water)
	if _water_splash:
		_water_splash.restart()
		_water_splash.emitting = _in_water


func is_in_water() -> bool:
	return _in_water


func _build_water_splash() -> void:
	var splash_material := StandardMaterial3D.new()
	splash_material.albedo_color = Color(0.62, 0.88, 0.92, 0.72)
	splash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	splash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var droplet := SphereMesh.new()
	droplet.radius = 0.025
	droplet.height = 0.05
	droplet.radial_segments = 5
	droplet.rings = 3
	droplet.material = splash_material
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.42, 0.04, 0.55)
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 58.0
	process.initial_velocity_min = 0.7
	process.initial_velocity_max = 1.7
	process.gravity = Vector3(0.0, -3.8, 0.0)
	process.scale_min = 0.5
	process.scale_max = 1.35
	_water_splash = GPUParticles3D.new()
	_water_splash.name = "WaterFootSplashes"
	_water_splash.position = Vector3(0.0, 0.16, 0.0)
	_water_splash.amount = 18
	_water_splash.lifetime = 0.55
	_water_splash.randomness = 0.72
	_water_splash.explosiveness = 0.18
	_water_splash.emitting = false
	_water_splash.process_material = process
	_water_splash.draw_pass_1 = droplet
	add_child(_water_splash)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_camera(event.relative)
	elif event is InputEventMouseButton and event.pressed and not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func rotate_camera(relative: Vector2) -> void:
	if not _controls_enabled:
		return
	var sensitivity := GameState.camera_sensitivity * 0.01
	if Input.is_action_pressed("aim"):
		sensitivity *= 0.42
	var vertical_sign := -1.0 if GameState.invert_camera_y else 1.0
	_target_camera_yaw -= relative.x * sensitivity
	_target_camera_pitch = clampf(
		_target_camera_pitch - relative.y * sensitivity * vertical_sign,
		deg_to_rad(camera_pitch_min),
		deg_to_rad(camera_pitch_max)
	)


func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	if not enabled:
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_release("move_forward")
		Input.action_release("move_back")
		Input.action_release("sprint")
		Input.action_release("fire")
		Input.action_release("aim")
		Input.action_release("reload")


func take_damage(amount: int) -> void:
	if _damage_cooldown > 0.0 or _health <= 0:
		return
	_damage_cooldown = 0.5
	_health = maxi(0, _health - amount)
	health_changed.emit(_health, max_health)
	var original_scale := visual.scale
	var tween := create_tween()
	tween.tween_property(visual, "scale", original_scale * Vector3(1.08, 0.9, 1.08), 0.07)
	tween.tween_property(visual, "scale", original_scale, 0.12)
	if _health <= 0:
		set_controls_enabled(false)
		died.emit()


func restore_health() -> void:
	_health = max_health
	health_changed.emit(_health, max_health)


func _shoot() -> void:
	if _shot_cooldown > 0.0 or _reload_remaining > 0.0 or not _controls_enabled:
		return
	if _ammo <= 0:
		_start_reload()
		return
	_ammo -= 1
	ammo_changed.emit(_ammo, _reserve, magazine_size)
	_shot_cooldown = 0.22
	var origin := camera.global_position
	var direction := _assisted_shot_direction(origin, -camera.global_basis.z)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 55.0, 5, [get_rid()])
	query.collide_with_areas = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	var hit_enemy := false
	if not result.is_empty():
		var collider: Object = result.get("collider")
		if collider and collider.has_method("take_damage"):
			collider.call("take_damage", weapon_damage, result.get("position", Vector3.ZERO))
			hit_enemy = true
			if OS.has_feature("mobile"):
				Input.vibrate_handheld(32)
	shot_fired.emit(hit_enemy)
	muzzle_flash.visible = true
	if _animation_tree:
		_animation_tree.set("parameters/FireShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_target_camera_pitch = clampf(
		_target_camera_pitch + deg_to_rad(0.65),
		deg_to_rad(camera_pitch_min),
		deg_to_rad(camera_pitch_max)
	)
	weapon.rotation.x = _weapon_rest_rotation.x - deg_to_rad(5.0)
	var tween := create_tween()
	tween.tween_property(weapon, "rotation", _weapon_rest_rotation, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(0.055).timeout.connect(func():
		if is_instance_valid(muzzle_flash):
			muzzle_flash.visible = false
	)


func _update_aim(delta: float) -> void:
	var aiming := Input.is_action_pressed("aim") and _controls_enabled
	# A scope must look from the player's eye line, not from a close shoulder
	# camera.  The full character is hidden locally while scoped so neither the
	# head nor the backpack can cover the lion.  It is restored as soon as the
	# player explicitly toggles the scope off.
	visual.visible = not aiming
	var target_length := aim_camera_distance if aiming else camera_distance
	var target_fov := scope_fov if aiming else 68.0
	var target_shoulder := 0.0 if aiming else shoulder_offset
	var zoom_weight := minf(1.0, delta * 14.0)
	spring_arm.spring_length = lerpf(spring_arm.spring_length, target_length, zoom_weight)
	camera.fov = lerpf(camera.fov, target_fov, zoom_weight)
	camera.position.x = lerpf(camera.position.x, target_shoulder, zoom_weight)
	_aim_assist_refresh -= delta
	if aiming and (_aim_assist_refresh <= 0.0 or not is_instance_valid(_current_aim_target)):
		_aim_assist_refresh = 0.12
		_current_aim_target = _find_aim_target(aim_assist_degrees)
	elif not aiming:
		_current_aim_target = null
	var target_locked := aiming and is_instance_valid(_current_aim_target)
	if aiming != _aiming_last or target_locked != _aim_locked_last:
		_aiming_last = aiming
		_aim_locked_last = target_locked
		aim_state_changed.emit(aiming, target_locked)


func _assisted_shot_direction(origin: Vector3, camera_direction: Vector3) -> Vector3:
	if not Input.is_action_pressed("aim"):
		return camera_direction.normalized()
	var target := _current_aim_target
	if not is_instance_valid(target):
		target = _find_aim_target(aim_assist_degrees)
	if is_instance_valid(target):
		return (target.global_position + Vector3.UP * 0.72 - origin).normalized()
	return camera_direction.normalized()


func _find_aim_target(max_degrees: float) -> Node3D:
	if not camera or not is_inside_tree():
		return null
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	var minimum_dot := cos(deg_to_rad(max_degrees))
	var best_score := minimum_dot
	var best_target: Node3D
	for candidate_node in get_tree().get_nodes_in_group("lion_enemy"):
		var candidate := candidate_node as Node3D
		if not is_instance_valid(candidate):
			continue
		var target_position := candidate.global_position + Vector3.UP * 0.72
		var offset := target_position - origin
		var distance := offset.length()
		if distance < 0.4 or distance > 55.0:
			continue
		var dot := forward.dot(offset / distance)
		if dot < minimum_dot:
			continue
		var query := PhysicsRayQueryParameters3D.create(origin, target_position, 5, [get_rid()])
		query.collide_with_areas = false
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.get("collider") != candidate:
			continue
		var score := dot - distance * 0.00035
		if score > best_score:
			best_score = score
			best_target = candidate
	return best_target


func get_aim_target() -> Node3D:
	return _current_aim_target


func _update_camera(delta: float) -> void:
	var smoothing := maxf(1.0, GameState.camera_smoothing)
	var weight := 1.0 - exp(-smoothing * delta)
	_current_camera_yaw = lerp_angle(_current_camera_yaw, _target_camera_yaw, weight)
	_current_camera_pitch = lerp_angle(_current_camera_pitch, _target_camera_pitch, weight)
	camera_pivot.rotation.y = _current_camera_yaw
	spring_arm.rotation.x = _current_camera_pitch
	camera_moved.emit(_current_camera_yaw, _current_camera_pitch)


func _speed_for_input(input_strength: float, sprinting: bool) -> float:
	if input_strength <= 0.001:
		return 0.0
	var curved := pow(input_strength, 1.12)
	var normal_speed: float
	if curved <= 0.68:
		normal_speed = lerpf(0.0, walk_speed, curved / 0.68)
	else:
		normal_speed = lerpf(walk_speed, run_speed * 0.84, (curved - 0.68) / 0.32)
	if sprinting and curved > 0.28:
		normal_speed = lerpf(normal_speed, run_speed, (curved - 0.28) / 0.72)
	return normal_speed


func get_camera_angles() -> Vector2:
	return Vector2(_current_camera_yaw, _current_camera_pitch)


func get_target_camera_angles() -> Vector2:
	return Vector2(_target_camera_yaw, _target_camera_pitch)


func _animate_body(delta: float, speed_ratio: float, running: bool) -> void:
	var grounded := is_on_floor()
	if _animation_tree:
		var locomotion := clampf(speed_ratio, 0.0, 1.0) if grounded else 0.12
		_animation_tree.set("parameters/Locomotion/blend_position", locomotion)
		_animation_tree.set("parameters/AimBlend/blend_amount", 1.0 if Input.is_action_pressed("aim") else 0.0)
		visual.position.y = _visual_base_y
		return
	if grounded and speed_ratio > 0.03:
		_motion_clock += delta * (10.5 if running else 7.0)
		var swing := sin(_motion_clock) * (0.78 if running else 0.48)
		left_arm.rotation.x = swing
		right_arm.rotation.x = -swing
		left_leg.rotation.x = -swing * 0.82
		right_leg.rotation.x = swing * 0.82
		visual.position.y = _visual_base_y + absf(sin(_motion_clock * 2.0)) * 0.035
	elif not grounded:
		left_arm.rotation.x = lerpf(left_arm.rotation.x, -0.3, minf(1.0, delta * 7.0))
		right_arm.rotation.x = lerpf(right_arm.rotation.x, -0.3, minf(1.0, delta * 7.0))
		left_leg.rotation.x = lerpf(left_leg.rotation.x, 0.18, minf(1.0, delta * 7.0))
		right_leg.rotation.x = lerpf(right_leg.rotation.x, -0.18, minf(1.0, delta * 7.0))
	else:
		_motion_clock += delta * 1.8
		left_arm.rotation.x = lerpf(left_arm.rotation.x, 0.0, minf(1.0, delta * 8.0))
		right_arm.rotation.x = lerpf(right_arm.rotation.x, 0.0, minf(1.0, delta * 8.0))
		left_leg.rotation.x = lerpf(left_leg.rotation.x, 0.0, minf(1.0, delta * 8.0))
		right_leg.rotation.x = lerpf(right_leg.rotation.x, 0.0, minf(1.0, delta * 8.0))
		visual.position.y = _visual_base_y + sin(_motion_clock) * 0.012


func _start_reload() -> void:
	if not _controls_enabled or _reload_remaining > 0.0 or _ammo >= magazine_size or _reserve <= 0:
		return
	_reload_remaining = reload_duration
	reload_started.emit(reload_duration)
	if _animation_tree:
		_animation_tree.set("parameters/ReloadShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _finish_reload() -> void:
	var needed := magazine_size - _ammo
	var amount := mini(needed, _reserve)
	_ammo += amount
	_reserve -= amount
	ammo_changed.emit(_ammo, _reserve, magazine_size)


func get_ammo_state() -> Vector3i:
	return Vector3i(_ammo, _reserve, magazine_size)


func _setup_character_rig() -> void:
	_character_skeleton = _find_skeleton(human_model)
	var embedded_player := _find_animation_player(human_model)
	var uses_embedded_soldier := embedded_player != null and embedded_player.has_animation(&"CharacterArmature|Idle")
	if _character_skeleton:
		if uses_embedded_soldier:
			_setup_embedded_soldier_weapon()
		else:
			_apply_ranger_clothing(human_model)
			_build_tactical_gear()
		var weapon_socket := BoneAttachment3D.new()
		if not uses_embedded_soldier:
			weapon_socket.name = "WeaponSocket"
			weapon_socket.bone_name = "RightHand"
			_character_skeleton.add_child(weapon_socket)
			weapon.reparent(weapon_socket, false)
			weapon.position = Vector3(0.015, 0.115, -0.035)
			weapon.rotation_degrees = Vector3(88.0, 4.0, 92.0)
			weapon.scale = Vector3.ONE * 0.68
			_weapon_rest_rotation = weapon.rotation

	if uses_embedded_soldier:
		_animation_player = embedded_player
		_setup_embedded_soldier_animation_tree()
		return

	_animation_player = AnimationPlayer.new()
	_animation_player.name = "CharacterAnimationPlayer"
	human_model.add_child(_animation_player)
	_animation_player.root_node = NodePath("..")
	var library := AnimationLibrary.new()
	var animation_paths := {
		"Idle": "res://addons/quaternius_ik_rigged/Animations/Idle.res",
		"Walk": "res://addons/quaternius_ik_rigged/Animations/Walk.res",
		"Jog": "res://addons/quaternius_ik_rigged/Animations/Jog_Fwd.res",
		"Sprint": "res://addons/quaternius_ik_rigged/Animations/Sprint.res",
		"Aim": "res://addons/quaternius_ik_rigged/Animations/Pistol_Idle.res",
		"Fire": "res://addons/quaternius_ik_rigged/Animations/Pistol_Shoot.res",
		"Reload": "res://addons/quaternius_ik_rigged/Animations/Pistol_Reload.res",
	}
	for animation_name in animation_paths:
		var source_animation := load(animation_paths[animation_name]) as Animation
		if source_animation:
			var animation := source_animation.duplicate(true) as Animation
			_retarget_animation_paths(animation)
			if animation_name in ["Idle", "Walk", "Jog", "Sprint", "Aim"]:
				animation.loop_mode = Animation.LOOP_LINEAR
			library.add_animation(animation_name, animation)
	_animation_player.add_animation_library("", library)

	var locomotion := AnimationNodeBlendSpace1D.new()
	locomotion.min_space = 0.0
	locomotion.max_space = 1.0
	locomotion.add_blend_point(_animation_node("Idle"), 0.0, -1, &"Idle")
	locomotion.add_blend_point(_animation_node("Walk"), 0.42, -1, &"Walk")
	locomotion.add_blend_point(_animation_node("Jog"), 0.72, -1, &"Jog")
	locomotion.add_blend_point(_animation_node("Sprint"), 1.0, -1, &"Sprint")

	var blend_tree := AnimationNodeBlendTree.new()
	blend_tree.add_node("Locomotion", locomotion, Vector2(0.0, 80.0))
	blend_tree.add_node("Aim", _animation_node("Aim"), Vector2(0.0, 220.0))
	blend_tree.add_node("AimBlend", AnimationNodeBlend2.new(), Vector2(260.0, 120.0))
	blend_tree.add_node("Fire", _animation_node("Fire"), Vector2(260.0, 280.0))
	var fire_shot := AnimationNodeOneShot.new()
	fire_shot.fadein_time = 0.04
	fire_shot.fadeout_time = 0.08
	blend_tree.add_node("FireShot", fire_shot, Vector2(500.0, 160.0))
	blend_tree.add_node("Reload", _animation_node("Reload"), Vector2(500.0, 320.0))
	var reload_shot := AnimationNodeOneShot.new()
	reload_shot.fadein_time = 0.08
	reload_shot.fadeout_time = 0.12
	blend_tree.add_node("ReloadShot", reload_shot, Vector2(730.0, 170.0))
	blend_tree.connect_node("AimBlend", 0, "Locomotion")
	blend_tree.connect_node("AimBlend", 1, "Aim")
	blend_tree.connect_node("FireShot", 0, "AimBlend")
	blend_tree.connect_node("FireShot", 1, "Fire")
	blend_tree.connect_node("ReloadShot", 0, "FireShot")
	blend_tree.connect_node("ReloadShot", 1, "Reload")
	blend_tree.connect_node("output", 0, "ReloadShot")

	_animation_tree = AnimationTree.new()
	_animation_tree.name = "AnimationTree"
	human_model.add_child(_animation_tree)
	_animation_tree.anim_player = NodePath("../CharacterAnimationPlayer")
	_animation_tree.tree_root = blend_tree
	_animation_tree.active = true
	_animation_tree.set("parameters/Locomotion/blend_position", 0.0)


func _setup_embedded_soldier_weapon() -> void:
	var attachment := _find_node_named(_character_skeleton, &"Index1_R") as BoneAttachment3D
	if not attachment:
		return
	for child in attachment.get_children():
		if child is MeshInstance3D:
			child.visible = child.name == &"AK"
	weapon.visible = false
	muzzle_flash.reparent(attachment, false)
	muzzle_flash.position = Vector3(-0.0034, 0.00155, -0.0012)


func _setup_embedded_soldier_animation_tree() -> void:
	var locomotion := AnimationNodeBlendSpace1D.new()
	locomotion.min_space = 0.0
	locomotion.max_space = 1.0
	locomotion.add_blend_point(_animation_node(&"CharacterArmature|Idle"), 0.0, -1, &"Idle")
	locomotion.add_blend_point(_animation_node(&"CharacterArmature|Run"), 0.48, -1, &"Run")
	locomotion.add_blend_point(_animation_node(&"CharacterArmature|Run_Gun"), 1.0, -1, &"Sprint")
	var blend_tree := AnimationNodeBlendTree.new()
	blend_tree.add_node("Locomotion", locomotion, Vector2(0.0, 80.0))
	blend_tree.add_node("Aim", _animation_node(&"CharacterArmature|Idle_Shoot"), Vector2(0.0, 220.0))
	blend_tree.add_node("AimBlend", AnimationNodeBlend2.new(), Vector2(260.0, 120.0))
	blend_tree.add_node("Fire", _animation_node(&"CharacterArmature|Idle_Shoot"), Vector2(260.0, 280.0))
	var fire_shot := AnimationNodeOneShot.new()
	fire_shot.fadein_time = 0.035
	fire_shot.fadeout_time = 0.08
	blend_tree.add_node("FireShot", fire_shot, Vector2(500.0, 160.0))
	blend_tree.add_node("Reload", _animation_node(&"CharacterArmature|Duck"), Vector2(500.0, 320.0))
	var reload_shot := AnimationNodeOneShot.new()
	reload_shot.fadein_time = 0.08
	reload_shot.fadeout_time = 0.12
	blend_tree.add_node("ReloadShot", reload_shot, Vector2(730.0, 170.0))
	blend_tree.connect_node("AimBlend", 0, "Locomotion")
	blend_tree.connect_node("AimBlend", 1, "Aim")
	blend_tree.connect_node("FireShot", 0, "AimBlend")
	blend_tree.connect_node("FireShot", 1, "Fire")
	blend_tree.connect_node("ReloadShot", 0, "FireShot")
	blend_tree.connect_node("ReloadShot", 1, "Reload")
	blend_tree.connect_node("output", 0, "ReloadShot")
	_animation_tree = AnimationTree.new()
	_animation_tree.name = "AnimationTree"
	human_model.add_child(_animation_tree)
	_animation_tree.anim_player = NodePath("../AnimationPlayer")
	_animation_tree.tree_root = blend_tree
	_animation_tree.active = true
	_animation_tree.set("parameters/Locomotion/blend_position", 0.0)


func _build_tactical_gear() -> void:
	# The imported base mesh supplies realistic anatomy and skinning. These lightweight
	# bone-mounted pieces turn it into a clothed ranger while keeping every part animated.
	var cloth := _gear_material(Color("405646"), 0.9)
	var webbing := _gear_material(Color("6e664c"), 0.96)
	var leather := _gear_material(Color("504438"), 0.88)
	var metal := _gear_material(Color("39403d"), 0.38, 0.48)

	var chest_socket := _bone_socket("UpperChest", "TacticalVestSocket")
	if chest_socket:
		_add_gear_box(chest_socket, "CanvasBackpack", Vector3(0.36, 0.43, 0.16), Vector3(0.0, -0.2, 0.19), webbing)
		_add_gear_box(chest_socket, "LeftShoulderStrap", Vector3(0.07, 0.48, 0.035), Vector3(-0.18, -0.19, -0.16), leather)
		_add_gear_box(chest_socket, "RightShoulderStrap", Vector3(0.07, 0.48, 0.035), Vector3(0.18, -0.19, -0.16), leather)

	var head_socket := _bone_socket("Head", "HairSocket")
	if head_socket:
		if not _add_rigged_hair(head_socket):
			var hair := _gear_material(Color("17130f"), 0.94)
			var hair_mesh := _add_gear_capsule(head_socket, "ShortHair", Vector3(0.29, 0.2, 0.27), Vector3(0.0, 0.08, 0.015), hair)
			hair_mesh.scale.y = 0.72

	var spine_socket := _bone_socket("Spine", "BeltSocket")
	if spine_socket:
		_add_gear_box(spine_socket, "UtilityBelt", Vector3(0.67, 0.13, 0.28), Vector3(0.0, 0.02, 0.0), leather)
		_add_gear_box(spine_socket, "BeltBuckle", Vector3(0.12, 0.11, 0.055), Vector3(0.0, 0.0, -0.17), metal)


func _add_rigged_hair(head_socket: BoneAttachment3D) -> bool:
	var packed := load("res://assets/models/characters/quaternius_hair_cc0/origin/Hair_SimpleParted.gltf") as PackedScene
	if not packed or not _character_skeleton:
		return false
	var prototype := packed.instantiate()
	var source := _find_mesh_instance(prototype)
	var head_index := _character_skeleton.find_bone("Head")
	if not source or head_index < 0:
		prototype.free()
		return false
	var hair := MeshInstance3D.new()
	hair.name = "NaturalPartedHair"
	hair.mesh = source.mesh
	# Convert the full-character-space hairstyle into Head-bone local space.
	# The bone attachment then carries it through every locomotion/aim animation.
	hair.transform = _character_skeleton.get_bone_global_rest(head_index).affine_inverse() * source.transform
	var source_material := source.mesh.surface_get_material(0) as StandardMaterial3D
	if source_material:
		var hair_material := source_material.duplicate(true) as StandardMaterial3D
		hair_material.albedo_color = Color("3b271b")
		hair_material.roughness = 0.88
		hair.set_surface_override_material(0, hair_material)
	hair.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	head_socket.add_child(hair)
	prototype.free()
	return true


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.mesh:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found:
			return found
	return null


func _bone_socket(bone_name: StringName, socket_name: String) -> BoneAttachment3D:
	if not _character_skeleton or _character_skeleton.find_bone(bone_name) < 0:
		return null
	var socket := BoneAttachment3D.new()
	socket.name = socket_name
	socket.bone_name = bone_name
	_character_skeleton.add_child(socket)
	return socket


func _add_limb_gear(bone_name: StringName, gear_name: String, dimensions: Vector3, local_position: Vector3, material: Material) -> void:
	var socket := _bone_socket(bone_name, gear_name + "Socket")
	if socket:
		_add_gear_capsule(socket, gear_name, dimensions, local_position, material)


func _add_gear_box(parent: Node3D, gear_name: String, dimensions: Vector3, local_position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = gear_name
	mesh_instance.position = local_position
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_gear_capsule(parent: Node3D, gear_name: String, dimensions: Vector3, local_position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = gear_name
	mesh_instance.position = local_position
	var mesh := CapsuleMesh.new()
	mesh.radius = dimensions.x * 0.5
	mesh.height = dimensions.y
	mesh.radial_segments = 12
	mesh.rings = 4
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.scale.z = dimensions.z / dimensions.x
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mesh_instance)
	return mesh_instance


func _gear_material(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _apply_ranger_clothing(node: Node) -> void:
	var clothing_shader := load("res://assets/characters/ranger_clothing.gdshader") as Shader
	if not clothing_shader:
		return
	if node is MeshInstance3D and node.name == "SuperHero_Male" and node.mesh:
		for surface in range(node.mesh.get_surface_count()):
			var original := node.mesh.surface_get_material(surface) as BaseMaterial3D
			var clothing := ShaderMaterial.new()
			clothing.shader = clothing_shader
			if original and original.albedo_texture:
				clothing.set_shader_parameter("skin_texture", original.albedo_texture)
			node.set_surface_override_material(surface, clothing)
	for child in node.get_children():
		_apply_ranger_clothing(child)


func _animation_node(animation_name: StringName) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = animation_name
	return node


func _retarget_animation_paths(animation: Animation) -> void:
	if not _character_skeleton:
		return
	var skeleton_path := String(human_model.get_path_to(_character_skeleton))
	for track_index in range(animation.get_track_count()):
		var old_path := String(animation.track_get_path(track_index))
		if old_path.begins_with("%GeneralSkeleton"):
			animation.track_set_path(track_index, NodePath(old_path.replace("%GeneralSkeleton", skeleton_path)))


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


func _find_node_named(node: Node, target_name: StringName) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_node_named(child, target_name)
		if found:
			return found
	return null
