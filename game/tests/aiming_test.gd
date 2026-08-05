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
	var lion_scene := load("res://scenes/characters/lion_enemy.tscn") as PackedScene
	var player := player_scene.instantiate()
	var lion := lion_scene.instantiate()
	root.add_child(player)
	lion.position = Vector3(0.0, 0.0, -12.0)
	root.add_child(lion)
	player.set_physics_process(false)
	lion.set_physics_process(false)
	await process_frame
	await physics_frame
	var camera := player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	lion.global_position = camera.global_position - camera.global_basis.z * 12.0 - Vector3.UP * 0.72
	await physics_frame

	Input.action_press("aim")
	for frame in range(24):
		await process_frame
	_check(camera.fov < 38.0, "المنظار يقرّب مجال الرؤية")
	_check(float(player.get_node("CameraPivot/SpringArm3D").spring_length) < 0.22, "المنظار ينتقل إلى خط نظر السلاح")
	_check(not player.get_node("Visual").visible, "جسم اللاعب لا يحجب مجال المنظار")
	var target := player.call("_find_aim_target", 12.0) as Node3D
	_check(target == lion, "مساعدة التصويب تلتقط الأسد القريب من مركز المنظار")
	var health_before := int(lion.get("_health"))
	player.call("_shoot")
	await physics_frame
	_check(int(lion.get("_health")) < health_before, "الرصاصة المصوبة تصيب الأسد")
	_check(Input.is_action_pressed("aim"), "المنظار يبقى ثابتًا بعد إطلاق النار")
	_check(not player.get_node("Visual").visible, "إطلاق النار لا يعيد كاميرا الشخص تلقائيًا")
	Input.action_release("aim")
	for frame in range(2):
		await process_frame
	_check(player.get_node("Visual").visible, "زر المنظار يعيد الوضع العادي عند اختياره")

	print("AIMING TEST ", "FAILED" if _failed else "PASSED")
	quit(1 if _failed else 0)
