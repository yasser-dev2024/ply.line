extends Control

signal look_dragged(relative: Vector2)

@export var drag_threshold := 3.5

var _touch_index := -1
var _mouse_dragging := false
var _touch_distance := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_touch_distance = 0.0
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_touch_distance = 0.0
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_touch_distance += event.relative.length()
		if _touch_distance >= drag_threshold:
			look_dragged.emit(event.relative.limit_length(72.0))
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_dragging = event.pressed
	elif event is InputEventMouseMotion and _mouse_dragging:
		look_dragged.emit(event.relative)
