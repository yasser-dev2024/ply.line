extends CharacterBody3D

signal health_changed(current: int, maximum: int)
signal died(enemy: CharacterBody3D)
signal attacked_player(damage: int)
signal state_changed(state_name: StringName)

enum LionState {
	ROAM,
	ALERT,
	STALK,
	CHASE,
	CIRCLE,
	ATTACK_WINDUP,
	ATTACK_RECOVER,
	HURT,
	RETURN,
	DEAD,
}

@export var max_health := 100
@export var prowl_speed := 2.15
@export var stalk_speed := 1.45
@export var chase_speed := 5.0
@export var detection_range := 17.0
@export var attack_range := 2.25
@export var attack_damage := 16

@onready var visual: Node3D = $Visual
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var status_label: Label3D = $StatusLabel

var _target: CharacterBody3D
var _health := 100
var _spawn_position := Vector3.ZERO
var _patrol_target := Vector3.ZERO
var _state := LionState.ROAM
var _state_time := 0.0
var _attack_cooldown := 0.0
var _patrol_timer := 0.0
var _attack_committed := false
var _elite := false
var _motion_materials: Array[ShaderMaterial] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("lion_enemy")
	_health = max_health
	_spawn_position = global_position
	_rng.seed = int(global_position.x * 107.0 + global_position.z * 71.0 + 9001.0)
	_apply_motion_shader()
	_choose_patrol_target()
	_update_label()
	_change_state(LionState.ROAM)


func setup(target: CharacterBody3D, stage_number: int, elite: bool = false) -> void:
	_target = target
	_elite = elite
	max_health = 80 + stage_number * 20 + (80 if elite else 0)
	_health = max_health
	chase_speed = 4.5 + stage_number * 0.35 + (0.5 if elite else 0.0)
	attack_damage = 12 + stage_number * 4 + (8 if elite else 0)
	detection_range = 15.0 + stage_number * 2.0
	if elite:
		visual.scale *= 1.18
		status_label.modulate = Color("d5a960")
	_update_label()


func _physics_process(delta: float) -> void:
	if _state == LionState.DEAD:
		return
	_state_time += delta
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_patrol_timer = maxf(0.0, _patrol_timer - delta)
	if not is_on_floor():
		velocity += get_gravity() * delta

	var distance := INF
	var target_direction := Vector3.ZERO
	if is_instance_valid(_target):
		target_direction = _target.global_position - global_position
		target_direction.y = 0.0
		distance = target_direction.length()

	var desired_direction := Vector3.ZERO
	var desired_speed := 0.0
	var attack_mix := 0.0
	match _state:
		LionState.ROAM:
			if distance <= detection_range:
				_change_state(LionState.ALERT)
			elif _patrol_timer <= 0.0 or global_position.distance_to(_patrol_target) < 1.0:
				_choose_patrol_target()
			desired_direction = _direction_to(_patrol_target)
			desired_speed = prowl_speed
		LionState.ALERT:
			_face_direction(target_direction, delta, 7.0)
			if _state_time >= 0.62:
				_change_state(LionState.STALK)
		LionState.STALK:
			if distance > detection_range * 1.35:
				_change_state(LionState.RETURN)
			elif distance < 8.5 or _state_time > 2.3:
				_change_state(LionState.CHASE)
			elif is_instance_valid(_target):
				desired_direction = _direction_to(_target.global_position)
				desired_speed = stalk_speed
		LionState.CHASE:
			if distance > detection_range * 1.55:
				_change_state(LionState.RETURN)
			elif distance <= attack_range + 0.7:
				_change_state(LionState.CIRCLE if _rng.randf() < 0.48 else LionState.ATTACK_WINDUP)
			elif is_instance_valid(_target):
				desired_direction = _direction_to(_target.global_position)
				desired_speed = chase_speed
		LionState.CIRCLE:
			if not is_instance_valid(_target):
				_change_state(LionState.RETURN)
			elif distance > attack_range + 2.3:
				_change_state(LionState.CHASE)
			elif _state_time > 0.68 and _attack_cooldown <= 0.0:
				_change_state(LionState.ATTACK_WINDUP)
			else:
				var tangent := Vector3(-target_direction.z, 0.0, target_direction.x).normalized()
				if int(get_instance_id()) % 2 == 0:
					tangent = -tangent
				desired_direction = (tangent + target_direction.normalized() * 0.16).normalized()
				desired_speed = prowl_speed * 1.15
		LionState.ATTACK_WINDUP:
			attack_mix = clampf(_state_time / 0.42, 0.0, 1.0)
			_face_direction(target_direction, delta, 11.0)
			if _state_time >= 0.42 and not _attack_committed:
				_attack_committed = true
				_attack_cooldown = 1.15 if not _elite else 0.92
				if distance <= attack_range + 0.8 and is_instance_valid(_target):
					_target.take_damage(attack_damage)
					attacked_player.emit(attack_damage)
			if _state_time >= 0.58:
				_change_state(LionState.ATTACK_RECOVER)
		LionState.ATTACK_RECOVER:
			attack_mix = maxf(0.0, 1.0 - _state_time / 0.42)
			if target_direction.length_squared() > 0.01:
				desired_direction = -target_direction.normalized()
				desired_speed = 1.1
			if _state_time >= 0.48:
				_change_state(LionState.CIRCLE if distance < attack_range + 1.5 else LionState.CHASE)
		LionState.HURT:
			if _state_time >= 0.28:
				_change_state(LionState.CHASE)
		LionState.RETURN:
			if global_position.distance_to(_spawn_position) < 1.15:
				_choose_patrol_target()
				_change_state(LionState.ROAM)
			elif distance <= detection_range * 0.75:
				_change_state(LionState.ALERT)
			else:
				desired_direction = _direction_to(_spawn_position)
				desired_speed = prowl_speed

	_apply_movement(desired_direction, desired_speed, delta)
	move_and_slide()
	var movement_ratio := Vector2(velocity.x, velocity.z).length() / maxf(chase_speed, 0.01)
	_set_motion("motion_amount", clampf(movement_ratio, 0.0, 1.0))
	_set_motion("gait_speed", lerpf(2.2, 8.4, clampf(movement_ratio, 0.0, 1.0)))
	_set_motion("attack_mix", attack_mix)
	_set_motion("hurt_mix", 1.0 if _state == LionState.HURT else 0.0)


func _apply_movement(direction: Vector3, speed: float, delta: float) -> void:
	if direction.length_squared() > 0.01 and speed > 0.0:
		var separated := _apply_pack_separation(direction).normalized()
		var desired := separated * speed
		velocity.x = move_toward(velocity.x, desired.x, 12.5 * delta)
		velocity.z = move_toward(velocity.z, desired.z, 12.5 * delta)
		_face_direction(separated, delta, 7.5)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)


func _direction_to(destination: Vector3) -> Vector3:
	var direct := destination - global_position
	direct.y = 0.0
	if direct.length_squared() < 0.02:
		return Vector3.ZERO
	var map_rid := navigation_agent.get_navigation_map()
	if map_rid.is_valid() and NavigationServer3D.map_get_iteration_id(map_rid) > 0:
		navigation_agent.target_position = destination
		if not navigation_agent.is_navigation_finished():
			var next_position := navigation_agent.get_next_path_position()
			var path_direction := next_position - global_position
			path_direction.y = 0.0
			if path_direction.length_squared() > 0.02:
				return path_direction.normalized()
	return direct.normalized()


func _apply_pack_separation(direction: Vector3) -> Vector3:
	var result := direction
	for other in get_tree().get_nodes_in_group("lion_enemy"):
		if other == self or not is_instance_valid(other):
			continue
		var away: Vector3 = global_position - other.global_position
		away.y = 0.0
		var distance_squared := away.length_squared()
		if distance_squared > 0.01 and distance_squared < 4.0:
			result += away.normalized() * (1.0 - sqrt(distance_squared) * 0.5) * 0.82
	return result


func _face_direction(direction: Vector3, delta: float, turn_speed: float) -> void:
	if direction.length_squared() < 0.01:
		return
	var target_angle := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_angle, minf(1.0, delta * turn_speed))


func take_damage(amount: int, _hit_position: Vector3 = Vector3.ZERO) -> void:
	if _state == LionState.DEAD:
		return
	_health = maxi(0, _health - amount)
	health_changed.emit(_health, max_health)
	_update_label()
	status_label.visible = true
	var tween := create_tween()
	tween.tween_property(visual, "scale", visual.scale * 0.92, 0.055)
	tween.tween_property(visual, "scale", visual.scale, 0.11)
	tween.tween_callback(func(): status_label.visible = false)
	if _health <= 0:
		_die()
	else:
		_change_state(LionState.HURT)


func _die() -> void:
	_change_state(LionState.DEAD)
	collision.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	status_label.visible = false
	died.emit(self)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual, "rotation:z", deg_to_rad(84.0), 0.65).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(visual, "position:y", -0.22, 0.65)
	tween.chain().tween_interval(1.6)
	tween.chain().tween_property(self, "scale", Vector3.ZERO, 0.3)
	tween.chain().tween_callback(queue_free)


func _change_state(next_state: LionState) -> void:
	if _state == next_state and _state_time > 0.0:
		return
	_state = next_state
	_state_time = 0.0
	_attack_committed = false
	state_changed.emit(get_state_name())


func get_state_name() -> StringName:
	return LionState.keys()[_state].to_lower()


func get_health() -> int:
	return _health


func _choose_patrol_target() -> void:
	_patrol_timer = _rng.randf_range(2.8, 5.8)
	_patrol_target = _spawn_position + Vector3(_rng.randf_range(-4.8, 4.8), 0.0, _rng.randf_range(-5.6, 5.6))


func _update_label() -> void:
	if status_label:
		status_label.text = "أسد  %d / %d" % [_health, max_health]


func _apply_motion_shader() -> void:
	var shader := load("res://assets/characters/lion_motion.gdshader") as Shader
	for child in visual.get_children():
		_collect_mesh_materials(child, shader)


func _collect_mesh_materials(node: Node, shader: Shader) -> void:
	if node is MeshInstance3D and node.mesh:
		for surface in range(node.mesh.get_surface_count()):
			var original := node.mesh.surface_get_material(surface) as BaseMaterial3D
			var animated := ShaderMaterial.new()
			animated.shader = shader
			if original:
				animated.set_shader_parameter("albedo_color", original.albedo_color)
				if original.albedo_texture:
					animated.set_shader_parameter("albedo_texture", original.albedo_texture)
					animated.set_shader_parameter("use_texture", true)
			node.set_surface_override_material(surface, animated)
			_motion_materials.append(animated)
	for child in node.get_children():
		_collect_mesh_materials(child, shader)


func _set_motion(parameter: StringName, value: float) -> void:
	for material in _motion_materials:
		material.set_shader_parameter(parameter, value)
