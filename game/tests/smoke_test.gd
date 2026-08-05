extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		printerr("FAIL: ", message)


func _run() -> void:
	var packed := load("res://scenes/levels/forest_level.tscn") as PackedScene
	_check(packed != null, "تحميل مشهد الغابة")
	if packed == null:
		quit(1)
		return

	var level := packed.instantiate()
	root.add_child(level)
	await process_frame
	await physics_frame

	var player := level.get_node_or_null("Player") as CharacterBody3D
	var hud := level.get_node_or_null("HUD")
	_check(player != null, "وجود اللاعب ثلاثي الأبعاد")
	_check(hud != null, "وجود واجهة اللمس")
	_check(get_nodes_in_group("collectible").size() == 3, "وجود عناصر مهمة المرحلة الأولى")
	_check(get_nodes_in_group("lion_enemy").size() == 2, "وجود أسدين متحركين في المرحلة الأولى")
	_check(level.get_node_or_null("RealForestWorld/NaturalTreeTrunks") != null, "استخدام MultiMesh للأشجار الطبيعية الجديدة")
	_check(level.get_node_or_null("RealForestWorld/SculptedForestTerrain") != null, "وجود تضاريس طبيعية غير مسطحة")
	_check(level.get_node_or_null("RealForestWorld/FlowingRiver") != null, "وجود نهر متحرك داخل العالم الجديد")
	_check(level.get_node_or_null("GoalArea") != null, "وجود هدف نهاية تفاعلي")

	if player != null:
		var start_position := player.global_position
		Input.action_press("move_forward")
		for frame in range(28):
			await physics_frame
		Input.action_release("move_forward")
		_check(player.global_position.distance_to(start_position) > 0.35, "استجابة اللاعب للحركة عبر Input Map")

		var items := get_nodes_in_group("collectible")
		for item in items:
			item.call("_on_body_entered", player)
		await process_frame
		_check(int(level.get("_pieces_collected")) == 3, "تحديث عداد عناصر المهمة")
		level.call("_on_adventure_event_entered", player)
		await process_frame
		_check(bool(level.get("_adventure_event_completed")), "إلزام حدث الاستكشاف قبل نهاية المرحلة")
		var lions := get_nodes_in_group("lion_enemy")
		for lion in lions:
			lion.call("take_damage", 999, lion.global_position)
		await process_frame
		_check(int(level.get("_lions_remaining")) == 0, "ربط هزيمة الأسود بهدف المرحلة")
		level.call("_on_goal_entered", player)
		Input.action_press("interact")
		await process_frame
		Input.action_release("interact")
		_check(bool(level.get("_completed")), "إكمال سلسلة أهداف المرحلة عند التفاعل النهائي")

	if _failures.is_empty():
		print("SMOKE TEST PASSED")
		quit(0)
	else:
		printerr("SMOKE TEST FAILED: ", _failures)
		quit(1)
