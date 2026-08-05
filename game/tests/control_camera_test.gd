extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failed = true
		printerr("FAIL: ", message)


func _run() -> void:
	var player_scene := load("res://scenes/characters/player.tscn") as PackedScene
	_check(player_scene != null, "player scene loads")
	if player_scene == null:
		quit(1)
		return

	var player := player_scene.instantiate()
	root.add_child(player)
	await process_frame

	var slow_speed: float = player.call("_speed_for_input", 0.30, false)
	var walk_speed: float = player.call("_speed_for_input", 0.68, false)
	var run_speed: float = player.call("_speed_for_input", 1.0, true)
	_check(slow_speed > 0.0 and slow_speed < walk_speed, "analog stick gives a slow walk")
	_check(walk_speed < run_speed, "full input and sprint give a faster run")

	var camera_before: Vector2 = player.call("get_camera_angles")
	player.call("rotate_camera", Vector2(120.0, 45.0))
	var camera_target: Vector2 = player.call("get_target_camera_angles")
	var camera_immediate: Vector2 = player.call("get_camera_angles")
	_check(camera_target.distance_to(camera_before) > 0.02, "drag changes the desired camera angle")
	_check(camera_immediate.distance_to(camera_target) > 0.001, "camera does not snap to the desired angle")
	for frame in range(8):
		await process_frame
	var camera_smoothed: Vector2 = player.call("get_camera_angles")
	_check(camera_smoothed.distance_to(camera_target) < camera_before.distance_to(camera_target), "camera eases toward its target")
	player.call("rotate_camera", Vector2(0.0, 50000.0))
	var clamped_target: Vector2 = player.call("get_target_camera_angles")
	_check(clamped_target.y >= deg_to_rad(-34.01), "camera downward pitch is clamped")

	var joystick_script := load("res://scripts/ui/virtual_joystick.gd") as Script
	var joystick := joystick_script.new() as Control
	joystick.size = Vector2(300.0, 270.0)
	root.add_child(joystick)
	await process_frame
	joystick.call("_begin_at", Vector2(150.0, 140.0))
	joystick.call("_update_knob", Vector2(178.0, 140.0))
	var partial_strength := Input.get_action_strength("move_right")
	joystick.call("_update_knob", Vector2(250.0, 140.0))
	var full_strength := Input.get_action_strength("move_right")
	_check(partial_strength > 0.0 and partial_strength < 0.75, "joystick preserves partial analog strength")
	_check(full_strength > partial_strength and full_strength > 0.95, "joystick reaches full analog strength")
	joystick.call("_release_actions")

	player.queue_free()
	joystick.queue_free()
	print("CONTROL CAMERA TEST ", "FAILED" if _failed else "PASSED")
	quit(1 if _failed else 0)
