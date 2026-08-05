extends Control

signal vector_changed(value: Vector2)

@export var radius := 76.0
@export_range(0.0, 0.5, 0.01) var deadzone := 0.12
@export_range(0.5, 2.0, 0.05) var response_curve := 1.15
@export var floating_mode := true

var _touch_index := -1
var _knob := Vector2.ZERO
var _base_center := Vector2.ZERO
var _value := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	floating_mode = GameState.floating_joystick
	modulate.a = GameState.control_opacity
	_reset_base()
	queue_redraw()


func _exit_tree() -> void:
	_release_actions()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_begin_at(event.position)
			_update_knob(event.position)
			accept_event()
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_knob = Vector2.ZERO
			_release_actions()
			queue_redraw()
			accept_event()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_knob(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touch_index = -2
			_begin_at(event.position)
			_update_knob(event.position)
		else:
			_touch_index = -1
			_knob = Vector2.ZERO
			_release_actions()
			queue_redraw()
	elif event is InputEventMouseMotion and _touch_index == -2:
		_update_knob(event.position)


func _draw() -> void:
	draw_circle(_base_center, radius, Color(0.015, 0.035, 0.03, 0.48))
	draw_circle(_base_center, radius - 4.0, Color(0.82, 0.91, 0.84, 0.15), false, 3.0)
	draw_circle(_base_center + _knob, radius * 0.39, Color(0.91, 0.76, 0.39, 0.82))
	draw_circle(_base_center + _knob, radius * 0.27, Color(1.0, 0.91, 0.65, 0.22), false, 2.0)


func _update_knob(local_position: Vector2) -> void:
	_knob = (local_position - _base_center).limit_length(radius)
	var raw := _knob / radius
	var magnitude := raw.length()
	if magnitude <= deadzone:
		_value = Vector2.ZERO
	else:
		var remapped := clampf((magnitude - deadzone) / (1.0 - deadzone), 0.0, 1.0)
		_value = raw.normalized() * pow(remapped, response_curve)
	_apply_axis("move_left", "move_right", _value.x)
	_apply_axis("move_forward", "move_back", _value.y)
	vector_changed.emit(_value)
	queue_redraw()


func _apply_axis(negative_action: StringName, positive_action: StringName, value: float) -> void:
	if value < -0.001:
		Input.action_press(negative_action, absf(value))
		Input.action_release(positive_action)
	elif value > 0.001:
		Input.action_press(positive_action, absf(value))
		Input.action_release(negative_action)
	else:
		Input.action_release(negative_action)
		Input.action_release(positive_action)


func _release_actions() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_forward")
	Input.action_release("move_back")
	_value = Vector2.ZERO
	vector_changed.emit(_value)
	_reset_base()


func _begin_at(local_position: Vector2) -> void:
	if not floating_mode:
		return
	var padding := radius + 4.0
	_base_center = Vector2(
		clampf(local_position.x, padding, maxf(padding, size.x - padding)),
		clampf(local_position.y, padding, maxf(padding, size.y - padding))
	)


func _reset_base() -> void:
	_base_center = size * 0.5
	queue_redraw()
