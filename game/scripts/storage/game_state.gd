extends Node

const SAVE_PATH := "user://progress.cfg"

var best_time_seconds: float = 0.0
var unlocked_level: int = 1
var quality_level: int = 0 if OS.has_feature("mobile") else 1
var camera_sensitivity: float = 0.22
var camera_smoothing: float = 12.0
var invert_camera_y: bool = false
var floating_joystick: bool = true
var control_opacity: float = 0.82
var master_volume: float = 0.8
var run_started_msec: int = 0
var selected_level: int = 1
var coins: int = 0
var relics: int = 0
var completed_levels: Array = []


func _ready() -> void:
	_setup_input_map()
	load_progress()
	apply_settings()


func _setup_input_map() -> void:
	_add_action("move_left", 0.15)
	_add_action("move_right", 0.15)
	_add_action("move_forward", 0.15)
	_add_action("move_back", 0.15)
	_add_action("jump")
	_add_action("sprint")
	_add_action("interact")
	_add_action("fire")
	_add_action("aim")
	_add_action("reload")
	_add_action("pause")

	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("move_forward", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("jump", KEY_SPACE)
	_add_key("sprint", KEY_SHIFT)
	_add_key("interact", KEY_E)
	_add_mouse_button("fire", MOUSE_BUTTON_LEFT)
	_add_mouse_button("aim", MOUSE_BUTTON_RIGHT)
	_add_key("reload", KEY_R)
	_add_key("pause", KEY_ESCAPE)

	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_button("jump", JOY_BUTTON_A)
	_add_joy_button("sprint", JOY_BUTTON_LEFT_STICK)
	_add_joy_button("interact", JOY_BUTTON_X)
	_add_joy_button("fire", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_button("aim", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_button("reload", JOY_BUTTON_Y)
	_add_joy_button("pause", JOY_BUTTON_START)


func _add_action(action_name: StringName, deadzone: float = 0.2) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, deadzone)


func _add_key(action_name: StringName, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	if not InputMap.action_has_event(action_name, event):
		InputMap.action_add_event(action_name, event)


func _add_joy_axis(action_name: StringName, axis: JoyAxis, axis_value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	InputMap.action_add_event(action_name, event)


func _add_joy_button(action_name: StringName, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action_name, event)


func _add_mouse_button(action_name: StringName, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action_name, event)


func get_level_scene(level_number: int = selected_level) -> String:
	return "res://scenes/levels/forest_stage_%d.tscn" % clampi(level_number, 1, 5)


func grant_stage_reward(stage_number: int, full_reward: int) -> int:
	var awarded := full_reward
	if stage_number in completed_levels:
		awarded = maxi(25, int(full_reward / 5.0))
	else:
		completed_levels.append(stage_number)
		relics += 1
	coins += awarded
	return awarded


func start_run() -> void:
	run_started_msec = Time.get_ticks_msec()


func finish_run(measured_seconds: float = -1.0) -> float:
	var elapsed := measured_seconds
	if elapsed < 0.0:
		elapsed = maxf(0.0, (Time.get_ticks_msec() - run_started_msec) / 1000.0)
	if best_time_seconds <= 0.0 or elapsed < best_time_seconds:
		best_time_seconds = elapsed
		save_progress()
	return elapsed


func save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "best_time_seconds", best_time_seconds)
	config.set_value("progress", "unlocked_level", unlocked_level)
	config.set_value("progress", "coins", coins)
	config.set_value("progress", "relics", relics)
	config.set_value("progress", "completed_levels", completed_levels)
	config.set_value("settings", "quality_level", quality_level)
	config.set_value("settings", "camera_sensitivity", camera_sensitivity)
	config.set_value("settings", "camera_smoothing", camera_smoothing)
	config.set_value("settings", "invert_camera_y", invert_camera_y)
	config.set_value("settings", "floating_joystick", floating_joystick)
	config.set_value("settings", "control_opacity", control_opacity)
	config.set_value("settings", "master_volume", master_volume)
	config.save(SAVE_PATH)


func load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	best_time_seconds = float(config.get_value("progress", "best_time_seconds", 0.0))
	unlocked_level = clampi(int(config.get_value("progress", "unlocked_level", 1)), 1, 5)
	coins = maxi(0, int(config.get_value("progress", "coins", 0)))
	relics = maxi(0, int(config.get_value("progress", "relics", 0)))
	completed_levels = config.get_value("progress", "completed_levels", [])
	quality_level = int(config.get_value("settings", "quality_level", quality_level))
	# A stable frame rate matters more than excessive distant foliage on phones.
	# Force the tested mobile profile even when an older save selected higher quality.
	if OS.has_feature("mobile"):
		quality_level = 0
	camera_sensitivity = float(config.get_value("settings", "camera_sensitivity", 0.22))
	camera_smoothing = clampf(float(config.get_value("settings", "camera_smoothing", 12.0)), 4.0, 24.0)
	invert_camera_y = bool(config.get_value("settings", "invert_camera_y", false))
	floating_joystick = bool(config.get_value("settings", "floating_joystick", true))
	control_opacity = clampf(float(config.get_value("settings", "control_opacity", 0.82)), 0.35, 1.0)
	master_volume = float(config.get_value("settings", "master_volume", 0.8))


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))
	var mobile_profile := OS.has_feature("mobile")
	Engine.max_fps = 30 if mobile_profile or quality_level == 0 else 60
	Engine.physics_ticks_per_second = 30 if mobile_profile else 60
	var viewport := get_viewport()
	if viewport:
		viewport.scaling_3d_scale = 0.52 if mobile_profile else [0.72, 0.86, 1.0][clampi(quality_level, 0, 2)]
