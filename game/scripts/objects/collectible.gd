extends Area3D

signal collected(item: Area3D)

var _origin_y := 0.0
var _phase := 0.0
var _taken := false


func _ready() -> void:
	add_to_group("collectible")
	_origin_y = position.y
	_phase = position.x * 0.71 + position.z * 0.37
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _taken:
		return
	rotation.y += delta * 1.7
	position.y = _origin_y + sin(Time.get_ticks_msec() * 0.0025 + _phase) * 0.12


func _on_body_entered(body: Node3D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	set_deferred("monitoring", false)
	collected.emit(self)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.22).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "position:y", position.y + 1.0, 0.22)
	tween.chain().tween_callback(queue_free)
